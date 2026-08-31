from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class ProfileErrorReportCreate(BaseModel):
    category: str = Field(
        min_length=1,
        max_length=50,
    )
    description: str = Field(
        min_length=1,
        max_length=5000,
    )


class ProfileErrorReportModerationUpdate(BaseModel):
    status: str = Field(
        min_length=1,
        max_length=30,
    )
    resolution_note: str = Field(
        default="",
        max_length=5000,
    )


class ProfileErrorReportUserSummary(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    first_name: str
    last_name: str


class ProfileErrorReportResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    user_id: int
    category: str
    description: str
    status: str
    reviewed_by: int | None
    reviewed_at: datetime | None
    resolution_note: str
    created_at: datetime
    updated_at: datetime


class ProfileErrorReportDetailResponse(ProfileErrorReportResponse):
    user: ProfileErrorReportUserSummary | None = None
    reviewer: ProfileErrorReportUserSummary | None = None