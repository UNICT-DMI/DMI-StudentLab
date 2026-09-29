from datetime import datetime, timedelta, timezone
from pathlib import Path
from uuid import uuid4

from sqlalchemy.orm import Session

from models.material_share import MaterialShare
from models.user import User
from schemas.material_share import (
    MaterialShareCompleteRequest,
    MaterialShareUploadRequest,
    MaterialShareVerifyRequest,
)
from services.notification import create_notification
from services.private_blob import delete_private_blob_sync
from services.upload_authorization import (
    create_upload_authorization,
    decode_upload_authorization,
    require_upload_authorization_fields,
    require_upload_authorization_type,
    require_upload_authorization_user,
)


SHARE_CLOUD_DAYS = 8
MAX_SHARE_SIZE = 250 * 1024 * 1024


def utc_now():
    return datetime.now(timezone.utc)


def _hash(value: str):
    normalized = value.strip().lower()
    if len(normalized) != 64 or not all(c in "0123456789abcdef" for c in normalized):
        raise ValueError("Hash del file non valido.")
    return normalized


def prepare_share_upload(
    db: Session,
    user: User,
    data: MaterialShareUploadRequest,
):
    if data.recipient_user_id == user.id:
        raise ValueError("Non puoi condividere un materiale con te stesso.")

    recipient = (
        db.query(User)
        .filter(
            User.id == data.recipient_user_id,
            User.is_active.is_(True),
        )
        .first()
    )
    if recipient is None:
        raise ValueError("Destinatario non trovato.")

    if data.size > MAX_SHARE_SIZE:
        raise ValueError("Il file supera la dimensione massima consentita.")

    extension = Path(data.original_name).suffix.lower()
    pathname = f"material-shares/{user.id}/{uuid4().hex}{extension}"
    payload = {
        "v": 1,
        "type": "material_share",
        "uid": user.id,
        "recipient_user_id": data.recipient_user_id,
        "pathname": pathname,
        "size": data.size,
        "mime_type": data.mime_type.strip().lower(),
        "file_hash": _hash(data.file_hash),
    }
    token, expires = create_upload_authorization(payload)

    return {
        "allowed": True,
        "pathname": pathname,
        "upload_token": token,
        "valid_until": expires * 1000,
        "cloud_days": SHARE_CLOUD_DAYS,
        "max_file_size": MAX_SHARE_SIZE,
    }


def verify_share_upload(user: User, data: MaterialShareVerifyRequest):
    payload = decode_upload_authorization(data.upload_token)
    require_upload_authorization_type(payload, "material_share")
    require_upload_authorization_user(payload, user.id)

    normalized_hash = _hash(data.file_hash)
    normalized_mime = data.mime_type.strip().lower()

    require_upload_authorization_fields(
        payload,
        {
            "recipient_user_id": data.recipient_user_id,
            "pathname": data.pathname.strip(),
            "size": data.size,
            "mime_type": normalized_mime,
            "file_hash": normalized_hash,
        },
    )

    return {
        "allowed": True,
        "recipient_user_id": data.recipient_user_id,
        "pathname": data.pathname.strip(),
        "mime_type": normalized_mime,
        "size": data.size,
        "file_hash": normalized_hash,
        "valid_until": int(payload["exp"]) * 1000,
    }


def complete_share(
    db: Session,
    user: User,
    data: MaterialShareCompleteRequest,
):
    payload = decode_upload_authorization(data.upload_token)
    require_upload_authorization_type(payload, "material_share")
    require_upload_authorization_user(payload, user.id)
    require_upload_authorization_fields(
        payload,
        {
            "recipient_user_id": data.recipient_user_id,
            "pathname": data.pathname,
            "size": data.size,
            "mime_type": data.mime_type.strip().lower(),
            "file_hash": _hash(data.file_hash),
        },
    )

    now = utc_now()
    record = MaterialShare(
        sender_user_id=user.id,
        recipient_user_id=data.recipient_user_id,
        subject_id=data.subject_id,
        original_name=data.original_name.strip(),
        stored_name=data.pathname.strip(),
        mime_type=data.mime_type.strip().lower(),
        size=data.size,
        file_hash=_hash(data.file_hash),
        message=data.message.strip() if data.message else None,
        status="pending",
        cloud_expires_at=now + timedelta(days=SHARE_CLOUD_DAYS),
    )
    db.add(record)
    db.flush()

    create_notification(
        db,
        user_id=record.recipient_user_id,
        notification_type="material_share",
        title="Nuovo materiale condiviso",
        message=(
            f'{user.first_name} {user.last_name} vuole condividere '
            f'"{record.original_name}" con te. Il file resta disponibile '
            "nel cloud per massimo 8 giorni."
        ),
        actor_user_id=user.id,
        resource_type="material_share",
        resource_id=record.id,
        action_type="material_share",
        action_resource_id=record.id,
        action_status="pending",
        expires_at=record.cloud_expires_at,
        commit=False,
    )

    db.commit()
    db.refresh(record)
    return record


def accept_share(db: Session, user: User, share_id: int):
    record = (
        db.query(MaterialShare)
        .filter(
            MaterialShare.id == share_id,
            MaterialShare.recipient_user_id == user.id,
        )
        .first()
    )
    if record is None:
        raise ValueError("Condivisione non trovata.")

    if record.cloud_expires_at <= utc_now():
        expire_share(db, record)
        raise ValueError("La condivisione è scaduta.")

    if record.status == "pending":
        record.status = "accepted"
        record.accepted_at = utc_now()
        record.updated_at = utc_now()
        db.commit()
        db.refresh(record)

    return record


def mark_delivered(db: Session, user: User, share_id: int):
    record = (
        db.query(MaterialShare)
        .filter(
            MaterialShare.id == share_id,
            MaterialShare.recipient_user_id == user.id,
        )
        .first()
    )
    if record is None:
        raise ValueError("Condivisione non trovata.")

    if record.status not in {"accepted", "delivered"}:
        raise ValueError("La condivisione non è stata accettata.")

    if record.status != "delivered":
        record.status = "delivered"
        record.delivered_at = utc_now()
        record.updated_at = utc_now()
        delete_private_blob_sync(record.stored_name)
        db.commit()
        db.refresh(record)

    return record


def reject_share(db: Session, user: User, share_id: int):
    record = (
        db.query(MaterialShare)
        .filter(
            MaterialShare.id == share_id,
            MaterialShare.recipient_user_id == user.id,
        )
        .first()
    )
    if record is None:
        raise ValueError("Condivisione non trovata.")

    if record.status in {"delivered", "rejected", "expired"}:
        return record

    record.status = "rejected"
    record.rejected_at = utc_now()
    record.updated_at = utc_now()
    delete_private_blob_sync(record.stored_name)
    db.commit()
    db.refresh(record)
    return record


def expire_share(db: Session, record: MaterialShare):
    if record.status in {"delivered", "rejected", "expired"}:
        return record

    delete_private_blob_sync(record.stored_name)
    record.status = "expired"
    record.updated_at = utc_now()
    db.commit()
    db.refresh(record)
    return record


def process_expired_shares(db: Session):
    now = utc_now()
    rows = (
        db.query(MaterialShare)
        .filter(
            MaterialShare.cloud_expires_at <= now,
            MaterialShare.status.in_(["pending", "accepted"]),
        )
        .all()
    )

    for record in rows:
        delete_private_blob_sync(record.stored_name)
        record.status = "expired"
        record.updated_at = now

    if rows:
        db.commit()

    return len(rows)
