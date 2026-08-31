from datetime import datetime, timezone

from sqlalchemy import func, or_
from sqlalchemy.orm import Session, joinedload

from models.group import GroupMember, StudyGroup
from models.quiz_assignment import QuizAssignment, QuizAssignmentRecipient
from models.quiz_attempt import QuizAttempt
from models.subject import Subject
from models.teacher_assignment import TeacherAssignment
from models.user import User
from schemas.quiz_assignment import QuizAssignmentCreate, QuizAssignmentUpdate
from services.notification import create_notification
from services.quiz_service import find_question, question_count


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _as_utc(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def get_quiz_assignment_by_id(db: Session, assignment_id: int) -> QuizAssignment | None:
    return (
        db.query(QuizAssignment)
        .options(joinedload(QuizAssignment.recipients))
        .filter(QuizAssignment.id == assignment_id)
        .first()
    )


def _get_subject(db: Session, department: str, course: str, subject: str) -> Subject | None:
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


def _require_teacher_subject(db: Session, actor: User, subject_record: Subject) -> None:
    if actor.role in {"admin", "creator"}:
        return
    if actor.role != "teacher":
        raise PermissionError("Solo i docenti verificati possono assegnare quiz.")
    if actor.teacher_verification_status != "verified":
        raise PermissionError("Il profilo docente non è verificato.")
    row = (
        db.query(TeacherAssignment)
        .filter(
            TeacherAssignment.user_id == actor.id,
            TeacherAssignment.subject_id == subject_record.id,
            TeacherAssignment.verification_status == "verified",
            TeacherAssignment.is_current.is_(True),
        )
        .first()
    )
    if row is None:
        raise PermissionError("Non sei autorizzato ad assegnare quiz per questa materia.")


def _require_recipient_user(db: Session, user_id: int) -> User:
    user = db.query(User).filter(User.id == user_id, User.is_active.is_(True)).first()
    if user is None:
        raise ValueError(f"Utente destinatario {user_id} non trovato o non attivo.")
    return user


def _require_group(db: Session, group_id: int) -> StudyGroup:
    group = db.query(StudyGroup).filter(StudyGroup.id == group_id).first()
    if group is None:
        raise ValueError(f"Gruppo {group_id} non trovato.")
    return group


def _teacher_can_assign_to_group(db: Session, actor: User, group_id: int) -> bool:
    if actor.role in {"admin", "creator"}:
        return True
    member = (
        db.query(GroupMember)
        .filter(GroupMember.group_id == group_id, GroupMember.user_id == actor.id)
        .first()
    )
    return member is not None and member.role in {"owner", "admin"}


def _validate_configuration(
    department: str,
    course: str,
    subject: str,
    selection_mode: str,
    arguments: list[str],
    question_ids: list[int],
    question_count_value: int,
) -> None:
    if selection_mode not in {"random", "arguments", "selected_questions"}:
        raise ValueError("Modalità di selezione delle domande non valida.")
    if selection_mode == "selected_questions":
        if not question_ids:
            raise ValueError("Devi selezionare almeno una domanda.")
        if len(question_ids) != len(set(question_ids)):
            raise ValueError("La stessa domanda non può essere selezionata più volte.")
        for question_id in question_ids:
            if find_question(
                id_question=question_id,
                department=department,
                course=course,
                subject=subject,
                include_hidden=False,
            ) is None:
                raise ValueError(f"La domanda {question_id} non è disponibile.")
        return
    selected_arguments = arguments if selection_mode == "arguments" else []
    if selection_mode == "arguments" and not selected_arguments:
        raise ValueError("Devi selezionare almeno un argomento.")
    if question_count_value <= 0:
        raise ValueError("Il numero di domande deve essere maggiore di zero.")
    available = question_count(
        department=department,
        course=course,
        subject=subject,
        selected_arguments=selected_arguments,
    )
    if available <= 0:
        raise ValueError("Non ci sono domande disponibili per questa configurazione.")
    if question_count_value > available:
        raise ValueError(f"Il numero massimo di domande disponibili è {available}.")


def _normalize_ids(values: list[int]) -> list[int]:
    return list(dict.fromkeys(int(value) for value in values))


def _validate_recipients(db: Session, actor: User, user_ids: list[int], group_ids: list[int]) -> None:
    if not user_ids and not group_ids:
        raise ValueError("Devi specificare almeno un destinatario o un gruppo.")
    for user_id in user_ids:
        _require_recipient_user(db, user_id)
    for group_id in group_ids:
        _require_group(db, group_id)
        if not _teacher_can_assign_to_group(db, actor, group_id):
            raise PermissionError(f"Non puoi assegnare quiz al gruppo {group_id}.")


def _effective_user_ids(db: Session, user_ids: list[int], group_ids: list[int]) -> set[int]:
    result = set(user_ids)
    if group_ids:
        rows = (
            db.query(GroupMember.user_id)
            .join(User, User.id == GroupMember.user_id)
            .filter(GroupMember.group_id.in_(group_ids), User.is_active.is_(True))
            .distinct()
            .all()
        )
        result.update(int(row[0]) for row in rows)
    return result


def _notify(db: Session, assignment: QuizAssignment, actor: User, user_ids: set[int]) -> None:
    actor_name = " ".join(
        value.strip()
        for value in [actor.first_name or "", actor.last_name or ""]
        if value and value.strip()
    ) or "Un docente"
    mode_label = "simulazione" if assignment.execution_mode == "simulation" else "esercitazione"
    for user_id in sorted(user_ids):
        create_notification(
            db=db,
            user_id=user_id,
            notification_type="quiz_assignment",
            title="Nuovo quiz assegnato",
            message=f'{actor_name} ti ha assegnato "{assignment.title}" per {assignment.subject} in modalità {mode_label}.',
            actor_user_id=actor.id,
            resource_type="quiz_assignment",
            resource_id=assignment.id,
            action_type=None,
            action_resource_id=None,
            action_status="none",
            expires_at=assignment.due_at,
            commit=False,
        )


def _has_attempts(db: Session, assignment_id: int) -> bool:
    return (
        db.query(QuizAttempt.id)
        .filter(QuizAttempt.assignment_id == assignment_id, QuizAttempt.is_deleted.is_(False))
        .first()
        is not None
    )


def _replace_recipients(db: Session, assignment: QuizAssignment, user_ids: list[int], group_ids: list[int]) -> None:
    (
        db.query(QuizAssignmentRecipient)
        .filter(QuizAssignmentRecipient.assignment_id == assignment.id)
        .delete(synchronize_session=False)
    )
    for user_id in user_ids:
        db.add(QuizAssignmentRecipient(assignment_id=assignment.id, user_id=user_id, group_id=None))
    for group_id in group_ids:
        db.add(QuizAssignmentRecipient(assignment_id=assignment.id, user_id=None, group_id=group_id))


def create_quiz_assignment(db: Session, actor: User, data: QuizAssignmentCreate) -> QuizAssignment:
    subject_record = _get_subject(db, data.department, data.course, data.subject)
    if subject_record is None:
        raise ValueError("Materia non trovata.")
    _require_teacher_subject(db, actor, subject_record)
    _validate_configuration(
        data.department,
        data.course,
        data.subject,
        data.selection_mode,
        list(data.arguments),
        list(data.question_ids),
        data.question_count,
    )
    user_ids = _normalize_ids(list(data.user_ids))
    group_ids = _normalize_ids(list(data.group_ids))
    _validate_recipients(db, actor, user_ids, group_ids)
    due_at = _as_utc(data.due_at)
    if due_at is not None and due_at <= utc_now():
        raise ValueError("La scadenza deve essere futura.")
    assignment = QuizAssignment(
        teacher_id=actor.id,
        subject_id=subject_record.id,
        department=data.department.strip(),
        course=data.course.strip(),
        subject=data.subject.strip(),
        title=data.title.strip(),
        description=data.description.strip() if data.description and data.description.strip() else None,
        selection_mode=data.selection_mode,
        execution_mode=data.execution_mode,
        external_activity_policy=data.external_activity_policy,
        selected_arguments=list(data.arguments) if data.selection_mode == "arguments" else [],
        selected_question_ids=list(data.question_ids) if data.selection_mode == "selected_questions" else [],
        question_count=len(data.question_ids) if data.selection_mode == "selected_questions" else data.question_count,
        time_limit_seconds=data.time_limit_seconds,
        due_at=due_at,
        is_active=True,
    )
    try:
        db.add(assignment)
        db.flush()
        _replace_recipients(db, assignment, user_ids, group_ids)
        _notify(db, assignment, actor, _effective_user_ids(db, user_ids, group_ids))
        db.commit()
        db.refresh(assignment)
    except Exception:
        db.rollback()
        raise
    return get_quiz_assignment_by_id(db, assignment.id)


def update_quiz_assignment(
    db: Session,
    assignment: QuizAssignment,
    actor: User,
    data: QuizAssignmentUpdate,
) -> QuizAssignment:
    if actor.role not in {"admin", "creator"} and assignment.teacher_id != actor.id:
        raise PermissionError("Non puoi modificare questa assegnazione.")

    values = data.model_dump(exclude_unset=True)
    user_ids = values.pop("user_ids", None)
    group_ids = values.pop("group_ids", None)

    structural_fields = {
        "department", "course", "subject", "selection_mode", "execution_mode", "external_activity_policy",
        "arguments", "question_ids", "question_count", "time_limit_seconds",
    }
    if _has_attempts(db, assignment.id) and structural_fields.intersection(values):
        raise ValueError("Non puoi modificare struttura, modalità o tempo del quiz dopo l'avvio di un tentativo.")

    if "due_at" in values:
        values["due_at"] = _as_utc(values["due_at"])
        if values["due_at"] is not None and values["due_at"] <= utc_now():
            raise ValueError("La scadenza deve essere futura.")

    if "title" in values and values["title"] is not None:
        values["title"] = values["title"].strip()
    if "description" in values:
        values["description"] = values["description"].strip() if values["description"] else None

    if any(key in values for key in {"selection_mode", "arguments", "question_ids", "question_count"}):
        selection_mode = values.get("selection_mode", assignment.selection_mode)
        arguments = values.get("arguments", assignment.selected_arguments or [])
        question_ids = values.get("question_ids", assignment.selected_question_ids or [])
        count = values.get("question_count", assignment.question_count)
        _validate_configuration(
            assignment.department,
            assignment.course,
            assignment.subject,
            selection_mode,
            list(arguments or []),
            list(question_ids or []),
            count,
        )
        values["selected_arguments"] = list(arguments or []) if selection_mode == "arguments" else []
        values["selected_question_ids"] = list(question_ids or []) if selection_mode == "selected_questions" else []
        values.pop("arguments", None)
        values.pop("question_ids", None)
        if selection_mode == "selected_questions":
            values["question_count"] = len(values["selected_question_ids"])

    if user_ids is not None or group_ids is not None:
        current_users = [r.user_id for r in assignment.recipients if r.user_id is not None]
        current_groups = [r.group_id for r in assignment.recipients if r.group_id is not None]
        normalized_users = _normalize_ids(list(user_ids if user_ids is not None else current_users))
        normalized_groups = _normalize_ids(list(group_ids if group_ids is not None else current_groups))
        _validate_recipients(db, actor, normalized_users, normalized_groups)
        _replace_recipients(db, assignment, normalized_users, normalized_groups)

    for field, value in values.items():
        setattr(assignment, field, value)

    try:
        db.commit()
        db.refresh(assignment)
    except Exception:
        db.rollback()
        raise
    return get_quiz_assignment_by_id(db, assignment.id)


def deactivate_quiz_assignment(db: Session, assignment: QuizAssignment, actor: User) -> QuizAssignment:
    if actor.role not in {"admin", "creator"} and assignment.teacher_id != actor.id:
        raise PermissionError("Non puoi disattivare questa assegnazione.")
    assignment.is_active = False
    try:
        db.commit()
        db.refresh(assignment)
    except Exception:
        db.rollback()
        raise
    return assignment


def delete_quiz_assignment(db: Session, assignment: QuizAssignment, actor: User) -> None:
    if actor.role not in {"admin", "creator"} and assignment.teacher_id != actor.id:
        raise PermissionError("Non puoi eliminare questa assegnazione.")
    if _has_attempts(db, assignment.id):
        assignment.is_active = False
        db.commit()
        return
    try:
        db.delete(assignment)
        db.commit()
    except Exception:
        db.rollback()
        raise


def get_teacher_quiz_assignments(db: Session, actor: User) -> list[QuizAssignment]:
    query = db.query(QuizAssignment).options(joinedload(QuizAssignment.recipients))
    if actor.role not in {"admin", "creator"}:
        query = query.filter(QuizAssignment.teacher_id == actor.id)
    return query.order_by(QuizAssignment.created_at.desc(), QuizAssignment.id.desc()).all()


def _get_user_group_ids(db: Session, user_id: int) -> list[int]:
    return [int(row[0]) for row in db.query(GroupMember.group_id).filter(GroupMember.user_id == user_id).all()]


def can_user_access_quiz_assignment(db: Session, assignment_id: int, user_id: int) -> bool:
    direct = (
        db.query(QuizAssignmentRecipient)
        .filter(
            QuizAssignmentRecipient.assignment_id == assignment_id,
            QuizAssignmentRecipient.user_id == user_id,
        )
        .first()
    )
    if direct is not None:
        return True
    group_ids = _get_user_group_ids(db, user_id)
    if not group_ids:
        return False
    return (
        db.query(QuizAssignmentRecipient)
        .filter(
            QuizAssignmentRecipient.assignment_id == assignment_id,
            QuizAssignmentRecipient.group_id.in_(group_ids),
        )
        .first()
        is not None
    )


def get_user_quiz_assignments(db: Session, user_id: int) -> list[dict]:
    user = _require_recipient_user(db, user_id)
    group_ids = _get_user_group_ids(db, user.id)
    filters = [QuizAssignmentRecipient.user_id == user.id]
    if group_ids:
        filters.append(QuizAssignmentRecipient.group_id.in_(group_ids))
    assignments = (
        db.query(QuizAssignment)
        .join(QuizAssignmentRecipient, QuizAssignmentRecipient.assignment_id == QuizAssignment.id)
        .options(joinedload(QuizAssignment.recipients))
        .filter(QuizAssignment.is_active.is_(True), or_(*filters))
        .distinct()
        .order_by(QuizAssignment.due_at.asc(), QuizAssignment.created_at.desc())
        .all()
    )
    now = utc_now()
    result = []
    for assignment in assignments:
        attempt = (
            db.query(QuizAttempt)
            .filter(
                QuizAttempt.assignment_id == assignment.id,
                QuizAttempt.user_id == user.id,
                QuizAttempt.is_deleted.is_(False),
            )
            .first()
        )
        expired = assignment.due_at is not None and assignment.due_at <= now
        completed = attempt is not None and attempt.status == "completed"
        in_progress = attempt is not None and attempt.status == "in_progress"
        result.append({
            "id": assignment.id,
            "teacher_id": assignment.teacher_id,
            "subject_id": assignment.subject_id,
            "department": assignment.department,
            "course": assignment.course,
            "subject": assignment.subject,
            "title": assignment.title,
            "description": assignment.description,
            "selection_mode": assignment.selection_mode,
            "execution_mode": assignment.execution_mode,
            "external_activity_policy": assignment.external_activity_policy,
            "selected_arguments": assignment.selected_arguments or [],
            "selected_question_ids": assignment.selected_question_ids or [],
            "question_count": assignment.question_count,
            "time_limit_seconds": assignment.time_limit_seconds,
            "due_at": assignment.due_at,
            "is_active": assignment.is_active,
            "created_at": assignment.created_at,
            "updated_at": assignment.updated_at,
            "recipients": assignment.recipients,
            "is_expired": expired,
            "can_start": not expired and attempt is None,
            "attempt_id": attempt.id if attempt is not None else None,
            "is_completed": completed,
            "is_in_progress": in_progress,
        })
    return result



def get_student_quiz_assignments(
    db: Session,
    user_id: int,
) -> list[dict]:
    return get_user_quiz_assignments(
        db=db,
        user_id=user_id,
    )

def get_quiz_assignment_results(db: Session, assignment: QuizAssignment, actor: User) -> list[QuizAttempt]:
    if actor.role not in {"admin", "creator"} and assignment.teacher_id != actor.id:
        raise PermissionError("Non puoi visualizzare i risultati di questa assegnazione.")
    return (
        db.query(QuizAttempt)
        .filter(QuizAttempt.assignment_id == assignment.id, QuizAttempt.is_deleted.is_(False))
        .order_by(QuizAttempt.completed_at.desc().nullslast(), QuizAttempt.started_at.desc())
        .all()
    )