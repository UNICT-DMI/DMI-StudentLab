from pathlib import (
    Path,
)

from services.developer_api_contract import (
    build_api_contract,
)

from services.developer_indexer import (
    ArchitectureIndex,
    IndexedEndpoint,
    IndexedFile,
    IndexedFunction,
)


def _file(
    path: str,
    *,
    layer: str,
    functions=None,
    endpoints=None,
):
    return IndexedFile(
        id=path,
        path=path,
        name=Path(path).name,
        extension=Path(path).suffix,
        language="Python",
        layer=layer,
        module="test",
        description="",
        importance="",
        documented=False,
        outdated=False,
        changed=False,
        security_critical=False,
        risk="medium",
        size_bytes=1,
        modified_at=0,
        content_hash="x",
        functions=functions or [],
        endpoints=endpoints or [],
    )


def test_backend_endpoint_contract_is_observed():
    handler = IndexedFunction(
        id="BE/main.py::api_login",
        name="api_login",
        signature=(
            "api_login("
            "request: LoginRequest, "
            "current_user = Depends(...)"
            ")"
        ),
    )

    endpoint = IndexedEndpoint(
        method="POST",
        path="/login",
        function_name="api_login",
        dependencies=[
            "get_current_user",
        ],
        response_model="TokenResponse",
        confidence="observed",
    )

    file = _file(
        "BE/main.py",
        layer="Backend API",
        functions=[
            handler,
        ],
        endpoints=[
            endpoint,
        ],
    )

    index = ArchitectureIndex(
        repository_root=Path("."),
        files=[
            file,
        ],
        changed_paths=set(),
    )

    contract = build_api_contract(
        index,
        path="BE/main.py",
        function_name="api_login",
    )

    assert contract is not None
    assert (
        contract[
            "backend_endpoints"
        ][0]["method"]
        == "POST"
    )
    assert (
        contract[
            "backend_endpoints"
        ][0]["path"]
        == "/login"
    )
    assert (
        contract[
            "backend_endpoints"
        ][0]["confidence"]
        == "observed"
    )
    assert (
        "get_current_user"
        in contract[
            "auth_dependencies"
        ]
    )


def test_service_resolves_calling_endpoint():
    service_function = IndexedFunction(
        id=(
            "BE/services/auth.py"
            "::authenticate_user"
        ),
        name="authenticate_user",
        signature=(
            "authenticate_user("
            "email: str, password: str"
            ")"
        ),
    )

    api_function = IndexedFunction(
        id="BE/main.py::api_login",
        name="api_login",
        signature=(
            "api_login("
            "request: LoginRequest"
            ")"
        ),
        calls=[
            "authenticate_user",
        ],
    )

    endpoint = IndexedEndpoint(
        method="POST",
        path="/login",
        function_name="api_login",
        response_model="TokenResponse",
        confidence="observed",
    )

    service_file = _file(
        "BE/services/auth.py",
        layer="Backend Service",
        functions=[
            service_function,
        ],
    )

    api_file = _file(
        "BE/main.py",
        layer="Backend API",
        functions=[
            api_function,
        ],
        endpoints=[
            endpoint,
        ],
    )

    index = ArchitectureIndex(
        repository_root=Path("."),
        files=[
            service_file,
            api_file,
        ],
        changed_paths=set(),
    )

    contract = build_api_contract(
        index,
        path="BE/services/auth.py",
        function_name="authenticate_user",
    )

    assert contract is not None
    assert len(
        contract[
            "backend_endpoints"
        ]
    ) == 1
    assert (
        contract[
            "backend_endpoints"
        ][0]["function"]
        == "api_login"
    )