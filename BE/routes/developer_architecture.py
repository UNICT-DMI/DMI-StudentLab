from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query,
)

from models.user import (
    User,
)

from core.developer_security import (
    get_developer_system_user,
)

from schemas.developer_architecture import (
    DeveloperApiContractResponse,
    DeveloperFileResponse,
    DeveloperFlowResponse,
    DeveloperGraphResponse,
    DeveloperImpactResponse,
    DeveloperRepositoryStatusResponse,
    DeveloperRuntimeRiskResponse,
    DeveloperStackTraceAnalysisResponse,
    DeveloperStackTraceRequest,
    DeveloperSearchResultResponse,
    DeveloperSourceResponse,
    DeveloperTreeNodeResponse,
)

from services.developer_flows import (
    apply_flow_metadata,
    get_flow,
    resolve_flows,
)

from services.developer_api_contract import (
    build_api_contract,
)

from services.developer_graph import (
    build_graph,
)

from services.developer_impact import (
    build_impact_analysis,
)

from services.developer_indexer import (
    ArchitectureIndex,
    build_architecture_index,
    get_indexed_file,
)

from services.developer_repository import (
    repository_source_info,
)

from services.developer_search import (
    search_architecture,
)

from services.developer_stack_trace import (
    analyze_stack_trace,
)


from services.developer_runtime_risk import (
    build_runtime_risk,
)


from services.developer_source import (
    read_indexed_source,
)


router = APIRouter(
    prefix="/developer",
    tags=[
        "developer",
    ],
)


def _index() -> ArchitectureIndex:
    try:
        index = build_architecture_index()

        return apply_flow_metadata(
            index,
        )

    except RuntimeError as exception:
        raise HTTPException(
            status_code=503,
            detail=str(
                exception,
            ),
        ) from exception


def _tree_node(
    name: str,
    path: str,
    node_type: str,
    *,
    documented: bool = False,
    outdated: bool = False,
    changed: bool = False,
    security_critical: bool = False,
    function_count: int | None = None,
    children: list[dict] | None = None,
) -> dict:
    return {
        "id": (
            path
            if path
            else "root"
        ),
        "name": name,
        "path": path,
        "type": node_type,
        "documented": documented,
        "outdated": outdated,
        "changed": changed,
        "security_critical": (
            security_critical
        ),
        "function_count": (
            function_count
        ),
        "children": (
            children
            or []
        ),
    }


def _build_tree(
    index: ArchitectureIndex,
) -> dict:
    root = {
        "directories": {},
        "files": {},
    }

    by_path = index.by_path

    for file in index.files:
        parts = file.path.split(
            "/",
        )

        cursor = root

        for part in parts[:-1]:
            cursor = (
                cursor[
                    "directories"
                ]
                .setdefault(
                    part,
                    {
                        "directories": {},
                        "files": {},
                    },
                )
            )

        cursor[
            "files"
        ][
            parts[-1]
        ] = file.path

    def convert(
        node: dict,
        current_path: str,
        display_name: str,
    ) -> dict:
        children: list[
            dict
        ] = []

        for directory_name in sorted(
            node["directories"],
            key=str.lower,
        ):
            child_path = (
                f"{current_path}/"
                f"{directory_name}"
                if current_path
                else directory_name
            )

            children.append(
                convert(
                    node[
                        "directories"
                    ][
                        directory_name
                    ],
                    child_path,
                    directory_name,
                ),
            )

        for file_name in sorted(
            node["files"],
            key=str.lower,
        ):
            file_path = (
                node["files"][
                    file_name
                ]
            )

            file = by_path[
                file_path
            ]

            children.append(
                _tree_node(
                    file_name,
                    file.path,
                    "file",
                    documented=(
                        file.documented
                    ),
                    outdated=(
                        file.outdated
                    ),
                    changed=(
                        file.changed
                    ),
                    security_critical=(
                        file.security_critical
                    ),
                    function_count=len(
                        file.functions,
                    ),
                ),
            )

        return _tree_node(
            display_name,
            current_path,
            "folder",
            children=children,
        )

    source = repository_source_info(
        index.repository_root,
    )

    return convert(
        root,
        "",
        source.repository_label,
    )


def _serialize_function(
    function,
) -> dict:
    return {
        "id": function.id,
        "name": function.name,
        "signature": (
            function.signature
        ),
        "description": (
            function.description
        ),
        "line_start": (
            function.line_start
        ),
        "line_end": (
            function.line_end
        ),
        "is_async": (
            function.is_async
        ),
        "calls": function.calls,
        "called_by": (
            function.called_by
        ),
        "flows": function.flows,
        "security": (
            function.security
        ),
        "inputs": function.inputs,
        "outputs": function.outputs,
        "risk": function.risk,
    }


def _serialize_file(
    file,
    *,
    source_type: str,
) -> dict:
    return {
        "id": file.id,
        "path": file.path,
        "name": file.name,
        "extension": (
            file.extension
        ),
        "language": (
            file.language
        ),
        "layer": file.layer,
        "module": file.module,
        "description": (
            file.description
        ),
        "importance": (
            file.importance
        ),
        "source_type": (
            source_type
        ),
        "documented": (
            file.documented
        ),
        "outdated": file.outdated,
        "changed": file.changed,
        "security_critical": (
            file.security_critical
        ),
        "risk": file.risk,
        "size_bytes": (
            file.size_bytes
        ),
        "modified_at": (
            file.modified_at
        ),
        "content_hash": (
            file.content_hash
        ),
        "functions": [
            _serialize_function(
                function,
            )
            for function
            in file.functions
        ],
        "imports": file.imports,
        "relations": (
            file.relations
        ),
        "flows": file.flows,
        "security_notes": (
            file.security_notes
        ),
        "endpoints": [
            {
                "method":
                    endpoint.method,
                "path":
                    endpoint.path,
                "function_name":
                    endpoint.function_name,
                "line_start":
                    endpoint.line_start,
                "router_name":
                    endpoint.router_name,
                "dependencies":
                    endpoint.dependencies,
                "response_model":
                    endpoint.response_model,
                "security_critical":
                    endpoint.security_critical,
                "confidence":
                    endpoint.confidence,
            }
            for endpoint
            in file.endpoints
        ],
        "models": [
            {
                "name":
                    model.name,
                "table_name":
                    model.table_name,
                "bases":
                    model.bases,
                "columns":
                    model.columns,
                "relationships":
                    model.relationships,
                "line_start":
                    model.line_start,
                "confidence":
                    model.confidence,
            }
            for model
            in file.models
        ],
        "tests": [
            {
                "name":
                    test.name,
                "line_start":
                    test.line_start,
                "framework":
                    test.framework,
                "calls":
                    test.calls,
                "target_candidates":
                    test.target_candidates,
                "confidence":
                    test.confidence,
            }
            for test
            in file.tests
        ],
    }


@router.get(
    "/access",
)
def developer_access(
    current_user: User = Depends(
        get_developer_system_user,
    ),
):
    return {
        "authorized": True,
        "role": current_user.role,
    }


@router.get(
    "/status",
    response_model=(
        DeveloperRepositoryStatusResponse
    ),
)
def developer_status(
    current_user: User = Depends(
        get_developer_system_user,
    ),
):
    index = _index()

    source = repository_source_info(
        index.repository_root,
    )

    functions_indexed = sum(
        len(
            file.functions,
        )
        for file in index.files
    )

    return {
        "repository_name": (
            source.repository_name
        ),
        "repository_root": (
            source.repository_label
        ),
        "source_type": (
            source.source_type
        ),
        "git_available": (
            source.git_available
        ),
        "branch": source.branch,
        "head_commit": (
            source.head_commit
        ),
        "files_indexed": len(
            index.files,
        ),
        "functions_indexed": (
            functions_indexed
        ),
        "documented_files": sum(
            1
            for file in index.files
            if file.documented
        ),
        "outdated_files": sum(
            1
            for file in index.files
            if file.outdated
        ),
        "changed_files": sum(
            1
            for file in index.files
            if file.changed
        ),
        "security_critical_files": sum(
            1
            for file in index.files
            if file.security_critical
        ),
    }


@router.get(
    "/tree",
    response_model=(
        DeveloperTreeNodeResponse
    ),
)
def developer_tree(
    current_user: User = Depends(
        get_developer_system_user,
    ),
):
    index = _index()

    return _build_tree(
        index,
    )


@router.get(
    "/files",
    response_model=list[
        DeveloperFileResponse
    ],
)
def developer_files(
    current_user: User = Depends(
        get_developer_system_user,
    ),
):
    index = _index()

    source = repository_source_info(
        index.repository_root,
    )

    return [
        _serialize_file(
            file,
            source_type=(
                source.source_type
            ),
        )
        for file in index.files
    ]


@router.get(
    "/file",
    response_model=(
        DeveloperFileResponse
    ),
)
def developer_file(
    path: str = Query(
        ...,
        min_length=1,
        max_length=600,
    ),
    current_user: User = Depends(
        get_developer_system_user,
    ),
):
    index = _index()

    file = get_indexed_file(
        index,
        path,
    )

    if file is None:
        raise HTTPException(
            status_code=404,
            detail=(
                "File non presente "
                "nell'indice Developer."
            ),
        )

    source = repository_source_info(
        index.repository_root,
    )

    return _serialize_file(
        file,
        source_type=(
            source.source_type
        ),
    )


@router.get(
    "/search",
    response_model=list[
        DeveloperSearchResultResponse
    ],
)
def developer_search(
    q: str = Query(
        ...,
        min_length=2,
        max_length=200,
    ),
    limit: int = Query(
        30,
        ge=1,
        le=100,
    ),
    current_user: User = Depends(
        get_developer_system_user,
    ),
):
    index = _index()

    return search_architecture(
        index,
        q,
        limit,
    )


@router.get(
    "/graph",
    response_model=(
        DeveloperGraphResponse
    ),
)
def developer_graph(
    current_user: User = Depends(
        get_developer_system_user,
    ),
):
    index = _index()

    return build_graph(
        index,
    )

@router.get(
    "/flows",
    response_model=list[
        DeveloperFlowResponse
    ],
)
def developer_flows(
    current_user: User = Depends(
        get_developer_system_user,
    ),
):
    index = _index()

    return resolve_flows(
        index,
    )


@router.get(
    "/flow/{flow_id}",
    response_model=(
        DeveloperFlowResponse
    ),
)
def developer_flow(
    flow_id: str,
    current_user: User = Depends(
        get_developer_system_user,
    ),
):
    index = _index()

    flow = get_flow(
        index,
        flow_id,
    )

    if flow is None:
        raise HTTPException(
            status_code=404,
            detail=(
                "Flow applicativo "
                "non trovato."
            ),
        )

    return flow

@router.get(
    "/impact",
    response_model=(
        DeveloperImpactResponse
    ),
)
def developer_impact(
    path: str = Query(
        ...,
        min_length=1,
        max_length=600,
    ),
    function: str | None = Query(
        None,
        min_length=1,
        max_length=200,
    ),
    current_user: User = Depends(
        get_developer_system_user,
    ),
):
    index = _index()

    impact = build_impact_analysis(
        index,
        path=path,
        function_name=function,
    )

    if impact is None:
        raise HTTPException(
            status_code=404,
            detail=(
                "File o funzione non presente "
                "nell'indice Developer."
            ),
        )

    return impact

@router.get(
    "/source",
    response_model=(
        DeveloperSourceResponse
    ),
)
def developer_source(
    path: str = Query(
        ...,
        min_length=1,
        max_length=600,
    ),
    function: str | None = Query(
        None,
        min_length=1,
        max_length=200,
    ),
    current_user: User = Depends(
        get_developer_system_user,
    ),
):
    index = _index()

    try:
        source = read_indexed_source(
            index,
            path=path,
            function_name=function,
        )

    except ValueError as exception:
        raise HTTPException(
            status_code=413,
            detail=str(
                exception,
            ),
        ) from exception

    if source is None:
        raise HTTPException(
            status_code=404,
            detail=(
                "File o funzione non presente "
                "nell'indice Developer."
            ),
        )

    return source

@router.get(
    "/api-contract",
    response_model=(
        DeveloperApiContractResponse
    ),
)
def developer_api_contract(
    path: str = Query(
        ...,
        min_length=1,
        max_length=600,
    ),
    function: str = Query(
        ...,
        min_length=1,
        max_length=200,
    ),
    current_user: User = Depends(
        get_developer_system_user,
    ),
):
    index = _index()

    contract = build_api_contract(
        index,
        path=path,
        function_name=function,
    )

    if contract is None:
        raise HTTPException(
            status_code=404,
            detail=(
                "File o funzione non presente "
                "nell'indice Developer."
            ),
        )

    return contract

@router.get(
    "/runtime-risk",
    response_model=(
        DeveloperRuntimeRiskResponse
    ),
)
def developer_runtime_risk(
    path: str = Query(
        ...,
        min_length=1,
        max_length=600,
    ),
    function: str = Query(
        ...,
        min_length=1,
        max_length=200,
    ),
    current_user: User = Depends(
        get_developer_system_user,
    ),
):
    index = _index()

    result = build_runtime_risk(
        index,
        path=path,
        function_name=function,
    )

    if result is None:
        raise HTTPException(
            status_code=404,
            detail=(
                "File o funzione non presente "
                "nell'indice Developer."
            ),
        )

    return result

@router.post(
    "/stack-trace/analyze",
    response_model=(
        DeveloperStackTraceAnalysisResponse
    ),
)
def developer_stack_trace_analyze(
    payload: DeveloperStackTraceRequest,
    current_user: User = Depends(
        get_developer_system_user,
    ),
):
    index = _index()

    return analyze_stack_trace(
        index,
        payload.stack_trace,
    )

