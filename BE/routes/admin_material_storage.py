from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_admin_user
from models.user import User
from schemas.admin_material_storage import (
    AdminMaterialStorageCleanupRequest,
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
)

router = APIRouter(
    prefix="/admin/material-storage",
    tags=["admin-material-storage"],
)


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