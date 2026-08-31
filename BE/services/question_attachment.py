import re
import uuid

from pathlib import Path

from schemas.question_attachment import (
    QuestionAttachmentCompleteRequest,
    QuestionAttachmentUploadRequest,
    QuestionAttachmentVerifyRequest,
)

from services.upload_authorization import (
    create_upload_authorization,
    decode_upload_authorization,
    require_upload_authorization_fields,
    require_upload_authorization_type,
    require_upload_authorization_user,
)


MAX_QUESTION_ATTACHMENT_SIZE = (
    50
    * 1024
    * 1024
)

MAX_ORIGINAL_NAME_LENGTH = 255

SHA256_PATTERN = re.compile(
    r"^[a-fA-F0-9]{64}$"
)


ALLOWED_IMAGE_TYPES = {
    "image/png",
    "image/jpeg",
    "image/webp",
}


ALLOWED_DOCUMENT_TYPES = {
    "application/pdf",
    "text/plain",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation",
}


ALLOWED_CONTENT_TYPES = (
    ALLOWED_IMAGE_TYPES
    |
    ALLOWED_DOCUMENT_TYPES
)


ALLOWED_EXTENSIONS_BY_MIME = {
    "image/png": {
        ".png",
    },
    "image/jpeg": {
        ".jpg",
        ".jpeg",
    },
    "image/webp": {
        ".webp",
    },
    "application/pdf": {
        ".pdf",
    },
    "text/plain": {
        ".txt",
    },
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document": {
        ".docx",
    },
    "application/vnd.openxmlformats-officedocument.presentationml.presentation": {
        ".pptx",
    },
}


def _normalize_slug(
    value: str,
) -> str:
    if not isinstance(
        value,
        str,
    ):
        raise ValueError(
            "Percorso non valido."
        )

    value = (
        value
        .strip()
        .lower()
    )

    if (
        not value
        or ".." in value
        or "/" in value
        or "\\" in value
        or "\x00" in value
    ):
        raise ValueError(
            "Percorso non valido."
        )

    value = re.sub(
        r"[\s\-]+",
        "_",
        value,
    )

    value = re.sub(
        r"[^a-z0-9_]",
        "",
        value,
    )

    value = re.sub(
        r"_+",
        "_",
        value,
    )

    value = value.strip(
        "_"
    )

    if not value:
        raise ValueError(
            "Percorso non valido."
        )

    return value


def _normalize_question_id(
    question_id: str,
) -> str:
    return _normalize_slug(
        str(
            question_id
        )
    )


def validate_question_attachment_original_name(
    original_name: str,
) -> str:
    if not isinstance(
        original_name,
        str,
    ):
        raise ValueError(
            "Nome file non valido."
        )

    original_name = (
        original_name.strip()
    )

    if (
        not original_name
        or len(
            original_name
        ) > MAX_ORIGINAL_NAME_LENGTH
        or "/" in original_name
        or "\\" in original_name
        or "\x00" in original_name
        or original_name in {
            ".",
            "..",
        }
    ):
        raise ValueError(
            "Nome file non valido."
        )

    return original_name


def validate_question_attachment_mime_type(
    mime_type: str,
) -> str:
    if not isinstance(
        mime_type,
        str,
    ):
        raise ValueError(
            "Tipo di file non supportato."
        )

    mime_type = (
        mime_type
        .strip()
        .lower()
    )

    if (
        mime_type
        not in ALLOWED_CONTENT_TYPES
    ):
        raise ValueError(
            "Tipo di file non supportato."
        )

    return mime_type


def validate_question_attachment_extension(
    original_name: str,
    mime_type: str,
) -> str:
    original_name = (
        validate_question_attachment_original_name(
            original_name
        )
    )

    mime_type = (
        validate_question_attachment_mime_type(
            mime_type
        )
    )

    suffix = (
        Path(
            original_name
        )
        .suffix
        .lower()
    )

    if (
        suffix
        not in ALLOWED_EXTENSIONS_BY_MIME[
            mime_type
        ]
    ):
        raise ValueError(
            "L'estensione del file non corrisponde al tipo di contenuto."
        )

    return suffix


def validate_question_attachment_size(
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
            "Dimensione file non valida."
        )

    if (
        size
        > MAX_QUESTION_ATTACHMENT_SIZE
    ):
        raise ValueError(
            "Il file supera la dimensione massima consentita di 50 MB."
        )

    return size


def validate_question_attachment_hash(
    file_hash: str,
) -> str:
    if not isinstance(
        file_hash,
        str,
    ):
        raise ValueError(
            "Hash del file non valido."
        )

    file_hash = (
        file_hash
        .strip()
        .lower()
    )

    if not SHA256_PATTERN.fullmatch(
        file_hash
    ):
        raise ValueError(
            "Hash del file non valido."
        )

    return file_hash


def get_question_attachment_type(
    mime_type: str,
) -> str:
    mime_type = (
        validate_question_attachment_mime_type(
            mime_type
        )
    )

    if mime_type in ALLOWED_IMAGE_TYPES:
        return "image"

    return "document"


def generate_question_attachment_path(
    *,
    user_id: int,
    department: str,
    course: str,
    subject: str,
    original_name: str,
    mime_type: str,
    question_id: str | None = None,
) -> tuple[
    str,
    str,
]:
    if user_id <= 0:
        raise ValueError(
            "Utente non valido."
        )

    department_slug = (
        _normalize_slug(
            department
        )
    )

    course_slug = (
        _normalize_slug(
            course
        )
    )

    subject_slug = (
        _normalize_slug(
            subject
        )
    )

    suffix = (
        validate_question_attachment_extension(
            original_name,
            mime_type,
        )
    )

    attachment_id = (
        uuid.uuid4().hex
    )

    stored_name = (
        f"{attachment_id}"
        f"{suffix}"
    )

    if question_id is not None:
        question_slug = (
            _normalize_question_id(
                question_id
            )
        )

        pathname = (
            f"questions/"
            f"{department_slug}/"
            f"{course_slug}/"
            f"{subject_slug}/"
            f"{question_slug}/"
            f"{stored_name}"
        )

    else:
        pathname = (
            f"questions/tmp/"
            f"{user_id}/"
            f"{department_slug}/"
            f"{course_slug}/"
            f"{subject_slug}/"
            f"{stored_name}"
        )

    return (
        attachment_id,
        pathname,
    )


def prepare_question_attachment_upload(
    *,
    user_id: int,
    data: QuestionAttachmentUploadRequest,
):
    if user_id <= 0:
        raise ValueError(
            "Utente non valido."
        )

    original_name = (
        validate_question_attachment_original_name(
            data.original_name
        )
    )

    mime_type = (
        validate_question_attachment_mime_type(
            data.mime_type
        )
    )

    validate_question_attachment_extension(
        original_name,
        mime_type,
    )

    size = (
        validate_question_attachment_size(
            data.size
        )
    )

    file_hash = (
        validate_question_attachment_hash(
            data.file_hash
        )
    )

    attachment_type = (
        get_question_attachment_type(
            mime_type
        )
    )

    attachment_id, pathname = (
        generate_question_attachment_path(
            user_id=user_id,
            department=data.department,
            course=data.course,
            subject=data.subject,
            original_name=original_name,
            mime_type=mime_type,
            question_id=data.question_id,
        )
    )

    payload = {
        "v":
            1,
        "type":
            "question_attachment",
        "uid":
            user_id,
        "aid":
            attachment_id,
        "department":
            data.department.strip(),
        "course":
            data.course.strip(),
        "subject":
            data.subject.strip(),
        "question_id":
            data.question_id,
        "original_name":
            original_name,
        "mime_type":
            mime_type,
        "size":
            size,
        "file_hash":
            file_hash,
        "pathname":
            pathname,
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
        "attachment_id":
            attachment_id,
        "attachment_type":
            attachment_type,
        "original_name":
            original_name,
        "mime_type":
            mime_type,
        "pathname":
            pathname,
        "max_file_size":
            MAX_QUESTION_ATTACHMENT_SIZE,
        "file_hash":
            file_hash,
        "size":
            size,
        "upload_token":
            upload_token,
        "valid_until":
            expires_at
            * 1000,
    }


def verify_question_attachment_upload(
    *,
    user_id: int,
    data: QuestionAttachmentVerifyRequest,
):
    payload = (
        decode_upload_authorization(
            data.upload_token
        )
    )

    require_upload_authorization_type(
        payload,
        "question_attachment",
    )

    require_upload_authorization_user(
        payload,
        user_id,
    )

    mime_type = (
        validate_question_attachment_mime_type(
            data.mime_type
        )
    )

    size = (
        validate_question_attachment_size(
            data.size
        )
    )

    file_hash = (
        validate_question_attachment_hash(
            data.file_hash
        )
    )

    require_upload_authorization_fields(
        payload,
        {
            "aid":
                data.attachment_id,
            "pathname":
                data.pathname,
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
        "pathname":
            data.pathname,
        "attachment_id":
            data.attachment_id,
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


def complete_question_attachment(
    *,
    user_id: int,
    data: QuestionAttachmentCompleteRequest,
):
    payload = (
        decode_upload_authorization(
            data.upload_token
        )
    )

    require_upload_authorization_type(
        payload,
        "question_attachment",
    )

    require_upload_authorization_user(
        payload,
        user_id,
    )

    original_name = (
        validate_question_attachment_original_name(
            data.original_name
        )
    )

    mime_type = (
        validate_question_attachment_mime_type(
            data.mime_type
        )
    )

    validate_question_attachment_extension(
        original_name,
        mime_type,
    )

    size = (
        validate_question_attachment_size(
            data.size
        )
    )

    file_hash = (
        validate_question_attachment_hash(
            data.file_hash
        )
    )

    require_upload_authorization_fields(
        payload,
        {
            "aid":
                data.attachment_id,
            "department":
                data.department.strip(),
            "course":
                data.course.strip(),
            "subject":
                data.subject.strip(),
            "original_name":
                original_name,
            "mime_type":
                mime_type,
            "size":
                size,
            "file_hash":
                file_hash,
            "pathname":
                data.pathname,
        },
    )

    attachment_type = (
        get_question_attachment_type(
            mime_type
        )
    )

    return {
        "id":
            data.attachment_id,
        "type":
            attachment_type,
        "original_name":
            original_name,
        "mime_type":
            mime_type,
        "stored_name":
            data.pathname,
    }