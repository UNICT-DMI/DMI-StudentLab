from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


MaterialStorageSource = Literal[
    "publication_request",
    "public",
    "teacher",
    "group",
    "personal_sync",
    "shared_user",
]


class AdminMaterialStorageRenameRequest(BaseModel):
    display_name: str = Field(min_length=1, max_length=250)


class AdminMaterialStorageRetireRequest(BaseModel):
    reason: str = Field(min_length=1, max_length=2000)


class AdminMaterialStorageDeleteBlobRequest(BaseModel):
    confirmation: Literal["ELIMINA"]


class AdminMaterialStorageRejectRequest(BaseModel):
    rejection_reason: str = Field(min_length=1, max_length=2000)
    admin_note: str | None = Field(default=None, max_length=4000)
    delete_blob: bool = True


class AdminMaterialStorageCleanupRequest(BaseModel):
    confirmation: Literal["ELIMINA"]
    rejected_publications: bool = True
    removed_materials: bool = True
    orphan_blobs: bool = False


class AdminMaterialStorageEventResponse(BaseModel):
    id: int
    source: str
    material_id: int | None
    action: str
    blob_path: str | None
    original_name: str | None
    size: int | None
    actor_id: int | None
    reason: str | None
    created_at: datetime


class AdminMovePublicFolderRequest(BaseModel):
    source_subject_id: int = Field(gt=0)
    source_path: list[str] = Field(min_length=1, max_length=8)
    destination_subject_id: int = Field(gt=0)
    destination_path: list[str] = Field(default_factory=list, max_length=8)


class AdminPlacePublicMaterialRequest(BaseModel):
    subject_id: int = Field(gt=0)
    path_segments: list[str] = Field(default_factory=list, max_length=8)


class AdminPublicVisibilityRequest(BaseModel):
    state: Literal['visible', 'hidden', 'in_review', 'archived']


class AdminPublicAudienceRequest(BaseModel):
    audience_type: Literal['public', 'course', 'subject', 'group', 'user']
    audience_id: int | None = Field(default=None, gt=0)
