from datetime import (
    datetime,
    timedelta,
    timezone,
)

import hashlib
import hmac
import os

from uuid import (
    uuid4,
)

from jose import (
    JWTError,
    jwt,
)

from core.config import (
    settings,
)


UPLOAD_AUTHORIZATION_EXPIRE_MINUTES = int(
    os.getenv(
        "UPLOAD_AUTHORIZATION_EXPIRE_MINUTES",
        "15",
    )
)

UPLOAD_AUTHORIZATION_ALGORITHM = (
    "HS256"
)

UPLOAD_AUTHORIZATION_TOKEN_USE = (
    "upload_authorization"
)

RESERVED_CLAIMS = {
    "iat",
    "exp",
    "jti",
    "token_use",
}


def utc_now() -> datetime:
    return datetime.now(
        timezone.utc,
    )


def _upload_authorization_secret() -> str:
    secret_key = (
        settings.secret_key
        or ""
    )

    if not secret_key:
        raise RuntimeError(
            "Chiave di sicurezza non configurata.",
        )

    return hashlib.sha256(
        (
            f"{secret_key}:"
            "studentlab:"
            "upload_authorization"
        ).encode(
            "utf-8",
        )
    ).hexdigest()


def create_upload_authorization(
    payload: dict,
) -> tuple[
    str,
    int,
]:
    if not isinstance(
        payload,
        dict,
    ):
        raise ValueError(
            "Dati di autorizzazione upload non validi.",
        )

    if not payload:
        raise ValueError(
            "Dati di autorizzazione upload mancanti.",
        )

    if any(
        key in payload
        for key in RESERVED_CLAIMS
    ):
        raise ValueError(
            "Dati di autorizzazione upload non validi.",
        )

    token_type = payload.get(
        "type",
    )

    if (
        not isinstance(
            token_type,
            str,
        )
        or not token_type.strip()
    ):
        raise ValueError(
            "Tipo di autorizzazione upload non valido.",
        )

    user_id = payload.get(
        "uid",
    )

    if (
        not isinstance(
            user_id,
            int,
        )
        or isinstance(
            user_id,
            bool,
        )
        or user_id <= 0
    ):
        raise ValueError(
            "Utente dell'autorizzazione upload non valido.",
        )

    now = utc_now()

    expires_at = (
        now
        + timedelta(
            minutes=(
                UPLOAD_AUTHORIZATION_EXPIRE_MINUTES
            ),
        )
    )

    token_payload = dict(
        payload,
    )

    token_payload[
        "type"
    ] = token_type.strip()

    token_payload.update(
        {
            "token_use":
                UPLOAD_AUTHORIZATION_TOKEN_USE,
            "iat":
                int(
                    now.timestamp()
                ),
            "exp":
                int(
                    expires_at.timestamp()
                ),
            "jti":
                uuid4().hex,
        }
    )

    token = jwt.encode(
        token_payload,
        _upload_authorization_secret(),
        algorithm=(
            UPLOAD_AUTHORIZATION_ALGORITHM
        ),
    )

    return (
        token,
        int(
            expires_at.timestamp()
        ),
    )


def decode_upload_authorization(
    token: str,
) -> dict:
    if (
        not isinstance(
            token,
            str,
        )
        or not token.strip()
    ):
        raise ValueError(
            "Autorizzazione upload non valida.",
        )

    try:
        payload = jwt.decode(
            token.strip(),
            _upload_authorization_secret(),
            algorithms=[
                UPLOAD_AUTHORIZATION_ALGORITHM,
            ],
        )

    except JWTError as exception:
        raise ValueError(
            "Autorizzazione upload non valida o scaduta.",
        ) from exception

    if not isinstance(
        payload,
        dict,
    ):
        raise ValueError(
            "Autorizzazione upload non valida.",
        )

    if (
        payload.get(
            "token_use",
        )
        !=
        UPLOAD_AUTHORIZATION_TOKEN_USE
    ):
        raise ValueError(
            "Autorizzazione upload non valida.",
        )

    issued_at = payload.get(
        "iat",
    )

    expires_at = payload.get(
        "exp",
    )

    token_id = payload.get(
        "jti",
    )

    if (
        not isinstance(
            issued_at,
            int,
        )
        or isinstance(
            issued_at,
            bool,
        )
        or not isinstance(
            expires_at,
            int,
        )
        or isinstance(
            expires_at,
            bool,
        )
        or not isinstance(
            token_id,
            str,
        )
        or not token_id
    ):
        raise ValueError(
            "Autorizzazione upload non valida.",
        )

    if expires_at <= int(
        utc_now().timestamp()
    ):
        raise ValueError(
            "Autorizzazione upload scaduta.",
        )

    return payload


def require_upload_authorization_type(
    payload: dict,
    expected_type: str,
) -> None:
    if not isinstance(
        payload,
        dict,
    ):
        raise ValueError(
            "Autorizzazione upload non valida.",
        )

    if (
        not isinstance(
            expected_type,
            str,
        )
        or not expected_type.strip()
    ):
        raise ValueError(
            "Tipo di autorizzazione upload non valido.",
        )

    actual_type = payload.get(
        "type",
    )

    if (
        not isinstance(
            actual_type,
            str,
        )
        or not hmac.compare_digest(
            actual_type,
            expected_type.strip(),
        )
    ):
        raise ValueError(
            "Autorizzazione upload non valida per questa operazione.",
        )


def require_upload_authorization_user(
    payload: dict,
    user_id: int,
) -> None:
    if not isinstance(
        payload,
        dict,
    ):
        raise ValueError(
            "Autorizzazione upload non valida.",
        )

    if (
        not isinstance(
            user_id,
            int,
        )
        or isinstance(
            user_id,
            bool,
        )
        or user_id <= 0
    ):
        raise ValueError(
            "Utente non valido.",
        )

    authorized_user_id = payload.get(
        "uid",
    )

    if (
        not isinstance(
            authorized_user_id,
            int,
        )
        or isinstance(
            authorized_user_id,
            bool,
        )
        or authorized_user_id
        !=
        user_id
    ):
        raise ValueError(
            "Autorizzazione upload non valida per questo utente.",
        )


def require_upload_authorization_fields(
    payload: dict,
    expected_fields: dict,
) -> None:
    if (
        not isinstance(
            payload,
            dict,
        )
        or not isinstance(
            expected_fields,
            dict,
        )
    ):
        raise ValueError(
            "Autorizzazione upload non valida.",
        )

    for (
        field_name,
        expected_value,
    ) in expected_fields.items():
        if (
            not isinstance(
                field_name,
                str,
            )
            or not field_name
        ):
            raise ValueError(
                "Campo di autorizzazione upload non valido.",
            )

        if field_name not in payload:
            raise ValueError(
                "Autorizzazione upload incompleta.",
            )

        actual_value = payload[
            field_name
        ]

        if (
            isinstance(
                actual_value,
                str,
            )
            and isinstance(
                expected_value,
                str,
            )
        ):
            if not hmac.compare_digest(
                actual_value,
                expected_value,
            ):
                raise ValueError(
                    "I dati dell'upload non corrispondono all'autorizzazione.",
                )

        elif (
            actual_value
            !=
            expected_value
        ):
            raise ValueError(
                "I dati dell'upload non corrispondono all'autorizzazione.",
            )