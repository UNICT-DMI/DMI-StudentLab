from datetime import datetime
from typing import Literal

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
)


class GroupCreate(BaseModel):
    name: str = Field(
        min_length=1,
        max_length=150,
    )

    description: str | None = Field(
        default=None,
        max_length=5000,
    )

    subject_id: int | None = Field(
        default=None,
        gt=0,
    )

    university: str = Field(
        min_length=1,
        max_length=150,
    )

    department: str = Field(
        min_length=1,
        max_length=150,
    )

    course: str = Field(
        min_length=1,
        max_length=150,
    )

    is_private: bool = False

    @field_validator(
        "name",
        "university",
        "department",
        "course",
    )
    @classmethod
    def normalize_required_text(
        cls,
        value: str,
    ) -> str:
        normalized = value.strip()

        if not normalized:
            raise ValueError(
                "Il campo non può essere vuoto.",
            )

        return normalized

    @field_validator(
        "description",
    )
    @classmethod
    def normalize_description(
        cls,
        value: str | None,
    ) -> str | None:
        if value is None:
            return None

        normalized = value.strip()

        return (
            normalized
            if normalized
            else None
        )


class GroupUpdate(BaseModel):
    name: str | None = Field(
        default=None,
        min_length=1,
        max_length=150,
    )

    description: str | None = Field(
        default=None,
        max_length=5000,
    )

    subject_id: int | None = Field(
        default=None,
        gt=0,
    )

    university: str | None = Field(
        default=None,
        min_length=1,
        max_length=150,
    )

    department: str | None = Field(
        default=None,
        min_length=1,
        max_length=150,
    )

    course: str | None = Field(
        default=None,
        min_length=1,
        max_length=150,
    )

    is_private: bool | None = None

    @field_validator(
        "name",
        "university",
        "department",
        "course",
    )
    @classmethod
    def normalize_optional_required_text(
        cls,
        value: str | None,
    ) -> str | None:
        if value is None:
            return None

        normalized = value.strip()

        if not normalized:
            raise ValueError(
                "Il campo non può essere vuoto.",
            )

        return normalized

    @field_validator(
        "description",
    )
    @classmethod
    def normalize_optional_description(
        cls,
        value: str | None,
    ) -> str | None:
        if value is None:
            return None

        normalized = value.strip()

        return (
            normalized
            if normalized
            else None
        )


class GroupMemberResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int

    group_id: int

    user_id: int

    role: Literal[
        "owner",
        "admin",
        "member",
    ]

    joined_at: datetime


class PublicGroupUserResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int

    first_name: str

    last_name: str

    role: str

    university: str | None

    department: str | None

    course: str | None

    teacher_verification_status: str

    available: bool

    available_for_help: bool

    available_for_private_lessons: bool


class PublicGroupMemberResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int

    user_id: int

    role: Literal[
        "owner",
        "admin",
        "member",
    ]

    joined_at: datetime

    user: PublicGroupUserResponse


class GroupResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int

    name: str

    description: str | None

    subject_id: int | None

    university: str

    department: str

    course: str

    is_private: bool

    status: Literal[
        "active",
        "pending_deletion",
        "deleted",
    ]

    deletion_requested_at: datetime | None

    deletion_deadline: datetime | None

    created_by: int

    created_at: datetime

    updated_at: datetime


class PublicGroupResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int

    name: str

    description: str | None

    subject_id: int | None

    university: str

    department: str

    course: str

    created_by: int

    created_at: datetime


class GroupDetailResponse(
    GroupResponse,
):
    members: list[
        GroupMemberResponse
    ] = Field(
        default_factory=list,
    )


class PublicGroupDetailResponse(
    PublicGroupResponse,
):
    members: list[
        PublicGroupMemberResponse
    ] = Field(
        default_factory=list,
    )


class AddGroupMemberRequest(BaseModel):
    user_id: int = Field(
        gt=0,
    )

    role: Literal[
        "admin",
        "member",
    ] = "member"


class ChangeGroupMemberRoleRequest(
    BaseModel,
):
    role: Literal[
        "admin",
        "member",
    ]


class GroupJoinRequestCreate(
    BaseModel,
):
    pass


class GroupJoinRequestResponse(
    BaseModel,
):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int

    group_id: int

    user_id: int

    status: Literal[
        "pending",
        "accepted",
        "rejected",
        "cancelled",
    ]

    reviewed_by: int | None

    reviewed_at: datetime | None

    created_at: datetime

    updated_at: datetime


class JoinGroupResponse(BaseModel):
    joined: bool

    pending: bool

    message: str