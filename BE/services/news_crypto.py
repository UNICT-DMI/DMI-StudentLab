import base64
import hashlib

from cryptography.fernet import Fernet, InvalidToken

from core.config import settings


_ENC_PREFIX = "enc:v1:"


def _fernet() -> Fernet:
    digest = hashlib.sha256(
        f"news-at-rest::{settings.secret_key}".encode("utf-8"),
    ).digest()

    return Fernet(base64.urlsafe_b64encode(digest))


def encrypt_at_rest(plaintext: str | None) -> str | None:
    if plaintext is None:
        return None

    token = _fernet().encrypt(plaintext.encode("utf-8")).decode("ascii")

    return f"{_ENC_PREFIX}{token}"


def decrypt_at_rest(value: str | None) -> str | None:
    if value is None:
        return None

    if not value.startswith(_ENC_PREFIX):
        return value

    token = value[len(_ENC_PREFIX):]

    try:
        return _fernet().decrypt(token.encode("ascii")).decode("utf-8")
    except (InvalidToken, ValueError):
        return value
