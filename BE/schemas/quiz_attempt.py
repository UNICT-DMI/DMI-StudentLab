from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field


ExecutionMode = Literal["practice", "simulation"]
ExternalActivityPolicy = Literal["disabled", "structured_devices"]
CompletionReason = Literal["completed", "time_expired", "user_confirmed_exit", "app_backgrounded", "external_activity_detected", "session_abandoned"]


class QuizAnswerSubmit(BaseModel):
    question_id: str = Field(min_length=1, max_length=100)
    selected_option_id: str | None = Field(default=None, max_length=100)
    response_time_seconds: int | None = Field(default=None, ge=0)


class QuizAttemptStart(BaseModel):
    department: str = Field(min_length=1, max_length=100)
    course: str = Field(min_length=1, max_length=100)
    subject: str = Field(min_length=1, max_length=255)
    arguments: list[str] = Field(default_factory=list)
    all_arguments: bool = False
    number_of_questions: int = Field(gt=0)
    time_limit_seconds: int | None = Field(default=None, gt=0)


class QuizAttemptSubmit(BaseModel):
    answers: list[QuizAnswerSubmit] = Field(default_factory=list)
    elapsed_seconds: int = Field(default=0, ge=0)
    completion_reason: CompletionReason = "completed"
    interruption_count: int = Field(default=0, ge=0)


class QuizAttemptAnswerResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    attempt_id: int
    question_id: str
    argument: str | None = None
    question_text: str
    attachments_snapshot: list[dict[str, Any]] = Field(default_factory=list)
    options_snapshot: list[dict[str, Any]] = Field(default_factory=list)
    selected_option_id: str | None = None
    selected_option_text: str | None = None
    correct_option_id: str
    correct_option_text: str
    is_answered: bool
    is_correct: bool
    response_time_seconds: int | None = None
    formal_explanation: str | None = None
    informal_explanation: str | None = None
    selected_answer_explanation: str | None = None
    correct_answer_explanation: str | None = None
    created_at: datetime


class QuizAttemptResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    user_id: int
    assignment_id: int | None = None
    department: str
    course: str
    subject: str
    selected_arguments: list[str] = Field(default_factory=list)
    question_ids: list[str] = Field(default_factory=list)
    question_count: int
    correct_count: int
    wrong_count: int
    unanswered_count: int
    percentage: float
    time_limit_seconds: int | None = None
    elapsed_seconds: int | None = None
    execution_mode: ExecutionMode
    external_activity_policy: ExternalActivityPolicy
    completion_reason: CompletionReason | None = None
    interruption_count: int
    last_interrupted_at: datetime | None = None
    status: str
    started_at: datetime
    completed_at: datetime | None = None
    is_hidden_from_history: bool
    is_deleted: bool
    created_at: datetime
    updated_at: datetime


class QuizAttemptDetailResponse(QuizAttemptResponse):
    answers: list[QuizAttemptAnswerResponse] = Field(default_factory=list)


class QuizAttemptHistoryResponse(BaseModel):
    total: int
    attempts: list[QuizAttemptResponse] = Field(default_factory=list)