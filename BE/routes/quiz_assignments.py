from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
)

from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_current_user

from models.user import User

from schemas.quiz_assignment import (
    QuizAssignmentCreate,
    QuizAssignmentResponse,
    QuizAssignmentUpdate,
    StudentAssignedQuizResponse,
)

from schemas.quiz_attempt import (
    QuizAttemptResponse,
)

from services.quiz_assignment_service import (
    can_user_access_quiz_assignment,
    create_quiz_assignment,
    deactivate_quiz_assignment,
    get_quiz_assignment_by_id,
    get_quiz_assignment_results,
    get_student_quiz_assignments,
    get_teacher_quiz_assignments,
    get_user_quiz_assignments,
    update_quiz_assignment,
)


router = APIRouter(
    prefix="/quiz-assignments",
    tags=[
        "quiz-assignments",
    ],
)


def _raise_service_error(
    exception: Exception,
):
    if isinstance(
        exception,
        PermissionError,
    ):
        raise HTTPException(
            status_code=403,
            detail=str(
                exception
            ),
        ) from exception

    message = str(
        exception
    )

    lowered_message = (
        message.lower()
    )

    if (
        "non trovata"
        in lowered_message
        or "non trovato"
        in lowered_message
    ):
        status_code = 404
    else:
        status_code = 400

    raise HTTPException(
        status_code=status_code,
        detail=message,
    ) from exception


@router.post(
    "",
    response_model=QuizAssignmentResponse,
    status_code=201,
)
def api_create_quiz_assignment(
    request: QuizAssignmentCreate,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    try:
        return create_quiz_assignment(
            db,
            current_user,
            request,
        )

    except (
        ValueError,
        PermissionError,
    ) as exception:
        _raise_service_error(
            exception
        )


@router.get(
    "/teacher",
    response_model=list[
        QuizAssignmentResponse
    ],
)
def api_teacher_quiz_assignments(
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    if current_user.role not in {
        "teacher",
        "admin",
        "creator",
    }:
        raise HTTPException(
            status_code=403,
            detail=(
                "Non puoi visualizzare le assegnazioni docente."
            ),
        )

    return get_teacher_quiz_assignments(
        db,
        current_user,
    )


@router.get(
    "/me",
    response_model=list[
        StudentAssignedQuizResponse
    ],
)
def api_my_quiz_assignments(
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    try:
        return get_user_quiz_assignments(
            db=db,
            user_id=current_user.id,
        )

    except (
        ValueError,
        PermissionError,
    ) as exception:
        _raise_service_error(
            exception
        )


@router.get(
    "/student",
    response_model=list[
        StudentAssignedQuizResponse
    ],
    deprecated=True,
)
def api_student_quiz_assignments(
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    try:
        return get_student_quiz_assignments(
            db,
            current_user.id,
        )

    except (
        ValueError,
        PermissionError,
    ) as exception:
        _raise_service_error(
            exception
        )


@router.get(
    "/{assignment_id}",
    response_model=QuizAssignmentResponse,
)
def api_quiz_assignment_detail(
    assignment_id: int,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    assignment = (
        get_quiz_assignment_by_id(
            db,
            assignment_id,
        )
    )

    if assignment is None:
        raise HTTPException(
            status_code=404,
            detail=(
                "Assegnazione non trovata."
            ),
        )

    if (
        current_user.role
        not in {
            "admin",
            "creator",
        }
        and assignment.teacher_id
        != current_user.id
    ):
        allowed = (
            can_user_access_quiz_assignment(
                db,
                assignment.id,
                current_user.id,
            )
        )

        if not allowed:
            raise HTTPException(
                status_code=403,
                detail=(
                    "Non puoi visualizzare questa assegnazione."
                ),
            )

    return assignment


@router.patch(
    "/{assignment_id}",
    response_model=QuizAssignmentResponse,
)
def api_update_quiz_assignment(
    assignment_id: int,
    request: QuizAssignmentUpdate,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    assignment = (
        get_quiz_assignment_by_id(
            db,
            assignment_id,
        )
    )

    if assignment is None:
        raise HTTPException(
            status_code=404,
            detail=(
                "Assegnazione non trovata."
            ),
        )

    try:
        return update_quiz_assignment(
            db,
            assignment,
            current_user,
            request,
        )

    except (
        ValueError,
        PermissionError,
    ) as exception:
        _raise_service_error(
            exception
        )


@router.post(
    "/{assignment_id}/reactivate",
    response_model=QuizAssignmentResponse,
)
def api_reactivate_quiz_assignment(
    assignment_id: int,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    assignment = (
        get_quiz_assignment_by_id(
            db,
            assignment_id,
        )
    )

    if assignment is None:
        raise HTTPException(
            status_code=404,
            detail=(
                "Assegnazione non trovata."
            ),
        )

    if assignment.is_active:
        return assignment

    try:
        request = QuizAssignmentUpdate(
            is_active=True,
        )

        return update_quiz_assignment(
            db,
            assignment,
            current_user,
            request,
        )

    except (
        ValueError,
        PermissionError,
    ) as exception:
        _raise_service_error(
            exception
        )


@router.delete(
    "/{assignment_id}",
)
def api_deactivate_quiz_assignment(
    assignment_id: int,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    assignment = (
        get_quiz_assignment_by_id(
            db,
            assignment_id,
        )
    )

    if assignment is None:
        raise HTTPException(
            status_code=404,
            detail=(
                "Assegnazione non trovata."
            ),
        )

    try:
        deactivate_quiz_assignment(
            db,
            assignment,
            current_user,
        )

    except (
        ValueError,
        PermissionError,
    ) as exception:
        _raise_service_error(
            exception
        )

    return {
        "success":
            True,
        "message":
            "Assegnazione disattivata.",
    }


@router.get(
    "/{assignment_id}/results",
    response_model=list[
        QuizAttemptResponse
    ],
)
def api_quiz_assignment_results(
    assignment_id: int,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    assignment = (
        get_quiz_assignment_by_id(
            db,
            assignment_id,
        )
    )

    if assignment is None:
        raise HTTPException(
            status_code=404,
            detail=(
                "Assegnazione non trovata."
            ),
        )

    try:
        return get_quiz_assignment_results(
            db,
            assignment,
            current_user,
        )

    except PermissionError as exception:
        _raise_service_error(
            exception
        )