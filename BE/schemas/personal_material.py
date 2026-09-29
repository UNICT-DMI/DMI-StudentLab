from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class PersonalMaterialUploadRequest(BaseModel):
    subject_id: int | None = None
    university: str | None = Field(default=None, max_length=255)
    department: str | None = Field(default=None, max_length=255)
    course: str | None = Field(default=None, max_length=255)
    subject_name: str | None = Field(default=None, max_length=255)
    original_name: str = Field(min_length=1, max_length=255)
    mime_type: str = Field(min_length=1, max_length=255)
    size: int = Field(gt=0)
    file_hash: str = Field(min_length=64, max_length=64)


class PersonalMaterialVerifyRequest(BaseModel):
    pathname: str = Field(min_length=1, max_length=1024)
    mime_type: str = Field(min_length=1, max_length=255)
    size: int = Field(gt=0)
    file_hash: str = Field(min_length=64, max_length=64)
    upload_token: str = Field(min_length=1)


class PersonalMaterialVerifyResponse(BaseModel):
    allowed: bool
    pathname: str
    mime_type: str
    size: int
    file_hash: str
    valid_until: int


class PersonalMaterialCompleteRequest(PersonalMaterialUploadRequest):
    pathname: str
    upload_token: str


class PersonalMaterialResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    owner_user_id: int
    subject_id: int | None
    university: str | None
    department: str | None
    course: str | None
    subject_name: str | None
    original_name: str
    mime_type: str
    size: int
    file_hash: str
    version: int
    status: str
    retention_status: str
    retention_warning_at: datetime | None
    retention_expires_at: datetime | None
    last_owner_activity_at: datetime
    last_downloaded_at: datetime | None
    created_at: datetime
    updated_at: datetime


class PersonalRetentionAction(BaseModel):
    action: str = Field(pattern="^(keep|delete)$")
