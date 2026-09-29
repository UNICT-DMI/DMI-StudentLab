from datetime import datetime, timezone

from sqlalchemy.orm import Session, joinedload

from models.device_session import DeviceSession
from models.study_plan import StudyPlanContribution, StudyPlanItem, StudyPlanProgress
from models.user import User
from schemas.study_plan import StudyPlanSyncRequest
from services.quiz_statistics_service import get_student_question_statistics


def utc_now():
    return datetime.now(timezone.utc)


def _mastery(correct: int, wrong: int, unanswered: int) -> float:
    total = correct + wrong + unanswered
    if total <= 0:
        return 0.0
    return round((correct / total) * 100.0, 2)


def _status(mastery: float, wrong: int, unanswered: int) -> str:
    if mastery >= 85.0:
        return "consolidated"
    if mastery >= 60.0:
        return "improving"
    return "review"


def _ensure_session(
    db: Session,
    user: User,
    *,
    session_uuid: str,
    device_id: str,
    device_label: str | None,
    source_type: str,
) -> DeviceSession:
    session = db.query(DeviceSession).filter(DeviceSession.session_uuid == session_uuid).first()
    now = utc_now()

    if session is not None:
        if session.user_id != user.id:
            raise PermissionError("Questa sessione appartiene a un altro account.")
        session.device_id = device_id
        session.device_label = device_label
        session.source_type = source_type
        session.last_activity_at = now
        return session

    session = DeviceSession(
        session_uuid=session_uuid,
        device_id=device_id,
        user_id=user.id,
        device_label=device_label,
        source_type=source_type,
        contribution_enabled=True,
        created_at=now,
        last_activity_at=now,
        associated_at=now,
        dissociated_at=None,
    )
    db.add(session)
    db.flush()
    return session


def _ensure_item(db: Session, user_id: int, data) -> StudyPlanItem:
    item = (
        db.query(StudyPlanItem)
        .filter(
            StudyPlanItem.user_id == user_id,
            StudyPlanItem.department == data.department,
            StudyPlanItem.course == data.course,
            StudyPlanItem.subject == data.subject,
            StudyPlanItem.question_id == data.question_id,
        )
        .first()
    )
    now = utc_now()

    if item is None:
        item = StudyPlanItem(
            user_id=user_id,
            department=data.department,
            course=data.course,
            subject=data.subject,
            argument=data.argument,
            question_id=data.question_id,
            question_text=data.question_text or "",
            options_snapshot=data.options or [],
            correct_option_id=data.correct_option_id,
            correct_option_text=data.correct_option_text,
            formal_explanation=data.formal_explanation,
            informal_explanation=data.informal_explanation,
            correct_answer_explanation=data.correct_answer_explanation,
            question_type=getattr(data, "question_type", None) or "multiple_choice",
            correct_payload=getattr(data, "correct_payload", None),
            mastery_percentage=0.0,
            status="review",
            first_seen_at=data.first_seen_at or data.last_answered_at or now,
            last_seen_at=data.last_answered_at or now,
            created_at=now,
            updated_at=now,
        )
        db.add(item)
        db.flush()
        return item

    item.argument = data.argument or item.argument
    if data.question_text:
        item.question_text = data.question_text
    if data.options:
        item.options_snapshot = data.options
    item.correct_option_id = data.correct_option_id or item.correct_option_id
    item.correct_option_text = data.correct_option_text or item.correct_option_text
    item.formal_explanation = data.formal_explanation or item.formal_explanation
    item.informal_explanation = data.informal_explanation or item.informal_explanation
    item.correct_answer_explanation = data.correct_answer_explanation or item.correct_answer_explanation
    if getattr(data, "question_type", None) and data.question_type != "multiple_choice":
        item.question_type = data.question_type
    if getattr(data, "correct_payload", None):
        item.correct_payload = data.correct_payload
    item.last_seen_at = data.last_answered_at or now
    item.updated_at = now
    return item


def _recompute_item(db: Session, item: StudyPlanItem) -> None:
    contributions = (
        db.query(StudyPlanContribution)
        .join(DeviceSession, DeviceSession.id == StudyPlanContribution.device_session_id)
        .filter(
            StudyPlanContribution.item_id == item.id,
            DeviceSession.contribution_enabled.is_(True),
        )
        .all()
    )
    correct = sum(value.correct_count for value in contributions)
    wrong = sum(value.wrong_count for value in contributions)
    unanswered = sum(value.unanswered_count for value in contributions)
    reviews = sum(value.review_count for value in contributions)
    mastery = _mastery(correct, wrong, unanswered)
    item.mastery_percentage = mastery
    item.status = _status(mastery, wrong, unanswered)
    item.updated_at = utc_now()

    progress = (
        db.query(StudyPlanProgress)
        .filter(StudyPlanProgress.user_id == item.user_id, StudyPlanProgress.item_id == item.id)
        .first()
    )
    if progress is None:
        progress = StudyPlanProgress(user_id=item.user_id, item_id=item.id)
        db.add(progress)

    progress.total_reviews = reviews
    progress.successful_reviews = correct
    progress.consecutive_correct = 1 if contributions and all(c.last_is_correct is True for c in contributions if c.last_is_correct is not None) else 0
    progress.mastery_percentage = mastery
    progress.last_reviewed_at = max(
        (value.last_answered_at for value in contributions if value.last_answered_at is not None),
        default=None,
    )
    progress.completed_at = progress.last_reviewed_at if item.status == "consolidated" else None
    progress.updated_at = utc_now()


def sync_study_plan(db: Session, user: User, request: StudyPlanSyncRequest) -> dict:
    session = _ensure_session(
        db,
        user,
        session_uuid=request.session_uuid,
        device_id=request.device_id,
        device_label=request.device_label,
        source_type=request.source_type,
    )
    imported = 0
    updated = 0
    ignored = 0
    touched: set[int] = set()

    for data in request.contributions:
        item = _ensure_item(db, user.id, data)
        existing = (
            db.query(StudyPlanContribution)
            .filter(StudyPlanContribution.contribution_uuid == data.contribution_uuid)
            .first()
        )
        if existing is not None and existing.item_id != item.id:
            raise ValueError("Identificativo contributo non coerente.")
        if existing is not None and existing.device_session_id != session.id:
            raise ValueError("Il contributo appartiene a una sessione diversa.")
        if existing is not None and data.client_revision < existing.client_revision:
            ignored += 1
            continue

        if existing is None:
            existing = StudyPlanContribution(
                contribution_uuid=data.contribution_uuid,
                item_id=item.id,
                device_session_id=session.id,
                source_type=request.source_type,
                source_user_id=None if request.source_type == "guest" else user.id,
                first_seen_at=data.first_seen_at or data.last_answered_at or utc_now(),
            )
            db.add(existing)
            imported += 1
        else:
            updated += 1

        existing.source_type = request.source_type
        existing.source_user_id = None if request.source_type == "guest" else user.id
        existing.correct_count = data.correct_count
        existing.wrong_count = data.wrong_count
        existing.unanswered_count = data.unanswered_count
        existing.review_count = data.review_count
        existing.last_is_correct = data.last_is_correct
        existing.last_selected_option_id = data.last_selected_option_id
        existing.last_selected_option_text = data.last_selected_option_text
        existing.last_selected_answer_explanation = data.last_selected_answer_explanation
        existing.last_answered_at = data.last_answered_at
        existing.client_revision = data.client_revision
        existing.updated_at = utc_now()
        touched.add(item.id)

    session.last_activity_at = utc_now()
    db.flush()
    for item_id in touched:
        item = db.query(StudyPlanItem).filter(StudyPlanItem.id == item_id).first()
        if item is not None:
            _recompute_item(db, item)

    db.commit()
    return {
        "success": True,
        "session_uuid": session.session_uuid,
        "imported": imported,
        "updated": updated,
        "ignored": ignored,
        "plan": get_study_plan_bootstrap(db, user),
    }


def _materialize_legacy_history(db: Session, user: User) -> None:
    statistics = get_student_question_statistics(db, user.id)
    if not statistics:
        return

    session_uuid = f"server-history-{user.id}"
    session = _ensure_session(
        db,
        user,
        session_uuid=session_uuid,
        device_id="server-history",
        device_label="Storico account",
        source_type="authenticated",
    )
    touched: set[int] = set()

    for stats in statistics:
        data = type("LegacyData", (), {})()
        data.department = str(stats.get("department") or "").strip()
        data.course = str(stats.get("course") or "").strip()
        data.subject = str(stats.get("subject") or "").strip()
        data.argument = stats.get("argument")
        data.question_id = str(stats.get("question_id") or "").strip()
        data.question_text = str(stats.get("question_text") or "")
        data.options = stats.get("options") or []
        data.correct_option_id = stats.get("correct_option_id") or None
        data.correct_option_text = stats.get("correct_option_text") or None
        data.formal_explanation = stats.get("formal_explanation") or None
        data.informal_explanation = stats.get("informal_explanation") or None
        data.correct_answer_explanation = stats.get("correct_answer_explanation") or None
        data.question_type = stats.get("question_type") or "multiple_choice"
        data.correct_payload = stats.get("correct_payload")
        data.first_seen_at = None
        data.last_answered_at = stats.get("last_answered_at")
        if not data.department or not data.course or not data.subject or not data.question_id:
            continue

        item = _ensure_item(db, user.id, data)
        contribution_uuid = f"legacy:{user.id}:{item.id}"
        contribution = (
            db.query(StudyPlanContribution)
            .filter(StudyPlanContribution.contribution_uuid == contribution_uuid)
            .first()
        )
        if contribution is None:
            contribution = StudyPlanContribution(
                contribution_uuid=contribution_uuid,
                item_id=item.id,
                device_session_id=session.id,
                source_type="authenticated",
                source_user_id=user.id,
                first_seen_at=item.first_seen_at,
            )
            db.add(contribution)

        contribution.correct_count = int(stats.get("correct_count") or 0)
        contribution.wrong_count = int(stats.get("wrong_count") or 0)
        contribution.unanswered_count = int(stats.get("unanswered_count") or 0)
        contribution.review_count = int(stats.get("times_seen") or 0)
        contribution.last_is_correct = stats.get("last_is_correct")
        contribution.last_selected_option_id = stats.get("last_selected_option_id")
        contribution.last_selected_option_text = stats.get("last_selected_option_text")
        contribution.last_selected_answer_explanation = stats.get("last_selected_answer_explanation")
        contribution.last_answered_at = stats.get("last_answered_at")
        contribution.client_revision = int(stats.get("times_seen") or 0)
        contribution.updated_at = utc_now()
        touched.add(item.id)

    db.flush()
    for item_id in touched:
        item = db.query(StudyPlanItem).filter(StudyPlanItem.id == item_id).first()
        if item is not None:
            _recompute_item(db, item)
    db.commit()


def _serialize_item(item: StudyPlanItem) -> dict:
    active = [value for value in item.contributions if value.device_session and value.device_session.contribution_enabled]
    correct = sum(value.correct_count for value in active)
    wrong = sum(value.wrong_count for value in active)
    unanswered = sum(value.unanswered_count for value in active)
    reviews = sum(value.review_count for value in active)
    return {
        "id": item.id,
        "department": item.department,
        "course": item.course,
        "subject": item.subject,
        "argument": item.argument,
        "question_id": item.question_id,
        "question_text": item.question_text or "",
        "options": item.options_snapshot or [],
        "correct_option_id": item.correct_option_id,
        "correct_option_text": item.correct_option_text,
        "formal_explanation": item.formal_explanation,
        "informal_explanation": item.informal_explanation,
        "correct_answer_explanation": item.correct_answer_explanation,
        "question_type": getattr(item, "question_type", None) or "multiple_choice",
        "correct_payload": getattr(item, "correct_payload", None),
        "mastery_percentage": item.mastery_percentage or 0.0,
        "status": item.status,
        "first_seen_at": item.first_seen_at,
        "last_seen_at": item.last_seen_at,
        "total_answers": correct + wrong + unanswered,
        "correct_count": correct,
        "wrong_count": wrong,
        "unanswered_count": unanswered,
        "review_count": reviews,
        "source_count": len(active),
        "contributions": [
            {
                "contribution_uuid": value.contribution_uuid,
                "session_uuid": value.device_session.session_uuid,
                "source_type": value.source_type,
                "source_user_id": value.source_user_id,
                "contribution_enabled": value.device_session.contribution_enabled,
                "correct_count": value.correct_count,
                "wrong_count": value.wrong_count,
                "unanswered_count": value.unanswered_count,
                "review_count": value.review_count,
                "last_is_correct": value.last_is_correct,
                "last_selected_option_id": value.last_selected_option_id,
                "last_selected_option_text": value.last_selected_option_text,
                "last_selected_answer_explanation": value.last_selected_answer_explanation,
                "first_seen_at": value.first_seen_at,
                "last_answered_at": value.last_answered_at,
                "client_revision": value.client_revision,
            }
            for value in active
        ],
    }


def get_study_plan_bootstrap(db: Session, user: User) -> dict:
    _materialize_legacy_history(db, user)
    sessions = (
        db.query(DeviceSession)
        .filter(DeviceSession.user_id == user.id)
        .order_by(DeviceSession.last_activity_at.desc())
        .all()
    )
    items = (
        db.query(StudyPlanItem)
        .options(joinedload(StudyPlanItem.contributions).joinedload(StudyPlanContribution.device_session))
        .filter(StudyPlanItem.user_id == user.id)
        .order_by(StudyPlanItem.mastery_percentage.asc(), StudyPlanItem.last_seen_at.desc())
        .all()
    )
    return {
        "user_id": user.id,
        "generated_at": utc_now(),
        "sessions": [
            {
                "session_uuid": value.session_uuid,
                "device_id": value.device_id,
                "device_label": value.device_label,
                "source_type": value.source_type,
                "contribution_enabled": value.contribution_enabled,
                "created_at": value.created_at,
                "last_activity_at": value.last_activity_at,
                "associated_at": value.associated_at,
                "dissociated_at": value.dissociated_at,
                "contribution_count": len(value.contributions),
            }
            for value in sessions
        ],
        "items": [_serialize_item(item) for item in items],
    }


def set_session_contribution_enabled(
    db: Session,
    user: User,
    session_uuid: str,
    enabled: bool,
) -> dict:
    session = (
        db.query(DeviceSession)
        .filter(DeviceSession.user_id == user.id, DeviceSession.session_uuid == session_uuid)
        .first()
    )
    if session is None:
        raise ValueError("Sessione non trovata.")

    session.contribution_enabled = enabled
    session.dissociated_at = None if enabled else utc_now()
    if enabled:
        session.associated_at = utc_now()

    item_ids = [value.item_id for value in session.contributions]
    db.flush()
    for item_id in set(item_ids):
        item = db.query(StudyPlanItem).filter(StudyPlanItem.id == item_id).first()
        if item is not None:
            _recompute_item(db, item)
    db.commit()
    return get_study_plan_bootstrap(db, user)
