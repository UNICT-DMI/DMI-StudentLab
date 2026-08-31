import random
from copy import deepcopy
from datetime import datetime, timezone

from sqlalchemy.orm import Session, joinedload

from models.quiz_attempt import QuizAttempt, QuizAttemptAnswer
from models.user import User
from schemas.quiz_attempt import QuizAttemptStart, QuizAttemptSubmit
from services.quiz_assignment_service import can_user_access_quiz_assignment, get_quiz_assignment_by_id
from services.quiz_service import find_question, question_count, shuffle_filter


def utc_now():
    return datetime.now(timezone.utc)


def _metadata(question: dict) -> dict:
    value = question.get("metadata", {})
    return value if isinstance(value, dict) else {}


def _attachments(question: dict) -> list[dict]:
    value = question.get("attachments", [])
    return [item for item in value if isinstance(item, dict)] if isinstance(value, list) else []


def _options(question: dict) -> list[dict]:
    value = question.get("option", [])
    return [item for item in value if isinstance(item, dict)] if isinstance(value, list) else []


def _option_text(question: dict, option_id: str | None) -> str | None:
    if option_id is None:
        return None
    for option in _options(question):
        if str(option.get("id")) == str(option_id):
            return str(option.get("text", ""))
    return None


def _snapshot(question: dict) -> dict:
    result = deepcopy(question)
    result["metadata"] = deepcopy(_metadata(question))
    result["attachments"] = deepcopy(_attachments(question))
    options = deepcopy(_options(question))
    random.shuffle(options)
    result["option"] = options
    return result


def _public_question(question: dict) -> dict:
    return {
        "id_question": str(question.get("id_question")),
        "estimed_time": question.get("estimed_time"),
        "metadata": _metadata(question),
        "text": str(question.get("text", "")),
        "attachments": _attachments(question),
        "option": _options(question),
    }


def _snapshot_question(attempt: QuizAttempt, question_id: str) -> dict | None:
    snapshots = attempt.questions_snapshot or []
    if not isinstance(snapshots, list):
        return None
    for question in snapshots:
        if isinstance(question, dict) and str(question.get("id_question")) == str(question_id):
            return question
    return None


def get_quiz_attempt_by_id(db: Session, attempt_id: int) -> QuizAttempt | None:
    return (
        db.query(QuizAttempt)
        .options(joinedload(QuizAttempt.answers))
        .filter(QuizAttempt.id == attempt_id)
        .first()
    )


def _public_attempt(attempt: QuizAttempt) -> dict:
    snapshots = attempt.questions_snapshot or []
    return {
        "attempt_id": attempt.id,
        "assignment_id": attempt.assignment_id,
        "department": attempt.department,
        "course": attempt.course,
        "subject": attempt.subject,
        "arguments": attempt.selected_arguments or [],
        "question_count": attempt.question_count,
        "time_limit_seconds": attempt.time_limit_seconds,
        "execution_mode": attempt.execution_mode,
        "external_activity_policy": attempt.external_activity_policy,
        "interruption_count": attempt.interruption_count,
        "started_at": attempt.started_at,
        "questions": [_public_question(q) for q in snapshots if isinstance(q, dict)],
    }


def _create_quiz_attempt(
    db: Session,
    user: User,
    *,
    department: str,
    course: str,
    subject: str,
    questions: list[dict],
    time_limit_seconds: int | None,
    assignment_id: int | None = None,
    execution_mode: str = "practice",
    external_activity_policy: str = "disabled",
):
    if not questions:
        raise ValueError("Il quiz non contiene domande.")

    snapshots = [_snapshot(question) for question in questions]
    question_ids = [str(question.get("id_question")) for question in snapshots]
    arguments: list[str] = []

    for question in snapshots:
        argument = _metadata(question).get("argoment")
        if isinstance(argument, str):
            value = argument.strip()
            if value and value not in arguments:
                arguments.append(value)

    attempt = QuizAttempt(
        user_id=user.id,
        assignment_id=assignment_id,
        department=department,
        course=course,
        subject=subject,
        selected_arguments=arguments,
        question_ids=question_ids,
        questions_snapshot=snapshots,
        question_count=len(snapshots),
        correct_count=0,
        wrong_count=0,
        unanswered_count=len(snapshots),
        percentage=0.0,
        time_limit_seconds=time_limit_seconds,
        elapsed_seconds=None,
        execution_mode=execution_mode,
        external_activity_policy=external_activity_policy,
        completion_reason=None,
        interruption_count=0,
        last_interrupted_at=None,
        status="in_progress",
        started_at=utc_now(),
        completed_at=None,
        is_hidden_from_history=False,
        is_deleted=False,
    )

    try:
        db.add(attempt)
        db.commit()
        db.refresh(attempt)
    except Exception:
        db.rollback()
        raise

    return _public_attempt(attempt)


def start_quiz_attempt(db: Session, user: User, data: QuizAttemptStart):
    selected_arguments = [] if data.all_arguments else data.arguments
    available = question_count(
        department=data.department,
        course=data.course,
        subject=data.subject,
        selected_arguments=selected_arguments,
    )

    if available <= 0:
        raise ValueError("Non ci sono domande disponibili per i filtri selezionati.")
    if data.number_of_questions > available:
        raise ValueError(f"Il numero massimo di domande disponibili è {available}.")

    questions = shuffle_filter(
        department=data.department,
        course=data.course,
        subject=data.subject,
        selected_arguments=selected_arguments,
        number_of_questions=data.number_of_questions,
    )

    if len(questions) != data.number_of_questions:
        raise ValueError("Non è stato possibile generare il numero richiesto di domande.")

    return _create_quiz_attempt(
        db,
        user,
        department=data.department,
        course=data.course,
        subject=data.subject,
        questions=questions,
        time_limit_seconds=data.time_limit_seconds,
        execution_mode="practice",
        external_activity_policy="disabled",
    )


def start_assigned_quiz_attempt(db: Session, user: User, assignment_id: int):
    assignment = get_quiz_assignment_by_id(db, assignment_id)

    if assignment is None:
        raise ValueError("Assegnazione non trovata.")
    if not assignment.is_active:
        raise ValueError("Questa assegnazione non è più attiva.")
    if assignment.due_at is not None and assignment.due_at <= utc_now():
        raise ValueError("Questa assegnazione è scaduta.")
    if not can_user_access_quiz_assignment(db, assignment.id, user.id):
        raise PermissionError("Non puoi svolgere questa assegnazione.")

    existing = (
        db.query(QuizAttempt)
        .filter(
            QuizAttempt.user_id == user.id,
            QuizAttempt.assignment_id == assignment.id,
            QuizAttempt.is_deleted.is_(False),
        )
        .first()
    )

    if existing is not None:
        if existing.status == "completed":
            raise ValueError("Hai già completato questo quiz assegnato.")
        return _public_attempt(existing)

    if assignment.selection_mode == "selected_questions":
        questions = []
        for question_id in assignment.selected_question_ids or []:
            question = find_question(
                id_question=str(question_id),
                department=assignment.department,
                course=assignment.course,
                subject=assignment.subject,
                include_hidden=False,
            )
            if question is None:
                raise ValueError(f"La domanda {question_id} non è più disponibile.")
            questions.append(question)
    else:
        selected_arguments = assignment.selected_arguments or [] if assignment.selection_mode == "arguments" else []
        available = question_count(
            department=assignment.department,
            course=assignment.course,
            subject=assignment.subject,
            selected_arguments=selected_arguments,
        )
        if available < assignment.question_count:
            raise ValueError("Non ci sono più abbastanza domande disponibili per questo quiz.")
        questions = shuffle_filter(
            department=assignment.department,
            course=assignment.course,
            subject=assignment.subject,
            selected_arguments=selected_arguments,
            number_of_questions=assignment.question_count,
        )

    if len(questions) != assignment.question_count:
        raise ValueError("Non è stato possibile generare il quiz assegnato.")

    return _create_quiz_attempt(
        db,
        user,
        assignment_id=assignment.id,
        department=assignment.department,
        course=assignment.course,
        subject=assignment.subject,
        questions=questions,
        time_limit_seconds=assignment.time_limit_seconds,
        execution_mode=assignment.execution_mode,
        external_activity_policy=assignment.external_activity_policy,
    )


def resume_quiz_attempt(db: Session, user: User, attempt_id: int):
    attempt = get_quiz_attempt_by_id(db, attempt_id)

    if attempt is None or attempt.is_deleted:
        raise ValueError("Tentativo non trovato.")
    if attempt.user_id != user.id:
        raise PermissionError("Non puoi accedere a questo tentativo.")
    if attempt.status != "in_progress":
        raise ValueError("Questo tentativo non è più in corso.")

    if attempt.time_limit_seconds is not None:
        elapsed = int((utc_now() - attempt.started_at).total_seconds())
        if elapsed >= attempt.time_limit_seconds:
            return complete_quiz_attempt(
                db,
                user,
                attempt.id,
                QuizAttemptSubmit(
                    answers=[],
                    elapsed_seconds=elapsed,
                    completion_reason="time_expired",
                    interruption_count=attempt.interruption_count,
                ),
            )

    return _public_attempt(attempt)


def complete_quiz_attempt(db: Session, user: User, attempt_id: int, data: QuizAttemptSubmit):
    attempt = get_quiz_attempt_by_id(db, attempt_id)

    if attempt is None or attempt.is_deleted:
        raise ValueError("Tentativo non trovato.")
    if attempt.user_id != user.id:
        raise PermissionError("Non puoi completare questo tentativo.")
    if attempt.status == "completed":
        return attempt

    submitted = {str(answer.question_id): answer for answer in data.answers}
    saved_answers: list[QuizAttemptAnswer] = []
    correct_count = 0
    wrong_count = 0
    unanswered_count = 0

    for question_id in attempt.question_ids or []:
        question = _snapshot_question(attempt, str(question_id))
        if question is None:
            raise ValueError(f"Snapshot della domanda {question_id} non disponibile.")

        answer = submitted.get(str(question_id))
        selected_option_id = answer.selected_option_id if answer is not None else None
        response_time_seconds = answer.response_time_seconds if answer is not None else None
        correct_option_id = str(question.get("id_correct", ""))
        selected_option_text = _option_text(question, selected_option_id)
        correct_option_text = _option_text(question, correct_option_id) or ""
        is_answered = selected_option_id is not None and selected_option_text is not None
        is_correct = is_answered and str(selected_option_id) == correct_option_id

        if is_correct:
            correct_count += 1
        elif is_answered:
            wrong_count += 1
        else:
            unanswered_count += 1

        explanations = question.get("question_response_explanation", {})
        if not isinstance(explanations, dict):
            explanations = {}

        argument = _metadata(question).get("argoment")
        if not isinstance(argument, str):
            argument = None

        saved_answers.append(
            QuizAttemptAnswer(
                attempt_id=attempt.id,
                question_id=str(question_id),
                argument=argument,
                question_text=str(question.get("text", "")),
                attachments_snapshot=deepcopy(_attachments(question)),
                options_snapshot=deepcopy(_options(question)),
                selected_option_id=selected_option_id,
                selected_option_text=selected_option_text,
                correct_option_id=correct_option_id,
                correct_option_text=correct_option_text,
                is_answered=is_answered,
                is_correct=is_correct,
                response_time_seconds=response_time_seconds,
                formal_explanation=question.get("formal_explanation"),
                informal_explanation=question.get("informal_explanation"),
                selected_answer_explanation=explanations.get(selected_option_id) if selected_option_id else None,
                correct_answer_explanation=explanations.get(correct_option_id),
            )
        )

    percentage = (correct_count / attempt.question_count) * 100 if attempt.question_count > 0 else 0.0
    real_elapsed = max(0, int((utc_now() - attempt.started_at).total_seconds()))
    requested_elapsed = max(0, data.elapsed_seconds)
    elapsed = max(real_elapsed, requested_elapsed)

    if attempt.time_limit_seconds is not None:
        elapsed = min(elapsed, attempt.time_limit_seconds)
        if real_elapsed >= attempt.time_limit_seconds and data.completion_reason == "completed":
            data.completion_reason = "time_expired"

    attempt.correct_count = correct_count
    attempt.wrong_count = wrong_count
    attempt.unanswered_count = unanswered_count
    attempt.percentage = round(percentage, 2)
    attempt.elapsed_seconds = elapsed
    attempt.completion_reason = data.completion_reason
    attempt.interruption_count = max(attempt.interruption_count or 0, data.interruption_count)
    attempt.status = "completed"
    attempt.completed_at = utc_now()

    try:
        db.query(QuizAttemptAnswer).filter(QuizAttemptAnswer.attempt_id == attempt.id).delete(synchronize_session=False)
        db.add_all(saved_answers)
        db.commit()
        db.refresh(attempt)
    except Exception:
        db.rollback()
        raise

    return get_quiz_attempt_by_id(db, attempt.id)


def register_attempt_interruption(db: Session, user: User, attempt_id: int):
    attempt = get_quiz_attempt_by_id(db, attempt_id)
    if attempt is None or attempt.is_deleted:
        raise ValueError("Tentativo non trovato.")
    if attempt.user_id != user.id:
        raise PermissionError("Non puoi modificare questo tentativo.")
    if attempt.status != "in_progress":
        return attempt

    attempt.interruption_count = (attempt.interruption_count or 0) + 1
    attempt.last_interrupted_at = utc_now()

    try:
        db.commit()
        db.refresh(attempt)
    except Exception:
        db.rollback()
        raise

    return attempt


def get_student_quiz_history(
    db: Session,
    user_id: int,
    *,
    include_hidden: bool = False,
    limit: int = 50,
    offset: int = 0,
):
    safe_limit = max(1, min(limit, 100))
    safe_offset = max(0, offset)

    query = db.query(QuizAttempt).filter(
        QuizAttempt.user_id == user_id,
        QuizAttempt.status == "completed",
        QuizAttempt.is_deleted.is_(False),
    )

    if not include_hidden:
        query = query.filter(QuizAttempt.is_hidden_from_history.is_(False))

    return {
        "total": query.count(),
        "attempts": (
            query.order_by(QuizAttempt.completed_at.desc(), QuizAttempt.id.desc())
            .offset(safe_offset)
            .limit(safe_limit)
            .all()
        ),
    }


def hide_quiz_attempt_from_history(db: Session, attempt: QuizAttempt, actor: User):
    if attempt.is_deleted:
        raise ValueError("Tentativo non trovato.")
    attempt.is_hidden_from_history = True
    attempt.hidden_from_history_at = utc_now()
    attempt.hidden_from_history_by = actor.id
    db.commit()
    db.refresh(attempt)
    return attempt


def restore_quiz_attempt_to_history(db: Session, attempt: QuizAttempt):
    if attempt.is_deleted:
        raise ValueError("Tentativo non trovato.")
    attempt.is_hidden_from_history = False
    attempt.hidden_from_history_at = None
    attempt.hidden_from_history_by = None
    db.commit()
    db.refresh(attempt)
    return attempt


def delete_quiz_attempt(db: Session, attempt: QuizAttempt, actor: User):
    if attempt.is_deleted:
        return attempt
    now = utc_now()
    attempt.is_deleted = True
    attempt.deleted_at = now
    attempt.deleted_by = actor.id
    attempt.is_hidden_from_history = True
    attempt.hidden_from_history_at = attempt.hidden_from_history_at or now
    attempt.hidden_from_history_by = attempt.hidden_from_history_by or actor.id
    db.commit()
    db.refresh(attempt)
    return attempt