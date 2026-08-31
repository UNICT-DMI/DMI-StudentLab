from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class GroupOwnershipTransferCreate(BaseModel):
    proposed_owner_id: int


class GroupOwnershipTransferResponseAction(BaseModel):
    action: str = Field(
        min_length=1,
        max_length=20,
    )


class GroupOwnershipTransferUserSummary(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    first_name: str
    last_name: str


class GroupOwnershipTransferGroupSummary(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    name: str
    status: str


class GroupOwnershipTransferResponse(BaseModel):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    group_id: int
    current_owner_id: int
    proposed_owner_id: int
    account_deletion_request_id: int | None
    status: str
    created_at: datetime
    expires_at: datetime
    responded_at: datetime | None
    accepted_at: datetime | None
    rejected_at: datetime | None
    expired_at: datetime | None
    completed_at: datetime | None
    cancelled_at: datetime | None


class GroupOwnershipTransferDetailResponse(GroupOwnershipTransferResponse):
    group: GroupOwnershipTransferGroupSummary | None = None
    current_owner: GroupOwnershipTransferUserSummary | None = None
    proposed_owner: GroupOwnershipTransferUserSummary | None = None