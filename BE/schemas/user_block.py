from datetime import datetime

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
)


class UserBlockCreate(
    BaseModel,
):
    blocked_user_id: int = Field(
        gt=0,
    )


class UserBlockUserResponse(
    BaseModel,
):
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


class UserBlockResponse(
    BaseModel,
):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    blocker_user_id: int
    blocked_user_id: int
    created_at: datetime

    blocked: (
        UserBlockUserResponse
        | None
    ) = None


class UserBlockListResponse(
    BaseModel,
):
    items: list[
        UserBlockResponse
    ]

    total: int


class UserBlockStatusResponse(
    BaseModel,
):
    blocked: bool
    blocked_user_id: int


class UserUnblockResponse(
    BaseModel,
):
    success: bool
    blocked_user_id: int
    message: str