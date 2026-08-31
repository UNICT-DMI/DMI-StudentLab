from datetime import (
    datetime,
    timezone,
)

from sqlalchemy.orm import (
    Session,
    joinedload,
)

from models.subject import (
    Subject,
    SubjectOffering,
)

from models.teacher_assignment import (
    TeacherAssignment,
)

from models.user import User

from schemas.teacher_assignment import (
    TeacherAssignmentCreate,
    TeacherAssignmentUpdate,
)


def get_teacher_assignment_by_id(
    db: Session,
    assignment_id: int,
):
    return (
        db.query(
            TeacherAssignment,
        )
        .options(
            joinedload(
                TeacherAssignment.subject,
            )
            .joinedload(
                Subject.offerings,
            )
            .joinedload(
                SubjectOffering.teachers,
            ),
            joinedload(
                TeacherAssignment.offering,
            )
            .joinedload(
                SubjectOffering.teachers,
            ),
        )
        .filter(
            TeacherAssignment.id ==
            assignment_id,
        )
        .first()
    )


def get_teacher_assignments(
    db: Session,
    teacher_id: int,
):
    return (
        db.query(
            TeacherAssignment,
        )
        .options(
            joinedload(
                TeacherAssignment.subject,
            )
            .joinedload(
                Subject.offerings,
            )
            .joinedload(
                SubjectOffering.teachers,
            ),
            joinedload(
                TeacherAssignment.offering,
            )
            .joinedload(
                SubjectOffering.teachers,
            ),
        )
        .filter(
            TeacherAssignment.user_id ==
            teacher_id,
        )
        .order_by(
            TeacherAssignment.is_current.desc(),
            TeacherAssignment.id.asc(),
        )
        .all()
    )


def get_pending_teacher_assignments(
    db: Session,
):
    return (
        db.query(
            TeacherAssignment,
        )
        .options(
            joinedload(
                TeacherAssignment.subject,
            )
            .joinedload(
                Subject.offerings,
            )
            .joinedload(
                SubjectOffering.teachers,
            ),
            joinedload(
                TeacherAssignment.offering,
            )
            .joinedload(
                SubjectOffering.teachers,
            ),
            joinedload(
                TeacherAssignment.user,
            ),
        )
        .filter(
            TeacherAssignment.verification_status ==
            "pending",
        )
        .order_by(
            TeacherAssignment.id.asc(),
        )
        .all()
    )


def get_all_teacher_assignments(
    db: Session,
    status: str | None = None,
):
    query = (
        db.query(
            TeacherAssignment,
        )
        .options(
            joinedload(
                TeacherAssignment.subject,
            )
            .joinedload(
                Subject.offerings,
            )
            .joinedload(
                SubjectOffering.teachers,
            ),
            joinedload(
                TeacherAssignment.offering,
            )
            .joinedload(
                SubjectOffering.teachers,
            ),
            joinedload(
                TeacherAssignment.user,
            ),
        )
    )

    if status is not None:
        query = query.filter(
            TeacherAssignment.verification_status ==
            status,
        )

    return (
        query
        .order_by(
            TeacherAssignment.id.desc(),
        )
        .all()
    )


def reset_teacher_assignment(
    db: Session,
    assignment: TeacherAssignment,
):
    assignment.verification_status = (
        "pending"
    )

    assignment.verified_by = None

    assignment.verified_at = None

    db.commit()

    return get_teacher_assignment_by_id(
        db,
        assignment.id,
    )


def get_verified_teacher_assignment(
    db: Session,
    teacher_id: int,
    subject_id: int,
):
    return (
        db.query(
            TeacherAssignment,
        )
        .filter(
            TeacherAssignment.user_id ==
            teacher_id,
            TeacherAssignment.subject_id ==
            subject_id,
            TeacherAssignment.verification_status ==
            "verified",
            TeacherAssignment.is_current.is_(
                True,
            ),
        )
        .first()
    )


def _get_subject(
    db: Session,
    subject_id: int,
):
    subject = (
        db.query(
            Subject,
        )
        .filter(
            Subject.id ==
            subject_id,
            Subject.is_active.is_(
                True,
            ),
        )
        .first()
    )

    if subject is None:
        raise ValueError(
            "Materia non trovata.",
        )

    return subject


def _get_offering(
    db: Session,
    subject_id: int,
    offering_id: int | None,
):
    if offering_id is None:
        return None

    offering = (
        db.query(
            SubjectOffering,
        )
        .filter(
            SubjectOffering.id ==
            offering_id,
            SubjectOffering.subject_id ==
            subject_id,
            SubjectOffering.is_active.is_(
                True,
            ),
        )
        .first()
    )

    if offering is None:
        raise ValueError(
            "Offering non trovata oppure non appartenente alla materia selezionata.",
        )

    return offering


def _check_duplicate(
    db: Session,
    teacher_id: int,
    subject_id: int,
    offering_id: int | None,
    exclude_assignment_id: int | None = None,
):
    query = (
        db.query(
            TeacherAssignment,
        )
        .filter(
            TeacherAssignment.user_id ==
            teacher_id,
        )
    )

    if offering_id is None:
        query = query.filter(
            TeacherAssignment.subject_id ==
            subject_id,
            TeacherAssignment.offering_id.is_(
                None,
            ),
        )
    else:
        query = query.filter(
            TeacherAssignment.offering_id ==
            offering_id,
        )

    if exclude_assignment_id is not None:
        query = query.filter(
            TeacherAssignment.id !=
            exclude_assignment_id,
        )

    if query.first() is not None:
        raise ValueError(
            "Insegnamento già associato al docente.",
        )


def create_teacher_assignment(
    db: Session,
    teacher: User,
    data: TeacherAssignmentCreate,
):
    if teacher.role != "teacher":
        raise PermissionError(
            "Solo un docente può aggiungere insegnamenti.",
        )

    _get_subject(
        db,
        data.subject_id,
    )

    _get_offering(
        db,
        data.subject_id,
        data.offering_id,
    )

    _check_duplicate(
        db,
        teacher.id,
        data.subject_id,
        data.offering_id,
    )

    assignment = TeacherAssignment(
        user_id=teacher.id,
        subject_id=data.subject_id,
        offering_id=data.offering_id,
        verification_status="pending",
        verified_by=None,
        verified_at=None,
        is_current=data.is_current,
    )

    db.add(
        assignment,
    )

    db.commit()

    return get_teacher_assignment_by_id(
        db,
        assignment.id,
    )


def update_teacher_assignment(
    db: Session,
    teacher: User,
    assignment: TeacherAssignment,
    data: TeacherAssignmentUpdate,
):
    if (
        assignment.user_id !=
        teacher.id
    ):
        raise PermissionError(
            "Non puoi modificare questo insegnamento.",
        )

    values = data.model_dump(
        exclude_unset=True,
    )

    subject_id = values.get(
        "subject_id",
        assignment.subject_id,
    )

    if "offering_id" in values:
        offering_id = values[
            "offering_id"
        ]
    elif (
        "subject_id" in values
        and subject_id !=
        assignment.subject_id
    ):
        offering_id = None
    else:
        offering_id = (
            assignment.offering_id
        )

    _get_subject(
        db,
        subject_id,
    )

    _get_offering(
        db,
        subject_id,
        offering_id,
    )

    _check_duplicate(
        db,
        teacher.id,
        subject_id,
        offering_id,
        exclude_assignment_id=(
            assignment.id
        ),
    )

    verification_changed = (
        subject_id !=
        assignment.subject_id
        or offering_id !=
        assignment.offering_id
    )

    assignment.subject_id = (
        subject_id
    )

    assignment.offering_id = (
        offering_id
    )

    if (
        "is_current" in values
    ):
        assignment.is_current = (
            values["is_current"]
        )

    if verification_changed:
        assignment.verification_status = (
            "pending"
        )
        assignment.verified_by = None
        assignment.verified_at = None

    db.commit()

    return get_teacher_assignment_by_id(
        db,
        assignment.id,
    )


def delete_teacher_assignment(
    db: Session,
    teacher: User,
    assignment: TeacherAssignment,
):
    if (
        assignment.user_id !=
        teacher.id
    ):
        raise PermissionError(
            "Non puoi eliminare questo insegnamento.",
        )

    db.delete(
        assignment,
    )

    db.commit()


def verify_teacher_assignment(
    db: Session,
    assignment: TeacherAssignment,
    admin: User,
):
    teacher = (
        db.query(
            User,
        )
        .filter(
            User.id ==
            assignment.user_id,
        )
        .first()
    )

    if teacher is None:
        raise ValueError(
            "Docente non trovato.",
        )

    if teacher.role != "teacher":
        raise ValueError(
            "L'utente associato non è un docente.",
        )

    if (
        teacher.teacher_verification_status !=
        "verified"
    ):
        raise ValueError(
            "Il docente deve essere verificato prima di verificare un insegnamento.",
        )

    assignment.verification_status = (
        "verified"
    )

    assignment.verified_by = (
        admin.id
    )

    assignment.verified_at = (
        datetime.now(
            timezone.utc,
        )
    )

    db.commit()

    return get_teacher_assignment_by_id(
        db,
        assignment.id,
    )


def reject_teacher_assignment(
    db: Session,
    assignment: TeacherAssignment,
    admin: User,
):
    assignment.verification_status = (
        "rejected"
    )

    assignment.verified_by = (
        admin.id
    )

    assignment.verified_at = (
        datetime.now(
            timezone.utc,
        )
    )

    db.commit()

    return get_teacher_assignment_by_id(
        db,
        assignment.id,
    )