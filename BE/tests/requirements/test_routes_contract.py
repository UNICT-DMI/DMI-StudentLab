import pytest

from main import app


HTTP_METHODS = {
    "get",
    "post",
    "put",
    "patch",
    "delete",
    "options",
    "head",
}


def route_map():
    schema = app.openapi()

    result = {}

    for path, operations in schema.get(
        "paths",
        {},
    ).items():
        result[path] = {
            method.upper()
            for method in operations.keys()
            if method.lower()
            in HTTP_METHODS
        }

    return result


def iter_routes(
    routes,
):
    for route in routes:
        nested_routes = getattr(
            route,
            "routes",
            None,
        )

        if nested_routes is not None:
            yield from iter_routes(
                nested_routes,
            )

        if (
            getattr(
                route,
                "path",
                None,
            )
            is not None
        ):
            yield route


def dependency_names(
    path,
    method,
):
    method = method.upper()

    for route in iter_routes(
        app.routes,
    ):
        route_path = getattr(
            route,
            "path",
            None,
        )

        route_methods = (
            getattr(
                route,
                "methods",
                None,
            )
            or set()
        )

        if (
            route_path != path
            or method not in route_methods
        ):
            continue

        dependant = getattr(
            route,
            "dependant",
            None,
        )

        if dependant is None:
            return set()

        names = set()

        def collect_dependencies(
            dependency,
        ):
            call = getattr(
                dependency,
                "call",
                None,
            )

            if call is not None:
                names.add(
                    getattr(
                        call,
                        "__name__",
                        str(
                            call,
                        ),
                    )
                )

            for child in getattr(
                dependency,
                "dependencies",
                [],
            ):
                collect_dependencies(
                    child,
                )

        for dependency in dependant.dependencies:
            collect_dependencies(
                dependency,
            )

        return names

    return set()


@pytest.mark.parametrize(
    "path,method,required_dependency",
    [
        (
            "/admin/access",
            "GET",
            "get_admin_user",
        ),
        (
            "/admin/teachers/pending",
            "GET",
            "get_admin_user",
        ),
        (
            "/admin/grades/pending",
            "GET",
            "get_admin_user",
        ),
        (
            "/teacher/access",
            "GET",
            "get_verified_teacher_user",
        ),
        (
            "/teacher/subjects",
            "GET",
            "get_verified_teacher_user",
        ),
        (
            "/teacher/materials/upload-request",
            "POST",
            "get_verified_teacher_user",
        ),
        (
            "/teacher/materials/complete",
            "POST",
            "get_verified_teacher_user",
        ),
        (
            "/teacher/materials",
            "GET",
            "get_verified_teacher_user",
        ),
    ],
)
def test_sensitive_routes_have_required_dependency(
    path,
    method,
    required_dependency,
):
    names = dependency_names(
        path,
        method,
    )

    assert required_dependency in names, (
        f"{method} {path} deve dipendere da "
        f"{required_dependency}; "
        f"dipendenze trovate: "
        f"{sorted(names)}"
    )