from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    status,
)

from sqlalchemy.orm import (
    Session,
)

from core.config import (
    settings,
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

from schemas.user_public_key import (
    ComplianceKeyResponse,
    UserPublicKeyListResponse,
    UserPublicKeyRegister,
    UserPublicKeyResponse,
    UserPublicKeyRevokeResponse,
)

from services.user_public_key import (
    get_recipient_public_keys,
    list_own_public_keys,
    register_public_key,
    revoke_public_key,
)


router = APIRouter(
    tags=["Chiavi pubbliche"],
)


def _list_response(
    keys,
) -> UserPublicKeyListResponse:
    return UserPublicKeyListResponse(
        items=[
            UserPublicKeyResponse.model_validate(
                key,
            )
            for key in keys
        ],
        total=len(
            keys,
        ),
    )


@router.post(
    "/me/public-keys",
    response_model=UserPublicKeyResponse,
    status_code=status.HTTP_201_CREATED,
)
def api_register_public_key(
    request: UserPublicKeyRegister,
    db: Session = Depends(
        get_db,
    ),
    current_user: User = Depends(
        get_current_user,
    ),
):
    try:
        return register_public_key(
            db,
            current_user,
            request,
        )
    except ValueError as exception:
        raise HTTPException(
            status_code=(
                status.HTTP_400_BAD_REQUEST
            ),
            detail=str(
                exception,
            ),
        )
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=(
                status
                .HTTP_500_INTERNAL_SERVER_ERROR
            ),
            detail="Impossibile registrare la chiave del dispositivo.",
        )


@router.get(
    "/me/public-keys",
    response_model=UserPublicKeyListResponse,
)
def api_list_own_public_keys(
    db: Session = Depends(
        get_db,
    ),
    current_user: User = Depends(
        get_current_user,
    ),
):
    return _list_response(
        list_own_public_keys(
            db,
            current_user.id,
        ),
    )


@router.delete(
    "/me/public-keys/{device_id}",
    response_model=UserPublicKeyRevokeResponse,
)
def api_revoke_public_key(
    device_id: str,
    db: Session = Depends(
        get_db,
    ),
    current_user: User = Depends(
        get_current_user,
    ),
):
    try:
        revoked = revoke_public_key(
            db,
            current_user.id,
            device_id.strip(),
        )
    except ValueError as exception:
        raise HTTPException(
            status_code=(
                status.HTTP_404_NOT_FOUND
            ),
            detail=str(
                exception,
            ),
        )

    return UserPublicKeyRevokeResponse(
        success=True,
        message="Dispositivo revocato.",
        device_id=revoked.device_id,
    )


@router.get(
    "/users/{user_id}/public-keys",
    response_model=UserPublicKeyListResponse,
)
def api_list_user_public_keys(
    user_id: int,
    db: Session = Depends(
        get_db,
    ),
    current_user: User = Depends(
        get_current_user,
    ),
):
    try:
        keys = get_recipient_public_keys(
            db,
            current_user,
            user_id,
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
        raise HTTPException(
            status_code=(
                status.HTTP_404_NOT_FOUND
            ),
            detail=str(
                exception,
            ),
        )

    return _list_response(
        keys,
    )


@router.get(
    "/crypto/compliance-key",
    response_model=ComplianceKeyResponse,
)
def api_compliance_key(
    current_user: User = Depends(
        get_current_user,
    ),
):
    public_key = settings.compliance_public_key

    return ComplianceKeyResponse(
        configured=bool(
            public_key,
        ),
        key_id=settings.compliance_key_id,
        algo=settings.compliance_key_algo,
        public_key=public_key,
    )
