from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from models.account_deletion_request import AccountDeletionRequest
from models.group import StudyGroup
from models.group_ownership_transfer import GroupOwnershipTransfer
from models.user import User
from schemas.account_deletion_request import (
    AccountDeletionOwnedGroupSummary,
    AccountDeletionOwnershipTransferSummary,
    AccountDeletionRequestCreate,
    AccountDeletionRequestDetailResponse,
    AccountDeletionRequestResponse,
)
from services.account_anonymization import (
    anonymize_and_delete_user_personal_data,
)

ACTIVE_DELETION_STATUSES = {
    "pending",
    "waiting_group_transfer",
    "ready_for_deletion",
}

OWNERSHIP_TRANSFER_EXPIRATION_DAYS = 30

def _get_owned_groups(
    db: Session,
    user_id: int,
) -> list[StudyGroup]:
    return (
        db.query(StudyGroup)
        .filter(
            StudyGroup.created_by == user_id,
            StudyGroup.status.in_(
                [
                    "active",
                    "pending_deletion",
                ]
            ),
        )
        .order_by(
            StudyGroup.created_at.asc(),
        )
        .all()
    )

def _get_deletion_transfers(
    db: Session,
    deletion_request_id: int,
) -> list[GroupOwnershipTransfer]:
    return (
        db.query(GroupOwnershipTransfer)
        .filter(
            GroupOwnershipTransfer.account_deletion_request_id
            == deletion_request_id,
        )
        .order_by(
            GroupOwnershipTransfer.created_at.asc(),
        )
        .all()
    )

def _get_active_deletion_request(
    db: Session,
    user_id: int,
) -> AccountDeletionRequest | None:
    return (
        db.query(AccountDeletionRequest)
        .filter(
            AccountDeletionRequest.user_id == user_id,
            AccountDeletionRequest.status.in_(
                list(ACTIVE_DELETION_STATUSES)
            ),
        )
        .order_by(
            AccountDeletionRequest.created_at.desc(),
        )
        .first()
    )

def create_account_deletion_request(
    db: Session,
    current_user: User,
    payload: AccountDeletionRequestCreate,
) -> AccountDeletionRequest:
    existing_request = _get_active_deletion_request(
        db,
        current_user.id,
    )

    if existing_request is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Esiste già una richiesta di eliminazione account attiva.",
        )

    owned_groups = _get_owned_groups(
        db,
        current_user.id,
    )

    now = datetime.now(
        timezone.utc,
    )

    if owned_groups:
        request_status = "waiting_group_transfer"
        ownership_resolution_deadline = (
            now
            + timedelta(
                days=OWNERSHIP_TRANSFER_EXPIRATION_DAYS,
            )
        )
    else:
        request_status = "ready_for_deletion"
        ownership_resolution_deadline = None

    deletion_request = AccountDeletionRequest(
        user_id=current_user.id,
        status=request_status,
        reason=payload.reason,
        note=payload.note.strip(),
        requested_at=now,
        ownership_resolution_deadline=ownership_resolution_deadline,
        completed_at=None,
        cancelled_at=None,
    )

    db.add(
        deletion_request,
    )

    if owned_groups:
        for group in owned_groups:
            group.status = "pending_deletion"
            group.deletion_requested_at = now
            group.deletion_deadline = ownership_resolution_deadline

    db.commit()
    db.refresh(
        deletion_request,
    )

    return deletion_request

def get_my_account_deletion_request(
    db: Session,
    current_user: User,
) -> AccountDeletionRequest:
    deletion_request = (
        db.query(AccountDeletionRequest)
        .filter(
            AccountDeletionRequest.user_id == current_user.id,
        )
        .order_by(
            AccountDeletionRequest.created_at.desc(),
        )
        .first()
    )

    if deletion_request is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Nessuna richiesta di eliminazione account trovata.",
        )

    return deletion_request

def get_account_deletion_request_by_id(
    db: Session,
    request_id: int,
    current_user: User,
) -> AccountDeletionRequest:
    deletion_request = (
        db.query(AccountDeletionRequest)
        .filter(
            AccountDeletionRequest.id == request_id,
        )
        .first()
    )

    if deletion_request is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Richiesta di eliminazione account non trovata.",
        )

    if (
        current_user.role not in {
            "admin",
            "creator",
        }
        and deletion_request.user_id != current_user.id
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Non sei autorizzato a visualizzare questa richiesta.",
        )

    return deletion_request

def get_account_deletion_request_detail(
    db: Session,
    request_id: int,
    current_user: User,
) -> AccountDeletionRequestDetailResponse:
    deletion_request = get_account_deletion_request_by_id(
        db,
        request_id,
        current_user,
    )

    owned_groups = _get_owned_groups(
        db,
        deletion_request.user_id,
    )

    transfers = _get_deletion_transfers(
        db,
        deletion_request.id,
    )

    owned_group_summaries = [
        AccountDeletionOwnedGroupSummary(
            id=group.id,
            name=group.name,
            status=group.status,
            requires_ownership_transfer=True,
        )
        for group in owned_groups
    ]

    transfer_summaries = [
        AccountDeletionOwnershipTransferSummary.model_validate(
            transfer
        )
        for transfer in transfers
    ]

    base_response = AccountDeletionRequestResponse.model_validate(
        deletion_request
    )

    return AccountDeletionRequestDetailResponse(
        **base_response.model_dump(),
        owned_groups=owned_group_summaries,
        ownership_transfers=transfer_summaries,
        can_delete_immediately=(
            deletion_request.status == "ready_for_deletion"
            and len(owned_groups) == 0
        ),
    )

def get_pending_account_deletion_requests(
    db: Session,
) -> list[AccountDeletionRequest]:
    return (
        db.query(AccountDeletionRequest)
        .filter(
            AccountDeletionRequest.status.in_(
                [
                    "pending",
                    "waiting_group_transfer",
                    "ready_for_deletion",
                ]
            )
        )
        .order_by(
            AccountDeletionRequest.requested_at.asc(),
        )
        .all()
    )

def cancel_account_deletion_request(
    db: Session,
    current_user: User,
) -> AccountDeletionRequest:
    deletion_request = _get_active_deletion_request(
        db,
        current_user.id,
    )

    if deletion_request is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Nessuna richiesta di eliminazione account attiva.",
        )

    transfers = _get_deletion_transfers(
        db,
        deletion_request.id,
    )

    if any(
        transfer.status in {
            "accepted",
            "completed",
        }
        for transfer in transfers
    ):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="La richiesta non può essere annullata perché almeno un trasferimento di proprietà è già stato accettato.",
        )

    now = datetime.now(
        timezone.utc,
    )

    for transfer in transfers:
        if transfer.status == "pending":
            transfer.status = "cancelled"
            transfer.cancelled_at = now

    owned_groups = _get_owned_groups(
        db,
        current_user.id,
    )

    for group in owned_groups:
        if group.status == "pending_deletion":
            group.status = "active"
            group.deletion_requested_at = None
            group.deletion_deadline = None

    deletion_request.status = "cancelled"
    deletion_request.cancelled_at = now
    deletion_request.updated_at = now

    db.commit()
    db.refresh(
        deletion_request,
    )

    return deletion_request

def refresh_account_deletion_request_status(
    db: Session,
    deletion_request: AccountDeletionRequest,
) -> AccountDeletionRequest:
    if deletion_request.status not in ACTIVE_DELETION_STATUSES:
        return deletion_request

    owned_groups = _get_owned_groups(
        db,
        deletion_request.user_id,
    )

    now = datetime.now(
        timezone.utc,
    )

    if not owned_groups:
        deletion_request.status = "ready_for_deletion"
        deletion_request.ownership_resolution_deadline = None
        deletion_request.updated_at = now

        db.commit()
        db.refresh(
            deletion_request,
        )

        return deletion_request

    deletion_request.status = "waiting_group_transfer"

    if deletion_request.ownership_resolution_deadline is None:
        deletion_request.ownership_resolution_deadline = (
            now
            + timedelta(
                days=OWNERSHIP_TRANSFER_EXPIRATION_DAYS,
            )
        )

    deletion_request.updated_at = now

    db.commit()
    db.refresh(
        deletion_request,
    )

    return deletion_request

def admin_delete_user_account(
    db: Session,
    current_user: User,
    user_id: int,
) -> User:
    if user_id <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Identificativo utente non valido.",
        )

    if current_user.id == user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                "Non puoi eliminare il tuo account dalla gestione utenti. "
                "Usa il flusso di eliminazione del profilo personale."
            ),
        )

    target_user = (
        db.query(User)
        .filter(
            User.id == user_id,
        )
        .first()
    )

    if target_user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Utente non trovato.",
        )

    owned_groups = _get_owned_groups(
        db,
        target_user.id,
    )

    if owned_groups:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                "L'account non può essere eliminato finché l'utente "
                "possiede gruppi attivi o in attesa di eliminazione."
            ),
        )

    active_request = _get_active_deletion_request(
        db,
        target_user.id,
    )

    now = datetime.now(
        timezone.utc,
    )

    try:
        anonymize_and_delete_user_personal_data(
            db,
            target_user,
        )

        if active_request is not None:
            active_request.status = "completed"
            active_request.completed_at = now
            active_request.ownership_resolution_deadline = None
            active_request.updated_at = now

        db.commit()
        db.refresh(
            target_user,
        )

        return target_user

    except HTTPException:
        db.rollback()
        raise

    except Exception as exc:
        db.rollback()

        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Impossibile eliminare l'account utente.",
        ) from exc

def complete_account_deletion(
    db: Session,
    current_user: User,
) -> AccountDeletionRequest:
    deletion_request = _get_active_deletion_request(
        db,
        current_user.id,
    )

    if deletion_request is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Nessuna richiesta di eliminazione account attiva.",
        )

    deletion_request = refresh_account_deletion_request_status(
        db,
        deletion_request,
    )

    if deletion_request.status != "ready_for_deletion":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="L'account non può ancora essere eliminato perché esistono gruppi di cui sei proprietario.",
        )

    now = datetime.now(
        timezone.utc,
    )

    try:
        anonymize_and_delete_user_personal_data(
            db,
            current_user,
        )

        deletion_request.status = "completed"
        deletion_request.completed_at = now
        deletion_request.ownership_resolution_deadline = None
        deletion_request.updated_at = now

        db.commit()
        db.refresh(
            deletion_request,
        )

        return deletion_request

    except HTTPException:
        db.rollback()
        raise

    except Exception as exc:
        db.rollback()

        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Impossibile completare l'eliminazione dell'account.",
        ) from exc