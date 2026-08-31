import base64

from cryptography.exceptions import (
    InvalidTag,
)

from cryptography.hazmat.primitives.ciphers.aead import (
    AESGCM,
)


FORMAT_VERSION = 1

CONTENT_KEY_LENGTH = 32

MAC_LENGTH = 16


class DisclosureError(Exception):
    pass


def _decode(value: str, field: str) -> bytes:
    text = (value or "").strip()

    if not text:
        raise DisclosureError(
            f"Campo di cifratura mancante: {field}.",
        )

    padded = text + "=" * (-len(text) % 4)

    for altchars in (
        None,
        b"-_",
    ):
        try:
            return base64.b64decode(
                padded,
                altchars=altchars,
                validate=True,
            )
        except ValueError:
            continue

    raise DisclosureError(
        f"Campo di cifratura non valido: {field}.",
    )


def associated_data(
    *,
    sender_id: int,
    sender_device: str,
) -> bytes:
    return (
        f"studentlab-private-news-v{FORMAT_VERSION}"
        f"|{sender_id}|{sender_device}"
    ).encode("utf-8")


def decrypt_with_content_key(
    *,
    ciphertext: str,
    metadata: dict,
    content_key: str,
) -> str:
    key = _decode(
        content_key,
        "content_key",
    )

    if len(key) != CONTENT_KEY_LENGTH:
        raise DisclosureError(
            "La chiave del messaggio non ha la lunghezza attesa.",
        )

    version = metadata.get("v")

    if version not in (
        None,
        FORMAT_VERSION,
    ):
        raise DisclosureError(
            f"Formato del messaggio non supportato: v{version}.",
        )

    payload = _decode(
        ciphertext,
        "ciphertext",
    )

    if len(payload) <= MAC_LENGTH:
        raise DisclosureError(
            "Messaggio cifrato incompleto.",
        )

    nonce = _decode(
        metadata.get("nonce"),
        "nonce",
    )

    try:
        sender_id = int(
            metadata.get(
                "sender_id",
                0,
            )
            or 0,
        )
    except (TypeError, ValueError):
        raise DisclosureError(
            "Mittente dichiarato non valido.",
        )

    try:
        clear = AESGCM(
            key,
        ).decrypt(
            nonce,
            payload,
            associated_data(
                sender_id=sender_id,
                sender_device=str(
                    metadata.get(
                        "sender_device",
                        "",
                    )
                    or "",
                ),
            ),
        )
    except InvalidTag:
        raise DisclosureError(
            "La chiave fornita non decifra questo messaggio: la "
            "segnalazione non è verificabile.",
        )

    try:
        return clear.decode("utf-8")
    except UnicodeDecodeError:
        raise DisclosureError(
            "Il contenuto decifrato non è testo valido.",
        )


def wrap_targets(metadata: dict) -> list[str]:
    wrapped = metadata.get("wrapped_keys")

    if not isinstance(wrapped, dict):
        return []

    return sorted(
        str(
            key,
        )
        for key in wrapped.keys()
    )
