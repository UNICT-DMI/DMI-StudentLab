from pathlib import (
    Path,
)

from services.developer_indexer import (
    ArchitectureIndex,
    IndexedFile,
    IndexedFunction,
)

from services.developer_source import (
    _infer_braced_symbol_end,
    read_indexed_source,
)


def _index_for_file(
    tmp_path: Path,
    *,
    relative_path: str,
    content: str,
    language: str,
    function: IndexedFunction,
) -> ArchitectureIndex:
    absolute = (
        tmp_path
        / relative_path
    )

    absolute.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    absolute.write_text(
        content,
        encoding="utf-8",
    )

    file = IndexedFile(
        id=relative_path,
        path=relative_path,
        name=absolute.name,
        extension=absolute.suffix,
        language=language,
        layer="Frontend",
        module="test",
        description="",
        importance="",
        documented=False,
        outdated=False,
        changed=False,
        security_critical=False,
        risk="medium",
        size_bytes=len(
            content.encode(
                "utf-8",
            )
        ),
        modified_at=0,
        content_hash="hash",
        functions=[
            function,
        ],
    )

    return ArchitectureIndex(
        repository_root=tmp_path,
        files=[
            file,
        ],
        changed_paths=set(),
    )


def test_dart_brace_scanner_finds_end():
    lines = [
        "Future<void> example() async {",
        "  if (true) {",
        "    print('ok');",
        "  }",
        "}",
        "void next() {}",
    ]

    assert (
        _infer_braced_symbol_end(
            lines,
            1,
        )
        == 5
    )


def test_source_reader_returns_function_block(
    tmp_path: Path,
    monkeypatch,
):
    relative = (
        "fe/lib/example.dart"
    )

    content = """Future<void> example() async {
  if (true) {
    print('ok');
  }
}

void next() {}
"""

    function = IndexedFunction(
        id=(
            relative
            + "::example"
        ),
        name="example",
        signature="example()",
        line_start=1,
        line_end=1,
    )

    index = _index_for_file(
        tmp_path,
        relative_path=relative,
        content=content,
        language="Dart",
        function=function,
    )

    class SourceInfo:
        head_commit = "abc123"
        repository_label = "repo"
        branch = "main"

    monkeypatch.setattr(
        "services.developer_source."
        "repository_source_info",
        lambda _: SourceInfo(),
    )

    result = read_indexed_source(
        index,
        path=relative,
        function_name="example",
    )

    assert result is not None
    assert (
        result["source_kind"]
        == "function"
    )
    assert result["line_start"] == 1
    assert result["line_end"] == 5
    assert (
        "print('ok');"
        in result["source"]
    )
    assert (
        "void next()"
        not in result["source"]
    )
    assert (
        result["commit_sha"]
        == "abc123"
    )


def test_source_reader_rejects_unknown_file(
    tmp_path: Path,
):
    index = ArchitectureIndex(
        repository_root=tmp_path,
        files=[],
        changed_paths=set(),
    )

    assert (
        read_indexed_source(
            index,
            path="../../.env",
        )
        is None
    )