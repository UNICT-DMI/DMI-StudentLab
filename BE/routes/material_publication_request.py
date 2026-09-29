from pathlib import Path
from uuid import uuid4
import json

from pydantic import (
    BaseModel,
)

from services.public_material_access import can_read_public_material
from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
)

from sqlalchemy.exc import (
    IntegrityError,
)

from sqlalchemy.orm import (
    Session,
)

from core.database import (
    get_db,
)

from core.security import (
    get_admin_user,
    get_current_user,
)

from models.user import (
    User,
)
from models.material_publication_request import MaterialPublicationRequest

from schemas.material_publication_request import (
    MaterialDuplicateReviewRequest,
    MaterialPublicationApproveRequest,
    MaterialPublicationCompleteRequest,
    MaterialPublicationRequestAdminResponse,
    MaterialPublicationRequestResponse,
    MaterialPublicationRejectRequest,
    MaterialPublicationUploadRequest,
)

from schemas.public_material import (
    PublicMaterialAdminResponse,
)

from services.material_publication_request import (
    MAX_PUBLIC_MATERIAL_SIZE,
    approve_material_publication_request,
    create_material_publication_request,
    find_duplicate_candidate,
    get_pending_publication_requests,
    get_publication_request_by_id,
    get_publication_requests,
    get_subject_for_publication,
    get_user_publication_requests,
    reject_material_publication_request,
    review_material_duplicate,
    validate_publication_material_mime_type,
    validate_publication_material_size,
)

from services.private_blob import (
    private_blob_response,
    verify_private_blob,
)

from services.public_material import (
    get_public_material_by_id,
)
from core.config import settings
from services.drive_material_catalog import clean_path, default_path
from services.drive_material_storage import copy_public_material, preview_public_material, mark_retry, public_drive_response
from services.admin_material_storage import record_storage_event, utc_now
from services.public_drive_blob_retirement import retire_public_staging_blob_best_effort

from services.upload_authorization import (
    create_upload_authorization,
    decode_upload_authorization,
    require_upload_authorization_fields,
    require_upload_authorization_type,
    require_upload_authorization_user,
)


router = APIRouter()


class MaterialPublicationVerifyRequest(BaseModel):
    subject_id: int
    pathname: str
    mime_type: str
    size: int
    file_hash: str
    upload_token: str



def generate_publication_stored_name(
    user_id: int,
    original_name: str,
):
    extension = (
        Path(
            original_name,
        )
        .suffix
        .lower()
    )

    return (
        "material-publication/"
        f"{user_id}/"
        f"{uuid4().hex}"
        f"{extension}"
    )


def validate_publication_storage_path(
    *,
    user_id: int,
    stored_name: str,
):
    expected_prefix = (
        f"material-publication/{user_id}/"
    )

    if not stored_name.startswith(
        expected_prefix,
    ):
        raise ValueError(
            "Percorso del materiale non valido.",
        )


@router.post(
    "/material_publication/upload-request",
)
def api_material_publication_upload_request(
    request: MaterialPublicationUploadRequest,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    subject = get_subject_for_publication(
        db,
        request.subject_id,
    )

    if subject is None:
        raise HTTPException(
            status_code=404,
            detail="Materia non trovata.",
        )

    try:
        validate_publication_material_size(
            request.size,
        )

        mime_type = (
            request.mime_type
            .strip()
            .lower()
        )

        validate_publication_material_mime_type(
            mime_type,
        )

        original_name = (
            request.original_name
            .strip()
        )

        if not original_name:
            raise ValueError(
                "Nome del file non valido.",
            )

        file_hash = (
            request.file_hash
            .strip()
            .lower()
        )

        if (
            len(file_hash) != 64
            or not all(
                char in "0123456789abcdef"
                for char in file_hash
            )
        ):
            raise ValueError(
                "Hash del file non valido.",
            )

    except ValueError as exception:
        raise HTTPException(
            status_code=400,
            detail=str(exception),
        ) from exception

    duplicate = find_duplicate_candidate(
        db,
        subject_id=request.subject_id,
        original_name=original_name,
        size=request.size,
        file_hash=file_hash,
    )

    visible_duplicate = (
        duplicate
        if duplicate is not None
        and can_read_public_material(db, duplicate, current_user.id)
        else None
    )

    stored_name = (
        generate_publication_stored_name(
            current_user.id,
            original_name,
        )
    )

    payload = {
        "v": 1,
        "type": "material_publication",
        "uid": current_user.id,
        "subject_id": request.subject_id,
        "pathname": stored_name,
        "mime_type": mime_type,
        "size": request.size,
        "file_hash": file_hash,
    }

    try:
        (
            upload_token,
            expires_at,
        ) = create_upload_authorization(
            payload,
        )
    except RuntimeError as exception:
        raise HTTPException(
            status_code=503,
            detail=(
                "Il servizio di caricamento "
                "non è disponibile."
            ),
        ) from exception

    return {
        "allowed": True,
        "pathname": stored_name,
        "mime_type": mime_type,
        "size": request.size,
        "file_hash": file_hash,
        "max_file_size": MAX_PUBLIC_MATERIAL_SIZE,
        "upload_token": upload_token,
        "valid_until": expires_at * 1000,
        # Il duplicato viene segnalato allo studente solo se è un materiale
        # che può già leggere: altrimenti la risposta rivelerebbe l'esistenza
        # di file nascosti o riservati. La revisione admin lo rileva comunque.
        "possible_duplicate": visible_duplicate is not None,
        "possible_duplicate_material_id": (
            visible_duplicate.id if visible_duplicate is not None else None
        ),
        "possible_duplicate_exact": bool(
            visible_duplicate is not None
            and (visible_duplicate.file_hash or "").lower() == file_hash
        ),
        "possible_duplicate_title": (
            visible_duplicate.title if visible_duplicate is not None else None
        ),
        "possible_duplicate_path": (
            json.loads(visible_duplicate.catalog_path_json or "[]")
            if visible_duplicate is not None else None
        ),
    }


@router.post(
    "/material_publication/verify-upload",
)
def api_material_publication_verify_upload(
    request: MaterialPublicationVerifyRequest,
    current_user: User = Depends(
        get_current_user,
    ),
):
    try:
        payload = decode_upload_authorization(
            request.upload_token,
        )

        require_upload_authorization_type(
            payload,
            "material_publication",
        )

        require_upload_authorization_user(
            payload,
            current_user.id,
        )

        pathname = (
            request.pathname
            .strip()
        )

        validate_publication_storage_path(
            user_id=current_user.id,
            stored_name=pathname,
        )

        mime_type = (
            request.mime_type
            .strip()
            .lower()
        )

        validate_publication_material_mime_type(
            mime_type,
        )

        validate_publication_material_size(
            request.size,
        )

        file_hash = (
            request.file_hash
            .strip()
            .lower()
        )

        if (
            len(file_hash) != 64
            or not all(
                char in "0123456789abcdef"
                for char in file_hash
            )
        ):
            raise ValueError(
                "Hash del file non valido.",
            )

        require_upload_authorization_fields(
            payload,
            {
                "subject_id":
                    request.subject_id,
                "pathname":
                    pathname,
                "mime_type":
                    mime_type,
                "size":
                    request.size,
                "file_hash":
                    file_hash,
            },
        )

        return {
            "allowed": True,
            "subject_id":
                request.subject_id,
            "pathname":
                pathname,
            "mime_type":
                mime_type,
            "size":
                request.size,
            "file_hash":
                file_hash,
            "valid_until":
                int(
                    payload[
                        "exp"
                    ]
                )
                * 1000,
        }

    except RuntimeError as exception:
        raise HTTPException(
            status_code=503,
            detail=(
                "Il servizio di caricamento "
                "non è disponibile."
            ),
        ) from exception

    except ValueError as exception:
        raise HTTPException(
            status_code=400,
            detail=str(exception),
        ) from exception


@router.post(
    "/material_publication/complete",
    response_model=
        MaterialPublicationRequestResponse,
)
async def api_material_publication_complete(
    request:
        MaterialPublicationCompleteRequest,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    try:
        validate_publication_storage_path(
            user_id=current_user.id,
            stored_name=request.stored_name,
        )

        validate_publication_material_size(
            request.size,
        )

        validate_publication_material_mime_type(
            request.mime_type,
        )

        await verify_private_blob(
            stored_name=(
                request.stored_name
            ),
            expected_size=(
                request.size
            ),
            expected_mime_type=(
                request.mime_type
            ),
            expected_sha256=(
                request.file_hash
            ),
        )

        publication_request = (
            create_material_publication_request(
                db,
                current_user=current_user,
                data=request,
            )
        )

        return publication_request

    except PermissionError as exception:
        raise HTTPException(
            status_code=403,
            detail=str(
                exception,
            ),
        )

    except ValueError as exception:
        message = str(
            exception,
        )

        status_code = (
            404
            if message ==
            "Materia non trovata."
            else 400
        )

        raise HTTPException(
            status_code=status_code,
            detail=message,
        )

    except IntegrityError:
        db.rollback()

        raise HTTPException(
            status_code=409,
            detail=(
                "Impossibile creare la richiesta "
                "di pubblicazione."
            ),
        )


@router.get(
    "/material_publication/me",
    response_model=list[
        MaterialPublicationRequestResponse
    ],
)
def api_my_material_publication_requests(
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return get_user_publication_requests(
        db,
        current_user.id,
    )


@router.get(
    "/material_publication/me/{request_id}",
    response_model=
        MaterialPublicationRequestResponse,
)
def api_my_material_publication_request(
    request_id: int,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    publication_request = (
        get_publication_request_by_id(
            db,
            request_id,
        )
    )

    if publication_request is None:
        raise HTTPException(
            status_code=404,
            detail="Richiesta non trovata.",
        )

    if (
        publication_request.user_id !=
        current_user.id
    ):
        raise HTTPException(
            status_code=404,
            detail="Richiesta non trovata.",
        )

    return publication_request


@router.get(
    "/admin/material_publications",
    response_model=list[
        MaterialPublicationRequestAdminResponse
    ],
)
def api_admin_material_publications(
    status: str | None = None,
    current_user: User = Depends(
        get_admin_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    if (
        status is not None
        and status not in [
            "pending",
            "approved",
            "rejected",
        ]
    ):
        raise HTTPException(
            status_code=400,
            detail=(
                "Stato della richiesta non valido."
            ),
        )

    return get_publication_requests(
        db,
        status=status,
    )


@router.get(
    "/admin/material_publications/pending",
    response_model=list[
        MaterialPublicationRequestAdminResponse
    ],
)
def api_admin_pending_material_publications(
    current_user: User = Depends(
        get_admin_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return get_pending_publication_requests(
        db,
    )


@router.get(
    "/admin/material_publications/{request_id}",
    response_model=
        MaterialPublicationRequestAdminResponse,
)
def api_admin_material_publication_request(
    request_id: int,
    current_user: User = Depends(
        get_admin_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    publication_request = (
        get_publication_request_by_id(
            db,
            request_id,
        )
    )

    if publication_request is None:
        raise HTTPException(
            status_code=404,
            detail="Richiesta non trovata.",
        )

    return publication_request


@router.get(
    "/admin/material_publications/{request_id}/file",
)
async def api_admin_material_publication_file(
    request_id: int,
    current_user: User = Depends(
        get_admin_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    publication_request = (
        get_publication_request_by_id(
            db,
            request_id,
        )
    )

    if publication_request is None:
        raise HTTPException(
            status_code=404,
            detail="Richiesta non trovata.",
        )

    if publication_request.status == 'approved' and publication_request.approved_public_material_id:
        material = get_public_material_by_id(db, publication_request.approved_public_material_id)
        if (material is not None and material.drive_file_id and
                material.stored_name == publication_request.stored_name):
            return await public_drive_response(drive_file_id=material.drive_file_id,
                original_name=material.original_name, mime_type=material.mime_type,
                inline=True)

    return await private_blob_response(
        stored_name=(
            publication_request.stored_name
        ),
        original_name=(
            publication_request.original_name
        ),
        mime_type=(
            publication_request.mime_type
        ),
        inline=True,
    )


@router.get(
    "/admin/material_publications/{request_id}/possible-duplicate",
    response_model=
        PublicMaterialAdminResponse,
)
def api_admin_possible_duplicate_material(
    request_id: int,
    current_user: User = Depends(
        get_admin_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    publication_request = (
        get_publication_request_by_id(
            db,
            request_id,
        )
    )

    if publication_request is None:
        raise HTTPException(
            status_code=404,
            detail="Richiesta non trovata.",
        )

    material_id = (
        publication_request
        .possible_duplicate_material_id
    )

    if material_id is None:
        raise HTTPException(
            status_code=404,
            detail="Nessun possibile duplicato.",
        )

    material = get_public_material_by_id(
        db,
        material_id,
    )

    if material is None:
        raise HTTPException(
            status_code=404,
            detail=(
                "Materiale duplicato non trovato."
            ),
        )

    return material


@router.get(
    "/admin/material_publications/{request_id}/possible-duplicate/file",
)
async def api_admin_possible_duplicate_material_file(
    request_id: int,
    current_user: User = Depends(
        get_admin_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    publication_request = (
        get_publication_request_by_id(
            db,
            request_id,
        )
    )

    if publication_request is None:
        raise HTTPException(
            status_code=404,
            detail="Richiesta non trovata.",
        )

    material_id = (
        publication_request
        .possible_duplicate_material_id
    )

    if material_id is None:
        raise HTTPException(
            status_code=404,
            detail="Nessun possibile duplicato.",
        )

    material = get_public_material_by_id(
        db,
        material_id,
    )

    if material is None:
        raise HTTPException(
            status_code=404,
            detail=(
                "Materiale duplicato non trovato."
            ),
        )

    if material.drive_file_id:
        return await public_drive_response(drive_file_id=material.drive_file_id,
            original_name=material.original_name, mime_type=material.mime_type,
            inline=True)

    return await private_blob_response(
        stored_name=(
            material.stored_name
        ),
        original_name=(
            material.original_name
        ),
        mime_type=(
            material.mime_type
        ),
        inline=True,
    )


@router.patch(
    "/admin/material_publications/{request_id}/duplicate",
    response_model=
        MaterialPublicationRequestAdminResponse,
)
def api_admin_review_material_duplicate(
    request_id: int,
    request:
        MaterialDuplicateReviewRequest,
    current_user: User = Depends(
        get_admin_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    publication_request = (
        get_publication_request_by_id(
            db,
            request_id,
        )
    )

    if publication_request is None:
        raise HTTPException(
            status_code=404,
            detail="Richiesta non trovata.",
        )

    try:
        return review_material_duplicate(
            db,
            publication_request=(
                publication_request
            ),
            current_admin=current_user,
            data=request,
        )

    except ValueError as exception:
        raise HTTPException(
            status_code=400,
            detail=str(
                exception,
            ),
        )


@router.post('/admin/material_publications/{request_id}/duplicate/recheck',
             response_model=MaterialPublicationRequestAdminResponse)
def api_admin_recheck_publication_duplicate(
    request_id: int, current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    proposal = db.query(MaterialPublicationRequest).filter(
        MaterialPublicationRequest.id == request_id).with_for_update().first()
    if proposal is None:
        raise HTTPException(404, 'Proposta non trovata.')
    if proposal.status != 'pending':
        return proposal
    fresh = find_duplicate_candidate(db, subject_id=proposal.subject_id,
        original_name=proposal.original_name, size=proposal.size,
        file_hash=proposal.file_hash)
    fresh_id = fresh.id if fresh else None
    fresh_status = ('confirmed' if fresh and fresh.file_hash == proposal.file_hash
        else 'suspected' if fresh else 'none')
    if (fresh_id != proposal.possible_duplicate_material_id or
            fresh_status != proposal.duplicate_status):
        proposal.possible_duplicate_material_id = fresh_id
        proposal.duplicate_status = fresh_status
        proposal.comparison_status = ('same_material' if fresh_status == 'confirmed'
            else 'pending' if fresh else 'not_required')
        db.commit()
        db.refresh(proposal)
    return proposal


@router.post(
    "/admin/material_publications/{request_id}/approve",
    response_model=
        PublicMaterialAdminResponse,
)
async def api_admin_approve_material_publication(
    request_id: int,
    request:
        MaterialPublicationApproveRequest,
    current_user: User = Depends(
        get_admin_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    publication_request = (
        get_publication_request_by_id(
            db,
            request_id,
        )
    )

    if publication_request is None:
        raise HTTPException(
            status_code=404,
            detail="Richiesta non trovata.",
        )

    drive_enabled = all((settings.drive_folder_id, settings.drive_client_id,
        settings.drive_client_secret, settings.drive_refresh_token))
    if drive_enabled and request.approved_action in {'publish_new', 'publish_separate'}:
        selected = clean_path(request.drive_path_segments if request.drive_path_segments
            is not None else default_path(publication_request))
        inspection = await preview_public_material(publication_request, selected)
        if any(item['same_folder'] and item['name'].casefold() ==
               publication_request.original_name.casefold() for item in inspection['conflicts']):
            raise HTTPException(409, 'Esiste un file omonimo nella cartella selezionata: scegli un altro percorso.')
        if inspection['conflicts'] and not request.allow_drive_duplicate:
            raise HTTPException(409, 'Possibile duplicato su Drive: confronta i file prima di approvare.')

    try:
        approved = (
            approve_material_publication_request(
                db,
                publication_request=(
                    publication_request
                ),
                current_admin=current_user,
                data=request,
            )
        )
        if approved.drive_activation_pending:
            if request.drive_path_segments is not None:
                approved.drive_path_json = json.dumps(clean_path(request.drive_path_segments), ensure_ascii=False)
            approved.drive_allow_duplicate = bool(request.allow_drive_duplicate)
            db.commit()
            try:
                drive_id = await copy_public_material(approved)
                approved.drive_file_id = drive_id
                approved.drive_copied_at = utc_now()
                approved.drive_activation_pending = False
                approved.drive_retry_after = None
                approved.status = 'published'
                approved.is_visible = True
                approved.visibility_state = 'visible'
                approved.version = (approved.version or 1) + 1
                approved.updated_at = utc_now()
                record_storage_event(db, source='public', material_id=approved.id,
                    action='drive_copied', actor_id=current_user.id,
                    blob_path=approved.stored_name, original_name=approved.original_name,
                    size=approved.size, details={'source': 'approval'}, commit=False)
                db.commit()
                await retire_public_staging_blob_best_effort(db, approved, current_user.id)
            except Exception as exc:
                db.rollback()
                # Approved and hidden until a later automatic retry or admin decision.
                state = mark_retry(approved, exc)
                record_storage_event(db, source='public', material_id=approved.id,
                    action='drive_copy_pending', actor_id=current_user.id,
                    details={'state': state}, commit=True)
            db.refresh(approved)
        return approved

    except ValueError as exception:
        message = str(
            exception,
        )

        status_code = (
            409
            if message in [
                (
                    "La richiesta ha già generato "
                    "un materiale pubblico."
                ),
                (
                    "Il materiale è stato confermato "
                    "come duplicato."
                ),
            ]
            else 400
        )

        raise HTTPException(
            status_code=status_code,
            detail=message,
        )

    except IntegrityError:
        db.rollback()

        raise HTTPException(
            status_code=409,
            detail=(
                "Impossibile pubblicare "
                "il materiale."
            ),
        )


@router.post('/admin/material_publications/{request_id}/drive-preview')
async def api_admin_preview_publication_drive(
    request_id: int, request: dict,
    current_user: User = Depends(get_admin_user), db: Session = Depends(get_db),
):
    publication = get_publication_request_by_id(db, request_id)
    if publication is None or publication.status != 'pending':
        raise HTTPException(404, 'Proposta in attesa non trovata.')
    path = request.get('path')
    selected = clean_path(path if path is not None else default_path(publication))
    return await preview_public_material(publication, selected)


@router.post(
    "/admin/material_publications/{request_id}/reject",
    response_model=
        MaterialPublicationRequestAdminResponse,
)
def api_admin_reject_material_publication(
    request_id: int,
    request:
        MaterialPublicationRejectRequest,
    current_user: User = Depends(
        get_admin_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    publication_request = (
        get_publication_request_by_id(
            db,
            request_id,
        )
    )

    if publication_request is None:
        raise HTTPException(
            status_code=404,
            detail="Richiesta non trovata.",
        )

    try:
        return (
            reject_material_publication_request(
                db,
                publication_request=(
                    publication_request
                ),
                current_admin=current_user,
                data=request,
            )
        )

    except ValueError as exception:
        raise HTTPException(
            status_code=400,
            detail=str(
                exception,
            ),
        )
