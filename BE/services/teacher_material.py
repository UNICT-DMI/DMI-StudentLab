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

from models.subject import (
    Subject,
)

from models.teacher_material import (
    TeacherMaterial,
)

from models.user import (
    User,
)

from schemas.teacher_material import (
    TeacherMaterialCompleteRequest,
    TeacherMaterialUpdate,
    TeacherMaterialUploadRequest,
    TeacherMaterialVerifyRequest,
)

from services.teacher_assignment import (
    get_verified_teacher_assignment,
)

from services.upload_authorization import (
    create_upload_authorization,
    decode_upload_authorization,
    require_upload_authorization_fields,
    require_upload_authorization_type,
    require_upload_authorization_user,
)


MAX_TEACHER_MATERIAL_SIZE = (
    250
    * 1024
    * 1024
)


ALLOWED_TEACHER_MATERIAL_VISIBILITY = {
    "students",
    "private",
}


ALLOWED_TEACHER_MIME_TYPES = {
    "application/pdf",
    "application/zip",
    "application/x-zip-compressed",
    "application/msword",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/vnd.ms-powerpoint",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    "application/vnd.ms-excel",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "text/plain",
    "text/csv",
    "image/jpeg",
    "image/png",
    "image/webp",
}


ALLOWED_TEACHER_EXTENSIONS_BY_MIME = {
    "application/pdf": {
        ".pdf",
    },
    "application/zip": {
        ".zip",
    },
    "application/x-zip-compressed": {
        ".zip",
    },
    "application/msword": {
        ".doc",
    },
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document": {
        ".docx",
    },
    "application/vnd.ms-powerpoint": {
        ".ppt",
    },
    "application/vnd.openxmlformats-officedocument.presentationml.presentation": {
        ".pptx",
    },
    "application/vnd.ms-excel": {
        ".xls",
    },
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": {
        ".xlsx",
    },
    "text/plain": {
        ".txt",
    },
    "text/csv": {
        ".csv",
    },
    "image/jpeg": {
        ".jpg",
        ".jpeg",
    },
    "image/png": {
        ".png",
    },
    "image/webp": {
        ".webp",
    },
}


def utc_now():
    return datetime.now(
        timezone.utc,
    )


def require_teacher_subject(
    db: Session,
    teacher_id: int,
    subject_id: int,
):
    subject = (
        db.query(
            Subject,
        )
        .filter(
            Subject.id
            == subject_id,
            Subject.is_active.is_(
                True,
            ),
        )
        .first()
    )

    if subject is None:
        raise ValueError(
            "Materia non trovata.",
        )

    assignment = (
        get_verified_teacher_assignment(
            db,
            teacher_id,
            subject_id,
        )
    )

    if assignment is None:
        raise PermissionError(
            "Il docente non possiede un insegnamento verificato per questa materia.",
        )

    return subject


def validate_teacher_material_size(
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

    if (
        size
        > MAX_TEACHER_MATERIAL_SIZE
    ):
        raise ValueError(
            "Il file supera la dimensione massima consentita di 250 MB.",
        )

    return size


def validate_teacher_material_mime_type(
    mime_type: str,
) -> str:
    if not isinstance(
        mime_type,
        str,
    ):
        raise ValueError(
            "Tipo di file non consentito.",
        )

    value = (
        mime_type
        .split(
            ";",
            1,
        )[0]
        .strip()
        .lower()
    )

    if (
        value
        not in ALLOWED_TEACHER_MIME_TYPES
    ):
        raise ValueError(
            "Tipo di file non consentito.",
        )

    return value


def validate_teacher_original_name(
    original_name: str,
) -> str:
    if not isinstance(
        original_name,
        str,
    ):
        raise ValueError(
            "Nome del file non valido.",
        )

    value = (
        original_name.strip()
    )

    if (
        not value
        or len(
            value
        ) > 255
        or "/" in value
        or "\\" in value
        or "\x00" in value
        or value in {
            ".",
            "..",
        }
    ):
        raise ValueError(
            "Nome del file non valido.",
        )

    if (
        Path(
            value
        ).name
        != value
    ):
        raise ValueError(
            "Nome del file non valido.",
        )

    return value


def validate_teacher_material_extension(
    original_name: str,
    mime_type: str,
) -> str:
    original_name = (
        validate_teacher_original_name(
            original_name
        )
    )

    mime_type = (
        validate_teacher_material_mime_type(
            mime_type
        )
    )

    extension = (
        Path(
            original_name
        )
        .suffix
        .lower()
    )

    if (
        extension
        not in ALLOWED_TEACHER_EXTENSIONS_BY_MIME[
            mime_type
        ]
    ):
        raise ValueError(
            "L'estensione del file non corrisponde al tipo di contenuto.",
        )

    return extension


def normalize_teacher_file_hash(
    file_hash: str | None,
) -> str | None:
    if file_hash is None:
        return None

    if not isinstance(
        file_hash,
        str,
    ):
        raise ValueError(
            "Hash del file non valido.",
        )

    value = (
        file_hash
        .strip()
        .lower()
    )

    if not value:
        return None

    if len(
        value
    ) != 64:
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


def generate_teacher_material_stored_name(
    teacher_id: int,
    subject_id: int,
    original_name: str,
    mime_type: str | None = None,
):
    if teacher_id <= 0:
        raise ValueError(
            "Docente non valido.",
        )

    if subject_id <= 0:
        raise ValueError(
            "Materia non valida.",
        )

    original_name = (
        validate_teacher_original_name(
            original_name
        )
    )

    if mime_type is not None:
        extension = (
            validate_teacher_material_extension(
                original_name,
                mime_type,
            )
        )
    else:
        extension = (
            Path(
                original_name
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
        f"teacher-materials/"
        f"{teacher_id}/"
        f"{subject_id}/"
        f"{unique_id}"
        f"{extension}"
    )


def validate_teacher_material_stored_name(
    teacher_id: int,
    subject_id: int,
    stored_name: str,
) -> str:
    if not isinstance(
        stored_name,
        str,
    ):
        raise ValueError(
            "Percorso storage non valido.",
        )

    stored_name = (
        stored_name.strip()
    )

    expected_prefix = (
        f"teacher-materials/"
        f"{teacher_id}/"
        f"{subject_id}/"
    )

    if (
        not stored_name.startswith(
            expected_prefix,
        )
        or stored_name.startswith(
            "/"
        )
        or ".." in stored_name
        or "\\" in stored_name
        or "\x00" in stored_name
        or "\r" in stored_name
        or "\n" in stored_name
    ):
        raise ValueError(
            "Percorso storage non valido.",
        )

    relative_name = (
        stored_name[
            len(
                expected_prefix
            ):
        ]
    )

    if (
        not relative_name
        or "/" in relative_name
    ):
        raise ValueError(
            "Percorso storage non valido.",
        )

    return stored_name


def ensure_teacher_material_not_duplicate(
    db: Session,
    teacher_id: int,
    subject_id: int,
    file_hash: str | None,
    *,
    exclude_material_id: int | None = None,
):
    normalized_hash = (
        normalize_teacher_file_hash(
            file_hash,
        )
    )

    if normalized_hash is None:
        return

    query = (
        db.query(
            TeacherMaterial,
        )
        .filter(
            TeacherMaterial.uploaded_by
            == teacher_id,
            TeacherMaterial.subject_id
            == subject_id,
            TeacherMaterial.file_hash
            == normalized_hash,
            TeacherMaterial.status
            != "removed",
            TeacherMaterial.is_active.is_(
                True,
            ),
        )
    )

    if exclude_material_id is not None:
        query = query.filter(
            TeacherMaterial.id
            != exclude_material_id,
        )

    if query.first() is not None:
        raise ValueError(
            "Questo file è già presente per questa materia.",
        )


def prepare_teacher_material_upload(
    db: Session,
    *,
    teacher_id: int,
    data: TeacherMaterialUploadRequest,
):
    require_teacher_subject(
        db,
        teacher_id,
        data.subject_id,
    )

    original_name = (
        validate_teacher_original_name(
            data.original_name
        )
    )

    mime_type = (
        validate_teacher_material_mime_type(
            data.mime_type
        )
    )

    validate_teacher_material_extension(
        original_name,
        mime_type,
    )

    size = (
        validate_teacher_material_size(
            data.size
        )
    )

    file_hash = (
        normalize_teacher_file_hash(
            data.file_hash
        )
    )

    ensure_teacher_material_not_duplicate(
        db,
        teacher_id,
        data.subject_id,
        file_hash,
    )

    pathname = (
        generate_teacher_material_stored_name(
            teacher_id,
            data.subject_id,
            original_name,
            mime_type,
        )
    )

    payload = {
        "v":
            1,
        "type":
            "teacher_material",
        "uid":
            teacher_id,
        "subject_id":
            data.subject_id,
        "original_name":
            original_name,
        "pathname":
            pathname,
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
        "subject_id":
            data.subject_id,
        "uploaded_by":
            teacher_id,
        "original_name":
            original_name,
        "pathname":
            pathname,
        "mime_type":
            mime_type,
        "size":
            size,
        "file_hash":
            file_hash,
        "max_file_size":
            MAX_TEACHER_MATERIAL_SIZE,
        "upload_token":
            upload_token,
        "valid_until":
            expires_at
            * 1000,
    }


def verify_teacher_material_upload(
    *,
    teacher_id: int,
    data: TeacherMaterialVerifyRequest,
):
    payload = (
        decode_upload_authorization(
            data.upload_token
        )
    )

    require_upload_authorization_type(
        payload,
        "teacher_material",
    )

    require_upload_authorization_user(
        payload,
        teacher_id,
    )

    pathname = (
        validate_teacher_material_stored_name(
            teacher_id,
            data.subject_id,
            data.pathname,
        )
    )

    mime_type = (
        validate_teacher_material_mime_type(
            data.mime_type
        )
    )

    size = (
        validate_teacher_material_size(
            data.size
        )
    )

    file_hash = (
        normalize_teacher_file_hash(
            data.file_hash
        )
    )

    require_upload_authorization_fields(
        payload,
        {
            "subject_id":
                data.subject_id,
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
        "subject_id":
            data.subject_id,
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


def validate_teacher_material_completion(
    *,
    teacher_id: int,
    data: TeacherMaterialCompleteRequest,
):
    payload = (
        decode_upload_authorization(
            data.upload_token
        )
    )

    require_upload_authorization_type(
        payload,
        "teacher_material",
    )

    require_upload_authorization_user(
        payload,
        teacher_id,
    )

    original_name = (
        validate_teacher_original_name(
            data.original_name
        )
    )

    mime_type = (
        validate_teacher_material_mime_type(
            data.mime_type
        )
    )

    validate_teacher_material_extension(
        original_name,
        mime_type,
    )

    size = (
        validate_teacher_material_size(
            data.size
        )
    )

    file_hash = (
        normalize_teacher_file_hash(
            data.file_hash
        )
    )

    stored_name = (
        validate_teacher_material_stored_name(
            teacher_id,
            data.subject_id,
            data.stored_name,
        )
    )

    require_upload_authorization_fields(
        payload,
        {
            "subject_id":
                data.subject_id,
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
        "subject_id":
            data.subject_id,
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


def create_teacher_material(
    db: Session,
    teacher: User,
    request: TeacherMaterialCompleteRequest,
):
    require_teacher_subject(
        db,
        teacher.id,
        request.subject_id,
    )

    completion = (
        validate_teacher_material_completion(
            teacher_id=teacher.id,
            data=request,
        )
    )

    ensure_teacher_material_not_duplicate(
        db,
        teacher.id,
        request.subject_id,
        completion[
            "file_hash"
        ],
    )

    visibility = (
        request.visibility
        .strip()
        .lower()
    )

    if (
        visibility
        not in ALLOWED_TEACHER_MATERIAL_VISIBILITY
    ):
        raise ValueError(
            "Visibilità materiale non valida.",
        )

    title = (
        request.title.strip()
    )

    if not title:
        raise ValueError(
            "Titolo del materiale obbligatorio.",
        )

    material = TeacherMaterial(
        subject_id=(
            completion[
                "subject_id"
            ]
        ),
        uploaded_by=teacher.id,
        title=title,
        description=(
            request.description
            .strip()
        ),
        original_name=(
            completion[
                "original_name"
            ]
        ),
        stored_name=(
            completion[
                "stored_name"
            ]
        ),
        file_path=(
            completion[
                "file_path"
            ]
        ),
        mime_type=(
            completion[
                "mime_type"
            ]
        ),
        size=(
            completion[
                "size"
            ]
        ),
        file_hash=(
            completion[
                "file_hash"
            ]
        ),
        version=1,
        status="active",
        visibility=visibility,
        is_active=True,
        updated_by=teacher.id,
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
            "Impossibile creare il materiale.",
        ) from exception

    except Exception:
        db.rollback()
        raise


def get_teacher_materials(
    db: Session,
    teacher_id: int,
    *,
    include_removed: bool = False,
):
    query = (
        db.query(
            TeacherMaterial,
        )
        .filter(
            TeacherMaterial.uploaded_by
            == teacher_id,
        )
    )

    if not include_removed:
        query = query.filter(
            TeacherMaterial.status
            != "removed",
        )

    return (
        query
        .order_by(
            TeacherMaterial.updated_at.desc(),
            TeacherMaterial.created_at.desc(),
        )
        .all()
    )


def get_teacher_material_by_id(
    db: Session,
    material_id: int,
    *,
    include_removed: bool = False,
):
    query = (
        db.query(
            TeacherMaterial,
        )
        .filter(
            TeacherMaterial.id
            == material_id,
        )
    )

    if not include_removed:
        query = query.filter(
            TeacherMaterial.status
            != "removed",
        )

    return query.first()


def get_admin_teacher_material_by_id(
    db: Session,
    material_id: int,
):
    return (
        db.query(
            TeacherMaterial,
        )
        .filter(
            TeacherMaterial.id
            == material_id,
        )
        .first()
    )


def get_admin_teacher_materials(
    db: Session,
    *,
    teacher_id: int | None = None,
    subject_id: int | None = None,
    status: str | None = None,
):
    query = (
        db.query(
            TeacherMaterial,
        )
    )

    if teacher_id is not None:
        query = query.filter(
            TeacherMaterial.uploaded_by
            == teacher_id,
        )

    if subject_id is not None:
        query = query.filter(
            TeacherMaterial.subject_id
            == subject_id,
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
            TeacherMaterial.status
            == status,
        )

    return (
        query
        .order_by(
            TeacherMaterial.updated_at.desc(),
            TeacherMaterial.created_at.desc(),
        )
        .all()
    )


def require_teacher_material_owner(
    material: TeacherMaterial,
    teacher_id: int,
):
    if (
        material.uploaded_by
        != teacher_id
    ):
        raise PermissionError(
            "Non puoi gestire questo materiale.",
        )

    return material


def update_teacher_material(
    db: Session,
    material: TeacherMaterial,
    teacher: User,
    request: TeacherMaterialUpdate,
):
    require_teacher_material_owner(
        material,
        teacher.id,
    )

    if material.status == "removed":
        raise ValueError(
            "Il materiale è stato rimosso.",
        )

    values = request.model_dump(
        exclude_unset=True,
    )

    if (
        "title" in values
        and values[
            "title"
        ] is not None
    ):
        title = (
            values[
                "title"
            ]
            .strip()
        )

        if not title:
            raise ValueError(
                "Titolo del materiale obbligatorio.",
            )

        values[
            "title"
        ] = title

    if (
        "description" in values
        and values[
            "description"
        ] is not None
    ):
        values[
            "description"
        ] = (
            values[
                "description"
            ]
            .strip()
        )

    if (
        "visibility" in values
        and values[
            "visibility"
        ] is not None
    ):
        visibility = (
            values[
                "visibility"
            ]
            .strip()
            .lower()
        )

        if (
            visibility
            not in ALLOWED_TEACHER_MATERIAL_VISIBILITY
        ):
            raise ValueError(
                "Visibilità materiale non valida.",
            )

        values[
            "visibility"
        ] = visibility

    protected_fields = {
        "id",
        "subject_id",
        "uploaded_by",
        "original_name",
        "stored_name",
        "file_path",
        "mime_type",
        "size",
        "file_hash",
        "version",
        "status",
        "is_active",
        "updated_by",
        "removed_by",
        "removed_at",
        "removal_reason",
        "created_at",
        "updated_at",
    }

    for key, value in (
        values.items()
    ):
        if key in protected_fields:
            continue

        setattr(
            material,
            key,
            value,
        )

    material.updated_by = (
        teacher.id
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


def replace_teacher_material_file(
    db: Session,
    material: TeacherMaterial,
    teacher: User,
    *,
    original_name: str,
    stored_name: str,
    file_path: str,
    mime_type: str,
    size: int,
    file_hash: str | None,
):
    require_teacher_material_owner(
        material,
        teacher.id,
    )

    if material.status == "removed":
        raise ValueError(
            "Il materiale è stato rimosso.",
        )

    require_teacher_subject(
        db,
        teacher.id,
        material.subject_id,
    )

    original_name = (
        validate_teacher_original_name(
            original_name
        )
    )

    size = (
        validate_teacher_material_size(
            size
        )
    )

    mime_type = (
        validate_teacher_material_mime_type(
            mime_type
        )
    )

    validate_teacher_material_extension(
        original_name,
        mime_type,
    )

    stored_name = (
        validate_teacher_material_stored_name(
            teacher.id,
            material.subject_id,
            stored_name,
        )
    )

    file_path = stored_name

    normalized_hash = (
        normalize_teacher_file_hash(
            file_hash
        )
    )

    ensure_teacher_material_not_duplicate(
        db,
        teacher.id,
        material.subject_id,
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

    material.status = (
        "active"
    )

    material.is_active = (
        True
    )

    material.updated_by = (
        teacher.id
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
            "Questo file è già presente per questa materia.",
        ) from exception

    except Exception:
        db.rollback()
        raise


def hide_teacher_material(
    db: Session,
    material: TeacherMaterial,
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


def restore_teacher_material(
    db: Session,
    material: TeacherMaterial,
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


def remove_teacher_material(
    db: Session,
    material: TeacherMaterial,
    *,
    removed_by: int,
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


def delete_teacher_material(
    db: Session,
    material: TeacherMaterial,
    teacher: User,
):
    require_teacher_material_owner(
        material,
        teacher.id,
    )

    return remove_teacher_material(
        db,
        material,
        removed_by=teacher.id,
        removal_reason=(
            "Rimosso dal docente."
        ),
    )


def get_student_teacher_materials(
    db: Session,
    subject_id: int,
):
    return (
        db.query(
            TeacherMaterial,
        )
        .join(
            User,
            User.id
            == TeacherMaterial.uploaded_by,
        )
        .filter(
            TeacherMaterial.subject_id
            == subject_id,
            TeacherMaterial.visibility
            == "students",
            TeacherMaterial.status
            == "active",
            TeacherMaterial.is_active.is_(
                True,
            ),
            User.role
            == "teacher",
            User.teacher_verification_status
            == "verified",
            User.is_active.is_(
                True,
            ),
        )
        .order_by(
            TeacherMaterial.updated_at
            .desc(),
            TeacherMaterial.created_at
            .desc(),
        )
        .all()
    )