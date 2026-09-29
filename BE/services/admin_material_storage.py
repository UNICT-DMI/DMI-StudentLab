import json
from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session
from core.config import settings

from models.material import GroupMaterial
from models.material_publication_request import MaterialPublicationRequest
from models.material_storage_event import MaterialStorageEvent
from models.public_material import PublicMaterial
from models.teacher_material import TeacherMaterial
from models.teacher_material_request import TeacherMaterialRequest
from core.material_course_proposal import MaterialCourseProposal
from models.user import User
from models.personal_material import PersonalSyncedMaterial
from models.material_share import MaterialShare
from services.personal_material import storage_owner_ref
from services.private_blob import delete_private_blob, list_private_blobs


SOURCES = {
    "publication_request",
    "public",
    "teacher",
    "group",
    "personal_sync",
    "shared_user",
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


def _person_name(user):
    """Nome leggibile di un utente, o None se assente."""
    if user is None:
        return None
    name = f"{getattr(user, 'first_name', '') or ''} {getattr(user, 'last_name', '') or ''}".strip()
    return name or getattr(user, 'email', None)


def _public_item(record):
    return {
        "source": "public",
        "id": record.id,
        "status": record.status,
        "visibility_state": record.visibility_state,
        "drive_copied": bool(record.drive_file_id),
        "drive_copied_at": record.drive_copied_at,
        "drive_activation_pending": bool(record.drive_activation_pending),
        "drive_retry_after": record.drive_retry_after,
        "drive_retry_attempts": record.drive_retry_attempts,
        "drive_path_segments": json.loads(record.drive_path_json) if record.drive_path_json else None,
        "audience_type": record.audience_type,
        "audience_id": record.audience_id,
        "title": record.title,
        "original_name": record.original_name,
        "stored_name": record.stored_name,
        "size": record.size,
        "mime_type": record.mime_type,
        "user_id": record.uploaded_by,
        # Provenienza per l'ispettore del Catalogo Drive (solo admin).
        "uploader_name": _person_name(getattr(record, "uploader", None)),
        "approver_name": _person_name(getattr(record, "approver", None)),
        "approved_at": record.approved_at,
        "created_at": record.created_at,
        "contributor_mode": getattr(record, "contributor_mode", None),
        "file_hash": record.file_hash,
        "subject_id": record.subject_id,
        "path_segments": json.loads(record.catalog_path_json or '[]'),
        "group_id": None,
        "updated_at": record.updated_at,
        "safe_to_delete_blob": record.status == "removed" and not (record.stored_name or '').startswith('drive-import/'),
        "expects_blob": record.status != "removed" and not record.drive_file_id
            and not (record.stored_name or '').startswith('drive-import/'),
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



def _personal_item(record):
    return {
        "source":"personal_sync",
        "id":record.id,
        "status":record.status,
        "title":"Materiale personale",
        "original_name":None,
        "stored_name":record.stored_name,
        "size":record.size,
        "mime_type":record.mime_type,
        "user_id":None,
        "owner_ref":storage_owner_ref(record.owner_user_id),
        "subject_id":record.subject_id,
        "group_id":None,
        "updated_at":record.updated_at,
        "created_at":record.created_at,
        "cloud_expires_at":record.retention_expires_at,
        "retention_status":record.retention_status,
        "safe_to_delete_blob":record.status=="removed" or record.retention_status=="deleted",
        "expects_blob":record.status=="active",
        "can_retire":False,
        "can_rename":False,
        "private_content":True,
    }


def _share_item(record):
    return {
        "source":"shared_user",
        "id":record.id,
        "status":record.status,
        "title":"Condivisione privata",
        "original_name":None,
        "stored_name":record.stored_name,
        "size":record.size,
        "mime_type":record.mime_type,
        "user_id":None,
        "owner_ref":storage_owner_ref(record.sender_user_id),
        "subject_id":record.subject_id,
        "group_id":None,
        "updated_at":record.updated_at,
        "created_at":record.created_at,
        "cloud_expires_at":record.cloud_expires_at,
        "safe_to_delete_blob":record.status in {"delivered","rejected","expired"},
        "expects_blob":record.status in {"pending","accepted"},
        "can_retire":False,
        "can_rename":False,
        "private_content":True,
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
    if source == "personal_sync":
        return db.query(PersonalSyncedMaterial).filter(PersonalSyncedMaterial.id == material_id).first()
    if source == "shared_user":
        return db.query(MaterialShare).filter(MaterialShare.id == material_id).first()
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
    if source == "personal_sync":
        return _personal_item(record)
    if source == "shared_user":
        return _share_item(record)
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

    if source in {None, "personal_sync"}:
        query = db.query(PersonalSyncedMaterial)
        if status:
            query = query.filter(PersonalSyncedMaterial.status == status)
        items.extend(_personal_item(item) for item in query.order_by(PersonalSyncedMaterial.updated_at.desc()).all())

    if source in {None, "shared_user"}:
        query = db.query(MaterialShare)
        if status:
            query = query.filter(MaterialShare.status == status)
        items.extend(_share_item(item) for item in query.order_by(MaterialShare.updated_at.desc()).all())

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
        PersonalSyncedMaterial,
        MaterialShare,
    ):
        rows = db.query(model.stored_name).all()
        for row in rows:
            value = _clean_text(row[0])
            if value:
                values.add(value)

    return values


def queue_counts(db: Session) -> dict:
    """Elementi in attesa nelle tre code admin, per i badge della pagina."""
    return {
        "pending_publication_requests": db.query(MaterialPublicationRequest.id)
        .filter(MaterialPublicationRequest.status == "pending").count(),
        "pending_course_proposals": db.query(MaterialCourseProposal.id)
        .filter(MaterialCourseProposal.status == "pending").count(),
        "open_studentlab_requests": db.query(TeacherMaterialRequest.id)
        .filter(TeacherMaterialRequest.recipient_kind == "studentlab",
                TeacherMaterialRequest.status == "pending").count(),
    }


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
            **queue_counts(db),
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


def move_public_folder(
    db: Session, *, source_subject_id: int, source_path: list[str],
    destination_subject_id: int, destination_path: list[str],
    actor: User,
):
    """Move one logical folder and all descendants; never move Blob bytes."""
    from models.subject import Subject

    def validate(path, allow_empty=False):
        if (not allow_empty and not path) or len(path) > 8:
            raise ValueError('Percorso della cartella non valido.')
        for segment in path:
            if (not isinstance(segment, str) or not segment.strip() or
                len(segment.strip()) > 80 or segment in {'.', '..'} or
                '/' in segment or '\\' in segment):
                raise ValueError('Nome della cartella non valido.')
        return [segment.strip() for segment in path]

    source = validate(source_path)
    target = validate(destination_path, allow_empty=True)
    if source_subject_id == destination_subject_id and target[:len(source)] == source:
        raise ValueError('Non puoi spostare una cartella dentro sé stessa.')
    subject = db.query(Subject).filter(Subject.id == destination_subject_id,
                                       Subject.is_active.is_(True)).first()
    if subject is None:
        raise ValueError('Materia di destinazione non trovata.')

    rows = db.query(PublicMaterial).filter(
        PublicMaterial.subject_id == source_subject_id,
    ).with_for_update().all()
    affected = []
    for row in rows:
        current = json.loads(row.catalog_path_json or '[]')
        if current[:len(source)] != source:
            continue
        if row.audience_type == 'group' and destination_subject_id != source_subject_id:
            raise ValueError('Modifica i destinatari del gruppo prima di spostare la cartella in un’altra materia.')
        next_path = target + source[-1:] + current[len(source):]
        if len(next_path) > 8:
            raise ValueError('Il percorso risultante è troppo profondo.')
        affected.append((row, next_path))
    if not affected:
        raise ValueError('Nessun file nella cartella indicata.')

    now = utc_now()
    for row, path in affected:
        row.catalog_path_json = json.dumps(path, ensure_ascii=False)
        row.subject_id = subject.id
        row.university = subject.university
        row.university_code = subject.university_code
        row.department = subject.department
        row.department_code = subject.department_code or ''
        row.course = subject.course
        row.course_code = subject.course_code or ''
        row.version = (row.version or 1) + 1
        row.updated_at = now
        record_storage_event(db, source='public', material_id=row.id,
            action='folder_moved', actor_id=actor.id, blob_path=row.stored_name,
            original_name=row.original_name, size=row.size,
            details={'source_subject_id': source_subject_id, 'source_path': source,
                     'destination_subject_id': destination_subject_id,
                     'destination_path': path}, commit=False)
    try:
        db.commit()
    except Exception:
        db.rollback()
        raise
    return {'moved_files': len(affected), 'destination_subject_id': subject.id}


def place_public_file(db: Session, *, material_id: int, subject_id: int,
                      path: list[str], actor: User):
    """Reclassify one published file without altering its physical storage."""
    from models.subject import Subject

    if len(path) > 8 or any(
        not isinstance(part, str) or not part.strip() or len(part.strip()) > 80
        or part in {'.', '..'} or '/' in part or '\\' in part
        for part in path
    ):
        raise ValueError('Percorso non valido.')
    subject = db.query(Subject).filter(Subject.id == subject_id,
                                       Subject.is_active.is_(True)).first()
    if subject is None:
        raise ValueError('Materia non trovata.')
    material = db.query(PublicMaterial).filter(PublicMaterial.id == material_id).with_for_update().first()
    if material is None or material.status == 'removed':
        raise ValueError('Materiale non trovato o ritirato.')
    if material.audience_type == 'group' and material.subject_id != subject.id:
        raise ValueError('Modifica i destinatari del gruppo prima di cambiare materia.')
    material.subject_id = subject.id
    material.university, material.university_code = subject.university, subject.university_code
    material.department, material.department_code = subject.department, subject.department_code or ''
    material.course, material.course_code = subject.course, subject.course_code or ''
    material.catalog_path_json = json.dumps([part.strip() for part in path], ensure_ascii=False)
    material.version = (material.version or 1) + 1
    material.updated_at = utc_now()
    record_storage_event(db, source='public', material_id=material.id,
        action='reclassified', actor_id=actor.id, blob_path=material.stored_name,
        original_name=material.original_name, size=material.size,
        details={'subject_id': subject.id, 'path_segments': path}, commit=False)
    try:
        db.commit()
    except Exception:
        db.rollback()
        raise
    return {'id': material.id, 'subject_id': subject.id, 'path_segments': path}


def set_public_visibility(db: Session, *, material_id: int, state: str, actor: User):
    if state not in {'visible', 'hidden', 'in_review', 'archived'}:
        raise ValueError('Visibilità non valida.')
    material = db.query(PublicMaterial).filter(PublicMaterial.id == material_id).with_for_update().first()
    if material is None or material.status == 'removed':
        raise ValueError('Materiale non trovato o ritirato.')
    if state == 'visible' and not material.drive_file_id and (
        material.drive_activation_pending or (
            settings.drive_client_id and settings.drive_client_secret and settings.drive_refresh_token
        )
    ):
        raise ValueError('Completa prima il caricamento su Drive.')
    if state != 'visible':
        material.drive_activation_pending = False
    material.visibility_state = state
    material.status = 'published' if state == 'visible' else 'hidden'
    material.is_visible = state == 'visible'
    material.version = (material.version or 1) + 1
    material.updated_at = utc_now()
    record_storage_event(db, source='public', material_id=material.id,
        action='visibility_changed', actor_id=actor.id, blob_path=material.stored_name,
        original_name=material.original_name, size=material.size,
        details={'visibility_state': state}, commit=False)
    try:
        db.commit()
    except Exception:
        db.rollback()
        raise
    return {'id': material.id, 'visibility_state': state,
            'is_visible': material.is_visible}


def set_public_audience(db: Session, *, material_id: int, audience_type: str,
                        audience_id: int | None, actor: User):
    from models.group import StudyGroup
    from models.subject import Subject

    material = db.query(PublicMaterial).filter(PublicMaterial.id == material_id).with_for_update().first()
    if material is None or material.status == 'removed':
        raise ValueError('Materiale non trovato o ritirato.')
    if audience_type in {'public', 'course', 'subject'}:
        if audience_id is not None:
            raise ValueError('Questo destinatario non richiede un ID.')
    elif audience_type == 'group':
        group = db.query(StudyGroup).filter(StudyGroup.id == audience_id,
                                           StudyGroup.status == 'active').first()
        if group is None or group.subject_id != material.subject_id:
            raise ValueError('Il gruppo deve essere attivo e appartenere alla stessa materia.')
    elif audience_type == 'user':
        if audience_id is None or db.query(User.id).filter(User.id == audience_id,
                                                         User.is_active.is_(True)).first() is None:
            raise ValueError('Studente destinatario non trovato.')
    else:
        raise ValueError('Destinatario non valido.')
    if audience_type == 'subject':
        subject = db.query(Subject).filter(Subject.id == material.subject_id,
                                           Subject.is_active.is_(True)).first()
        if subject is None:
            raise ValueError('Materia non più disponibile.')
    material.audience_type = audience_type
    material.audience_id = audience_id
    material.version = (material.version or 1) + 1
    material.updated_at = utc_now()
    record_storage_event(db, source='public', material_id=material.id,
        action='audience_changed', actor_id=actor.id,
        blob_path=material.stored_name, original_name=material.original_name,
        size=material.size, details={'type': audience_type, 'id': audience_id},
        commit=False)
    try:
        db.commit()
    except Exception:
        db.rollback()
        raise
    return {'id': material.id, 'audience_type': audience_type,
            'audience_id': audience_id}
