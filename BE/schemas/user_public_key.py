import base64
import re

from datetime import datetime

from typing import Literal

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
)


PublicKeyAlgo = Literal["x25519"]


_DEVICE_ID_PATTERN = re.compile(
    r"^[A-Za-z0-9._-]{8,64}$",
)

_KEY_LENGTHS = {
    "x25519": 32,
}


def _canonical_public_key(
    value: str,
    algo: str,
) -> str:
    normalized = value.strip()

    if not normalized:
        raise ValueError(
            "Chiave pubblica non valida.",
        )

    padded = normalized + "=" * (-len(normalized) % 4)

    for altchars in (
        None,
        b"-_",
    ):
        try:
            raw = base64.b64decode(
                padded,
                altchars=altchars,
                validate=True,
            )
        except ValueError:
            continue

        expected = _KEY_LENGTHS.get(algo)

        if expected is not None and len(raw) != expected:
            raise ValueError(
                f"La chiave pubblica {algo} deve essere di "
                f"{expected} byte.",
            )

        return base64.b64encode(
            raw,
        ).decode("ascii")

    raise ValueError(
        "Chiave pubblica non codificata in base64.",
    )


class UserPublicKeyRegister(
    BaseModel,
):
    device_id: str = Field(
        min_length=8,
        max_length=64,
    )

    algo: PublicKeyAlgo = "x25519"

    public_key: str = Field(
        min_length=1,
        max_length=512,
    )

    device_label: str | None = Field(
        default=None,
        max_length=100,
    )

    @field_validator(
        "device_id",
    )
    @classmethod
    def validate_device_id(
        cls,
        value: str,
    ) -> str:
        normalized = value.strip()

        if not _DEVICE_ID_PATTERN.match(
            normalized,
        ):
            raise ValueError(
                "Identificativo del dispositivo non valido.",
            )

        return normalized

    @field_validator(
        "device_label",
    )
    @classmethod
    def normalize_device_label(
        cls,
        value: str | None,
    ) -> str | None:
        if value is None:
            return None

        normalized = value.strip()

        return normalized or None

    @field_validator(
        "public_key",
    )
    @classmethod
    def validate_public_key(
        cls,
        value: str,
        info,
    ) -> str:
        algo = (
            info.data.get(
                "algo",
            )
            or "x25519"
        )

        return _canonical_public_key(
            value,
            algo,
        )


class UserPublicKeyResponse(
    BaseModel,
):
    model_config = ConfigDict(
        from_attributes=True,
    )

    id: int
    user_id: int
    device_id: str
    device_label: str | None
    algo: str
    public_key: str
    created_at: datetime
    rotated_at: datetime | None
    revoked_at: datetime | None


class UserPublicKeyListResponse(
    BaseModel,
):
    items: list[UserPublicKeyResponse]
    total: int


class UserPublicKeyRevokeResponse(
    BaseModel,
):
    success: bool
    message: str
    device_id: str


class ComplianceKeyResponse(
    BaseModel,
):
    configured: bool
    key_id: str
    algo: str
    public_key: str
