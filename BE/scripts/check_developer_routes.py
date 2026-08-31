from __future__ import annotations

from collections.abc import (
    Iterable,
)

from typing import (
    Any,
)

from main import (
    app,
)


DEVELOPER_PREFIX = "/developer"


def _children(
    route: Any,
) -> Iterable[Any]:
    routes = getattr(
        route,
        "routes",
        None,
    )

    if isinstance(
        routes,
        Iterable,
    ):
        return routes

    router = getattr(
        route,
        "router",
        None,
    )

    nested_routes = getattr(
        router,
        "routes",
        None,
    )

    if isinstance(
        nested_routes,
        Iterable,
    ):
        return nested_routes

    return ()


def _route_path(
    route: Any,
) -> str | None:
    path = getattr(
        route,
        "path",
        None,
    )

    if isinstance(
        path,
        str,
    ):
        return path

    path_format = getattr(
        route,
        "path_format",
        None,
    )

    if isinstance(
        path_format,
        str,
    ):
        return path_format

    return None


def iter_routes(
    routes: Iterable[Any],
    *,
    seen: set[int] | None = None,
):
    if seen is None:
        seen = set()

    for route in routes:
        route_id = id(
            route,
        )

        if route_id in seen:
            continue

        seen.add(
            route_id,
        )

        path = _route_path(
            route,
        )

        if path is not None:
            yield route

        children = _children(
            route,
        )

        if children:
            yield from iter_routes(
                children,
                seen=seen,
            )


def _methods(
    route: Any,
) -> str:
    methods = getattr(
        route,
        "methods",
        None,
    )

    if not methods:
        return "-"

    return ",".join(
        sorted(
            str(
                method,
            )
            for method in methods
        ),
    )


def main() -> int:
    developer_routes = []

    for route in iter_routes(
        app.routes,
    ):
        path = _route_path(
            route,
        )

        if (
            path is not None
            and path.startswith(
                DEVELOPER_PREFIX,
            )
        ):
            developer_routes.append(
                (
                    path,
                    _methods(
                        route,
                    ),
                ),
            )

    developer_routes = sorted(
        set(
            developer_routes,
        ),
    )

    if not developer_routes:
        print(
            "ERRORE: nessuna route "
            "/developer registrata."
        )
        return 1

    print(
        "Route Developer registrate:"
    )

    for path, methods in (
        developer_routes
    ):
        print(
            f"{methods:12} {path}"
        )

    required_paths = {
        "/developer/access",
        "/developer/status",
        "/developer/tree",
        "/developer/files",
        "/developer/file",
        "/developer/search",
        "/developer/graph",
    }

    available_paths = {
        path
        for path, _ in developer_routes
    }

    missing = (
        required_paths
        - available_paths
    )

    if missing:
        print()
        print(
            "Route mancanti:"
        )

        for path in sorted(
            missing,
        ):
            print(
                f"- {path}"
            )

        return 2

    print()
    print(
        "OK: tutte le route "
        "Developer richieste sono registrate."
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(
        main(),
    )