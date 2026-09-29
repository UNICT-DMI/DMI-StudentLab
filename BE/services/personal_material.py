from datetime import datetime, timedelta, timezone
from pathlib import Path
from uuid import uuid4
import hashlib

from sqlalchemy.orm import Session

from models.personal_material import PersonalSyncedMaterial
from models.user import User
from schemas.personal_material import (
    PersonalMaterialCompleteRequest,
    PersonalMaterialUploadRequest,
    PersonalMaterialVerifyRequest,
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


RETENTION_INACTIVITY_DAYS = 365
RETENTION_WARNING_DAYS = 30
MAX_PERSONAL_MATERIAL_SIZE = 250 * 1024 * 1024


def utc_now():
    return datetime.now(timezone.utc)


def _hash(value: str):
    normalized = value.strip().lower()
    if len(normalized) != 64 or not all(c in "0123456789abcdef" for c in normalized):
        raise ValueError("Hash del file non valido.")
    return normalized


def _owner_ref(user_id: int):
    return "U-" + hashlib.sha256(
        f"studentlab-storage:{user_id}".encode()
    ).hexdigest()[:8].upper()


def prepare_personal_upload(user: User, data: PersonalMaterialUploadRequest):
    if data.size > MAX_PERSONAL_MATERIAL_SIZE:
        raise ValueError("Il file supera la dimensione massima consentita.")

    extension = Path(data.original_name).suffix.lower()
    pathname = f"personal-sync/{user.id}/{uuid4().hex}{extension}"
    payload = {
        "v": 1,
        "type": "personal_material",
        "uid": user.id,
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
        "max_file_size": MAX_PERSONAL_MATERIAL_SIZE,
    }


def verify_personal_upload(user: User, data: PersonalMaterialVerifyRequest):
    payload = decode_upload_authorization(data.upload_token)
    require_upload_authorization_type(payload, "personal_material")
    require_upload_authorization_user(payload, user.id)

    normalized_hash = _hash(data.file_hash)
    normalized_mime = data.mime_type.strip().lower()

    require_upload_authorization_fields(
        payload,
        {
            "pathname": data.pathname.strip(),
            "size": data.size,
            "mime_type": normalized_mime,
            "file_hash": normalized_hash,
        },
    )

    return {
        "allowed": True,
        "pathname": data.pathname.strip(),
        "mime_type": normalized_mime,
        "size": data.size,
        "file_hash": normalized_hash,
        "valid_until": int(payload["exp"]) * 1000,
    }


def complete_personal_upload(
    db: Session,
    user: User,
    data: PersonalMaterialCompleteRequest,
):
    payload = decode_upload_authorization(data.upload_token)
    require_upload_authorization_type(payload, "personal_material")
    require_upload_authorization_user(payload, user.id)
    require_upload_authorization_fields(
        payload,
        {
            "pathname": data.pathname,
            "size": data.size,
            "mime_type": data.mime_type.strip().lower(),
            "file_hash": _hash(data.file_hash),
        },
    )

    existing = (
        db.query(PersonalSyncedMaterial)
        .filter(
            PersonalSyncedMaterial.owner_user_id == user.id,
            PersonalSyncedMaterial.file_hash == _hash(data.file_hash),
            PersonalSyncedMaterial.status == "active",
        )
        .first()
    )
    if existing is not None:
        return existing

    now = utc_now()
    record = PersonalSyncedMaterial(
        owner_user_id=user.id,
        subject_id=data.subject_id,
        university=data.university,
        department=data.department,
        course=data.course,
        subject_name=data.subject_name,
        original_name=data.original_name.strip(),
        stored_name=data.pathname.strip(),
        mime_type=data.mime_type.strip().lower(),
        size=data.size,
        file_hash=_hash(data.file_hash),
        version=1,
        status="active",
        retention_status="active",
        last_owner_activity_at=now,
    )
    db.add(record)
    db.commit()
    db.refresh(record)
    return record


def mark_personal_activity(db: Session, record: PersonalSyncedMaterial):
    record.last_owner_activity_at = utc_now()
    if record.retention_status == "warning":
        record.retention_status = "active"
        record.retention_warning_at = None
        record.retention_expires_at = None
    record.updated_at = utc_now()
    db.commit()
    db.refresh(record)
    return record


def process_personal_retention(db: Session):
    now = utc_now()
    warning_before = now - timedelta(days=RETENTION_INACTIVITY_DAYS)
    rows = (
        db.query(PersonalSyncedMaterial)
        .filter(PersonalSyncedMaterial.status == "active")
        .all()
    )
    warned = 0
    deleted = 0

    for record in rows:
        if (
            record.retention_status == "active"
            and record.last_owner_activity_at <= warning_before
        ):
            record.retention_status = "warning"
            record.retention_warning_at = now
            record.retention_expires_at = now + timedelta(days=RETENTION_WARNING_DAYS)
            create_notification(
                db,
                user_id=record.owner_user_id,
                notification_type="personal_storage_retention",
                title="Materiale personale in scadenza",
                message=(
                    f'La copia cloud di "{record.original_name}" verrà eliminata '
                    "tra 30 giorni se non scegli di conservarla."
                ),
                resource_type="personal_material",
                resource_id=record.id,
                action_type="personal_material_retention",
                action_resource_id=record.id,
                action_status="pending",
                expires_at=record.retention_expires_at,
                commit=False,
            )
            warned += 1
        elif (
            record.retention_status == "warning"
            and record.retention_expires_at is not None
            and record.retention_expires_at <= now
        ):
            delete_private_blob_sync(record.stored_name)
            record.status = "removed"
            record.retention_status = "deleted"
            record.deleted_at = now
            deleted += 1

    if warned or deleted:
        db.commit()

    return {"warned": warned, "deleted": deleted}


def retention_action(
    db: Session,
    user: User,
    material_id: int,
    action: str,
):
    record = (
        db.query(PersonalSyncedMaterial)
        .filter(
            PersonalSyncedMaterial.id == material_id,
            PersonalSyncedMaterial.owner_user_id == user.id,
        )
        .first()
    )
    if record is None:
        raise ValueError("Materiale personale non trovato.")

    if action == "keep":
        return mark_personal_activity(db, record)

    if action == "delete":
        delete_private_blob_sync(record.stored_name)
        record.status = "removed"
        record.retention_status = "deleted"
        record.deleted_at = utc_now()
        record.updated_at = utc_now()
        db.commit()
        db.refresh(record)
        return record

    raise ValueError("Azione non valida.")


def storage_owner_ref(user_id: int):
    return _owner_ref(user_id)
