from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


QuestionModerationSource = Literal["proposal", "report"]
QuestionModerationStatus = Literal["pending", "under_review", "approved", "rejected"]
QuestionReportReason = Literal[
    "wrong_correct_answer",
    "unclear_question",
    "wrong_explanation",
    "wrong_feedback",
    "duplicate_question",
    "text_error",
    "not_relevant",
    "other",
]


def _required(value: str) -> str:
    normalized = value.strip()
    if not normalized:
        raise ValueError("Valore obbligatorio.")
    return normalized


class QuestionReportCreate(BaseModel):
    department: str = Field(min_length=1, max_length=100)
    course: str = Field(min_length=1, max_length=100)
    subject: str = Field(min_length=1, max_length=255)
    question_id: str = Field(min_length=1, max_length=100)
    reason: QuestionReportReason
    message: str | None = Field(default=None, max_length=2000)

    @field_validator("department", "course", "subject", "question_id")
    @classmethod
    def normalize_required(cls, value: str) -> str:
        return _required(value)

    @field_validator("message")
    @classmethod
    def normalize_message(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = value.strip()
        return normalized or None


class QuestionProposalCreate(BaseModel):
    department: str = Field(min_length=1, max_length=100)
    course: str = Field(min_length=1, max_length=100)
    subject: str = Field(min_length=1, max_length=255)
    question: dict[str, Any]

    @field_validator("department", "course", "subject")
    @classmethod
    def normalize_required(cls, value: str) -> str:
        return _required(value)


class QuestionProposalBatchCreate(BaseModel):
    proposals: list[QuestionProposalCreate] = Field(min_length=1, max_length=100)


class QuestionProposalUpdate(BaseModel):
    question: dict[str, Any]


class QuestionTemporaryAttachmentCleanupRequest(BaseModel):
    attachments: list[dict[str, Any]] = Field(min_length=1, max_length=100)


class QuestionModerationResolution(BaseModel):
    status: Literal["approved", "rejected"]
    resolution_note: str | None = Field(default=None, max_length=4000)

    @field_validator("resolution_note")
    @classmethod
    def normalize_note(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = value.strip()
        return normalized or None


class QuestionModerationUser(BaseModel):
    id: int
    first_name: str
    last_name: str
    role: str


class QuestionModerationResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    source_type: QuestionModerationSource
    department: str
    course: str
    subject: str
    question_id: str | None = None
    proposed_question_payload: dict[str, Any] | None = None
    report_reason: str | None = None
    report_message: str | None = None
    status: QuestionModerationStatus
    reviewer_role: str | None = None
    resolution_note: str | None = None
    review_started_at: datetime | None = None
    reviewed_at: datetime | None = None
    created_at: datetime
    updated_at: datetime
    created_by_user: QuestionModerationUser
    reviewed_by_user: QuestionModerationUser | None = None
    question: dict[str, Any] | None = None
