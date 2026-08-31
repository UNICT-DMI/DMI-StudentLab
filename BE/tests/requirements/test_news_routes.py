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


def student(
    user_id: int = 100,
):
    return SimpleNamespace(
        id=user_id,
        first_name="Anna",
        last_name="Rossi",
        role="student",
        is_active=True,
    )


def admin():
    return SimpleNamespace(
        id=200,
        first_name="Marco",
        last_name="Bianchi",
        role="admin",
        is_active=True,
    )


def authenticate_as(
    user,
    admin_user=None,
):
    app.dependency_overrides[
        get_db
    ] = fake_db

    app.dependency_overrides[
        get_current_user
    ] = lambda: user

    app.dependency_overrides[
        get_optional_current_user
    ] = lambda: user

    app.dependency_overrides[
        get_admin_user
    ] = lambda: (
        admin_user
        if admin_user is not None
        else user
    )


def allow_group_access(
    monkeypatch,
    group_id: int = 12,
):
    monkeypatch.setattr(
        news_routes,
        "_require_group_access",
        lambda db, gid, user: SimpleNamespace(
            id=gid,
            name="Reti",
        ),
    )


@pytest.mark.parametrize(
    "method,path",
    [
        (
            "post",
            "/news/avvisi",
        ),
        (
            "get",
            "/news/groups/12",
        ),
        (
            "post",
            "/news/groups/12",
        ),
        (
            "get",
            "/news/private",
        ),
        (
            "post",
            "/news/private",
        ),
    ],
)
def test_news_endpoints_reject_anonymous_user(
    method,
    path,
):
    if method == "post":
        response = client.post(
            path,
            json={},
        )
    else:
        response = client.get(
            path,
        )

    assert response.status_code in {
        401,
        403,
    }, (
        f"{method.upper()} {path} accessibile "
        f"senza autenticazione: "
        f"{response.status_code}"
    )


def route_dependency_names(
    path: str,
    method: str,
) -> set[str]:
    names = set()

    for route in news_routes.router.routes:
        if getattr(
            route,
            "path",
            None,
        ) != path or method not in (
            getattr(
                route,
                "methods",
                None,
            )
            or set()
        ):
            continue

        for dependency in route.dependant.dependencies:
            names.add(
                getattr(
                    dependency.call,
                    "__name__",
                    "",
                ),
            )

    return names


@pytest.mark.parametrize(
    "path,method,required_dependency",
    [
        (
            "/news/avvisi",
            "POST",
            "get_admin_user",
        ),
        (
            "/news/groups/{group_id}",
            "POST",
            "get_current_user",
        ),
        (
            "/news/private",
            "POST",
            "get_current_user",
        ),
        (
            "/news/private",
            "GET",
            "get_current_user",
        ),
    ],
)
def test_news_routes_declare_required_dependency(
    path,
    method,
    required_dependency,
):
    names = route_dependency_names(
        path,
        method,
    )

    assert required_dependency in names, (
        f"{method} {path} deve dipendere da "
        f"{required_dependency}; "
        f"dipendenze trovate: {names}"
    )


def test_avviso_create_list_and_reply():
    authenticate_as(
        admin(),
    )

    created = client.post(
        "/news/avvisi",
        json={
            "title": "Manutenzione",
            "content": "Domani stop",
        },
    )

    assert created.status_code == 201

    body = created.json()

    assert body["write_token"]
    assert body["can_delete"] is True
    assert body["author_name"] == "Marco Bianchi"

    listed = client.get(
        "/news/avvisi",
    )

    assert listed.status_code == 200
    assert listed.json()["total"] == 1
    assert (
        listed.json()["items"][0][
            "write_token"
        ]
        is None
    )

    reply = client.post(
        f"/news/avvisi/{body['id']}/replies",
        json={
            "content": "ok",
        },
    )

    assert reply.status_code == 201

    detail = client.get(
        f"/news/avvisi/{body['id']}",
    )

    assert (
        detail.json()["replies"][0][
            "content"
        ]
        == "ok"
    )


def test_avviso_detail_returns_404_when_missing():
    authenticate_as(
        student(),
    )

    response = client.get(
        "/news/avvisi/inesistente",
    )

    assert response.status_code == 404


def test_delete_avviso_requires_valid_write_token():
    authenticate_as(
        admin(),
    )

    body = client.post(
        "/news/avvisi",
        json={
            "title": "T",
            "content": "C",
        },
    ).json()

    without_token = client.delete(
        f"/news/avvisi/{body['id']}",
    )

    assert without_token.status_code == 403

    wrong_owner = client.delete(
        f"/news/avvisi/{body['id']}",
        headers={
            "X-News-Write-Token": "wrong",
        },
    )

    assert wrong_owner.status_code == 403

    deleted = client.delete(
        f"/news/avvisi/{body['id']}",
        headers={
            "X-News-Write-Token": body[
                "write_token"
            ],
        },
    )

    assert deleted.status_code == 200
    assert client.get(
        "/news/avvisi",
    ).json()["total"] == 0


def test_group_news_scoped_to_group(
    monkeypatch,
):
    authenticate_as(
        student(),
    )

    allow_group_access(
        monkeypatch,
    )

    created = client.post(
        "/news/groups/12",
        json={
            "content": "ciao gruppo",
        },
    )

    assert created.status_code == 201
    assert created.json()["group_name"] == "Reti"

    assert client.get(
        "/news/groups/12",
    ).json()["total"] == 1

    assert client.get(
        "/news/groups/99",
    ).json()["total"] == 0


def test_group_news_forbidden_for_non_member(
    monkeypatch,
):
    authenticate_as(
        student(),
    )

    def deny(
        db,
        group_id,
        user,
    ):
        raise news_routes.HTTPException(
            status_code=403,
            detail="Non appartieni a questo gruppo.",
        )

    monkeypatch.setattr(
        news_routes,
        "_require_group_access",
        deny,
    )

    assert client.get(
        "/news/groups/12",
    ).status_code == 403

    assert client.post(
        "/news/groups/12",
        json={
            "content": "x",
        },
    ).status_code == 403


def test_private_news_stores_ciphertext_only(
    monkeypatch,
    news_dir,
):
    sender = student(
        7,
    )

    authenticate_as(
        sender,
    )

    monkeypatch.setattr(
        news_routes,
        "_require_active_recipient",
        lambda db, recipient_id: student(
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
            7: "Anna Rossi",
            3: "Bob Verdi",
        },
    )

    created = client.post(
        "/news/private",
        json={
            "recipient_id": 3,
            "ciphertext": "BASE64CIPHERTEXT",
            "algo": "x25519-aesgcm",
        },
    )

    assert created.status_code == 201

    body = created.json()

    assert body["conversation_id"] == "3_7"
    assert body["write_token"]
    assert body["sender_name"] == "Anna Rossi"
    assert body["recipient_name"] == "Bob Verdi"

    stored = (
        news_dir
        / "private"
        / "3_7"
        / f"{body['id']}.json"
    ).read_text(
        encoding="utf-8",
    )

    assert "BASE64CIPHERTEXT" in stored

    inbox = client.get(
        "/news/private",
    ).json()

    assert inbox["total"] == 1
    assert inbox["items"][0]["sender_name"] == "Anna Rossi"

    conversation = client.get(
        "/news/private/3",
    ).json()

    assert conversation["total"] == 1
    assert conversation["items"][0]["recipient_name"] == "Bob Verdi"

    assert client.get(
        "/news/private/999",
    ).json()["total"] == 0

    deleted = client.delete(
        f"/news/private/3/{body['id']}",
        headers={
            "X-News-Write-Token": body[
                "write_token"
            ],
        },
    )

    assert deleted.status_code == 200


def test_private_news_blocked_recipient_is_forbidden(
    monkeypatch,
):
    authenticate_as(
        student(
            7,
        ),
    )

    monkeypatch.setattr(
        news_routes,
        "_require_active_recipient",
        lambda db, recipient_id: student(
            recipient_id,
        ),
    )

    monkeypatch.setattr(
        news_routes,
        "can_send_private_content",
        lambda db, sender_id, recipient_id: False,
    )

    response = client.post(
        "/news/private",
        json={
            "recipient_id": 3,
            "ciphertext": "CIPHER",
            "algo": "x25519-aesgcm",
        },
    )

    assert response.status_code == 403


def test_private_news_rejects_self_recipient():
    authenticate_as(
        student(
            7,
        ),
    )

    response = client.post(
        "/news/private",
        json={
            "recipient_id": 7,
            "ciphertext": "CIPHER",
            "algo": "x25519-aesgcm",
        },
    )

    assert response.status_code == 400
