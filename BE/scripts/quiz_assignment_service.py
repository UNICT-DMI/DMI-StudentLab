from datetime import (
    datetime,
    timezone,
)

from sqlalchemy import (
    or_,
)

from sqlalchemy.orm import (
    Session,
    joinedload,
)

from models.group import (
    GroupMember,
    StudyGroup,
)

from models.quiz_assignment import (
    QuizAssignment,
    QuizAssignmentRecipient,
)

from models.subject import (
    Subject,
)

from models.teacher_assignment import (
    TeacherAssignment,
)

from models.user import (
    User,
)

from schemas.quiz_assignment import (
    QuizAssignmentCreate,
    QuizAssignmentUpdate,
)

from services.quiz_service import (
    find_question,
    question_count,
)


def utc_now():
    return datetime.now(
        timezone.utc,
    )


def get_assignment_by_id(
    db: Session,
    assignment_id: int,
):
    return (
        db.query(
            QuizAssignment
        )
        .options(
            joinedload(
                QuizAssignment.recipients
            )
        )
        .filter(
            QuizAssignment.id
            ==
            assignment_id,
        )
        .first()
    )


def get_assignment_subject(
    db: Session,
    department: str,
    course: str,
    subject: str,
):
    return (
        db.query(
            Subject
        )
        .filter(
            Subject.department_code
            .ilike(
                department.strip()
            ),
            Subject.course_code
            .ilike(
                course.strip()
            ),
            Subject.name
            .ilike(
                subject.strip()
            ),
            Subject.is_active.is_(
                True
            ),
        )
        .first()
    )


def require_teacher_subject(
    db: Session,
    actor: User,
    subject_record: Subject,
):
    if actor.role in {
        "admin",
        "creator",
    }:
        return

    if (
        actor.role != "teacher"
        or actor.teacher_verification_status
        != "verified"
    ):
        raise PermissionError(
            "Non puoi assegnare quiz."
        )

    assignment = (
        db.query(
            TeacherAssignment
        )
        .filter(
            TeacherAssignment.user_id
            ==
            actor.id,

            TeacherAssignment.subject_id
            ==
            subject_record.id,

            TeacherAssignment.verification_status
            ==
            "verified",

            TeacherAssignment.is_current.is_(
                True
            ),
        )
        .first()
    )

    if assignment is None:
        raise PermissionError(
            "Non sei autorizzato ad assegnare quiz per questa materia."
        )


def require_valid_student(
    db: Session,
    user_id: int,
):
    user = (
        db.query(
            User
        )
        .filter(
            User.id
            ==
            user_id,

            User.is_active.is_(
                True
            ),
        )
        .first()
    )

    if user is None:
        raise ValueError(
            f"Studente {user_id} non trovato."
        )

    return user


def require_valid_group(
    db: Session,
    actor: User,
    group_id: int,
):
    group = (
        db.query(
            StudyGroup
        )
        .filter(
            StudyGroup.id
            ==
            group_id,

            StudyGroup.status
            ==
            "active",
        )
        .first()
    )

    if group is None:
        raise ValueError(
            f"Gruppo {group_id} non trovato."
        )

    if actor.role in {
        "admin",
        "creator",
    }:
        return group

    membership = (
        db.query(
            GroupMember
        )
        .filter(
            GroupMember.group_id
            ==
            group_id,

            GroupMember.user_id
            ==
            actor.id,
        )
        .first()
    )

    if (
        membership is None
        or membership.role
        not in {
            "owner",
            "admin",
        }
    ):
        raise PermissionError(
            "Puoi assegnare quiz soltanto ai gruppi che gestisci."
        )

    return group


def validate_assignment_questions(
    data: QuizAssignmentCreate,
):
    selected_arguments = (
        data.arguments
        if data.selection_mode
        == "arguments"
        else []
    )

    if (
        data.selection_mode
        in {
            "random",
            "arguments",
        }
    ):
        available = question_count(
            department=(
                data.department
            ),
            course=(
                data.course
            ),
            subject=(
                data.subject
            ),
            selected_arguments=(
                selected_arguments
            ),
        )

        if available <= 0:
            raise ValueError(
                "Non ci sono domande disponibili per questa configurazione."
            )

        if (
            data.question_count
            >
            available
        ):
            raise ValueError(
                f"Il numero massimo di domande disponibili è {available}."
            )

        return

    for question_id in (
        data.question_ids
    ):
        question = find_question(
            id_question=(
                question_id
            ),
            department=(
                data.department
            ),
            course=(
                data.course
            ),
            subject=(
                data.subject
            ),
            include_hidden=False,
        )

        if question is None:
            raise ValueError(
                f"La domanda {question_id} non è disponibile."
            )


def create_quiz_assignment(
    db: Session,
    actor: User,
    data: QuizAssignmentCreate,
):
    subject_record = (
        get_assignment_subject(
            db,
            data.department,
            data.course,
            data.subject,
        )
    )

    if subject_record is None:
        raise ValueError(
            "Materia non trovata."
        )

    require_teacher_subject(
        db,
        actor,
        subject_record,
    )

    validate_assignment_questions(
        data
    )

    for user_id in data.user_ids:
        require_valid_student(
            db,
            user_id,
        )

    for group_id in data.group_ids:
        require_valid_group(
            db,
            actor,
            group_id,
        )

    assignment = QuizAssignment(
        teacher_id=(
            actor.id
        ),

        subject_id=(
            subject_record.id
        ),

        department=(
            data.department
        ),

        course=(
            data.course
        ),

        subject=(
            data.subject
        ),

        title=(
            data.title
        ),

        description=(
            data.description
        ),

        selection_mode=(
            data.selection_mode
        ),

        selected_arguments=(
            data.arguments
            if data.selection_mode
            == "arguments"
            else []
        ),

        selected_question_ids=(
            data.question_ids
            if data.selection_mode
            == "selected_questions"
            else []
        ),

        question_count=(
            data.question_count
        ),

        time_limit_seconds=(
            data.time_limit_seconds
        ),

        due_at=(
            data.due_at
        ),

        is_active=True,
    )

    try:
        db.add(
            assignment
        )

        db.flush()

        for user_id in (
            data.user_ids
        ):
            db.add(
                QuizAssignmentRecipient(
                    assignment_id=(
                        assignment.id
                    ),
                    user_id=(
                        user_id
                    ),
                    group_id=None,
                )
            )

        for group_id in (
            data.group_ids
        ):
            db.add(
                QuizAssignmentRecipient(
                    assignment_id=(
                        assignment.id
                    ),
                    user_id=None,
                    group_id=(
                        group_id
                    ),
                )
            )

        db.commit()

        return (
            get_assignment_by_id(
                db,
                assignment.id,
            )
        )

    except Exception:
        db.rollback()
        raise


def update_quiz_assignment(
    db: Session,
    assignment: QuizAssignment,
    actor: User,
    data: QuizAssignmentUpdate,
):
    if (
        actor.role
        not in {
            "admin",
            "creator",
        }
        and assignment.teacher_id
        != actor.id
    ):
        raise PermissionError(
            "Non puoi modificare questa assegnazione."
        )

    values = data.model_dump(
        exclude_unset=True,
    )

    if (
        values.get(
            "due_at"
        )
        is not None
        and values[
            "due_at"
        ] <= utc_now()
    ):
        raise ValueError(
            "La scadenza deve essere futura."
        )

    for field, value in (
        values.items()
    ):
        setattr(
            assignment,
            field,
            value,
        )

    try:
        db.commit()

        return (
            get_assignment_by_id(
                db,
                assignment.id,
            )
        )

    except Exception:
        db.rollback()
        raise


def delete_quiz_assignment(
    db: Session,
    assignment: QuizAssignment,
    actor: User,
):
    if (
        actor.role
        not in {
            "admin",
            "creator",
        }
        and assignment.teacher_id
        != actor.id
    ):
        raise PermissionError(
            "Non puoi eliminare questa assegnazione."
        )

    assignment.is_active = False

    try:
        db.commit()

        db.refresh(
            assignment
        )

        return assignment

    except Exception:
        db.rollback()
        raise


def get_teacher_assignments(
    db: Session,
    actor: User,
):
    query = (
        db.query(
            QuizAssignment
        )
        .options(
            joinedload(
                QuizAssignment.recipients
            )
        )
    )

    if actor.role not in {
        "admin",
        "creator",
    }:
        query = query.filter(
            QuizAssignment.teacher_id
            ==
            actor.id
        )

    return (
        query
        .order_by(
            QuizAssignment.created_at.desc()
        )
        .all()
    )


def get_student_assignments(
    db: Session,
    user_id: int,
):
    group_ids = [
        group_id
        for (
            group_id,
        ) in (
            db.query(
                GroupMember.group_id
            )
            .filter(
                GroupMember.user_id
                ==
                user_id
            )
            .all()
        )
    ]

    filters = [
        QuizAssignmentRecipient.user_id
        ==
        user_id
    ]

    if group_ids:
        filters.append(
            QuizAssignmentRecipient.group_id.in_(
                group_ids
            )
        )

    assignments = (
        db.query(
            QuizAssignment
        )
        .join(
            QuizAssignmentRecipient,
            QuizAssignmentRecipient.assignment_id
            ==
            QuizAssignment.id,
        )
        .options(
            joinedload(
                QuizAssignment.recipients
            )
        )
        .filter(
            QuizAssignment.is_active.is_(
                True
            ),
            or_(
                *filters
            ),
        )
        .distinct()
        .order_by(
            QuizAssignment.created_at.desc()
        )
        .all()
    )

    now = utc_now()

    result = []

    for assignment in assignments:
        expired = (
            assignment.due_at
            is not None
            and assignment.due_at
            < now
        )

        result.append(
            {
                "id":
                    assignment.id,

                "teacher_id":
                    assignment.teacher_id,

                "subject_id":
                    assignment.subject_id,

                "department":
                    assignment.department,

                "course":
                    assignment.course,

                "subject":
                    assignment.subject,

                "title":
                    assignment.title,

                "description":
                    assignment.description,

                "selection_mode":
                    assignment.selection_mode,

                "selected_arguments":
                    assignment.selected_arguments,

                "selected_question_ids":
                    assignment.selected_question_ids,

                "question_count":
                    assignment.question_count,

                "time_limit_seconds":
                    assignment.time_limit_seconds,

                "due_at":
                    assignment.due_at,

                "is_active":
                    assignment.is_active,

                "created_at":
                    assignment.created_at,

                "updated_at":
                    assignment.updated_at,

                "recipients":
                    assignment.recipients,

                "is_expired":
                    expired,

                "can_start":
                    (
                        assignment.is_active
                        and not expired
                    ),
            }
        )

    return result


def can_student_access_assignment(
    db: Session,
    assignment_id: int,
    user_id: int,
) -> bool:
    assignment = (
        get_assignment_by_id(
            db,
            assignment_id,
        )
    )

    if (
        assignment is None
        or not assignment.is_active
    ):
        return False

    direct = (
        db.query(
            QuizAssignmentRecipient
        )
        .filter(
            QuizAssignmentRecipient.assignment_id
            ==
            assignment_id,

            QuizAssignmentRecipient.user_id
            ==
            user_id,
        )
        .first()
    )

    if direct is not None:
        return True

    user_group_ids = [
        group_id
        for (
            group_id,
        ) in (
            db.query(
                GroupMember.group_id
            )
            .filter(
                GroupMember.user_id
                ==
                user_id
            )
            .all()
        )
    ]

    if not user_group_ids:
        return False

    group_recipient = (
        db.query(
            QuizAssignmentRecipient
        )
        .filter(
            QuizAssignmentRecipient.assignment_id
            ==
            assignment_id,

            QuizAssignmentRecipient.group_id.in_(
                user_group_ids
            ),
        )
        .first()
    )

    return (
        group_recipient
        is not None
    )