from __future__ import annotations

from dataclasses import (
    dataclass,
)

from services.developer_indexer import (
    ArchitectureIndex,
    IndexedEndpoint,
    IndexedFile,
    IndexedFunction,
)


@dataclass(
    frozen=True,
)
class ApiContractMatch:
    file: str
    function: str
    method: str | None
    path: str | None
    auth_dependencies: tuple[str, ...]
    request_schema: str | None
    response_schema: str | None
    confidence: str
    security_critical: bool


def _normalize(
    value: str,
) -> str:
    return (
        value
        .strip()
        .lower()
        .replace("-", "_")
    )


def _function_by_name(
    file: IndexedFile,
    name: str,
) -> IndexedFunction | None:
    normalized = _normalize(
        name,
    )

    for function in file.functions:
        if (
            _normalize(
                function.name,
            )
            == normalized
        ):
            return function

    return None


def _request_schema_from_function(
    function: IndexedFunction,
) -> str | None:
    for item in function.inputs:
        normalized = item.lower()

        if normalized in {
            "self",
            "cls",
            "db",
            "current_user",
            "user",
            "request",
        }:
            continue

    signature = function.signature

    if "(" not in signature:
        return None

    arguments = (
        signature
        .split(
            "(",
            1,
        )[1]
        .rsplit(
            ")",
            1,
        )[0]
    )

    for raw in arguments.split(
        ",",
    ):
        item = raw.strip()

        if ":" not in item:
            continue

        name, annotation = (
            item.split(
                ":",
                1,
            )
        )

        name = name.strip()
        annotation = (
            annotation
            .split(
                "=",
                1,
            )[0]
            .strip()
        )

        if name in {
            "db",
            "current_user",
            "user",
        }:
            continue

        if annotation in {
            "str",
            "int",
            "float",
            "bool",
            "Session",
            "Request",
        }:
            continue

        if annotation:
            return annotation

    return None


def _endpoint_for_function(
    file: IndexedFile,
    function_name: str,
) -> IndexedEndpoint | None:
    for endpoint in file.endpoints:
        if (
            endpoint.function_name
            == function_name
        ):
            return endpoint

    return None


def _direct_callers(
    index: ArchitectureIndex,
    function_name: str,
) -> list[
    tuple[
        IndexedFile,
        IndexedFunction,
    ]
]:
    normalized = _normalize(
        function_name,
    )

    result: list[
        tuple[
            IndexedFile,
            IndexedFunction,
        ]
    ] = []

    for file in index.files:
        for function in file.functions:
            for call in function.calls:
                short = _normalize(
                    call.split(".")[-1],
                )

                if short != normalized:
                    continue

                result.append(
                    (
                        file,
                        function,
                    ),
                )

                break

    return result


def _resolve_backend_endpoints(
    index: ArchitectureIndex,
    file: IndexedFile,
    function: IndexedFunction,
) -> list[
    ApiContractMatch
]:
    matches: list[
        ApiContractMatch
    ] = []

    own_endpoint = _endpoint_for_function(
        file,
        function.name,
    )

    if own_endpoint is not None:
        matches.append(
            ApiContractMatch(
                file=file.path,
                function=function.name,
                method=own_endpoint.method,
                path=own_endpoint.path,
                auth_dependencies=tuple(
                    own_endpoint.dependencies,
                ),
                request_schema=(
                    _request_schema_from_function(
                        function,
                    )
                ),
                response_schema=(
                    own_endpoint.response_model
                ),
                confidence=(
                    own_endpoint.confidence
                ),
                security_critical=(
                    own_endpoint.security_critical
                    or file.security_critical
                ),
            ),
        )

    for caller_file, caller in _direct_callers(
        index,
        function.name,
    ):
        endpoint = _endpoint_for_function(
            caller_file,
            caller.name,
        )

        if endpoint is None:
            continue

        candidate = (
            endpoint.method,
            endpoint.path,
            caller_file.path,
            caller.name,
        )

        if any(
            (
                item.method,
                item.path,
                item.file,
                item.function,
            )
            == candidate
            for item in matches
        ):
            continue

        matches.append(
            ApiContractMatch(
                file=caller_file.path,
                function=caller.name,
                method=endpoint.method,
                path=endpoint.path,
                auth_dependencies=tuple(
                    endpoint.dependencies,
                ),
                request_schema=(
                    _request_schema_from_function(
                        caller,
                    )
                ),
                response_schema=(
                    endpoint.response_model
                ),
                confidence=(
                    endpoint.confidence
                ),
                security_critical=(
                    endpoint.security_critical
                    or caller_file.security_critical
                ),
            ),
        )

    return matches


def _frontend_http_hints(
    function: IndexedFunction,
) -> list[dict]:
    result: list[dict] = []

    for call in function.calls:
        lower = call.lower()

        method = None

        if lower.endswith(
            ".get",
        ):
            method = "GET"
        elif lower.endswith(
            ".post",
        ):
            method = "POST"
        elif lower.endswith(
            ".put",
        ):
            method = "PUT"
        elif lower.endswith(
            ".patch",
        ):
            method = "PATCH"
        elif lower.endswith(
            ".delete",
        ):
            method = "DELETE"

        if method is None:
            continue

        result.append(
            {
                "method":
                    method,
                "path":
                    None,
                "call":
                    call,
                "confidence":
                    "inferred",
            },
        )

    return result


def build_api_contract(
    index: ArchitectureIndex,
    *,
    path: str,
    function_name: str,
) -> dict | None:
    file = index.by_path.get(
        path,
    )

    if file is None:
        return None

    function = _function_by_name(
        file,
        function_name,
    )

    if function is None:
        return None

    backend_endpoints = (
        _resolve_backend_endpoints(
            index,
            file,
            function,
        )
    )

    frontend_http = (
        _frontend_http_hints(
            function,
        )
        if file.layer == "Frontend"
        else []
    )

    auth_required = any(
        endpoint.auth_dependencies
        for endpoint in backend_endpoints
    )

    auth_dependencies = sorted(
        {
            dependency
            for endpoint
            in backend_endpoints
            for dependency
            in endpoint.auth_dependencies
        },
    )

    request_schemas = sorted(
        {
            endpoint.request_schema
            for endpoint
            in backend_endpoints
            if endpoint.request_schema
        },
    )

    response_schemas = sorted(
        {
            endpoint.response_schema
            for endpoint
            in backend_endpoints
            if endpoint.response_schema
        },
    )

    security_critical = (
        file.security_critical
        or bool(
            function.security,
        )
        or any(
            endpoint.security_critical
            for endpoint
            in backend_endpoints
        )
    )

    if backend_endpoints:
        confidence = (
            "observed"
            if all(
                endpoint.confidence
                == "observed"
                for endpoint
                in backend_endpoints
            )
            else "mixed"
        )
    elif frontend_http:
        confidence = "inferred"
    else:
        confidence = "unknown"

    summary_parts: list[str] = []

    if backend_endpoints:
        summary_parts.append(
            (
                f"{len(backend_endpoints)} "
                "backend endpoint(s) resolved"
            )
        )

    if auth_required:
        summary_parts.append(
            "authentication dependency detected"
        )

    if request_schemas:
        summary_parts.append(
            (
                "request schema(s): "
                + ", ".join(
                    request_schemas,
                )
            )
        )

    if response_schemas:
        summary_parts.append(
            (
                "response schema(s): "
                + ", ".join(
                    response_schemas,
                )
            )
        )

    if not summary_parts:
        summary_parts.append(
            "no concrete API contract resolved"
        )

    return {
        "path":
            file.path,
        "function":
            function.name,
        "layer":
            file.layer,
        "summary":
            "; ".join(
                summary_parts,
            )
            + ".",
        "confidence":
            confidence,
        "auth_required":
            auth_required,
        "auth_dependencies":
            auth_dependencies,
        "request_schemas":
            request_schemas,
        "response_schemas":
            response_schemas,
        "security_critical":
            security_critical,
        "backend_endpoints": [
            {
                "file":
                    endpoint.file,
                "function":
                    endpoint.function,
                "method":
                    endpoint.method,
                "path":
                    endpoint.path,
                "auth_dependencies":
                    list(
                        endpoint.auth_dependencies,
                    ),
                "request_schema":
                    endpoint.request_schema,
                "response_schema":
                    endpoint.response_schema,
                "confidence":
                    endpoint.confidence,
                "security_critical":
                    endpoint.security_critical,
            }
            for endpoint
            in backend_endpoints
        ],
        "frontend_http_hints":
            frontend_http,
    }