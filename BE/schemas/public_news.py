from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


PublicNewsTargetType = Literal[
    "all",
    "university",
    "department",
    "course",
    "subject",
]


class PublicNewsCreate(BaseModel):
    target_type: PublicNewsTargetType
    title: str = Field(min_length=1, max_length=160)
    content: str = Field(min_length=1, max_length=5000)
    subject_id: int | None = Field(default=None, gt=0)
    city: str | None = Field(default=None, max_length=160)
    university: str | None = Field(default=None, max_length=255)
    university_code: str | None = Field(default=None, max_length=100)
    department: str | None = Field(default=None, max_length=255)
    department_code: str | None = Field(default=None, max_length=100)
    course: str | None = Field(default=None, max_length=255)
    course_code: str | None = Field(default=None, max_length=100)

    @field_validator(
        "title",
        "content",
        "city",
        "university",
        "university_code",
        "department",
        "department_code",
        "course",
        "course_code",
    )
    @classmethod
    def normalize_text(cls, value: str | None):
        if value is None:
            return None
        normalized = value.strip()
        return normalized or None

    @model_validator(mode="after")
    def validate_target(self):
        if self.target_type == "subject" and self.subject_id is None:
            raise ValueError("Seleziona una materia.")
        if self.target_type == "university" and not self.university:
            raise ValueError("Seleziona un ateneo.")
        if self.target_type == "department" and (not self.university or not self.department):
            raise ValueError("Seleziona ateneo e dipartimento.")
        if self.target_type == "course" and (not self.university or not self.department or not self.course):
            raise ValueError("Seleziona ateneo, dipartimento e corso.")
        return self


class PublicNewsModerationRequest(BaseModel):
    reason: str = Field(min_length=1, max_length=1000)


class PublicNewsAuthorResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    first_name: str
    last_name: str
    role: str
    teacher_verification_status: str


class PublicNewsResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    author_user_id: int
    subject_id: int | None
    target_type: str
    title: str
    content: str
    city: str | None
    university: str | None
    university_code: str | None
    department: str | None
    department_code: str | None
    course: str | None
    course_code: str | None
    subject_name: str | None
    status: str
    created_at: datetime
    updated_at: datetime
    author: PublicNewsAuthorResponse


class PublicNewsFeedItemResponse(PublicNewsResponse):
    can_delete: bool = False
    can_moderate: bool = False
    can_report: bool = False
    can_block_author: bool = False


class PublicNewsFeedResponse(BaseModel):
    items: list[PublicNewsFeedItemResponse]
    total: int
    limit: int
    offset: int


class PublicNewsDeleteResponse(BaseModel):
    success: bool
    message: str
    news_id: int
    status: str
