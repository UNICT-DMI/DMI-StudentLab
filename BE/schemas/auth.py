from datetime import date
from typing import Literal

from pydantic import BaseModel, Field, field_validator, model_validator

from services.password_policy import validate_password_policy


AcademicPathStatusValue = Literal[
    "enrolled",
    "graduated",
    "suspended",
    "withdrawn",
    "transferred",
]

UserRoleValue = Literal[
    "student",
    "teacher",
]


class RegisterRequest(BaseModel):
    first_name: str = Field(min_length=1, max_length=100)
    last_name: str = Field(min_length=1, max_length=100)
    email: str = Field(min_length=3, max_length=320)
    password: str = Field(min_length=8, max_length=128)
    date_of_birth: date
    policy_version: str = Field(min_length=1, max_length=50)
    privacy_acknowledged: bool
    terms_accepted: bool
    university: str | None = Field(default=None, max_length=255)
    university_code: str | None = Field(default=None, max_length=100)
    department: str | None = Field(default=None, max_length=255)
    department_code: str | None = Field(default=None, max_length=100)
    course: str | None = Field(default=None, max_length=255)
    course_code: str | None = Field(default=None, max_length=100)
    degree_type: str | None = Field(default=None, max_length=100)
    academic_status: AcademicPathStatusValue = "enrolled"
    start_year: int | None = Field(default=None, ge=1900, le=2200)
    graduation_year: int | None = Field(default=None, ge=1900, le=2200)
    description: str = Field(default="", max_length=2000)
    role: UserRoleValue
    available: bool = False
    available_for_help: bool | None = None
    available_for_private_lessons: bool | None = None
    willing_to_teach: bool | None = None

    @field_validator("password")
    @classmethod
    def validate_password(cls, value: str) -> str:
        return validate_password_policy(value)


class RegistrationResponse(BaseModel):
    registration_id: str
    email: str
    email_verification_required: bool = True
    expires_in: int


class EmailVerificationRequest(BaseModel):
    registration_id: str = Field(min_length=1, max_length=255)
    code: str = Field(pattern=r"^\d{6}$")


class EmailVerificationResendRequest(BaseModel):
    registration_id: str = Field(min_length=1, max_length=255)


class EmailVerificationResendResponse(BaseModel):
    registration_id: str
    email: str
    expires_in: int
    message: str


class PendingRegistrationEmailUpdateRequest(BaseModel):
    registration_id: str = Field(min_length=1, max_length=255)
    current_password: str = Field(min_length=1, max_length=128)
    new_email: str = Field(min_length=3, max_length=320)


class PendingRegistrationPasswordUpdateRequest(BaseModel):
    registration_id: str = Field(min_length=1, max_length=255)
    current_password: str = Field(min_length=1, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)
    confirm_password: str = Field(min_length=8, max_length=128)

    @field_validator("new_password")
    @classmethod
    def validate_new_password(cls, value: str) -> str:
        return validate_password_policy(value)

    @model_validator(mode="after")
    def validate_passwords(self):
        if self.new_password != self.confirm_password:
            raise ValueError("Le password non coincidono.")
        return self


class PendingRegistrationUpdateResponse(BaseModel):
    registration_id: str
    email: str
    message: str
    expires_in: int | None = None


class LoginRequest(BaseModel):
    email: str = Field(min_length=3, max_length=320)
    password: str = Field(min_length=1, max_length=128)


class LoginResponse(BaseModel):
    authenticated: bool
    email_verification_required: bool
    access_token: str | None = None
    token_type: str = "bearer"
    registration_id: str | None = None
    email: str | None = None
    expires_in: int | None = None


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class PasswordResetStartRequest(BaseModel):
    email: str = Field(min_length=3, max_length=320)


class PasswordResetStartResponse(BaseModel):
    request_id: str
    message: str


class PasswordResetCompleteRequest(BaseModel):
    request_id: str = Field(min_length=1, max_length=64)
    code: str = Field(pattern=r"^\d{6}$")
    new_password: str = Field(min_length=8, max_length=128)
    confirm_password: str = Field(min_length=8, max_length=128)

    @field_validator("new_password")
    @classmethod
    def validate_new_password(cls, value: str) -> str:
        return validate_password_policy(value)

    @model_validator(mode="after")
    def validate_passwords(self):
        if self.new_password != self.confirm_password:
            raise ValueError("Le password non coincidono.")
        return self


class PasswordResetCompleteResponse(BaseModel):
    success: bool
    message: str


class PasswordChangeRequest(BaseModel):
    current_password: str = Field(min_length=1, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)
    confirm_password: str = Field(min_length=8, max_length=128)

    @field_validator("new_password")
    @classmethod
    def validate_new_password(cls, value: str) -> str:
        return validate_password_policy(value)

    @model_validator(mode="after")
    def validate_passwords(self):
        if self.new_password != self.confirm_password:
            raise ValueError("Le password non coincidono.")
        return self


class PasswordChangeResponse(BaseModel):
    success: bool
    message: str


class EmailChangeStartRequest(BaseModel):
    current_password: str = Field(min_length=1, max_length=128)
    new_email: str = Field(min_length=3, max_length=320)


class EmailChangeStartResponse(BaseModel):
    request_id: str
    new_email: str
    message: str


class EmailChangeCompleteRequest(BaseModel):
    request_id: str = Field(min_length=1, max_length=64)
    code: str = Field(pattern=r"^\d{6}$")


class EmailChangeCompleteResponse(BaseModel):
    success: bool
    email: str
    message: str
