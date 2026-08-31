from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from models.notification import Notification
from models.user import User


VALID_ACTION_STATUSES = {
    "none",
    "pending",
    "accepted",
    "rejected",
    "expired",
    "completed",
    "cancelled",
}


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _validate_action_status(
    action_status: str,
) -> None:
    if action_status not in VALID_ACTION_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Stato azione della notifica non valido.",
        )


def create_notification(
    db: Session,
    user_id: int,
    notification_type: str,
    title: str,
    message: str = "",
    actor_user_id: int | None = None,
    resource_type: str | None = None,
    resource_id: int | None = None,
    action_type: str | None = None,
    action_resource_id: int | None = None,
    action_status: str = "none",
    expires_at: datetime | None = None,
    commit: bool = True,
) -> Notification:
    _validate_action_status(
        action_status,
    )

    user = (
        db.query(User)
        .filter(
            User.id == user_id,
            User.is_active.is_(True),
        )
        .first()
    )

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Utente destinatario della notifica non trovato.",
        )

    notification = Notification(
        user_id=user_id,
        actor_user_id=actor_user_id,
        type=notification_type,
        title=title,
        message=message,
        resource_type=resource_type,
        resource_id=resource_id,
        action_type=action_type,
        action_resource_id=action_resource_id,
        action_status=action_status,
        is_read=False,
        read_at=None,
        expires_at=expires_at,
    )

    db.add(notification)

    if commit:
        db.commit()
        db.refresh(notification)
    else:
        db.flush()

    return notification


def get_my_notifications(
    db: Session,
    current_user: User,
    unread_only: bool = False,
    limit: int = 50,
    offset: int = 0,
) -> list[Notification]:
    limit = max(
        1,
        min(limit, 100),
    )
    offset = max(
        0,
        offset,
    )

    query = (
        db.query(Notification)
        .filter(
            Notification.user_id == current_user.id,
        )
    )

    if unread_only:
        query = query.filter(
            Notification.is_read.is_(False),
        )

    return (
        query
        .order_by(
            Notification.created_at.desc(),
        )
        .offset(offset)
        .limit(limit)
        .all()
    )


def get_notification_by_id(
    db: Session,
    notification_id: int,
    current_user: User,
) -> Notification:
    notification = (
        db.query(Notification)
        .filter(
            Notification.id == notification_id,
            Notification.user_id == current_user.id,
        )
        .first()
    )

    if notification is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notifica non trovata.",
        )

    return notification


def get_unread_notification_count(
    db: Session,
    current_user: User,
) -> int:
    return (
        db.query(Notification)
        .filter(
            Notification.user_id == current_user.id,
            Notification.is_read.is_(False),
        )
        .count()
    )


def mark_notification_as_read(
    db: Session,
    notification_id: int,
    current_user: User,
) -> Notification:
    notification = get_notification_by_id(
        db,
        notification_id,
        current_user,
    )

    if notification.is_read:
        return notification

    now = _now()

    notification.is_read = True
    notification.read_at = now
    notification.updated_at = now

    db.commit()
    db.refresh(notification)

    return notification


def mark_notification_as_unread(
    db: Session,
    notification_id: int,
    current_user: User,
) -> Notification:
    notification = get_notification_by_id(
        db,
        notification_id,
        current_user,
    )

    if not notification.is_read:
        return notification

    notification.is_read = False
    notification.read_at = None
    notification.updated_at = _now()

    db.commit()
    db.refresh(notification)

    return notification


def mark_all_notifications_as_read(
    db: Session,
    current_user: User,
) -> int:
    notifications = (
        db.query(Notification)
        .filter(
            Notification.user_id == current_user.id,
            Notification.is_read.is_(False),
        )
        .all()
    )

    if not notifications:
        return 0

    now = _now()

    for notification in notifications:
        notification.is_read = True
        notification.read_at = now
        notification.updated_at = now

    db.commit()

    return len(notifications)


def update_notification_action_status(
    db: Session,
    notification_id: int,
    action_status: str,
    mark_as_read: bool = True,
    commit: bool = True,
) -> Notification:
    _validate_action_status(
        action_status,
    )

    notification = (
        db.query(Notification)
        .filter(
            Notification.id == notification_id,
        )
        .first()
    )

    if notification is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Notifica non trovata.",
        )

    now = _now()

    notification.action_status = action_status
    notification.updated_at = now

    if mark_as_read:
        notification.is_read = True
        notification.read_at = now

    if commit:
        db.commit()
        db.refresh(notification)
    else:
        db.flush()

    return notification


def update_notification_action_status_by_resource(
    db: Session,
    action_type: str,
    action_resource_id: int,
    action_status: str,
    mark_as_read: bool = True,
    commit: bool = True,
) -> Notification | None:
    _validate_action_status(
        action_status,
    )

    notification = (
        db.query(Notification)
        .filter(
            Notification.action_type == action_type,
            Notification.action_resource_id == action_resource_id,
        )
        .order_by(
            Notification.created_at.desc(),
        )
        .first()
    )

    if notification is None:
        return None

    now = _now()

    notification.action_status = action_status
    notification.updated_at = now

    if mark_as_read:
        notification.is_read = True
        notification.read_at = now

    if commit:
        db.commit()
        db.refresh(notification)
    else:
        db.flush()

    return notification


def update_notifications_action_status_by_resource(
    db: Session,
    action_type: str,
    action_resource_id: int,
    action_status: str,
    *,
    current_statuses: set[str] | None = None,
    mark_as_read: bool = False,
    commit: bool = True,
) -> int:
    _validate_action_status(
        action_status,
    )

    query = (
        db.query(Notification)
        .filter(
            Notification.action_type == action_type,
            Notification.action_resource_id == action_resource_id,
        )
    )

    if current_statuses:
        query = query.filter(
            Notification.action_status.in_(
                current_statuses
            )
        )

    notifications = query.all()

    if not notifications:
        return 0

    now = _now()

    for notification in notifications:
        notification.action_status = action_status
        notification.updated_at = now

        if mark_as_read:
            notification.is_read = True
            notification.read_at = now

    if commit:
        db.commit()
    else:
        db.flush()

    return len(notifications)


def update_user_notification_action_status_by_resource(
    db: Session,
    user_id: int,
    action_type: str,
    action_resource_id: int,
    action_status: str,
    *,
    current_statuses: set[str] | None = None,
    mark_as_read: bool = True,
    commit: bool = True,
) -> Notification | None:
    _validate_action_status(
        action_status,
    )

    query = (
        db.query(Notification)
        .filter(
            Notification.user_id == user_id,
            Notification.action_type == action_type,
            Notification.action_resource_id == action_resource_id,
        )
    )

    if current_statuses:
        query = query.filter(
            Notification.action_status.in_(
                current_statuses
            )
        )

    notification = (
        query
        .order_by(
            Notification.created_at.desc(),
        )
        .first()
    )

    if notification is None:
        return None

    now = _now()

    notification.action_status = action_status
    notification.updated_at = now

    if mark_as_read:
        notification.is_read = True
        notification.read_at = now

    if commit:
        db.commit()
        db.refresh(notification)
    else:
        db.flush()

    return notification


def update_notifications_expiration_by_resource(
    db: Session,
    action_type: str,
    action_resource_id: int,
    expires_at: datetime | None,
    *,
    only_pending: bool = True,
    commit: bool = True,
) -> int:
    query = (
        db.query(Notification)
        .filter(
            Notification.action_type == action_type,
            Notification.action_resource_id == action_resource_id,
        )
    )

    if only_pending:
        query = query.filter(
            Notification.action_status == "pending",
        )

    notifications = query.all()

    if not notifications:
        return 0

    now = _now()

    for notification in notifications:
        notification.expires_at = expires_at
        notification.updated_at = now

    if commit:
        db.commit()
    else:
        db.flush()

    return len(notifications)


def expire_notification_if_needed(
    db: Session,
    notification: Notification,
    commit: bool = True,
) -> bool:
    if notification.expires_at is None:
        return False

    if notification.action_status != "pending":
        return False

    now = _now()

    if notification.expires_at > now:
        return False

    notification.action_status = "expired"
    notification.updated_at = now

    if commit:
        db.commit()
        db.refresh(notification)
    else:
        db.flush()

    return True


def process_expired_notifications(
    db: Session,
) -> int:
    now = _now()

    notifications = (
        db.query(Notification)
        .filter(
            Notification.action_status == "pending",
            Notification.expires_at.isnot(None),
            Notification.expires_at <= now,
        )
        .all()
    )

    if not notifications:
        return 0

    for notification in notifications:
        notification.action_status = "expired"
        notification.updated_at = now

    db.commit()

    return len(notifications)


def delete_notification(
    db: Session,
    notification_id: int,
    current_user: User,
) -> None:
    notification = get_notification_by_id(
        db,
        notification_id,
        current_user,
    )

    db.delete(notification)
    db.commit()


def delete_all_my_notifications(
    db: Session,
    current_user: User,
) -> int:
    notifications = (
        db.query(Notification)
        .filter(
            Notification.user_id == current_user.id,
        )
        .all()
    )

    count = len(notifications)

    for notification in notifications:
        db.delete(notification)

    db.commit()

    return count