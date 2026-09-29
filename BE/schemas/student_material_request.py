from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class StudentMaterialRequestCreate(BaseModel):
    recipient_user_id: int
    subject_id: int | None = None
    topic: str | None = Field(default=None, max_length=255)
    message: str = Field(min_length=1, max_length=3000)


class StudentMaterialRequestResolve(BaseModel):
    action: str = Field(pattern="^(fulfilled|declined)$")
    fulfilled_share_id: int | None = None


class StudentMaterialRequestResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    requester_user_id: int
    recipient_user_id: int
    subject_id: int | None
    subject_name: str | None = None
    recipient_name: str | None = None
    requester_name: str | None = None
    topic: str | None
    message: str
    status: str
    fulfilled_share_id: int | None
    resolved_at: datetime | None
    created_at: datetime
    updated_at: datetime
