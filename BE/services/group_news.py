from datetime import (
    datetime,
    timezone,
)

from sqlalchemy import (
    and_,
    or_,
)

from sqlalchemy.orm import (
    Session,
    joinedload,
)

from models.group import (
    StudyGroup,
)

from models.group_news import (
    GroupNews,
)

from models.user import (
    User,
)

from schemas.group_news import (
    GroupNewsCreate,
)

from services.group import (
    get_group_member,
)

from services.user_block import (
    can_send_private_content,
    get_blocked_user_ids,
    should_hide_user_content,
)


def utc_now():
    return datetime.now(
        timezone.utc,
    )


def get_group_news_by_id(
    db: Session,
    news_id: int,
):
    if news_id <= 0:
        return None

    return (
        db.query(
            GroupNews,
        )
        .options(
            joinedload(
                GroupNews.author,
            ),
            joinedload(
                GroupNews.recipient,
            ),
            joinedload(
                GroupNews.group,
            ),
        )
        .filter(
            GroupNews.id
            ==
            news_id,
        )
        .first()
    )


def require_group_news_member(
    db: Session,
    group_id: int,
    user_id: int,
):
    member = get_group_member(
        db,
        group_id,
        user_id,
    )

    if member is None:
        raise PermissionError(
            "Non appartieni a questo gruppo.",
        )

    return member


def require_active_group(
    db: Session,
    group_id: int,
):
    if group_id <= 0:
        raise ValueError(
            "Gruppo non valido.",
        )

    group = (
        db.query(
            StudyGroup,
        )
        .filter(
            StudyGroup.id
            ==
            group_id,
            StudyGroup.status
            ==
            "active",
        )
        .first()
    )

    if group is None:
        raise ValueError(
            "Gruppo non trovato.",
        )

    return group


def create_group_news(
    db: Session,
    group_id: int,
    author_user_id: int,
    data: GroupNewsCreate,
):
    require_active_group(
        db,
        group_id,
    )

    require_group_news_member(
        db,
        group_id,
        author_user_id,
    )

    recipient_user_id = (
        data.recipient_user_id
    )

    if (
        data.visibility
        ==
        "private"
    ):
        if recipient_user_id is None:
            raise ValueError(
                "Destinatario non valido.",
            )

        recipient_member = get_group_member(
            db,
            group_id,
            recipient_user_id,
        )

        if recipient_member is None:
            raise ValueError(
                "Il destinatario non appartiene al gruppo.",
            )

        if (
            recipient_user_id
            ==
            author_user_id
        ):
            raise ValueError(
                "Non puoi inviare una news privata a te stesso.",
            )

        if not can_send_private_content(
            db,
            author_user_id,
            recipient_user_id,
        ):
            raise PermissionError(
                "Non è possibile inviare una news privata a questo utente.",
            )

    parent = None

    if (
        data.parent_news_id
        is not None
    ):
        parent = get_group_news_by_id(
            db,
            data.parent_news_id,
        )

        if parent is None:
            raise ValueError(
                "News originale non trovata.",
            )

        if (
            parent.group_id
            !=
            group_id
        ):
            raise ValueError(
                "La news originale appartiene a un altro gruppo.",
            )

        if (
            parent.status
            !=
            "active"
        ):
            raise ValueError(
                "Non è possibile rispondere a questa news.",
            )

        if (
            parent.expires_at
            <=
            utc_now()
        ):
            raise ValueError(
                "La news originale è scaduta.",
            )

        if (
            parent.visibility
            ==
            "private"
        ):
            allowed_users = {
                parent.author_user_id,
                parent.recipient_user_id,
            }

            if (
                author_user_id
                not in
                allowed_users
            ):
                raise PermissionError(
                    "Non puoi rispondere a questa news privata.",
                )

            expected_recipient_user_id = (
                parent.recipient_user_id
                if author_user_id
                ==
                parent.author_user_id
                else parent.author_user_id
            )

            if (
                data.visibility
                !=
                "private"
                or recipient_user_id
                !=
                expected_recipient_user_id
            ):
                raise ValueError(
                    "La risposta a una news privata deve restare privata tra gli stessi utenti.",
                )

            if not can_send_private_content(
                db,
                author_user_id,
                expected_recipient_user_id,
            ):
                raise PermissionError(
                    "Non è possibile rispondere a questa news privata.",
                )

        elif (
            data.visibility
            ==
            "private"
        ):
            if recipient_user_id is None:
                raise ValueError(
                    "Destinatario non valido.",
                )

            recipient_member = get_group_member(
                db,
                group_id,
                recipient_user_id,
            )

            if recipient_member is None:
                raise ValueError(
                    "Il destinatario non appartiene al gruppo.",
                )

    news = GroupNews(
        group_id=group_id,
        author_user_id=author_user_id,
        recipient_user_id=(
            recipient_user_id
        ),
        parent_news_id=(
            data.parent_news_id
        ),
        visibility=(
            data.visibility
        ),
        content=(
            data.content
        ),
        status="active",
    )

    try:
        db.add(
            news,
        )

        db.commit()

        db.refresh(
            news,
        )

        return get_group_news_by_id(
            db,
            news.id,
        )

    except Exception:
        db.rollback()
        raise


def can_view_group_news(
    db: Session,
    news: GroupNews,
    viewer_user_id: int,
) -> bool:
    if (
        viewer_user_id <= 0
    ):
        return False

    if (
        news.status
        !=
        "active"
    ):
        return False

    if (
        news.expires_at
        <=
        utc_now()
    ):
        return False

    if (
        get_group_member(
            db,
            news.group_id,
            viewer_user_id,
        )
        is None
    ):
        return False

    if (
        viewer_user_id
        !=
        news.author_user_id
        and should_hide_user_content(
            db,
            viewer_user_id,
            news.author_user_id,
        )
    ):
        return False

    if (
        news.visibility
        ==
        "group"
    ):
        return True

    return (
        viewer_user_id
        ==
        news.author_user_id
        or viewer_user_id
        ==
        news.recipient_user_id
    )


def get_group_news_feed(
    db: Session,
    group_id: int,
    viewer_user_id: int,
    limit: int = 50,
    offset: int = 0,
):
    require_active_group(
        db,
        group_id,
    )

    require_group_news_member(
        db,
        group_id,
        viewer_user_id,
    )

    safe_limit = max(
        1,
        min(
            limit,
            100,
        ),
    )

    safe_offset = max(
        0,
        offset,
    )

    blocked_user_ids = set(
        get_blocked_user_ids(
            db,
            viewer_user_id,
        )
    )

    now = utc_now()

    visibility_filter = or_(
        GroupNews.visibility
        ==
        "group",
        and_(
            GroupNews.visibility
            ==
            "private",
            or_(
                GroupNews.author_user_id
                ==
                viewer_user_id,
                GroupNews.recipient_user_id
                ==
                viewer_user_id,
            ),
        ),
    )

    query = (
        db.query(
            GroupNews,
        )
        .options(
            joinedload(
                GroupNews.author,
            ),
            joinedload(
                GroupNews.recipient,
            ),
            joinedload(
                GroupNews.group,
            ),
        )
        .filter(
            GroupNews.group_id
            ==
            group_id,
            GroupNews.status
            ==
            "active",
            GroupNews.expires_at
            >
            now,
            visibility_filter,
        )
    )

    if blocked_user_ids:
        query = query.filter(
            or_(
                GroupNews.author_user_id
                ==
                viewer_user_id,
                GroupNews.author_user_id.notin_(
                    blocked_user_ids,
                ),
            )
        )

    total = query.count()

    items = (
        query
        .order_by(
            GroupNews.created_at.desc(),
        )
        .offset(
            safe_offset,
        )
        .limit(
            safe_limit,
        )
        .all()
    )

    return (
        items,
        total,
        safe_limit,
        safe_offset,
    )


def get_private_group_news_inbox(
    db: Session,
    viewer_user_id: int,
    limit: int = 50,
    offset: int = 0,
):
    if viewer_user_id <= 0:
        raise ValueError(
            "Utente non valido.",
        )

    safe_limit = max(
        1,
        min(
            limit,
            100,
        ),
    )

    safe_offset = max(
        0,
        offset,
    )

    blocked_user_ids = set(
        get_blocked_user_ids(
            db,
            viewer_user_id,
        )
    )

    now = utc_now()

    query = (
        db.query(
            GroupNews,
        )
        .join(
            StudyGroup,
            StudyGroup.id
            ==
            GroupNews.group_id,
        )
        .options(
            joinedload(
                GroupNews.author,
            ),
            joinedload(
                GroupNews.recipient,
            ),
            joinedload(
                GroupNews.group,
            ),
        )
        .filter(
            GroupNews.visibility
            ==
            "private",
            GroupNews.status
            ==
            "active",
            GroupNews.expires_at
            >
            now,
            StudyGroup.status
            ==
            "active",
            or_(
                GroupNews.author_user_id
                ==
                viewer_user_id,
                GroupNews.recipient_user_id
                ==
                viewer_user_id,
            ),
        )
    )

    if blocked_user_ids:
        query = query.filter(
            or_(
                GroupNews.author_user_id
                ==
                viewer_user_id,
                GroupNews.author_user_id.notin_(
                    blocked_user_ids,
                ),
            )
        )

    total = query.count()

    items = (
        query
        .order_by(
            GroupNews.created_at.desc(),
        )
        .offset(
            safe_offset,
        )
        .limit(
            safe_limit,
        )
        .all()
    )

    return (
        items,
        total,
        safe_limit,
        safe_offset,
    )


def can_delete_group_news(
    db: Session,
    news: GroupNews,
    user_id: int,
) -> bool:
    if (
        user_id <= 0
    ):
        return False

    if (
        news.status
        !=
        "active"
    ):
        return False

    if (
        news.author_user_id
        ==
        user_id
    ):
        return True

    if (
        news.visibility
        ==
        "private"
    ):
        return False

    member = get_group_member(
        db,
        news.group_id,
        user_id,
    )

    if member is None:
        return False

    return (
        member.role
        in {
            "owner",
            "admin",
        }
    )


def can_moderate_group_news(
    db: Session,
    news: GroupNews,
    user_id: int,
) -> bool:
    if (
        user_id <= 0
    ):
        return False

    if (
        news.status
        !=
        "active"
    ):
        return False

    member = get_group_member(
        db,
        news.group_id,
        user_id,
    )

    if member is None:
        return False

    if (
        member.role
        not in {
            "owner",
            "admin",
        }
    ):
        return False

    if (
        news.visibility
        ==
        "private"
        and user_id
        not in {
            news.author_user_id,
            news.recipient_user_id,
        }
    ):
        return False

    return True


def apply_group_news_deletion(
    db: Session,
    news: GroupNews,
    user_id: int,
):
    if (
        news.status
        !=
        "active"
    ):
        raise ValueError(
            "La news non è più disponibile.",
        )

    if (
        news.author_user_id
        ==
        user_id
    ):
        status = (
            "deleted_by_author"
        )

    else:
        if (
            news.visibility
            ==
            "private"
        ):
            raise PermissionError(
                "Non puoi eliminare una news privata di un altro utente.",
            )

        member = get_group_member(
            db,
            news.group_id,
            user_id,
        )

        if member is None:
            raise PermissionError(
                "Non puoi eliminare questa news.",
            )

        if (
            member.role
            ==
            "owner"
        ):
            status = (
                "removed_by_group_owner"
            )

        elif (
            member.role
            ==
            "admin"
        ):
            status = (
                "removed_by_group_admin"
            )

        else:
            raise PermissionError(
                "Non puoi eliminare questa news.",
            )

    news.status = status
    news.deleted_by_user_id = user_id
    news.deleted_at = utc_now()

    return news


def delete_group_news(
    db: Session,
    news: GroupNews,
    user_id: int,
):
    try:
        apply_group_news_deletion(
            db,
            news,
            user_id,
        )

        db.commit()

        db.refresh(
            news,
        )

        return news

    except Exception:
        db.rollback()
        raise


def apply_group_news_moderation(
    db: Session,
    news: GroupNews,
    moderator_user_id: int,
    reason: str,
):
    if (
        news.status
        !=
        "active"
    ):
        raise ValueError(
            "La news non è più disponibile.",
        )

    normalized_reason = (
        reason.strip()
    )

    if not normalized_reason:
        raise ValueError(
            "Il motivo della moderazione non può essere vuoto.",
        )

    member = get_group_member(
        db,
        news.group_id,
        moderator_user_id,
    )

    if member is None:
        raise PermissionError(
            "Non puoi moderare questa news.",
        )

    if (
        news.visibility
        ==
        "private"
        and moderator_user_id
        not in {
            news.author_user_id,
            news.recipient_user_id,
        }
    ):
        raise PermissionError(
            "Non puoi moderare una news privata di altri utenti.",
        )

    if (
        member.role
        ==
        "owner"
    ):
        status = (
            "removed_by_group_owner"
        )

    elif (
        member.role
        ==
        "admin"
    ):
        status = (
            "removed_by_group_admin"
        )

    else:
        raise PermissionError(
            "Non puoi moderare questa news.",
        )

    now = utc_now()

    news.status = status
    news.deleted_by_user_id = (
        moderator_user_id
    )
    news.deleted_at = now
    news.moderated_by_user_id = (
        moderator_user_id
    )
    news.moderated_at = now
    news.moderation_reason = (
        normalized_reason
    )

    return news


def moderate_group_news(
    db: Session,
    news: GroupNews,
    moderator_user_id: int,
    reason: str,
):
    try:
        apply_group_news_moderation(
            db,
            news,
            moderator_user_id,
            reason,
        )

        db.commit()

        db.refresh(
            news,
        )

        return news

    except Exception:
        db.rollback()
        raise


def apply_platform_group_news_moderation(
    db: Session,
    news: GroupNews,
    moderator_user_id: int,
    reason: str,
):
    if (
        news.status
        !=
        "active"
    ):
        raise ValueError(
            "La news non è più disponibile.",
        )

    normalized_reason = (
        reason.strip()
    )

    if not normalized_reason:
        raise ValueError(
            "Il motivo della moderazione non può essere vuoto.",
        )

    moderator = (
        db.query(
            User,
        )
        .filter(
            User.id
            ==
            moderator_user_id,
            User.role.in_(
                [
                    "admin",
                    "creator",
                ]
            ),
            User.is_active.is_(
                True,
            ),
        )
        .first()
    )

    if moderator is None:
        raise PermissionError(
            "Permessi di moderazione insufficienti.",
        )

    now = utc_now()

    news.status = (
        "removed_by_platform_moderator"
    )

    news.deleted_by_user_id = (
        moderator_user_id
    )

    news.deleted_at = now

    news.moderated_by_user_id = (
        moderator_user_id
    )

    news.moderated_at = now

    news.moderation_reason = (
        normalized_reason
    )

    return news


def platform_moderate_group_news(
    db: Session,
    news: GroupNews,
    moderator_user_id: int,
    reason: str,
):
    try:
        apply_platform_group_news_moderation(
            db,
            news,
            moderator_user_id,
            reason,
        )

        db.commit()

        db.refresh(
            news,
        )

        return news

    except Exception:
        db.rollback()
        raise


def expire_group_news(
    db: Session,
):
    now = utc_now()

    rows = (
        db.query(
            GroupNews,
        )
        .filter(
            GroupNews.status
            ==
            "active",
            GroupNews.expires_at
            <=
            now,
        )
        .all()
    )

    if not rows:
        return 0

    try:
        for news in rows:
            news.status = (
                "expired"
            )

            news.deleted_at = (
                now
            )

        db.commit()

        return len(
            rows,
        )

    except Exception:
        db.rollback()
        raise


def get_expired_group_news(
    db: Session,
):
    return (
        db.query(
            GroupNews,
        )
        .options(
            joinedload(
                GroupNews.author,
            ),
            joinedload(
                GroupNews.recipient,
            ),
        )
        .filter(
            GroupNews.status
            ==
            "expired",
        )
        .order_by(
            GroupNews.created_at.asc(),
        )
        .all()
    )


def hard_delete_expired_group_news(
    db: Session,
    news_ids: list[int],
):
    normalized_ids = list(
        {
            news_id
            for news_id in news_ids
            if news_id > 0
        }
    )

    if not normalized_ids:
        return 0

    rows = (
        db.query(
            GroupNews,
        )
        .filter(
            GroupNews.id.in_(
                normalized_ids,
            ),
            GroupNews.status
            ==
            "expired",
        )
        .all()
    )

    if not rows:
        return 0

    try:
        for news in rows:
            db.delete(
                news,
            )

        db.commit()

        return len(
            rows,
        )

    except Exception:
        db.rollback()
        raise