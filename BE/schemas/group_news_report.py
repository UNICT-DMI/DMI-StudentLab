from datetime import datetime
from typing import Literal

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
)


class GroupNewsReportCreate(
    BaseModel,
):
    reason: Literal[
        "spam",
        "harassment",
        "hate_speech",
        "sexual_content",
        "violence",
        "misinformation",
        "privacy_violation",
        "impersonation",
        "illegal_content",
        "other",
    ]

    description: str | None = Field(
        default=None,
        max_length=2000,
    )

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

        if not normalized:
            return None

        return normalized


class GroupNewsReportModerationRequest(
    BaseModel,
):
    status: Literal[
        "under_review",
        "resolved",
        "rejected",
    ]

    moderation_action: Literal[
        "none",
        "hide_news",
        "remove_news",
        "warn_user",
        "remove_user_from_group",
    ] = "none"

    moderation_note: str | None = Field(
        default=None,
        max_length=2000,
    )

    @field_validator(
        "moderation_note",
    )
    @classmethod
    def normalize_moderation_note(
        cls,
        value: str | None,
    ) -> str | None:
        if value is None:
            return None

        normalized = value.strip()

        if not normalized:
            return None

        return normalized


class GroupNewsPlatformModerationRequest(
    BaseModel,
):
    status: Literal[
        "under_review",
        "resolved",
        "rejected",
    ]

    moderation_action: Literal[
        "none",
        "hide_news",
        "remove_news",
        "warn_user",
        "remove_user_from_group",
        "suspend_user",
        "deactivate_user",
    ] = "none"

    moderation_note: str | None = Field(
        default=None,
        max_length=2000,
    )

    @field_validator(
        "moderation_note",
    )
    @classmethod
    def normalize_moderation_note(
        cls,
        value: str | None,
    ) -> str | None:
        if value is None:
            return None

        normalized = value.strip()

        if not normalized:
            return None

        return normalized


class GroupNewsReportReporterResponse(
    BaseModel,
):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    first_name: str
    last_name: str


class GroupNewsReportAuthorResponse(
    BaseModel,
):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    first_name: str
    last_name: str
    role: str
    teacher_verification_status: str


class GroupNewsReportReviewerResponse(
    BaseModel,
):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    first_name: str
    last_name: str
    role: str


class GroupNewsReportResponse(
    BaseModel,
):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    news_id: int
    group_id: int
    reporter_user_id: int
    reported_author_user_id: int | None

    reason: Literal[
        "spam",
        "harassment",
        "hate_speech",
        "sexual_content",
        "violence",
        "misinformation",
        "privacy_violation",
        "impersonation",
        "illegal_content",
        "other",
    ]

    description: str | None

    status: Literal[
        "pending",
        "under_review",
        "resolved",
        "rejected",
    ]

    moderation_action: Literal[
        "none",
        "hide_news",
        "remove_news",
        "warn_user",
        "remove_user_from_group",
        "suspend_user",
        "deactivate_user",
    ]

    moderation_note: str | None

    reviewed_by_user_id: int | None
    reviewed_at: datetime | None

    created_at: datetime
    updated_at: datetime


class GroupNewsReportDetailResponse(
    GroupNewsReportResponse,
):
    reporter: (
        GroupNewsReportReporterResponse
        | None
    ) = None

    reported_author: (
        GroupNewsReportAuthorResponse
        | None
    ) = None

    reviewer: (
        GroupNewsReportReviewerResponse
        | None
    ) = None


class GroupNewsReportListResponse(
    BaseModel,
):
    items: list[
        GroupNewsReportDetailResponse
    ]

    total: int
    limit: int
    offset: int