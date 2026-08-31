import json
from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session

from models.material import GroupMaterial
from models.material_publication_request import MaterialPublicationRequest
from models.material_storage_event import MaterialStorageEvent
from models.public_material import PublicMaterial
from models.teacher_material import TeacherMaterial
from models.user import User
from services.private_blob import delete_private_blob, list_private_blobs


SOURCES = {
    "publication_request",
    "public",
    "teacher",
    "group",
}

ORPHAN_MIN_AGE = timedelta(hours=2)


def utc_now():
    return datetime.now(timezone.utc)


def _clean_text(value):
    if value is None:
        return None
    normalized = str(value).strip()
    return normalized if normalized else None


def record_storage_event(
    db: Session,
    *,
    source: str,
    material_id: int | None,
    action: str,
    actor_id: int | None,
    blob_path: str | None = None,
    original_name: str | None = None,
    size: int | None = None,
    reason: str | None = None,
    details: dict | None = None,
    commit: bool = True,
):
    event = MaterialStorageEvent(
        source=source,
        material_id=material_id,
        action=action,
        blob_path=_clean_text(blob_path),
        original_name=_clean_text(original_name),
        size=size,
        actor_id=actor_id,
        reason=_clean_text(reason),
        details_json=(
            json.dumps(details, ensure_ascii=False, sort_keys=True)
            if details
            else None
        ),
    )
    db.add(event)
    if commit:
        db.commit()
        db.refresh(event)
    return event


def _publication_item(record):
    return {
        "source": "publication_request",
        "id": record.id,
        "status": record.status,
        "title": record.title,
        "original_name": record.original_name,
        "stored_name": record.stored_name,
        "size": record.size,
        "mime_type": record.mime_type,
        "user_id": record.user_id,
        "subject_id": record.subject_id,
        "group_id": None,
        "updated_at": record.updated_at,
        "safe_to_delete_blob": record.status == "rejected",
        "expects_blob": record.status == "pending",
        "can_retire": False,
        "can_rename": True,
    }


def _public_item(record):
    return {
        "source": "public",
        "id": record.id,
        "status": record.status,
        "title": record.title,
        "original_name": record.original_name,
        "stored_name": record.stored_name,
        "size": record.size,
        "mime_type": record.mime_type,
        "user_id": record.uploaded_by,
        "subject_id": record.subject_id,
        "group_id": None,
        "updated_at": record.updated_at,
        "safe_to_delete_blob": record.status == "removed",
        "expects_blob": record.status != "removed",
        "can_retire": record.status != "removed",
        "can_rename": True,
    }


def _teacher_item(record):
    return {
        "source": "teacher",
        "id": record.id,
        "status": record.status,
        "title": record.title,
        "original_name": record.original_name,
        "stored_name": record.stored_name,
        "size": record.size,
        "mime_type": record.mime_type,
        "user_id": record.uploaded_by,
        "subject_id": record.subject_id,
        "group_id": None,
        "updated_at": record.updated_at,
        "safe_to_delete_blob": record.status == "removed",
        "expects_blob": record.status != "removed",
        "can_retire": record.status != "removed",
        "can_rename": True,
    }


def _group_item(record):
    return {
        "source": "group",
        "id": record.id,
        "status": record.status,
        "title": record.original_name,
        "original_name": record.original_name,
        "stored_name": record.stored_name,
        "size": record.size,
        "mime_type": record.mime_type,
        "user_id": record.uploaded_by,
        "subject_id": None,
        "group_id": record.group_id,
        "updated_at": record.updated_at,
        "safe_to_delete_blob": record.status == "removed",
        "expects_blob": record.status != "removed",
        "can_retire": record.status != "removed",
        "can_rename": False,
    }


def get_storage_record(db: Session, source: str, material_id: int):
    if source == "publication_request":
        return (
            db.query(MaterialPublicationRequest)
            .filter(MaterialPublicationRequest.id == material_id)
            .first()
        )
    if source == "public":
        return db.query(PublicMaterial).filter(PublicMaterial.id == material_id).first()
    if source == "teacher":
        return (
            db.query(TeacherMaterial)
            .filter(TeacherMaterial.id == material_id)
            .first()
        )
    if source == "group":
        return db.query(GroupMaterial).filter(GroupMaterial.id == material_id).first()
    raise ValueError("Sorgente materiale non valida.")


def serialize_storage_record(source: str, record):
    if source == "publication_request":
        return _publication_item(record)
    if source == "public":
        return _public_item(record)
    if source == "teacher":
        return _teacher_item(record)
    if source == "group":
        return _group_item(record)
    raise ValueError("Sorgente materiale non valida.")


def get_admin_material_items(
    db: Session,
    *,
    source: str | None = None,
    status: str | None = None,
):
    if source is not None and source not in SOURCES:
        raise ValueError("Sorgente materiale non valida.")

    items = []

    if source in {None, "publication_request"}:
        query = db.query(MaterialPublicationRequest)
        if status:
            query = query.filter(MaterialPublicationRequest.status == status)
        items.extend(
            _publication_item(item)
            for item in query.order_by(MaterialPublicationRequest.updated_at.desc()).all()
        )

    if source in {None, "public"}:
        query = db.query(PublicMaterial)
        if status:
            query = query.filter(PublicMaterial.status == status)
        items.extend(
            _public_item(item)
            for item in query.order_by(PublicMaterial.updated_at.desc()).all()
        )

    if source in {None, "teacher"}:
        query = db.query(TeacherMaterial)
        if status:
            query = query.filter(TeacherMaterial.status == status)
        items.extend(
            _teacher_item(item)
            for item in query.order_by(TeacherMaterial.updated_at.desc()).all()
        )

    if source in {None, "group"}:
        query = db.query(GroupMaterial)
        if status:
            query = query.filter(GroupMaterial.status == status)
        items.extend(
            _group_item(item)
            for item in query.order_by(GroupMaterial.updated_at.desc()).all()
        )

    items.sort(
        key=lambda value: value.get("updated_at") or datetime.min.replace(tzinfo=timezone.utc),
        reverse=True,
    )
    return items


def get_all_referenced_blob_paths(db: Session):
    values = set()

    for model in (
        MaterialPublicationRequest,
        PublicMaterial,
        TeacherMaterial,
        GroupMaterial,
    ):
        rows = db.query(model.stored_name).all()
        for row in rows:
            value = _clean_text(row[0])
            if value:
                values.add(value)

    return values


async def build_storage_snapshot(db: Session):
    blobs = await list_private_blobs()
    blob_by_path = {
        getattr(blob, "pathname", ""): blob
        for blob in blobs
        if getattr(blob, "pathname", "")
    }
    references = get_all_referenced_blob_paths(db)
    items = get_admin_material_items(db)

    for item in items:
        blob = blob_by_path.get(item["stored_name"])
        item["blob_exists"] = blob is not None
        item["blob_size"] = (
            int(getattr(blob, "size", 0) or 0)
            if blob is not None
            else 0
        )

    total_bytes = sum(int(getattr(blob, "size", 0) or 0) for blob in blobs)
    referenced_bytes = sum(
        int(getattr(blob_by_path[path], "size", 0) or 0)
        for path in references
        if path in blob_by_path
    )

    orphan_blobs = []
    now = utc_now()
    for path, blob in blob_by_path.items():
        if path in references:
            continue

        uploaded_at = getattr(blob, "uploaded_at", None)
        age_safe = True
        if uploaded_at is not None:
            if uploaded_at.tzinfo is None:
                uploaded_at = uploaded_at.replace(tzinfo=timezone.utc)
            age_safe = now - uploaded_at >= ORPHAN_MIN_AGE

        orphan_blobs.append(
            {
                "pathname": path,
                "size": int(getattr(blob, "size", 0) or 0),
                "uploaded_at": uploaded_at,
                "safe_to_cleanup": age_safe,
            }
        )

    reclaimable = sum(
        item["blob_size"]
        for item in items
        if item["safe_to_delete_blob"] and item["blob_exists"]
    )
    reclaimable += sum(
        blob["size"] for blob in orphan_blobs if blob["safe_to_cleanup"]
    )

    return {
        "summary": {
            "blob_count": len(blobs),
            "total_bytes": total_bytes,
            "referenced_bytes": referenced_bytes,
            "orphan_bytes": max(total_bytes - referenced_bytes, 0),
            "reclaimable_bytes": reclaimable,
            "database_record_count": len(items),
            "missing_blob_count": sum(
                1
                for item in items
                if item["expects_blob"] and not item["blob_exists"]
            ),
            "orphan_blob_count": len(orphan_blobs),
        },
        "items": items,
        "orphan_blobs": orphan_blobs,
    }


async def delete_record_blob(
    db: Session,
    *,
    source: str,
    material_id: int,
    actor: User,
    reason: str | None = None,
):
    record = get_storage_record(db, source, material_id)
    if record is None:
        raise ValueError("Materiale non trovato.")

    item = serialize_storage_record(source, record)
    if not item["safe_to_delete_blob"]:
        raise ValueError(
            "Il file può essere eliminato solo dopo il rifiuto o il ritiro del materiale."
        )

    deleted = await delete_private_blob(item["stored_name"])
    record_storage_event(
        db,
        source=source,
        material_id=material_id,
        action="blob_deleted" if deleted else "blob_already_missing",
        actor_id=actor.id,
        blob_path=item["stored_name"],
        original_name=item["original_name"],
        size=item["size"],
        reason=reason,
    )

    return {
        **item,
        "blob_deleted": deleted,
        "blob_exists": False,
    }


def retire_material(
    db: Session,
    *,
    source: str,
    material_id: int,
    actor: User,
    reason: str,
):
    if source not in {"public", "teacher", "group"}:
        raise ValueError("Questo tipo di materiale non può essere ritirato.")

    record = get_storage_record(db, source, material_id)
    if record is None:
        raise ValueError("Materiale non trovato.")

    normalized_reason = reason.strip()
    if not normalized_reason:
        raise ValueError("Inserisci il motivo del ritiro.")

    now = utc_now()

    if source == "public":
        record.status = "removed"
        record.is_visible = False
        record.removed_by = actor.id
        record.removed_at = now
        record.removal_reason = normalized_reason
        record.updated_at = now
    else:
        record.status = "removed"
        record.is_active = False
        record.removed_by = actor.id
        record.removed_at = now
        record.removal_reason = normalized_reason
        record.updated_by = actor.id
        record.updated_at = now

    record_storage_event(
        db,
        source=source,
        material_id=material_id,
        action="retired",
        actor_id=actor.id,
        blob_path=record.stored_name,
        original_name=record.original_name,
        size=record.size,
        reason=normalized_reason,
        commit=False,
    )

    try:
        db.commit()
        db.refresh(record)
    except Exception:
        db.rollback()
        raise

    return serialize_storage_record(source, record)


def rename_material(
    db: Session,
    *,
    source: str,
    material_id: int,
    actor: User,
    display_name: str,
):
    if source not in {"publication_request", "public", "teacher"}:
        raise ValueError("Il nome di questo materiale non è modificabile da qui.")

    record = get_storage_record(db, source, material_id)
    if record is None:
        raise ValueError("Materiale non trovato.")

    value = display_name.strip()
    if not value:
        raise ValueError("Nome materiale non valido.")

    previous = record.title
    record.title = value
    record.updated_at = utc_now()

    record_storage_event(
        db,
        source=source,
        material_id=material_id,
        action="display_name_changed",
        actor_id=actor.id,
        blob_path=record.stored_name,
        original_name=record.original_name,
        size=record.size,
        details={"previous": previous, "current": value},
        commit=False,
    )

    try:
        db.commit()
        db.refresh(record)
    except Exception:
        db.rollback()
        raise

    return serialize_storage_record(source, record)


async def cleanup_dry_run(db: Session):
    snapshot = await build_storage_snapshot(db)

    candidates = [
        item
        for item in snapshot["items"]
        if item["safe_to_delete_blob"] and item["blob_exists"]
    ]

    return {
        "record_candidates": candidates,
        "orphan_candidates": [
            item
            for item in snapshot["orphan_blobs"]
            if item["safe_to_cleanup"]
        ],
        "reclaimable_bytes": snapshot["summary"]["reclaimable_bytes"],
    }


async def execute_cleanup(
    db: Session,
    *,
    actor: User,
    rejected_publications: bool,
    removed_materials: bool,
    orphan_blobs: bool,
):
    dry_run = await cleanup_dry_run(db)
    deleted = []
    failed = []

    for item in dry_run["record_candidates"]:
        should_delete = (
            item["source"] == "publication_request"
            and item["status"] == "rejected"
            and rejected_publications
        ) or (
            item["source"] in {"public", "teacher", "group"}
            and item["status"] == "removed"
            and removed_materials
        )

        if not should_delete:
            continue

        try:
            result = await delete_record_blob(
                db,
                source=item["source"],
                material_id=item["id"],
                actor=actor,
                reason="Pulizia storage amministrativa.",
            )
            if result["blob_deleted"]:
                deleted.append(item["stored_name"])
        except Exception as exception:
            failed.append(
                {
                    "pathname": item["stored_name"],
                    "error": str(exception),
                }
            )

    if orphan_blobs:
        for item in dry_run["orphan_candidates"]:
            path = item["pathname"]
            try:
                did_delete = await delete_private_blob(path)
                if did_delete:
                    deleted.append(path)
                record_storage_event(
                    db,
                    source="orphan",
                    material_id=None,
                    action="orphan_blob_deleted" if did_delete else "orphan_blob_missing",
                    actor_id=actor.id,
                    blob_path=path,
                    size=item["size"],
                    reason="Pulizia Blob orfano.",
                )
            except Exception as exception:
                failed.append({"pathname": path, "error": str(exception)})

    return {
        "deleted_count": len(deleted),
        "deleted": deleted,
        "failed_count": len(failed),
        "failed": failed,
    }