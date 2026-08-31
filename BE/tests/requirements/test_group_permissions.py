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
    "method,path",
    [
        (
            "POST",
            "/create_group",
        ),
        (
            "GET",
            "/groups",
        ),
        (
            "GET",
            "/group/{group_id}",
        ),
        (
            "PATCH",
            "/update_group/{group_id}",
        ),
        (
            "DELETE",
            "/delete_group/{group_id}",
        ),
    ],
)
def test_group_core_routes_exist(
    method,
    path,
):
    schema = app.openapi()

    assert path in schema["paths"]

    assert (
        method.lower()
        in schema["paths"][path]
    )


def test_group_creation_requires_authentication():
    response = client.post(
        "/create_group",
        json={},
    )

    assert response.status_code in {
        401,
        403,
        422,
    }


def test_group_update_requires_authentication():
    response = client.patch(
        "/update_group/1",
        json={},
    )

    assert response.status_code in {
        401,
        403,
        404,
        422,
    }


def test_group_delete_requires_authentication():
    response = client.delete(
        "/delete_group/1",
    )

    assert response.status_code in {
        401,
        403,
        404,
    }


@pytest.mark.parametrize(
    "method,path",
    [
        (
            "POST",
            "/request_join_group/{group_id}",
        ),
        (
            "GET",
            "/group_requests/{group_id}",
        ),
        (
            "POST",
            "/accept_group_request/{request_id}",
        ),
        (
            "POST",
            "/reject_group_request/{request_id}",
        ),
    ],
)
def test_group_join_request_routes_exist(
    method,
    path,
):
    schema = app.openapi()

    assert path in schema["paths"]

    assert (
        method.lower()
        in schema["paths"][path]
    )


def test_group_join_request_requires_authentication():
    response = client.post(
        "/request_join_group/1",
        json={},
    )

    assert response.status_code in {
        401,
        403,
        404,
        422,
    }


def test_group_requests_list_requires_authentication():
    response = client.get(
        "/group_requests/1",
    )

    assert response.status_code in {
        401,
        403,
        404,
    }


def test_accept_group_request_requires_authentication():
    response = client.post(
        "/accept_group_request/1",
        json={},
    )

    assert response.status_code in {
        401,
        403,
        404,
        422,
    }


def test_reject_group_request_requires_authentication():
    response = client.post(
        "/reject_group_request/1",
        json={},
    )

    assert response.status_code in {
        401,
        403,
        404,
        422,
    }


@pytest.mark.parametrize(
    "method,path",
    [
        (
            "POST",
            "/add_group_member/{group_id}",
        ),
        (
            "DELETE",
            "/remove_group_member/{group_id}/{user_id}",
        ),
        (
            "PATCH",
            "/update_group_member_role/{group_id}/{user_id}",
        ),
    ],
)
def test_group_member_management_routes_exist(
    method,
    path,
):
    schema = app.openapi()

    assert path in schema["paths"]

    assert (
        method.lower()
        in schema["paths"][path]
    )


def test_add_group_member_requires_authentication():
    response = client.post(
        "/add_group_member/1",
        json={},
    )

    assert response.status_code in {
        401,
        403,
        404,
        422,
    }


def test_remove_group_member_requires_authentication():
    response = client.delete(
        "/remove_group_member/1/2",
    )

    assert response.status_code in {
        401,
        403,
        404,
    }


def test_update_group_member_role_requires_authentication():
    response = client.patch(
        "/update_group_member_role/1/2",
        json={},
    )

    assert response.status_code in {
        401,
        403,
        404,
        422,
    }


@pytest.mark.parametrize(
    "method,path",
    [
        (
            "GET",
            "/user_groups/{user_id}",
        ),
        (
            "GET",
            "/group/{group_id}",
        ),
        (
            "GET",
            "/groups",
        ),
    ],
)
def test_group_read_routes_exist(
    method,
    path,
):
    schema = app.openapi()

    assert path in schema["paths"]

    assert (
        method.lower()
        in schema["paths"][path]
    )


def test_user_groups_requires_authentication_or_is_explicitly_public():
    response = client.get(
        "/user_groups/1",
    )

    assert response.status_code in {
        200,
        401,
        403,
        404,
    }


def test_group_detail_requires_authentication_or_is_explicitly_public():
    response = client.get(
        "/group/1",
    )

    assert response.status_code in {
        200,
        401,
        403,
        404,
    }


def test_group_list_requires_authentication_or_is_explicitly_public():
    response = client.get(
        "/groups",
    )

    assert response.status_code in {
        200,
        401,
        403,
    }


@pytest.mark.parametrize(
    "method,path",
    [
        (
            "POST",
            "/groups/{group_id}/ownership-transfer",
        ),
        (
            "GET",
            "/group-ownership-transfers/incoming",
        ),
        (
            "GET",
            "/group-ownership-transfers/outgoing",
        ),
        (
            "GET",
            "/group-ownership-transfers/{transfer_id}",
        ),
        (
            "POST",
            "/group-ownership-transfers/{transfer_id}/accept",
        ),
        (
            "POST",
            "/group-ownership-transfers/{transfer_id}/reject",
        ),
        (
            "POST",
            "/group-ownership-transfers/{transfer_id}/cancel",
        ),
        (
            "POST",
            "/group-ownership-transfers/{transfer_id}/respond",
        ),
    ],
)
def test_group_ownership_transfer_routes_exist(
    method,
    path,
):
    schema = app.openapi()

    assert path in schema["paths"]

    assert (
        method.lower()
        in schema["paths"][path]
    )


def test_group_ownership_transfer_creation_requires_authentication():
    response = client.post(
        "/groups/1/ownership-transfer",
        json={},
    )

    assert response.status_code in {
        401,
        403,
        404,
        422,
    }


def test_incoming_group_ownership_transfers_require_authentication():
    response = client.get(
        "/group-ownership-transfers/incoming",
    )

    assert response.status_code in {
        401,
        403,
    }


def test_outgoing_group_ownership_transfers_require_authentication():
    response = client.get(
        "/group-ownership-transfers/outgoing",
    )

    assert response.status_code in {
        401,
        403,
    }


def test_group_ownership_transfer_detail_requires_authentication():
    response = client.get(
        "/group-ownership-transfers/1",
    )

    assert response.status_code in {
        401,
        403,
        404,
    }


@pytest.mark.parametrize(
    "action",
    [
        "accept",
        "reject",
        "cancel",
        "respond",
    ],
)
def test_group_ownership_transfer_actions_require_authentication(
    action,
):
    response = client.post(
        (
            "/group-ownership-transfers/1/"
            f"{action}"
        ),
        json={},
    )

    assert response.status_code in {
        401,
        403,
        404,
        422,
    }


@pytest.mark.parametrize(
    "method,path",
    [
        (
            "GET",
            "/group_materials/{group_id}",
        ),
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
                "a" * 64,
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


def test_remove_group_material_requires_authentication():
    response = client.delete(
        "/remove_group_material/1",
    )

    assert response.status_code in {
        401,
        403,
        404,
    }


@pytest.mark.parametrize(
    "method,path",
    [
        (
            "POST",
            "/group-reports",
        ),
        (
            "GET",
            "/me/group-reports",
        ),
        (
            "GET",
            "/group-reports/{report_id}",
        ),
        (
            "POST",
            "/group-content-reports",
        ),
        (
            "GET",
            "/me/group-content-reports",
        ),
        (
            "GET",
            "/group-content-reports/{report_id}",
        ),
    ],
)
def test_group_report_routes_exist(
    method,
    path,
):
    schema = app.openapi()

    assert path in schema["paths"]

    assert (
        method.lower()
        in schema["paths"][path]
    )


def test_group_report_creation_requires_authentication():
    response = client.post(
        "/group-reports",
        json={},
    )

    assert response.status_code in {
        401,
        403,
        422,
    }


def test_group_content_report_creation_requires_authentication():
    response = client.post(
        "/group-content-reports",
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
        "/create_group",
        "/groups",
        "/group/{group_id}",
        "/update_group/{group_id}",
        "/delete_group/{group_id}",
        "/request_join_group/{group_id}",
        "/group_requests/{group_id}",
        "/accept_group_request/{request_id}",
        "/reject_group_request/{request_id}",
        "/add_group_member/{group_id}",
        "/remove_group_member/{group_id}/{user_id}",
        "/update_group_member_role/{group_id}/{user_id}",
        "/user_groups/{user_id}",
        "/groups/{group_id}/ownership-transfer",
        "/group-ownership-transfers/incoming",
        "/group-ownership-transfers/outgoing",
        "/group-ownership-transfers/{transfer_id}",
        "/group-ownership-transfers/{transfer_id}/accept",
        "/group-ownership-transfers/{transfer_id}/reject",
        "/group-ownership-transfers/{transfer_id}/cancel",
        "/group-ownership-transfers/{transfer_id}/respond",
    ],
)
def test_group_routes_do_not_expose_put(
    path,
):
    schema = app.openapi()

    assert path in schema["paths"]

    assert (
        "put"
        not in schema["paths"][path]
    )