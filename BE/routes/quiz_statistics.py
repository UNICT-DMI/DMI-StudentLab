from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query,
    status,
)

from sqlalchemy import func
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_current_user

from models.subject import Subject
from models.teacher_assignment import TeacherAssignment
from models.user import User

from schemas.quiz_statistics import (
    QuizArgumentStatisticsResponse,
    QuizLearningProfileResponse,
    QuizOverallStatisticsResponse,
    QuizQuestionStatisticsResponse,
    QuizReviewQuestionResponse,
    QuizSubjectStatisticsResponse,
)

from services.quiz_statistics_service import (
    get_student_argument_statistics,
    get_student_learning_profile,
    get_student_overall_statistics,
    get_student_question_statistics,
    get_student_review_questions,
    get_student_subject_statistics,
    get_student_weak_arguments,
)


router = APIRouter(
    prefix="/quiz-statistics",
    tags=[
        "quiz-statistics",
    ],
)


def _normalize_required_filter(
    value: str,
    field_name: str,
) -> str:
    normalized = value.strip()

    if not normalized:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=(
                f"Il campo {field_name} è obbligatorio."
            ),
        )

    return normalized


def _get_subject_record(
    db: Session,
    department: str,
    course: str,
    subject: str,
) -> Subject | None:
    return (
        db.query(
            Subject
        )
        .filter(
            func.lower(
                Subject.department_code
            ) == department.strip().lower(),
            func.lower(
                Subject.course_code
            ) == course.strip().lower(),
            func.lower(
                Subject.name
            ) == subject.strip().lower(),
            Subject.is_active.is_(True),
        )
        .first()
    )


def _get_active_user(
    db: Session,
    user_id: int,
) -> User | None:
    return (
        db.query(
            User
        )
        .filter(
            User.id == user_id,
            User.is_active.is_(True),
        )
        .first()
    )


def _can_teacher_access_subject(
    db: Session,
    teacher: User,
    department: str,
    course: str,
    subject: str,
) -> bool:
    if teacher.role in {
        "admin",
        "creator",
    }:
        return True

    if (
        teacher.role != "teacher"
        or teacher.teacher_verification_status
        != "verified"
    ):
        return False

    subject_record = (
        _get_subject_record(
            db,
            department,
            course,
            subject,
        )
    )

    if subject_record is None:
        return False

    assignment = (
        db.query(
            TeacherAssignment
        )
        .filter(
            TeacherAssignment.user_id == teacher.id,
            TeacherAssignment.subject_id == subject_record.id,
            TeacherAssignment.verification_status == "verified",
            TeacherAssignment.is_current.is_(True),
        )
        .first()
    )

    return (
        assignment is not None
    )


def _require_student_statistics_access(
    db: Session,
    current_user: User,
    student_id: int,
    department: str | None = None,
    course: str | None = None,
    subject: str | None = None,
) -> None:
    if student_id <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Utente non valido.",
        )

    target_user = _get_active_user(
        db,
        student_id,
    )

    if target_user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Utente non trovato.",
        )

    if (
        current_user.id
        == student_id
    ):
        return

    if current_user.role in {
        "admin",
        "creator",
    }:
        return

    if (
        department is None
        or course is None
        or subject is None
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Per visualizzare le statistiche di un altro utente devi specificare la materia."
            ),
        )

    department = _normalize_required_filter(
        department,
        "dipartimento",
    )
    course = _normalize_required_filter(
        course,
        "corso",
    )
    subject = _normalize_required_filter(
        subject,
        "materia",
    )

    if not _can_teacher_access_subject(
        db,
        current_user,
        department,
        course,
        subject,
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Non puoi visualizzare le statistiche di questa materia."
            ),
        )


@router.get(
    "/me/overall",
    response_model=QuizOverallStatisticsResponse,
)
def api_my_overall_statistics(
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(
        get_db
    ),
):
    return get_student_overall_statistics(
        db,
        current_user.id,
    )


@router.get(
    "/me/subjects",
    response_model=list[
        QuizSubjectStatisticsResponse
    ],
)
def api_my_subject_statistics(
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(
        get_db
    ),
):
    return get_student_subject_statistics(
        db,
        current_user.id,
    )


@router.get(
    "/me/arguments",
    response_model=list[
        QuizArgumentStatisticsResponse
    ],
)
def api_my_argument_statistics(
    department: str | None = None,
    course: str | None = None,
    subject: str | None = None,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(
        get_db
    ),
):
    return get_student_argument_statistics(
        db,
        current_user.id,
        department=department,
        course=course,
        subject=subject,
    )


@router.get(
    "/me/questions",
    response_model=list[
        QuizQuestionStatisticsResponse
    ],
)
def api_my_question_statistics(
    department: str | None = None,
    course: str | None = None,
    subject: str | None = None,
    argument: str | None = None,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(
        get_db
    ),
):
    return get_student_question_statistics(
        db,
        current_user.id,
        department=department,
        course=course,
        subject=subject,
        argument=argument,
    )


@router.get(
    "/me/weak-arguments",
    response_model=list[
        QuizArgumentStatisticsResponse
    ],
)
def api_my_weak_arguments(
    department: str | None = None,
    course: str | None = None,
    subject: str | None = None,
    maximum_accuracy: float = Query(
        default=70.0,
        ge=0.0,
        le=100.0,
    ),
    minimum_answers: int = Query(
        default=1,
        ge=1,
        le=10000,
    ),
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(
        get_db
    ),
):
    return get_student_weak_arguments(
        db,
        current_user.id,
        department=department,
        course=course,
        subject=subject,
        maximum_accuracy=maximum_accuracy,
        minimum_answers=minimum_answers,
    )


@router.get(
    "/me/review",
    response_model=list[
        QuizReviewQuestionResponse
    ],
)
def api_my_review_questions(
    department: str | None = None,
    course: str | None = None,
    subject: str | None = None,
    argument: str | None = None,
    include_correct: bool = Query(
        default=False
    ),
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(
        get_db
    ),
):
    return get_student_review_questions(
        db,
        current_user.id,
        department=department,
        course=course,
        subject=subject,
        argument=argument,
        include_correct=include_correct,
    )


@router.get(
    "/me/profile",
    response_model=QuizLearningProfileResponse,
)
def api_my_learning_profile(
    department: str | None = None,
    course: str | None = None,
    subject: str | None = None,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(
        get_db
    ),
):
    return get_student_learning_profile(
        db,
        current_user.id,
        department=department,
        course=course,
        subject=subject,
    )


@router.get(
    "/students/{student_id}/arguments",
    response_model=list[
        QuizArgumentStatisticsResponse
    ],
)
def api_student_argument_statistics(
    student_id: int,
    department: str,
    course: str,
    subject: str,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(
        get_db
    ),
):
    department = _normalize_required_filter(
        department,
        "dipartimento",
    )
    course = _normalize_required_filter(
        course,
        "corso",
    )
    subject = _normalize_required_filter(
        subject,
        "materia",
    )

    _require_student_statistics_access(
        db,
        current_user,
        student_id,
        department,
        course,
        subject,
    )

    return get_student_argument_statistics(
        db,
        student_id,
        department=department,
        course=course,
        subject=subject,
    )


@router.get(
    "/students/{student_id}/questions",
    response_model=list[
        QuizQuestionStatisticsResponse
    ],
)
def api_student_question_statistics(
    student_id: int,
    department: str,
    course: str,
    subject: str,
    argument: str | None = None,
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(
        get_db
    ),
):
    department = _normalize_required_filter(
        department,
        "dipartimento",
    )
    course = _normalize_required_filter(
        course,
        "corso",
    )
    subject = _normalize_required_filter(
        subject,
        "materia",
    )

    _require_student_statistics_access(
        db,
        current_user,
        student_id,
        department,
        course,
        subject,
    )

    return get_student_question_statistics(
        db,
        student_id,
        department=department,
        course=course,
        subject=subject,
        argument=argument,
    )


@router.get(
    "/students/{student_id}/weak-arguments",
    response_model=list[
        QuizArgumentStatisticsResponse
    ],
)
def api_student_weak_arguments(
    student_id: int,
    department: str,
    course: str,
    subject: str,
    maximum_accuracy: float = Query(
        default=70.0,
        ge=0.0,
        le=100.0,
    ),
    minimum_answers: int = Query(
        default=1,
        ge=1,
        le=10000,
    ),
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(
        get_db
    ),
):
    department = _normalize_required_filter(
        department,
        "dipartimento",
    )
    course = _normalize_required_filter(
        course,
        "corso",
    )
    subject = _normalize_required_filter(
        subject,
        "materia",
    )

    _require_student_statistics_access(
        db,
        current_user,
        student_id,
        department,
        course,
        subject,
    )

    return get_student_weak_arguments(
        db,
        student_id,
        department=department,
        course=course,
        subject=subject,
        maximum_accuracy=maximum_accuracy,
        minimum_answers=minimum_answers,
    )


@router.get(
    "/students/{student_id}/review",
    response_model=list[
        QuizReviewQuestionResponse
    ],
)
def api_student_review_questions(
    student_id: int,
    department: str,
    course: str,
    subject: str,
    argument: str | None = None,
    include_correct: bool = Query(
        default=False
    ),
    current_user: User = Depends(
        get_current_user
    ),
    db: Session = Depends(
        get_db
    ),
):
    department = _normalize_required_filter(
        department,
        "dipartimento",
    )
    course = _normalize_required_filter(
        course,
        "corso",
    )
    subject = _normalize_required_filter(
        subject,
        "materia",
    )

    _require_student_statistics_access(
        db,
        current_user,
        student_id,
        department,
        course,
        subject,
    )

    return get_student_review_questions(
        db,
        student_id,
        department=department,
        course=course,
        subject=subject,
        argument=argument,
        include_correct=include_correct,
    )