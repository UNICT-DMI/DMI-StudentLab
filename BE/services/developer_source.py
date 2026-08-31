from __future__ import annotations

from dataclasses import (
    dataclass,
)

from pathlib import (
    Path,
)

from services.developer_indexer import (
    ArchitectureIndex,
    IndexedFile,
    IndexedFunction,
)

from services.developer_repository import (
    ensure_path_inside_repository,
    repository_source_info,
)


MAX_SOURCE_RESPONSE_BYTES = (
    512 * 1024
)


@dataclass(
    frozen=True,
)
class SourceSelection:
    line_start: int
    line_end: int
    source: str


def _function_by_name(
    file: IndexedFile,
    name: str,
) -> IndexedFunction | None:
    normalized = (
        name
        .strip()
        .lower()
    )

    for function in file.functions:
        if (
            function.name
            .strip()
            .lower()
            == normalized
        ):
            return function

    return None


def _line_slice(
    lines: list[str],
    line_start: int,
    line_end: int,
) -> str:
    start_index = max(
        0,
        line_start - 1,
    )

    end_index = min(
        len(lines),
        line_end,
    )

    return "\n".join(
        lines[
            start_index:end_index
        ],
    )


def _infer_braced_symbol_end(
    lines: list[str],
    line_start: int,
) -> int:
    start_index = max(
        0,
        line_start - 1,
    )

    opened = 0
    seen_open = False

    in_single = False
    in_double = False
    escaped = False

    for index in range(
        start_index,
        len(lines),
    ):
        line = lines[index]
        line_comment = False

        position = 0

        while position < len(
            line,
        ):
            char = line[position]

            if line_comment:
                break

            if escaped:
                escaped = False
                position += 1
                continue

            if char == "\\":
                if (
                    in_single
                    or in_double
                ):
                    escaped = True

                position += 1
                continue

            if (
                not in_double
                and char == "'"
            ):
                in_single = (
                    not in_single
                )

                position += 1
                continue

            if (
                not in_single
                and char == '"'
            ):
                in_double = (
                    not in_double
                )

                position += 1
                continue

            if (
                not in_single
                and not in_double
            ):
                if (
                    char == "/"
                    and position + 1
                    < len(line)
                    and line[
                        position + 1
                    ] == "/"
                ):
                    line_comment = True
                    break

                if char == "{":
                    opened += 1
                    seen_open = True

                elif (
                    char == "}"
                    and seen_open
                ):
                    opened -= 1

                    if opened <= 0:
                        return index + 1

            position += 1

    if seen_open:
        return len(
            lines,
        )

    return min(
        len(lines),
        line_start,
    )


def _resolve_function_selection(
    file: IndexedFile,
    function: IndexedFunction,
    lines: list[str],
) -> SourceSelection:
    line_start = (
        function.line_start
        or 1
    )

    line_end = (
        function.line_end
        or line_start
    )

    if (
        file.language == "Dart"
        and line_end <= line_start
    ):
        line_end = (
            _infer_braced_symbol_end(
                lines,
                line_start,
            )
        )

    line_start = max(
        1,
        min(
            line_start,
            len(lines)
            if lines
            else 1,
        ),
    )

    line_end = max(
        line_start,
        min(
            line_end,
            len(lines)
            if lines
            else line_start,
        ),
    )

    return SourceSelection(
        line_start=line_start,
        line_end=line_end,
        source=_line_slice(
            lines,
            line_start,
            line_end,
        ),
    )


def _resolve_file_selection(
    lines: list[str],
) -> SourceSelection:
    if not lines:
        return SourceSelection(
            line_start=1,
            line_end=1,
            source="",
        )

    return SourceSelection(
        line_start=1,
        line_end=len(
            lines,
        ),
        source="\n".join(
            lines,
        ),
    )


def read_indexed_source(
    index: ArchitectureIndex,
    *,
    path: str,
    function_name: str | None = None,
) -> dict | None:
    file = index.by_path.get(
        path,
    )

    if file is None:
        return None

    absolute_path = (
        ensure_path_inside_repository(
            index.repository_root,
            file.path,
        )
    )

    if (
        not absolute_path.exists()
        or not absolute_path.is_file()
    ):
        return None

    try:
        source_text = (
            absolute_path.read_text(
                encoding="utf-8",
                errors="replace",
            )
        )
    except OSError:
        return None

    lines = source_text.splitlines()

    function = None

    if function_name is not None:
        function = _function_by_name(
            file,
            function_name,
        )

        if function is None:
            return None

        selection = (
            _resolve_function_selection(
                file,
                function,
                lines,
            )
        )

    else:
        selection = (
            _resolve_file_selection(
                lines,
            )
        )

    encoded = (
        selection.source.encode(
            "utf-8",
        )
    )

    if (
        len(encoded)
        > MAX_SOURCE_RESPONSE_BYTES
    ):
        raise ValueError(
            "Il sorgente richiesto supera "
            "il limite della Developer Area."
        )

    source_info = (
        repository_source_info(
            index.repository_root,
        )
    )

    return {
        "path":
            file.path,
        "language":
            file.language,
        "symbol":
            (
                function.name
                if function is not None
                else None
            ),
        "source_kind":
            (
                "function"
                if function is not None
                else "file"
            ),
        "line_start":
            selection.line_start,
        "line_end":
            selection.line_end,
        "line_count":
            (
                selection.line_end
                - selection.line_start
                + 1
            ),
        "source":
            selection.source,
        "commit_sha":
            source_info.head_commit,
        "content_hash":
            file.content_hash,
        "repository":
            source_info.repository_label,
        "branch":
            source_info.branch,
    }