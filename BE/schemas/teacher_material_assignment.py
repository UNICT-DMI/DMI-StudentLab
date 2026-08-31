from datetime import datetime

from typing import Literal

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
)


TeacherMaterialAssignmentStatus = Literal[
    "active",
    "revoked",
]


class TeacherMaterialAssignmentCreate(
    BaseModel,
):
    user_id: int | None = Field(
        default=None,
        gt=0,
    )

    group_id: int | None = Field(
        default=None,
        gt=0,
    )


class TeacherMaterialAssignmentBulkCreate(
    BaseModel,
):
    user_ids: list[int] = Field(
        default_factory=list,
    )

    group_ids: list[int] = Field(
        default_factory=list,
    )


class TeacherMaterialAssignmentResponse(
    BaseModel,
):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int

    material_id: int

    assigned_by: int

    user_id: int | None

    group_id: int | None

    status: TeacherMaterialAssignmentStatus

    revoked_by: int | None

    assigned_at: datetime

    updated_at: datetime

    revoked_at: datetime | None


class TeacherMaterialAssignmentTargetResponse(
    BaseModel,
):
    id: int

    type: Literal[
        "user",
        "group",
    ]

    name: str


class TeacherMaterialAssignmentDetailResponse(
    TeacherMaterialAssignmentResponse,
):
    target: (
        TeacherMaterialAssignmentTargetResponse
        | None
    ) = None