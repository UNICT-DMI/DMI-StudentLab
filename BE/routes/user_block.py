from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    status,
)

from sqlalchemy.exc import (
    IntegrityError,
)

from sqlalchemy.orm import (
    Session,
)

from core.database import (
    get_db,
)

from core.security import (
    get_current_user,
)

from models.user import (
    User,
)

from schemas.user_block import (
    UserBlockCreate,
    UserBlockListResponse,
    UserBlockResponse,
    UserBlockStatusResponse,
    UserUnblockResponse,
)

from services.user_block import (
    create_user_block,
    delete_user_block,
    get_blocked_users,
    is_user_blocked,
)


router = APIRouter(
    prefix="/user-blocks",
    tags=[
        "User Blocks",
    ],
)


@router.post(
    "",
    response_model=UserBlockResponse,
    status_code=status.HTTP_201_CREATED,
)
def api_create_user_block(
    request: UserBlockCreate,
    db: Session = Depends(
        get_db,
    ),
    current_user: User = Depends(
        get_current_user,
    ),
):
    try:
        return create_user_block(
            db,
            current_user.id,
            request.blocked_user_id,
        )

    except ValueError as exception:
        message = str(
            exception,
        )

        if (
            message
            ==
            "Utente già bloccato."
        ):
            raise HTTPException(
                status_code=(
                    status.HTTP_409_CONFLICT
                ),
                detail=message,
            )

        if (
            message
            ==
            "Utente non trovato."
        ):
            raise HTTPException(
                status_code=(
                    status.HTTP_404_NOT_FOUND
                ),
                detail=message,
            )

        raise HTTPException(
            status_code=(
                status.HTTP_400_BAD_REQUEST
            ),
            detail=message,
        )

    except IntegrityError:
        db.rollback()

        raise HTTPException(
            status_code=(
                status.HTTP_409_CONFLICT
            ),
            detail=(
                "Impossibile bloccare questo utente."
            ),
        )

    except Exception:
        db.rollback()

        raise HTTPException(
            status_code=(
                status.HTTP_500_INTERNAL_SERVER_ERROR
            ),
            detail=(
                "Impossibile completare il blocco dell'utente."
            ),
        )


@router.delete(
    "/{blocked_user_id}",
    response_model=UserUnblockResponse,
)
def api_delete_user_block(
    blocked_user_id: int,
    db: Session = Depends(
        get_db,
    ),
    current_user: User = Depends(
        get_current_user,
    ),
):
    if blocked_user_id <= 0:
        raise HTTPException(
            status_code=(
                status.HTTP_400_BAD_REQUEST
            ),
            detail="Utente non valido.",
        )

    try:
        delete_user_block(
            db,
            current_user.id,
            blocked_user_id,
        )

        return UserUnblockResponse(
            success=True,
            blocked_user_id=(
                blocked_user_id
            ),
            message=(
                "Utente sbloccato."
            ),
        )

    except ValueError as exception:
        message = str(
            exception,
        )

        if (
            message
            ==
            "Blocco utente non trovato."
        ):
            raise HTTPException(
                status_code=(
                    status.HTTP_404_NOT_FOUND
                ),
                detail=message,
            )

        raise HTTPException(
            status_code=(
                status.HTTP_400_BAD_REQUEST
            ),
            detail=message,
        )

    except Exception:
        db.rollback()

        raise HTTPException(
            status_code=(
                status.HTTP_500_INTERNAL_SERVER_ERROR
            ),
            detail=(
                "Impossibile sbloccare questo utente."
            ),
        )


@router.get(
    "",
    response_model=UserBlockListResponse,
)
def api_get_blocked_users(
    db: Session = Depends(
        get_db,
    ),
    current_user: User = Depends(
        get_current_user,
    ),
):
    try:
        items = get_blocked_users(
            db,
            current_user.id,
        )

        return UserBlockListResponse(
            items=items,
            total=len(
                items,
            ),
        )

    except Exception:
        raise HTTPException(
            status_code=(
                status.HTTP_500_INTERNAL_SERVER_ERROR
            ),
            detail=(
                "Impossibile recuperare gli utenti bloccati."
            ),
        )


@router.get(
    "/{blocked_user_id}/status",
    response_model=UserBlockStatusResponse,
)
def api_get_user_block_status(
    blocked_user_id: int,
    db: Session = Depends(
        get_db,
    ),
    current_user: User = Depends(
        get_current_user,
    ),
):
    if blocked_user_id <= 0:
        raise HTTPException(
            status_code=(
                status.HTTP_400_BAD_REQUEST
            ),
            detail="Utente non valido.",
        )

    if (
        blocked_user_id
        ==
        current_user.id
    ):
        return UserBlockStatusResponse(
            blocked=False,
            blocked_user_id=(
                blocked_user_id
            ),
        )

    try:
        blocked = is_user_blocked(
            db,
            current_user.id,
            blocked_user_id,
        )

        return UserBlockStatusResponse(
            blocked=blocked,
            blocked_user_id=(
                blocked_user_id
            ),
        )

    except Exception:
        raise HTTPException(
            status_code=(
                status.HTTP_500_INTERNAL_SERVER_ERROR
            ),
            detail=(
                "Impossibile verificare lo stato del blocco."
            ),
        )