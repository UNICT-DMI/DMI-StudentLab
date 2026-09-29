from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_current_user
from models.material_share import MaterialShare
from models.user import User
from schemas.material_share import (
    MaterialShareCompleteRequest,
    MaterialShareResponse,
    MaterialShareUploadRequest,
    MaterialShareVerifyRequest,
    MaterialShareVerifyResponse,
)
from services.material_share import (
    accept_share,
    complete_share,
    mark_delivered,
    prepare_share_upload,
    process_expired_shares,
    reject_share,
    verify_share_upload,
)
from services.private_blob import private_blob_response, verify_private_blob


router = APIRouter(
    prefix="/material-shares",
    tags=["material-shares"],
)


@router.post("/upload-request")
def upload_request(
    request: MaterialShareUploadRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        return prepare_share_upload(db, current_user, request)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post(
    "/verify-upload",
    response_model=MaterialShareVerifyResponse,
)
def verify_upload(
    request: MaterialShareVerifyRequest,
    current_user: User = Depends(get_current_user),
):
    try:
        return verify_share_upload(current_user, request)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post(
    "/complete",
    response_model=MaterialShareResponse,
)
async def complete(
    request: MaterialShareCompleteRequest,
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
        return complete_share(db, current_user, request)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get(
    "",
    response_model=list[MaterialShareResponse],
)
def list_shares(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    process_expired_shares(db)
    return (
        db.query(MaterialShare)
        .filter(
            (MaterialShare.sender_user_id == current_user.id)
            | (MaterialShare.recipient_user_id == current_user.id)
        )
        .order_by(MaterialShare.created_at.desc())
        .all()
    )


@router.post(
    "/{share_id}/accept",
    response_model=MaterialShareResponse,
)
def accept(
    share_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        return accept_share(db, current_user, share_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/{share_id}/download")
async def download(
    share_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    record = (
        db.query(MaterialShare)
        .filter(
            MaterialShare.id == share_id,
            MaterialShare.recipient_user_id == current_user.id,
            MaterialShare.status.in_(["accepted", "delivered"]),
        )
        .first()
    )
    if record is None:
        raise HTTPException(
            status_code=404,
            detail="Condivisione non trovata.",
        )

    return await private_blob_response(
        stored_name=record.stored_name,
        original_name=record.original_name,
        mime_type=record.mime_type,
        inline=False,
    )


@router.post(
    "/{share_id}/delivered",
    response_model=MaterialShareResponse,
)
def delivered(
    share_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        return mark_delivered(db, current_user, share_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post(
    "/{share_id}/reject",
    response_model=MaterialShareResponse,
)
def reject(
    share_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        return reject_share(db, current_user, share_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
