from datetime import datetime, timezone
from typing import Any

from pydantic import ValidationError
from sqlalchemy import func
from sqlalchemy.orm import Session

from models.question_moderation import QuestionModerationItem
from models.subject import Subject
from models.teacher_assignment import TeacherAssignment
from models.user import User
from schemas.question import QuestionCreate
from schemas.question_moderation import (
    QuestionModerationResolution,
    QuestionProposalCreate,
    QuestionProposalUpdate,
    QuestionReportCreate,
)
from services.private_blob import delete_private_blob_sync
from services.question_service import create_question, get_question


ADMIN_ROLES = {"admin", "creator"}


def utc_now():
    return datetime.now(timezone.utc)


def _is_admin(user: User) -> bool:
    return str(user.role or "").strip().lower() in ADMIN_ROLES


def _is_student(user: User) -> bool:
    return str(user.role or "").strip().lower() == "student"


def _get_subject(
    db: Session,
    department: str,
    course: str,
    subject: str,
) -> Subject | None:
    return (
        db.query(Subject)
        .filter(
            func.lower(Subject.department_code) == department.strip().lower(),
            func.lower(Subject.course_code) == course.strip().lower(),
            func.lower(Subject.name) == subject.strip().lower(),
            Subject.is_active.is_(True),
        )
        .first()
    )


def _teacher_can_manage_subject(
    db: Session,
    user: User,
    department: str,
    course: str,
    subject: str,
) -> bool:
    if str(user.role or "").strip().lower() != "teacher":
        return False
    if str(user.teacher_verification_status or "").strip().lower() != "verified":
        return False
    row = (
        db.query(TeacherAssignment.id)
        .join(Subject, Subject.id == TeacherAssignment.subject_id)
        .filter(
            TeacherAssignment.user_id == user.id,
            TeacherAssignment.verification_status == "verified",
            TeacherAssignment.is_current.is_(True),
            Subject.is_active.is_(True),
            func.lower(Subject.department_code) == department.strip().lower(),
            func.lower(Subject.course_code) == course.strip().lower(),
            func.lower(Subject.name) == subject.strip().lower(),
        )
        .first()
    )
    return row is not None


def require_moderation_access(
    db: Session,
    user: User,
    item: QuestionModerationItem | None = None,
    department: str | None = None,
    course: str | None = None,
    subject: str | None = None,
) -> None:
    if _is_admin(user):
        return
    target_department = item.department if item is not None else department
    target_course = item.course if item is not None else course
    target_subject = item.subject if item is not None else subject
    if not target_department or not target_course or not target_subject:
        raise PermissionError("Materia non disponibile.")
    if not _teacher_can_manage_subject(
        db,
        user,
        target_department,
        target_course,
        target_subject,
    ):
        raise PermissionError("Non puoi revisionare le domande di questa materia.")


def _normalize_teacher(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, str):
        normalized = value.strip()
        return [normalized] if normalized else []
    if isinstance(value, list):
        result: list[str] = []
        for item in value:
            normalized = str(item).strip()
            if normalized and normalized not in result:
                result.append(normalized)
        return result
    raise ValueError("Il campo docente non è valido.")


def _normalize_response_explanations(
    value: Any,
    options: Any,
) -> dict[str, str]:
    option_ids: list[str] = []
    if isinstance(options, list):
        for option in options:
            if not isinstance(option, dict):
                continue
            option_id = str(option.get("id", "")).strip()
            if option_id and option_id not in option_ids:
                option_ids.append(option_id)
    if isinstance(value, dict):
        return {
            str(key).strip(): str(raw).strip()
            for key, raw in value.items()
            if str(key).strip()
        }
    if isinstance(value, str):
        normalized = value.strip()
        if not normalized:
            return {}
        return {option_id: normalized for option_id in option_ids}
    return {}


def _attachment_owner_from_path(stored_name: str) -> int | None:
    parts = stored_name.strip().split("/")
    if len(parts) < 4:
        return None
    if parts[0] != "questions" or parts[1] != "tmp":
        return None
    try:
        return int(parts[2])
    except ValueError:
        return None


def _normalize_attachments(
    value: Any,
    allowed_user_ids: set[int],
) -> list[dict[str, Any]]:
    if value is None:
        return []
    if not isinstance(value, list):
        raise ValueError("Gli allegati della proposta non sono validi.")
    result: list[dict[str, Any]] = []
    seen: set[str] = set()
    for raw in value:
        if not isinstance(raw, dict):
            raise ValueError("Gli allegati della proposta non sono validi.")
        attachment = dict(raw)
        attachment_id = str(attachment.get("id", "")).strip()
        attachment_type = str(attachment.get("type", "")).strip().lower()
        original_name = str(attachment.get("original_name", "")).strip()
        mime_type = str(attachment.get("mime_type", "")).strip().lower()
        stored_name = str(attachment.get("stored_name", "")).strip()
        owner_id = _attachment_owner_from_path(stored_name)
        if (
            not attachment_id
            or attachment_type not in {"image", "document"}
            or not original_name
            or not mime_type
            or not stored_name
            or owner_id not in allowed_user_ids
        ):
            raise ValueError("Un allegato della proposta non è valido.")
        if stored_name in seen:
            continue
        seen.add(stored_name)
        result.append(
            {
                "id": attachment_id,
                "type": attachment_type,
                "original_name": original_name,
                "mime_type": mime_type,
                "stored_name": stored_name,
            }
        )
    return result


def _normalize_proposal_payload(
    db: Session,
    user: User,
    department: str,
    course: str,
    subject: str,
    payload: dict[str, Any],
    allowed_attachment_user_ids: set[int],
) -> dict[str, Any]:
    subject_record = _get_subject(db, department, course, subject)
    if subject_record is None:
        raise ValueError("Materia non trovata.")
    normalized = dict(payload)
    metadata_raw = normalized.get("metadata")
    metadata = dict(metadata_raw) if isinstance(metadata_raw, dict) else {}
    metadata["university"] = (
        str(metadata.get("university") or subject_record.university or "").strip()
    )
    metadata["department"] = str(
        metadata.get("department") or subject_record.department or ""
    ).strip()
    metadata["department_code"] = department.strip()
    metadata["course"] = str(
        metadata.get("course") or subject_record.course or ""
    ).strip()
    metadata["course_code"] = course.strip()
    metadata["subject"] = subject.strip()
    metadata["subject_code"] = str(subject_record.code or "").strip()
    metadata["teacher"] = _normalize_teacher(metadata.get("teacher"))
    if not str(metadata.get("year_of_validity", "")).strip():
        metadata["year_of_validity"] = "attuale"
    normalized["metadata"] = metadata
    normalized["question_response_explanation"] = _normalize_response_explanations(
        normalized.get("question_response_explanation"),
        normalized.get("option"),
    )
    normalized["attachments"] = _normalize_attachments(
        normalized.get("attachments"),
        allowed_attachment_user_ids,
    )
    try:
        validated = QuestionCreate.model_validate(normalized)
    except ValidationError as exception:
        first = exception.errors()[0] if exception.errors() else {}
        message = str(first.get("msg") or "La domanda proposta non è valida.")
        message = message.removeprefix("Value error, ").strip()
        raise ValueError(message) from exception
    return validated.model_dump(mode="json")


def create_question_report(
    db: Session,
    user: User,
    data: QuestionReportCreate,
) -> QuestionModerationItem:
    question = get_question(
        department=data.department,
        course=data.course,
        subject=data.subject,
        question_id=data.question_id,
        include_hidden=True,
    )
    if question is None:
        raise ValueError("Domanda non trovata.")
    existing = (
        db.query(QuestionModerationItem)
        .filter(
            QuestionModerationItem.source_type == "report",
            QuestionModerationItem.created_by == user.id,
            QuestionModerationItem.department == data.department,
            QuestionModerationItem.course == data.course,
            QuestionModerationItem.subject == data.subject,
            QuestionModerationItem.question_id == data.question_id,
            QuestionModerationItem.status.in_(["pending", "under_review"]),
        )
        .first()
    )
    if existing is not None:
        raise FileExistsError(
            "Hai già segnalato questa domanda e la segnalazione è ancora in revisione."
        )
    item = QuestionModerationItem(
        source_type="report",
        department=data.department,
        course=data.course,
        subject=data.subject,
        question_id=data.question_id,
        report_reason=data.reason,
        report_message=data.message,
        created_by=user.id,
        status="pending",
    )
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


def create_question_proposal(
    db: Session,
    user: User,
    data: QuestionProposalCreate,
    commit: bool = True,
) -> QuestionModerationItem:
    if not _is_student(user):
        raise PermissionError("Solo gli studenti possono proporre una domanda.")
    payload = _normalize_proposal_payload(
        db,
        user,
        data.department,
        data.course,
        data.subject,
        data.question,
        {user.id},
    )
    item = QuestionModerationItem(
        source_type="proposal",
        department=data.department,
        course=data.course,
        subject=data.subject,
        proposed_question_payload=payload,
        created_by=user.id,
        status="pending",
    )
    db.add(item)
    if commit:
        db.commit()
        db.refresh(item)
    return item


def create_question_proposals(
    db: Session,
    user: User,
    proposals: list[QuestionProposalCreate],
) -> list[QuestionModerationItem]:
    if not proposals:
        raise ValueError("Nessuna domanda da proporre.")
    items: list[QuestionModerationItem] = []
    try:
        for proposal in proposals:
            items.append(
                create_question_proposal(
                    db,
                    user,
                    proposal,
                    commit=False,
                )
            )
        db.commit()
        for item in items:
            db.refresh(item)
        return items
    except Exception:
        db.rollback()
        raise


def get_moderation_item(
    db: Session,
    item_id: int,
) -> QuestionModerationItem | None:
    return (
        db.query(QuestionModerationItem)
        .filter(QuestionModerationItem.id == item_id)
        .first()
    )


def list_moderation_items(
    db: Session,
    user: User,
    status: str | None = None,
    department: str | None = None,
    course: str | None = None,
    subject: str | None = None,
) -> list[QuestionModerationItem]:
    query = db.query(QuestionModerationItem)
    if status:
        query = query.filter(QuestionModerationItem.status == status)
    if department:
        query = query.filter(QuestionModerationItem.department == department)
    if course:
        query = query.filter(QuestionModerationItem.course == course)
    if subject:
        query = query.filter(QuestionModerationItem.subject == subject)
    if not _is_admin(user):
        if not department or not course or not subject:
            raise PermissionError("Seleziona una materia verificata.")
        require_moderation_access(
            db,
            user,
            department=department,
            course=course,
            subject=subject,
        )
    return (
        query.order_by(
            QuestionModerationItem.created_at.desc(),
            QuestionModerationItem.id.desc(),
        )
        .all()
    )


def list_my_proposals(
    db: Session,
    user: User,
) -> list[QuestionModerationItem]:
    return (
        db.query(QuestionModerationItem)
        .filter(
            QuestionModerationItem.source_type == "proposal",
            QuestionModerationItem.created_by == user.id,
        )
        .order_by(
            QuestionModerationItem.created_at.desc(),
            QuestionModerationItem.id.desc(),
        )
        .all()
    )


def claim_moderation_item(
    db: Session,
    user: User,
    item_id: int,
) -> QuestionModerationItem:
    item = (
        db.query(QuestionModerationItem)
        .filter(QuestionModerationItem.id == item_id)
        .with_for_update()
        .first()
    )
    if item is None:
        raise ValueError("Elemento di moderazione non trovato.")
    require_moderation_access(db, user, item=item)
    if item.status in {"approved", "rejected"}:
        return item
    if item.status == "under_review" and item.reviewed_by not in {None, user.id}:
        raise RuntimeError("Questa domanda è già in revisione da un altro moderatore.")
    item.status = "under_review"
    item.reviewed_by = user.id
    item.reviewer_role = str(user.role or "").strip().lower()
    item.review_started_at = item.review_started_at or utc_now()
    item.updated_at = utc_now()
    db.commit()
    db.refresh(item)
    return item


def update_proposal_payload(
    db: Session,
    user: User,
    item_id: int,
    data: QuestionProposalUpdate,
) -> QuestionModerationItem:
    item = (
        db.query(QuestionModerationItem)
        .filter(QuestionModerationItem.id == item_id)
        .with_for_update()
        .first()
    )
    if item is None or item.source_type != "proposal":
        raise ValueError("Proposta non trovata.")
    require_moderation_access(db, user, item=item)
    if item.status in {"approved", "rejected"}:
        raise ValueError("La proposta è già stata trattata.")
    if item.status == "under_review" and item.reviewed_by not in {None, user.id}:
        raise RuntimeError("Questa domanda è già in revisione da un altro moderatore.")
    payload = _normalize_proposal_payload(
        db,
        user,
        item.department,
        item.course,
        item.subject,
        data.question,
        {item.created_by, user.id},
    )
    old_attachments = (
        item.proposed_question_payload.get("attachments", [])
        if isinstance(item.proposed_question_payload, dict)
        else []
    )
    new_paths = {
        str(raw.get("stored_name", "")).strip()
        for raw in payload.get("attachments", [])
        if isinstance(raw, dict)
    }
    for raw in old_attachments:
        if not isinstance(raw, dict):
            continue
        stored_name = str(raw.get("stored_name", "")).strip()
        if stored_name and stored_name not in new_paths:
            delete_private_blob_sync(stored_name)
    item.proposed_question_payload = payload
    item.status = "under_review"
    item.reviewed_by = user.id
    item.reviewer_role = str(user.role or "").strip().lower()
    item.review_started_at = item.review_started_at or utc_now()
    item.updated_at = utc_now()
    db.commit()
    db.refresh(item)
    return item


def _delete_proposal_attachments(item: QuestionModerationItem) -> None:
    payload = item.proposed_question_payload
    if not isinstance(payload, dict):
        return
    attachments = payload.get("attachments", [])
    if not isinstance(attachments, list):
        return
    for raw in attachments:
        if not isinstance(raw, dict):
            continue
        stored_name = str(raw.get("stored_name", "")).strip()
        if stored_name:
            delete_private_blob_sync(stored_name)


def delete_my_pending_proposal(
    db: Session,
    user: User,
    item_id: int,
) -> None:
    item = (
        db.query(QuestionModerationItem)
        .filter(
            QuestionModerationItem.id == item_id,
            QuestionModerationItem.source_type == "proposal",
            QuestionModerationItem.created_by == user.id,
        )
        .with_for_update()
        .first()
    )
    if item is None:
        raise ValueError("Proposta non trovata.")
    if item.status != "pending":
        raise ValueError("La proposta non può più essere eliminata.")
    _delete_proposal_attachments(item)
    db.delete(item)
    db.commit()


def cleanup_temporary_attachments(
    user: User,
    attachments: list[dict[str, Any]],
) -> int:
    deleted = 0
    for raw in attachments:
        if not isinstance(raw, dict):
            continue
        stored_name = str(raw.get("stored_name", "")).strip()
        owner_id = _attachment_owner_from_path(stored_name)
        if owner_id != user.id:
            continue
        if stored_name and delete_private_blob_sync(stored_name):
            deleted += 1
    return deleted


def resolve_moderation_item(
    db: Session,
    user: User,
    item_id: int,
    data: QuestionModerationResolution,
) -> QuestionModerationItem:
    item = (
        db.query(QuestionModerationItem)
        .filter(QuestionModerationItem.id == item_id)
        .with_for_update()
        .first()
    )
    if item is None:
        raise ValueError("Elemento di moderazione non trovato.")
    require_moderation_access(db, user, item=item)
    if item.status in {"approved", "rejected"}:
        return item
    if item.status == "under_review" and item.reviewed_by not in {None, user.id}:
        raise RuntimeError("Questa domanda è già in revisione da un altro moderatore.")
    if item.source_type == "report" and item.question_id:
        question = get_question(
            department=item.department,
            course=item.course,
            subject=item.subject,
            question_id=item.question_id,
            include_hidden=True,
        )
        if question is None:
            raise ValueError("La domanda segnalata non è più disponibile.")
    if item.source_type == "proposal":
        if data.status == "approved":
            payload = item.proposed_question_payload
            if not isinstance(payload, dict):
                raise ValueError("La proposta non contiene una domanda valida.")
            validated = QuestionCreate.model_validate(payload)
            created = create_question(
                department=item.department,
                course=item.course,
                subject=item.subject,
                data=validated,
            )
            item.question_id = str(created.get("id_question", "")).strip() or None
        else:
            _delete_proposal_attachments(item)
            if isinstance(item.proposed_question_payload, dict):
                cleaned_payload = dict(item.proposed_question_payload)
                cleaned_payload["attachments"] = []
                item.proposed_question_payload = cleaned_payload
    item.status = data.status
    item.reviewed_by = user.id
    item.reviewer_role = str(user.role or "").strip().lower()
    item.resolution_note = data.resolution_note
    item.review_started_at = item.review_started_at or utc_now()
    item.reviewed_at = utc_now()
    item.updated_at = utc_now()
    db.commit()
    db.refresh(item)
    return item


def serialize_moderation_item(
    db: Session,
    item: QuestionModerationItem,
) -> dict:
    creator = db.query(User).filter(User.id == item.created_by).first()
    reviewer = (
        db.query(User).filter(User.id == item.reviewed_by).first()
        if item.reviewed_by
        else None
    )
    question = None
    if item.question_id:
        question = get_question(
            department=item.department,
            course=item.course,
            subject=item.subject,
            question_id=item.question_id,
            include_hidden=True,
        )

    def user_payload(value: User | None):
        if value is None:
            return None
        return {
            "id": value.id,
            "first_name": value.first_name,
            "last_name": value.last_name,
            "role": value.role,
        }

    return {
        "id": item.id,
        "source_type": item.source_type,
        "department": item.department,
        "course": item.course,
        "subject": item.subject,
        "question_id": item.question_id,
        "proposed_question_payload": item.proposed_question_payload,
        "report_reason": item.report_reason,
        "report_message": item.report_message,
        "status": item.status,
        "reviewer_role": item.reviewer_role,
        "resolution_note": item.resolution_note,
        "review_started_at": item.review_started_at,
        "reviewed_at": item.reviewed_at,
        "created_at": item.created_at,
        "updated_at": item.updated_at,
        "created_by_user": user_payload(creator),
        "reviewed_by_user": user_payload(reviewer),
        "question": question,
    }
