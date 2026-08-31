from sqlalchemy import (
    and_,
    or_,
)

from sqlalchemy.orm import (
    Session,
    joinedload,
)

from models.user import (
    User,
)

from models.user_block import (
    UserBlock,
)


def get_user_block(
    db: Session,
    blocker_user_id: int,
    blocked_user_id: int,
) -> UserBlock | None:
    if (
        blocker_user_id <= 0
        or blocked_user_id <= 0
    ):
        return None

    return (
        db.query(
            UserBlock,
        )
        .filter(
            UserBlock.blocker_user_id
            ==
            blocker_user_id,
            UserBlock.blocked_user_id
            ==
            blocked_user_id,
        )
        .first()
    )


def is_user_blocked(
    db: Session,
    blocker_user_id: int,
    blocked_user_id: int,
) -> bool:
    return (
        get_user_block(
            db,
            blocker_user_id,
            blocked_user_id,
        )
        is not None
    )


def is_block_relationship_present(
    db: Session,
    user_a_id: int,
    user_b_id: int,
) -> bool:
    if (
        user_a_id <= 0
        or user_b_id <= 0
        or user_a_id == user_b_id
    ):
        return False

    return (
        db.query(
            UserBlock.id,
        )
        .filter(
            or_(
                and_(
                    UserBlock.blocker_user_id
                    ==
                    user_a_id,
                    UserBlock.blocked_user_id
                    ==
                    user_b_id,
                ),
                and_(
                    UserBlock.blocker_user_id
                    ==
                    user_b_id,
                    UserBlock.blocked_user_id
                    ==
                    user_a_id,
                ),
            )
        )
        .first()
        is not None
    )


def get_blocked_user_ids(
    db: Session,
    blocker_user_id: int,
) -> list[int]:
    if blocker_user_id <= 0:
        return []

    rows = (
        db.query(
            UserBlock.blocked_user_id,
        )
        .filter(
            UserBlock.blocker_user_id
            ==
            blocker_user_id,
        )
        .all()
    )

    return [
        blocked_user_id
        for (
            blocked_user_id,
        ) in rows
    ]


def get_users_who_blocked_user_ids(
    db: Session,
    blocked_user_id: int,
) -> list[int]:
    if blocked_user_id <= 0:
        return []

    rows = (
        db.query(
            UserBlock.blocker_user_id,
        )
        .filter(
            UserBlock.blocked_user_id
            ==
            blocked_user_id,
        )
        .all()
    )

    return [
        blocker_user_id
        for (
            blocker_user_id,
        ) in rows
    ]


def get_blocked_users(
    db: Session,
    blocker_user_id: int,
) -> list[UserBlock]:
    if blocker_user_id <= 0:
        return []

    return (
        db.query(
            UserBlock,
        )
        .options(
            joinedload(
                UserBlock.blocked,
            )
        )
        .filter(
            UserBlock.blocker_user_id
            ==
            blocker_user_id,
        )
        .order_by(
            UserBlock.created_at.desc(),
        )
        .all()
    )


def create_user_block(
    db: Session,
    blocker_user_id: int,
    blocked_user_id: int,
) -> UserBlock:
    if blocker_user_id <= 0:
        raise ValueError(
            "Utente non valido.",
        )

    if blocked_user_id <= 0:
        raise ValueError(
            "Utente da bloccare non valido.",
        )

    if (
        blocker_user_id
        ==
        blocked_user_id
    ):
        raise ValueError(
            "Non puoi bloccare il tuo stesso account.",
        )

    blocker_user = (
        db.query(
            User,
        )
        .filter(
            User.id
            ==
            blocker_user_id,
            User.is_active.is_(
                True,
            ),
        )
        .first()
    )

    if blocker_user is None:
        raise ValueError(
            "Utente non valido.",
        )

    blocked_user = (
        db.query(
            User,
        )
        .filter(
            User.id
            ==
            blocked_user_id,
            User.is_active.is_(
                True,
            ),
        )
        .first()
    )

    if blocked_user is None:
        raise ValueError(
            "Utente non trovato.",
        )

    existing = get_user_block(
        db,
        blocker_user_id,
        blocked_user_id,
    )

    if existing is not None:
        raise ValueError(
            "Utente già bloccato.",
        )

    block = UserBlock(
        blocker_user_id=(
            blocker_user_id
        ),
        blocked_user_id=(
            blocked_user_id
        ),
    )

    try:
        db.add(
            block,
        )

        db.commit()

        db.refresh(
            block,
        )

        return (
            db.query(
                UserBlock,
            )
            .options(
                joinedload(
                    UserBlock.blocked,
                )
            )
            .filter(
                UserBlock.id
                ==
                block.id,
            )
            .first()
        )

    except Exception:
        db.rollback()
        raise


def delete_user_block(
    db: Session,
    blocker_user_id: int,
    blocked_user_id: int,
) -> None:
    if (
        blocker_user_id <= 0
        or blocked_user_id <= 0
    ):
        raise ValueError(
            "Blocco utente non trovato.",
        )

    block = get_user_block(
        db,
        blocker_user_id,
        blocked_user_id,
    )

    if block is None:
        raise ValueError(
            "Blocco utente non trovato.",
        )

    try:
        db.delete(
            block,
        )

        db.commit()

    except Exception:
        db.rollback()
        raise


def can_send_private_content(
    db: Session,
    sender_user_id: int,
    recipient_user_id: int,
) -> bool:
    if (
        sender_user_id <= 0
        or recipient_user_id <= 0
    ):
        return False

    if (
        sender_user_id
        ==
        recipient_user_id
    ):
        return False

    return not (
        is_block_relationship_present(
            db,
            sender_user_id,
            recipient_user_id,
        )
    )


def can_deliver_private_notification(
    db: Session,
    actor_user_id: int,
    recipient_user_id: int,
) -> bool:
    return can_send_private_content(
        db,
        actor_user_id,
        recipient_user_id,
    )


def should_hide_user_content(
    db: Session,
    viewer_user_id: int,
    author_user_id: int,
) -> bool:
    if (
        viewer_user_id <= 0
        or author_user_id <= 0
    ):
        return False

    if (
        viewer_user_id
        ==
        author_user_id
    ):
        return False

    return is_user_blocked(
        db,
        viewer_user_id,
        author_user_id,
    )


def get_mutually_restricted_user_ids(
    db: Session,
    user_id: int,
) -> set[int]:
    if user_id <= 0:
        return set()

    blocked = set(
        get_blocked_user_ids(
            db,
            user_id,
        )
    )

    blocked_by = set(
        get_users_who_blocked_user_ids(
            db,
            user_id,
        )
    )

    return (
        blocked
        |
        blocked_by
    )