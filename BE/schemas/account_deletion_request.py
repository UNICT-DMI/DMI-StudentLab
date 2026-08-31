from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class AccountDeletionRequestCreate(BaseModel):
    reason: str = Field(
        default="user_request",
        min_length=1,
        max_length=100,
    )
    note: str = Field(
        default="",
        max_length=5000,
    )


class AccountDeletionRequestCancel(BaseModel):
    note: str = Field(
        default="",
        max_length=5000,
    )


class AccountDeletionOwnedGroupSummary(BaseModel):
    id: int
    name: str
    status: str
    requires_ownership_transfer: bool = True


class AccountDeletionOwnershipTransferSummary(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    group_id: int
    current_owner_id: int
    proposed_owner_id: int
    status: str
    created_at: datetime
    expires_at: datetime
    responded_at: datetime | None
    accepted_at: datetime | None
    rejected_at: datetime | None
    expired_at: datetime | None
    completed_at: datetime | None
    cancelled_at: datetime | None


class AccountDeletionRequestResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    user_id: int
    status: str
    reason: str
    note: str
    requested_at: datetime
    ownership_resolution_deadline: datetime | None
    completed_at: datetime | None
    cancelled_at: datetime | None
    created_at: datetime
    updated_at: datetime


class AccountDeletionRequestDetailResponse(AccountDeletionRequestResponse):
    owned_groups: list[AccountDeletionOwnedGroupSummary] = []
    ownership_transfers: list[AccountDeletionOwnershipTransferSummary] = []
    can_delete_immediately: bool = False