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

from core.security import (
    get_admin_user,
    get_current_user,
    get_optional_current_user,
)

from main import (
    app,
)

import routes.news as news_routes


client = TestClient(
    app,
)


SENDER_ID = 7

RECIPIENT_ID = 3


@pytest.fixture(
    autouse=True,
)
def news_dir(
    tmp_path,
    monkeypatch,
):
    monkeypatch.setenv(
        "StudentLab_NEWS_DIR",
        str(
            tmp_path,
        ),
    )

    app.dependency_overrides.clear()

    yield tmp_path

    app.dependency_overrides.clear()


def fake_db():
    yield SimpleNamespace()


def user(
    user_id: int,
):
    return SimpleNamespace(
        id=user_id,
        first_name="Anna",
        last_name="Rossi",
        role="student",
        is_active=True,
    )


def authenticate_as(
    current,
):
    app.dependency_overrides[
        get_db
    ] = fake_db

    app.dependency_overrides[
        get_current_user
    ] = lambda: current

    app.dependency_overrides[
        get_optional_current_user
    ] = lambda: current

    app.dependency_overrides[
        get_admin_user
    ] = lambda: current


@pytest.fixture(
    autouse=True,
)
def private_news_stubs(
    monkeypatch,
):
    monkeypatch.setattr(
        news_routes,
        "_require_active_recipient",
        lambda db, recipient_id: user(
            recipient_id,
        ),
    )

    monkeypatch.setattr(
        news_routes,
        "can_send_private_content",
        lambda db, sender_id, recipient_id: True,
    )

    monkeypatch.setattr(
        news_routes,
        "_participant_names",
        lambda db, records: {
            SENDER_ID: "Anna Rossi",
            RECIPIENT_ID: "Bob Verdi",
        },
    )


def wrap(
    suffix: str = "a",
):
    return {
        "epk": f"epk-{suffix}",
        "salt": f"salt-{suffix}",
        "nonce": f"nonce-{suffix}",
        "ct": f"ct-{suffix}",
    }


def send_private(
    wrapped_keys: dict | None = None,
):
    metadata = {
        "v": 1,
        "nonce": "bm9uY2U=",
        "sender_id": SENDER_ID,
        "sender_device": "device-mittente",
        "wrapped_keys": wrapped_keys
        if wrapped_keys is not None
        else {
            f"{SENDER_ID}:device-mittente": wrap(
                "mittente",
            ),
            "compliance:key-1": wrap(
                "compliance",
            ),
        },
    }

    response = client.post(
        "/news/private",
        json={
            "recipient_id": RECIPIENT_ID,
            "ciphertext": "BASE64CIPHERTEXT",
            "algo": "x25519-aesgcm",
            "metadata": metadata,
        },
    )

    assert response.status_code == 201, response.text

    return response.json()


def test_message_without_recipient_wrap_is_pending():
    authenticate_as(
        user(
            SENDER_ID,
        ),
    )

    created = send_private()

    assert created["delivery"] == "pending"

    pending = client.get(
        "/news/private/pending",
    ).json()

    assert pending["total"] == 1
    assert pending["items"][0]["id"] == created["id"]

    assert client.get(
        "/news/private",
    ).json()["total"] == 1

    authenticate_as(
        user(
            RECIPIENT_ID,
        ),
    )

    assert client.get(
        "/news/private",
    ).json()["total"] == 0

    assert client.get(
        f"/news/private/{SENDER_ID}",
    ).json()["total"] == 0

    assert client.get(
        "/news/private/pending",
    ).json()["total"] == 0


def test_message_with_recipient_wrap_is_delivered_immediately():
    authenticate_as(
        user(
            SENDER_ID,
        ),
    )

    created = send_private(
        wrapped_keys={
            f"{SENDER_ID}:device-mittente": wrap(
                "mittente",
            ),
            f"{RECIPIENT_ID}:device-destinatario": wrap(
                "destinatario",
            ),
        },
    )

    assert created["delivery"] == "delivered"

    assert client.get(
        "/news/private/pending",
    ).json()["total"] == 0

    authenticate_as(
        user(
            RECIPIENT_ID,
        ),
    )

    assert client.get(
        "/news/private",
    ).json()["total"] == 1


def test_sender_completes_delivery_by_adding_the_recipient_wrap():
    authenticate_as(
        user(
            SENDER_ID,
        ),
    )

    created = send_private()

    completed = client.post(
        f"/news/private/{RECIPIENT_ID}/{created['id']}/wrap",
        json={
            "wrapped_keys": {
                f"{RECIPIENT_ID}:device-destinatario": wrap(
                    "destinatario",
                ),
            },
        },
    )

    assert completed.status_code == 200, completed.text
    assert completed.json()["delivery"] == "delivered"

    assert client.get(
        "/news/private/pending",
    ).json()["total"] == 0

    authenticate_as(
        user(
            RECIPIENT_ID,
        ),
    )

    conversation = client.get(
        f"/news/private/{SENDER_ID}",
    ).json()

    assert conversation["total"] == 1

    delivered = conversation["items"][0]

    assert delivered["ciphertext"] == "BASE64CIPHERTEXT"
    assert (
        f"{RECIPIENT_ID}:device-destinatario"
        in delivered["metadata"]["wrapped_keys"]
    )


def test_only_the_sender_can_complete_the_delivery():
    authenticate_as(
        user(
            SENDER_ID,
        ),
    )

    created = send_private()

    authenticate_as(
        user(
            RECIPIENT_ID,
        ),
    )

    response = client.post(
        f"/news/private/{SENDER_ID}/{created['id']}/wrap",
        json={
            "wrapped_keys": {
                f"{RECIPIENT_ID}:device-destinatario": wrap(
                    "destinatario",
                ),
            },
        },
    )

    assert response.status_code == 403, response.text


def test_an_existing_wrap_cannot_be_replaced():
    authenticate_as(
        user(
            SENDER_ID,
        ),
    )

    created = send_private()

    response = client.post(
        f"/news/private/{RECIPIENT_ID}/{created['id']}/wrap",
        json={
            "wrapped_keys": {
                f"{SENDER_ID}:device-mittente": wrap(
                    "sostituita",
                ),
            },
        },
    )

    assert response.status_code == 400, response.text
    assert "già presente" in response.json()["detail"]


def test_wrapped_keys_payload_is_validated():
    authenticate_as(
        user(
            SENDER_ID,
        ),
    )

    created = send_private()

    empty = client.post(
        f"/news/private/{RECIPIENT_ID}/{created['id']}/wrap",
        json={
            "wrapped_keys": {},
        },
    )

    assert empty.status_code == 422

    incomplete = client.post(
        f"/news/private/{RECIPIENT_ID}/{created['id']}/wrap",
        json={
            "wrapped_keys": {
                f"{RECIPIENT_ID}:device-destinatario": {
                    "epk": "epk",
                },
            },
        },
    )

    assert incomplete.status_code == 422


def test_pending_path_is_not_read_as_a_user_id():
    authenticate_as(
        user(
            SENDER_ID,
        ),
    )

    response = client.get(
        "/news/private/pending",
    )

    assert response.status_code == 200, response.text
