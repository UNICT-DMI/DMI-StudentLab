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
    get_verified_teacher_user,
)


from main import (
    app,
)


import routes.notification as notification_routes


client = TestClient(
    app,
)


@pytest.fixture(
    autouse=True,
)
def clear_dependency_overrides():
    app.dependency_overrides.clear()

    yield

    app.dependency_overrides.clear()



def fake_db():
    yield SimpleNamespace()


def fake_authenticated_user():
    return SimpleNamespace(
        id=100,
        role="student",
        is_active=True,
    )


def fake_admin_user():
    return SimpleNamespace(
        id=200,
        role="admin",
        is_active=True,
    )


def fake_verified_teacher():
    return SimpleNamespace(
        id=300,
        role="teacher",
        teacher_verification_status=(
            "verified"
        ),
        is_active=True,
    )



@pytest.mark.parametrize(
    "path",
    [
        "/me",
        "/notifications",
        "/notifications/unread-count",
        "/me/account-deletion",
        "/me/group-reports",
        "/me/group-content-reports",
        "/me/profile-error-reports",
        "/me/teacher_assignments",
        "/me/user-reports",
    ],
)
def test_authenticated_endpoints_reject_anonymous_user(
    path,
):
    response = client.get(
        path,
    )

    assert response.status_code in {
        401,
        403,
    }, (
        f"{path} è accessibile senza autenticazione: "
        f"status={response.status_code}, "
        f"body={response.text}"
    )




@pytest.mark.parametrize(
    "path",
    [
        "/admin/access",
        "/admin/users",
        "/admin/grades/pending",
        "/admin/teachers/pending",
        "/admin/reviews",
        "/admin/group-reports",
        "/admin/group-content-reports",
        "/admin/account-deletions",
        "/admin/profile-error-reports",
        "/admin/user-reports",
        "/admin/teacher_assignments/pending",
        "/admin/material_publications",
        "/admin/public_materials",
    ],
)
def test_admin_endpoints_reject_anonymous_user(
    path,
):
    response = client.get(
        path,
    )

    assert response.status_code in {
        401,
        403,
    }, (
        f"Endpoint Admin accessibile senza login: "
        f"{path}; "
        f"status={response.status_code}"
    )




@pytest.mark.parametrize(
    "path",
    [
        "/teacher/access",
        "/teacher/subjects",
        "/teacher/materials",
    ],
)
def test_teacher_endpoints_reject_anonymous_user(
    path,
):
    response = client.get(
        path,
    )

    assert response.status_code in {
        401,
        403,
    }, (
        f"Endpoint Teacher accessibile senza login: "
        f"{path}; "
        f"status={response.status_code}"
    )



def test_admin_can_access_admin_area():
    app.dependency_overrides[
        get_admin_user
    ] = fake_admin_user

    response = client.get(
        "/admin/access",
    )

    assert response.status_code == 200

    assert response.json() == {
        "authorized":
            True,
    }




def test_verified_teacher_can_access_teacher_area():
    app.dependency_overrides[
        get_verified_teacher_user
    ] = fake_verified_teacher

    response = client.get(
        "/teacher/access",
    )

    assert response.status_code == 200

    assert response.json() == {
        "authorized":
            True,
    }



def test_authenticated_user_can_get_notification_unread_count(
    monkeypatch,
):
    app.dependency_overrides[
        get_current_user
    ] = fake_authenticated_user

    app.dependency_overrides[
        get_db
    ] = fake_db

    def fake_get_unread_notification_count(
        db,
        *,
        current_user,
    ):
        assert current_user.id == 100

        return 3

    monkeypatch.setattr(
        notification_routes,
        "get_unread_notification_count",
        fake_get_unread_notification_count,
    )

    response = client.get(
        "/notifications/unread-count",
    )

    assert response.status_code == 200

    assert response.json() == {
        "unread_count":
            3,
    }




def test_root_endpoint_remains_public():
    response = client.get(
        "/",
    )

    assert response.status_code == 200

    assert response.json() == {
        "status":
            "Server attivo.",
    }


@pytest.mark.parametrize(
    "method,path",
    [
        (
            "GET",
            "/notifications/unread-count",
        ),
        (
            "POST",
            "/group-reports",
        ),
        (
            "POST",
            "/group-content-reports",
        ),
        (
            "GET",
            "/me/account-deletion",
        ),
        (
            "POST",
            "/me/account-deletion",
        ),
        (
            "POST",
            "/me/account-deletion/cancel",
        ),
        (
            "POST",
            "/me/account-deletion/complete",
        ),
    ],
)
def test_included_router_sensitive_operations_reject_anonymous_user(
    method,
    path,
):
    response = client.request(
        method,
        path,
        json={},
    )

    assert response.status_code in {
        401,
        403,
    }, (
        f"{method} {path} non ha bloccato "
        f"un utente anonimo: "
        f"status={response.status_code}, "
        f"body={response.text}"
    )