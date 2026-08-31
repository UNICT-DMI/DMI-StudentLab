from typing import (
    Literal,
)

from pydantic import (
    BaseModel,
    Field,
)


DeveloperNodeType = Literal[
    "folder",
    "file",
]

DeveloperSourceType = Literal[
    "local",
    "remote",
    "synced",
]

DeveloperRiskLevel = Literal[
    "low",
    "medium",
    "high",
    "critical",
]


class DeveloperTreeNodeResponse(
    BaseModel,
):
    id: str
    name: str
    path: str
    type: DeveloperNodeType
    documented: bool = False
    outdated: bool = False
    changed: bool = False
    security_critical: bool = False
    function_count: int | None = None
    children: list[
        "DeveloperTreeNodeResponse"
    ] = Field(
        default_factory=list,
    )


class DeveloperFunctionResponse(
    BaseModel,
):
    id: str
    name: str
    signature: str
    description: str = ""
    line_start: int | None = None
    line_end: int | None = None
    is_async: bool = False
    calls: list[str] = Field(
        default_factory=list,
    )
    called_by: list[str] = Field(
        default_factory=list,
    )
    flows: list[str] = Field(
        default_factory=list,
    )
    security: list[str] = Field(
        default_factory=list,
    )
    inputs: list[str] = Field(
        default_factory=list,
    )
    outputs: list[str] = Field(
        default_factory=list,
    )
    risk: DeveloperRiskLevel = "medium"


class DeveloperRelationResponse(
    BaseModel,
):
    type: str
    label: str
    target_path: str
    target_function: str | None = None


class DeveloperEndpointResponse(
    BaseModel,
):
    method: str
    path: str
    function_name: str
    line_start: int | None = None
    router_name: str | None = None
    dependencies: list[str] = Field(
        default_factory=list,
    )
    response_model: str | None = None
    security_critical: bool = False
    confidence: Literal[
        "observed",
        "inferred",
    ] = "observed"


class DeveloperModelArtifactResponse(
    BaseModel,
):
    name: str
    table_name: str | None = None
    bases: list[str] = Field(
        default_factory=list,
    )
    columns: list[str] = Field(
        default_factory=list,
    )
    relationships: list[str] = Field(
        default_factory=list,
    )
    line_start: int | None = None
    confidence: Literal[
        "observed",
        "inferred",
    ] = "observed"


class DeveloperTestArtifactResponse(
    BaseModel,
):
    name: str
    line_start: int | None = None
    framework: str
    calls: list[str] = Field(
        default_factory=list,
    )
    target_candidates: list[str] = Field(
        default_factory=list,
    )
    confidence: Literal[
        "observed",
        "inferred",
    ] = "observed"


class DeveloperFileResponse(
    BaseModel,
):
    id: str
    path: str
    name: str
    extension: str
    language: str
    layer: str
    module: str
    description: str
    importance: str
    source_type: DeveloperSourceType = "local"
    documented: bool = False
    outdated: bool = False
    changed: bool = False
    security_critical: bool = False
    risk: DeveloperRiskLevel = "medium"
    size_bytes: int = 0
    modified_at: float | None = None
    content_hash: str
    functions: list[
        DeveloperFunctionResponse
    ] = Field(
        default_factory=list,
    )
    imports: list[str] = Field(
        default_factory=list,
    )
    relations: list[
        DeveloperRelationResponse
    ] = Field(
        default_factory=list,
    )
    flows: list[str] = Field(
        default_factory=list,
    )
    security_notes: list[str] = Field(
        default_factory=list,
    )
    endpoints: list[
        DeveloperEndpointResponse
    ] = Field(
        default_factory=list,
    )
    models: list[
        DeveloperModelArtifactResponse
    ] = Field(
        default_factory=list,
    )
    tests: list[
        DeveloperTestArtifactResponse
    ] = Field(
        default_factory=list,
    )


class DeveloperRepositoryStatusResponse(
    BaseModel,
):
    repository_name: str
    repository_root: str
    source_type: DeveloperSourceType
    git_available: bool
    branch: str | None = None
    head_commit: str | None = None
    files_indexed: int
    functions_indexed: int
    documented_files: int
    outdated_files: int
    changed_files: int
    security_critical_files: int


class DeveloperSearchResultResponse(
    BaseModel,
):
    kind: Literal[
        "file",
        "function",
        "flow",
    ]
    title: str
    subtitle: str
    path: str
    function_name: str | None = None
    score: float
    reasons: list[str] = Field(
        default_factory=list,
    )


class DeveloperFlowStepResponse(
    BaseModel,
):
    order: int
    title: str
    file: str
    function: str | None = None
    layer: str
    relation: str = "NEXT"
    context: str = ""
    security_critical: bool = False


class DeveloperFlowResponse(
    BaseModel,
):
    id: str
    name: str
    description: str
    risk: DeveloperRiskLevel
    steps: list[
        DeveloperFlowStepResponse
    ] = Field(
        default_factory=list,
    )


class DeveloperGraphNodeResponse(
    BaseModel,
):
    id: str
    label: str
    path: str
    function_name: str | None = None
    kind: str
    layer: str | None = None
    security_critical: bool = False


class DeveloperGraphEdgeResponse(
    BaseModel,
):
    id: str
    source: str
    target: str
    type: str
    label: str


class DeveloperGraphResponse(
    BaseModel,
):
    nodes: list[
        DeveloperGraphNodeResponse
    ] = Field(
        default_factory=list,
    )
    edges: list[
        DeveloperGraphEdgeResponse
    ] = Field(
        default_factory=list,
    )

class DeveloperImpactFunctionRefResponse(
    BaseModel,
):
    file: str
    function: str
    layer: str
    security_critical: bool = False
    risk: DeveloperRiskLevel = "medium"
    depth: int | None = None


class DeveloperImpactFlowResponse(
    BaseModel,
):
    id: str
    name: str
    risk: DeveloperRiskLevel
    matched_steps: list[int] = Field(
        default_factory=list,
    )


class DeveloperImpactEndpointResponse(
    BaseModel,
):
    file: str
    function: str
    method: str | None = None
    path: str | None = None
    confidence: Literal[
        "observed",
        "inferred",
    ] = "inferred"


class DeveloperImpactModelResponse(
    BaseModel,
):
    file: str
    name: str
    layer: str
    confidence: Literal[
        "observed",
        "inferred",
    ] = "observed"


class DeveloperImpactTestResponse(
    BaseModel,
):
    file: str
    confidence: Literal[
        "observed",
        "inferred",
    ]
    reason: str


class DeveloperImpactResponse(
    BaseModel,
):
    path: str
    function: str | None = None
    risk: DeveloperRiskLevel
    summary: str
    semantic_answer: str
    direct_callers: list[
        DeveloperImpactFunctionRefResponse
    ] = Field(
        default_factory=list,
    )
    direct_callees: list[
        DeveloperImpactFunctionRefResponse
    ] = Field(
        default_factory=list,
    )
    transitive_callers: list[
        DeveloperImpactFunctionRefResponse
    ] = Field(
        default_factory=list,
    )
    related_files: list[str] = Field(
        default_factory=list,
    )
    flows: list[
        DeveloperImpactFlowResponse
    ] = Field(
        default_factory=list,
    )
    endpoints: list[
        DeveloperImpactEndpointResponse
    ] = Field(
        default_factory=list,
    )
    models: list[
        DeveloperImpactModelResponse
    ] = Field(
        default_factory=list,
    )
    tests: list[
        DeveloperImpactTestResponse
    ] = Field(
        default_factory=list,
    )
    recommendations: list[str] = Field(
        default_factory=list,
    )
    security_flags: list[str] = Field(
        default_factory=list,
    )
    security_critical: bool = False

class DeveloperSourceResponse(
    BaseModel,
):
    path: str
    language: str
    symbol: str | None = None
    source_kind: Literal[
        "file",
        "function",
    ]
    line_start: int
    line_end: int
    line_count: int
    source: str
    commit_sha: str | None = None
    content_hash: str
    repository: str
    branch: str | None = None

class DeveloperApiEndpointContractResponse(
    BaseModel,
):
    file: str
    function: str
    method: str | None = None
    path: str | None = None
    auth_dependencies: list[str] = Field(
        default_factory=list,
    )
    request_schema: str | None = None
    response_schema: str | None = None
    confidence: Literal[
        "observed",
        "inferred",
        "mixed",
        "unknown",
    ] = "unknown"
    security_critical: bool = False


class DeveloperFrontendHttpHintResponse(
    BaseModel,
):
    method: str
    path: str | None = None
    call: str
    confidence: Literal[
        "observed",
        "inferred",
    ] = "inferred"


class DeveloperApiContractResponse(
    BaseModel,
):
    path: str
    function: str
    layer: str
    summary: str
    confidence: Literal[
        "observed",
        "inferred",
        "mixed",
        "unknown",
    ]
    auth_required: bool = False
    auth_dependencies: list[str] = Field(
        default_factory=list,
    )
    request_schemas: list[str] = Field(
        default_factory=list,
    )
    response_schemas: list[str] = Field(
        default_factory=list,
    )
    security_critical: bool = False
    backend_endpoints: list[
        DeveloperApiEndpointContractResponse
    ] = Field(
        default_factory=list,
    )
    frontend_http_hints: list[
        DeveloperFrontendHttpHintResponse
    ] = Field(
        default_factory=list,
    )

class DeveloperRuntimeFindingResponse(
    BaseModel,
):
    id: str
    title: str
    category: str
    severity: Literal[
        "info",
        "low",
        "medium",
        "high",
        "critical",
    ]
    confidence: Literal[
        "observed",
        "inferred",
    ]
    message: str
    evidence: str | None = None
    recommendation: str | None = None


class DeveloperSideEffectResponse(
    BaseModel,
):
    category: str
    label: str
    confidence: Literal[
        "observed",
        "inferred",
    ]
    evidence: str | None = None


class DeveloperErrorPathResponse(
    BaseModel,
):
    kind: str
    code: str | None = None
    label: str
    confidence: Literal[
        "observed",
        "inferred",
    ]


class DeveloperRuntimeRiskResponse(
    BaseModel,
):
    path: str
    function: str
    language: str
    risk: DeveloperRiskLevel
    summary: str
    security_critical: bool = False
    findings: list[
        DeveloperRuntimeFindingResponse
    ] = Field(
        default_factory=list,
    )
    side_effects: list[
        DeveloperSideEffectResponse
    ] = Field(
        default_factory=list,
    )
    error_paths: list[
        DeveloperErrorPathResponse
    ] = Field(
        default_factory=list,
    )

class DeveloperStackTraceRequest(
    BaseModel,
):
    stack_trace: str = Field(
        ...,
        min_length=1,
        max_length=100000,
    )


class DeveloperStackFrameResponse(
    BaseModel,
):
    position: int
    raw: str
    path: str | None = None
    line: int | None = None
    column: int | None = None
    symbol: str | None = None
    resolved: bool = False
    app_frame: bool = False
    confidence: Literal[
        "observed",
        "inferred",
    ]


class DeveloperStackPrimaryFrameResponse(
    BaseModel,
):
    path: str | None = None
    line: int | None = None
    column: int | None = None
    symbol: str | None = None
    confidence: Literal[
        "observed",
        "inferred",
    ]


class DeveloperStackTraceAnalysisResponse(
    BaseModel,
):
    diagnosis: str
    risk: DeveloperRiskLevel
    primary_frame: (
        DeveloperStackPrimaryFrameResponse
        | None
    ) = None
    frames: list[
        DeveloperStackFrameResponse
    ] = Field(
        default_factory=list,
    )
    studentlab_frames: int = 0
    unresolved_frames: int = 0
    runtime: dict | None = None
    impact: dict | None = None

