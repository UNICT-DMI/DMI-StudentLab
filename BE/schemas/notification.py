from datetime import datetime

from pydantic import BaseModel, ConfigDict


class NotificationUserSummary(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    first_name: str
    last_name: str


class NotificationResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    user_id: int
    actor_user_id: int | None
    type: str
    title: str
    message: str
    resource_type: str | None
    resource_id: int | None
    action_type: str | None
    action_resource_id: int | None
    action_status: str
    is_read: bool
    read_at: datetime | None
    expires_at: datetime | None
    created_at: datetime
    updated_at: datetime


class NotificationDetailResponse(NotificationResponse):
    actor: NotificationUserSummary | None = None


class NotificationListResponse(BaseModel):
    notifications: list[NotificationResponse]
    unread_count: int


class NotificationUnreadCountResponse(BaseModel):
    unread_count: int


class NotificationMarkReadResponse(BaseModel):
    id: int
    is_read: bool
    read_at: datetime | None


class NotificationMarkAllReadResponse(BaseModel):
    updated_count: int
    unread_count: int