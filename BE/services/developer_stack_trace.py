from __future__ import annotations

from dataclasses import (
    dataclass,
)

import re

from services.developer_impact import (
    build_impact_analysis,
)

from services.developer_indexer import (
    ArchitectureIndex,
    IndexedFile,
    IndexedFunction,
)

from services.developer_runtime_risk import (
    build_runtime_risk,
)


FLUTTER_FRAME_PATTERN = re.compile(
    r"(?P<path>(?:package:[^:\s]+/)?"
    r"(?:lib|test)/[^:\s)]+\.dart)"
    r":(?P<line>\d+)"
    r"(?::(?P<column>\d+))?"
)

ABSOLUTE_DART_PATTERN = re.compile(
    r"(?P<path>(?:[A-Za-z]:)?[^()\n]*?"
    r"(?:/|\\)(?:lib|test)(?:/|\\)[^:\s)]+\.dart)"
    r":(?P<line>\d+)"
    r"(?::(?P<column>\d+))?"
)

SYMBOL_PATTERN = re.compile(
    r"#\d+\s+"
    r"(?P<symbol>[A-Za-z0-9_<>.$]+)"
    r"(?:\s+\([^)]*\))?"
)


@dataclass(
    frozen=True,
)
class StackFrameCandidate:
    raw: str
    path: str | None
    line: int | None
    column: int | None
    symbol: str | None
    confidence: str


def _normalize_path(
    value: str,
) -> str:
    path = (
        value
        .replace("\\", "/")
        .strip()
    )

    if path.startswith(
        "package:",
    ):
        package_value = (
            path.split(
                ":",
                1,
            )[1]
        )

        parts = package_value.split(
            "/",
        )

        if parts:
            parts = parts[1:]

        path = "/".join(
            parts,
        )

    marker = "/lib/"

    if marker in path:
        path = (
            "fe/lib/"
            + path.split(
                marker,
                1,
            )[1]
        )

    marker = "/test/"

    if marker in path:
        path = (
            "fe/test/"
            + path.split(
                marker,
                1,
            )[1]
        )

    if path.startswith(
        "lib/",
    ):
        path = (
            "fe/"
            + path
        )

    if path.startswith(
        "test/",
    ):
        path = (
            "fe/"
            + path
        )

    return path


def _symbol_from_line(
    line: str,
) -> str | None:
    match = SYMBOL_PATTERN.search(
        line,
    )

    if match is None:
        return None

    symbol = (
        match.group(
            "symbol",
        )
        .split(".")[-1]
    )

    if symbol in {
        "<anonymous closure>",
        "<fn>",
    }:
        return None

    return symbol


def parse_stack_trace(
    stack_trace: str,
) -> list[
    StackFrameCandidate
]:
    frames: list[
        StackFrameCandidate
    ] = []

    for raw_line in stack_trace.splitlines():
        line = raw_line.strip()

        if not line:
            continue

        match = (
            FLUTTER_FRAME_PATTERN.search(
                line,
            )
            or ABSOLUTE_DART_PATTERN.search(
                line,
            )
        )

        symbol = _symbol_from_line(
            line,
        )

        if match is None:
            if symbol is not None:
                frames.append(
                    StackFrameCandidate(
                        raw=line,
                        path=None,
                        line=None,
                        column=None,
                        symbol=symbol,
                        confidence="inferred",
                    ),
                )
            continue

        frames.append(
            StackFrameCandidate(
                raw=line,
                path=_normalize_path(
                    match.group(
                        "path",
                    ),
                ),
                line=int(
                    match.group(
                        "line",
                    ),
                ),
                column=(
                    int(
                        match.group(
                            "column",
                        ),
                    )
                    if match.group(
                        "column",
                    )
                    else None
                ),
                symbol=symbol,
                confidence="observed",
            ),
        )

    return frames


def _function_for_line(
    file: IndexedFile,
    line: int,
) -> IndexedFunction | None:
    exact = [
        function
        for function in file.functions
        if (
            function.line_start is not None
            and function.line_end is not None
            and function.line_start
            <= line
            <= function.line_end
        )
    ]

    if exact:
        return min(
            exact,
            key=lambda function: (
                (
                    function.line_end
                    or line
                )
                - (
                    function.line_start
                    or line
                )
            ),
        )

    candidates = [
        function
        for function in file.functions
        if (
            function.line_start
            is not None
            and function.line_start
            <= line
        )
    ]

    if not candidates:
        return None

    return max(
        candidates,
        key=lambda function: (
            function.line_start
            or 0
        ),
    )


def _function_by_symbol(
    file: IndexedFile,
    symbol: str | None,
) -> IndexedFunction | None:
    if not symbol:
        return None

    normalized = (
        symbol
        .strip()
        .lower()
    )

    for function in file.functions:
        if (
            function.name.lower()
            == normalized
        ):
            return function

    return None


def analyze_stack_trace(
    index: ArchitectureIndex,
    stack_trace: str,
) -> dict:
    parsed = parse_stack_trace(
        stack_trace,
    )

    resolved_frames: list[
        dict
    ] = []

    primary: dict | None = None

    for position, frame in enumerate(
        parsed,
        start=1,
    ):
        file = (
            index.by_path.get(
                frame.path,
            )
            if frame.path
            else None
        )

        function = None

        if (
            file is not None
            and frame.line is not None
        ):
            function = _function_for_line(
                file,
                frame.line,
            )

        if (
            file is not None
            and function is None
        ):
            function = _function_by_symbol(
                file,
                frame.symbol,
            )

        app_frame = (
            file is not None
            and file.path.startswith(
                "fe/"
            )
        )

        confidence = (
            "observed"
            if (
                file is not None
                and frame.line is not None
            )
            else frame.confidence
        )

        resolved = {
            "position":
                position,
            "raw":
                frame.raw,
            "path":
                frame.path,
            "line":
                frame.line,
            "column":
                frame.column,
            "symbol":
                (
                    function.name
                    if function is not None
                    else frame.symbol
                ),
            "resolved":
                file is not None,
            "app_frame":
                app_frame,
            "confidence":
                confidence,
        }

        resolved_frames.append(
            resolved,
        )

        if (
            primary is None
            and app_frame
        ):
            primary = {
                **resolved,
                "file":
                    file,
                "function_obj":
                    function,
            }

    runtime = None
    impact = None

    if primary is not None:
        primary_file = primary[
            "file"
        ]
        primary_function = primary[
            "function_obj"
        ]

        if primary_function is not None:
            runtime = build_runtime_risk(
                index,
                path=primary_file.path,
                function_name=(
                    primary_function.name
                ),
            )

            impact = build_impact_analysis(
                index,
                path=primary_file.path,
                function_name=(
                    primary_function.name
                ),
            )

    user_frames = [
        frame
        for frame in resolved_frames
        if frame[
            "app_frame"
        ]
    ]

    unresolved = [
        frame
        for frame in resolved_frames
        if not frame[
            "resolved"
        ]
    ]

    if primary is None:
        diagnosis = (
            "No StudentLab Flutter frame "
            "could be resolved from this stack trace."
        )
        risk = "low"
    else:
        target = (
            primary.get(
                "symbol",
            )
            or primary.get(
                "path",
            )
            or "unknown"
        )

        risk = (
            runtime[
                "risk"
            ]
            if runtime is not None
            else (
                impact[
                    "risk"
                ]
                if impact is not None
                else "medium"
            )
        )

        diagnosis = (
            f"Primary StudentLab crash candidate: "
            f"{target} at "
            f"{primary.get('path')}:"
            f"{primary.get('line')}."
        )

        if runtime is not None:
            diagnosis += (
                f" Runtime analysis found "
                f"{len(runtime['findings'])} "
                "finding(s)."
            )

        if impact is not None:
            diagnosis += (
                f" Impact analysis links "
                f"{len(impact['flows'])} "
                "flow(s) and "
                f"{len(impact['related_files'])} "
                "related file(s)."
            )

    primary_response = None

    if primary is not None:
        primary_response = {
            "path":
                primary.get(
                    "path",
                ),
            "line":
                primary.get(
                    "line",
                ),
            "column":
                primary.get(
                    "column",
                ),
            "symbol":
                primary.get(
                    "symbol",
                ),
            "confidence":
                primary.get(
                    "confidence",
                ),
        }

    return {
        "diagnosis":
            diagnosis,
        "risk":
            risk,
        "primary_frame":
            primary_response,
        "frames":
            resolved_frames,
        "studentlab_frames":
            len(
                user_frames,
            ),
        "unresolved_frames":
            len(
                unresolved,
            ),
        "runtime":
            runtime,
        "impact":
            impact,
    }
