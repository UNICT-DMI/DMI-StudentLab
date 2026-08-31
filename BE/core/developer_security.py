from fastapi import (
    Depends,
    HTTPException,
    status,
)

from models.user import (
    User,
)

from core.security import (
    get_current_user,
)


DEVELOPER_SYSTEM_ROLES = {
    "creator",
    "devsyst",
}


def get_developer_system_user(
    current_user: User = Depends(
        get_current_user,
    ),
) -> User:
    role = (
        str(
            current_user.role
            or "",
        )
        .strip()
        .lower()
    )

    if role not in DEVELOPER_SYSTEM_ROLES:
        raise HTTPException(
            status_code=(
                status.HTTP_403_FORBIDDEN
            ),
            detail=(
                "Permessi Developer & System "
                "insufficienti."
            ),
        )

    return current_user
