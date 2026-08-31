from datetime import datetime

from typing import Literal

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
)


TeacherMaterialVisibility = Literal[
    "students",
    "private",
]


TeacherMaterialStatus = Literal[
    "active",
    "hidden",
    "removed",
]


MAX_TEACHER_MATERIAL_SIZE = (
    250
    * 1024
    * 1024
)


def _normalize_original_name(
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


def _normalize_mime_type(
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
        .split(
            ";",
            1,
        )[0]
        .strip()
        .lower()
    )

    if not value:
        raise ValueError(
            "Tipo di file non valido."
        )

    return value


def _normalize_file_hash(
    value,
):
    if value is None:
        return None

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

    if not value:
        return None

    return value


def _normalize_stored_name(
    value,
):
    if not isinstance(
        value,
        str,
    ):
        raise ValueError(
            "Percorso storage non valido."
        )

    value = value.strip()

    if (
        not value
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
            "Percorso storage non valido."
        )

    return value


class TeacherMaterialUploadRequest(
    BaseModel,
):
    subject_id: int = Field(
        gt=0,
    )

    original_name: str = Field(
        min_length=1,
        max_length=255,
    )

    mime_type: str = Field(
        min_length=1,
        max_length=150,
    )

    size: int = Field(
        gt=0,
        le=MAX_TEACHER_MATERIAL_SIZE,
    )

    file_hash: str | None = Field(
        default=None,
        min_length=64,
        max_length=64,
        pattern=r"^[a-fA-F0-9]{64}$",
    )

    @field_validator(
        "original_name",
        mode="before",
    )
    @classmethod
    def normalize_original_name(
        cls,
        value,
    ):
        return _normalize_original_name(
            value
        )

    @field_validator(
        "mime_type",
        mode="before",
    )
    @classmethod
    def normalize_mime_type(
        cls,
        value,
    ):
        return _normalize_mime_type(
            value
        )

    @field_validator(
        "file_hash",
        mode="before",
    )
    @classmethod
    def normalize_file_hash(
        cls,
        value,
    ):
        return _normalize_file_hash(
            value
        )


class TeacherMaterialUploadResponse(
    BaseModel,
):
    allowed: bool
    subject_id: int
    uploaded_by: int
    original_name: str
    pathname: str
    mime_type: str
    size: int
    file_hash: str | None
    max_file_size: int
    upload_token: str
    valid_until: int


class TeacherMaterialVerifyRequest(
    BaseModel,
):
    subject_id: int = Field(
        gt=0,
    )

    pathname: str = Field(
        min_length=1,
        max_length=1000,
    )

    mime_type: str = Field(
        min_length=1,
        max_length=150,
    )

    size: int = Field(
        gt=0,
        le=MAX_TEACHER_MATERIAL_SIZE,
    )

    file_hash: str | None = Field(
        default=None,
        min_length=64,
        max_length=64,
        pattern=r"^[a-fA-F0-9]{64}$",
    )

    upload_token: str = Field(
        min_length=20,
        max_length=10000,
    )

    @field_validator(
        "pathname",
        mode="before",
    )
    @classmethod
    def normalize_pathname(
        cls,
        value,
    ):
        return _normalize_stored_name(
            value
        )

    @field_validator(
        "mime_type",
        mode="before",
    )
    @classmethod
    def normalize_mime_type(
        cls,
        value,
    ):
        return _normalize_mime_type(
            value
        )

    @field_validator(
        "file_hash",
        mode="before",
    )
    @classmethod
    def normalize_file_hash(
        cls,
        value,
    ):
        return _normalize_file_hash(
            value
        )


class TeacherMaterialVerifyResponse(
    BaseModel,
):
    allowed: bool
    subject_id: int
    pathname: str
    mime_type: str
    size: int
    file_hash: str | None
    valid_until: int


class TeacherMaterialCompleteRequest(
    BaseModel,
):
    subject_id: int = Field(
        gt=0,
    )

    title: str = Field(
        min_length=1,
        max_length=255,
    )

    description: str = Field(
        default="",
        max_length=5000,
    )

    original_name: str = Field(
        min_length=1,
        max_length=255,
    )

    stored_name: str = Field(
        min_length=1,
        max_length=1000,
    )

    file_path: str = Field(
        min_length=1,
        max_length=1000,
    )

    mime_type: str = Field(
        min_length=1,
        max_length=150,
    )

    size: int = Field(
        gt=0,
        le=MAX_TEACHER_MATERIAL_SIZE,
    )

    file_hash: str | None = Field(
        default=None,
        min_length=64,
        max_length=64,
        pattern=r"^[a-fA-F0-9]{64}$",
    )

    visibility: TeacherMaterialVisibility = (
        "students"
    )

    upload_token: str = Field(
        min_length=20,
        max_length=10000,
    )

    @field_validator(
        "original_name",
        mode="before",
    )
    @classmethod
    def normalize_original_name(
        cls,
        value,
    ):
        return _normalize_original_name(
            value
        )

    @field_validator(
        "stored_name",
        mode="before",
    )
    @classmethod
    def normalize_stored_name(
        cls,
        value,
    ):
        return _normalize_stored_name(
            value
        )

    @field_validator(
        "file_path",
        mode="before",
    )
    @classmethod
    def normalize_file_path(
        cls,
        value,
    ):
        if not isinstance(
            value,
            str,
        ):
            raise ValueError(
                "Percorso file non valido."
            )

        value = value.strip()

        if (
            not value
            or "\x00" in value
            or "\r" in value
            or "\n" in value
        ):
            raise ValueError(
                "Percorso file non valido."
            )

        return value

    @field_validator(
        "mime_type",
        mode="before",
    )
    @classmethod
    def normalize_mime_type(
        cls,
        value,
    ):
        return _normalize_mime_type(
            value
        )

    @field_validator(
        "file_hash",
        mode="before",
    )
    @classmethod
    def normalize_file_hash(
        cls,
        value,
    ):
        return _normalize_file_hash(
            value
        )


class TeacherMaterialUpdate(
    BaseModel,
):
    title: str | None = Field(
        default=None,
        min_length=1,
        max_length=255,
    )

    description: str | None = Field(
        default=None,
        max_length=5000,
    )

    visibility: TeacherMaterialVisibility | None = (
        None
    )


class TeacherMaterialSubjectResponse(
    BaseModel,
):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    code: str
    name: str


class TeacherMaterialResponse(
    BaseModel,
):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    subject_id: int
    uploaded_by: int
    title: str
    description: str
    original_name: str
    stored_name: str
    file_path: str
    mime_type: str
    size: int
    file_hash: str | None
    version: int
    status: TeacherMaterialStatus
    visibility: TeacherMaterialVisibility
    is_active: bool
    updated_by: int | None
    removed_by: int | None
    removed_at: datetime | None
    removal_reason: str | None
    created_at: datetime
    updated_at: datetime

    subject: (
        TeacherMaterialSubjectResponse
        | None
    ) = None