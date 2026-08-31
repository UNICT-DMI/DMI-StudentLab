from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


PublicNewsReportReason = Literal[
    "spam",
    "harassment",
    "hate",
    "privacy",
    "illegal_content",
    "other",
]

PublicNewsReportStatus = Literal[
    "pending",
    "under_review",
    "resolved",
    "dismissed",
]

PublicNewsReportAction = Literal[
    "none",
    "hide_news",
    "remove_news",
    "warn_user",
    "suspend_user",
    "deactivate_user",
]


class PublicNewsReportCreate(BaseModel):
    reason: PublicNewsReportReason
    description: str = Field(default="", max_length=1000)


class PublicNewsReportModerationRequest(BaseModel):
    status: PublicNewsReportStatus
    action: PublicNewsReportAction = "none"
    note: str = Field(default="", max_length=2000)


class PublicNewsReportResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    news_id: int
    reporter_user_id: int
    reported_author_user_id: int | None
    reason: str
    description: str | None
    status: str
    moderation_action: str
    moderation_note: str | None
    reviewed_by_user_id: int | None
    reviewed_at: datetime | None
    created_at: datetime
    updated_at: datetime


class PublicNewsReportsResponse(BaseModel):
    items: list[PublicNewsReportResponse]
    total: int
    limit: int
    offset: int
