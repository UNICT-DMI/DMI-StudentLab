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
            "/group-ownership-transfers/{transfer_id}/respond",
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


def test_create_transfer_requires_authentication():
    response = client.post(
        "/groups/1/ownership-transfer",
        json={
            "proposed_owner_id":
                2,
        },
    )

    assert response.status_code in {
        401,
        403,
    }


def test_incoming_transfers_require_authentication():
    response = client.get(
        "/group-ownership-transfers/incoming",
    )

    assert response.status_code in {
        401,
        403,
    }


def test_outgoing_transfers_require_authentication():
    response = client.get(
        "/group-ownership-transfers/outgoing",
    )

    assert response.status_code in {
        401,
        403,
    }


def test_transfer_detail_requires_authentication():
    response = client.get(
        "/group-ownership-transfers/1",
    )

    assert response.status_code in {
        401,
        403,
    }


@pytest.mark.parametrize(
    "action",
    [
        "accept",
        "reject",
        "cancel",
    ],
)
def test_transfer_direct_actions_require_authentication(
    action,
):
    response = client.post(
        (
            "/group-ownership-transfers/1/"
            f"{action}"
        ),
    )

    assert response.status_code in {
        401,
        403,
    }


@pytest.mark.parametrize(
    "action",
    [
        "accept",
        "reject",
    ],
)
def test_transfer_respond_requires_authentication(
    action,
):
    response = client.post(
        "/group-ownership-transfers/1/respond",
        json={
            "action":
                action,
        },
    )

    assert response.status_code in {
        401,
        403,
    }


def test_create_transfer_requires_proposed_owner():
    schema = app.openapi()

    path = (
        "/groups/{group_id}/ownership-transfer"
    )

    operation = schema[
        "paths"
    ][
        path
    ][
        "post"
    ]

    assert (
        "requestBody"
        in operation
    )

    assert (
        operation[
            "requestBody"
        ][
            "required"
        ]
        is True
    )


def test_create_transfer_accepts_account_deletion_request_query_parameter():
    schema = app.openapi()

    operation = schema[
        "paths"
    ][
        "/groups/{group_id}/ownership-transfer"
    ][
        "post"
    ]

    parameters = operation.get(
        "parameters",
        [],
    )

    names = {
        parameter[
            "name"
        ]
        for parameter
        in parameters
    }

    assert (
        "group_id"
        in names
    )

    assert (
        "account_deletion_request_id"
        in names
    )


def test_transfer_detail_requires_transfer_id():
    schema = app.openapi()

    operation = schema[
        "paths"
    ][
        "/group-ownership-transfers/{transfer_id}"
    ][
        "get"
    ]

    parameters = operation.get(
        "parameters",
        [],
    )

    transfer_id = next(
        parameter
        for parameter
        in parameters
        if parameter[
            "name"
        ]
        == "transfer_id"
    )

    assert (
        transfer_id[
            "in"
        ]
        == "path"
    )

    assert (
        transfer_id[
            "required"
        ]
        is True
    )


@pytest.mark.parametrize(
    "path",
    [
        "/group-ownership-transfers/{transfer_id}/respond",
        "/group-ownership-transfers/{transfer_id}/accept",
        "/group-ownership-transfers/{transfer_id}/reject",
        "/group-ownership-transfers/{transfer_id}/cancel",
    ],
)
def test_transfer_action_requires_transfer_id(
    path,
):
    schema = app.openapi()

    operation = schema[
        "paths"
    ][
        path
    ][
        "post"
    ]

    parameters = operation.get(
        "parameters",
        [],
    )

    transfer_id = next(
        parameter
        for parameter
        in parameters
        if parameter[
            "name"
        ]
        == "transfer_id"
    )

    assert (
        transfer_id[
            "in"
        ]
        == "path"
    )

    assert (
        transfer_id[
            "required"
        ]
        is True
    )


def test_respond_route_has_request_body():
    schema = app.openapi()

    operation = schema[
        "paths"
    ][
        "/group-ownership-transfers/{transfer_id}/respond"
    ][
        "post"
    ]

    assert (
        "requestBody"
        in operation
    )

    assert (
        operation[
            "requestBody"
        ][
            "required"
        ]
        is True
    )


@pytest.mark.parametrize(
    "path",
    [
        "/groups/{group_id}/ownership-transfer",
        "/group-ownership-transfers/incoming",
        "/group-ownership-transfers/outgoing",
        "/group-ownership-transfers/{transfer_id}",
        "/group-ownership-transfers/{transfer_id}/respond",
        "/group-ownership-transfers/{transfer_id}/accept",
        "/group-ownership-transfers/{transfer_id}/reject",
        "/group-ownership-transfers/{transfer_id}/cancel",
    ],
)
def test_ownership_transfer_routes_do_not_expose_put(
    path,
):
    schema = app.openapi()

    assert path in schema["paths"]

    assert (
        "put"
        not in schema["paths"][path]
    )


def test_creation_route_does_not_expose_get():
    schema = app.openapi()

    methods = schema[
        "paths"
    ][
        "/groups/{group_id}/ownership-transfer"
    ]

    assert (
        "get"
        not in methods
    )


@pytest.mark.parametrize(
    "path",
    [
        "/group-ownership-transfers/incoming",
        "/group-ownership-transfers/outgoing",
        "/group-ownership-transfers/{transfer_id}",
    ],
)
def test_transfer_read_routes_do_not_expose_post(
    path,
):
    schema = app.openapi()

    assert (
        "post"
        not in schema[
            "paths"
        ][
            path
        ]
    )


@pytest.mark.parametrize(
    "path",
    [
        "/group-ownership-transfers/{transfer_id}/respond",
        "/group-ownership-transfers/{transfer_id}/accept",
        "/group-ownership-transfers/{transfer_id}/reject",
        "/group-ownership-transfers/{transfer_id}/cancel",
    ],
)
def test_transfer_action_routes_do_not_expose_get(
    path,
):
    schema = app.openapi()

    assert (
        "get"
        not in schema[
            "paths"
        ][
            path
        ]
    )


def test_ownership_transfer_service_functions_are_importable():
    from services.group_ownership_transfer import (
        accept_group_ownership_transfer,
        cancel_group_ownership_transfer,
        create_group_ownership_transfer,
        expire_group_ownership_transfer_if_needed,
        get_group_ownership_transfer,
        get_my_incoming_group_ownership_transfers,
        get_my_outgoing_group_ownership_transfers,
        process_expired_group_ownership_transfers,
        reject_group_ownership_transfer,
    )

    functions = [
        accept_group_ownership_transfer,
        cancel_group_ownership_transfer,
        create_group_ownership_transfer,
        expire_group_ownership_transfer_if_needed,
        get_group_ownership_transfer,
        get_my_incoming_group_ownership_transfers,
        get_my_outgoing_group_ownership_transfers,
        process_expired_group_ownership_transfers,
        reject_group_ownership_transfer,
    ]

    assert all(
        callable(
            function,
        )
        for function
        in functions
    )


def test_ownership_transfer_has_expiration_service():
    from services.group_ownership_transfer import (
        expire_group_ownership_transfer_if_needed,
        process_expired_group_ownership_transfers,
    )

    assert callable(
        expire_group_ownership_transfer_if_needed,
    )

    assert callable(
        process_expired_group_ownership_transfers,
    )