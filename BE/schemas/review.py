from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


ReviewModerationStatus = Literal[
    "pending",
    "approved",
    "rejected",
    "hidden",
]


class ReviewCreate(BaseModel):
    rating: int = Field(
        ge=1,
        le=5,
    )

    comment: str = Field(
        default="",
        max_length=2000,
    )

    subject_id: int | None = None


class ReviewUpdate(BaseModel):
    rating: int | None = Field(
        default=None,
        ge=1,
        le=5,
    )

    comment: str | None = Field(
        default=None,
        max_length=2000,
    )

    subject_id: int | None = None

    clear_subject: bool = False


class ReviewModerationUpdate(BaseModel):
    status: Literal[
        "approved",
        "rejected",
        "hidden",
    ]


class ReviewSubjectResponse(BaseModel):
    id: int

    code: str = ""

    name: str


class ReviewAcademicPathResponse(BaseModel):
    id: int

    university: str

    university_code: str

    department: str

    department_code: str

    course: str

    course_code: str

    degree_type: str | None = None

    status: str

    verification_status: str

    start_year: int | None = None

    graduation_year: int | None = None

    is_current: bool

    is_primary: bool


class ReviewAuthorResponse(BaseModel):
    id: int

    first_name: str

    last_name: str

    name: str

    role: str

    primary_academic_path: ReviewAcademicPathResponse | None = None


class ReviewModeratorResponse(BaseModel):
    id: int

    first_name: str

    last_name: str

    name: str

    role: str


class ReviewResponse(BaseModel):
    id: int

    reviewer_id: int

    reviewed_user_id: int

    rating: int

    comment: str

    moderation_status: ReviewModerationStatus

    moderated_by: int | None = None

    moderated_at: datetime | None = None

    subject: ReviewSubjectResponse | None = None

    reviewer: ReviewAuthorResponse

    moderator: ReviewModeratorResponse | None = None

    created_at: datetime

    updated_at: datetime


class ReviewSummaryResponse(BaseModel):
    average_rating: float

    review_count: int


class UserReviewsResponse(BaseModel):
    reviews: list[ReviewResponse]

    summary: ReviewSummaryResponse

    my_review: ReviewResponse | None = None


class AdminReviewsResponse(BaseModel):
    reviews: list[ReviewResponse]

    total: int