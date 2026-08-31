from datetime import datetime

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
)


class AcademicTeacherCreate(BaseModel):
    name: str


class AcademicTeacherResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int

    name: str

    user_id: int | None

    is_active: bool


class SubjectOfferingCreate(BaseModel):
    module: str | None = None

    channel: str | None = None

    academic_year: str | None = None

    source_url: str | None = None

    teachers: list[str] = Field(
        default_factory=list,
    )


class SubjectOfferingResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int

    module: str | None

    channel: str | None

    academic_year: str | None

    source_url: str | None

    is_active: bool

    teachers: list[
        AcademicTeacherResponse
    ] = Field(
        default_factory=list,
    )


class SubjectCreate(BaseModel):
    code: str | None = None

    name: str

    university: str = (
        "Università degli Studi di Catania"
    )

    university_code: str = "UNICT"

    department: str

    department_code: str | None = None

    course: str

    course_code: str | None = None

    degree_type: str | None = None

    study_year: int | None = None

    offerings: list[
        SubjectOfferingCreate
    ] = Field(
        default_factory=list,
    )


class SubjectUpdate(BaseModel):
    code: str | None = None

    name: str | None = None

    university: str | None = None

    university_code: str | None = None

    department: str | None = None

    department_code: str | None = None

    course: str | None = None

    course_code: str | None = None

    degree_type: str | None = None

    study_year: int | None = None

    is_active: bool | None = None


class SubjectResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int

    code: str | None

    name: str

    university: str

    university_code: str

    department: str

    department_code: str | None

    course: str

    course_code: str | None

    degree_type: str | None

    study_year: int | None

    is_active: bool

    offerings: list[
        SubjectOfferingResponse
    ] = Field(
        default_factory=list,
    )


class UserSubjectCreate(BaseModel):
    subject_id: int

    grade: int | None = Field(
        default=None,
        ge=18,
        le=30,
    )

    note: str | None = None

    can_help: bool = False

    can_give_private_lessons: bool = False


class UserSubjectUpdate(BaseModel):
    grade: int | None = Field(
        default=None,
        ge=18,
        le=30,
    )

    note: str | None = None

    can_help: bool | None = None

    can_give_private_lessons: bool | None = None


class UserSubjectResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int

    grade: int | None

    grade_status: str

    grade_verified_by: int | None

    grade_verified_at: datetime | None

    note: str | None

    can_help: bool

    can_give_private_lessons: bool

    subject: SubjectResponse