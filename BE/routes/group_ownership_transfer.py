from fastapi import (
    APIRouter,
    Depends,
    status,
)

from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_current_user

from models.user import User

from schemas.group_ownership_transfer import (
    GroupOwnershipTransferCreate,
    GroupOwnershipTransferDetailResponse,
    GroupOwnershipTransferResponse,
    GroupOwnershipTransferResponseAction,
)

from services.group_ownership_transfer import (
    accept_group_ownership_transfer,
    cancel_group_ownership_transfer,
    create_group_ownership_transfer,
    get_group_ownership_transfer,
    get_my_incoming_group_ownership_transfers,
    get_my_outgoing_group_ownership_transfers,
    reject_group_ownership_transfer,
)


router = APIRouter(
    tags=[
        "Group Ownership Transfer",
    ],
)


@router.post(
    "/groups/{group_id}/ownership-transfer",
    response_model=GroupOwnershipTransferResponse,
    status_code=status.HTTP_201_CREATED,
)
def api_create_group_ownership_transfer(
    group_id: int,
    request: GroupOwnershipTransferCreate,
    account_deletion_request_id: int | None = None,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return create_group_ownership_transfer(
        db,
        group_id=group_id,
        current_user=current_user,
        proposed_owner_id=request.proposed_owner_id,
        account_deletion_request_id=account_deletion_request_id,
    )


@router.get(
    "/group-ownership-transfers/incoming",
    response_model=list[
        GroupOwnershipTransferDetailResponse
    ],
)
def api_incoming_group_ownership_transfers(
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return get_my_incoming_group_ownership_transfers(
        db,
        current_user=current_user,
    )


@router.get(
    "/group-ownership-transfers/outgoing",
    response_model=list[
        GroupOwnershipTransferDetailResponse
    ],
)
def api_outgoing_group_ownership_transfers(
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return get_my_outgoing_group_ownership_transfers(
        db,
        current_user=current_user,
    )


@router.get(
    "/group-ownership-transfers/{transfer_id}",
    response_model=GroupOwnershipTransferDetailResponse,
)
def api_group_ownership_transfer(
    transfer_id: int,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return get_group_ownership_transfer(
        db,
        transfer_id=transfer_id,
        current_user=current_user,
    )


@router.post(
    "/group-ownership-transfers/{transfer_id}/respond",
    response_model=GroupOwnershipTransferResponse,
)
def api_respond_group_ownership_transfer(
    transfer_id: int,
    request: GroupOwnershipTransferResponseAction,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    action = request.action.strip().lower()

    if action == "accept":
        return accept_group_ownership_transfer(
            db,
            transfer_id=transfer_id,
            current_user=current_user,
        )

    if action == "reject":
        return reject_group_ownership_transfer(
            db,
            transfer_id=transfer_id,
            current_user=current_user,
        )

    from fastapi import HTTPException

    raise HTTPException(
        status_code=status.HTTP_400_BAD_REQUEST,
        detail="Azione non valida. Usa 'accept' oppure 'reject'.",
    )


@router.post(
    "/group-ownership-transfers/{transfer_id}/accept",
    response_model=GroupOwnershipTransferResponse,
)
def api_accept_group_ownership_transfer(
    transfer_id: int,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return accept_group_ownership_transfer(
        db,
        transfer_id=transfer_id,
        current_user=current_user,
    )


@router.post(
    "/group-ownership-transfers/{transfer_id}/reject",
    response_model=GroupOwnershipTransferResponse,
)
def api_reject_group_ownership_transfer(
    transfer_id: int,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return reject_group_ownership_transfer(
        db,
        transfer_id=transfer_id,
        current_user=current_user,
    )


@router.post(
    "/group-ownership-transfers/{transfer_id}/cancel",
    response_model=GroupOwnershipTransferResponse,
)
def api_cancel_group_ownership_transfer(
    transfer_id: int,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return cancel_group_ownership_transfer(
        db,
        transfer_id=transfer_id,
        current_user=current_user,
    )
