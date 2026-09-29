"""Catalog changes are private to an admin until one atomic publication."""
import hashlib
import json
from datetime import datetime, timezone
from types import SimpleNamespace

from sqlalchemy.orm import Session
import httpx

from models.group import StudyGroup
from models.material_catalog_draft import (
    MaterialCatalogDraft, MaterialCatalogFolder, MaterialCatalogImportDraft,
)
from models.public_material import PublicMaterial
from models.subject import Subject
from models.user import User
from services.admin_material_storage import record_storage_event
from services.public_material_access import can_read_public_material
from core.config import settings
from services.drive_material_catalog import FOLDER_MIME, verify_under_root
from services.drive_material_storage import _access_token, _session


def _path(parts):
    if not isinstance(parts, list) or len(parts) > 8 or any(
        not isinstance(part, str) or not part.strip() or len(part.strip()) > 80
        or part.strip() in {'.', '..'} or '/' in part or '\\' in part
        for part in parts
    ):
        raise ValueError('Percorso non valido (massimo otto cartelle).')
    return [part.strip() for part in parts]


def _validate(db, *, material, subject_id, path, state, audience, audience_id):
    subject = db.query(Subject).filter(Subject.id == subject_id,
        Subject.is_active.is_(True)).first()
    if subject is None:
        raise ValueError('Materia di destinazione non disponibile.')
    path = _path(path)
    if state not in {'visible', 'hidden', 'in_review', 'archived'}:
        raise ValueError('Visibilità non valida.')
    if state == 'visible' and not material.drive_file_id and (
        material.drive_activation_pending or (
            settings.drive_client_id and settings.drive_client_secret and settings.drive_refresh_token
        )
    ):
        raise ValueError('Completa prima il caricamento su Drive.')
    if audience in {'public', 'course', 'subject'}:
        if audience_id is not None:
            raise ValueError('Questo destinatario non richiede un ID.')
    elif audience == 'group':
        if material.subject_id != subject.id or not db.query(StudyGroup.id).filter(
            StudyGroup.id == audience_id, StudyGroup.subject_id == subject.id,
            StudyGroup.status == 'active').first():
            raise ValueError('Il gruppo deve appartenere alla materia selezionata.')
    elif audience == 'user':
        if audience_id is None or not db.query(User.id).filter(
            User.id == audience_id, User.is_active.is_(True)).first():
            raise ValueError('Studente destinatario non trovato.')
    else:
        raise ValueError('Destinatario non valido.')
    return subject, path


def _serialize(draft):
    return {'material_id': draft.material_id, 'base_version': draft.base_version,
        'subject_id': draft.subject_id, 'path_segments': json.loads(draft.path_json),
        'visibility_state': draft.visibility_state, 'audience_type': draft.audience_type,
        'audience_id': draft.audience_id, 'updated_at': draft.updated_at.isoformat()}


def list_drafts(db, admin_id):
    return [_serialize(d) for d in db.query(MaterialCatalogDraft).filter(
        MaterialCatalogDraft.admin_id == admin_id).order_by(MaterialCatalogDraft.id).all()]


def list_folders(db, admin_id):
    return [{'id': f.id, 'subject_id': f.subject_id,
        'path_segments': json.loads(f.path_json),
        'visibility_state': f.visibility_state,
        'draft': f.draft_admin_id is not None}
        for f in db.query(MaterialCatalogFolder).filter(
            (MaterialCatalogFolder.draft_admin_id.is_(None)) |
            (MaterialCatalogFolder.draft_admin_id == admin_id)).all()]


def stage_folder(db, admin_id, subject_id, path):
    path = _path(path)
    if not path or db.query(Subject.id).filter(Subject.id == subject_id,
            Subject.is_active.is_(True)).first() is None:
        raise ValueError('Indica una materia e un percorso valido.')
    encoded = json.dumps(path, ensure_ascii=False)
    existing = db.query(MaterialCatalogFolder).filter(
        MaterialCatalogFolder.subject_id == subject_id,
        MaterialCatalogFolder.path_json == encoded).first()
    if existing:
        if existing.draft_admin_id not in (None, admin_id):
            raise ValueError('La cartella è in modifica da un altro amministratore.')
        return {'id': existing.id, 'path_segments': path,
            'draft': existing.draft_admin_id is not None}
    folder = MaterialCatalogFolder(subject_id=subject_id, path_json=encoded,
        visibility_state='visible', draft_admin_id=admin_id,
        updated_at=datetime.now(timezone.utc))
    db.add(folder)
    db.commit()
    return {'id': folder.id, 'path_segments': path, 'draft': True}


def list_imports(db, admin_id):
    return [{'id': d.id, 'drive_file_id': d.drive_file_id,
        'subject_id': d.subject_id, 'path_segments': json.loads(d.path_json),
        'audience_type': d.audience_type, 'audience_id': d.audience_id,
        'name': d.original_name, 'size': d.size, 'mime_type': d.mime_type}
        for d in db.query(MaterialCatalogImportDraft).filter(
            MaterialCatalogImportDraft.admin_id == admin_id).all()]


async def stage_drive_import(db, *, admin_id, file_id, subject_id, path,
        audience, audience_id, allow_duplicate=False):
    if not file_id or len(file_id) > 128:
        raise ValueError('File Drive non valido.')
    path = _path(path)
    subject = db.query(Subject).filter(Subject.id == subject_id,
        Subject.is_active.is_(True)).first()
    if subject is None:
        raise ValueError('Materia di destinazione non disponibile.')
    if audience in {'public', 'course', 'subject'}:
        if audience_id is not None:
            raise ValueError('Destinatario non valido.')
    elif audience == 'group':
        if not db.query(StudyGroup.id).filter(StudyGroup.id == audience_id,
                StudyGroup.subject_id == subject_id, StudyGroup.status == 'active').first():
            raise ValueError('Gruppo non valido per la materia.')
    elif audience == 'user':
        if audience_id is None or not db.query(User.id).filter(
                User.id == audience_id, User.is_active.is_(True)).first():
            raise ValueError('Studente destinatario non trovato.')
    else:
        raise ValueError('Destinatario non valido.')
    async with await _session() as client:
        headers = {'Authorization': f'Bearer {await _access_token(client)}'}
        entry = await verify_under_root(client, headers, file_id)
    name = str(entry.get('name') or '')[:255]
    mime = str(entry.get('mimeType') or '')[:150]
    size = int(entry.get('size') or 0)
    if not name or mime == FOLDER_MIME or mime.startswith('application/vnd.google-apps.'):
        raise ValueError('Seleziona un file scaricabile da Drive.')
    if not 0 < size <= 20 * 1024 * 1024:
        raise ValueError('Importazione diretta disponibile per file fino a 20 MB.')
    if db.query(PublicMaterial.id).filter(PublicMaterial.drive_file_id == file_id).first():
        raise RuntimeError('Questo file Drive è già presente nello storico del catalogo.')
    matches = db.query(PublicMaterial).filter(
        PublicMaterial.subject_id == subject_id,
        PublicMaterial.original_name == name,
        PublicMaterial.size == size,
        PublicMaterial.status != 'removed').limit(5).all()
    if matches and not allow_duplicate:
        return {'conflicts': [{'id': m.id, 'name': m.original_name,
            'path_segments': json.loads(m.catalog_path_json or '[]'),
            'size': m.size} for m in matches],
            'incoming': {'name': name, 'path_segments': path, 'size': size}}
    draft = db.query(MaterialCatalogImportDraft).filter(
        MaterialCatalogImportDraft.admin_id == admin_id,
        MaterialCatalogImportDraft.drive_file_id == file_id).first()
    if draft is None:
        draft = MaterialCatalogImportDraft(admin_id=admin_id, drive_file_id=file_id)
        db.add(draft)
    draft.subject_id, draft.path_json = subject_id, json.dumps(path, ensure_ascii=False)
    draft.audience_type, draft.audience_id = audience, audience_id
    draft.original_name, draft.mime_type, draft.size = name, mime, size
    draft.allow_duplicate = allow_duplicate
    draft.updated_at = datetime.now(timezone.utc)
    db.commit()
    return {'staged': True, 'file_id': file_id}


def stage(db, *, admin_id, material_id, subject_id, path, state, audience, audience_id):
    material = db.query(PublicMaterial).filter(PublicMaterial.id == material_id,
        PublicMaterial.status != 'removed').first()
    if material is None:
        raise ValueError('Materiale non disponibile.')
    _, cleaned = _validate(db, material=material, subject_id=subject_id,
        path=path, state=state, audience=audience, audience_id=audience_id)
    draft = db.query(MaterialCatalogDraft).filter(
        MaterialCatalogDraft.admin_id == admin_id,
        MaterialCatalogDraft.material_id == material_id).first()
    if draft is not None and material.version != draft.base_version:
        raise RuntimeError('Il materiale è stato modificato. Scarta la bozza e ricarica il catalogo.')
    if draft is None:
        draft = MaterialCatalogDraft(admin_id=admin_id, material_id=material_id,
            base_version=material.version or 1)
        db.add(draft)
    draft.subject_id = subject_id
    draft.path_json = json.dumps(cleaned, ensure_ascii=False)
    draft.visibility_state = state
    draft.audience_type = audience
    draft.audience_id = audience_id
    draft.updated_at = datetime.now(timezone.utc)
    db.commit()
    return _serialize(draft)


def discard(db, admin_id):
    count = db.query(MaterialCatalogDraft).filter(
        MaterialCatalogDraft.admin_id == admin_id).delete(synchronize_session=False)
    count += db.query(MaterialCatalogFolder).filter(
        MaterialCatalogFolder.draft_admin_id == admin_id).delete(synchronize_session=False)
    count += db.query(MaterialCatalogImportDraft).filter(
        MaterialCatalogImportDraft.admin_id == admin_id).delete(synchronize_session=False)
    db.commit()
    return {'discarded': count}


async def publish(db, actor):
    # Lock all draft rows, then lock each affected file. A stale version aborts
    # the entire transaction; no partial publication or Drive byte moves.
    drafts = db.query(MaterialCatalogDraft).filter(
        MaterialCatalogDraft.admin_id == actor.id).order_by(
        MaterialCatalogDraft.material_id).with_for_update().all()
    folders = db.query(MaterialCatalogFolder).filter(
        MaterialCatalogFolder.draft_admin_id == actor.id).with_for_update().all()
    imports = db.query(MaterialCatalogImportDraft).filter(
        MaterialCatalogImportDraft.admin_id == actor.id).with_for_update().all()
    if not (drafts or folders or imports):
        return {'published': 0}
    prepared = []
    prepared_hashes = set()
    if imports:
        async with await _session() as client:
            headers = {'Authorization': f'Bearer {await _access_token(client)}'}
            for entry in imports:
                live = await verify_under_root(client, headers, entry.drive_file_id)
                if (live.get('name') != entry.original_name or
                    int(live.get('size') or 0) != entry.size or
                    live.get('mimeType') != entry.mime_type):
                    raise RuntimeError('Il file Drive è cambiato dopo la bozza. Aggiorna la proposta.')
                if db.query(PublicMaterial.id).filter(
                    PublicMaterial.drive_file_id == entry.drive_file_id).first():
                    raise RuntimeError('Un file Drive della bozza è già presente nello storico.')
                digest = hashlib.sha256()
                count = 0
                try:
                    async with client.stream('GET',
                            f'https://www.googleapis.com/drive/v3/files/{entry.drive_file_id}',
                            headers=headers, params={'alt': 'media',
                                'supportsAllDrives': 'true'}) as response:
                        response.raise_for_status()
                        async for chunk in response.aiter_bytes():
                            count += len(chunk)
                            if count > 20 * 1024 * 1024:
                                raise RuntimeError('Il file Drive supera il limite di 20 MB.')
                            digest.update(chunk)
                except httpx.HTTPError as exc:
                    raise RuntimeError('Impossibile verificare il file su Drive.') from exc
                if count != entry.size:
                    raise RuntimeError('La dimensione del file Drive è cambiata.')
                duplicate = db.query(PublicMaterial.id).filter(
                    PublicMaterial.subject_id == entry.subject_id,
                    PublicMaterial.file_hash == digest.hexdigest(),
                    PublicMaterial.status != 'removed').first()
                if duplicate and not entry.allow_duplicate:
                    raise RuntimeError('File identico già pubblicato: controlla i duplicati prima di pubblicare.')
                fingerprint = (entry.subject_id, digest.hexdigest())
                if fingerprint in prepared_hashes and not entry.allow_duplicate:
                    raise RuntimeError('La bozza contiene due file identici per la stessa materia.')
                prepared_hashes.add(fingerprint)
                subject = db.query(Subject).filter(Subject.id == entry.subject_id,
                    Subject.is_active.is_(True)).first()
                if subject is None:
                    raise RuntimeError('Una materia della bozza non è più disponibile.')
                prepared.append((entry, subject, digest.hexdigest()))
    materials = {}
    subjects = {}
    for draft in drafts:
        material = db.query(PublicMaterial).filter(
            PublicMaterial.id == draft.material_id).with_for_update().first()
        if material is None or material.status == 'removed' or (
            material.version or 1) != draft.base_version:
            raise RuntimeError('Un file è cambiato dopo la bozza. Ricarica prima di pubblicare.')
        subject, _ = _validate(db, material=material,
            subject_id=draft.subject_id, path=json.loads(draft.path_json),
            state=draft.visibility_state, audience=draft.audience_type,
            audience_id=draft.audience_id)
        materials[draft.material_id] = material
        subjects[draft.material_id] = subject
    now = datetime.now(timezone.utc)
    for folder in folders:
        if db.query(Subject.id).filter(Subject.id == folder.subject_id,
                Subject.is_active.is_(True)).first() is None:
            raise RuntimeError('Una materia delle cartelle non è più disponibile.')
        _path(json.loads(folder.path_json))
        folder.draft_admin_id = None
        folder.updated_at = now
    for entry, subject, digest in prepared:
        row = PublicMaterial(subject_id=subject.id, uploaded_by=None,
            university=subject.university, university_code=subject.university_code or '',
            department=subject.department, department_code=subject.department_code or '',
            course=subject.course, course_code=subject.course_code or '',
            title=entry.original_name[:250], original_name=entry.original_name,
            stored_name=f'drive-import/{entry.drive_file_id}',
            file_path=f'drive://{entry.drive_file_id}',
            catalog_path_json=entry.path_json, mime_type=entry.mime_type,
            size=entry.size, file_hash=digest, drive_file_id=entry.drive_file_id,
            drive_copied_at=now, audience_type=entry.audience_type,
            audience_id=entry.audience_id, status='published', is_visible=True,
            visibility_state='visible', approved_by=actor.id, approved_at=now,
            contributor_mode='anonymous')
        db.add(row)
        db.delete(entry)
    for draft in drafts:
        material = materials[draft.material_id]
        subject = subjects[draft.material_id]
        before = {'subject_id': material.subject_id,
            'path_segments': json.loads(material.catalog_path_json or '[]'),
            'visibility_state': material.visibility_state,
            'audience_type': material.audience_type, 'audience_id': material.audience_id}
        material.subject_id = subject.id
        material.university, material.university_code = subject.university, subject.university_code
        material.department, material.department_code = subject.department, subject.department_code or ''
        material.course, material.course_code = subject.course, subject.course_code or ''
        material.catalog_path_json = draft.path_json
        material.visibility_state = draft.visibility_state
        material.status = 'published' if draft.visibility_state == 'visible' else 'hidden'
        material.is_visible = draft.visibility_state == 'visible'
        if not material.is_visible:
            material.drive_activation_pending = False
        material.audience_type = draft.audience_type
        material.audience_id = draft.audience_id
        material.version = (material.version or 1) + 1
        material.updated_at = now
        record_storage_event(db, source='public', material_id=material.id,
            action='catalog_published', actor_id=actor.id, blob_path=material.stored_name,
            original_name=material.original_name, size=material.size,
            details={'previous': before, 'subject_id': subject.id,
                'path_segments': json.loads(draft.path_json),
                'visibility_state': draft.visibility_state,
                'audience_type': draft.audience_type, 'audience_id': draft.audience_id},
            commit=False)
        db.delete(draft)
    try:
        db.commit()
    except Exception:
        db.rollback()
        raise
    return {'published': len(drafts) + len(folders) + len(imports)}


def preview(db, *, admin_id, user_id=None):
    drafts = {d.material_id: d for d in db.query(MaterialCatalogDraft).filter(
        MaterialCatalogDraft.admin_id == admin_id).all()}
    result = []
    for row in db.query(PublicMaterial).filter(PublicMaterial.status != 'removed').all():
        draft = drafts.get(row.id)
        # An ORM shallow copy shares SQLAlchemy instrumentation with the live
        # row and can accidentally flush preview changes. Use detached values.
        projected = SimpleNamespace(**{
            column.key: getattr(row, column.key)
            for column in PublicMaterial.__table__.columns
        }) if draft is not None else row
        if draft is not None:
            projected.subject_id = draft.subject_id
            projected.catalog_path_json = draft.path_json
            projected.visibility_state = draft.visibility_state
            projected.audience_type = draft.audience_type
            projected.audience_id = draft.audience_id
            projected.status = 'published' if draft.visibility_state == 'visible' else 'hidden'
            projected.is_visible = draft.visibility_state == 'visible'
            projected.subject = db.query(Subject).filter(Subject.id == draft.subject_id).first()
        allowed = bool(projected.status == 'published' and projected.is_visible and
            can_read_public_material(db, projected, user_id))
        result.append({'id': row.id, 'subject_id': projected.subject_id,
            'title': row.title, 'path_segments': json.loads(projected.catalog_path_json or '[]'),
            'audience_type': projected.audience_type, 'visibility_state': projected.visibility_state,
            'allowed': allowed, 'draft': draft is not None,
            'reason': 'Visibile' if allowed else 'Nascosto o fuori dai destinatari'})
    # Pending imports are not present in public_materials yet. Test their
    # prospective audience through the same access policy used at download.
    for entry in db.query(MaterialCatalogImportDraft).filter(
            MaterialCatalogImportDraft.admin_id == admin_id).all():
        subject = db.query(Subject).filter(Subject.id == entry.subject_id).first()
        projected = SimpleNamespace(**{
            column.key: None for column in PublicMaterial.__table__.columns
        })
        projected.subject_id, projected.subject = entry.subject_id, subject
        projected.audience_type, projected.audience_id = entry.audience_type, entry.audience_id
        projected.status, projected.is_visible = 'published', True
        projected.visibility_state = 'visible'
        allowed = bool(can_read_public_material(db, projected, user_id))
        result.append({'id': None, 'subject_id': entry.subject_id,
            'title': entry.original_name, 'path_segments': json.loads(entry.path_json),
            'audience_type': entry.audience_type, 'visibility_state': 'visible',
            'allowed': allowed, 'draft': True,
            'reason': 'Visibile' if allowed else 'Fuori dai destinatari'})
    return {'viewer': 'guest' if user_id is None else 'student', 'user_id': user_id,
        'files': result, 'folders': list_folders(db, admin_id)}
