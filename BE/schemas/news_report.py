from datetime import datetime

from typing import Literal

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
    model_validator,
)


NewsReportCategory = Literal[
    "avvisi",
    "gruppi",
    "private",
]

NewsReportReason = Literal[
    "spam",
    "harassment",
    "hate",
    "privacy",
    "illegal_content",
    "other",
]

NewsReportStatus = Literal[
    "pending",
    "under_review",
    "resolved",
    "dismissed",
]

NewsReportAction = Literal[
    "none",
    "hide_news",
    "remove_news",
]


class NewsReportCreate(
    BaseModel,
):
    category: NewsReportCategory

    news_id: str = Field(
        min_length=1,
        max_length=64,
    )

    reason: NewsReportReason

    description: str = Field(
        default="",
        max_length=2000,
    )

    group_id: int | None = Field(
        default=None,
        gt=0,
    )

    other_user_id: int | None = Field(
        default=None,
        gt=0,
    )

    disclosed_content_key: str | None = Field(
        default=None,
        max_length=512,
    )

    disclosure_consent: bool = False

    @field_validator(
        "news_id",
    )
    @classmethod
    def validate_news_id(
        cls,
        value: str,
    ) -> str:
        normalized = value.strip()

        if not normalized or "/" in normalized:
            raise ValueError(
                "Identificativo della news non valido.",
            )

        return normalized

    @field_validator(
        "description",
    )
    @classmethod
    def normalize_description(
        cls,
        value: str,
    ) -> str:
        return value.strip()

    @model_validator(
        mode="after",
    )
    def validate_target(
        self,
    ):
        if self.category == "gruppi" and self.group_id is None:
            raise ValueError(
                "Per segnalare una news di gruppo serve il gruppo.",
            )

        if self.category == "private" and self.other_user_id is None:
            raise ValueError(
                "Per segnalare un messaggio privato serve l'altro utente.",
            )

        if self.category == "private":
            if not self.disclosure_consent:
                raise ValueError(
                    "Per segnalare un messaggio cifrato devi acconsentire a "
                    "renderlo leggibile ai moderatori.",
                )

            if not (self.disclosed_content_key or "").strip():
                raise ValueError(
                    "Chiave di disclosure mancante: il messaggio non "
                    "sarebbe verificabile.",
                )

        if self.category != "private" and self.disclosed_content_key:
            raise ValueError(
                "La chiave di disclosure vale solo per i messaggi privati.",
            )

        return self


class NewsReportModerationRequest(
    BaseModel,
):
    status: NewsReportStatus

    action: NewsReportAction = "none"

    note: str = Field(
        default="",
        max_length=2000,
    )

    @field_validator(
        "note",
    )
    @classmethod
    def normalize_note(
        cls,
        value: str,
    ) -> str:
        return value.strip()


class NewsReportResponse(
    BaseModel,
):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    category: str
    news_id: str
    group_id: int | None
    conversation_id: str | None
    reporter_user_id: int
    reported_user_id: int | None
    reason: str
    description: str | None
    status: str
    moderation_action: str
    moderation_note: str | None
    reviewed_by_user_id: int | None
    reviewed_at: datetime | None
    disclosure_consent_at: datetime | None
    disclosure_opened_at: datetime | None
    created_at: datetime
    updated_at: datetime


class NewsReportListResponse(
    BaseModel,
):
    items: list[NewsReportResponse]
    total: int
    limit: int
    offset: int


class NewsReportDisclosureResponse(
    BaseModel,
):
    report_id: int
    category: str
    news_id: str
    author_id: int | None
    author_name: str
    created_at: datetime | None
    content: str
    verified: bool
    wrap_targets: list[str] = []
