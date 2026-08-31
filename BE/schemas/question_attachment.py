import re

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
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

ATTACHMENT_ID_PATTERN = re.compile(
    r"^[a-fA-F0-9]{32}$"
)


def _validate_context_value(
    value,
):
    if not isinstance(
        value,
        str,
    ):
        raise ValueError(
            "Valore non valido."
        )

    value = value.strip()

    if (
        not value
        or "\x00" in value
    ):
        raise ValueError(
            "Valore non valido."
        )

    return value


def _validate_original_name(
    value,
):
    if not isinstance(
        value,
        str,
    ):
        raise ValueError(
            "Nome file non valido."
        )

    value = value.strip()

    if (
        not value
        or "/" in value
        or "\\" in value
        or "\x00" in value
        or value in {
            ".",
            "..",
        }
    ):
        raise ValueError(
            "Nome file non valido."
        )

    return value


def _validate_mime_type(
    value,
):
    if not isinstance(
        value,
        str,
    ):
        raise ValueError(
            "Tipo di file non valido."
        )

    value = (
        value
        .strip()
        .lower()
    )

    if not value:
        raise ValueError(
            "Tipo di file non valido."
        )

    return value


def _validate_file_hash(
    value,
):
    if not isinstance(
        value,
        str,
    ):
        raise ValueError(
            "Hash del file non valido."
        )

    value = (
        value
        .strip()
        .lower()
    )

    if not SHA256_PATTERN.fullmatch(
        value
    ):
        raise ValueError(
            "Hash del file non valido."
        )

    return value


def _validate_attachment_id(
    value,
):
    if not isinstance(
        value,
        str,
    ):
        raise ValueError(
            "Identificativo allegato non valido."
        )

    value = (
        value
        .strip()
        .lower()
    )

    if not ATTACHMENT_ID_PATTERN.fullmatch(
        value
    ):
        raise ValueError(
            "Identificativo allegato non valido."
        )

    return value


def _validate_pathname(
    value,
):
    if not isinstance(
        value,
        str,
    ):
        raise ValueError(
            "Percorso allegato non valido."
        )

    value = value.strip()

    if (
        not value.startswith(
            "questions/"
        )
        or value.startswith(
            "/"
        )
        or ".." in value
        or "\\" in value
        or "\x00" in value
        or "\r" in value
        or "\n" in value
    ):
        raise ValueError(
            "Percorso allegato non valido."
        )

    return value


class QuestionAttachmentUploadRequest(
    BaseModel
):
    department: str = Field(
        min_length=1,
        max_length=100,
    )
    course: str = Field(
        min_length=1,
        max_length=100,
    )
    subject: str = Field(
        min_length=1,
        max_length=200,
    )
    question_id: str | None = Field(
        default=None,
        max_length=100,
    )
    original_name: str = Field(
        min_length=1,
        max_length=MAX_ORIGINAL_NAME_LENGTH,
    )
    mime_type: str = Field(
        min_length=1,
        max_length=150,
    )
    size: int = Field(
        gt=0,
        le=MAX_QUESTION_ATTACHMENT_SIZE,
    )
    file_hash: str = Field(
        min_length=64,
        max_length=64,
    )

    @field_validator(
        "department",
        "course",
        "subject",
        mode="before",
    )
    @classmethod
    def validate_context(
        cls,
        value,
    ):
        return _validate_context_value(
            value
        )

    @field_validator(
        "question_id",
        mode="before",
    )
    @classmethod
    def validate_question_id(
        cls,
        value,
    ):
        if value is None:
            return None

        value = str(
            value
        ).strip()

        if not value:
            return None

        if (
            "/" in value
            or "\\" in value
            or ".." in value
            or "\x00" in value
        ):
            raise ValueError(
                "Identificativo domanda non valido."
            )

        return value

    @field_validator(
        "original_name",
        mode="before",
    )
    @classmethod
    def validate_original_name(
        cls,
        value,
    ):
        return _validate_original_name(
            value
        )

    @field_validator(
        "mime_type",
        mode="before",
    )
    @classmethod
    def validate_mime_type(
        cls,
        value,
    ):
        return _validate_mime_type(
            value
        )

    @field_validator(
        "file_hash",
        mode="before",
    )
    @classmethod
    def validate_file_hash(
        cls,
        value,
    ):
        return _validate_file_hash(
            value
        )


class QuestionAttachmentUploadResponse(
    BaseModel
):
    allowed: bool
    attachment_id: str
    attachment_type: str
    original_name: str
    mime_type: str
    pathname: str
    max_file_size: int
    file_hash: str
    size: int
    upload_token: str
    valid_until: int

    @field_validator(
        "attachment_id",
        mode="before",
    )
    @classmethod
    def validate_attachment_id(
        cls,
        value,
    ):
        return _validate_attachment_id(
            value
        )

    @field_validator(
        "pathname",
        mode="before",
    )
    @classmethod
    def validate_pathname(
        cls,
        value,
    ):
        return _validate_pathname(
            value
        )

    @field_validator(
        "file_hash",
        mode="before",
    )
    @classmethod
    def validate_file_hash(
        cls,
        value,
    ):
        return _validate_file_hash(
            value
        )

    @field_validator(
        "attachment_type",
    )
    @classmethod
    def validate_attachment_type(
        cls,
        value: str,
    ):
        if value not in {
            "image",
            "document",
        }:
            raise ValueError(
                "Tipo allegato non valido."
            )

        return value


class QuestionAttachmentVerifyRequest(
    BaseModel
):
    upload_token: str = Field(
        min_length=20,
        max_length=10000,
    )
    pathname: str = Field(
        min_length=1,
        max_length=1024,
    )
    attachment_id: str = Field(
        min_length=32,
        max_length=32,
    )
    mime_type: str = Field(
        min_length=1,
        max_length=150,
    )
    size: int = Field(
        gt=0,
        le=MAX_QUESTION_ATTACHMENT_SIZE,
    )
    file_hash: str = Field(
        min_length=64,
        max_length=64,
    )

    @field_validator(
        "pathname",
        mode="before",
    )
    @classmethod
    def validate_pathname(
        cls,
        value,
    ):
        return _validate_pathname(
            value
        )

    @field_validator(
        "attachment_id",
        mode="before",
    )
    @classmethod
    def validate_attachment_id(
        cls,
        value,
    ):
        return _validate_attachment_id(
            value
        )

    @field_validator(
        "mime_type",
        mode="before",
    )
    @classmethod
    def validate_mime_type(
        cls,
        value,
    ):
        return _validate_mime_type(
            value
        )

    @field_validator(
        "file_hash",
        mode="before",
    )
    @classmethod
    def validate_file_hash(
        cls,
        value,
    ):
        return _validate_file_hash(
            value
        )


class QuestionAttachmentVerifyResponse(
    BaseModel
):
    allowed: bool
    pathname: str
    attachment_id: str
    mime_type: str
    size: int
    file_hash: str
    valid_until: int


class QuestionAttachmentCompleteRequest(
    BaseModel
):
    department: str = Field(
        min_length=1,
        max_length=100,
    )
    course: str = Field(
        min_length=1,
        max_length=100,
    )
    subject: str = Field(
        min_length=1,
        max_length=200,
    )
    attachment_id: str = Field(
        min_length=32,
        max_length=32,
    )
    original_name: str = Field(
        min_length=1,
        max_length=MAX_ORIGINAL_NAME_LENGTH,
    )
    mime_type: str = Field(
        min_length=1,
        max_length=150,
    )
    pathname: str = Field(
        min_length=1,
        max_length=1024,
    )
    size: int = Field(
        gt=0,
        le=MAX_QUESTION_ATTACHMENT_SIZE,
    )
    file_hash: str = Field(
        min_length=64,
        max_length=64,
    )
    upload_token: str = Field(
        min_length=20,
        max_length=10000,
    )

    @field_validator(
        "department",
        "course",
        "subject",
        mode="before",
    )
    @classmethod
    def validate_context(
        cls,
        value,
    ):
        return _validate_context_value(
            value
        )

    @field_validator(
        "attachment_id",
        mode="before",
    )
    @classmethod
    def validate_attachment_id(
        cls,
        value,
    ):
        return _validate_attachment_id(
            value
        )

    @field_validator(
        "original_name",
        mode="before",
    )
    @classmethod
    def validate_original_name(
        cls,
        value,
    ):
        return _validate_original_name(
            value
        )

    @field_validator(
        "mime_type",
        mode="before",
    )
    @classmethod
    def validate_mime_type(
        cls,
        value,
    ):
        return _validate_mime_type(
            value
        )

    @field_validator(
        "pathname",
        mode="before",
    )
    @classmethod
    def validate_pathname(
        cls,
        value,
    ):
        return _validate_pathname(
            value
        )

    @field_validator(
        "file_hash",
        mode="before",
    )
    @classmethod
    def validate_file_hash(
        cls,
        value,
    ):
        return _validate_file_hash(
            value
        )


class QuestionAttachmentCompleteResponse(
    BaseModel
):
    model_config = ConfigDict(
        from_attributes=True
    )

    id: str
    type: str
    original_name: str
    mime_type: str
    stored_name: str

    @field_validator(
        "id",
        mode="before",
    )
    @classmethod
    def validate_id(
        cls,
        value,
    ):
        return _validate_attachment_id(
            value
        )

    @field_validator(
        "stored_name",
        mode="before",
    )
    @classmethod
    def validate_stored_name(
        cls,
        value,
    ):
        return _validate_pathname(
            value
        )

    @field_validator(
        "type",
    )
    @classmethod
    def validate_type(
        cls,
        value: str,
    ):
        if value not in {
            "image",
            "document",
        }:
            raise ValueError(
                "Tipo allegato non valido."
            )

        return value