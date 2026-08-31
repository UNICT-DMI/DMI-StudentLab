from datetime import (
    datetime,
    timezone,
)

from sqlalchemy.orm import (
    Session,
)

from models.user import (
    User,
)

from models.user_public_key import (
    UserPublicKey,
)

from schemas.user_public_key import (
    UserPublicKeyRegister,
)

from services.user_block import (
    can_send_private_content,
)


MAX_ACTIVE_DEVICES = 10


def _now():
    return datetime.now(
        timezone.utc,
    )


def register_public_key(
    db: Session,
    user: User,
    request: UserPublicKeyRegister,
) -> UserPublicKey:
    existing = (
        db.query(
            UserPublicKey,
        )
        .filter(
            UserPublicKey.user_id
            ==
            user.id,
            UserPublicKey.device_id
            ==
            request.device_id,
        )
        .first()
    )

    if existing is not None:
        existing.algo = request.algo
        existing.public_key = request.public_key
        existing.device_label = request.device_label
        existing.rotated_at = _now()
        existing.revoked_at = None

        db.commit()
        db.refresh(
            existing,
        )

        return existing

    active_devices = (
        db.query(
            UserPublicKey,
        )
        .filter(
            UserPublicKey.user_id
            ==
            user.id,
            UserPublicKey.revoked_at.is_(
                None,
            ),
        )
        .count()
    )

    if active_devices >= MAX_ACTIVE_DEVICES:
        raise ValueError(
            "Hai raggiunto il numero massimo di dispositivi "
            "registrati. Revoca un dispositivo prima di "
            "aggiungerne un altro.",
        )

    created = UserPublicKey(
        user_id=user.id,
        device_id=request.device_id,
        device_label=request.device_label,
        algo=request.algo,
        public_key=request.public_key,
        created_at=_now(),
    )

    db.add(
        created,
    )

    db.commit()
    db.refresh(
        created,
    )

    return created


def list_own_public_keys(
    db: Session,
    user_id: int,
) -> list[UserPublicKey]:
    return (
        db.query(
            UserPublicKey,
        )
        .filter(
            UserPublicKey.user_id
            ==
            user_id,
        )
        .order_by(
            UserPublicKey.created_at.desc(),
        )
        .all()
    )


def list_active_public_keys(
    db: Session,
    user_id: int,
) -> list[UserPublicKey]:
    return (
        db.query(
            UserPublicKey,
        )
        .filter(
            UserPublicKey.user_id
            ==
            user_id,
            UserPublicKey.revoked_at.is_(
                None,
            ),
        )
        .order_by(
            UserPublicKey.created_at.desc(),
        )
        .all()
    )


def revoke_public_key(
    db: Session,
    user_id: int,
    device_id: str,
) -> UserPublicKey:
    key = (
        db.query(
            UserPublicKey,
        )
        .filter(
            UserPublicKey.user_id
            ==
            user_id,
            UserPublicKey.device_id
            ==
            device_id,
        )
        .first()
    )

    if key is None:
        raise ValueError(
            "Dispositivo non trovato.",
        )

    if key.revoked_at is None:
        key.revoked_at = _now()

        db.commit()
        db.refresh(
            key,
        )

    return key


def get_recipient_public_keys(
    db: Session,
    viewer: User,
    recipient_id: int,
) -> list[UserPublicKey]:
    if recipient_id <= 0:
        raise ValueError(
            "Utente non valido.",
        )

    if recipient_id == viewer.id:
        return list_active_public_keys(
            db,
            viewer.id,
        )

    recipient = (
        db.query(
            User,
        )
        .filter(
            User.id
            ==
            recipient_id,
            User.is_active.is_(
                True,
            ),
        )
        .first()
    )

    if recipient is None:
        raise ValueError(
            "Utente non trovato.",
        )

    if not can_send_private_content(
        db,
        viewer.id,
        recipient_id,
    ):
        raise PermissionError(
            "Non puoi comunicare con questo utente.",
        )

    return list_active_public_keys(
        db,
        recipient_id,
    )
