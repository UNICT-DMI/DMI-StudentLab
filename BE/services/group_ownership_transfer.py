from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from models.account_deletion_request import AccountDeletionRequest
from models.group import GroupMember, StudyGroup
from models.group_ownership_transfer import GroupOwnershipTransfer
from models.notification import Notification
from models.user import User


OWNERSHIP_TRANSFER_EXPIRATION_DAYS = 30

ACTIVE_GROUP_STATUSES = {
    "active",
    "pending_deletion",
}


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _get_group(
    db: Session,
    group_id: int,
) -> StudyGroup:
    group = (
        db.query(StudyGroup)
        .filter(
            StudyGroup.id == group_id,
        )
        .first()
    )

    if group is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Gruppo non trovato.",
        )

    return group


def _get_group_member(
    db: Session,
    group_id: int,
    user_id: int,
) -> GroupMember | None:
    return (
        db.query(GroupMember)
        .filter(
            GroupMember.group_id == group_id,
            GroupMember.user_id == user_id,
        )
        .first()
    )


def _get_transfer(
    db: Session,
    transfer_id: int,
) -> GroupOwnershipTransfer:
    transfer = (
        db.query(GroupOwnershipTransfer)
        .filter(
            GroupOwnershipTransfer.id == transfer_id,
        )
        .first()
    )

    if transfer is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Richiesta di trasferimento proprietà non trovata.",
        )

    return transfer


def _get_pending_transfer_for_group(
    db: Session,
    group_id: int,
) -> GroupOwnershipTransfer | None:
    return (
        db.query(GroupOwnershipTransfer)
        .filter(
            GroupOwnershipTransfer.group_id == group_id,
            GroupOwnershipTransfer.status == "pending",
        )
        .first()
    )


def _get_transfer_notification(
    db: Session,
    transfer_id: int,
) -> Notification | None:
    return (
        db.query(Notification)
        .filter(
            Notification.type == "group_ownership_transfer",
            Notification.action_resource_id == transfer_id,
        )
        .order_by(
            Notification.created_at.desc(),
        )
        .first()
    )


def _update_transfer_notification(
    db: Session,
    transfer: GroupOwnershipTransfer,
    action_status: str,
    now: datetime,
) -> None:
    notification = _get_transfer_notification(
        db,
        transfer.id,
    )

    if notification is None:
        return

    notification.action_status = action_status
    notification.is_read = True
    notification.read_at = now
    notification.updated_at = now


def _create_transfer_notification(
    db: Session,
    transfer: GroupOwnershipTransfer,
    group: StudyGroup,
    current_owner: User,
) -> Notification:
    notification = Notification(
        user_id=transfer.proposed_owner_id,
        actor_user_id=current_owner.id,
        type="group_ownership_transfer",
        title="Richiesta di proprietà del gruppo",
        message=(
            f"{current_owner.first_name} {current_owner.last_name} "
            f"ti ha proposto come nuovo proprietario del gruppo "
            f"\"{group.name}\"."
        ),
        resource_type="group",
        resource_id=group.id,
        action_type="accept_reject_group_ownership",
        action_resource_id=transfer.id,
        action_status="pending",
        is_read=False,
        read_at=None,
        expires_at=transfer.expires_at,
    )

    db.add(notification)

    return notification


def _delete_group_after_failed_transfer(
    db: Session,
    group: StudyGroup,
    now: datetime,
) -> None:
    group.status = "deleted"

    if group.deletion_requested_at is None:
        group.deletion_requested_at = now

    group.deletion_deadline = now
    group.updated_at = now


def _refresh_account_deletion_request(
    db: Session,
    account_deletion_request_id: int | None,
    user_id: int,
    now: datetime,
) -> None:
    if account_deletion_request_id is None:
        return

    deletion_request = (
        db.query(AccountDeletionRequest)
        .filter(
            AccountDeletionRequest.id == account_deletion_request_id,
            AccountDeletionRequest.user_id == user_id,
        )
        .first()
    )

    if deletion_request is None:
        return

    remaining_owned_groups = (
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
        .count()
    )

    if remaining_owned_groups == 0:
        deletion_request.status = "ready_for_deletion"
        deletion_request.ownership_resolution_deadline = None
    else:
        deletion_request.status = "waiting_group_transfer"

    deletion_request.updated_at = now


def create_group_ownership_transfer(
    db: Session,
    group_id: int,
    current_user: User,
    proposed_owner_id: int,
    account_deletion_request_id: int | None = None,
) -> GroupOwnershipTransfer:
    group = _get_group(
        db,
        group_id,
    )

    if group.status not in ACTIVE_GROUP_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Il gruppo non è disponibile per un trasferimento di proprietà.",
        )

    if group.created_by != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo il proprietario del gruppo può trasferirne la proprietà.",
        )

    if proposed_owner_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Non puoi proporre te stesso come nuovo proprietario.",
        )

    proposed_owner = (
        db.query(User)
        .filter(
            User.id == proposed_owner_id,
            User.is_active.is_(True),
        )
        .first()
    )

    if proposed_owner is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Utente proposto come nuovo proprietario non trovato.",
        )

    proposed_member = _get_group_member(
        db,
        group.id,
        proposed_owner_id,
    )

    if proposed_member is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Il nuovo proprietario deve essere già membro del gruppo.",
        )

    existing_transfer = _get_pending_transfer_for_group(
        db,
        group.id,
    )

    if existing_transfer is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Esiste già una richiesta di trasferimento proprietà in attesa per questo gruppo.",
        )

    deletion_request = None

    if account_deletion_request_id is not None:
        deletion_request = (
            db.query(AccountDeletionRequest)
            .filter(
                AccountDeletionRequest.id == account_deletion_request_id,
                AccountDeletionRequest.user_id == current_user.id,
            )
            .first()
        )

        if deletion_request is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Richiesta di eliminazione account non trovata.",
            )

        if deletion_request.status != "waiting_group_transfer":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="La richiesta di eliminazione account non è in attesa di trasferimento gruppi.",
            )

    now = _now()
    expires_at = now + timedelta(
        days=OWNERSHIP_TRANSFER_EXPIRATION_DAYS,
    )

    transfer = GroupOwnershipTransfer(
        group_id=group.id,
        current_owner_id=current_user.id,
        proposed_owner_id=proposed_owner.id,
        account_deletion_request_id=account_deletion_request_id,
        status="pending",
        created_at=now,
        expires_at=expires_at,
        responded_at=None,
        accepted_at=None,
        rejected_at=None,
        expired_at=None,
        completed_at=None,
        cancelled_at=None,
    )

    db.add(transfer)
    db.flush()

    group.status = "pending_deletion"
    group.deletion_requested_at = (
        group.deletion_requested_at or now
    )
    group.deletion_deadline = expires_at
    group.updated_at = now

    if deletion_request is not None:
        if (
            deletion_request.ownership_resolution_deadline is None
            or expires_at > deletion_request.ownership_resolution_deadline
        ):
            deletion_request.ownership_resolution_deadline = expires_at

        deletion_request.updated_at = now

    _create_transfer_notification(
        db,
        transfer,
        group,
        current_user,
    )

    db.commit()
    db.refresh(transfer)

    return transfer


def get_group_ownership_transfer(
    db: Session,
    transfer_id: int,
    current_user: User,
) -> GroupOwnershipTransfer:
    transfer = _get_transfer(
        db,
        transfer_id,
    )

    if (
        current_user.role not in {
            "admin",
            "creator",
        }
        and current_user.id
        not in {
            transfer.current_owner_id,
            transfer.proposed_owner_id,
        }
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Non sei autorizzato a visualizzare questa richiesta.",
        )

    if transfer.status == "pending":
        expire_group_ownership_transfer_if_needed(
            db,
            transfer,
        )

    return transfer


def get_my_incoming_group_ownership_transfers(
    db: Session,
    current_user: User,
) -> list[GroupOwnershipTransfer]:
    transfers = (
        db.query(GroupOwnershipTransfer)
        .filter(
            GroupOwnershipTransfer.proposed_owner_id == current_user.id,
        )
        .order_by(
            GroupOwnershipTransfer.created_at.desc(),
        )
        .all()
    )

    for transfer in transfers:
        if transfer.status == "pending":
            expire_group_ownership_transfer_if_needed(
                db,
                transfer,
                commit=False,
            )

    db.commit()

    return transfers


def get_my_outgoing_group_ownership_transfers(
    db: Session,
    current_user: User,
) -> list[GroupOwnershipTransfer]:
    transfers = (
        db.query(GroupOwnershipTransfer)
        .filter(
            GroupOwnershipTransfer.current_owner_id == current_user.id,
        )
        .order_by(
            GroupOwnershipTransfer.created_at.desc(),
        )
        .all()
    )

    for transfer in transfers:
        if transfer.status == "pending":
            expire_group_ownership_transfer_if_needed(
                db,
                transfer,
                commit=False,
            )

    db.commit()

    return transfers


def accept_group_ownership_transfer(
    db: Session,
    transfer_id: int,
    current_user: User,
) -> GroupOwnershipTransfer:
    transfer = _get_transfer(
        db,
        transfer_id,
    )

    if transfer.proposed_owner_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo l'utente proposto può accettare questa richiesta.",
        )

    expire_group_ownership_transfer_if_needed(
        db,
        transfer,
    )

    if transfer.status != "pending":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Questa richiesta di trasferimento non è più disponibile.",
        )

    group = _get_group(
        db,
        transfer.group_id,
    )

    if group.created_by != transfer.current_owner_id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Il proprietario del gruppo è già cambiato.",
        )

    proposed_member = _get_group_member(
        db,
        group.id,
        transfer.proposed_owner_id,
    )

    if proposed_member is None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Non fai più parte del gruppo.",
        )

    old_owner_member = _get_group_member(
        db,
        group.id,
        transfer.current_owner_id,
    )

    now = _now()

    proposed_member.role = "owner"

    if old_owner_member is not None:
        old_owner_member.role = "member"

    group.created_by = transfer.proposed_owner_id
    group.status = "active"
    group.deletion_requested_at = None
    group.deletion_deadline = None
    group.updated_at = now

    transfer.status = "completed"
    transfer.responded_at = now
    transfer.accepted_at = now
    transfer.completed_at = now

    _update_transfer_notification(
        db,
        transfer,
        "accepted",
        now,
    )

    _refresh_account_deletion_request(
        db,
        transfer.account_deletion_request_id,
        transfer.current_owner_id,
        now,
    )

    db.commit()
    db.refresh(transfer)

    return transfer


def reject_group_ownership_transfer(
    db: Session,
    transfer_id: int,
    current_user: User,
) -> GroupOwnershipTransfer:
    transfer = _get_transfer(
        db,
        transfer_id,
    )

    if transfer.proposed_owner_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo l'utente proposto può rifiutare questa richiesta.",
        )

    expire_group_ownership_transfer_if_needed(
        db,
        transfer,
    )

    if transfer.status != "pending":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Questa richiesta di trasferimento non è più disponibile.",
        )

    group = _get_group(
        db,
        transfer.group_id,
    )

    now = _now()

    transfer.status = "rejected"
    transfer.responded_at = now
    transfer.rejected_at = now

    _delete_group_after_failed_transfer(
        db,
        group,
        now,
    )

    _update_transfer_notification(
        db,
        transfer,
        "rejected",
        now,
    )

    _refresh_account_deletion_request(
        db,
        transfer.account_deletion_request_id,
        transfer.current_owner_id,
        now,
    )

    db.commit()
    db.refresh(transfer)

    return transfer


def cancel_group_ownership_transfer(
    db: Session,
    transfer_id: int,
    current_user: User,
) -> GroupOwnershipTransfer:
    transfer = _get_transfer(
        db,
        transfer_id,
    )

    if transfer.current_owner_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo il proprietario che ha creato la richiesta può annullarla.",
        )

    expire_group_ownership_transfer_if_needed(
        db,
        transfer,
    )

    if transfer.status != "pending":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Questa richiesta non può più essere annullata.",
        )

    group = _get_group(
        db,
        transfer.group_id,
    )

    now = _now()

    transfer.status = "cancelled"
    transfer.cancelled_at = now

    group.status = "active"
    group.deletion_requested_at = None
    group.deletion_deadline = None
    group.updated_at = now

    _update_transfer_notification(
        db,
        transfer,
        "cancelled",
        now,
    )

    if transfer.account_deletion_request_id is not None:
        deletion_request = (
            db.query(AccountDeletionRequest)
            .filter(
                AccountDeletionRequest.id
                == transfer.account_deletion_request_id,
            )
            .first()
        )

        if deletion_request is not None:
            deletion_request.status = "waiting_group_transfer"
            deletion_request.updated_at = now

    db.commit()
    db.refresh(transfer)

    return transfer


def expire_group_ownership_transfer_if_needed(
    db: Session,
    transfer: GroupOwnershipTransfer,
    commit: bool = True,
) -> bool:
    if transfer.status != "pending":
        return False

    now = _now()

    if transfer.expires_at > now:
        return False

    group = (
        db.query(StudyGroup)
        .filter(
            StudyGroup.id == transfer.group_id,
        )
        .first()
    )

    transfer.status = "expired"
    transfer.expired_at = now

    if group is not None:
        _delete_group_after_failed_transfer(
            db,
            group,
            now,
        )

    _update_transfer_notification(
        db,
        transfer,
        "expired",
        now,
    )

    _refresh_account_deletion_request(
        db,
        transfer.account_deletion_request_id,
        transfer.current_owner_id,
        now,
    )

    if commit:
        db.commit()
        db.refresh(transfer)

    return True


def process_expired_group_ownership_transfers(
    db: Session,
) -> int:
    now = _now()

    transfers = (
        db.query(GroupOwnershipTransfer)
        .filter(
            GroupOwnershipTransfer.status == "pending",
            GroupOwnershipTransfer.expires_at <= now,
        )
        .all()
    )

    expired_count = 0

    for transfer in transfers:
        expired = expire_group_ownership_transfer_if_needed(
            db,
            transfer,
            commit=False,
        )

        if expired:
            expired_count += 1

    db.commit()

    return expired_count