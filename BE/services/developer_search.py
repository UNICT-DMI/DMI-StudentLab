from __future__ import annotations

import re

from services.developer_indexer import (
    ArchitectureIndex,
)


INTENT_EXPANSIONS = {
    "login": {
        "auth",
        "authenticate",
        "password",
        "token",
        "session",
    },
    "docente": {
        "teacher",
        "verified",
        "verification",
        "assignment",
    },
    "teacher": {
        "docente",
        "verified",
        "verification",
        "assignment",
    },
    "sicurezza": {
        "security",
        "auth",
        "permission",
        "role",
        "token",
    },
    "security": {
        "sicurezza",
        "auth",
        "permission",
        "role",
        "token",
    },
    "materiale": {
        "material",
        "upload",
        "blob",
        "download",
    },
    "gruppo": {
        "group",
        "member",
        "owner",
        "admin",
    },
    "notifica": {
        "notification",
        "unread",
        "recipient",
    },
}


def _tokens(
    value: str,
) -> list[str]:
    return [
        token
        for token in re.findall(
            r"[a-zA-Z0-9_./-]+",
            value.lower(),
        )
        if len(token) >= 2
    ]


def _expanded_tokens(
    query: str,
) -> set[str]:
    tokens = set(
        _tokens(
            query,
        ),
    )

    expanded = set(
        tokens,
    )

    for token in tokens:
        expanded.update(
            INTENT_EXPANSIONS.get(
                token,
                set(),
            ),
        )

    return expanded


def _score_text(
    query: str,
    tokens: set[str],
    text: str,
) -> tuple[
    float,
    list[str],
]:
    normalized = (
        text.lower()
    )

    score = 0.0
    reasons: list[str] = []

    exact = (
        query.strip().lower()
    )

    if (
        exact
        and exact in normalized
    ):
        score += 10.0
        reasons.append(
            "corrispondenza frase",
        )

    for token in tokens:
        if token not in normalized:
            continue

        occurrences = (
            normalized.count(
                token,
            )
        )

        score += min(
            6.0,
            1.5 * occurrences,
        )

        reasons.append(
            f"match: {token}",
        )

    return (
        score,
        reasons,
    )


def search_architecture(
    index: ArchitectureIndex,
    query: str,
    limit: int = 30,
) -> list[dict]:
    query = query.strip()

    if not query:
        return []

    tokens = _expanded_tokens(
        query,
    )

    results: list[dict] = []

    for file in index.files:
        file_text = " ".join(
            [
                file.path,
                file.name,
                file.layer,
                file.module,
                file.description,
                file.importance,
                " ".join(
                    file.imports,
                ),
                " ".join(
                    file.flows,
                ),
                " ".join(
                    file.security_notes,
                ),
            ],
        )

        score, reasons = (
            _score_text(
                query,
                tokens,
                file_text,
            )
        )

        if file.security_critical and (
            "security" in tokens
            or "sicurezza" in tokens
        ):
            score += 4.0
            reasons.append(
                "security-critical",
            )

        if score > 0:
            results.append(
                {
                    "kind": "file",
                    "title": file.name,
                    "subtitle": (
                        f"{file.layer} · "
                        f"{file.module}"
                    ),
                    "path": file.path,
                    "function_name": None,
                    "score": score,
                    "reasons": reasons,
                },
            )

        for function in file.functions:
            function_text = " ".join(
                [
                    function.name,
                    function.signature,
                    function.description,
                    " ".join(
                        function.calls,
                    ),
                    " ".join(
                        function.called_by,
                    ),
                    " ".join(
                        function.flows,
                    ),
                    " ".join(
                        function.security,
                    ),
                    file.path,
                ],
            )

            function_score, function_reasons = (
                _score_text(
                    query,
                    tokens,
                    function_text,
                )
            )

            if function.name.lower() in query.lower():
                function_score += 8.0
                function_reasons.append(
                    "nome funzione",
                )

            if function_score <= 0:
                continue

            results.append(
                {
                    "kind": "function",
                    "title": (
                        f"{function.name}()"
                    ),
                    "subtitle": file.path,
                    "path": file.path,
                    "function_name": (
                        function.name
                    ),
                    "score": (
                        function_score
                        + 2.0
                    ),
                    "reasons": (
                        function_reasons
                    ),
                },
            )

    results.sort(
        key=lambda item: (
            -item["score"],
            item["path"],
            item["title"],
        ),
    )

    return results[
        :max(
            1,
            min(
                limit,
                100,
            ),
        )
    ]
