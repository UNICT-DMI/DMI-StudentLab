from fastapi import (
    Depends,
    HTTPException,
    status,
)

from fastapi.security import (
    HTTPAuthorizationCredentials,
    HTTPBearer,
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

from models.user import (
    User,
)

from services.auth import (
    decode_access_token,
)

from services.user import (
    get_user_by_id,
)


security = HTTPBearer()

optional_security = HTTPBearer(
    auto_error=False,
)


ADMIN_ROLES = {
    "admin",
    "creator",
}


def require_active_user(
    user: User,
) -> User:
    if not user.is_active:
        raise HTTPException(
            status_code=(
                status.HTTP_403_FORBIDDEN
            ),
            detail=(
                "Account non attivo."
            ),
        )

    return user


def require_verified_email(
    user: User,
) -> User:
    if (
        user.email_verified_at
        is None
    ):
        raise HTTPException(
            status_code=(
                status.HTTP_403_FORBIDDEN
            ),
            detail=(
                "Verifica la tua email "
                "prima di continuare."
            ),
        )

    return user


def require_authenticated_user(
    user: User,
) -> User:
    require_active_user(
        user,
    )

    require_verified_email(
        user,
    )

    return user


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(
        security,
    ),
    db: Session = Depends(
        get_db,
    ),
) -> User:
    user_id = decode_access_token(
        token=(
            credentials.credentials
        ),
        secret_key=(
            settings.secret_key
        ),
    )

    if user_id is None:
        raise HTTPException(
            status_code=(
                status.HTTP_401_UNAUTHORIZED
            ),
            detail=(
                "Token non valido o scaduto."
            ),
        )

    user = get_user_by_id(
        db,
        user_id,
    )

    if user is None:
        raise HTTPException(
            status_code=(
                status.HTTP_401_UNAUTHORIZED
            ),
            detail=(
                "Utente non trovato."
            ),
        )

    require_authenticated_user(
        user,
    )

    return user


def get_optional_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(
        optional_security,
    ),
    db: Session = Depends(
        get_db,
    ),
) -> User | None:
    if credentials is None:
        return None

    user_id = decode_access_token(
        token=(
            credentials.credentials
        ),
        secret_key=(
            settings.secret_key
        ),
    )

    if user_id is None:
        raise HTTPException(
            status_code=(
                status.HTTP_401_UNAUTHORIZED
            ),
            detail=(
                "Token non valido o scaduto."
            ),
        )

    user = get_user_by_id(
        db,
        user_id,
    )

    if user is None:
        raise HTTPException(
            status_code=(
                status.HTTP_401_UNAUTHORIZED
            ),
            detail=(
                "Utente non trovato."
            ),
        )

    require_authenticated_user(
        user,
    )

    return user


def get_admin_user(
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
) -> User:
    user = get_user_by_id(
        db,
        current_user.id,
    )

    if user is None:
        raise HTTPException(
            status_code=(
                status.HTTP_401_UNAUTHORIZED
            ),
            detail=(
                "Utente non trovato."
            ),
        )

    require_authenticated_user(
        user,
    )

    role = (
        user.role
        or ""
    ).strip().lower()

    if role not in ADMIN_ROLES:
        raise HTTPException(
            status_code=(
                status.HTTP_403_FORBIDDEN
            ),
            detail=(
                "Accesso riservato "
                "agli amministratori."
            ),
        )

    return user


def get_verified_teacher_user(
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
) -> User:
    user = get_user_by_id(
        db,
        current_user.id,
    )

    if user is None:
        raise HTTPException(
            status_code=(
                status.HTTP_401_UNAUTHORIZED
            ),
            detail=(
                "Utente non trovato."
            ),
        )

    require_authenticated_user(
        user,
    )

    role = (
        user.role
        or ""
    ).strip().lower()

    if role != "teacher":
        raise HTTPException(
            status_code=(
                status.HTTP_403_FORBIDDEN
            ),
            detail=(
                "Accesso riservato "
                "ai docenti."
            ),
        )

    teacher_status = (
        user.teacher_verification_status
        or ""
    ).strip().lower()

    if (
        teacher_status !=
        "verified"
    ):
        raise HTTPException(
            status_code=(
                status.HTTP_403_FORBIDDEN
            ),
            detail=(
                "Docente non ancora "
                "verificato."
            ),
        )

    return user


def get_verified_teacher(
    current_user: User = Depends(
        get_verified_teacher_user,
    ),
) -> User:
    return current_user


def get_creator_user(
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
) -> User:
    user = get_user_by_id(
        db,
        current_user.id,
    )

    if user is None:
        raise HTTPException(
            status_code=(
                status.HTTP_401_UNAUTHORIZED
            ),
            detail=(
                "Utente non trovato."
            ),
        )

    require_authenticated_user(
        user,
    )

    role = (
        user.role
        or ""
    ).strip().lower()

    if role != "creator":
        raise HTTPException(
            status_code=(
                status.HTTP_403_FORBIDDEN
            ),
            detail=(
                "Accesso riservato "
                "al creator."
            ),
        )

    return user