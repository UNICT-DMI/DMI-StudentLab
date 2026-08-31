import uuid

from datetime import (
    datetime,
    timezone,
)

from pathlib import Path

from sqlalchemy.exc import (
    IntegrityError,
)

from sqlalchemy.orm import (
    Session,
)

from models.group import (
    StudyGroup,
)

from models.material import (
    GroupMaterial,
)

from schemas.material import (
    GroupMaterialCompleteRequest,
    GroupMaterialUploadRequest,
    GroupMaterialVerifyRequest,
)

from services.upload_authorization import (
    create_upload_authorization,
    decode_upload_authorization,
    require_upload_authorization_fields,
    require_upload_authorization_type,
    require_upload_authorization_user,
)


ALLOWED_MIME_TYPES = {
    "application/pdf",
    "text/plain",
    "application/zip",
    "application/x-zip-compressed",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation",
}


ALLOWED_EXTENSIONS_BY_MIME = {
    "application/pdf": {
        ".pdf",
    },
    "text/plain": {
        ".txt",
    },
    "application/zip": {
        ".zip",
    },
    "application/x-zip-compressed": {
        ".zip",
    },
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document": {
        ".docx",
    },
    "application/vnd.openxmlformats-officedocument.presentationml.presentation": {
        ".pptx",
    },
}


MAX_FILE_SIZE = (
    250
    * 1024
    * 1024
)


def utc_now():
    return datetime.now(
        timezone.utc,
    )


def validate_original_name(
    original_name: str,
) -> str:
    if not isinstance(
        original_name,
        str,
    ):
        raise ValueError(
            "Nome file non valido.",
        )

    normalized_name = (
        original_name.strip()
    )

    if (
        not normalized_name
        or len(
            normalized_name
        ) > 255
        or "/" in normalized_name
        or "\\" in normalized_name
        or "\x00" in normalized_name
        or normalized_name in {
            ".",
            "..",
        }
    ):
        raise ValueError(
            "Nome file non valido.",
        )

    if (
        Path(
            normalized_name
        ).name
        != normalized_name
    ):
        raise ValueError(
            "Nome file non valido.",
        )

    return normalized_name


def validate_material_size(
    size: int,
) -> int:
    if (
        not isinstance(
            size,
            int,
        )
        or isinstance(
            size,
            bool,
        )
        or size <= 0
    ):
        raise ValueError(
            "Il file è vuoto.",
        )

    if size > MAX_FILE_SIZE:
        raise ValueError(
            "Il file supera la dimensione "
            "massima consentita di 250 MB.",
        )

    return size


def validate_material_mime_type(
    mime_type: str,
) -> str:
    if not isinstance(
        mime_type,
        str,
    ):
        raise ValueError(
            "Tipo di file non supportato.",
        )

    normalized_mime_type = (
        mime_type
        .split(
            ";",
            1,
        )[0]
        .strip()
        .lower()
    )

    if (
        normalized_mime_type
        not in ALLOWED_MIME_TYPES
    ):
        raise ValueError(
            "Tipo di file non supportato.",
        )

    return normalized_mime_type


def validate_material_extension(
    original_name: str,
    mime_type: str,
) -> str:
    normalized_name = (
        validate_original_name(
            original_name
        )
    )

    normalized_mime_type = (
        validate_material_mime_type(
            mime_type
        )
    )

    extension = (
        Path(
            normalized_name
        )
        .suffix
        .lower()
    )

    if (
        extension
        not in ALLOWED_EXTENSIONS_BY_MIME[
            normalized_mime_type
        ]
    ):
        raise ValueError(
            "L'estensione del file non corrisponde "
            "al tipo di contenuto.",
        )

    return extension


def normalize_file_hash(
    file_hash: str,
) -> str:
    if not isinstance(
        file_hash,
        str,
    ):
        raise ValueError(
            "Hash del file non valido.",
        )

    normalized_hash = (
        file_hash
        .strip()
        .lower()
    )

    if (
        len(
            normalized_hash,
        )
        != 64
    ):
        raise ValueError(
            "Hash del file non valido.",
        )

    if not all(
        character
        in "0123456789abcdef"
        for character
        in normalized_hash
    ):
        raise ValueError(
            "Hash del file non valido.",
        )

    return normalized_hash


def generate_stored_name(
    group_id: int,
    original_name: str,
    mime_type: str | None = None,
) -> str:
    if (
        not isinstance(
            group_id,
            int,
        )
        or isinstance(
            group_id,
            bool,
        )
        or group_id <= 0
    ):
        raise ValueError(
            "ID gruppo non valido.",
        )

    normalized_name = (
        validate_original_name(
            original_name
        )
    )

    if mime_type is not None:
        extension = (
            validate_material_extension(
                normalized_name,
                mime_type,
            )
        )
    else:
        extension = (
            Path(
                normalized_name
            )
            .suffix
            .lower()
        )

    if not extension:
        raise ValueError(
            "Estensione file non valida.",
        )

    unique_id = (
        uuid.uuid4().hex
    )

    return (
        f"groups/"
        f"group_{group_id}/"
        f"{unique_id}{extension}"
    )


def validate_stored_name(
    group_id: int,
    stored_name: str,
) -> str:
    if not isinstance(
        stored_name,
        str,
    ):
        raise ValueError(
            "Percorso storage non valido.",
        )

    normalized_stored_name = (
        stored_name.strip()
    )

    expected_prefix = (
        f"groups/group_{group_id}/"
    )

    if (
        not normalized_stored_name.startswith(
            expected_prefix,
        )
        or normalized_stored_name.startswith(
            "/"
        )
        or ".." in normalized_stored_name
        or "\\" in normalized_stored_name
        or "\x00" in normalized_stored_name
        or "\r" in normalized_stored_name
        or "\n" in normalized_stored_name
    ):
        raise ValueError(
            "Percorso storage non valido.",
        )

    relative_path = (
        normalized_stored_name[
            len(
                expected_prefix
            ):
        ]
    )

    if (
        not relative_path
        or "/" in relative_path
    ):
        raise ValueError(
            "Percorso storage non valido.",
        )

    return normalized_stored_name


def prepare_group_material_upload(
    db: Session,
    *,
    group_id: int,
    uploaded_by: int,
    data: GroupMaterialUploadRequest,
):
    if (
        not isinstance(
            uploaded_by,
            int,
        )
        or isinstance(
            uploaded_by,
            bool,
        )
        or uploaded_by <= 0
    ):
        raise ValueError(
            "ID utente non valido.",
        )

    original_name = (
        validate_original_name(
            data.original_name
        )
    )

    mime_type = (
        validate_material_mime_type(
            data.mime_type
        )
    )

    validate_material_extension(
        original_name,
        mime_type,
    )

    size = (
        validate_material_size(
            data.size
        )
    )

    file_hash = (
        normalize_file_hash(
            data.file_hash
        )
    )

    ensure_material_not_duplicate(
        db,
        group_id,
        file_hash,
    )

    stored_name = (
        generate_stored_name(
            group_id,
            original_name,
            mime_type,
        )
    )

    payload = {
        "v":
            1,
        "type":
            "group_material",
        "uid":
            uploaded_by,
        "gid":
            group_id,
        "original_name":
            original_name,
        "pathname":
            stored_name,
        "mime_type":
            mime_type,
        "size":
            size,
        "file_hash":
            file_hash,
    }

    (
        upload_token,
        expires_at,
    ) = create_upload_authorization(
        payload
    )

    return {
        "allowed":
            True,
        "group_id":
            group_id,
        "uploaded_by":
            uploaded_by,
        "original_name":
            original_name,
        "pathname":
            stored_name,
        "mime_type":
            mime_type,
        "size":
            size,
        "file_hash":
            file_hash,
        "max_file_size":
            MAX_FILE_SIZE,
        "upload_token":
            upload_token,
        "valid_until":
            expires_at
            * 1000,
    }


def verify_group_material_upload(
    *,
    user_id: int,
    data: GroupMaterialVerifyRequest,
):
    payload = (
        decode_upload_authorization(
            data.upload_token
        )
    )

    require_upload_authorization_type(
        payload,
        "group_material",
    )

    require_upload_authorization_user(
        payload,
        user_id,
    )

    mime_type = (
        validate_material_mime_type(
            data.mime_type
        )
    )

    size = (
        validate_material_size(
            data.size
        )
    )

    file_hash = (
        normalize_file_hash(
            data.file_hash
        )
    )

    pathname = (
        validate_stored_name(
            data.group_id,
            data.pathname,
        )
    )

    require_upload_authorization_fields(
        payload,
        {
            "gid":
                data.group_id,
            "pathname":
                pathname,
            "mime_type":
                mime_type,
            "size":
                size,
            "file_hash":
                file_hash,
        },
    )

    return {
        "allowed":
            True,
        "group_id":
            data.group_id,
        "pathname":
            pathname,
        "mime_type":
            mime_type,
        "size":
            size,
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


def validate_group_material_completion(
    *,
    user_id: int,
    group_id: int,
    data: GroupMaterialCompleteRequest,
):
    payload = (
        decode_upload_authorization(
            data.upload_token
        )
    )

    require_upload_authorization_type(
        payload,
        "group_material",
    )

    require_upload_authorization_user(
        payload,
        user_id,
    )

    original_name = (
        validate_original_name(
            data.original_name
        )
    )

    mime_type = (
        validate_material_mime_type(
            data.mime_type
        )
    )

    validate_material_extension(
        original_name,
        mime_type,
    )

    size = (
        validate_material_size(
            data.size
        )
    )

    file_hash = (
        normalize_file_hash(
            data.file_hash
        )
    )

    stored_name = (
        validate_stored_name(
            group_id,
            data.stored_name,
        )
    )

    require_upload_authorization_fields(
        payload,
        {
            "gid":
                group_id,
            "original_name":
                original_name,
            "pathname":
                stored_name,
            "mime_type":
                mime_type,
            "size":
                size,
            "file_hash":
                file_hash,
        },
    )

    return {
        "original_name":
            original_name,
        "stored_name":
            stored_name,
        "file_path":
            stored_name,
        "mime_type":
            mime_type,
        "size":
            size,
        "file_hash":
            file_hash,
    }


def get_group_material_by_hash(
    db: Session,
    group_id: int,
    file_hash: str,
    *,
    include_removed: bool = True,
):
    normalized_hash = (
        normalize_file_hash(
            file_hash,
        )
    )

    query = (
        db.query(
            GroupMaterial,
        )
        .filter(
            GroupMaterial.group_id
            == group_id,
            GroupMaterial.file_hash
            == normalized_hash,
        )
    )

    if not include_removed:
        query = query.filter(
            GroupMaterial.status
            != "removed",
            GroupMaterial.is_active.is_(
                True,
            ),
        )

    return query.first()


def material_exists_in_group(
    db: Session,
    group_id: int,
    file_hash: str,
) -> bool:
    return (
        get_group_material_by_hash(
            db,
            group_id,
            file_hash,
            include_removed=False,
        )
        is not None
    )


def ensure_material_not_duplicate(
    db: Session,
    group_id: int,
    file_hash: str,
    *,
    exclude_material_id: int | None = None,
) -> None:
    normalized_hash = (
        normalize_file_hash(
            file_hash,
        )
    )

    query = (
        db.query(
            GroupMaterial,
        )
        .filter(
            GroupMaterial.group_id
            == group_id,
            GroupMaterial.file_hash
            == normalized_hash,
            GroupMaterial.status
            != "removed",
            GroupMaterial.is_active.is_(
                True,
            ),
        )
    )

    if exclude_material_id is not None:
        query = query.filter(
            GroupMaterial.id
            != exclude_material_id,
        )

    if query.first() is not None:
        raise ValueError(
            "Questo materiale è già presente "
            "nel gruppo.",
        )


def create_group_material_record(
    db: Session,
    group_id: int,
    uploaded_by: int,
    original_name: str,
    stored_name: str,
    file_path: str,
    mime_type: str,
    size: int,
    file_hash: str,
):
    original_name = (
        validate_original_name(
            original_name
        )
    )

    size = (
        validate_material_size(
            size
        )
    )

    mime_type = (
        validate_material_mime_type(
            mime_type
        )
    )

    validate_material_extension(
        original_name,
        mime_type,
    )

    stored_name = (
        validate_stored_name(
            group_id,
            stored_name,
        )
    )

    file_path = stored_name

    normalized_hash = (
        normalize_file_hash(
            file_hash,
        )
    )

    existing = (
        get_group_material_by_hash(
            db,
            group_id,
            normalized_hash,
            include_removed=True,
        )
    )

    if (
        existing is not None
        and existing.status
        != "removed"
    ):
        raise ValueError(
            "Questo materiale è già presente "
            "nel gruppo.",
        )

    if existing is not None:
        existing.uploaded_by = (
            uploaded_by
        )

        existing.original_name = (
            original_name
        )

        existing.stored_name = (
            stored_name
        )

        existing.file_path = (
            file_path
        )

        existing.mime_type = (
            mime_type
        )

        existing.size = (
            size
        )

        existing.file_hash = (
            normalized_hash
        )

        existing.version = (
            max(
                existing.version
                or 1,
                1,
            )
            + 1
        )

        existing.status = (
            "active"
        )

        existing.is_active = (
            True
        )

        existing.updated_by = (
            uploaded_by
        )

        existing.removed_by = (
            None
        )

        existing.removed_at = (
            None
        )

        existing.removal_reason = (
            None
        )

        existing.updated_at = (
            utc_now()
        )

        try:
            db.commit()

            db.refresh(
                existing,
            )

            return existing

        except Exception:
            db.rollback()
            raise

    ensure_material_not_duplicate(
        db,
        group_id,
        normalized_hash,
    )

    material = GroupMaterial(
        group_id=group_id,
        uploaded_by=uploaded_by,
        original_name=original_name,
        stored_name=stored_name,
        file_path=file_path,
        mime_type=mime_type,
        size=size,
        file_hash=normalized_hash,
        version=1,
        status="active",
        is_active=True,
        updated_by=uploaded_by,
    )

    try:
        db.add(
            material,
        )

        db.commit()

        db.refresh(
            material,
        )

        return material

    except IntegrityError as exception:
        db.rollback()

        raise ValueError(
            "Questo materiale è già presente "
            "nel gruppo.",
        ) from exception

    except Exception:
        db.rollback()
        raise


def replace_group_material_record(
    db: Session,
    material: GroupMaterial,
    *,
    updated_by: int,
    original_name: str,
    stored_name: str,
    file_path: str,
    mime_type: str,
    size: int,
    file_hash: str,
):
    if material.status == "removed":
        raise ValueError(
            "Il materiale è stato rimosso.",
        )

    original_name = (
        validate_original_name(
            original_name
        )
    )

    size = (
        validate_material_size(
            size
        )
    )

    mime_type = (
        validate_material_mime_type(
            mime_type
        )
    )

    validate_material_extension(
        original_name,
        mime_type,
    )

    stored_name = (
        validate_stored_name(
            material.group_id,
            stored_name,
        )
    )

    file_path = stored_name

    normalized_hash = (
        normalize_file_hash(
            file_hash,
        )
    )

    ensure_material_not_duplicate(
        db,
        material.group_id,
        normalized_hash,
        exclude_material_id=(
            material.id
        ),
    )

    material.original_name = (
        original_name
    )

    material.stored_name = (
        stored_name
    )

    material.file_path = (
        file_path
    )

    material.mime_type = (
        mime_type
    )

    material.size = (
        size
    )

    material.file_hash = (
        normalized_hash
    )

    material.version = (
        max(
            material.version
            or 1,
            1,
        )
        + 1
    )

    material.updated_by = (
        updated_by
    )

    material.updated_at = (
        utc_now()
    )

    material.status = (
        "active"
    )

    material.is_active = (
        True
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

    try:
        db.commit()

        db.refresh(
            material,
        )

        return material

    except IntegrityError as exception:
        db.rollback()

        raise ValueError(
            "Questo materiale è già presente "
            "nel gruppo.",
        ) from exception

    except Exception:
        db.rollback()
        raise


def get_group_materials(
    db: Session,
    group_id: int,
):
    return (
        db.query(
            GroupMaterial,
        )
        .filter(
            GroupMaterial.group_id
            == group_id,
            GroupMaterial.status
            == "active",
            GroupMaterial.is_active.is_(
                True,
            ),
        )
        .order_by(
            GroupMaterial.updated_at.desc(),
            GroupMaterial.created_at.desc(),
        )
        .all()
    )


def get_admin_group_materials(
    db: Session,
    *,
    group_id: int | None = None,
    status: str | None = None,
):
    query = (
        db.query(
            GroupMaterial,
        )
    )

    if group_id is not None:
        query = query.filter(
            GroupMaterial.group_id
            == group_id,
        )

    if status is not None:
        if status not in {
            "active",
            "hidden",
            "removed",
        }:
            raise ValueError(
                "Stato del materiale non valido.",
            )

        query = query.filter(
            GroupMaterial.status
            == status,
        )

    return (
        query
        .order_by(
            GroupMaterial.updated_at.desc(),
            GroupMaterial.created_at.desc(),
        )
        .all()
    )


def get_public_group_materials(
    db: Session,
    group_id: int,
):
    group = (
        db.query(
            StudyGroup,
        )
        .filter(
            StudyGroup.id
            == group_id,
            StudyGroup.is_private.is_(
                False,
            ),
            StudyGroup.status
            == "active",
        )
        .first()
    )

    if group is None:
        return None

    return get_group_materials(
        db,
        group_id,
    )


def get_group_material_by_id(
    db: Session,
    material_id: int,
    *,
    include_removed: bool = False,
):
    query = (
        db.query(
            GroupMaterial,
        )
        .filter(
            GroupMaterial.id
            == material_id,
        )
    )

    if not include_removed:
        query = query.filter(
            GroupMaterial.status
            != "removed",
            GroupMaterial.is_active.is_(
                True,
            ),
        )

    return query.first()


def get_admin_group_material_by_id(
    db: Session,
    material_id: int,
):
    return (
        db.query(
            GroupMaterial,
        )
        .filter(
            GroupMaterial.id
            == material_id,
        )
        .first()
    )


def get_public_group_material_by_id(
    db: Session,
    material_id: int,
):
    return (
        db.query(
            GroupMaterial,
        )
        .join(
            StudyGroup,
            StudyGroup.id
            == GroupMaterial.group_id,
        )
        .filter(
            GroupMaterial.id
            == material_id,
            GroupMaterial.status
            == "active",
            GroupMaterial.is_active.is_(
                True,
            ),
            StudyGroup.is_private.is_(
                False,
            ),
            StudyGroup.status
            == "active",
        )
        .first()
    )


def is_material_from_public_group(
    db: Session,
    material_id: int,
) -> bool:
    material = (
        get_public_group_material_by_id(
            db,
            material_id,
        )
    )

    return material is not None


def hide_group_material(
    db: Session,
    material: GroupMaterial,
    *,
    updated_by: int,
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

    material.is_active = (
        True
    )

    material.updated_by = (
        updated_by
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


def restore_group_material(
    db: Session,
    material: GroupMaterial,
    *,
    updated_by: int,
):
    if material.status == "removed":
        raise ValueError(
            "Il materiale è stato rimosso.",
        )

    material.status = (
        "active"
    )

    material.is_active = (
        True
    )

    material.updated_by = (
        updated_by
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


async def delete_group_material(
    db: Session,
    material: GroupMaterial,
    *,
    removed_by: int | None = None,
    removal_reason: str | None = None,
):
    if material.status == "removed":
        return material

    material.status = (
        "removed"
    )

    material.is_active = (
        False
    )

    material.removed_by = (
        removed_by
    )

    material.removed_at = (
        utc_now()
    )

    material.removal_reason = (
        removal_reason.strip()
        if (
            removal_reason is not None
            and removal_reason.strip()
        )
        else None
    )

    material.updated_by = (
        removed_by
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