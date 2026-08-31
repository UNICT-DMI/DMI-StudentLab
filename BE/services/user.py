from datetime import (
    datetime,
    timezone,
)

from sqlalchemy.orm import (
    Session,
    joinedload,
)

from models.user import (
    User,
    UserAcademicPath,
)

from models.subject import (
    Subject,
    SubjectOffering,
    UserSubject,
)

from models.teacher_assignment import (
    TeacherAssignment,
)

from schemas.user import (
    UserAcademicPathCreate,
    UserAcademicPathUpdate,
    UserCreate,
    UserUpdate,
)

from schemas.subject import (
    UserSubjectCreate,
    UserSubjectUpdate,
)


def create_user(
    db: Session,
    data: UserCreate,
):
    role = data.role

    teacher_verification_status = (
        "pending"
        if role == "teacher"
        else "not_required"
    )

    available_for_help = (
        data.available
        if data.available_for_help is None
        else data.available_for_help
    )

    if (
        data.available_for_private_lessons
        is not None
    ):
        available_for_private_lessons = (
            data.available_for_private_lessons
        )

    elif data.willing_to_teach is not None:
        available_for_private_lessons = (
            data.willing_to_teach
        )

    else:
        available_for_private_lessons = (
            False
        )

    user = User(
        first_name=(
            data.first_name
            .strip()
        ),
        last_name=(
            data.last_name
            .strip()
        ),
        email=(
            data.email
            .strip()
            .lower()
        ),
        university=data.university,
        department=data.department,
        course=data.course,
        description=data.description,
        role=role,
        teacher_verification_status=(
            teacher_verification_status
        ),
        available=data.available,
        available_for_help=(
            available_for_help
        ),
        available_for_private_lessons=(
            available_for_private_lessons
        ),
        willing_to_teach=(
            available_for_private_lessons
        ),
    )

    db.add(
        user,
    )

    db.flush()

    if (
        data.university
        and data.university_code
        and data.department
        and data.department_code
        and data.course
        and data.course_code
    ):
        academic_status = (
            data.academic_status
        )

        academic_path = UserAcademicPath(
            user_id=user.id,
            university=data.university,
            university_code=(
                data.university_code
            ),
            department=data.department,
            department_code=(
                data.department_code
            ),
            course=data.course,
            course_code=(
                data.course_code
            ),
            degree_type=(
                data.degree_type
            ),
            status=(
                academic_status
            ),
            verification_status=(
                "pending"
                if academic_status ==
                "graduated"
                else "not_required"
            ),
            start_year=(
                data.start_year
            ),
            graduation_year=(
                data.graduation_year
            ),
            is_current=(
                academic_status ==
                "enrolled"
            ),
            is_primary=True,
        )

        db.add(
            academic_path,
        )

    db.commit()

    return get_user_by_id(
        db,
        user.id,
    )


def _user_query(
    db: Session,
):
    return (
        db.query(
            User,
        )
        .options(
            joinedload(
                User.academic_paths,
            ),
            joinedload(
                User.subjects,
            )
            .joinedload(
                UserSubject.subject,
            )
            .joinedload(
                Subject.offerings,
            )
            .joinedload(
                SubjectOffering.teachers,
            ),
            joinedload(
                User.teacher_assignments,
            )
            .joinedload(
                TeacherAssignment.subject,
            )
            .joinedload(
                Subject.offerings,
            )
            .joinedload(
                SubjectOffering.teachers,
            ),
            joinedload(
                User.teacher_assignments,
            )
            .joinedload(
                TeacherAssignment.offering,
            )
            .joinedload(
                SubjectOffering.teachers,
            ),
        )
    )


def get_users(
    db: Session,
):
    return (
        _user_query(
            db,
        )
        .order_by(
            User.last_name.asc(),
            User.first_name.asc(),
        )
        .all()
    )


def get_available_users(
    db: Session,
):
    return (
        _user_query(
            db,
        )
        .filter(
            User.is_active.is_(
                True,
            ),
            User.email_verified_at.is_not(
                None,
            ),
            User.available.is_(
                True,
            ),
            User.role.in_(
                [
                    "student",
                    "teacher",
                ]
            ),
        )
        .order_by(
            User.last_name.asc(),
            User.first_name.asc(),
        )
        .all()
    )


def get_available_user_by_id(
    db: Session,
    user_id: int,
):
    return (
        _user_query(
            db,
        )
        .filter(
            User.id ==
            user_id,
            User.is_active.is_(
                True,
            ),
            User.email_verified_at.is_not(
                None,
            ),
            User.available.is_(
                True,
            ),
            User.role.in_(
                [
                    "student",
                    "teacher",
                ]
            ),
        )
        .first()
    )


def get_user_by_id(
    db: Session,
    user_id: int,
):
    return (
        _user_query(
            db,
        )
        .filter(
            User.id ==
            user_id,
        )
        .first()
    )


def get_user_by_email(
    db: Session,
    email: str,
):
    normalized_email = (
        email
        .strip()
        .lower()
    )

    return (
        db.query(
            User,
        )
        .filter(
            User.email ==
            normalized_email,
        )
        .first()
    )


def update_user(
    db: Session,
    user: User,
    data: UserUpdate,
):
    update_data = (
        data.model_dump(
            exclude_unset=True,
        )
    )

    private_lessons = (
        update_data.pop(
            "available_for_private_lessons",
            None,
        )
    )

    legacy_private_lessons = (
        update_data.pop(
            "willing_to_teach",
            None,
        )
    )

    for field, value in update_data.items():
        setattr(
            user,
            field,
            value,
        )

    if private_lessons is not None:
        user.available_for_private_lessons = (
            private_lessons
        )

        user.willing_to_teach = (
            private_lessons
        )

    elif legacy_private_lessons is not None:
        user.available_for_private_lessons = (
            legacy_private_lessons
        )

        user.willing_to_teach = (
            legacy_private_lessons
        )

    db.commit()

    return get_user_by_id(
        db,
        user.id,
    )


def create_academic_path(
    db: Session,
    user: User,
    data: UserAcademicPathCreate,
):
    if (
        data.is_current
        and data.status !=
        "enrolled"
    ):
        raise ValueError(
            "Solo un percorso attualmente frequentato può essere impostato come corrente.",
        )

    has_paths = (
        db.query(
            UserAcademicPath,
        )
        .filter(
            UserAcademicPath.user_id ==
            user.id,
        )
        .first()
        is not None
    )

    is_primary = (
        data.is_primary
        or not has_paths
    )

    if data.is_current:
        (
            db.query(
                UserAcademicPath,
            )
            .filter(
                UserAcademicPath.user_id ==
                user.id,
                UserAcademicPath.is_current.is_(
                    True,
                ),
            )
            .update(
                {
                    "is_current":
                        False,
                },
                synchronize_session=False,
            )
        )

    if is_primary:
        (
            db.query(
                UserAcademicPath,
            )
            .filter(
                UserAcademicPath.user_id ==
                user.id,
                UserAcademicPath.is_primary.is_(
                    True,
                ),
            )
            .update(
                {
                    "is_primary":
                        False,
                },
                synchronize_session=False,
            )
        )

    verification_status = (
        "pending"
        if data.status ==
        "graduated"
        else "not_required"
    )

    academic_path = UserAcademicPath(
        user_id=user.id,
        university=data.university,
        university_code=(
            data.university_code
        ),
        department=data.department,
        department_code=(
            data.department_code
        ),
        course=data.course,
        course_code=(
            data.course_code
        ),
        degree_type=(
            data.degree_type
        ),
        status=data.status,
        verification_status=(
            verification_status
        ),
        verified_by=None,
        verified_at=None,
        start_year=(
            data.start_year
        ),
        graduation_year=(
            data.graduation_year
        ),
        is_current=(
            data.is_current
        ),
        is_primary=(
            is_primary
        ),
    )

    db.add(
        academic_path,
    )

    if is_primary:
        _sync_primary_academic_path(
            user,
            academic_path,
        )

    db.commit()

    db.refresh(
        academic_path,
    )

    return academic_path


def get_academic_path_by_id(
    db: Session,
    academic_path_id: int,
):
    return (
        db.query(
            UserAcademicPath,
        )
        .filter(
            UserAcademicPath.id ==
            academic_path_id,
        )
        .first()
    )


def get_user_academic_paths(
    db: Session,
    user_id: int,
):
    return (
        db.query(
            UserAcademicPath,
        )
        .filter(
            UserAcademicPath.user_id ==
            user_id,
        )
        .order_by(
            UserAcademicPath.is_primary.desc(),
            UserAcademicPath.is_current.desc(),
            UserAcademicPath.id.asc(),
        )
        .all()
    )


def get_available_user_academic_paths(
    db: Session,
    user_id: int,
):
    user = get_available_user_by_id(
        db,
        user_id,
    )

    if user is None:
        return None

    return get_user_academic_paths(
        db,
        user_id,
    )


def update_academic_path(
    db: Session,
    user: User,
    academic_path: UserAcademicPath,
    data: UserAcademicPathUpdate,
):
    update_data = (
        data.model_dump(
            exclude_unset=True,
        )
    )

    if (
        update_data.get(
            "is_primary",
        ) is False
        and academic_path.is_primary
    ):
        raise ValueError(
            "Il percorso principale deve essere sostituito con un altro percorso prima di essere rimosso come principale.",
        )

    resulting_status = (
        update_data.get(
            "status",
            academic_path.status,
        )
    )

    resulting_current = (
        update_data.get(
            "is_current",
            academic_path.is_current,
        )
    )

    if (
        resulting_current
        and resulting_status !=
        "enrolled"
    ):
        raise ValueError(
            "Solo un percorso attualmente frequentato può essere impostato come corrente.",
        )

    verification_fields = {
        "university",
        "university_code",
        "department",
        "department_code",
        "course",
        "course_code",
        "degree_type",
        "status",
        "start_year",
        "graduation_year",
    }

    verification_changed = any(
        field in update_data
        and update_data[field] !=
        getattr(
            academic_path,
            field,
        )
        for field in verification_fields
    )

    wants_current = (
        update_data.get(
            "is_current",
        ) is True
    )

    wants_primary = (
        update_data.get(
            "is_primary",
        ) is True
    )

    if wants_current:
        (
            db.query(
                UserAcademicPath,
            )
            .filter(
                UserAcademicPath.user_id ==
                user.id,
                UserAcademicPath.id !=
                academic_path.id,
                UserAcademicPath.is_current.is_(
                    True,
                ),
            )
            .update(
                {
                    "is_current":
                        False,
                },
                synchronize_session=False,
            )
        )

    if wants_primary:
        (
            db.query(
                UserAcademicPath,
            )
            .filter(
                UserAcademicPath.user_id ==
                user.id,
                UserAcademicPath.id !=
                academic_path.id,
                UserAcademicPath.is_primary.is_(
                    True,
                ),
            )
            .update(
                {
                    "is_primary":
                        False,
                },
                synchronize_session=False,
            )
        )

    for field, value in update_data.items():
        setattr(
            academic_path,
            field,
            value,
        )

    if academic_path.status != "enrolled":
        academic_path.is_current = (
            False
        )

    if academic_path.status == "graduated":
        if verification_changed:
            academic_path.verification_status = (
                "pending"
            )

            academic_path.verified_by = (
                None
            )

            academic_path.verified_at = (
                None
            )

    else:
        academic_path.verification_status = (
            "not_required"
        )

        academic_path.verified_by = (
            None
        )

        academic_path.verified_at = (
            None
        )

    if academic_path.is_primary:
        _sync_primary_academic_path(
            user,
            academic_path,
        )

    db.commit()

    db.refresh(
        academic_path,
    )

    return academic_path


def set_current_academic_path(
    db: Session,
    user: User,
    academic_path: UserAcademicPath,
):
    if academic_path.status != "enrolled":
        raise ValueError(
            "Solo un percorso attualmente frequentato può essere impostato come corrente.",
        )

    (
        db.query(
            UserAcademicPath,
        )
        .filter(
            UserAcademicPath.user_id ==
            user.id,
        )
        .update(
            {
                "is_current":
                    False,
            },
            synchronize_session=False,
        )
    )

    academic_path.is_current = (
        True
    )

    db.commit()

    db.refresh(
        academic_path,
    )

    return academic_path


def set_primary_academic_path(
    db: Session,
    user: User,
    academic_path: UserAcademicPath,
):
    (
        db.query(
            UserAcademicPath,
        )
        .filter(
            UserAcademicPath.user_id ==
            user.id,
        )
        .update(
            {
                "is_primary":
                    False,
            },
            synchronize_session=False,
        )
    )

    academic_path.is_primary = (
        True
    )

    _sync_primary_academic_path(
        user,
        academic_path,
    )

    db.commit()

    db.refresh(
        academic_path,
    )

    return academic_path


def remove_academic_path(
    db: Session,
    user: User,
    academic_path: UserAcademicPath,
):
    was_primary = (
        academic_path.is_primary
    )

    db.delete(
        academic_path,
    )

    db.flush()

    if was_primary:
        replacement = (
            db.query(
                UserAcademicPath,
            )
            .filter(
                UserAcademicPath.user_id ==
                user.id,
            )
            .order_by(
                UserAcademicPath.is_current.desc(),
                UserAcademicPath.id.desc(),
            )
            .first()
        )

        if replacement is not None:
            replacement.is_primary = (
                True
            )

            _sync_primary_academic_path(
                user,
                replacement,
            )

        else:
            user.university = None
            user.department = None
            user.course = None

    db.commit()


def verify_academic_path(
    db: Session,
    academic_path: UserAcademicPath,
    verified_by: int,
):
    if (
        academic_path.status !=
        "graduated"
    ):
        raise ValueError(
            "Solo un percorso completato con titolo conseguito può essere verificato.",
        )

    academic_path.verification_status = (
        "verified"
    )

    academic_path.verified_by = (
        verified_by
    )

    academic_path.verified_at = (
        datetime.now(
            timezone.utc,
        )
    )

    db.commit()

    db.refresh(
        academic_path,
    )

    return academic_path


def reject_academic_path(
    db: Session,
    academic_path: UserAcademicPath,
    verified_by: int,
):
    if (
        academic_path.status !=
        "graduated"
    ):
        raise ValueError(
            "Solo un percorso completato con titolo conseguito può essere verificato.",
        )

    academic_path.verification_status = (
        "rejected"
    )

    academic_path.verified_by = (
        verified_by
    )

    academic_path.verified_at = (
        datetime.now(
            timezone.utc,
        )
    )

    db.commit()

    db.refresh(
        academic_path,
    )

    return academic_path


def get_pending_academic_path_verifications(
    db: Session,
):
    return (
        db.query(
            UserAcademicPath,
        )
        .filter(
            UserAcademicPath.status ==
            "graduated",
            UserAcademicPath.verification_status ==
            "pending",
        )
        .order_by(
            UserAcademicPath.id.asc(),
        )
        .all()
    )


def add_subject_to_user(
    db: Session,
    user_id: int,
    data: UserSubjectCreate,
):
    existing = get_user_subject(
        db,
        user_id=user_id,
        subject_id=data.subject_id,
    )

    if existing is not None:
        raise ValueError(
            "Materia già associata all'utente.",
        )

    grade_status = (
        "pending"
        if data.grade is not None
        else "none"
    )

    user_subject = UserSubject(
        user_id=user_id,
        subject_id=data.subject_id,
        grade=data.grade,
        grade_status=grade_status,
        note=data.note,
        can_help=data.can_help,
        can_give_private_lessons=(
            data.can_give_private_lessons
        ),
    )

    db.add(
        user_subject,
    )

    db.commit()

    db.refresh(
        user_subject,
    )

    return user_subject


def update_user_subject(
    db: Session,
    user_subject: UserSubject,
    data: UserSubjectUpdate,
):
    update_data = (
        data.model_dump(
            exclude_unset=True,
        )
    )

    if "grade" in update_data:
        new_grade = (
            update_data[
                "grade"
            ]
        )

        if new_grade is None:
            user_subject.grade_status = (
                "none"
            )

            user_subject.grade_verified_by = (
                None
            )

            user_subject.grade_verified_at = (
                None
            )

        elif (
            new_grade !=
            user_subject.grade
        ):
            user_subject.grade_status = (
                "pending"
            )

            user_subject.grade_verified_by = (
                None
            )

            user_subject.grade_verified_at = (
                None
            )

    for field, value in update_data.items():
        setattr(
            user_subject,
            field,
            value,
        )

    db.commit()

    db.refresh(
        user_subject,
    )

    return user_subject


def get_user_subject(
    db: Session,
    user_id: int,
    subject_id: int,
):
    return (
        db.query(
            UserSubject,
        )
        .filter(
            UserSubject.user_id ==
            user_id,
            UserSubject.subject_id ==
            subject_id,
        )
        .first()
    )


def remove_subject_from_user(
    db: Session,
    user_subject: UserSubject,
):
    db.delete(
        user_subject,
    )

    db.commit()


def verify_teacher(
    db: Session,
    user: User,
    verified_by: int,
):
    if user.role != "teacher":
        raise ValueError(
            "L'utente non è registrato come docente.",
        )

    user.teacher_verification_status = (
        "verified"
    )

    user.teacher_verified_by = (
        verified_by
    )

    user.teacher_verified_at = (
        datetime.now(
            timezone.utc,
        )
    )

    db.commit()

    return get_user_by_id(
        db,
        user.id,
    )


def reject_teacher(
    db: Session,
    user: User,
    verified_by: int,
):
    if user.role != "teacher":
        raise ValueError(
            "L'utente non è registrato come docente.",
        )

    user.teacher_verification_status = (
        "rejected"
    )

    user.teacher_verified_by = (
        verified_by
    )

    user.teacher_verified_at = (
        datetime.now(
            timezone.utc,
        )
    )

    db.commit()

    return get_user_by_id(
        db,
        user.id,
    )


def set_user_active_status(
    db: Session,
    user: User,
    is_active: bool,
):
    user.is_active = (
        is_active
    )

    db.commit()

    return get_user_by_id(
        db,
        user.id,
    )


def _sync_primary_academic_path(
    user: User,
    academic_path: UserAcademicPath,
):
    user.university = (
        academic_path.university
    )

    user.department = (
        academic_path.department
    )

    user.course = (
        academic_path.course
    )