from datetime import datetime

from typing import Literal

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
    model_validator,
)


class GroupNewsAuthorResponse(
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


class GroupNewsRecipientResponse(
    BaseModel,
):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    first_name: str
    last_name: str


class GroupNewsCreate(
    BaseModel,
):
    visibility: Literal[
        "group",
        "private",
    ] = "group"

    recipient_user_id: int | None = Field(
        default=None,
        gt=0,
    )

    parent_news_id: int | None = Field(
        default=None,
        gt=0,
    )

    content: str = Field(
        min_length=1,
        max_length=5000,
    )

    @field_validator(
        "content",
    )
    @classmethod
    def normalize_content(
        cls,
        value: str,
    ) -> str:
        normalized = value.strip()

        if not normalized:
            raise ValueError(
                "Il contenuto della news non può essere vuoto.",
            )

        return normalized

    @model_validator(
        mode="after",
    )
    def validate_visibility(
        self,
    ):
        if (
            self.visibility == "group"
            and self.recipient_user_id
            is not None
        ):
            raise ValueError(
                "Una news di gruppo non può avere un destinatario privato.",
            )

        if (
            self.visibility == "private"
            and self.recipient_user_id
            is None
        ):
            raise ValueError(
                "Una news privata deve avere un destinatario.",
            )

        return self


class GroupNewsModerationRequest(
    BaseModel,
):
    action: Literal[
        "hide_news",
        "remove_news",
    ]

    reason: str = Field(
        min_length=1,
        max_length=1000,
    )

    @field_validator(
        "reason",
    )
    @classmethod
    def normalize_reason(
        cls,
        value: str,
    ) -> str:
        normalized = value.strip()

        if not normalized:
            raise ValueError(
                "Il motivo della moderazione non può essere vuoto.",
            )

        return normalized


class GroupNewsDeleteResponse(
    BaseModel,
):
    success: bool
    message: str
    news_id: int

    status: Literal[
        "deleted_by_author",
        "removed_by_group_owner",
        "removed_by_group_admin",
        "removed_by_platform_moderator",
        "expired",
    ]


class GroupNewsResponse(
    BaseModel,
):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    group_id: int
    author_user_id: int
    recipient_user_id: int | None
    parent_news_id: int | None

    visibility: Literal[
        "group",
        "private",
    ]

    content: str

    status: Literal[
        "active",
        "deleted_by_author",
        "removed_by_group_owner",
        "removed_by_group_admin",
        "removed_by_platform_moderator",
        "expired",
    ]

    deleted_by_user_id: int | None
    deleted_at: datetime | None

    moderated_by_user_id: int | None
    moderated_at: datetime | None
    moderation_reason: str | None

    created_at: datetime
    updated_at: datetime
    expires_at: datetime

    author: GroupNewsAuthorResponse

    recipient: (
        GroupNewsRecipientResponse
        | None
    ) = None


class GroupNewsFeedItemResponse(
    BaseModel,
):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    group_id: int
    author_user_id: int
    recipient_user_id: int | None
    parent_news_id: int | None

    visibility: Literal[
        "group",
        "private",
    ]

    is_private: bool
    content: str
    created_at: datetime
    expires_at: datetime

    author: GroupNewsAuthorResponse

    recipient: (
        GroupNewsRecipientResponse
        | None
    ) = None

    can_reply: bool = False
    can_delete: bool = False
    can_moderate: bool = False
    can_report: bool = False
    can_block_author: bool = False


class GroupNewsFeedResponse(
    BaseModel,
):
    group_id: int

    items: list[
        GroupNewsFeedItemResponse
    ]

    total: int
    limit: int
    offset: int


class GroupNewsPrivateInboxItemResponse(
    GroupNewsFeedItemResponse,
):
    group_name: str
    subject_id: int | None = None
    subject_name: str = ""


class GroupNewsPrivateInboxResponse(
    BaseModel,
):
    items: list[
        GroupNewsPrivateInboxItemResponse
    ]

    total: int
    limit: int
    offset: int


class GroupNewsAdminResponse(
    GroupNewsResponse,
):
    can_platform_moderate: bool