from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


SelectionMode = Literal["random", "arguments", "selected_questions"]
ExecutionMode = Literal["practice", "simulation"]
ExternalActivityPolicy = Literal["disabled", "structured_devices"]


class QuizAssignmentRecipientResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    assignment_id: int
    user_id: int | None = None
    group_id: int | None = None
    created_at: datetime


class QuizAssignmentCreate(BaseModel):
    department: str = Field(min_length=1, max_length=100)
    course: str = Field(min_length=1, max_length=100)
    subject: str = Field(min_length=1, max_length=255)
    title: str = Field(min_length=1, max_length=255)
    description: str | None = None
    selection_mode: SelectionMode = "random"
    execution_mode: ExecutionMode = "practice"
    external_activity_policy: ExternalActivityPolicy = "disabled"
    arguments: list[str] = Field(default_factory=list)
    question_ids: list[int] = Field(default_factory=list)
    question_count: int = Field(default=10, gt=0)
    time_limit_seconds: int | None = Field(default=None, gt=0)
    due_at: datetime | None = None
    user_ids: list[int] = Field(default_factory=list)
    group_ids: list[int] = Field(default_factory=list)
    # v18 · tipi di esercizio (None o ["multiple_choice"] = come prima) ed esercizi scelti a mano ("ex:12", "dz:4"…)
    question_types: list[str] | None = Field(default=None, max_length=12)
    item_ids: list[str] = Field(default_factory=list, max_length=200)
    attempts_per_item: int | None = Field(default=None, ge=1, le=5)


class QuizAssignmentUpdate(BaseModel):
    department: str | None = Field(default=None, min_length=1, max_length=100)
    course: str | None = Field(default=None, min_length=1, max_length=100)
    subject: str | None = Field(default=None, min_length=1, max_length=255)
    title: str | None = Field(default=None, min_length=1, max_length=255)
    description: str | None = None
    selection_mode: SelectionMode | None = None
    execution_mode: ExecutionMode | None = None
    external_activity_policy: ExternalActivityPolicy | None = None
    arguments: list[str] | None = None
    question_ids: list[int] | None = None
    question_count: int | None = Field(default=None, gt=0)
    time_limit_seconds: int | None = Field(default=None, gt=0)
    due_at: datetime | None = None
    is_active: bool | None = None
    user_ids: list[int] | None = None
    group_ids: list[int] | None = None
    question_types: list[str] | None = Field(default=None, max_length=12)
    item_ids: list[str] | None = Field(default=None, max_length=200)
    attempts_per_item: int | None = Field(default=None, ge=1, le=5)


class QuizAssignmentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    teacher_id: int
    subject_id: int
    department: str
    course: str
    subject: str
    title: str
    description: str | None = None
    selection_mode: SelectionMode
    execution_mode: ExecutionMode
    external_activity_policy: ExternalActivityPolicy
    selected_arguments: list[str] = Field(default_factory=list)
    selected_question_ids: list[int | str] = Field(default_factory=list)
    question_count: int
    time_limit_seconds: int | None = None
    due_at: datetime | None = None
    question_types: list[str] | None = None
    attempts_per_item: int | None = None
    assigned_by_role: str = "teacher"
    is_active: bool
    created_at: datetime
    updated_at: datetime
    recipients: list[QuizAssignmentRecipientResponse] = Field(default_factory=list)


class StudentAssignedQuizResponse(QuizAssignmentResponse):
    is_expired: bool = False
    can_start: bool = False
    attempt_id: int | None = None
    is_completed: bool = False
    is_in_progress: bool = False