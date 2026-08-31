from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
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
)

from models.user import (
    User,
)

from schemas.contact import (
    ContactUserRequest,
    ContactUserResponse,
)

from services.contact import (
    send_contact_request,
)


router = APIRouter(
    prefix="/contact",
    tags=[
        "Contact",
    ],
)


@router.post(
    "/users/{user_id}",
    response_model=ContactUserResponse,
    status_code=status.HTTP_200_OK,
)
def api_contact_user(
    user_id: int,
    request: ContactUserRequest,
    db: Session = Depends(
        get_db,
    ),
    current_user: User = Depends(
        get_current_user,
    ),
):
    try:
        return send_contact_request(
            db,
            sender=current_user,
            recipient_user_id=user_id,
            data=request,
        )

    except PermissionError as exception:
        raise HTTPException(
            status_code=(
                status.HTTP_403_FORBIDDEN
            ),
            detail=str(
                exception,
            ),
        )

    except ValueError as exception:
        message = str(
            exception,
        )

        status_code = (
            status.HTTP_404_NOT_FOUND
            if message ==
            "L'utente non è disponibile."
            else status.HTTP_400_BAD_REQUEST
        )

        raise HTTPException(
            status_code=status_code,
            detail=message,
        )

    except RuntimeError:
        raise HTTPException(
            status_code=(
                status.HTTP_503_SERVICE_UNAVAILABLE
            ),
            detail=(
                "Il servizio email non è temporaneamente disponibile. Riprova tra qualche momento."
            ),
        )

    except Exception:
        raise HTTPException(
            status_code=(
                status.HTTP_500_INTERNAL_SERVER_ERROR
            ),
            detail=(
                "Non è stato possibile inviare la richiesta."
            ),
        )