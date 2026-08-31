from datetime import datetime

from typing import Literal

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
)


MaterialPublicationStatus = Literal[
    "pending",
    "approved",
    "rejected",
]


MaterialDuplicateStatus = Literal[
    "none",
    "suspected",
    "confirmed",
    "not_duplicate",
]


MaterialPublicationRequestType = Literal[
    "new_material",
    "update_candidate",
]


MaterialComparisonStatus = Literal[
    "not_required",
    "pending",
    "same_material",
    "candidate_update",
    "different_material",
]


MaterialApprovedAction = Literal[
    "publish_new",
    "update_existing",
    "keep_existing",
    "publish_separate",
]


class MaterialPublicationRequestCreate(
    BaseModel,
):
    subject_id: int

    request_type: MaterialPublicationRequestType = (
        "new_material"
    )

    target_public_material_id: int | None = (
        None
    )

    title: str = Field(
        min_length=1,
        max_length=250,
    )

    description: str | None = None

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
    )

    file_hash: str = Field(
        min_length=64,
        max_length=64,
        pattern=r"^[a-fA-F0-9]{64}$",
    )


class MaterialPublicationUploadRequest(
    BaseModel,
):
    subject_id: int

    request_type: MaterialPublicationRequestType = (
        "new_material"
    )

    target_public_material_id: int | None = (
        None
    )

    title: str = Field(
        min_length=1,
        max_length=250,
    )

    description: str | None = None

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
    )

    file_hash: str = Field(
        min_length=64,
        max_length=64,
        pattern=r"^[a-fA-F0-9]{64}$",
    )


class MaterialPublicationCompleteRequest(
    BaseModel,
):
    subject_id: int

    request_type: MaterialPublicationRequestType = (
        "new_material"
    )

    target_public_material_id: int | None = (
        None
    )

    title: str = Field(
        min_length=1,
        max_length=250,
    )

    description: str | None = None

    original_name: str = Field(
        min_length=1,
        max_length=255,
    )

    stored_name: str = Field(
        min_length=1,
        max_length=500,
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
    )

    file_hash: str = Field(
        min_length=64,
        max_length=64,
        pattern=r"^[a-fA-F0-9]{64}$",
    )


class MaterialPublicationRequestResponse(
    BaseModel,
):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int

    user_id: int

    subject_id: int

    university: str

    university_code: str

    department: str

    department_code: str

    course: str

    course_code: str

    request_type: MaterialPublicationRequestType

    target_public_material_id: int | None

    title: str

    description: str | None

    original_name: str

    mime_type: str

    size: int

    file_hash: str

    status: MaterialPublicationStatus

    duplicate_status: MaterialDuplicateStatus

    comparison_status: MaterialComparisonStatus

    possible_duplicate_material_id: int | None

    reviewed_by: int | None

    reviewed_at: datetime | None

    rejection_reason: str | None

    admin_note: str | None

    approved_action: MaterialApprovedAction | None

    approved_public_material_id: int | None

    proposed_title: str | None

    proposed_description: str | None

    created_at: datetime

    updated_at: datetime


class MaterialPublicationRequestAdminResponse(
    MaterialPublicationRequestResponse,
):
    stored_name: str

    file_path: str


class MaterialPublicationApproveRequest(
    BaseModel,
):
    approved_action: MaterialApprovedAction | None = (
        None
    )

    proposed_title: str | None = Field(
        default=None,
        max_length=250,
    )

    proposed_description: str | None = (
        None
    )

    admin_note: str | None = None


class MaterialPublicationRejectRequest(
    BaseModel,
):
    rejection_reason: str = Field(
        min_length=1,
    )

    admin_note: str | None = None


class MaterialDuplicateReviewRequest(
    BaseModel,
):
    duplicate_status: Literal[
        "confirmed",
        "not_duplicate",
    ]

    comparison_status: Literal[
        "candidate_update",
        "different_material",
    ] | None = None

    proposed_title: str | None = Field(
        default=None,
        max_length=250,
    )

    proposed_description: str | None = (
        None
    )

    admin_note: str | None = None