import base64

import pytest

from services.private_news_disclosure import (
    DisclosureError,
    decrypt_with_content_key,
    wrap_targets,
)


# Payload reale prodotto dal client Flutter (PrivateNewsCryptoService, v1).
# Serve da contratto fra i due linguaggi: se una delle due parti cambia il
# formato senza bump di "v", questo test diventa rosso.
DART_FIXTURE = {
    "ciphertext": (
        "cXGp5COm78mM/AwyPYrTEIZ+lQgFTDmCGg7ChPsZV4047rhTpwCaH2cAjd0M/nY="
    ),
    "algo": "x25519-hkdf-sha256+aes-256-gcm",
    "metadata": {
        "v": 1,
        "kex_alg": "x25519-hkdf-sha256",
        "cek_alg": "aes-256-gcm",
        "nonce": "HAQFwr9Qdx+zlYLz",
        "sender_id": 7,
        "sender_device": "device-sender-1",
        "wrapped_keys": {
            "3:device-recipient": {
                "epk": (
                    "54Zn6xC4J7hgZMxKmB6Yo1/tNgJOytlOsIWb6OlO9QI="
                ),
                "salt": "xZ23TMvQaPD64Q9VEdK9CQ==",
                "nonce": "9eP/qfTiJT79UU5K",
                "ct": (
                    "7uY2yV+lKp+vSnnHLXR/JITJTjsV5zXGLBTGv2MuIc7Pmxa5"
                    "JRwmGGWUIbzxFVu3"
                ),
            },
        },
    },
    "content_key": "aHgTLEhDXWr+CqyWOgnOG6Dqx47E3VQiNHuVLdSt2Do=",
    "plaintext": "Contenuto illecito da segnalare",
}


def test_disclosed_key_decrypts_payload_produced_by_the_flutter_client():
    text = decrypt_with_content_key(
        ciphertext=DART_FIXTURE["ciphertext"],
        metadata=DART_FIXTURE["metadata"],
        content_key=DART_FIXTURE["content_key"],
    )

    assert text == DART_FIXTURE["plaintext"]


def test_wrong_content_key_is_rejected():
    other_key = base64.b64encode(
        bytes(
            range(
                32,
            ),
        ),
    ).decode("ascii")

    with pytest.raises(
        DisclosureError,
    ):
        decrypt_with_content_key(
            ciphertext=DART_FIXTURE["ciphertext"],
            metadata=DART_FIXTURE["metadata"],
            content_key=other_key,
        )


def test_altered_sender_breaks_verification():
    metadata = dict(
        DART_FIXTURE["metadata"],
    )

    metadata["sender_id"] = 999

    with pytest.raises(
        DisclosureError,
    ):
        decrypt_with_content_key(
            ciphertext=DART_FIXTURE["ciphertext"],
            metadata=metadata,
            content_key=DART_FIXTURE["content_key"],
        )


def test_altered_ciphertext_breaks_verification():
    payload = bytearray(
        base64.b64decode(
            DART_FIXTURE["ciphertext"],
        ),
    )

    payload[0] ^= 0xFF

    with pytest.raises(
        DisclosureError,
    ):
        decrypt_with_content_key(
            ciphertext=base64.b64encode(
                bytes(
                    payload,
                ),
            ).decode("ascii"),
            metadata=DART_FIXTURE["metadata"],
            content_key=DART_FIXTURE["content_key"],
        )


def test_unsupported_format_version_is_rejected():
    metadata = dict(
        DART_FIXTURE["metadata"],
    )

    metadata["v"] = 2

    with pytest.raises(
        DisclosureError,
    ):
        decrypt_with_content_key(
            ciphertext=DART_FIXTURE["ciphertext"],
            metadata=metadata,
            content_key=DART_FIXTURE["content_key"],
        )


def test_content_key_with_wrong_length_is_rejected():
    with pytest.raises(
        DisclosureError,
    ):
        decrypt_with_content_key(
            ciphertext=DART_FIXTURE["ciphertext"],
            metadata=DART_FIXTURE["metadata"],
            content_key=base64.b64encode(
                b"0" * 16,
            ).decode("ascii"),
        )


def test_wrap_targets_are_listed():
    assert wrap_targets(
        DART_FIXTURE["metadata"],
    ) == [
        "3:device-recipient",
    ]

    assert wrap_targets(
        {},
    ) == []
