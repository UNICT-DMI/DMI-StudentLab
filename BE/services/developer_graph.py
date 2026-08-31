from __future__ import annotations

from services.developer_indexer import (
    ArchitectureIndex,
)


def build_graph(
    index: ArchitectureIndex,
) -> dict:
    nodes: list[dict] = []
    edges: list[dict] = []

    file_node_ids: dict[
        str,
        str,
    ] = {}

    function_node_ids: dict[
        tuple[str, str],
        str,
    ] = {}

    for file in index.files:
        file_id = (
            "file:"
            + file.path
        )

        file_node_ids[
            file.path
        ] = file_id

        nodes.append(
            {
                "id": file_id,
                "label": file.name,
                "path": file.path,
                "function_name": None,
                "kind": "file",
                "layer": file.layer,
                "security_critical": (
                    file.security_critical
                ),
            },
        )

        for function in file.functions:
            function_id = (
                "function:"
                + file.path
                + "::"
                + function.name
            )

            function_node_ids[
                (
                    file.path,
                    function.name,
                )
            ] = function_id

            nodes.append(
                {
                    "id": function_id,
                    "label": (
                        function.name
                        + "()"
                    ),
                    "path": file.path,
                    "function_name": (
                        function.name
                    ),
                    "kind": "function",
                    "layer": file.layer,
                    "security_critical": (
                        bool(
                            function.security,
                        )
                    ),
                },
            )

            edges.append(
                {
                    "id": (
                        "contains:"
                        + file_id
                        + ":"
                        + function_id
                    ),
                    "source": file_id,
                    "target": function_id,
                    "type": "contains",
                    "label": "CONTAINS",
                },
            )

    available_functions: dict[
        str,
        list[
            tuple[str, str]
        ],
    ] = {}

    for file in index.files:
        for function in file.functions:
            available_functions.setdefault(
                function.name,
                [],
            ).append(
                (
                    file.path,
                    function.name,
                ),
            )

    for file in index.files:
        source_file_id = (
            file_node_ids[
                file.path
            ]
        )

        for relation in file.relations:
            target_path = (
                relation[
                    "target_path"
                ]
            )

            target_file_id = (
                file_node_ids.get(
                    target_path,
                )
            )

            if target_file_id is None:
                continue

            edges.append(
                {
                    "id": (
                        "relation:"
                        + file.path
                        + ":"
                        + target_path
                        + ":"
                        + relation[
                            "type"
                        ]
                    ),
                    "source": source_file_id,
                    "target": target_file_id,
                    "type": relation[
                        "type"
                    ],
                    "label": relation[
                        "label"
                    ],
                },
            )

        for function in file.functions:
            source_function_id = (
                function_node_ids.get(
                    (
                        file.path,
                        function.name,
                    ),
                )
            )

            if source_function_id is None:
                continue

            for raw_call in function.calls:
                short = (
                    raw_call
                    .split(".")[-1]
                )

                targets = (
                    available_functions.get(
                        short,
                        [],
                    )
                )

                for target_path, target_name in (
                    targets
                ):
                    target_function_id = (
                        function_node_ids.get(
                            (
                                target_path,
                                target_name,
                            ),
                        )
                    )

                    if (
                        target_function_id
                        is None
                    ):
                        continue

                    if (
                        target_function_id
                        == source_function_id
                    ):
                        continue

                    edges.append(
                        {
                            "id": (
                                "call:"
                                + source_function_id
                                + ":"
                                + target_function_id
                            ),
                            "source": (
                                source_function_id
                            ),
                            "target": (
                                target_function_id
                            ),
                            "type": "calls",
                            "label": "CALLS",
                        },
                    )

    deduplicated_edges: dict[
        str,
        dict,
    ] = {
        edge["id"]: edge
        for edge in edges
    }

    return {
        "nodes": nodes,
        "edges": list(
            deduplicated_edges.values(),
        ),
    }
