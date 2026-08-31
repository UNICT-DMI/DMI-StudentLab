from datetime import (
    datetime,
    timezone,
)

from sqlalchemy.exc import (
    IntegrityError,
)

from sqlalchemy.orm import (
    Session,
)

from models.public_material import (
    PublicMaterial,
)

from models.subject import (
    Subject,
)

from models.user import (
    User,
)


def utc_now():
    return datetime.now(
        timezone.utc,
    )


def normalize_public_material_hash(
    file_hash: str,
) -> str:
    value = (
        file_hash
        .strip()
        .lower()
    )

    if len(value) != 64:
        raise ValueError(
            "Hash del file non valido.",
        )

    if not all(
        character
        in "0123456789abcdef"
        for character
        in value
    ):
        raise ValueError(
            "Hash del file non valido.",
        )

    return value


def get_public_material_by_id(
    db: Session,
    material_id: int,
):
    return (
        db.query(
            PublicMaterial,
        )
        .filter(
            PublicMaterial.id ==
            material_id,
        )
        .first()
    )


def get_visible_public_material_by_id(
    db: Session,
    material_id: int,
):
    return (
        db.query(
            PublicMaterial,
        )
        .filter(
            PublicMaterial.id ==
            material_id,
            PublicMaterial.status ==
            "published",
            PublicMaterial.is_visible.is_(
                True,
            ),
        )
        .first()
    )


def get_public_material_by_hash(
    db: Session,
    *,
    subject_id: int,
    file_hash: str,
    include_removed: bool = True,
):
    normalized_hash = (
        normalize_public_material_hash(
            file_hash,
        )
    )

    query = (
        db.query(
            PublicMaterial,
        )
        .filter(
            PublicMaterial.subject_id ==
            subject_id,
            PublicMaterial.file_hash ==
            normalized_hash,
        )
    )

    if not include_removed:
        query = query.filter(
            PublicMaterial.status !=
            "removed",
        )

    return query.first()


def ensure_public_material_not_duplicate(
    db: Session,
    *,
    subject_id: int,
    file_hash: str,
    exclude_material_id: int | None = None,
):
    normalized_hash = (
        normalize_public_material_hash(
            file_hash,
        )
    )

    query = (
        db.query(
            PublicMaterial,
        )
        .filter(
            PublicMaterial.subject_id ==
            subject_id,
            PublicMaterial.file_hash ==
            normalized_hash,
            PublicMaterial.status !=
            "removed",
        )
    )

    if exclude_material_id is not None:
        query = query.filter(
            PublicMaterial.id !=
            exclude_material_id,
        )

    if query.first() is not None:
        raise ValueError(
            "Questo materiale è già presente "
            "nelle dispense pubbliche.",
        )


def get_public_materials(
    db: Session,
):
    return (
        db.query(
            PublicMaterial,
        )
        .filter(
            PublicMaterial.status ==
            "published",
            PublicMaterial.is_visible.is_(
                True,
            ),
        )
        .order_by(
            PublicMaterial.updated_at.desc(),
            PublicMaterial.created_at.desc(),
        )
        .all()
    )


def get_public_materials_by_subject(
    db: Session,
    subject_id: int,
):
    return (
        db.query(
            PublicMaterial,
        )
        .filter(
            PublicMaterial.subject_id ==
            subject_id,
            PublicMaterial.status ==
            "published",
            PublicMaterial.is_visible.is_(
                True,
            ),
        )
        .order_by(
            PublicMaterial.updated_at.desc(),
            PublicMaterial.created_at.desc(),
        )
        .all()
    )


def get_public_materials_by_catalog(
    db: Session,
    *,
    university_code: str,
    department_code: str,
    course_code: str,
    subject_id: int,
):
    subject = (
        db.query(
            Subject,
        )
        .filter(
            Subject.id ==
            subject_id,
            Subject.university_code ==
            university_code,
            Subject.department_code ==
            department_code,
            Subject.course_code ==
            course_code,
            Subject.is_active.is_(
                True,
            ),
        )
        .first()
    )

    if subject is None:
        return None

    return (
        db.query(
            PublicMaterial,
        )
        .filter(
            PublicMaterial.subject_id ==
            subject_id,
            PublicMaterial.university_code ==
            university_code,
            PublicMaterial.department_code ==
            department_code,
            PublicMaterial.course_code ==
            course_code,
            PublicMaterial.status ==
            "published",
            PublicMaterial.is_visible.is_(
                True,
            ),
        )
        .order_by(
            PublicMaterial.updated_at.desc(),
            PublicMaterial.created_at.desc(),
        )
        .all()
    )


def get_admin_public_materials(
    db: Session,
    status: str | None = None,
    subject_id: int | None = None,
):
    query = db.query(
        PublicMaterial,
    )

    if status is not None:
        if status not in {
            "published",
            "hidden",
            "removed",
        }:
            raise ValueError(
                "Stato del materiale non valido.",
            )

        query = query.filter(
            PublicMaterial.status ==
            status,
        )

    if subject_id is not None:
        query = query.filter(
            PublicMaterial.subject_id ==
            subject_id,
        )

    return (
        query
        .order_by(
            PublicMaterial.updated_at.desc(),
            PublicMaterial.created_at.desc(),
        )
        .all()
    )


def update_public_material_metadata(
    db: Session,
    *,
    material: PublicMaterial,
    current_admin: User,
    title: str | None = None,
    description: str | None = None,
):
    if material.status == "removed":
        raise ValueError(
            "Il materiale è stato rimosso.",
        )

    if title is not None:
        clean_title = (
            title
            .strip()
        )

        if not clean_title:
            raise ValueError(
                "Titolo del materiale obbligatorio.",
            )

        material.title = (
            clean_title
        )

    if description is not None:
        material.description = (
            description
            .strip()
        )

    material.updated_at = (
        utc_now()
    )

    try:
        db.commit()

        db.refresh(
            material,
        )

        return material

    except Exception:
        db.rollback()
        raise


def replace_public_material_file(
    db: Session,
    *,
    material: PublicMaterial,
    current_admin: User,
    original_name: str,
    stored_name: str,
    file_path: str,
    mime_type: str,
    size: int,
    file_hash: str,
    uploaded_by: int | None = None,
    publication_request_id: int | None = None,
    title: str | None = None,
    description: str | None = None,
):
    if material.status == "removed":
        raise ValueError(
            "Il materiale è stato rimosso.",
        )

    if size <= 0:
        raise ValueError(
            "Il file è vuoto.",
        )

    normalized_hash = (
        normalize_public_material_hash(
            file_hash,
        )
    )

    ensure_public_material_not_duplicate(
        db,
        subject_id=(
            material.subject_id
        ),
        file_hash=(
            normalized_hash
        ),
        exclude_material_id=(
            material.id
        ),
    )

    clean_original_name = (
        original_name
        .strip()
    )

    if not clean_original_name:
        raise ValueError(
            "Nome del file non valido.",
        )

    clean_stored_name = (
        stored_name
        .strip()
    )

    if not clean_stored_name:
        raise ValueError(
            "Percorso storage non valido.",
        )

    clean_file_path = (
        file_path
        .strip()
    )

    if not clean_file_path:
        raise ValueError(
            "Percorso file non valido.",
        )

    clean_mime_type = (
        mime_type
        .split(
            ";",
            1,
        )[0]
        .strip()
        .lower()
    )

    if not clean_mime_type:
        raise ValueError(
            "Tipo di file non valido.",
        )

    if title is not None:
        clean_title = (
            title
            .strip()
        )

        if not clean_title:
            raise ValueError(
                "Titolo del materiale obbligatorio.",
            )

        material.title = (
            clean_title
        )

    if description is not None:
        material.description = (
            description
            .strip()
        )

    material.original_name = (
        clean_original_name
    )

    material.stored_name = (
        clean_stored_name
    )

    material.file_path = (
        clean_file_path
    )

    material.mime_type = (
        clean_mime_type
    )

    material.size = (
        size
    )

    material.file_hash = (
        normalized_hash
    )

    material.version = (
        max(
            material.version or 1,
            1,
        )
        + 1
    )

    material.status = (
        "published"
    )

    material.is_visible = (
        True
    )

    material.approved_by = (
        current_admin.id
    )

    material.approved_at = (
        utc_now()
    )

    if uploaded_by is not None:
        material.uploaded_by = (
            uploaded_by
        )

    if publication_request_id is not None:
        material.publication_request_id = (
            publication_request_id
        )

    material.removed_by = (
        None
    )

    material.removed_at = (
        None
    )

    material.removal_reason = (
        None
    )

    material.updated_at = (
        utc_now()
    )

    try:
        db.commit()

        db.refresh(
            material,
        )

        return material

    except IntegrityError as exception:
        db.rollback()

        raise ValueError(
            "Impossibile aggiornare "
            "il materiale pubblico.",
        ) from exception

    except Exception:
        db.rollback()
        raise


def hide_public_material(
    db: Session,
    *,
    material: PublicMaterial,
    current_admin: User,
):
    if material.status == "removed":
        raise ValueError(
            "Il materiale è stato rimosso.",
        )

    if material.status == "hidden":
        return material

    material.status = (
        "hidden"
    )

    material.is_visible = (
        False
    )

    material.updated_at = (
        utc_now()
    )

    try:
        db.commit()

        db.refresh(
            material,
        )

        return material

    except Exception:
        db.rollback()
        raise


def restore_public_material(
    db: Session,
    *,
    material: PublicMaterial,
    current_admin: User,
):
    if material.status == "removed":
        raise ValueError(
            "Il materiale è stato rimosso.",
        )

    material.status = (
        "published"
    )

    material.is_visible = (
        True
    )

    material.updated_at = (
        utc_now()
    )

    try:
        db.commit()

        db.refresh(
            material,
        )

        return material

    except Exception:
        db.rollback()
        raise


def remove_public_material(
    db: Session,
    *,
    material: PublicMaterial,
    current_admin: User,
    removal_reason: str | None = None,
):
    if material.status == "removed":
        return material

    material.status = (
        "removed"
    )

    material.is_visible = (
        False
    )

    material.removed_by = (
        current_admin.id
    )

    material.removed_at = (
        utc_now()
    )

    material.removal_reason = (
        removal_reason
        .strip()
        if (
            removal_reason is not None
            and removal_reason.strip()
        )
        else None
    )

    material.updated_at = (
        utc_now()
    )

    try:
        db.commit()

        db.refresh(
            material,
        )

        return material

    except Exception:
        db.rollback()
        raise