from fastapi import (
    APIRouter,
    Depends,
    status,
)

from sqlalchemy.orm import Session

from core.database import get_db
from core.security import (
    get_admin_user,
    get_current_user,
)

from models.user import User

from schemas.account_deletion_request import (
    AccountDeletionRequestCreate,
    AccountDeletionRequestDetailResponse,
    AccountDeletionRequestResponse,
)

from services.account_deletion_request import (
    admin_delete_user_account,
    cancel_account_deletion_request,
    complete_account_deletion,
    create_account_deletion_request,
    get_account_deletion_request_by_id,
    get_account_deletion_request_detail,
    get_my_account_deletion_request,
    get_pending_account_deletion_requests,
    refresh_account_deletion_request_status,
)


router = APIRouter(
    tags=[
        "Account Deletion",
    ],
)


@router.post(
    "/me/account-deletion",
    response_model=AccountDeletionRequestResponse,
    status_code=status.HTTP_201_CREATED,
)
def api_create_account_deletion_request(
    request: AccountDeletionRequestCreate,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return create_account_deletion_request(
        db,
        current_user=current_user,
        payload=request,
    )


@router.get(
    "/me/account-deletion",
    response_model=AccountDeletionRequestResponse,
)
def api_get_my_account_deletion_request(
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    deletion_request = get_my_account_deletion_request(
        db,
        current_user=current_user,
    )

    return refresh_account_deletion_request_status(
        db,
        deletion_request,
    )


@router.get(
    "/me/account-deletion/detail",
    response_model=AccountDeletionRequestDetailResponse,
)
def api_get_my_account_deletion_request_detail(
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    deletion_request = get_my_account_deletion_request(
        db,
        current_user=current_user,
    )

    deletion_request = refresh_account_deletion_request_status(
        db,
        deletion_request,
    )

    return get_account_deletion_request_detail(
        db,
        request_id=deletion_request.id,
        current_user=current_user,
    )


@router.post(
    "/me/account-deletion/cancel",
    response_model=AccountDeletionRequestResponse,
)
def api_cancel_account_deletion_request(
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return cancel_account_deletion_request(
        db,
        current_user=current_user,
    )


@router.post(
    "/me/account-deletion/complete",
    response_model=AccountDeletionRequestResponse,
)
def api_complete_account_deletion(
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return complete_account_deletion(
        db,
        current_user=current_user,
    )


@router.get(
    "/admin/account-deletions",
    response_model=list[
        AccountDeletionRequestResponse
    ],
)
def api_admin_pending_account_deletions(
    current_user: User = Depends(
        get_admin_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return get_pending_account_deletion_requests(
        db,
    )


@router.get(
    "/admin/account-deletions/{request_id}",
    response_model=AccountDeletionRequestDetailResponse,
)
def api_admin_account_deletion_detail(
    request_id: int,
    current_user: User = Depends(
        get_admin_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    deletion_request = get_account_deletion_request_by_id(
        db,
        request_id=request_id,
        current_user=current_user,
    )

    deletion_request = refresh_account_deletion_request_status(
        db,
        deletion_request,
    )

    return get_account_deletion_request_detail(
        db,
        request_id=deletion_request.id,
        current_user=current_user,
    )


@router.delete(
    "/admin/users/{user_id}",
)
def api_admin_delete_user_account(
    user_id: int,
    current_user: User = Depends(
        get_admin_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    deleted_user = admin_delete_user_account(
        db,
        current_user=current_user,
        user_id=user_id,
    )

    return {
        "deleted": True,
        "user_id": deleted_user.id,
    }