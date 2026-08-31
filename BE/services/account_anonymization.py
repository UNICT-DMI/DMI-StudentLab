import secrets
from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from models.group import (
    GroupJoinRequest,
    GroupMember,
)
from models.group_ownership_transfer import GroupOwnershipTransfer
from models.notification import Notification
from models.subject import UserSubject
from models.teacher_assignment import TeacherAssignment
from models.user import (
    User,
    UserAcademicPath,
)
from services.auth import hash_password


def ensure_user_can_be_anonymized(
    db: Session,
    user: User,
) -> None:
    pending_owned_transfers = (
        db.query(GroupOwnershipTransfer)
        .filter(
            GroupOwnershipTransfer.current_owner_id == user.id,
            GroupOwnershipTransfer.status == "pending",
        )
        .count()
    )

    if pending_owned_transfers > 0:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                "L'account non può essere eliminato finché esistono "
                "trasferimenti di proprietà dei gruppi ancora in attesa."
            ),
        )


def cancel_incoming_ownership_transfers(
    db: Session,
    user_id: int,
    now: datetime,
) -> None:
    transfers = (
        db.query(GroupOwnershipTransfer)
        .filter(
            GroupOwnershipTransfer.proposed_owner_id == user_id,
            GroupOwnershipTransfer.status == "pending",
        )
        .all()
    )

    for transfer in transfers:
        transfer.status = "cancelled"
        transfer.cancelled_at = now


def delete_user_profile_data(
    db: Session,
    user_id: int,
) -> None:
    db.query(UserAcademicPath).filter(
        UserAcademicPath.user_id == user_id,
    ).delete(
        synchronize_session=False,
    )

    db.query(UserSubject).filter(
        UserSubject.user_id == user_id,
    ).delete(
        synchronize_session=False,
    )

    db.query(TeacherAssignment).filter(
        TeacherAssignment.user_id == user_id,
    ).delete(
        synchronize_session=False,
    )


def delete_user_group_participation(
    db: Session,
    user_id: int,
) -> None:
    db.query(GroupJoinRequest).filter(
        GroupJoinRequest.user_id == user_id,
    ).delete(
        synchronize_session=False,
    )

    db.query(GroupMember).filter(
        GroupMember.user_id == user_id,
    ).delete(
        synchronize_session=False,
    )


def delete_user_notifications(
    db: Session,
    user_id: int,
) -> None:
    db.query(Notification).filter(
        Notification.user_id == user_id,
    ).delete(
        synchronize_session=False,
    )


def anonymize_user_identity(
    user: User,
) -> None:
    random_email_token = secrets.token_urlsafe(32)
    random_password = secrets.token_urlsafe(64)

    user.first_name = "Utente"
    user.last_name = "eliminato"

    user.email = (
        f"deleted-{user.id}-{random_email_token}"
        "@deleted.studentlab.invalid"
    )

    user.password_hash = hash_password(
        random_password,
    )

    user.university = None
    user.department = None
    user.course = None
    user.description = None

    user.role = "student"

    user.teacher_verification_status = "not_required"
    user.teacher_verified_by = None
    user.teacher_verified_at = None

    user.available = False
    user.available_for_help = False
    user.available_for_private_lessons = False
    user.willing_to_teach = False

    user.is_active = False


def anonymize_and_delete_user_personal_data(
    db: Session,
    user: User,
) -> User:
    ensure_user_can_be_anonymized(
        db,
        user,
    )

    now = datetime.now(
        timezone.utc,
    )

    cancel_incoming_ownership_transfers(
        db,
        user.id,
        now,
    )

    delete_user_profile_data(
        db,
        user.id,
    )

    delete_user_group_participation(
        db,
        user.id,
    )

    delete_user_notifications(
        db,
        user.id,
    )

    anonymize_user_identity(
        user,
    )

    db.flush()

    return user