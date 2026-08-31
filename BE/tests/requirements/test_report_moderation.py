import pytest

from fastapi.testclient import TestClient

from main import app


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


@pytest.mark.parametrize(
    "path",
    [
        "/admin/user-reports",
        "/admin/user-reports/pending",
        "/admin/profile-error-reports",
        "/admin/profile-error-reports/pending",
        "/admin/group-reports",
        "/admin/group-reports/pending",
        "/admin/group-content-reports",
        "/admin/group-content-reports/pending",
    ],
)
def test_admin_report_lists_require_authentication(
    path,
):
    response = client.get(
        path,
    )

    assert response.status_code in {
        401,
        403,
    }


@pytest.mark.parametrize(
    "path,payload",
    [
        (
            "/admin/user-reports/1/moderation",
            {
                "status":
                    "resolved",
                "moderation_note":
                    "Test",
            },
        ),
        (
            "/admin/profile-error-reports/1/moderation",
            {
                "status":
                    "resolved",
                "resolution_note":
                    "Test",
            },
        ),
        (
            "/admin/group-reports/1/moderation",
            {
                "status":
                    "resolved",
                "moderation_note":
                    "Test",
            },
        ),
        (
            "/admin/group-content-reports/1/moderation",
            {
                "status":
                    "resolved",
                "moderation_action":
                    "none",
                "moderation_note":
                    "Test",
            },
        ),
    ],
)
def test_report_moderation_requires_authentication(
    path,
    payload,
):
    response = client.patch(
        path,
        json=payload,
    )

    assert response.status_code in {
        401,
        403,
    }


@pytest.mark.parametrize(
    "path",
    [
        "/me/user-reports",
        "/me/profile-error-reports",
        "/me/group-reports",
        "/me/group-content-reports",
    ],
)
def test_personal_report_lists_require_authentication(
    path,
):
    response = client.get(
        path,
    )

    assert response.status_code in {
        401,
        403,
    }


@pytest.mark.parametrize(
    "path",
    [
        "/group-reports",
        "/group-content-reports",
    ],
)
def test_report_creation_requires_authentication(
    path,
):
    response = client.post(
        path,
        json={},
    )

    assert response.status_code in {
        401,
        403,
    }


@pytest.mark.parametrize(
    "path,payload",
    [
        (
            "/admin/user-reports/1/moderation",
            {
                "status":
                    "invalid-status",
            },
        ),
        (
            "/admin/profile-error-reports/1/moderation",
            {
                "status":
                    "invalid-status",
            },
        ),
        (
            "/admin/group-reports/1/moderation",
            {
                "status":
                    "invalid-status",
            },
        ),
        (
            "/admin/group-content-reports/1/moderation",
            {
                "status":
                    "invalid-status",
                "moderation_action":
                    "none",
            },
        ),
    ],
)
def test_invalid_moderation_status_does_not_bypass_security(
    path,
    payload,
):
    response = client.patch(
        path,
        json=payload,
    )

    assert response.status_code in {
        401,
        403,
        422,
    }


@pytest.mark.parametrize(
    "action",
    [
        "",
        "invalid",
        "ban-everyone",
        "destroy",
        "root",
    ],
)
def test_invalid_group_content_moderation_action_does_not_bypass_security(
    action,
):
    response = client.patch(
        "/admin/group-content-reports/1/moderation",
        json={
            "status":
                "resolved",
            "moderation_action":
                action,
            "moderation_note":
                "Test",
        },
    )

    assert response.status_code in {
        401,
        403,
        422,
    }


@pytest.mark.parametrize(
    "path",
    [
        "/admin/user-reports",
        "/admin/user-reports/pending",
        "/admin/profile-error-reports",
        "/admin/profile-error-reports/pending",
        "/admin/group-reports",
        "/admin/group-reports/pending",
        "/admin/group-content-reports",
        "/admin/group-content-reports/pending",
    ],
)
def test_admin_report_routes_exist(
    path,
):
    schema = app.openapi()

    assert path in schema["paths"]

    assert (
        "get"
        in schema["paths"][path]
    )


@pytest.mark.parametrize(
    "path",
    [
        "/admin/user-reports/{report_id}/moderation",
        "/admin/profile-error-reports/{report_id}/moderation",
        "/admin/group-reports/{report_id}/moderation",
        "/admin/group-content-reports/{report_id}/moderation",
    ],
)
def test_admin_report_moderation_routes_exist(
    path,
):
    schema = app.openapi()

    assert path in schema["paths"]

    assert (
        "patch"
        in schema["paths"][path]
    )


@pytest.mark.parametrize(
    "path",
    [
        "/group-reports",
        "/group-content-reports",
    ],
)
def test_report_creation_routes_exist(
    path,
):
    schema = app.openapi()

    assert path in schema["paths"]

    assert (
        "post"
        in schema["paths"][path]
    )


@pytest.mark.parametrize(
    "path",
    [
        "/me/user-reports",
        "/me/profile-error-reports",
        "/me/group-reports",
        "/me/group-content-reports",
    ],
)
def test_personal_report_routes_exist(
    path,
):
    schema = app.openapi()

    assert path in schema["paths"]

    assert (
        "get"
        in schema["paths"][path]
    )


def test_group_report_detail_route_exists():
    schema = app.openapi()

    path = (
        "/group-reports/{report_id}"
    )

    assert path in schema["paths"]

    assert (
        "get"
        in schema["paths"][path]
    )


def test_group_content_report_detail_route_exists():
    schema = app.openapi()

    path = (
        "/group-content-reports/{report_id}"
    )

    assert path in schema["paths"]

    assert (
        "get"
        in schema["paths"][path]
    )


def test_user_report_detail_route_exists():
    schema = app.openapi()

    path = (
        "/user-reports/{report_id}"
    )

    assert path in schema["paths"]

    assert (
        "get"
        in schema["paths"][path]
    )


def test_profile_error_report_detail_route_exists():
    schema = app.openapi()

    path = (
        "/profile-error-reports/{report_id}"
    )

    assert path in schema["paths"]

    assert (
        "get"
        in schema["paths"][path]
    )