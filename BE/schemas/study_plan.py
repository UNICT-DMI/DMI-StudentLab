from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, Field, field_validator


StudySourceType = Literal["guest", "authenticated"]
StudyPlanStatus = Literal["review", "improving", "consolidated"]


class StudyPlanContributionSync(BaseModel):
    contribution_uuid: str = Field(min_length=8, max_length=128)
    department: str = Field(min_length=1, max_length=100)
    course: str = Field(min_length=1, max_length=100)
    subject: str = Field(min_length=1, max_length=255)
    argument: str | None = Field(default=None, max_length=255)
    question_id: str = Field(min_length=1, max_length=100)
    question_text: str = ""
    options: list[dict[str, Any]] = Field(default_factory=list)
    correct_option_id: str | None = Field(default=None, max_length=100)
    correct_option_text: str | None = None
    formal_explanation: str | None = None
    informal_explanation: str | None = None
    correct_answer_explanation: str | None = None
    # v18 · "multiple_choice" per le domande di sempre, oppure ordina/abbina/…
    question_type: str = Field(default="multiple_choice", max_length=30)
    correct_payload: dict[str, Any] | None = None
    correct_count: int = Field(default=0, ge=0)
    wrong_count: int = Field(default=0, ge=0)
    unanswered_count: int = Field(default=0, ge=0)
    review_count: int = Field(default=0, ge=0)
    last_is_correct: bool | None = None
    last_selected_option_id: str | None = Field(default=None, max_length=100)
    last_selected_option_text: str | None = None
    last_selected_answer_explanation: str | None = None
    first_seen_at: datetime | None = None
    last_answered_at: datetime | None = None
    client_revision: int = Field(default=0, ge=0)

    @field_validator("department", "course", "subject", "question_id", "contribution_uuid")
    @classmethod
    def normalize_required(cls, value: str) -> str:
        return value.strip()

    @field_validator("argument", "correct_option_id")
    @classmethod
    def normalize_optional(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = value.strip()
        return normalized or None


class StudyPlanSyncRequest(BaseModel):
    session_uuid: str = Field(min_length=8, max_length=64)
    device_id: str = Field(min_length=8, max_length=64)
    device_label: str | None = Field(default=None, max_length=100)
    source_type: StudySourceType
    contributions: list[StudyPlanContributionSync] = Field(default_factory=list, max_length=5000)

    @field_validator("session_uuid", "device_id")
    @classmethod
    def normalize_ids(cls, value: str) -> str:
        return value.strip()


class StudyPlanSessionResponse(BaseModel):
    session_uuid: str
    device_id: str
    device_label: str | None
    source_type: StudySourceType
    contribution_enabled: bool
    created_at: datetime
    last_activity_at: datetime
    associated_at: datetime
    dissociated_at: datetime | None
    contribution_count: int


class StudyPlanContributionResponse(BaseModel):
    contribution_uuid: str
    session_uuid: str
    source_type: StudySourceType
    source_user_id: int | None
    contribution_enabled: bool
    correct_count: int
    wrong_count: int
    unanswered_count: int
    review_count: int
    last_is_correct: bool | None
    last_selected_option_id: str | None
    last_selected_option_text: str | None
    last_selected_answer_explanation: str | None
    first_seen_at: datetime
    last_answered_at: datetime | None
    client_revision: int


class StudyPlanItemResponse(BaseModel):
    id: int
    department: str
    course: str
    subject: str
    argument: str | None
    question_id: str
    question_text: str
    options: list[dict[str, Any]]
    correct_option_id: str | None
    correct_option_text: str | None
    formal_explanation: str | None
    informal_explanation: str | None
    correct_answer_explanation: str | None
    mastery_percentage: float
    status: StudyPlanStatus
    first_seen_at: datetime
    last_seen_at: datetime
    total_answers: int
    correct_count: int
    wrong_count: int
    unanswered_count: int
    review_count: int
    source_count: int
    contributions: list[StudyPlanContributionResponse] = Field(default_factory=list)


class StudyPlanBootstrapResponse(BaseModel):
    user_id: int
    generated_at: datetime
    sessions: list[StudyPlanSessionResponse] = Field(default_factory=list)
    items: list[StudyPlanItemResponse] = Field(default_factory=list)


class StudyPlanSyncResponse(BaseModel):
    success: bool
    session_uuid: str
    imported: int
    updated: int
    ignored: int
    plan: StudyPlanBootstrapResponse


class StudyPlanAssociationRequest(BaseModel):
    contribution_enabled: bool
