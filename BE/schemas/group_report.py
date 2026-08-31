from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class GroupReportCreate(BaseModel):
    group_id: int
    reason: str = Field(
        min_length=1,
        max_length=100,
    )
    description: str = Field(
        default="",
        max_length=5000,
    )


class GroupReportModerationUpdate(BaseModel):
    status: str = Field(
        min_length=1,
        max_length=30,
    )
    moderation_note: str = Field(
        default="",
        max_length=5000,
    )


class GroupReportUserSummary(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    first_name: str
    last_name: str


class GroupReportGroupSummary(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    name: str
    status: str


class GroupReportResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    reporter_user_id: int
    group_id: int
    reason: str
    description: str
    status: str
    reviewed_by: int | None
    reviewed_at: datetime | None
    moderation_note: str
    created_at: datetime
    updated_at: datetime


class GroupReportDetailResponse(GroupReportResponse):
    reporter: GroupReportUserSummary | None = None
    group: GroupReportGroupSummary | None = None
    reviewer: GroupReportUserSummary | None = None