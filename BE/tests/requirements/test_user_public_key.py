import base64

from datetime import (
    datetime,
    timezone,
)

from types import (
    SimpleNamespace,
)

import pytest

from fastapi.testclient import (
    TestClient,
)

from pydantic import (
    ValidationError,
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

from main import (
    app,
)

from schemas.user_public_key import (
    UserPublicKeyRegister,
)

import routes.user_public_key as key_routes


client = TestClient(
    app,
)


RAW_KEY = bytes(
    range(
        32,
    ),
)

STANDARD_KEY = base64.b64encode(
    RAW_KEY,
).decode("ascii")


@pytest.fixture(
    autouse=True,
)
def clear_dependency_overrides():
    app.dependency_overrides.clear()

    yield

    app.dependency_overrides.clear()


def fake_db():
    yield SimpleNamespace(
        rollback=lambda: None,
    )


def user(
    user_id: int = 100,
):
    return SimpleNamespace(
        id=user_id,
        first_name="Anna",
        last_name="Rossi",
        role="student",
        is_active=True,
    )


def stored_key(
    device_id: str = "device-abc12345",
):
    return SimpleNamespace(
        id=1,
        user_id=100,
        device_id=device_id,
        device_label="Pixel",
        algo="x25519",
        public_key=STANDARD_KEY,
        created_at=datetime(
            2026,
            8,
            26,
            tzinfo=timezone.utc,
        ),
        rotated_at=None,
        revoked_at=None,
    )


def authenticate():
    app.dependency_overrides[
        get_db
    ] = fake_db

    app.dependency_overrides[
        get_current_user
    ] = lambda: user()


def test_register_accepts_urlsafe_key_and_normalizes_it():
    urlsafe = base64.urlsafe_b64encode(
        RAW_KEY,
    ).decode("ascii")

    request = UserPublicKeyRegister(
        device_id="device-abc12345",
        public_key=urlsafe,
    )

    assert request.public_key == STANDARD_KEY
    assert request.algo == "x25519"
    assert request.device_label is None


def test_register_rejects_key_with_wrong_length():
    short = base64.b64encode(
        b"0" * 16,
    ).decode("ascii")

    with pytest.raises(
        ValidationError,
    ):
        UserPublicKeyRegister(
            device_id="device-abc12345",
            public_key=short,
        )


def test_register_rejects_non_base64_key():
    with pytest.raises(
        ValidationError,
    ):
        UserPublicKeyRegister(
            device_id="device-abc12345",
            public_key="non-una-chiave!!",
        )


@pytest.mark.parametrize(
    "device_id",
    [
        "short",
        "device abc12345",
        "device/../abc12345",
    ],
)
def test_register_rejects_invalid_device_id(
    device_id,
):
    with pytest.raises(
        ValidationError,
    ):
        UserPublicKeyRegister(
            device_id=device_id,
            public_key=STANDARD_KEY,
        )


@pytest.mark.parametrize(
    "method,path",
    [
        (
            "post",
            "/me/public-keys",
        ),
        (
            "get",
            "/me/public-keys",
        ),
        (
            "delete",
            "/me/public-keys/device-abc12345",
        ),
        (
            "get",
            "/users/3/public-keys",
        ),
        (
            "get",
            "/crypto/compliance-key",
        ),
    ],
)
def test_public_key_endpoints_reject_anonymous_user(
    method,
    path,
):
    if method == "post":
        response = client.post(
            path,
            json={},
        )
    elif method == "delete":
        response = client.delete(
            path,
        )
    else:
        response = client.get(
            path,
        )

    assert response.status_code in {
        401,
        403,
    }, (
        f"{method.upper()} {path} accessibile senza "
        f"autenticazione: {response.status_code}"
    )


def test_register_public_key_returns_stored_device(
    monkeypatch,
):
    authenticate()

    captured = {}

    def fake_register(
        db,
        current_user,
        request,
    ):
        captured["user_id"] = current_user.id
        captured["public_key"] = request.public_key

        return stored_key()

    monkeypatch.setattr(
        key_routes,
        "register_public_key",
        fake_register,
    )

    response = client.post(
        "/me/public-keys",
        json={
            "device_id": "device-abc12345",
            "public_key": base64.urlsafe_b64encode(
                RAW_KEY,
            ).decode("ascii"),
            "device_label": "  Pixel  ",
        },
    )

    assert response.status_code == 201

    body = response.json()

    assert body["device_id"] == "device-abc12345"
    assert body["public_key"] == STANDARD_KEY
    assert body["revoked_at"] is None

    assert captured["user_id"] == 100
    assert captured["public_key"] == STANDARD_KEY


def test_register_public_key_reports_device_limit(
    monkeypatch,
):
    authenticate()

    def fake_register(
        db,
        current_user,
        request,
    ):
        raise ValueError(
            "Hai raggiunto il numero massimo di dispositivi registrati.",
        )

    monkeypatch.setattr(
        key_routes,
        "register_public_key",
        fake_register,
    )

    response = client.post(
        "/me/public-keys",
        json={
            "device_id": "device-abc12345",
            "public_key": STANDARD_KEY,
        },
    )

    assert response.status_code == 400
    assert "dispositivi" in response.json()["detail"]


def test_revoke_unknown_device_returns_404(
    monkeypatch,
):
    authenticate()

    def fake_revoke(
        db,
        user_id,
        device_id,
    ):
        raise ValueError(
            "Dispositivo non trovato.",
        )

    monkeypatch.setattr(
        key_routes,
        "revoke_public_key",
        fake_revoke,
    )

    response = client.delete(
        "/me/public-keys/device-abc12345",
    )

    assert response.status_code == 404


def test_recipient_keys_are_denied_when_blocked(
    monkeypatch,
):
    authenticate()

    def fake_recipient_keys(
        db,
        viewer,
        recipient_id,
    ):
        raise PermissionError(
            "Non puoi comunicare con questo utente.",
        )

    monkeypatch.setattr(
        key_routes,
        "get_recipient_public_keys",
        fake_recipient_keys,
    )

    response = client.get(
        "/users/3/public-keys",
    )

    assert response.status_code == 403


def test_recipient_keys_list_active_devices(
    monkeypatch,
):
    authenticate()

    monkeypatch.setattr(
        key_routes,
        "get_recipient_public_keys",
        lambda db, viewer, recipient_id: [
            stored_key(
                "device-abc12345",
            ),
            stored_key(
                "device-def67890",
            ),
        ],
    )

    response = client.get(
        "/users/3/public-keys",
    )

    assert response.status_code == 200

    body = response.json()

    assert body["total"] == 2
    assert {
        item["device_id"]
        for item in body["items"]
    } == {
        "device-abc12345",
        "device-def67890",
    }


def test_compliance_key_reports_missing_configuration(
    monkeypatch,
):
    authenticate()

    monkeypatch.setattr(
        settings,
        "compliance_public_key",
        "",
    )

    monkeypatch.setattr(
        settings,
        "compliance_key_id",
        "",
    )

    response = client.get(
        "/crypto/compliance-key",
    )

    assert response.status_code == 200
    assert response.json()["configured"] is False
    assert response.json()["public_key"] == ""


def test_compliance_key_is_exposed_when_configured(
    monkeypatch,
):
    authenticate()

    monkeypatch.setattr(
        settings,
        "compliance_public_key",
        STANDARD_KEY,
    )

    monkeypatch.setattr(
        settings,
        "compliance_key_id",
        "compliance-2026-08",
    )

    monkeypatch.setattr(
        settings,
        "compliance_key_algo",
        "x25519",
    )

    response = client.get(
        "/crypto/compliance-key",
    )

    body = response.json()

    assert body["configured"] is True
    assert body["key_id"] == "compliance-2026-08"
    assert body["algo"] == "x25519"
    assert body["public_key"] == STANDARD_KEY
