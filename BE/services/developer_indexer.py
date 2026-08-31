from __future__ import annotations

from dataclasses import (
    dataclass,
    field,
)

from pathlib import (
    Path,
)

from typing import (
    Any,
)

import ast
import re

from services.developer_repository import (
    RepositoryFile,
    git_changed_paths,
    iter_repository_files,
    resolve_repository_root,
)


SECURITY_PATH_PATTERNS = (
    "auth",
    "security",
    "permission",
    "role",
    "token",
    "password",
    "secret",
    "oauth",
    "admin",
    "moderation",
    "report",
)

SECURITY_SYMBOL_PATTERNS = (
    "authenticate",
    "authorize",
    "permission",
    "verified",
    "admin",
    "creator",
    "role",
    "password",
    "token",
    "secret",
    "jwt",
    "hmac",
    "hash",
    "login",
    "verify",
)

HTTP_METHODS = {
    "get",
    "post",
    "put",
    "patch",
    "delete",
    "options",
    "head",
}

SQLALCHEMY_COLUMN_CALLS = {
    "Column",
    "mapped_column",
}

SQLALCHEMY_RELATIONSHIP_CALLS = {
    "relationship",
}

LAYER_RULES = (
    ("fe/lib", "Frontend"),
    ("BE/routes", "Backend API"),
    ("BE/services", "Backend Service"),
    ("BE/models", "Database Model"),
    ("BE/schemas", "API Schema"),
    ("BE/core", "Core / Infrastructure"),
    ("BE/tests", "Tests"),
    ("test", "Tests"),
    ("fe/test", "Tests"),
    ("BE", "Backend"),
)

LANGUAGES = {
    ".py": "Python",
    ".dart": "Dart",
    ".md": "Markdown",
    ".txt": "Text",
    ".json": "JSON",
    ".yaml": "YAML",
    ".yml": "YAML",
    ".toml": "TOML",
    ".xml": "XML",
    ".sql": "SQL",
    ".js": "JavaScript",
    ".ts": "TypeScript",
    ".tsx": "TypeScript",
    ".jsx": "JavaScript",
    ".sh": "Shell",
}


@dataclass
class IndexedEndpoint:
    method: str
    path: str
    function_name: str
    line_start: int | None = None
    router_name: str | None = None
    dependencies: list[str] = field(
        default_factory=list,
    )
    response_model: str | None = None
    security_critical: bool = False
    confidence: str = "observed"


@dataclass
class IndexedModel:
    name: str
    table_name: str | None = None
    bases: list[str] = field(
        default_factory=list,
    )
    columns: list[str] = field(
        default_factory=list,
    )
    relationships: list[str] = field(
        default_factory=list,
    )
    line_start: int | None = None
    confidence: str = "observed"


@dataclass
class IndexedTest:
    name: str
    line_start: int | None = None
    framework: str = "unknown"
    calls: list[str] = field(
        default_factory=list,
    )
    target_candidates: list[str] = field(
        default_factory=list,
    )
    confidence: str = "observed"


@dataclass
class IndexedFunction:
    id: str
    name: str
    signature: str
    description: str = ""
    line_start: int | None = None
    line_end: int | None = None
    is_async: bool = False
    calls: list[str] = field(
        default_factory=list,
    )
    called_by: list[str] = field(
        default_factory=list,
    )
    flows: list[str] = field(
        default_factory=list,
    )
    security: list[str] = field(
        default_factory=list,
    )
    inputs: list[str] = field(
        default_factory=list,
    )
    outputs: list[str] = field(
        default_factory=list,
    )
    risk: str = "medium"


@dataclass
class IndexedFile:
    id: str
    path: str
    name: str
    extension: str
    language: str
    layer: str
    module: str
    description: str
    importance: str
    documented: bool
    outdated: bool
    changed: bool
    security_critical: bool
    risk: str
    size_bytes: int
    modified_at: float
    content_hash: str
    functions: list[
        IndexedFunction
    ] = field(
        default_factory=list,
    )
    imports: list[str] = field(
        default_factory=list,
    )
    relations: list[
        dict[str, Any]
    ] = field(
        default_factory=list,
    )
    flows: list[str] = field(
        default_factory=list,
    )
    security_notes: list[str] = field(
        default_factory=list,
    )
    endpoints: list[
        IndexedEndpoint
    ] = field(
        default_factory=list,
    )
    models: list[
        IndexedModel
    ] = field(
        default_factory=list,
    )
    tests: list[
        IndexedTest
    ] = field(
        default_factory=list,
    )


@dataclass
class ArchitectureIndex:
    repository_root: Path
    files: list[
        IndexedFile
    ]
    changed_paths: set[str]

    @property
    def by_path(
        self,
    ) -> dict[str, IndexedFile]:
        return {
            file.path: file
            for file in self.files
        }


def _safe_unparse(
    node: ast.AST | None,
) -> str:
    if node is None:
        return ""

    try:
        return ast.unparse(
            node,
        )
    except Exception:
        return ""


def _node_call_name(
    node: ast.Call,
) -> str | None:
    value = _safe_unparse(
        node.func,
    )

    if value:
        return value

    if isinstance(
        node.func,
        ast.Name,
    ):
        return node.func.id

    return None


def _annotation_text(
    node: ast.AST | None,
) -> str:
    return _safe_unparse(
        node,
    )


def _literal_string(
    node: ast.AST | None,
) -> str | None:
    if isinstance(
        node,
        ast.Constant,
    ) and isinstance(
        node.value,
        str,
    ):
        return node.value

    return None


def _function_signature(
    node: (
        ast.FunctionDef
        | ast.AsyncFunctionDef
    ),
) -> str:
    arguments: list[str] = []

    positional = list(
        node.args.posonlyargs,
    ) + list(
        node.args.args,
    )

    defaults = (
        [None]
        * (
            len(positional)
            - len(node.args.defaults)
        )
        + list(node.args.defaults)
    )

    for argument, default in zip(
        positional,
        defaults,
    ):
        item = argument.arg

        annotation = _annotation_text(
            argument.annotation,
        )

        if annotation:
            item += (
                f": {annotation}"
            )

        if default is not None:
            default_text = _safe_unparse(
                default,
            )

            item += (
                f" = {default_text or '...'}"
            )

        arguments.append(
            item,
        )

    if node.args.vararg is not None:
        arguments.append(
            "*"
            + node.args.vararg.arg,
        )

    for argument, default in zip(
        node.args.kwonlyargs,
        node.args.kw_defaults,
    ):
        item = argument.arg

        annotation = _annotation_text(
            argument.annotation,
        )

        if annotation:
            item += (
                f": {annotation}"
            )

        if default is not None:
            default_text = _safe_unparse(
                default,
            )

            item += (
                f" = {default_text or '...'}"
            )

        arguments.append(
            item,
        )

    if node.args.kwarg is not None:
        arguments.append(
            "**"
            + node.args.kwarg.arg,
        )

    return_annotation = (
        _annotation_text(
            node.returns,
        )
    )

    signature = (
        f"{node.name}("
        + ", ".join(
            arguments,
        )
        + ")"
    )

    if return_annotation:
        signature += (
            f" -> {return_annotation}"
        )

    return signature


def _python_function_calls(
    node: ast.AST,
) -> list[str]:
    calls: list[str] = []

    for child in ast.walk(
        node,
    ):
        if not isinstance(
            child,
            ast.Call,
        ):
            continue

        name = _node_call_name(
            child,
        )

        if (
            name
            and name not in calls
        ):
            calls.append(
                name,
            )

    return calls


def _depends_names(
    node: (
        ast.FunctionDef
        | ast.AsyncFunctionDef
    ),
) -> list[str]:
    dependencies: list[str] = []

    defaults = list(
        node.args.defaults,
    ) + [
        default
        for default in node.args.kw_defaults
        if default is not None
    ]

    for default in defaults:
        if not isinstance(
            default,
            ast.Call,
        ):
            continue

        call_name = (
            _node_call_name(
                default,
            )
            or ""
        )

        if (
            call_name.split(
                ".",
            )[-1]
            != "Depends"
        ):
            continue

        if not default.args:
            continue

        dependency = _safe_unparse(
            default.args[0],
        )

        if dependency:
            dependencies.append(
                dependency,
            )

    return sorted(
        set(
            dependencies,
        ),
    )


def _fastapi_endpoint_from_decorator(
    decorator: ast.AST,
    function_node: (
        ast.FunctionDef
        | ast.AsyncFunctionDef
    ),
) -> IndexedEndpoint | None:
    if not isinstance(
        decorator,
        ast.Call,
    ):
        return None

    function = decorator.func

    if not isinstance(
        function,
        ast.Attribute,
    ):
        return None

    method = (
        function.attr
        .strip()
        .lower()
    )

    if method not in HTTP_METHODS:
        return None

    router_name = _safe_unparse(
        function.value,
    )

    if not router_name:
        return None

    endpoint_path = None

    if decorator.args:
        endpoint_path = _literal_string(
            decorator.args[0],
        )

    if endpoint_path is None:
        for keyword in decorator.keywords:
            if keyword.arg == "path":
                endpoint_path = (
                    _literal_string(
                        keyword.value,
                    )
                )
                break

    if endpoint_path is None:
        return None

    response_model = None

    for keyword in decorator.keywords:
        if keyword.arg == "response_model":
            response_model = (
                _safe_unparse(
                    keyword.value,
                )
                or None
            )
            break

    dependencies = (
        _depends_names(
            function_node,
        )
    )

    security_critical = any(
        keyword
        in (
            " ".join(
                dependencies,
            )
            + " "
            + function_node.name
        ).lower()
        for keyword in (
            SECURITY_SYMBOL_PATTERNS
        )
    )

    return IndexedEndpoint(
        method=method.upper(),
        path=endpoint_path,
        function_name=(
            function_node.name
        ),
        line_start=(
            function_node.lineno
        ),
        router_name=router_name,
        dependencies=dependencies,
        response_model=(
            response_model
        ),
        security_critical=(
            security_critical
        ),
    )


def _python_fastapi_endpoints(
    tree: ast.Module,
) -> list[
    IndexedEndpoint
]:
    endpoints: list[
        IndexedEndpoint
    ] = []

    for node in tree.body:
        if not isinstance(
            node,
            (
                ast.FunctionDef,
                ast.AsyncFunctionDef,
            ),
        ):
            continue

        for decorator in (
            node.decorator_list
        ):
            endpoint = (
                _fastapi_endpoint_from_decorator(
                    decorator,
                    node,
                )
            )

            if endpoint is not None:
                endpoints.append(
                    endpoint,
                )

    return endpoints


def _sqlalchemy_assignment_name(
    node: (
        ast.Assign
        | ast.AnnAssign
    ),
) -> str | None:
    if isinstance(
        node,
        ast.AnnAssign,
    ):
        if isinstance(
            node.target,
            ast.Name,
        ):
            return node.target.id

        return None

    if len(node.targets) != 1:
        return None

    target = node.targets[0]

    if isinstance(
        target,
        ast.Name,
    ):
        return target.id

    return None


def _assignment_value(
    node: (
        ast.Assign
        | ast.AnnAssign
    ),
) -> ast.AST | None:
    if isinstance(
        node,
        ast.AnnAssign,
    ):
        return node.value

    return node.value


def _python_sqlalchemy_models(
    tree: ast.Module,
) -> list[
    IndexedModel
]:
    models: list[
        IndexedModel
    ] = []

    for node in tree.body:
        if not isinstance(
            node,
            ast.ClassDef,
        ):
            continue

        bases = [
            _safe_unparse(
                base,
            )
            for base in node.bases
        ]

        bases = [
            base
            for base in bases
            if base
        ]

        table_name = None
        columns: list[str] = []
        relationships: list[str] = []

        for child in node.body:
            if not isinstance(
                child,
                (
                    ast.Assign,
                    ast.AnnAssign,
                ),
            ):
                continue

            name = (
                _sqlalchemy_assignment_name(
                    child,
                )
            )

            value = _assignment_value(
                child,
            )

            if (
                name == "__tablename__"
            ):
                table_name = (
                    _literal_string(
                        value,
                    )
                )
                continue

            if (
                name is None
                or not isinstance(
                    value,
                    ast.Call,
                )
            ):
                continue

            call_name = (
                _node_call_name(
                    value,
                )
                or ""
            )

            short_name = (
                call_name
                .split(".")[-1]
            )

            if (
                short_name
                in SQLALCHEMY_COLUMN_CALLS
            ):
                columns.append(
                    name,
                )

            if (
                short_name
                in SQLALCHEMY_RELATIONSHIP_CALLS
            ):
                relationships.append(
                    name,
                )

        base_haystack = (
            " ".join(
                bases,
            )
            .lower()
        )

        is_sqlalchemy = (
            table_name is not None
            or bool(
                columns
            )
            or "base" in base_haystack
            or "declarativebase"
            in base_haystack
        )

        if not is_sqlalchemy:
            continue

        models.append(
            IndexedModel(
                name=node.name,
                table_name=(
                    table_name
                ),
                bases=bases,
                columns=sorted(
                    set(
                        columns,
                    ),
                ),
                relationships=sorted(
                    set(
                        relationships,
                    ),
                ),
                line_start=node.lineno,
            ),
        )

    return models


def _test_target_candidates(
    test_name: str,
    calls: list[str],
) -> list[str]:
    candidates: set[str] = set()

    normalized = test_name.lower()

    if normalized.startswith(
        "test_",
    ):
        remainder = normalized[5:]

        if remainder:
            candidates.add(
                remainder,
            )

    for call in calls:
        short = (
            call
            .split(".")[-1]
            .strip()
        )

        if (
            short
            and short
            not in {
                "assert",
                "print",
            }
        ):
            candidates.add(
                short,
            )

    return sorted(
        candidates,
    )


def _python_tests(
    tree: ast.Module,
) -> list[
    IndexedTest
]:
    tests: list[
        IndexedTest
    ] = []

    for node in ast.walk(
        tree,
    ):
        if not isinstance(
            node,
            (
                ast.FunctionDef,
                ast.AsyncFunctionDef,
            ),
        ):
            continue

        if not node.name.startswith(
            "test_",
        ):
            continue

        calls = (
            _python_function_calls(
                node,
            )
        )

        tests.append(
            IndexedTest(
                name=node.name,
                line_start=node.lineno,
                framework="pytest",
                calls=calls,
                target_candidates=(
                    _test_target_candidates(
                        node.name,
                        calls,
                    )
                ),
            ),
        )

    return tests


def _python_functions(
    path: str,
    text: str,
) -> tuple[
    list[IndexedFunction],
    list[str],
    list[IndexedEndpoint],
    list[IndexedModel],
    list[IndexedTest],
]:
    try:
        tree = ast.parse(
            text,
        )
    except SyntaxError:
        return (
            [],
            [],
            [],
            [],
            [],
        )

    functions: list[
        IndexedFunction
    ] = []

    imports: list[str] = []

    for node in ast.walk(
        tree,
    ):
        if isinstance(
            node,
            ast.Import,
        ):
            for alias in node.names:
                imports.append(
                    alias.name,
                )

        elif isinstance(
            node,
            ast.ImportFrom,
        ):
            module = (
                node.module
                or ""
            )

            for alias in node.names:
                imports.append(
                    (
                        f"{module}.{alias.name}"
                        if module
                        else alias.name
                    ),
                )

    for node in tree.body:
        if not isinstance(
            node,
            (
                ast.FunctionDef,
                ast.AsyncFunctionDef,
            ),
        ):
            continue

        calls = (
            _python_function_calls(
                node,
            )
        )

        security: list[str] = []

        haystack = (
            node.name
            + " "
            + " ".join(
                calls,
            )
            + " "
            + " ".join(
                _depends_names(
                    node,
                ),
            )
        ).lower()

        for keyword in (
            SECURITY_SYMBOL_PATTERNS
        ):
            if (
                keyword in haystack
                and keyword
                not in security
            ):
                security.append(
                    keyword,
                )

        inputs = [
            argument.arg
            for argument in (
                list(
                    node.args.posonlyargs,
                )
                + list(
                    node.args.args,
                )
                + list(
                    node.args.kwonlyargs,
                )
            )
            if argument.arg
            not in {
                "self",
                "cls",
            }
        ]

        risk = (
            "critical"
            if any(
                keyword
                in haystack
                for keyword in (
                    "password",
                    "token",
                    "secret",
                    "authenticate",
                    "login",
                )
            )
            else "high"
            if security
            else "medium"
        )

        functions.append(
            IndexedFunction(
                id=(
                    f"{path}::{node.name}"
                ),
                name=node.name,
                signature=(
                    _function_signature(
                        node,
                    )
                ),
                description=(
                    ast.get_docstring(
                        node,
                    )
                    or ""
                ),
                line_start=node.lineno,
                line_end=getattr(
                    node,
                    "end_lineno",
                    node.lineno,
                ),
                is_async=isinstance(
                    node,
                    ast.AsyncFunctionDef,
                ),
                calls=calls,
                security=security,
                inputs=inputs,
                outputs=(
                    [
                        _annotation_text(
                            node.returns,
                        ),
                    ]
                    if node.returns
                    is not None
                    else []
                ),
                risk=risk,
            ),
        )

    return (
        functions,
        sorted(
            set(
                imports,
            ),
        ),
        _python_fastapi_endpoints(
            tree,
        ),
        _python_sqlalchemy_models(
            tree,
        ),
        _python_tests(
            tree,
        ),
    )


_DART_FUNCTION_PATTERN = re.compile(
    r"(?m)^[ \t]*"
    r"(?:Future<[^>]+>|Future<void>|"
    r"Future|void|bool|int|double|String|"
    r"Widget|Map<[^>]+>|List<[^>]+>|"
    r"[A-Z][A-Za-z0-9_<>?, ]*)"
    r"[ \t]+"
    r"([a-zA-Z_][a-zA-Z0-9_]*)"
    r"[ \t]*\(([^)]*)\)"
)

_DART_TEST_PATTERN = re.compile(
    r"""(?m)\b(test|testWidgets)\s*\(\s*"""
    r"""['"]([^'"]+)['"]"""
)


def _dart_tests(
    text: str,
) -> list[
    IndexedTest
]:
    tests: list[
        IndexedTest
    ] = []

    for match in (
        _DART_TEST_PATTERN.finditer(
            text,
        )
    ):
        framework_call = match.group(
            1,
        )

        name = match.group(
            2,
        )

        line_start = (
            text.count(
                "\n",
                0,
                match.start(),
            )
            + 1
        )

        candidates = [
            token
            for token in re.findall(
                r"[A-Za-z_][A-Za-z0-9_]+",
                name,
            )
            if len(
                token,
            ) >= 3
        ]

        tests.append(
            IndexedTest(
                name=name,
                line_start=line_start,
                framework=(
                    "flutter_test"
                    if framework_call
                    == "testWidgets"
                    else "dart_test"
                ),
                target_candidates=(
                    sorted(
                        set(
                            candidates,
                        ),
                    )
                ),
            ),
        )

    return tests


def _dart_functions(
    path: str,
    text: str,
) -> tuple[
    list[IndexedFunction],
    list[str],
    list[IndexedTest],
]:
    functions: list[
        IndexedFunction
    ] = []

    for match in (
        _DART_FUNCTION_PATTERN
        .finditer(
            text,
        )
    ):
        name = match.group(
            1,
        )

        signature = (
            f"{name}("
            f"{match.group(2).strip()}"
            ")"
        )

        line_start = (
            text.count(
                "\n",
                0,
                match.start(),
            )
            + 1
        )

        haystack = (
            name.lower()
        )

        security = [
            keyword
            for keyword in (
                SECURITY_SYMBOL_PATTERNS
            )
            if keyword in haystack
        ]

        functions.append(
            IndexedFunction(
                id=(
                    f"{path}::{name}"
                ),
                name=name,
                signature=signature,
                line_start=line_start,
                line_end=line_start,
                security=security,
                risk=(
                    "high"
                    if security
                    else "medium"
                ),
            ),
        )

    imports = re.findall(
        r"""(?m)^\s*import\s+['"]([^'"]+)['"]""",
        text,
    )

    return (
        functions,
        sorted(
            set(
                imports,
            ),
        ),
        _dart_tests(
            text,
        ),
    )


def _layer_for_path(
    path: str,
) -> str:
    for prefix, layer in (
        LAYER_RULES
    ):
        if path.startswith(
            prefix,
        ):
            return layer

    return "Repository"


def _module_for_path(
    path: str,
) -> str:
    parts = Path(
        path,
    ).parts

    if len(parts) <= 1:
        return "Root"

    if parts[0] == "BE":
        if len(parts) >= 2:
            return parts[1]

    if (
        len(parts) >= 3
        and parts[0] == "fe"
        and parts[1] == "lib"
    ):
        return parts[2]

    return parts[
        max(
            0,
            len(parts) - 2,
        )
    ]


def _documentation_candidates(
    repository_root: Path,
    source_path: str,
) -> list[Path]:
    safe = (
        source_path
        .replace(
            "/",
            "__",
        )
    )

    source = (
        repository_root
        / source_path
    )

    return [
        source.with_suffix(
            source.suffix
            + ".md",
        ),
        source.with_suffix(
            source.suffix
            + ".txt",
        ),
        repository_root
        / "docs"
        / "architecture"
        / "files"
        / f"{safe}.md",
        repository_root
        / "docs"
        / "architecture"
        / "files"
        / f"{safe}.txt",
    ]


def _documentation_state(
    repository_root: Path,
    file: RepositoryFile,
) -> tuple[
    bool,
    bool,
]:
    existing = [
        path
        for path in (
            _documentation_candidates(
                repository_root,
                file.path,
            )
        )
        if path.exists()
        and path.is_file()
    ]

    if not existing:
        return (
            False,
            False,
        )

    latest_documentation = max(
        path.stat().st_mtime
        for path in existing
    )

    return (
        True,
        file.modified_at
        > latest_documentation,
    )


def _security_critical(
    path: str,
    functions: list[
        IndexedFunction
    ],
    endpoints: list[
        IndexedEndpoint
    ],
) -> bool:
    normalized = path.lower()

    if any(
        keyword in normalized
        for keyword in (
            SECURITY_PATH_PATTERNS
        )
    ):
        return True

    if any(
        function.security
        for function in functions
    ):
        return True

    return any(
        endpoint.security_critical
        for endpoint in endpoints
    )


def _description_for(
    path: str,
    layer: str,
    function_count: int,
    endpoint_count: int,
    model_count: int,
    test_count: int,
) -> str:
    details = [
        (
            f"{function_count} "
            "funzioni"
        ),
    ]

    if endpoint_count:
        details.append(
            f"{endpoint_count} endpoint"
        )

    if model_count:
        details.append(
            f"{model_count} modelli"
        )

    if test_count:
        details.append(
            f"{test_count} test"
        )

    return (
        f"{layer}: {path}. "
        "Contiene "
        + ", ".join(
            details,
        )
        + " indicizzati."
    )


def _importance_for(
    security_critical: bool,
    layer: str,
) -> str:
    if security_critical:
        return (
            "Nodo sensibile: modifiche possono "
            "influire su autenticazione, "
            "autorizzazioni o protezione dati."
        )

    if layer in {
        "Backend API",
        "Backend Service",
        "Database Model",
    }:
        return (
            "Nodo applicativo backend: "
            "verificare chiamanti, dati e "
            "contratti prima delle modifiche."
        )

    if layer == "Frontend":
        return (
            "Nodo frontend: verificare "
            "navigazione, stato e contratti API."
        )

    if layer == "Tests":
        return (
            "Nodo di test: utile per la regressione "
            "e la validazione delle modifiche."
        )

    return (
        "Nodo del repository indicizzato "
        "dalla Developer Area."
    )


def build_architecture_index(
) -> ArchitectureIndex:
    repository_root = (
        resolve_repository_root()
    )

    changed_paths = (
        git_changed_paths(
            repository_root,
        )
    )

    indexed: list[
        IndexedFile
    ] = []

    for repository_file in (
        iter_repository_files(
            repository_root,
        )
    ):
        try:
            text = (
                repository_file
                .absolute_path
                .read_text(
                    encoding="utf-8",
                    errors="replace",
                )
            )
        except OSError:
            continue

        suffix = (
            repository_file
            .absolute_path
            .suffix
            .lower()
        )

        endpoints: list[
            IndexedEndpoint
        ] = []

        models: list[
            IndexedModel
        ] = []

        tests: list[
            IndexedTest
        ] = []

        if suffix == ".py":
            (
                functions,
                imports,
                endpoints,
                models,
                tests,
            ) = _python_functions(
                repository_file.path,
                text,
            )

        elif suffix == ".dart":
            (
                functions,
                imports,
                tests,
            ) = _dart_functions(
                repository_file.path,
                text,
            )

        else:
            functions = []
            imports = []

        layer = _layer_for_path(
            repository_file.path,
        )

        documented, outdated = (
            _documentation_state(
                repository_root,
                repository_file,
            )
        )

        security_critical = (
            _security_critical(
                repository_file.path,
                functions,
                endpoints,
            )
        )

        risk = (
            "critical"
            if security_critical
            else "high"
            if (
                layer
                in {
                    "Backend API",
                    "Database Model",
                }
                or endpoints
            )
            else "medium"
        )

        security_notes: list[str] = []

        if security_critical:
            security_notes.append(
                "File classificato "
                "security-critical "
                "dall'indicizzatore."
            )

        for endpoint in endpoints:
            if (
                endpoint.security_critical
            ):
                security_notes.append(
                    (
                        f"{endpoint.method} "
                        f"{endpoint.path} usa "
                        "dipendenze o simboli "
                        "security-sensitive."
                    )
                )

        indexed.append(
            IndexedFile(
                id=repository_file.path,
                path=repository_file.path,
                name=(
                    repository_file
                    .absolute_path
                    .name
                ),
                extension=suffix,
                language=(
                    LANGUAGES.get(
                        suffix,
                        "Unknown",
                    )
                ),
                layer=layer,
                module=_module_for_path(
                    repository_file.path,
                ),
                description=(
                    _description_for(
                        repository_file.path,
                        layer,
                        len(
                            functions,
                        ),
                        len(
                            endpoints,
                        ),
                        len(
                            models,
                        ),
                        len(
                            tests,
                        ),
                    )
                ),
                importance=(
                    _importance_for(
                        security_critical,
                        layer,
                    )
                ),
                documented=documented,
                outdated=outdated,
                changed=(
                    repository_file.path
                    in changed_paths
                ),
                security_critical=(
                    security_critical
                ),
                risk=risk,
                size_bytes=(
                    repository_file
                    .size_bytes
                ),
                modified_at=(
                    repository_file
                    .modified_at
                ),
                content_hash=(
                    repository_file
                    .content_hash
                ),
                functions=functions,
                imports=imports,
                security_notes=(
                    sorted(
                        set(
                            security_notes,
                        ),
                    )
                ),
                endpoints=endpoints,
                models=models,
                tests=tests,
            ),
        )

    index = ArchitectureIndex(
        repository_root=repository_root,
        files=indexed,
        changed_paths=changed_paths,
    )

    _link_internal_calls(
        index,
    )

    _build_relations(
        index,
    )

    _link_test_targets(
        index,
    )

    return index


def _link_internal_calls(
    index: ArchitectureIndex,
) -> None:
    functions_by_name: dict[
        str,
        list[
            tuple[
                IndexedFile,
                IndexedFunction,
            ]
        ],
    ] = {}

    for file in index.files:
        for function in file.functions:
            functions_by_name.setdefault(
                function.name,
                [],
            ).append(
                (
                    file,
                    function,
                ),
            )

    for caller_file in index.files:
        for caller in (
            caller_file.functions
        ):
            for raw_call in caller.calls:
                short = (
                    raw_call
                    .split(".")[-1]
                )

                targets = (
                    functions_by_name.get(
                        short,
                        [],
                    )
                )

                if not targets:
                    continue

                for target_file, target in (
                    targets
                ):
                    reference = (
                        f"{caller_file.path} "
                        f"→ {caller.name}"
                    )

                    if (
                        reference
                        not in target.called_by
                    ):
                        target.called_by.append(
                            reference,
                        )


def _module_to_path(
    module: str,
) -> str:
    if module.startswith(
        "package:",
    ):
        package_value = (
            module.split(
                ":",
                1,
            )[1]
        )

        package_parts = (
            package_value.split(
                "/",
            )
        )

        if (
            package_parts
            and package_parts[0]
            == "fe"
        ):
            package_parts = (
                package_parts[1:]
            )

        return (
            "fe/lib/"
            + "/".join(
                package_parts,
            )
        )

    normalized = (
        module.split(
            ".",
        )
    )

    return "/".join(
        normalized,
    )


def _resolve_import_path(
    imported: str,
    available: set[str],
) -> str | None:
    target = (
        _module_to_path(
            imported,
        )
    )

    if target.startswith(
        "fe/lib/"
    ):
        candidates = [
            target,
            (
                target
                if target.endswith(
                    ".dart",
                )
                else target
                + ".dart"
            ),
        ]
    else:
        candidates = [
            f"BE/{target}.py",
            f"{target}.py",
            f"{target}.dart",
        ]

    return next(
        (
            candidate
            for candidate in candidates
            if candidate in available
        ),
        None,
    )


def _build_relations(
    index: ArchitectureIndex,
) -> None:
    available = {
        file.path
        for file in index.files
    }

    for file in index.files:
        relations: list[
            dict[str, Any]
        ] = []

        seen: set[
            tuple[str, str, str | None]
        ] = set()

        def add_relation(
            relation_type: str,
            label: str,
            target_path: str,
            target_function: str | None = None,
        ) -> None:
            key = (
                relation_type,
                target_path,
                target_function,
            )

            if key in seen:
                return

            seen.add(
                key,
            )

            relations.append(
                {
                    "type":
                        relation_type,
                    "label":
                        label,
                    "target_path":
                        target_path,
                    "target_function":
                        target_function,
                },
            )

        for imported in file.imports:
            resolved = (
                _resolve_import_path(
                    imported,
                    available,
                )
            )

            if resolved is None:
                continue

            add_relation(
                "imports",
                imported,
                resolved,
            )

            target_file = (
                index.by_path.get(
                    resolved,
                )
            )

            if (
                target_file is not None
                and target_file.models
            ):
                add_relation(
                    "uses_model",
                    (
                        "Uses model file "
                        + resolved
                    ),
                    resolved,
                )

        for endpoint in file.endpoints:
            add_relation(
                "endpoint",
                (
                    f"{endpoint.method} "
                    f"{endpoint.path}"
                ),
                file.path,
                endpoint.function_name,
            )

        file.relations = relations


def _normalized_symbol(
    value: str,
) -> str:
    return re.sub(
        r"[^a-z0-9_]+",
        "_",
        value.lower(),
    ).strip(
        "_",
    )


def _link_test_targets(
    index: ArchitectureIndex,
) -> None:
    function_targets: dict[
        str,
        list[
            tuple[
                IndexedFile,
                IndexedFunction,
            ]
        ],
    ] = {}

    for file in index.files:
        for function in file.functions:
            key = (
                _normalized_symbol(
                    function.name,
                )
            )

            function_targets.setdefault(
                key,
                [],
            ).append(
                (
                    file,
                    function,
                ),
            )

    for test_file in index.files:
        if not test_file.tests:
            continue

        for test in test_file.tests:
            candidate_keys = {
                _normalized_symbol(
                    candidate,
                )
                for candidate
                in test.target_candidates
            }

            for call in test.calls:
                candidate_keys.add(
                    _normalized_symbol(
                        call.split(
                            ".",
                        )[-1],
                    )
                )

            for key in candidate_keys:
                if not key:
                    continue

                targets = (
                    function_targets.get(
                        key,
                        [],
                    )
                )

                for (
                    target_file,
                    target_function,
                ) in targets:
                    relation = {
                        "type":
                            "tests",
                        "label":
                            test.name,
                        "target_path":
                            target_file.path,
                        "target_function":
                            target_function.name,
                    }

                    if (
                        relation
                        not in test_file.relations
                    ):
                        test_file.relations.append(
                            relation,
                        )


def get_indexed_file(
    index: ArchitectureIndex,
    path: str,
) -> IndexedFile | None:
    return index.by_path.get(
        path,
    )