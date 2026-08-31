from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class UserReportCreate(BaseModel):
    reported_user_id: int
    reason: str = Field(
        min_length=1,
        max_length=100,
    )
    description: str = Field(
        default="",
        max_length=5000,
    )


class UserReportModerationUpdate(BaseModel):
    status: str = Field(
        min_length=1,
        max_length=30,
    )
    moderation_note: str = Field(
        default="",
        max_length=5000,
    )


class UserReportUserSummary(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    first_name: str
    last_name: str


class UserReportResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    reporter_user_id: int
    reported_user_id: int
    reason: str
    description: str
    status: str
    reviewed_by: int | None
    reviewed_at: datetime | None
    moderation_note: str
    is_active: bool
    created_at: datetime
    updated_at: datetime


class UserReportDetailResponse(UserReportResponse):
    reporter: UserReportUserSummary | None = None
    reported_user: UserReportUserSummary | None = None
    reviewer: UserReportUserSummary | None = None