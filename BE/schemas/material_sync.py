from datetime import datetime

from typing import Literal

from pydantic import (
    BaseModel,
    Field,
)


MaterialSyncSource = Literal[
    "public",
    "teacher",
    "group",
]


MaterialSyncStatus = Literal[
    "active",
    "hidden",
    "removed",
]


class MaterialSyncItem(BaseModel):
    key: str

    source: MaterialSyncSource

    material_id: int = Field(
        gt=0,
    )

    subject_id: int | None = Field(
        default=None,
        gt=0,
    )

    group_id: int | None = Field(
        default=None,
        gt=0,
    )

    version: int = Field(
        ge=1,
    )

    status: MaterialSyncStatus

    is_active: bool

    is_visible: bool

    is_tombstone: bool

    original_name: str | None = None

    mime_type: str | None = None

    size: int | None = Field(
        default=None,
        ge=0,
    )

    file_hash: str | None = None

    updated_at: datetime | None = None

    removed_at: datetime | None = None


class MaterialSyncManifestResponse(
    BaseModel,
):
    generated_at: datetime

    since: datetime | None = None

    incremental: bool

    visible_keys: list[str]

    items: list[
        MaterialSyncItem
    ]