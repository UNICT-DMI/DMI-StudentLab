from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class GroupContentReportCreate(BaseModel):
    group_id: int
    content_type: str = Field(
        min_length=1,
        max_length=30,
    )
    content_id: int
    author_user_id: int | None = None
    reason: str = Field(
        min_length=1,
        max_length=100,
    )
    description: str = Field(
        default="",
        max_length=5000,
    )


class GroupContentReportModerationUpdate(BaseModel):
    status: str = Field(
        min_length=1,
        max_length=30,
    )
    moderation_action: str = Field(
        default="none",
        min_length=1,
        max_length=40,
    )
    moderation_note: str = Field(
        default="",
        max_length=5000,
    )


class GroupContentReportUserSummary(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    first_name: str
    last_name: str


class GroupContentReportGroupSummary(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    name: str
    status: str


class GroupContentReportResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    reporter_user_id: int
    group_id: int
    content_type: str
    content_id: int
    author_user_id: int | None
    reason: str
    description: str
    status: str
    reviewed_by: int | None
    reviewed_at: datetime | None
    moderation_action: str
    moderation_note: str
    created_at: datetime
    updated_at: datetime


class GroupContentReportDetailResponse(GroupContentReportResponse):
    reporter: GroupContentReportUserSummary | None = None
    author: GroupContentReportUserSummary | None = None
    reviewer: GroupContentReportUserSummary | None = None
    group: GroupContentReportGroupSummary | None = None