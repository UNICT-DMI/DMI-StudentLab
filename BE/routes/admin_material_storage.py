import hashlib
import json
import logging
from datetime import datetime, timezone
import httpx
from pydantic import BaseModel, Field
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_admin_user
from models.user import User
from models.public_material import PublicMaterial
from models.subject import Subject
from models.group import StudyGroup
from services.drive_material_storage import copy_public_material, drive_status, delete_public_drive_copy, preview_public_material, public_drive_response, _access_token, _session, mark_retry
from services.drive_material_catalog import clean_path, verify_under_root, FOLDER_MIME
from core.config import settings
from services.admin_material_storage import record_storage_event, utc_now
from services.public_drive_blob_retirement import retire_public_staging_blob_best_effort
from schemas.admin_material_storage import (
    AdminMaterialStorageCleanupRequest,
    AdminMovePublicFolderRequest,
    AdminPlacePublicMaterialRequest,
    AdminPublicVisibilityRequest,
    AdminPublicAudienceRequest,
    AdminMaterialStorageDeleteBlobRequest,
    AdminMaterialStorageRenameRequest,
    AdminMaterialStorageRetireRequest,
)
from services.admin_material_storage import (
    build_storage_snapshot,
    cleanup_dry_run,
    delete_record_blob,
    execute_cleanup,
    get_admin_material_items,
    rename_material,
    retire_material,
    move_public_folder,
    place_public_file,
    set_public_visibility,
    set_public_audience,
)
from services.material_catalog_draft import (
    list_drafts, list_folders, list_imports, stage, stage_folder,
    stage_drive_import, discard, publish, preview,
)

from services.drive_material_catalog import default_path
from services.material_publication_request import (
    approve_material_publication_request, get_publication_request_by_id,
)
from schemas.material_publication_request import MaterialPublicationApproveRequest
from models.teacher_material_request import TeacherMaterialRequest
from services.notification import create_notification
from services.material_catalog_draft import _path as catalog_path

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/admin/material-storage",
    tags=["admin-material-storage"],
)


class DrivePlacementRequest(BaseModel):
    path: list[str] | None = None
    allow_duplicate: bool = False


class DriveImportRequest(BaseModel):
    file_id: str
    subject_id: int
    audience_type: str = 'public'
    audience_id: int | None = None


class CatalogDraftRequest(BaseModel):
    subject_id: int
    path_segments: list[str]
    visibility_state: str
    audience_type: str
    audience_id: int | None = None


class CatalogFolderRequest(BaseModel):
    subject_id: int
    path_segments: list[str]


class CatalogImportRequest(BaseModel):
    file_id: str
    subject_id: int
    path_segments: list[str] = Field(default_factory=list)
    audience_type: str = 'public'
    audience_id: int | None = None
    allow_duplicate: bool = False


@router.get('/catalog/draft')
def get_catalog_draft(current_user: User = Depends(get_admin_user),
        db: Session = Depends(get_db)):
    return {'changes': list_drafts(db, current_user.id),
        'folders': list_folders(db, current_user.id),
        'imports': list_imports(db, current_user.id)}


@router.post('/catalog/folders')
def put_catalog_folder(request: CatalogFolderRequest,
        current_user: User = Depends(get_admin_user), db: Session = Depends(get_db)):
    try:
        return stage_folder(db, current_user.id, request.subject_id, request.path_segments)
    except ValueError as exc:
        db.rollback()
        raise HTTPException(400, str(exc)) from exc


@router.post('/catalog/import')
async def put_catalog_import(request: CatalogImportRequest,
        current_user: User = Depends(get_admin_user), db: Session = Depends(get_db)):
    try:
        return await stage_drive_import(db, admin_id=current_user.id,
            file_id=request.file_id, subject_id=request.subject_id,
            path=request.path_segments, audience=request.audience_type,
            audience_id=request.audience_id, allow_duplicate=request.allow_duplicate)
    except (ValueError, RuntimeError) as exc:
        db.rollback()
        raise HTTPException(409 if isinstance(exc, RuntimeError) else 400,
            str(exc)) from exc


@router.put('/catalog/draft/{material_id}')
def put_catalog_draft(material_id: int, request: CatalogDraftRequest,
        current_user: User = Depends(get_admin_user), db: Session = Depends(get_db)):
    try:
        return stage(db, admin_id=current_user.id, material_id=material_id,
            subject_id=request.subject_id, path=request.path_segments,
            state=request.visibility_state, audience=request.audience_type,
            audience_id=request.audience_id)
    except RuntimeError as exc:
        db.rollback()
        raise HTTPException(409, str(exc)) from exc
    except ValueError as exc:
        db.rollback()
        raise HTTPException(400, str(exc)) from exc


@router.delete('/catalog/draft')
def delete_catalog_draft(current_user: User = Depends(get_admin_user),
        db: Session = Depends(get_db)):
    return discard(db, current_user.id)


@router.post('/catalog/publish')
async def publish_catalog_draft(current_user: User = Depends(get_admin_user),
        db: Session = Depends(get_db)):
    try:
        return await publish(db, current_user)
    except RuntimeError as exc:
        db.rollback()
        raise HTTPException(409, str(exc)) from exc
    except ValueError as exc:
        db.rollback()
        raise HTTPException(400, str(exc)) from exc


@router.get('/catalog/preview')
def preview_catalog_draft(user_id: int | None = Query(default=None, gt=0),
        current_user: User = Depends(get_admin_user), db: Session = Depends(get_db)):
    if user_id is not None and db.query(User.id).filter(
        User.id == user_id, User.is_active.is_(True)).first() is None:
        raise HTTPException(404, 'Studente non trovato.')
    return preview(db, admin_id=current_user.id, user_id=user_id)


@router.get('/drive/import-options')
def admin_drive_import_options(current_user: User = Depends(get_admin_user),
        db: Session = Depends(get_db)):
    """Active catalog subjects for classifying existing Drive files."""
    subjects = db.query(Subject).filter(Subject.is_active.is_(True)).order_by(
        Subject.university, Subject.department, Subject.course,
        Subject.study_year, Subject.name).all()
    return [{'id': subject.id, 'name': subject.name,
             'university': subject.university, 'department': subject.department,
             'course': subject.course, 'year': subject.study_year}
            for subject in subjects]


@router.get('/drive/tree')
async def admin_drive_tree(folder_id: str | None = None,
    page_token: str | None = Query(default=None, max_length=512),
    current_user: User = Depends(get_admin_user), db: Session = Depends(get_db)):
    # Browsing the existing catalog needs read access; a writable root is
    # required only when creating a new Drive copy.
    folder_id = folder_id or settings.drive_folder_id
    async with await _session() as client:
        headers = {'Authorization': f'Bearer {await _access_token(client)}'}
        if folder_id != settings.drive_folder_id:
            folder = await verify_under_root(client, headers, folder_id)
            if folder.get('mimeType') != FOLDER_MIME:
                raise HTTPException(400, 'La destinazione non è una cartella.')
        try:
            response = await client.get('https://www.googleapis.com/drive/v3/files',
                headers=headers, params={'q': f"'{folder_id}' in parents and trashed = false",
                    'pageSize': 100, **({'pageToken': page_token} if page_token else {}),
                    'fields': 'nextPageToken,files(id,name,mimeType,size,parents,modifiedTime,owners(displayName,emailAddress),lastModifyingUser(displayName))',
                    'supportsAllDrives': 'true', 'includeItemsFromAllDrives': 'true'})
            response.raise_for_status()
            payload = response.json()
            children = payload.get('files') or []
        except (httpx.HTTPError, ValueError) as exc:
            raise HTTPException(503, 'Impossibile leggere questa cartella Drive.') from exc
        ids = [e['id'] for e in children if e.get('mimeType') != FOLDER_MIME]
        indexed = set()
        if ids:
            indexed = {row[0] for row in db.query(PublicMaterial.drive_file_id)
                .filter(PublicMaterial.drive_file_id.in_(ids), PublicMaterial.status != 'removed').all()}
        return {'folder_id': folder_id, 'next_page_token': payload.get('nextPageToken'), 'items': [
            {'id': e['id'], 'name': e.get('name', ''), 'mime_type': e.get('mimeType'),
             'size': int(e.get('size') or 0), 'indexed': e['id'] in indexed,
             'modified_at': e.get('modifiedTime'),
             'owner': ((e.get('owners') or [{}])[0].get('displayName')
                 or (e.get('owners') or [{}])[0].get('emailAddress')),
             'last_modified_by': (e.get('lastModifyingUser') or {}).get('displayName')}
            for e in sorted(children, key=lambda e: (e.get('mimeType') != FOLDER_MIME,
                e.get('name', '').casefold()))]}


@router.post('/drive/import')
async def admin_import_drive_file(request: DriveImportRequest,
    current_user: User = Depends(get_admin_user), db: Session = Depends(get_db)):
    """Index a Drive file only after its course and audience are chosen by an admin."""
    if request.audience_type not in {'public', 'course', 'subject', 'group', 'user'}:
        raise HTTPException(400, 'Destinatari non validi.')
    if request.audience_type in {'group', 'user'} and (request.audience_id is None or request.audience_id <= 0):
        raise HTTPException(400, 'Indica l’ID dello studente o del gruppo.')
    subject = db.query(Subject).filter(Subject.id == request.subject_id).first()
    if not subject or not subject.is_active:
        raise HTTPException(404, 'Materia del catalogo non trovata.')
    if request.audience_type == 'user' and not db.query(User.id).filter(
            User.id == request.audience_id, User.is_active.is_(True)).first():
        raise HTTPException(400, 'Studente destinatario non trovato.')
    if request.audience_type == 'group' and not db.query(StudyGroup.id).filter(
            StudyGroup.id == request.audience_id, StudyGroup.subject_id == subject.id,
            StudyGroup.status == 'active').first():
        raise HTTPException(400, 'Gruppo destinatario non valido per questa materia.')
    # Indexing an existing file reads Drive and writes only to our catalog.
    async with await _session() as client:
        headers = {'Authorization': f'Bearer {await _access_token(client)}'}
        entry = await verify_under_root(client, headers, request.file_id)
        mime = entry.get('mimeType', '')
        size = int(entry.get('size') or 0)
        if mime == FOLDER_MIME or mime.startswith('application/vnd.google-apps.'):
            raise HTTPException(400, 'Esporta il documento Google come file prima di importarlo.')
        if not 0 < size <= 20 * 1024 * 1024:
            raise HTTPException(413, 'Importazione diretta disponibile per file fino a 20 MB.')
        if db.query(PublicMaterial.id).filter(PublicMaterial.drive_file_id == request.file_id,
                PublicMaterial.status != 'removed').first():
            raise HTTPException(409, 'File già presente nel catalogo StudentLab.')
        digest = hashlib.sha256()
        count = 0
        try:
            async with client.stream('GET', f'https://www.googleapis.com/drive/v3/files/{request.file_id}',
                    headers=headers, params={'alt': 'media', 'supportsAllDrives': 'true'}) as response:
                response.raise_for_status()
                async for chunk in response.aiter_bytes():
                    count += len(chunk)
                    if count > 20 * 1024 * 1024:
                        raise HTTPException(413, 'File troppo grande per l’importazione diretta.')
                    digest.update(chunk)
        except httpx.HTTPError as exc:
            raise HTTPException(503, 'Impossibile leggere il file da Google Drive.') from exc
        if count != size:
            raise HTTPException(503, 'La dimensione del file Drive è cambiata. Riprova.')
        # Retain the folder hierarchy as catalog metadata; never move Drive bytes.
        folders = []
        parent_ids = entry.get('parents') or []
        for _ in range(20):
            if settings.drive_folder_id in parent_ids:
                break
            if len(parent_ids) != 1:
                raise HTTPException(400, 'Percorso del file Drive ambiguo.')
            parent = await verify_under_root(client, headers, parent_ids[0])
            if parent.get('mimeType') != FOLDER_MIME:
                raise HTTPException(400, 'Percorso del file Drive non valido.')
            folders.insert(0, parent.get('name', ''))
            parent_ids = parent.get('parents') or []
        else:
            raise HTTPException(400, 'Percorso Drive troppo profondo.')
        # A matching academic prefix is already represented by the subject card.
        expected = [subject.university, subject.department, subject.course, subject.name]
        if len(folders) >= 4 and all(str(a).casefold() == str(b).casefold()
                for a, b in zip(folders[:4], expected)):
            folders = folders[4:]
        folders = clean_path(folders)
        name = str(entry.get('name') or 'materiale')[:255]
        now = datetime.now(timezone.utc)
        row = PublicMaterial(subject_id=subject.id, uploaded_by=None,
            university=subject.university, university_code=subject.university_code or '',
            department=subject.department, department_code=subject.department_code or '',
            course=subject.course, course_code=subject.course_code or '',
            title=name[:250], original_name=name,
            stored_name=f'drive-import/{request.file_id}', file_path=f'drive://{request.file_id}',
            catalog_path_json=json.dumps(folders, ensure_ascii=False),
            mime_type=mime or 'application/octet-stream', size=size,
            file_hash=digest.hexdigest(), drive_file_id=request.file_id,
            drive_copied_at=now, audience_type=request.audience_type,
            audience_id=request.audience_id if request.audience_type in {'group', 'user'} else None,
            status='published', is_visible=True, visibility_state='visible',
            approved_by=current_user.id, approved_at=now, contributor_mode='anonymous')
        db.add(row)
        try:
            db.commit()
            db.refresh(row)
        except Exception:
            db.rollback()
            raise HTTPException(409, 'Impossibile registrare il file; verifica che non sia già presente.')
        return {'id': row.id, 'drive_file_id': request.file_id}


@router.post('/public/{material_id}/drive-preview')
async def admin_preview_public_drive(material_id: int, request: DrivePlacementRequest,
    current_user: User = Depends(get_admin_user), db: Session = Depends(get_db)):
    material = db.query(PublicMaterial).filter(PublicMaterial.id == material_id).first()
    if material is None or material.status == 'removed':
        raise HTTPException(404, 'Materiale non disponibile.')
    return await preview_public_material(material, request.path)


@router.get('/drive/file/{file_id}/preview')
async def admin_preview_file_in_drive(file_id: str,
    current_user: User = Depends(get_admin_user)):
    # Previews do not require permission to add files to the root.
    async with await _session() as client:
        headers = {'Authorization': f'Bearer {await _access_token(client)}'}
        file = await verify_under_root(client, headers, file_id)
        if int(file.get('size') or 0) > 20 * 1024 * 1024:
            raise HTTPException(413, 'Anteprima limitata a file di 20 MB.')
        mime = file.get('mimeType')
        if mime == FOLDER_MIME or not isinstance(mime, str):
            raise HTTPException(400, 'Questa cartella non ha un’anteprima file.')
        # Keep opaque or active content as an attachment.
        inline = mime in {'application/pdf', 'image/png', 'image/jpeg',
            'image/webp', 'text/plain'}
        return await public_drive_response(drive_file_id=file_id,
            original_name=file.get('name', 'materiale'), mime_type=mime,
            inline=inline)


@router.get('/drive/status')
async def admin_drive_status(
    current_user: User = Depends(get_admin_user),
):
    return await drive_status()


@router.post('/public/{material_id}/drive-copy')
async def admin_copy_public_to_drive(
    material_id: int,
    placement: DrivePlacementRequest | None = None,
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    material = db.query(PublicMaterial).filter(PublicMaterial.id == material_id).first()
    if material is None:
        raise HTTPException(status_code=404, detail='Materiale non trovato.')
    if material.drive_file_id:
        await retire_public_staging_blob_best_effort(db, material, current_user.id)
        return {'id': material.id, 'copied': True}
    if placement is not None:
        if placement.path is not None:
            material.drive_path_json = json.dumps(clean_path(placement.path), ensure_ascii=False)
        material.drive_allow_duplicate = placement.allow_duplicate
        material.drive_retry_after = None
        db.commit()
    try:
        drive_id = await copy_public_material(material)
    except Exception as exc:
        db.rollback()
        logger.error('admin_drive_copy_failed material_id=%s error_type=%s http_status=%s',
                     material_id, type(exc).__name__,
                     exc.status_code if isinstance(exc, HTTPException) else None)
        if material.drive_activation_pending:
            state = mark_retry(material, exc)
            record_storage_event(db, source='public', material_id=material.id,
                action='drive_copy_pending', actor_id=current_user.id,
                details={'state': state}, commit=True)
        if isinstance(exc, HTTPException):
            raise
        raise HTTPException(503, 'Non è stato possibile completare la copia Drive. Il file originale è conservato.') from exc
    material.drive_file_id = drive_id
    material.drive_copied_at = utc_now()
    material.drive_retry_after = None
    if material.drive_activation_pending:
        material.drive_activation_pending = False
        material.status = 'published'
        material.is_visible = True
        material.visibility_state = 'visible'
        material.version = (material.version or 1) + 1
        material.updated_at = utc_now()
    record_storage_event(db, source='public', material_id=material.id,
        action='drive_copied', actor_id=current_user.id,
        blob_path=material.stored_name, original_name=material.original_name,
        size=material.size, details={'drive_file_id': drive_id}, commit=False)
    try:
        db.commit()
    except Exception:
        db.rollback()
        raise
    await retire_public_staging_blob_best_effort(db, material, current_user.id)
    return {'id': material.id, 'copied': True}


@router.delete('/public/{material_id}/drive-copy')
async def admin_delete_public_drive_copy(
    material_id: int, confirmation: str = Query(...),
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    if confirmation != 'ELIMINA':
        raise HTTPException(status_code=400, detail='Conferma ELIMINA richiesta.')
    material = db.query(PublicMaterial).filter(PublicMaterial.id == material_id).first()
    if material is None or not material.drive_file_id:
        raise HTTPException(status_code=404, detail='Copia Drive non trovata.')
    previous_id = material.drive_file_id
    if material.status != 'removed':
        raise HTTPException(status_code=409,
            detail='Ritira prima il materiale: Drive è la copia principale.')
    await delete_public_drive_copy(material)
    material.drive_file_id = None
    material.drive_copied_at = None
    record_storage_event(db, source='public', material_id=material.id,
        action='drive_deleted', actor_id=current_user.id,
        blob_path=material.stored_name, original_name=material.original_name,
        size=material.size, details={'drive_file_id': previous_id}, commit=False)
    try:
        db.commit()
    except Exception:
        db.rollback()
        raise
    return {'id': material.id, 'copied': False}


@router.get("/overview")
async def admin_material_storage_overview(
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    return await build_storage_snapshot(db)


@router.get("/items")
def admin_material_storage_items(
    source: str | None = Query(default=None),
    status_filter: str | None = Query(default=None, alias="status"),
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    try:
        return get_admin_material_items(
            db,
            source=source,
            status=status_filter,
        )
    except ValueError as exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exception),
        )


@router.patch("/{source}/{material_id}/display-name")
def admin_material_storage_rename(
    source: str,
    material_id: int,
    request: AdminMaterialStorageRenameRequest,
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    try:
        return rename_material(
            db,
            source=source,
            material_id=material_id,
            actor=current_user,
            display_name=request.display_name,
        )
    except ValueError as exception:
        message = str(exception)
        raise HTTPException(
            status_code=(
                status.HTTP_404_NOT_FOUND
                if message == "Materiale non trovato."
                else status.HTTP_400_BAD_REQUEST
            ),
            detail=message,
        )


@router.post("/{source}/{material_id}/retire")
def admin_material_storage_retire(
    source: str,
    material_id: int,
    request: AdminMaterialStorageRetireRequest,
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    try:
        return retire_material(
            db,
            source=source,
            material_id=material_id,
            actor=current_user,
            reason=request.reason,
        )
    except ValueError as exception:
        message = str(exception)
        raise HTTPException(
            status_code=(
                status.HTTP_404_NOT_FOUND
                if message == "Materiale non trovato."
                else status.HTTP_400_BAD_REQUEST
            ),
            detail=message,
        )


@router.post("/{source}/{material_id}/delete-blob")
async def admin_material_storage_delete_blob(
    source: str,
    material_id: int,
    request: AdminMaterialStorageDeleteBlobRequest,
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    try:
        return await delete_record_blob(
            db,
            source=source,
            material_id=material_id,
            actor=current_user,
            reason="Eliminazione file confermata dall'amministrazione.",
        )
    except ValueError as exception:
        message = str(exception)
        raise HTTPException(
            status_code=(
                status.HTTP_404_NOT_FOUND
                if message == "Materiale non trovato."
                else status.HTTP_400_BAD_REQUEST
            ),
            detail=message,
        )


@router.patch('/public/{material_id}/visibility')
def admin_public_visibility(
    material_id: int, request: AdminPublicVisibilityRequest,
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    try:
        return set_public_visibility(db, material_id=material_id,
            state=request.state, actor=current_user)
    except ValueError as exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exception))


@router.patch('/public/{material_id}/audience')
def admin_public_audience(
    material_id: int, request: AdminPublicAudienceRequest,
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    try:
        return set_public_audience(db, material_id=material_id,
            audience_type=request.audience_type,
            audience_id=request.audience_id, actor=current_user)
    except ValueError as exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exception))


@router.patch('/public/{material_id}/placement')
def admin_place_public_material(
    material_id: int,
    request: AdminPlacePublicMaterialRequest,
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    try:
        return place_public_file(db, material_id=material_id,
            subject_id=request.subject_id, path=request.path_segments,
            actor=current_user)
    except ValueError as exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exception))


@router.post('/folders/move')
def admin_move_public_folder(
    request: AdminMovePublicFolderRequest,
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    try:
        return move_public_folder(db, source_subject_id=request.source_subject_id,
            source_path=request.source_path,
            destination_subject_id=request.destination_subject_id,
            destination_path=request.destination_path, actor=current_user)
    except ValueError as exception:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exception))


@router.get("/cleanup/dry-run")
async def admin_material_storage_cleanup_dry_run(
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    return await cleanup_dry_run(db)


@router.post("/cleanup/execute")
async def admin_material_storage_cleanup_execute(
    request: AdminMaterialStorageCleanupRequest,
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    return await execute_cleanup(
        db,
        actor=current_user,
        rejected_publications=request.rejected_publications,
        removed_materials=request.removed_materials,
        orphan_blobs=request.orphan_blobs,
    )


class AdminUploadPublishRequest(BaseModel):
    """Pubblicazione di un file caricato dall'admin (vedi "Carica materiale")."""
    destination: str = Field(pattern='^(dispense|drive_only)$')
    title: str | None = Field(default=None, max_length=250)
    path_segments: list[str] = Field(default_factory=list)
    audience_type: str = 'course'
    audience_id: int | None = None
    drive_path_segments: list[str] | None = None
    allow_drive_duplicate: bool = False
    # Richiesta degli studenti a StudentLab da chiudere con questo file.
    answer_request_id: int | None = None
    answer_message: str | None = Field(default=None, max_length=3000)


@router.post('/uploads/{request_id}/publish')
async def publish_admin_upload(request_id: int, request: AdminUploadPublishRequest,
        current_user: User = Depends(get_admin_user), db: Session = Depends(get_db)):
    """Pubblica un file che l'admin ha caricato con il flusso di proposta
    (verifica hash e duplicati già fatte al caricamento).

    - "dispense": visibile agli studenti scelti, nella cartella indicata;
    - "drive_only": copiato su Drive ma nascosto agli studenti finché non lo
      si mostra dal Catalogo Drive.
    Posizione, destinatari e visibilità vengono impostati prima che il file
    diventi visibile: con Drive attivo il materiale resta nascosto fino al
    termine della copia.
    """
    publication = get_publication_request_by_id(db, request_id)
    if publication is None or publication.status != 'pending' or publication.user_id != current_user.id:
        raise HTTPException(404, 'Caricamento non trovato o già pubblicato.')
    subject = db.query(Subject).filter(Subject.id == publication.subject_id).first()
    if subject is None or not subject.is_active:
        raise HTTPException(400, 'Materia non disponibile.')
    try:
        path = catalog_path(request.path_segments)
    except ValueError as exc:
        raise HTTPException(400, str(exc)) from exc
    audience = request.audience_type
    if audience in {'public', 'course', 'subject'}:
        audience_id = None
    elif audience == 'user':
        if request.audience_id is None or not db.query(User.id).filter(
                User.id == request.audience_id, User.is_active.is_(True)).first():
            raise HTTPException(400, 'Studente destinatario non trovato.')
        audience_id = request.audience_id
    elif audience == 'group':
        if request.audience_id is None or not db.query(StudyGroup.id).filter(
                StudyGroup.id == request.audience_id, StudyGroup.subject_id == subject.id,
                StudyGroup.status == 'active').first():
            raise HTTPException(400, 'Gruppo destinatario non valido per questa materia.')
        audience_id = request.audience_id
    else:
        raise HTTPException(400, 'Destinatari non validi.')
    answer = None
    if request.answer_request_id is not None:
        answer = db.query(TeacherMaterialRequest).filter(
            TeacherMaterialRequest.id == request.answer_request_id,
            TeacherMaterialRequest.recipient_kind == 'studentlab').first()
        if answer is None or answer.status != 'pending':
            raise HTTPException(409, 'La richiesta da chiudere non è più aperta.')
        if answer.subject_id != subject.id:
            raise HTTPException(400, 'La richiesta riguarda un’altra materia.')

    drive_enabled = all((settings.drive_folder_id, settings.drive_client_id,
        settings.drive_client_secret, settings.drive_refresh_token))
    drive_path = clean_path(request.drive_path_segments if request.drive_path_segments
        is not None else default_path(publication))
    if drive_enabled:
        inspection = await preview_public_material(publication, drive_path)
        if any(item['same_folder'] and item['name'].casefold() ==
                publication.original_name.casefold() for item in inspection['conflicts']):
            raise HTTPException(409, 'Esiste un file omonimo nella cartella Drive scelta: scegli un altro percorso.')
        if inspection['conflicts'] and not request.allow_drive_duplicate:
            raise HTTPException(409, 'Possibile duplicato su Drive: controlla i file prima di pubblicare.')

    visible = request.destination == 'dispense'
    try:
        approved = approve_material_publication_request(db, publication_request=publication,
            current_admin=current_user, data=MaterialPublicationApproveRequest(
                approved_action='publish_new', force_anonymous=True,
                proposed_title=(request.title or None), admin_note='Caricato da StudentLab',
                drive_path_segments=drive_path, allow_drive_duplicate=request.allow_drive_duplicate))
    except ValueError as exc:
        db.rollback()
        raise HTTPException(400, str(exc)) from exc

    def apply_state(material):
        material.catalog_path_json = json.dumps(path, ensure_ascii=False)
        material.audience_type, material.audience_id = audience, audience_id
        if request.title:
            material.title = request.title.strip()[:250]
        if not material.drive_activation_pending:
            material.status = 'published' if visible else 'hidden'
            material.is_visible = visible
            material.visibility_state = 'visible' if visible else 'hidden'
        material.updated_at = utc_now()

    apply_state(approved)
    if approved.drive_activation_pending:
        approved.drive_path_json = json.dumps(drive_path, ensure_ascii=False)
        approved.drive_allow_duplicate = bool(request.allow_drive_duplicate)
    db.commit()

    drive_pending = bool(approved.drive_activation_pending)
    if drive_pending:
        try:
            drive_id = await copy_public_material(approved)
            approved.drive_file_id = drive_id
            approved.drive_copied_at = utc_now()
            approved.drive_activation_pending = False
            approved.drive_retry_after = None
            approved.status = 'published' if visible else 'hidden'
            approved.is_visible = visible
            approved.visibility_state = 'visible' if visible else 'hidden'
            approved.version = (approved.version or 1) + 1
            approved.updated_at = utc_now()
            record_storage_event(db, source='public', material_id=approved.id,
                action='drive_copied', actor_id=current_user.id, blob_path=approved.stored_name,
                original_name=approved.original_name, size=approved.size,
                details={'source': 'admin_upload', 'destination': request.destination}, commit=False)
            db.commit()
            drive_pending = False
            await retire_public_staging_blob_best_effort(db, approved, current_user.id)
        except Exception as exc:
            db.rollback()
            # Resta nascosto finché la copia su Drive non riesce (nuovo tentativo automatico).
            state = mark_retry(approved, exc)
            record_storage_event(db, source='public', material_id=approved.id,
                action='drive_copy_pending', actor_id=current_user.id,
                details={'state': state}, commit=True)

    if answer is not None:
        answer = db.query(TeacherMaterialRequest).filter(
            TeacherMaterialRequest.id == answer.id).with_for_update().first()
        if answer is not None and answer.status == 'pending':
            answer.status = 'fulfilled'
            answer.fulfilled_public_material_id = approved.id
            answer.staff_response = (request.answer_message or '').strip() or (
                'Abbiamo pubblicato il materiale richiesto: lo trovi nelle Dispense della materia.')
            answer.resolved_by = current_user.id
            answer.resolved_at = utc_now()
            answer.updated_at = answer.resolved_at
            create_notification(db, user_id=answer.student_user_id,
                notification_type='teacher_material_request_resolved',
                title='Richiesta di materiale soddisfatta', message=answer.staff_response,
                actor_user_id=current_user.id, resource_type='teacher_material_request',
                resource_id=answer.id, commit=False)
            db.commit()

    db.refresh(approved)
    return {'material_id': approved.id, 'visible': bool(approved.is_visible),
        'drive_file_id': approved.drive_file_id, 'drive_pending': drive_pending,
        'answered_request_id': answer.id if answer is not None else None}
