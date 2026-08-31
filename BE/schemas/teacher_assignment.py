from datetime import datetime
from typing import Literal

from pydantic import (
    BaseModel,
    ConfigDict,
)

from schemas.subject import (
    SubjectOfferingResponse,
    SubjectResponse,
)


TeacherAssignmentVerificationStatus = Literal[
    "pending",
    "verified",
    "rejected",
]


class TeacherAssignmentCreate(BaseModel):
    subject_id: int
    offering_id: int | None = None
    is_current: bool = True


class TeacherAssignmentUpdate(BaseModel):
    subject_id: int | None = None
    offering_id: int | None = None
    is_current: bool | None = None


class TeacherAssignmentVerificationUpdate(BaseModel):
    status: Literal[
        "verified",
        "rejected",
        "pending",
    ]


class TeacherAssignmentResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    user_id: int
    subject_id: int
    offering_id: int | None

    verification_status: str

    verified_by: int | None
    verified_at: datetime | None

    is_current: bool

    created_at: datetime
    updated_at: datetime

    subject: SubjectResponse

    offering: SubjectOfferingResponse | None


class TeacherAssignmentTeacher(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    first_name: str
    last_name: str
    email: str


class TeacherAssignmentAdminResponse(TeacherAssignmentResponse):
    teacher: TeacherAssignmentTeacher | None = None