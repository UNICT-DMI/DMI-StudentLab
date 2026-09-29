from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class MaterialShareUploadRequest(BaseModel):
    recipient_user_id: int
    subject_id: int | None = None
    original_name: str = Field(min_length=1, max_length=255)
    mime_type: str = Field(min_length=1, max_length=255)
    size: int = Field(gt=0)
    file_hash: str = Field(min_length=64, max_length=64)
    message: str | None = Field(default=None, max_length=2000)


class MaterialShareVerifyRequest(BaseModel):
    recipient_user_id: int
    pathname: str = Field(min_length=1, max_length=1024)
    mime_type: str = Field(min_length=1, max_length=255)
    size: int = Field(gt=0)
    file_hash: str = Field(min_length=64, max_length=64)
    upload_token: str = Field(min_length=1)


class MaterialShareVerifyResponse(BaseModel):
    allowed: bool
    recipient_user_id: int
    pathname: str
    mime_type: str
    size: int
    file_hash: str
    valid_until: int


class MaterialShareCompleteRequest(MaterialShareUploadRequest):
    pathname: str
    upload_token: str


class MaterialShareResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    sender_user_id: int
    recipient_user_id: int
    subject_id: int | None
    original_name: str
    mime_type: str
    size: int
    file_hash: str
    message: str | None
    status: str
    cloud_expires_at: datetime
    accepted_at: datetime | None
    delivered_at: datetime | None
    rejected_at: datetime | None
    created_at: datetime
    updated_at: datetime
