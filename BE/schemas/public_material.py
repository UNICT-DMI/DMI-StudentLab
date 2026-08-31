from datetime import datetime

from typing import Literal

from pydantic import (
    BaseModel,
    ConfigDict,
)


PublicMaterialStatus = Literal[
    "published",
    "hidden",
    "removed",
]


class PublicMaterialResponse(
    BaseModel,
):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int

    subject_id: int

    uploaded_by: int | None

    publication_request_id: int | None

    university: str

    university_code: str

    department: str

    department_code: str

    course: str

    course_code: str

    title: str

    description: str | None

    original_name: str

    mime_type: str

    size: int

    file_hash: str

    version: int

    status: PublicMaterialStatus

    is_visible: bool

    approved_at: datetime | None

    created_at: datetime

    updated_at: datetime


class PublicMaterialAdminResponse(
    PublicMaterialResponse,
):
    stored_name: str

    file_path: str

    approved_by: int | None

    removed_by: int | None

    removed_at: datetime | None

    removal_reason: str | None