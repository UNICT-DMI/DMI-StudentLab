from typing import Literal
from pydantic import BaseModel, Field

SupportConsentScope = Literal["diagnostic", "full_sqlite"]
SupportActionType = Literal[
    "collect_diagnostics",
    "force_material_sync",
    "clear_remote_cache",
    "purge_stale_remote_materials",
    "refresh_manifest",
]


class SupportSessionCreateRequest(BaseModel):
    issue_summary: str = Field(min_length=3, max_length=500)
    issue_details: str | None = Field(default=None, max_length=5000)


class SupportSessionAcceptRequest(BaseModel):
    session_minutes: int = Field(default=60, ge=15, le=120)


class SupportConsentRequest(BaseModel):
    accepted: bool
    scope: SupportConsentScope = "diagnostic"


class SupportHeartbeatRequest(BaseModel):
    app_version: str | None = Field(default=None, max_length=100)
    platform: str | None = Field(default=None, max_length=100)


class SupportSnapshotRequest(BaseModel):
    app_version: str | None = Field(default=None, max_length=100)
    platform: str | None = Field(default=None, max_length=100)
    database_version: int | None = Field(default=None, ge=0)
    payload: dict


class SupportRemoteActionCreateRequest(BaseModel):
    action: SupportActionType
    payload: dict | None = None


class SupportRemoteActionAckRequest(BaseModel):
    status: Literal["running", "completed", "failed", "rejected"]
    result: dict | None = None
