from datetime import datetime
from typing import Any

from pydantic import (
    BaseModel,
    Field,
)


class QuizOverallStatisticsResponse(BaseModel):
    total_attempts: int
    total_questions: int
    correct_count: int
    wrong_count: int
    unanswered_count: int
    accuracy_percentage: float
    total_elapsed_seconds: int


class QuizSubjectStatisticsResponse(BaseModel):
    department: str
    course: str
    subject: str

    total_attempts: int
    total_questions: int

    correct_count: int
    wrong_count: int
    unanswered_count: int

    accuracy_percentage: float

    total_elapsed_seconds: int


class QuizArgumentStatisticsResponse(BaseModel):
    department: str
    course: str
    subject: str
    argument: str

    total_questions: int

    correct_count: int
    wrong_count: int
    unanswered_count: int

    accuracy_percentage: float

    total_response_time_seconds: int


class QuizQuestionStatisticsResponse(BaseModel):
    department: str
    course: str
    subject: str

    argument: str | None

    question_id: str
    question_text: str

    options: list[dict[str, Any]]

    correct_option_id: str
    correct_option_text: str

    formal_explanation: str | None
    informal_explanation: str | None
    correct_answer_explanation: str | None

    times_seen: int

    correct_count: int
    wrong_count: int
    unanswered_count: int

    accuracy_percentage: float

    total_response_time_seconds: int
    average_response_time_seconds: float

    last_is_correct: bool | None

    last_selected_option_id: str | None
    last_selected_option_text: str | None
    last_selected_answer_explanation: str | None
    last_answered_at: datetime | None = None


class QuizReviewQuestionResponse(
    QuizQuestionStatisticsResponse
):
    needs_review: bool


class QuizLearningProfileResponse(BaseModel):
    overall: QuizOverallStatisticsResponse

    subjects: list[
        QuizSubjectStatisticsResponse
    ] = Field(
        default_factory=list,
    )

    arguments: list[
        QuizArgumentStatisticsResponse
    ] = Field(
        default_factory=list,
    )

    weak_arguments: list[
        QuizArgumentStatisticsResponse
    ] = Field(
        default_factory=list,
    )

    review_questions: list[
        QuizReviewQuestionResponse
    ] = Field(
        default_factory=list,
    )