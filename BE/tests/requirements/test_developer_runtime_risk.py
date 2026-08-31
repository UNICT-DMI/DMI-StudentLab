from pathlib import (
    Path,
)

from services.developer_indexer import (
    ArchitectureIndex,
    IndexedFile,
    IndexedFunction,
)

from services.developer_runtime_risk import (
    _exception_paths,
    _flutter_runtime_findings,
    _network_findings,
    RuntimeFinding,
    SideEffect,
)


def test_flutter_async_context_risk():
    source = """
Future<void> submit() async {
  await repository.save();
  Navigator.of(context).pop();
}
"""

    findings: list[
        RuntimeFinding
    ] = []

    side_effects: list[
        SideEffect
    ] = []

    _flutter_runtime_findings(
        source,
        findings,
        side_effects,
    )

    ids = {
        item.id
        for item in findings
    }

    assert (
        "flutter_async_context"
        in ids
    )

    assert (
        "flutter_navigation_after_await"
        in ids
    )


def test_mounted_guard_reduces_flutter_risk():
    source = """
Future<void> submit() async {
  await repository.save();
  if (!mounted) return;
  Navigator.of(context).pop();
}
"""

    findings: list[
        RuntimeFinding
    ] = []

    side_effects: list[
        SideEffect
    ] = []

    _flutter_runtime_findings(
        source,
        findings,
        side_effects,
    )

    ids = {
        item.id
        for item in findings
    }

    assert (
        "flutter_async_context"
        not in ids
    )


def test_network_side_effect_detected():
    source = """
Future<void> load() async {
  await http.get(uri);
}
"""

    findings: list[
        RuntimeFinding
    ] = []

    side_effects: list[
        SideEffect
    ] = []

    _network_findings(
        source,
        findings,
        side_effects,
    )

    assert any(
        item.category == "network"
        for item in side_effects
    )


def test_http_error_paths_detected():
    source = """
raise HTTPException(
    status_code=403,
    detail="Forbidden",
)
"""

    paths = _exception_paths(
        source,
    )

    assert any(
        item["code"] == "403"
        for item in paths
    )
