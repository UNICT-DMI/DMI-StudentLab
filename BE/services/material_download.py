from sqlalchemy.orm import (
    Session,
)

from models.group import (
    GroupMember,
    StudyGroup,
)

from models.material import (
    GroupMaterial,
)

from models.public_material import (
    PublicMaterial,
)

from models.teacher_material import (
    TeacherMaterial,
)

from services.teacher_material_assignment import (
    can_user_access_teacher_material,
)


def _require_active_public_material(
    db: Session,
    material_id: int,
):
    material = (
        db.query(
            PublicMaterial,
        )
        .filter(
            PublicMaterial.id ==
            material_id,
        )
        .first()
    )

    if material is None:
        raise ValueError(
            "Materiale non trovato.",
        )

    status = (
        getattr(
            material,
            "status",
            None,
        )
        or "active"
    )

    is_visible = bool(
        getattr(
            material,
            "is_visible",
            True,
        )
    )

    is_active = bool(
        getattr(
            material,
            "is_active",
            True,
        )
    )

    if (
        status != "active"
        or not is_visible
        or not is_active
    ):
        raise ValueError(
            "Materiale non trovato.",
        )

    return material


def _require_accessible_teacher_material(
    db: Session,
    *,
    material_id: int,
    user_id: int,
):
    material = (
        db.query(
            TeacherMaterial,
        )
        .filter(
            TeacherMaterial.id ==
            material_id,
        )
        .first()
    )

    if material is None:
        raise ValueError(
            "Materiale non trovato.",
        )

    if (
        material.status !=
        "active"
        or not material.is_active
    ):
        raise ValueError(
            "Materiale non trovato.",
        )

    is_owner = (
        material.uploaded_by ==
        user_id
    )

    if (
        not is_owner
        and not can_user_access_teacher_material(
            db,
            user_id=user_id,
            material_id=material.id,
        )
    ):
        raise PermissionError(
            "Non puoi accedere a questo materiale.",
        )

    return material


def _user_is_group_member(
    db: Session,
    *,
    group_id: int,
    user_id: int,
):
    return (
        db.query(
            GroupMember,
        )
        .filter(
            GroupMember.group_id ==
            group_id,
            GroupMember.user_id ==
            user_id,
        )
        .first()
        is not None
    )


def _require_accessible_group_material(
    db: Session,
    *,
    material_id: int,
    user_id: int,
):
    material = (
        db.query(
            GroupMaterial,
        )
        .filter(
            GroupMaterial.id ==
            material_id,
        )
        .first()
    )

    if material is None:
        raise ValueError(
            "Materiale non trovato.",
        )

    if (
        material.status !=
        "active"
        or not material.is_active
    ):
        raise ValueError(
            "Materiale non trovato.",
        )

    group = (
        db.query(
            StudyGroup,
        )
        .filter(
            StudyGroup.id ==
            material.group_id,
        )
        .first()
    )

    if (
        group is None
        or group.status !=
        "active"
    ):
        raise ValueError(
            "Gruppo non trovato.",
        )

    if not group.is_private:
        return material

    if not _user_is_group_member(
        db,
        group_id=group.id,
        user_id=user_id,
    ):
        raise PermissionError(
            "Non puoi accedere a questo materiale.",
        )

    return material


def get_downloadable_material(
    db: Session,
    *,
    source: str,
    material_id: int,
    user_id: int,
):
    normalized_source = (
        source
        .strip()
        .lower()
    )

    if material_id <= 0:
        raise ValueError(
            "Materiale non trovato.",
        )

    if normalized_source == "public":
        material = (
            _require_active_public_material(
                db,
                material_id,
            )
        )

    elif normalized_source == "teacher":
        material = (
            _require_accessible_teacher_material(
                db,
                material_id=material_id,
                user_id=user_id,
            )
        )

    elif normalized_source == "group":
        material = (
            _require_accessible_group_material(
                db,
                material_id=material_id,
                user_id=user_id,
            )
        )

    else:
        raise ValueError(
            "Sorgente materiale non valida.",
        )

    return {
        "source":
            normalized_source,
        "material_id":
            material.id,
        "stored_name":
            material.stored_name,
        "original_name":
            material.original_name,
        "mime_type":
            material.mime_type,
        "size":
            getattr(
                material,
                "size",
                None,
            ),
        "file_hash":
            material.file_hash,
        "version":
            (
                getattr(
                    material,
                    "version",
                    1,
                )
                or 1
            ),
    }