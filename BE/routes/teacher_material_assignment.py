from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query,
    status,
)

from sqlalchemy.orm import (
    Session,
)

from core.database import (
    get_db,
)

from core.security import (
    get_current_user,
    get_verified_teacher_user,
)

from models.user import (
    User,
)

from schemas.teacher_material_assignment import (
    TeacherMaterialAssignmentBulkCreate,
    TeacherMaterialAssignmentCreate,
)

from services.teacher_material_assignment import (
    create_teacher_material_assignment,
    create_teacher_material_assignments_bulk,
    get_teacher_material_assignment_by_id,
    get_teacher_material_assignments,
    require_assignable_teacher_material,
    revoke_teacher_material_assignment,
)


router = APIRouter(
    tags=[
        "teacher-material-assignments",
    ],
)


def _serialize_assignment(
    assignment,
):
    return {
        "id":
            assignment.id,
        "material_id":
            assignment.material_id,
        "assigned_by":
            assignment.assigned_by,
        "user_id":
            assignment.user_id,
        "group_id":
            assignment.group_id,
        "status":
            assignment.status,
        "assigned_at":
            assignment.assigned_at,
        "revoked_by":
            assignment.revoked_by,
        "revoked_at":
            assignment.revoked_at,
        "updated_at":
            assignment.updated_at,
    }


@router.get(
    "/teacher/materials/{material_id}/assignments",
)
def api_teacher_material_assignments(
    material_id: int,
    include_revoked: bool = Query(
        default=False,
    ),
    current_user: User = Depends(
        get_verified_teacher_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    try:
        require_assignable_teacher_material(
            db,
            material_id,
            current_user.id,
        )

        assignments = (
            get_teacher_material_assignments(
                db,
                material_id,
                include_revoked=(
                    include_revoked
                ),
            )
        )

        return [
            _serialize_assignment(
                assignment,
            )
            for assignment
            in assignments
        ]

    except PermissionError as exc:
        raise HTTPException(
            status_code=(
                status.HTTP_403_FORBIDDEN
            ),
            detail=str(
                exc,
            ),
        )

    except ValueError as exc:
        message = str(
            exc,
        )

        if message == (
            "Materiale non trovato."
        ):
            status_code = (
                status.HTTP_404_NOT_FOUND
            )
        else:
            status_code = (
                status.HTTP_400_BAD_REQUEST
            )

        raise HTTPException(
            status_code=status_code,
            detail=message,
        )


@router.post(
    "/teacher/materials/{material_id}/assignments",
    status_code=(
        status.HTTP_201_CREATED
    ),
)
def api_create_teacher_material_assignment(
    material_id: int,
    request:
        TeacherMaterialAssignmentCreate,
    current_user: User = Depends(
        get_verified_teacher_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    try:
        assignment = (
            create_teacher_material_assignment(
                db,
                material_id=(
                    material_id
                ),
                teacher_id=(
                    current_user.id
                ),
                data=request,
            )
        )

        return _serialize_assignment(
            assignment,
        )

    except PermissionError as exc:
        raise HTTPException(
            status_code=(
                status.HTTP_403_FORBIDDEN
            ),
            detail=str(
                exc,
            ),
        )

    except ValueError as exc:
        message = str(
            exc,
        )

        if message in {
            "Materiale non trovato.",
            "Studente non trovato.",
            "Gruppo non trovato.",
        }:
            status_code = (
                status.HTTP_404_NOT_FOUND
            )
        else:
            status_code = (
                status.HTTP_400_BAD_REQUEST
            )

        raise HTTPException(
            status_code=status_code,
            detail=message,
        )


@router.post(
    "/teacher/materials/{material_id}/assignments/bulk",
    status_code=(
        status.HTTP_201_CREATED
    ),
)
def api_create_teacher_material_assignments_bulk(
    material_id: int,
    request:
        TeacherMaterialAssignmentBulkCreate,
    current_user: User = Depends(
        get_verified_teacher_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    try:
        assignments = (
            create_teacher_material_assignments_bulk(
                db,
                material_id=(
                    material_id
                ),
                teacher_id=(
                    current_user.id
                ),
                data=request,
            )
        )

        return [
            _serialize_assignment(
                assignment,
            )
            for assignment
            in assignments
        ]

    except PermissionError as exc:
        raise HTTPException(
            status_code=(
                status.HTTP_403_FORBIDDEN
            ),
            detail=str(
                exc,
            ),
        )

    except ValueError as exc:
        message = str(
            exc,
        )

        if message in {
            "Materiale non trovato.",
            "Studente non trovato.",
            "Gruppo non trovato.",
        }:
            status_code = (
                status.HTTP_404_NOT_FOUND
            )
        else:
            status_code = (
                status.HTTP_400_BAD_REQUEST
            )

        raise HTTPException(
            status_code=status_code,
            detail=message,
        )


@router.get(
    "/teacher-material-assignments/{assignment_id}",
)
def api_teacher_material_assignment(
    assignment_id: int,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    assignment = (
        get_teacher_material_assignment_by_id(
            db,
            assignment_id,
        )
    )

    if assignment is None:
        raise HTTPException(
            status_code=(
                status.HTTP_404_NOT_FOUND
            ),
            detail=(
                "Assegnazione non trovata."
            ),
        )

    is_target_user = (
        assignment.user_id ==
        current_user.id
    )

    can_manage = (
        assignment.assigned_by ==
        current_user.id
        or current_user.role
        in {
            "admin",
            "creator",
        }
    )

    if (
        not is_target_user
        and not can_manage
    ):
        raise HTTPException(
            status_code=(
                status.HTTP_404_NOT_FOUND
            ),
            detail=(
                "Assegnazione non trovata."
            ),
        )

    return _serialize_assignment(
        assignment,
    )


@router.patch(
    "/teacher-material-assignments/{assignment_id}/revoke",
)
def api_revoke_teacher_material_assignment(
    assignment_id: int,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    try:
        assignment = (
            revoke_teacher_material_assignment(
                db,
                assignment_id=(
                    assignment_id
                ),
                actor=current_user,
            )
        )

        return _serialize_assignment(
            assignment,
        )

    except PermissionError as exc:
        raise HTTPException(
            status_code=(
                status.HTTP_403_FORBIDDEN
            ),
            detail=str(
                exc,
            ),
        )

    except ValueError as exc:
        message = str(
            exc,
        )

        if message in {
            "Assegnazione non trovata.",
            "Materiale non trovato.",
        }:
            status_code = (
                status.HTTP_404_NOT_FOUND
            )
        else:
            status_code = (
                status.HTTP_400_BAD_REQUEST
            )

        raise HTTPException(
            status_code=status_code,
            detail=message,
        )