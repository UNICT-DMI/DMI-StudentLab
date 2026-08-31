from fastapi import (
    APIRouter,
    Depends,
    Response,
    status,
)

from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_current_user

from models.user import User

from schemas.notification import (
    NotificationDetailResponse,
    NotificationListResponse,
    NotificationMarkAllReadResponse,
    NotificationMarkReadResponse,
    NotificationResponse,
    NotificationUnreadCountResponse,
)

from services.notification import (
    delete_all_my_notifications,
    delete_notification,
    get_my_notifications,
    get_notification_by_id,
    get_unread_notification_count,
    mark_all_notifications_as_read,
    mark_notification_as_read,
    mark_notification_as_unread,
    process_expired_notifications,
)


router = APIRouter(
    tags=[
        "Notifications",
    ],
)


@router.get(
    "/notifications",
    response_model=NotificationListResponse,
)
def api_get_my_notifications(
    unread_only: bool = False,
    limit: int = 50,
    offset: int = 0,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    process_expired_notifications(
        db,
    )

    notifications = get_my_notifications(
        db,
        current_user=current_user,
        unread_only=unread_only,
        limit=limit,
        offset=offset,
    )

    unread_count = get_unread_notification_count(
        db,
        current_user=current_user,
    )

    return NotificationListResponse(
        notifications=[
            NotificationResponse.model_validate(
                notification
            )
            for notification in notifications
        ],
        unread_count=unread_count,
    )


@router.get(
    "/notifications/unread-count",
    response_model=NotificationUnreadCountResponse,
)
def api_get_unread_notification_count(
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    process_expired_notifications(
        db,
    )

    unread_count = get_unread_notification_count(
        db,
        current_user=current_user,
    )

    return NotificationUnreadCountResponse(
        unread_count=unread_count,
    )


@router.get(
    "/notifications/{notification_id}",
    response_model=NotificationDetailResponse,
)
def api_get_notification(
    notification_id: int,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    process_expired_notifications(
        db,
    )

    return get_notification_by_id(
        db,
        notification_id=notification_id,
        current_user=current_user,
    )


@router.post(
    "/notifications/{notification_id}/read",
    response_model=NotificationMarkReadResponse,
)
def api_mark_notification_as_read(
    notification_id: int,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    notification = mark_notification_as_read(
        db,
        notification_id=notification_id,
        current_user=current_user,
    )

    return NotificationMarkReadResponse(
        id=notification.id,
        is_read=notification.is_read,
        read_at=notification.read_at,
    )


@router.post(
    "/notifications/{notification_id}/unread",
    response_model=NotificationMarkReadResponse,
)
def api_mark_notification_as_unread(
    notification_id: int,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    notification = mark_notification_as_unread(
        db,
        notification_id=notification_id,
        current_user=current_user,
    )

    return NotificationMarkReadResponse(
        id=notification.id,
        is_read=notification.is_read,
        read_at=notification.read_at,
    )


@router.post(
    "/notifications/read-all",
    response_model=NotificationMarkAllReadResponse,
)
def api_mark_all_notifications_as_read(
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    process_expired_notifications(
        db,
    )

    updated_count = mark_all_notifications_as_read(
        db,
        current_user=current_user,
    )

    unread_count = get_unread_notification_count(
        db,
        current_user=current_user,
    )

    return NotificationMarkAllReadResponse(
        updated_count=updated_count,
        unread_count=unread_count,
    )


@router.delete(
    "/notifications/{notification_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def api_delete_notification(
    notification_id: int,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    delete_notification(
        db,
        notification_id=notification_id,
        current_user=current_user,
    )

    return Response(
        status_code=status.HTTP_204_NO_CONTENT,
    )


@router.delete(
    "/notifications",
    status_code=status.HTTP_204_NO_CONTENT,
)
def api_delete_all_notifications(
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    delete_all_my_notifications(
        db,
        current_user=current_user,
    )

    return Response(
        status_code=status.HTTP_204_NO_CONTENT,
    )