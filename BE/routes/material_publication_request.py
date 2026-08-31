from pathlib import Path
from uuid import uuid4

from pydantic import (
    BaseModel,
)

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
        "possible_duplicate": (
            duplicate is not None
        ),
        "possible_duplicate_material_id": (
            duplicate.id
            if duplicate is not None
            else None
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


@router.post(
    "/admin/material_publications/{request_id}/approve",
    response_model=
        PublicMaterialAdminResponse,
)
def api_admin_approve_material_publication(
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

    try:
        return (
            approve_material_publication_request(
                db,
                publication_request=(
                    publication_request
                ),
                current_admin=current_user,
                data=request,
            )
        )

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