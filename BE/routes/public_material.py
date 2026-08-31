from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_admin_user
from models.user import User
from schemas.public_material import PublicMaterialAdminResponse, PublicMaterialResponse
from services.private_blob import private_blob_response
from services.public_material import (
    get_admin_public_materials,
    get_public_material_by_id,
    get_public_materials,
    get_public_materials_by_catalog,
    get_public_materials_by_subject,
    get_visible_public_material_by_id,
    hide_public_material,
    remove_public_material,
    restore_public_material,
)

router = APIRouter()


@router.get("/public_materials", response_model=list[PublicMaterialResponse])
def api_public_materials(db: Session = Depends(get_db)):
    return get_public_materials(db)


@router.get(
    "/public_materials/subject/{subject_id}",
    response_model=list[PublicMaterialResponse],
)
def api_public_materials_by_subject(
    subject_id: int,
    db: Session = Depends(get_db),
):
    return get_public_materials_by_subject(db, subject_id)


@router.get(
    "/public_materials/catalog/{university_code}/{department_code}/{course_code}/{subject_id}",
    response_model=list[PublicMaterialResponse],
)
def api_public_materials_by_catalog(
    university_code: str,
    department_code: str,
    course_code: str,
    subject_id: int,
    db: Session = Depends(get_db),
):
    materials = get_public_materials_by_catalog(
        db,
        university_code=university_code,
        department_code=department_code,
        course_code=course_code,
        subject_id=subject_id,
    )
    if materials is None:
        raise HTTPException(
            status_code=404,
            detail="Materia non trovata.",
        )
    return materials


@router.get(
    "/public_materials/{material_id}",
    response_model=PublicMaterialResponse,
)
def api_public_material(
    material_id: int,
    db: Session = Depends(get_db),
):
    material = get_visible_public_material_by_id(
        db,
        material_id,
    )
    if material is None:
        raise HTTPException(
            status_code=404,
            detail="Materiale non trovato.",
        )
    return material


@router.get("/public_materials/{material_id}/view")
async def api_public_material_view(
    material_id: int,
    db: Session = Depends(get_db),
):
    material = get_visible_public_material_by_id(
        db,
        material_id,
    )
    if material is None:
        raise HTTPException(
            status_code=404,
            detail="Materiale non trovato.",
        )
    return await private_blob_response(
        stored_name=material.stored_name,
        original_name=material.original_name,
        mime_type=material.mime_type,
        inline=True,
    )


@router.get("/public_materials/{material_id}/download")
async def api_public_material_download(
    material_id: int,
    db: Session = Depends(get_db),
):
    material = get_visible_public_material_by_id(
        db,
        material_id,
    )
    if material is None:
        raise HTTPException(
            status_code=404,
            detail="Materiale non trovato.",
        )
    return await private_blob_response(
        stored_name=material.stored_name,
        original_name=material.original_name,
        mime_type=material.mime_type,
        inline=False,
    )


@router.get(
    "/admin/public_materials",
    response_model=list[PublicMaterialAdminResponse],
)
def api_admin_public_materials(
    status: str | None = None,
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    if status is not None and status not in {
        "published",
        "hidden",
        "removed",
    }:
        raise HTTPException(
            status_code=400,
            detail="Stato del materiale non valido.",
        )
    return get_admin_public_materials(
        db,
        status=status,
    )


@router.get(
    "/admin/public_materials/{material_id}",
    response_model=PublicMaterialAdminResponse,
)
def api_admin_public_material(
    material_id: int,
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    material = get_public_material_by_id(db, material_id)
    if material is None:
        raise HTTPException(
            status_code=404,
            detail="Materiale non trovato.",
        )
    return material


@router.get("/admin/public_materials/{material_id}/file")
async def api_admin_public_material_file(
    material_id: int,
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    material = get_public_material_by_id(db, material_id)
    if material is None:
        raise HTTPException(
            status_code=404,
            detail="Materiale non trovato.",
        )
    return await private_blob_response(
        stored_name=material.stored_name,
        original_name=material.original_name,
        mime_type=material.mime_type,
        inline=True,
    )


@router.get("/admin/public_materials/{material_id}/download")
async def api_admin_public_material_download(
    material_id: int,
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    material = get_public_material_by_id(db, material_id)
    if material is None:
        raise HTTPException(
            status_code=404,
            detail="Materiale non trovato.",
        )
    return await private_blob_response(
        stored_name=material.stored_name,
        original_name=material.original_name,
        mime_type=material.mime_type,
        inline=False,
    )


@router.post(
    "/admin/public_materials/{material_id}/hide",
    response_model=PublicMaterialAdminResponse,
)
def api_admin_hide_public_material(
    material_id: int,
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    material = get_public_material_by_id(db, material_id)
    if material is None:
        raise HTTPException(
            status_code=404,
            detail="Materiale non trovato.",
        )
    if material.status == "removed":
        raise HTTPException(
            status_code=400,
            detail="Il materiale è stato rimosso.",
        )
    if material.status == "hidden":
        raise HTTPException(
            status_code=400,
            detail="Il materiale è già nascosto.",
        )
    return hide_public_material(
        db,
        material=material,
        current_admin=current_user,
    )


@router.post(
    "/admin/public_materials/{material_id}/restore",
    response_model=PublicMaterialAdminResponse,
)
def api_admin_restore_public_material(
    material_id: int,
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    material = get_public_material_by_id(db, material_id)
    if material is None:
        raise HTTPException(
            status_code=404,
            detail="Materiale non trovato.",
        )
    if material.status == "removed":
        raise HTTPException(
            status_code=400,
            detail="Il materiale è stato rimosso.",
        )
    if material.status == "published":
        raise HTTPException(
            status_code=400,
            detail="Il materiale è già pubblicato.",
        )
    return restore_public_material(
        db,
        material=material,
        current_admin=current_user,
    )


@router.post(
    "/admin/public_materials/{material_id}/remove",
    response_model=PublicMaterialAdminResponse,
)
def api_admin_remove_public_material(
    material_id: int,
    current_user: User = Depends(get_admin_user),
    db: Session = Depends(get_db),
):
    material = get_public_material_by_id(db, material_id)
    if material is None:
        raise HTTPException(
            status_code=404,
            detail="Materiale non trovato.",
        )
    if material.status == "removed":
        raise HTTPException(
            status_code=400,
            detail="Il materiale è già stato rimosso.",
        )
    return remove_public_material(
        db,
        material=material,
        current_admin=current_user,
    )
