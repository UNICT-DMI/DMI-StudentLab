from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_current_user
from models.personal_material import PersonalSyncedMaterial
from models.user import User
from schemas.personal_material import (
    PersonalMaterialCompleteRequest,
    PersonalMaterialResponse,
    PersonalMaterialUploadRequest,
    PersonalMaterialVerifyRequest,
    PersonalMaterialVerifyResponse,
    PersonalRetentionAction,
)
from services.personal_material import (
    complete_personal_upload,
    prepare_personal_upload,
    process_personal_retention,
    retention_action,
    verify_personal_upload,
)
from services.private_blob import private_blob_response, verify_private_blob


router = APIRouter(
    prefix="/personal-materials",
    tags=["personal-materials"],
)


@router.post("/upload-request")
def upload_request(
    request: PersonalMaterialUploadRequest,
    current_user: User = Depends(get_current_user),
):
    try:
        return prepare_personal_upload(current_user, request)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post(
    "/verify-upload",
    response_model=PersonalMaterialVerifyResponse,
)
def verify_upload(
    request: PersonalMaterialVerifyRequest,
    current_user: User = Depends(get_current_user),
):
    try:
        return verify_personal_upload(current_user, request)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post(
    "/complete",
    response_model=PersonalMaterialResponse,
)
async def complete(
    request: PersonalMaterialCompleteRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        await verify_private_blob(
            stored_name=request.pathname,
            expected_size=request.size,
            expected_mime_type=request.mime_type,
            expected_sha256=request.file_hash,
        )
        return complete_personal_upload(db, current_user, request)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get(
    "",
    response_model=list[PersonalMaterialResponse],
)
def mine(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    process_personal_retention(db)
    return (
        db.query(PersonalSyncedMaterial)
        .filter(
            PersonalSyncedMaterial.owner_user_id == current_user.id,
            PersonalSyncedMaterial.status == "active",
        )
        .order_by(PersonalSyncedMaterial.updated_at.desc())
        .all()
    )


@router.get("/{material_id}/download")
async def download(
    material_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    record = (
        db.query(PersonalSyncedMaterial)
        .filter(
            PersonalSyncedMaterial.id == material_id,
            PersonalSyncedMaterial.owner_user_id == current_user.id,
            PersonalSyncedMaterial.status == "active",
        )
        .first()
    )
    if record is None:
        raise HTTPException(
            status_code=404,
            detail="Materiale personale non trovato.",
        )

    record.last_downloaded_at = record.updated_at
    db.commit()

    return await private_blob_response(
        stored_name=record.stored_name,
        original_name=record.original_name,
        mime_type=record.mime_type,
        inline=False,
    )


@router.post(
    "/{material_id}/retention",
    response_model=PersonalMaterialResponse,
)
def retention(
    material_id: int,
    request: PersonalRetentionAction,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        return retention_action(
            db,
            current_user,
            material_id,
            request.action,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
