from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query,
)

from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from core.database import get_db

from core.security import (
    get_admin_user,
    get_current_user,
)

from models.user import User

from schemas.teacher_assignment import (
    TeacherAssignmentAdminResponse,
    TeacherAssignmentCreate,
    TeacherAssignmentResponse,
    TeacherAssignmentTeacher,
    TeacherAssignmentUpdate,
    TeacherAssignmentVerificationUpdate,
)

from services.teacher_assignment import (
    create_teacher_assignment,
    delete_teacher_assignment,
    get_all_teacher_assignments,
    get_pending_teacher_assignments,
    get_teacher_assignment_by_id,
    get_teacher_assignments,
    reject_teacher_assignment,
    reset_teacher_assignment,
    update_teacher_assignment,
    verify_teacher_assignment,
)

from services.user import get_user_by_id


router = APIRouter()


@router.get(
    "/me/teacher_assignments",
    response_model=list[
        TeacherAssignmentResponse
    ],
)
def api_my_teacher_assignments(
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    if current_user.role != "teacher":
        raise HTTPException(
            status_code=403,
            detail="Solo un docente può visualizzare i propri insegnamenti.",
        )

    return get_teacher_assignments(
        db,
        current_user.id,
    )


@router.get(
    "/user/{user_id}/teacher_assignments",
    response_model=list[
        TeacherAssignmentResponse
    ],
)
def api_user_teacher_assignments(
    user_id: int,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    user = get_user_by_id(
        db,
        user_id,
    )

    if user is None:
        raise HTTPException(
            status_code=404,
            detail="Utente non trovato.",
        )

    if user.role != "teacher":
        return []

    return get_teacher_assignments(
        db,
        user_id,
    )


@router.post(
    "/me/teacher_assignments",
    response_model=TeacherAssignmentResponse,
    status_code=201,
)
def api_create_teacher_assignment(
    request: TeacherAssignmentCreate,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    try:
        return create_teacher_assignment(
            db,
            current_user,
            request,
        )

    except PermissionError as exception:
        db.rollback()

        raise HTTPException(
            status_code=403,
            detail=str(
                exception,
            ),
        )

    except ValueError as exception:
        db.rollback()

        raise HTTPException(
            status_code=400,
            detail=str(
                exception,
            ),
        )

    except IntegrityError:
        db.rollback()

        raise HTTPException(
            status_code=409,
            detail="Insegnamento già associato al docente.",
        )


@router.patch(
    "/me/teacher_assignments/{assignment_id}",
    response_model=TeacherAssignmentResponse,
)
def api_update_teacher_assignment(
    assignment_id: int,
    request: TeacherAssignmentUpdate,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    assignment = (
        get_teacher_assignment_by_id(
            db,
            assignment_id,
        )
    )

    if assignment is None:
        raise HTTPException(
            status_code=404,
            detail="Insegnamento non trovato.",
        )

    try:
        return update_teacher_assignment(
            db,
            current_user,
            assignment,
            request,
        )

    except PermissionError as exception:
        db.rollback()

        raise HTTPException(
            status_code=403,
            detail=str(
                exception,
            ),
        )

    except ValueError as exception:
        db.rollback()

        raise HTTPException(
            status_code=400,
            detail=str(
                exception,
            ),
        )

    except IntegrityError:
        db.rollback()

        raise HTTPException(
            status_code=409,
            detail="Insegnamento già associato al docente.",
        )


@router.delete(
    "/me/teacher_assignments/{assignment_id}",
)
def api_delete_teacher_assignment(
    assignment_id: int,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    assignment = (
        get_teacher_assignment_by_id(
            db,
            assignment_id,
        )
    )

    if assignment is None:
        raise HTTPException(
            status_code=404,
            detail="Insegnamento non trovato.",
        )

    try:
        delete_teacher_assignment(
            db,
            current_user,
            assignment,
        )

    except PermissionError as exception:
        db.rollback()

        raise HTTPException(
            status_code=403,
            detail=str(
                exception,
            ),
        )

    except IntegrityError:
        db.rollback()

        raise HTTPException(
            status_code=409,
            detail="Impossibile eliminare l'insegnamento.",
        )

    return {
        "success":
            True,
        "message":
            "Insegnamento eliminato.",
    }


def _admin_assignment_responses(
    assignments,
):
    result = []

    for assignment in assignments:
        response = TeacherAssignmentAdminResponse.model_validate(
            assignment,
        )

        if assignment.user is not None:
            response.teacher = TeacherAssignmentTeacher.model_validate(
                assignment.user,
            )

        result.append(
            response,
        )

    return result


@router.get(
    "/admin/teacher_assignments/pending",
    response_model=list[
        TeacherAssignmentAdminResponse
    ],
)
def api_admin_pending_teacher_assignments(
    current_user: User = Depends(
        get_admin_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return _admin_assignment_responses(
        get_pending_teacher_assignments(
            db,
        ),
    )


@router.get(
    "/admin/teacher_assignments",
    response_model=list[
        TeacherAssignmentAdminResponse
    ],
)
def api_admin_teacher_assignments(
    status: str | None = Query(
        default=None,
    ),
    current_user: User = Depends(
        get_admin_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    normalized_status = (
        status.strip().lower()
        if status is not None
        else None
    )

    if normalized_status in (
        None,
        "",
        "all",
    ):
        normalized_status = None
    elif normalized_status not in (
        "pending",
        "verified",
        "rejected",
    ):
        raise HTTPException(
            status_code=400,
            detail="Stato non valido.",
        )

    return _admin_assignment_responses(
        get_all_teacher_assignments(
            db,
            normalized_status,
        ),
    )


@router.patch(
    "/admin/teacher_assignments/{assignment_id}/verification",
    response_model=TeacherAssignmentResponse,
)
def api_admin_teacher_assignment_verification(
    assignment_id: int,
    request: TeacherAssignmentVerificationUpdate,
    current_user: User = Depends(
        get_admin_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    assignment = (
        get_teacher_assignment_by_id(
            db,
            assignment_id,
        )
    )

    if assignment is None:
        raise HTTPException(
            status_code=404,
            detail="Insegnamento non trovato.",
        )

    try:
        if request.status == "verified":
            return verify_teacher_assignment(
                db,
                assignment,
                current_user,
            )

        if request.status == "pending":
            return reset_teacher_assignment(
                db,
                assignment,
            )

        return reject_teacher_assignment(
            db,
            assignment,
            current_user,
        )

    except ValueError as exception:
        db.rollback()

        raise HTTPException(
            status_code=400,
            detail=str(
                exception,
            ),
        )

    except IntegrityError:
        db.rollback()

        raise HTTPException(
            status_code=409,
            detail="Impossibile aggiornare la verifica dell'insegnamento.",
        )