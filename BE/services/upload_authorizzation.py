import base64
import hashlib
import hmac
import json
import os
import time

from typing import Any


DEFAULT_UPLOAD_TOKEN_LIFETIME_SECONDS = (
    15
    * 60
)


def _get_upload_secret() -> bytes:
    value = (
        os.getenv(
            "STUDENTLAB_UPLOAD_AUTHORIZATION_SECRET"
        )
        or os.getenv(
            "QUESTION_ATTACHMENT_UPLOAD_SECRET"
        )
        or ""
    ).strip()

    if len(
        value
    ) < 32:
        raise RuntimeError(
            "Servizio di autorizzazione upload non configurato."
        )

    return value.encode(
        "utf-8"
    )


def _base64_encode(
    value: bytes,
) -> str:
    return (
        base64
        .urlsafe_b64encode(
            value
        )
        .decode(
            "ascii"
        )
        .rstrip(
            "="
        )
    )


def _base64_decode(
    value: str,
) -> bytes:
    padding = (
        "="
        * (
            -len(
                value
            )
            % 4
        )
    )

    return (
        base64
        .urlsafe_b64decode(
            value
            + padding
        )
    )


def create_upload_authorization(
    payload: dict[str, Any],
    *,
    lifetime_seconds: int = (
        DEFAULT_UPLOAD_TOKEN_LIFETIME_SECONDS
    ),
) -> tuple[
    str,
    int,
]:
    if (
        not isinstance(
            lifetime_seconds,
            int,
        )
        or isinstance(
            lifetime_seconds,
            bool,
        )
        or lifetime_seconds <= 0
    ):
        raise ValueError(
            "Durata autorizzazione upload non valida."
        )

    issued_at = int(
        time.time()
    )

    expires_at = (
        issued_at
        + lifetime_seconds
    )

    token_payload = {
        **payload,
        "iat":
            issued_at,
        "exp":
            expires_at,
    }

    raw_payload = (
        json.dumps(
            token_payload,
            ensure_ascii=False,
            separators=(
                ",",
                ":",
            ),
            sort_keys=True,
        )
        .encode(
            "utf-8"
        )
    )

    encoded_payload = (
        _base64_encode(
            raw_payload
        )
    )

    signature = (
        hmac.new(
            _get_upload_secret(),
            encoded_payload.encode(
                "ascii"
            ),
            hashlib.sha256,
        )
        .digest()
    )

    token = (
        f"{encoded_payload}."
        f"{_base64_encode(signature)}"
    )

    return (
        token,
        expires_at,
    )


def decode_upload_authorization(
    token: str,
) -> dict[str, Any]:
    if not isinstance(
        token,
        str,
    ):
        raise ValueError(
            "Autorizzazione upload non valida."
        )

    token = token.strip()

    if (
        not token
        or len(
            token
        ) > 10000
    ):
        raise ValueError(
            "Autorizzazione upload non valida."
        )

    parts = token.split(
        "."
    )

    if len(
        parts
    ) != 2:
        raise ValueError(
            "Autorizzazione upload non valida."
        )

    encoded_payload = parts[
        0
    ]

    encoded_signature = parts[
        1
    ]

    if (
        not encoded_payload
        or not encoded_signature
    ):
        raise ValueError(
            "Autorizzazione upload non valida."
        )

    expected_signature = (
        hmac.new(
            _get_upload_secret(),
            encoded_payload.encode(
                "ascii"
            ),
            hashlib.sha256,
        )
        .digest()
    )

    try:
        received_signature = (
            _base64_decode(
                encoded_signature
            )
        )

    except Exception as exception:
        raise ValueError(
            "Autorizzazione upload non valida."
        ) from exception

    if not hmac.compare_digest(
        expected_signature,
        received_signature,
    ):
        raise ValueError(
            "Autorizzazione upload non valida."
        )

    try:
        decoded_payload = (
            _base64_decode(
                encoded_payload
            )
            .decode(
                "utf-8"
            )
        )

        payload = json.loads(
            decoded_payload
        )

    except Exception as exception:
        raise ValueError(
            "Autorizzazione upload non valida."
        ) from exception

    if not isinstance(
        payload,
        dict,
    ):
        raise ValueError(
            "Autorizzazione upload non valida."
        )

    issued_at = payload.get(
        "iat"
    )

    expires_at = payload.get(
        "exp"
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
        or expires_at <= issued_at
    ):
        raise ValueError(
            "Autorizzazione upload non valida."
        )

    now = int(
        time.time()
    )

    if expires_at <= now:
        raise ValueError(
            "L'autorizzazione al caricamento è scaduta."
        )

    if issued_at > now + 60:
        raise ValueError(
            "Autorizzazione upload non valida."
        )

    return payload


def require_upload_authorization_type(
    payload: dict[str, Any],
    expected_type: str,
) -> None:
    upload_type = payload.get(
        "type"
    )

    if upload_type != expected_type:
        raise ValueError(
            "Autorizzazione upload non valida."
        )


def require_upload_authorization_user(
    payload: dict[str, Any],
    user_id: int,
) -> None:
    token_user_id = payload.get(
        "uid"
    )

    if (
        not isinstance(
            token_user_id,
            int,
        )
        or isinstance(
            token_user_id,
            bool,
        )
        or token_user_id != user_id
    ):
        raise ValueError(
            "Autorizzazione upload non valida."
        )


def require_upload_authorization_fields(
    payload: dict[str, Any],
    expected: dict[str, Any],
) -> None:
    for field, expected_value in (
        expected.items()
    ):
        if (
            payload.get(
                field
            )
            != expected_value
        ):
            raise ValueError(
                "I dati del caricamento non corrispondono all'autorizzazione."
            )