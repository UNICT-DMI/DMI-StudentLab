from types import SimpleNamespace

import pytest

from fastapi.testclient import TestClient

from core.database import get_db
from core.security import (
    get_admin_user,
    get_current_user,
    get_verified_teacher_user,
)
from main import app


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
def student_user():
    return SimpleNamespace(
        id=10,
        role="student",
        email_verified_at=object(),
        is_active=True,
    )


@pytest.fixture
def teacher_user():
    return SimpleNamespace(
        id=20,
        role="teacher",
        teacher_verification_status="verified",
        email_verified_at=object(),
        is_active=True,
    )


@pytest.fixture
def admin_user():
    return SimpleNamespace(
        id=30,
        role="admin",
        email_verified_at=object(),
        is_active=True,
    )


@pytest.fixture
def override_student(
    fake_db,
    student_user,
):
    def override_db():
        yield fake_db

    def override_current_user():
        return student_user

    app.dependency_overrides[
        get_db
    ] = override_db

    app.dependency_overrides[
        get_current_user
    ] = override_current_user

    return student_user


@pytest.fixture
def override_teacher(
    fake_db,
    teacher_user,
):
    def override_db():
        yield fake_db

    def override_verified_teacher():
        return teacher_user

    app.dependency_overrides[
        get_db
    ] = override_db

    app.dependency_overrides[
        get_verified_teacher_user
    ] = override_verified_teacher

    return teacher_user


@pytest.fixture
def override_admin(
    fake_db,
    admin_user,
):
    def override_db():
        yield fake_db

    def override_admin_user():
        return admin_user

    app.dependency_overrides[
        get_db
    ] = override_db

    app.dependency_overrides[
        get_admin_user
    ] = override_admin_user

    return admin_user


@pytest.mark.parametrize(
    "method,path",
    [
        (
            "GET",
            "/teacher/access",
        ),
        (
            "GET",
            "/teacher/subjects",
        ),
        (
            "GET",
            "/teacher/materials",
        ),
        (
            "POST",
            "/teacher/materials/upload-request",
        ),
        (
            "POST",
            "/teacher/materials/complete",
        ),
    ],
)
def test_teacher_material_routes_require_authentication(
    method,
    path,
):
    if method == "GET":
        response = client.get(
            path,
        )
    else:
        response = client.post(
            path,
            json={},
        )

    assert response.status_code in {
        401,
        403,
        422,
    }


@pytest.mark.parametrize(
    "path",
    [
        "/teacher/access",
        "/teacher/subjects",
        "/teacher/materials",
    ],
)
def test_teacher_get_routes_exist(
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
        "/teacher/materials/upload-request",
        "/teacher/materials/complete",
    ],
)
def test_teacher_post_routes_exist(
    path,
):
    schema = app.openapi()

    assert path in schema["paths"]

    assert (
        "post"
        in schema["paths"][path]
    )


@pytest.mark.parametrize(
    "method,path",
    [
        (
            "GET",
            "/teacher/materials/{material_id}",
        ),
        (
            "PATCH",
            "/teacher/materials/{material_id}",
        ),
        (
            "DELETE",
            "/teacher/materials/{material_id}",
        ),
    ],
)
def test_teacher_material_detail_routes_exist(
    method,
    path,
):
    schema = app.openapi()

    assert path in schema["paths"]

    assert (
        method.lower()
        in schema["paths"][path]
    )


def test_subject_teacher_materials_route_exists():
    schema = app.openapi()

    path = (
        "/subjects/{subject_id}/teacher-materials"
    )

    assert path in schema["paths"]

    assert (
        "get"
        in schema["paths"][path]
    )


@pytest.mark.parametrize(
    "path",
    [
        "/admin/material_publications",
        "/admin/material_publications/pending",
    ],
)
def test_admin_material_publication_routes_exist(
    path,
):
    schema = app.openapi()

    assert path in schema["paths"]

    assert (
        "get"
        in schema["paths"][path]
    )


@pytest.mark.parametrize(
    "method,path",
    [
        (
            "GET",
            "/admin/material_publications/{request_id}",
        ),
        (
            "GET",
            "/admin/material_publications/{request_id}/file",
        ),
        (
            "GET",
            "/admin/material_publications/{request_id}/possible-duplicate",
        ),
        (
            "GET",
            "/admin/material_publications/{request_id}/possible-duplicate/file",
        ),
        (
            "PATCH",
            "/admin/material_publications/{request_id}/duplicate",
        ),
        (
            "POST",
            "/admin/material_publications/{request_id}/approve",
        ),
        (
            "POST",
            "/admin/material_publications/{request_id}/reject",
        ),
    ],
)
def test_admin_material_publication_detail_routes_exist(
    method,
    path,
):
    schema = app.openapi()

    assert path in schema["paths"]

    assert (
        method.lower()
        in schema["paths"][path]
    )


@pytest.mark.parametrize(
    "path",
    [
        "/admin/material_publications",
        "/admin/material_publications/pending",
    ],
)
def test_admin_material_publication_routes_require_authentication(
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
    "method,path,payload",
    [
        (
            "PATCH",
            "/admin/material_publications/1/duplicate",
            {},
        ),
        (
            "POST",
            "/admin/material_publications/1/approve",
            {},
        ),
        (
            "POST",
            "/admin/material_publications/1/reject",
            {},
        ),
    ],
)
def test_admin_material_publication_actions_require_authentication(
    method,
    path,
    payload,
):
    if method == "PATCH":
        response = client.patch(
            path,
            json=payload,
        )
    else:
        response = client.post(
            path,
            json=payload,
        )

    assert response.status_code in {
        401,
        403,
        422,
    }


@pytest.mark.parametrize(
    "method,path",
    [
        (
            "POST",
            "/material_publication/upload-request",
        ),
        (
            "POST",
            "/material_publication/complete",
        ),
        (
            "GET",
            "/material_publication/me",
        ),
    ],
)
def test_user_material_publication_routes_exist(
    method,
    path,
):
    schema = app.openapi()

    assert path in schema["paths"]

    assert (
        method.lower()
        in schema["paths"][path]
    )


def test_user_material_publication_detail_route_exists():
    schema = app.openapi()

    path = (
        "/material_publication/me/{request_id}"
    )

    assert path in schema["paths"]

    assert (
        "get"
        in schema["paths"][path]
    )


@pytest.mark.parametrize(
    "path",
    [
        "/material_publication/upload-request",
        "/material_publication/complete",
    ],
)
def test_user_material_publication_post_requires_authentication(
    path,
):
    response = client.post(
        path,
        json={},
    )

    assert response.status_code in {
        401,
        403,
        422,
    }


def test_user_material_publication_list_requires_authentication():
    response = client.get(
        "/material_publication/me",
    )

    assert response.status_code in {
        401,
        403,
    }


@pytest.mark.parametrize(
    "method,path",
    [
        (
            "POST",
            "/group_material_upload_request/{group_id}",
        ),
        (
            "POST",
            "/group_material_complete/{group_id}",
        ),
        (
            "GET",
            "/group_materials/{group_id}",
        ),
        (
            "GET",
            "/group_material/{material_id}",
        ),
        (
            "DELETE",
            "/remove_group_material/{material_id}",
        ),
    ],
)
def test_group_material_routes_exist(
    method,
    path,
):
    schema = app.openapi()

    assert path in schema["paths"]

    assert (
        method.lower()
        in schema["paths"][path]
    )


def test_group_material_upload_requires_authentication():
    response = client.post(
        "/group_material_upload_request/1",
        json={
            "uploaded_by":
                10,
            "original_name":
                "test.pdf",
            "mime_type":
                "application/pdf",
            "size":
                100,
            "file_hash":
                (
                    "a"
                    * 64
                ),
        },
    )

    assert response.status_code in {
        401,
        403,
        404,
        422,
    }


def test_group_material_complete_requires_authentication():
    response = client.post(
        "/group_material_complete/1",
        json={},
    )

    assert response.status_code in {
        401,
        403,
        404,
        422,
    }


def test_group_material_delete_requires_authentication():
    response = client.delete(
        "/remove_group_material/999999",
    )

    assert response.status_code in {
        401,
        403,
        404,
    }


def test_teacher_access_with_verified_teacher(
    override_teacher,
):
    response = client.get(
        "/teacher/access",
    )

    assert response.status_code == 200


def test_material_upload_request_rejects_missing_body_for_teacher(
    override_teacher,
):
    response = client.post(
        "/teacher/materials/upload-request",
        json={},
    )

    assert response.status_code == 422


def test_material_complete_rejects_missing_body_for_teacher(
    override_teacher,
):
    response = client.post(
        "/teacher/materials/complete",
        json={},
    )

    assert response.status_code == 422


def test_material_detail_invalid_id_requires_teacher_authentication():
    response = client.get(
        "/teacher/materials/999999",
    )

    assert response.status_code in {
        401,
        403,
    }


def test_material_update_invalid_id_requires_teacher_authentication():
    response = client.patch(
        "/teacher/materials/999999",
        json={},
    )

    assert response.status_code in {
        401,
        403,
        422,
    }


def test_material_delete_invalid_id_requires_teacher_authentication():
    response = client.delete(
        "/teacher/materials/999999",
    )

    assert response.status_code in {
        401,
        403,
    }


def test_subject_teacher_materials_requires_authentication_or_is_public():
    response = client.get(
        "/subjects/1/teacher-materials",
    )

    assert response.status_code in {
        200,
        401,
        403,
        404,
    }


def test_teacher_material_routes_do_not_expose_put():
    schema = app.openapi()

    paths = [
        "/teacher/materials",
        "/teacher/materials/upload-request",
        "/teacher/materials/complete",
        "/teacher/materials/{material_id}",
    ]

    for path in paths:
        assert path in schema["paths"]

        assert (
            "put"
            not in schema["paths"][path]
        )


def test_material_publication_routes_do_not_expose_put():
    schema = app.openapi()

    paths = [
        "/material_publication/upload-request",
        "/material_publication/complete",
        "/material_publication/me",
        "/admin/material_publications",
    ]

    for path in paths:
        assert path in schema["paths"]

        assert (
            "put"
            not in schema["paths"][path]
        )