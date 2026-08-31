from types import (
    SimpleNamespace,
)

import pytest

from fastapi.testclient import (
    TestClient,
)

from core.database import (
    get_db,
)

from main import (
    app,
)

import main as main_module


client = TestClient(
    app,
)


class FakeDB:
    pass


@pytest.fixture(
    autouse=True,
)
def clear_dependency_overrides():
    app.dependency_overrides.clear()

    yield

    app.dependency_overrides.clear()


@pytest.fixture
def fake_db():
    return FakeDB()


@pytest.fixture
def override_db(
    fake_db,
):
    def dependency():
        yield fake_db

    app.dependency_overrides[
        get_db
    ] = dependency

    return fake_db


def verified_user(
    *,
    user_id=10,
    email="user@studentlab.test",
):
    return SimpleNamespace(
        id=user_id,
        email=email,
        email_verified_at=object(),
        email_verification_id=None,
    )


def unverified_user(
    *,
    user_id=10,
    email="user@studentlab.test",
    registration_id="registration-id",
):
    return SimpleNamespace(
        id=user_id,
        email=email,
        email_verified_at=None,
        email_verification_id=registration_id,
    )


def test_correct_email_verification_returns_token(
    monkeypatch,
    override_db,
):
    user = verified_user()

    monkeypatch.setattr(
        main_module,
        "verify_user_email",
        lambda db, registration_id, code, secret_key: user,
    )

    monkeypatch.setattr(
        main_module,
        "create_access_token",
        lambda user_id, secret_key: "test-access-token",
    )

    response = client.post(
        "/auth/email/verify",
        json={
            "registration_id":
                "registration-id",
            "code":
                "123456",
        },
    )

    assert response.status_code == 200

    body = response.json()

    assert (
        body[
            "access_token"
        ]
        == "test-access-token"
    )


def test_invalid_email_verification_code_is_rejected(
    monkeypatch,
    override_db,
):
    def fail_verification(
        db,
        registration_id,
        code,
        secret_key,
    ):
        raise ValueError(
            "Codice di verifica non valido.",
        )

    monkeypatch.setattr(
        main_module,
        "verify_user_email",
        fail_verification,
    )

    response = client.post(
        "/auth/email/verify",
        json={
            "registration_id":
                "registration-id",
            "code":
                "000000",
        },
    )

    assert response.status_code == 400


def test_expired_email_verification_code_is_rejected(
    monkeypatch,
    override_db,
):
    def fail_verification(
        db,
        registration_id,
        code,
        secret_key,
    ):
        raise ValueError(
            "Codice di verifica scaduto.",
        )

    monkeypatch.setattr(
        main_module,
        "verify_user_email",
        fail_verification,
    )

    response = client.post(
        "/auth/email/verify",
        json={
            "registration_id":
                "registration-id",
            "code":
                "123456",
        },
    )

    assert response.status_code == 400


def test_unknown_registration_id_is_rejected(
    monkeypatch,
    override_db,
):
    def fail_verification(
        db,
        registration_id,
        code,
        secret_key,
    ):
        raise ValueError(
            "Registrazione non trovata.",
        )

    monkeypatch.setattr(
        main_module,
        "verify_user_email",
        fail_verification,
    )

    response = client.post(
        "/auth/email/verify",
        json={
            "registration_id":
                "unknown-registration",
            "code":
                "123456",
        },
    )

    assert response.status_code == 400


def test_email_verification_does_not_create_token_on_failure(
    monkeypatch,
    override_db,
):
    token_created = {
        "value":
            False,
    }

    def fail_verification(
        db,
        registration_id,
        code,
        secret_key,
    ):
        raise ValueError(
            "Codice non valido.",
        )

    def fake_create_token(
        user_id,
        secret_key,
    ):
        token_created[
            "value"
        ] = True

        return "token"

    monkeypatch.setattr(
        main_module,
        "verify_user_email",
        fail_verification,
    )

    monkeypatch.setattr(
        main_module,
        "create_access_token",
        fake_create_token,
    )

    response = client.post(
        "/auth/email/verify",
        json={
            "registration_id":
                "registration-id",
            "code":
                "000000",
        },
    )

    assert response.status_code == 400

    assert (
        token_created[
            "value"
        ]
        is False
    )


def test_email_verification_uses_verified_user_id_for_token(
    monkeypatch,
    override_db,
):
    user = verified_user(
        user_id=42,
    )

    captured = {}

    monkeypatch.setattr(
        main_module,
        "verify_user_email",
        lambda db, registration_id, code, secret_key: user,
    )

    def fake_create_access_token(
        user_id,
        secret_key,
    ):
        captured[
            "user_id"
        ] = user_id

        return "token-42"

    monkeypatch.setattr(
        main_module,
        "create_access_token",
        fake_create_access_token,
    )

    response = client.post(
        "/auth/email/verify",
        json={
            "registration_id":
                "registration-id",
            "code":
                "123456",
        },
    )

    assert response.status_code == 200

    assert (
        captured[
            "user_id"
        ]
        == 42
    )


def test_email_verification_resend_returns_new_registration_id(
    monkeypatch,
    override_db,
):
    user = unverified_user(
        registration_id=(
            "new-registration-id"
        ),
    )

    monkeypatch.setattr(
        main_module,
        "resend_email_verification",
        lambda db, registration_id, secret_key: (
            user,
            600,
        ),
    )

    response = client.post(
        "/auth/email/resend",
        json={
            "registration_id":
                "old-registration-id",
        },
    )

    assert response.status_code == 200

    body = response.json()

    assert (
        body[
            "registration_id"
        ]
        == "new-registration-id"
    )

    assert (
        body[
            "expires_in"
        ]
        == 600
    )

    assert (
        body[
            "email"
        ]
        == "user@studentlab.test"
    )


def test_email_verification_resend_invalid_request_is_rejected(
    monkeypatch,
    override_db,
):
    def fail_resend(
        db,
        registration_id,
        secret_key,
    ):
        raise ValueError(
            "Richiesta di verifica non valida.",
        )

    monkeypatch.setattr(
        main_module,
        "resend_email_verification",
        fail_resend,
    )

    response = client.post(
        "/auth/email/resend",
        json={
            "registration_id":
                "invalid-registration",
        },
    )

    assert response.status_code == 400


def test_email_verification_resend_email_failure_returns_503(
    monkeypatch,
    override_db,
):
    def fail_resend(
        db,
        registration_id,
        secret_key,
    ):
        raise RuntimeError(
            "Email provider unavailable",
        )

    monkeypatch.setattr(
        main_module,
        "resend_email_verification",
        fail_resend,
    )

    response = client.post(
        "/auth/email/resend",
        json={
            "registration_id":
                "registration-id",
        },
    )

    assert response.status_code == 503


def test_email_verification_resend_requires_registration_id(
    override_db,
):
    response = client.post(
        "/auth/email/resend",
        json={},
    )

    assert response.status_code == 422


def test_email_verification_requires_registration_id(
    override_db,
):
    response = client.post(
        "/auth/email/verify",
        json={
            "code":
                "123456",
        },
    )

    assert response.status_code == 422


def test_email_verification_requires_code(
    override_db,
):
    response = client.post(
        "/auth/email/verify",
        json={
            "registration_id":
                "registration-id",
        },
    )

    assert response.status_code == 422


def test_invalid_login_credentials_are_rejected(
    monkeypatch,
    override_db,
):
    monkeypatch.setattr(
        main_module,
        "authenticate_user",
        lambda db, email, password: None,
    )

    response = client.post(
        "/login",
        json={
            "email":
                "user@studentlab.test",
            "password":
                "wrong-password",
        },
    )

    assert response.status_code == 401


def test_unverified_user_login_requires_email_verification(
    monkeypatch,
    override_db,
):
    user = unverified_user(
        registration_id=(
            "registration-id"
        ),
    )

    monkeypatch.setattr(
        main_module,
        "authenticate_user",
        lambda db, email, password: user,
    )

    if hasattr(
        main_module,
        "get_email_verification_expires_in",
    ):
        monkeypatch.setattr(
            main_module,
            "get_email_verification_expires_in",
            lambda user: 500,
        )

    response = client.post(
        "/login",
        json={
            "email":
                "user@studentlab.test",
            "password":
                "Password123!",
        },
    )

    assert response.status_code == 200

    body = response.json()

    assert (
        body[
            "authenticated"
        ]
        is False
    )

    assert (
        body[
            "email_verification_required"
        ]
        is True
    )

    assert (
        body[
            "registration_id"
        ]
        == "registration-id"
    )

    assert (
        body[
            "access_token"
        ]
        is None
    )


def test_verified_user_login_returns_access_token(
    monkeypatch,
    override_db,
):
    user = verified_user(
        user_id=50,
    )

    monkeypatch.setattr(
        main_module,
        "authenticate_user",
        lambda db, email, password: user,
    )

    monkeypatch.setattr(
        main_module,
        "create_access_token",
        lambda user_id, secret_key: (
            "login-access-token"
        ),
    )

    response = client.post(
        "/login",
        json={
            "email":
                "user@studentlab.test",
            "password":
                "Password123!",
        },
    )

    assert response.status_code == 200

    body = response.json()

    assert (
        body[
            "authenticated"
        ]
        is True
    )

    assert (
        body[
            "email_verification_required"
        ]
        is False
    )

    assert (
        body[
            "access_token"
        ]
        == "login-access-token"
    )


def test_verified_login_token_uses_authenticated_user_id(
    monkeypatch,
    override_db,
):
    user = verified_user(
        user_id=77,
    )

    captured = {}

    monkeypatch.setattr(
        main_module,
        "authenticate_user",
        lambda db, email, password: user,
    )

    def fake_create_access_token(
        user_id,
        secret_key,
    ):
        captured[
            "user_id"
        ] = user_id

        return "token-77"

    monkeypatch.setattr(
        main_module,
        "create_access_token",
        fake_create_access_token,
    )

    response = client.post(
        "/login",
        json={
            "email":
                "user@studentlab.test",
            "password":
                "Password123!",
        },
    )

    assert response.status_code == 200

    assert (
        captured[
            "user_id"
        ]
        == 77
    )


def test_failed_login_does_not_create_access_token(
    monkeypatch,
    override_db,
):
    called = {
        "token":
            False,
    }

    monkeypatch.setattr(
        main_module,
        "authenticate_user",
        lambda db, email, password: None,
    )

    def fake_create_access_token(
        user_id,
        secret_key,
    ):
        called[
            "token"
        ] = True

        return "token"

    monkeypatch.setattr(
        main_module,
        "create_access_token",
        fake_create_access_token,
    )

    response = client.post(
        "/login",
        json={
            "email":
                "user@studentlab.test",
            "password":
                "wrong-password",
        },
    )

    assert response.status_code == 401

    assert (
        called[
            "token"
        ]
        is False
    )