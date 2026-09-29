
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


MaterialSyncSource = Literal["public","teacher","group","personal_sync","shared_user"]


class MaterialSyncItem(BaseModel):
    key: str
    source: MaterialSyncSource
    material_id: int
    subject_id: int | None = None
    group_id: int | None = None
    version: int = Field(default=1, ge=1)
    status: str
    is_active: bool
    is_visible: bool
    is_tombstone: bool
    original_name: str | None = None
    university: str | None = None
    department: str | None = None
    course: str | None = None
    subject_name: str | None = None
    course_scope: str = 'degree'
    path_segments: list[str] = Field(default_factory=list)
    mime_type: str | None = None
    size: int | None = None
    file_hash: str | None = None
    cloud_policy: str | None = None
    cloud_expires_at: datetime | None = None
    retention_status: str | None = None
    shared_by_user_id: int | None = None
    updated_at: datetime | None = None
    removed_at: datetime | None = None


class MaterialSyncManifestResponse(BaseModel):
    generated_at: datetime
    incremental: bool
    visible_keys: list[str]
    items: list[MaterialSyncItem]
