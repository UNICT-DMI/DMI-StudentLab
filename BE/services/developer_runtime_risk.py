from __future__ import annotations

from dataclasses import (
    dataclass,
)

from services.developer_indexer import (
    ArchitectureIndex,
    IndexedFile,
    IndexedFunction,
)

from services.developer_source import (
    read_indexed_source,
)


@dataclass(
    frozen=True,
)
class RuntimeFinding:
    id: str
    title: str
    category: str
    severity: str
    confidence: str
    message: str
    evidence: str | None = None
    recommendation: str | None = None


@dataclass(
    frozen=True,
)
class SideEffect:
    category: str
    label: str
    confidence: str
    evidence: str | None = None


SEVERITY_WEIGHT = {
    "info": 0,
    "low": 1,
    "medium": 2,
    "high": 3,
    "critical": 4,
}


def _normalize(
    value: str,
) -> str:
    return (
        value
        .strip()
        .lower()
        .replace("-", "_")
    )


def _find_function(
    file: IndexedFile,
    function_name: str,
) -> IndexedFunction | None:
    normalized = _normalize(
        function_name,
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


def _add_finding(
    findings: list[RuntimeFinding],
    *,
    id: str,
    title: str,
    category: str,
    severity: str,
    confidence: str,
    message: str,
    evidence: str | None = None,
    recommendation: str | None = None,
) -> None:
    if any(
        item.id == id
        for item in findings
    ):
        return

    findings.append(
        RuntimeFinding(
            id=id,
            title=title,
            category=category,
            severity=severity,
            confidence=confidence,
            message=message,
            evidence=evidence,
            recommendation=recommendation,
        ),
    )


def _add_side_effect(
    side_effects: list[SideEffect],
    *,
    category: str,
    label: str,
    confidence: str,
    evidence: str | None = None,
) -> None:
    key = (
        category,
        label,
    )

    if any(
        (
            item.category,
            item.label,
        )
        == key
        for item in side_effects
    ):
        return

    side_effects.append(
        SideEffect(
            category=category,
            label=label,
            confidence=confidence,
            evidence=evidence,
        ),
    )


def _flutter_runtime_findings(
    source: str,
    findings: list[RuntimeFinding],
    side_effects: list[SideEffect],
) -> None:
    lowered = source.lower()

    has_await = (
        "await " in lowered
    )

    uses_context = any(
        token in source
        for token in (
            "context)",
            "context,",
            "context:",
            "Navigator.of(context)",
            "ScaffoldMessenger.of(context)",
            "showDialog(",
            "showModalBottomSheet(",
        )
    )

    has_mounted_guard = any(
        token in source
        for token in (
            "if (!mounted)",
            "if (!context.mounted)",
            "if (!mounted) return",
            "if (!context.mounted) return",
        )
    )

    if (
        has_await
        and uses_context
        and not has_mounted_guard
    ):
        _add_finding(
            findings,
            id="flutter_async_context",
            title="BuildContext after async gap",
            category="flutter_runtime",
            severity="high",
            confidence="inferred",
            message=(
                "The function awaits asynchronous work and "
                "also uses BuildContext without an observed "
                "mounted/context.mounted guard."
            ),
            evidence="await + BuildContext usage",
            recommendation=(
                "Check mounted/context.mounted before using "
                "Navigator, dialogs, ScaffoldMessenger or "
                "other inherited widgets after await."
            ),
        )

    if (
        has_await
        and "Navigator." in source
        and not has_mounted_guard
    ):
        _add_finding(
            findings,
            id="flutter_navigation_after_await",
            title="Navigation after await",
            category="navigation",
            severity="high",
            confidence="inferred",
            message=(
                "Navigation is performed in a function that "
                "contains await without an observed mounted guard."
            ),
            evidence="await + Navigator",
            recommendation=(
                "Ensure the State is still mounted before navigating."
            ),
        )

    if (
        has_await
        and "showDialog(" in source
        and not has_mounted_guard
    ):
        _add_finding(
            findings,
            id="flutter_dialog_after_await",
            title="Dialog after await",
            category="flutter_runtime",
            severity="high",
            confidence="inferred",
            message=(
                "showDialog is used in an async function without "
                "an observed mounted guard."
            ),
            evidence="await + showDialog",
            recommendation=(
                "Guard context usage after the async gap."
            ),
        )

    if "setState(" in source:
        _add_side_effect(
            side_effects,
            category="ui_state",
            label="Updates widget state",
            confidence="observed",
            evidence="setState(...)",
        )

    if "Navigator." in source:
        _add_side_effect(
            side_effects,
            category="navigation",
            label="Changes navigation stack",
            confidence="observed",
            evidence="Navigator",
        )

    if "showDialog(" in source:
        _add_side_effect(
            side_effects,
            category="ui",
            label="Opens dialog",
            confidence="observed",
            evidence="showDialog(...)",
        )

    if "ScaffoldMessenger.of(context)" in source:
        _add_side_effect(
            side_effects,
            category="ui",
            label="Shows snackbar/message",
            confidence="observed",
            evidence="ScaffoldMessenger",
        )


def _network_findings(
    source: str,
    findings: list[RuntimeFinding],
    side_effects: list[SideEffect],
) -> None:
    lowered = source.lower()

    network_tokens = (
        "http.get(",
        "http.post(",
        "http.put(",
        "http.patch(",
        "http.delete(",
        "_get(",
        "_post(",
        "_put(",
        "_patch(",
        "_delete(",
        "apirepository",
        "apiservice",
        "repository.",
    )

    if any(
        token in lowered
        for token in network_tokens
    ):
        _add_side_effect(
            side_effects,
            category="network",
            label="Performs network/API work",
            confidence="observed",
            evidence="HTTP/API call detected",
        )

    if (
        "await " in lowered
        and (
            "http." in lowered
            or "repository." in lowered
            or "api" in lowered
        )
        and "try" not in lowered
    ):
        _add_finding(
            findings,
            id="async_network_without_local_try",
            title="Async network path without local try/catch",
            category="error_handling",
            severity="medium",
            confidence="inferred",
            message=(
                "The function appears to await API/network work "
                "without a local try/catch block."
            ),
            evidence="await + API/network call",
            recommendation=(
                "Confirm the caller or repository layer handles "
                "network and decoding failures consistently."
            ),
        )


def _session_findings(
    source: str,
    side_effects: list[SideEffect],
) -> None:
    tokens = (
        "AuthSession.instance",
        "accessToken",
        "currentUser",
        "logout(",
        "clearSession",
        "saveSession",
        "updateUser",
    )

    for token in tokens:
        if token not in source:
            continue

        _add_side_effect(
            side_effects,
            category="session",
            label="Reads or updates authentication session",
            confidence="observed",
            evidence=token,
        )
        break


def _database_side_effects(
    file: IndexedFile,
    function: IndexedFunction,
    source: str,
    side_effects: list[SideEffect],
) -> None:
    lowered = source.lower()

    write_tokens = (
        "db.add(",
        "db.delete(",
        "db.commit(",
        "db.flush(",
        "session.add(",
        "session.delete(",
        ".update(",
    )

    if any(
        token in lowered
        for token in write_tokens
    ):
        _add_side_effect(
            side_effects,
            category="database",
            label="Writes database state",
            confidence="observed",
            evidence="SQLAlchemy session write/commit",
        )

    if (
        file.layer == "Database Model"
        or file.models
    ):
        _add_side_effect(
            side_effects,
            category="database",
            label="Touches database model contract",
            confidence="inferred",
            evidence=file.path,
        )


def _email_side_effects(
    source: str,
    side_effects: list[SideEffect],
) -> None:
    lowered = source.lower()

    if any(
        token in lowered
        for token in (
            "send_email",
            "smtp",
            "verification_email",
            "resend_email",
            "email_sender",
        )
    ):
        _add_side_effect(
            side_effects,
            category="email",
            label="Sends or schedules email",
            confidence="observed",
            evidence="email/SMTP call",
        )


def _storage_side_effects(
    source: str,
    side_effects: list[SideEffect],
) -> None:
    lowered = source.lower()

    if any(
        token in lowered
        for token in (
            "blob",
            "upload",
            "delete_file",
            "write_text(",
            "write_bytes(",
            "unlink(",
        )
    ):
        _add_side_effect(
            side_effects,
            category="storage",
            label="May modify file/blob storage",
            confidence="inferred",
            evidence="storage/file operation token",
        )


def _exception_paths(
    source: str,
) -> list[dict]:
    paths: list[dict] = []

    for code in (
        "400",
        "401",
        "403",
        "404",
        "409",
        "422",
        "429",
        "500",
        "503",
    ):
        if (
            f"status_code={code}"
            in source
            or f"status.HTTP_{code}"
            in source
        ):
            paths.append(
                {
                    "kind": "http",
                    "code": code,
                    "label": (
                        f"HTTP {code} path observed"
                    ),
                    "confidence": "observed",
                },
            )

    if (
        "raise HTTPException"
        in source
        and not paths
    ):
        paths.append(
            {
                "kind": "http",
                "code": None,
                "label": "HTTPException path observed",
                "confidence": "observed",
            },
        )

    if "throw " in source:
        paths.append(
            {
                "kind": "exception",
                "code": None,
                "label": "Dart exception throw observed",
                "confidence": "observed",
            },
        )

    if "except " in source or "catch (" in source:
        paths.append(
            {
                "kind": "handled",
                "code": None,
                "label": "Handled exception path observed",
                "confidence": "observed",
            },
        )

    return paths


def _overall_risk(
    findings: list[RuntimeFinding],
    security_critical: bool,
) -> str:
    candidates = [
        item.severity
        for item in findings
    ]

    if security_critical:
        candidates.append(
            "high",
        )

    if not candidates:
        return "low"

    return max(
        candidates,
        key=lambda value: (
            SEVERITY_WEIGHT.get(
                value,
                1,
            )
        ),
    )


def build_runtime_risk(
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

    function = _find_function(
        file,
        function_name,
    )

    if function is None:
        return None

    source_result = (
        read_indexed_source(
            index,
            path=path,
            function_name=function.name,
        )
    )

    if source_result is None:
        return None

    source = source_result[
        "source"
    ]

    findings: list[
        RuntimeFinding
    ] = []

    side_effects: list[
        SideEffect
    ] = []

    if file.language == "Dart":
        _flutter_runtime_findings(
            source,
            findings,
            side_effects,
        )

    _network_findings(
        source,
        findings,
        side_effects,
    )

    _session_findings(
        source,
        side_effects,
    )

    _database_side_effects(
        file,
        function,
        source,
        side_effects,
    )

    _email_side_effects(
        source,
        side_effects,
    )

    _storage_side_effects(
        source,
        side_effects,
    )

    security_critical = (
        file.security_critical
        or bool(
            function.security,
        )
    )

    risk = _overall_risk(
        findings,
        security_critical,
    )

    summary = (
        f"{len(findings)} runtime finding(s), "
        f"{len(side_effects)} side effect(s), "
        f"risk {risk.upper()}."
    )

    return {
        "path":
            file.path,
        "function":
            function.name,
        "language":
            file.language,
        "risk":
            risk,
        "summary":
            summary,
        "security_critical":
            security_critical,
        "findings": [
            {
                "id":
                    item.id,
                "title":
                    item.title,
                "category":
                    item.category,
                "severity":
                    item.severity,
                "confidence":
                    item.confidence,
                "message":
                    item.message,
                "evidence":
                    item.evidence,
                "recommendation":
                    item.recommendation,
            }
            for item in findings
        ],
        "side_effects": [
            {
                "category":
                    item.category,
                "label":
                    item.label,
                "confidence":
                    item.confidence,
                "evidence":
                    item.evidence,
            }
            for item in side_effects
        ],
        "error_paths":
            _exception_paths(
                source,
            ),
    }