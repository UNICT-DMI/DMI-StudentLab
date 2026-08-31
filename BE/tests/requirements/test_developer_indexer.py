from pathlib import Path

from services.developer_indexer import (
    ArchitectureIndex,
    IndexedFile,
    IndexedFunction,
    IndexedTest,
    _dart_functions,
    _link_test_targets,
    _python_functions,
)


def test_python_function_indexing():
    source = """
def verify_password(value: str) -> bool:
    return check(value)

def login(email: str):
    return verify_password(email)
"""

    functions, imports, endpoints, models, tests = (
        _python_functions(
            "BE/services/example.py",
            source,
        )
    )

    names = {
        function.name
        for function in functions
    }

    assert names == {
        "verify_password",
        "login",
    }

    login = next(
        function
        for function in functions
        if function.name == "login"
    )

    assert "verify_password" in login.calls
    assert endpoints == []
    assert models == []
    assert tests == []


def test_fastapi_endpoint_is_observed():
    source = """
from fastapi import Depends

@router.post(
    "/login",
    response_model=TokenResponse,
)
def api_login(
    request: LoginRequest,
    current_user=Depends(get_current_user),
):
    return login(request)
"""

    _, _, endpoints, _, _ = _python_functions(
        "BE/routes/auth.py",
        source,
    )

    assert len(endpoints) == 1

    endpoint = endpoints[0]

    assert endpoint.method == "POST"
    assert endpoint.path == "/login"
    assert endpoint.function_name == "api_login"
    assert endpoint.response_model == "TokenResponse"
    assert "get_current_user" in endpoint.dependencies
    assert endpoint.confidence == "observed"


def test_sqlalchemy_model_is_observed():
    source = """
class User(Base):
    __tablename__ = "users"

    id = mapped_column(primary_key=True)
    email = Column(String)
    groups = relationship("Group")
"""

    _, _, _, models, _ = _python_functions(
        "BE/models/user.py",
        source,
    )

    assert len(models) == 1

    model = models[0]

    assert model.name == "User"
    assert model.table_name == "users"
    assert "id" in model.columns
    assert "email" in model.columns
    assert "groups" in model.relationships
    assert model.confidence == "observed"


def test_pytest_test_is_observed():
    source = """
def authenticate_user():
    return True

def test_authenticate_user():
    assert authenticate_user()
"""

    _, _, _, _, tests = _python_functions(
        "BE/tests/test_auth.py",
        source,
    )

    assert len(tests) == 1

    test = tests[0]

    assert test.name == "test_authenticate_user"
    assert test.framework == "pytest"
    assert "authenticate_user" in test.calls


def test_dart_function_and_test_indexing():
    source = """
import 'package:flutter/material.dart';

Future<void> login(String email) async {
}

bool canAccess(String role) {
  return role == 'creator';
}

testWidgets(
  'login page submits credentials',
  (tester) async {},
);
"""

    functions, imports, tests = _dart_functions(
        "fe/test/login_test.dart",
        source,
    )

    names = {
        function.name
        for function in functions
    }

    assert "login" in names
    assert "canAccess" in names
    assert "package:flutter/material.dart" in imports
    assert len(tests) == 1
    assert tests[0].framework == "flutter_test"


def test_test_relations_are_linked():
    target = IndexedFile(
        id="BE/services/auth.py",
        path="BE/services/auth.py",
        name="auth.py",
        extension=".py",
        language="Python",
        layer="Backend Service",
        module="services",
        description="",
        importance="",
        documented=False,
        outdated=False,
        changed=False,
        security_critical=True,
        risk="critical",
        size_bytes=1,
        modified_at=0,
        content_hash="x",
        functions=[
            IndexedFunction(
                id=(
                    "BE/services/auth.py"
                    "::authenticate_user"
                ),
                name="authenticate_user",
                signature="authenticate_user()",
            ),
        ],
    )

    test_file = IndexedFile(
        id="BE/tests/test_auth.py",
        path="BE/tests/test_auth.py",
        name="test_auth.py",
        extension=".py",
        language="Python",
        layer="Tests",
        module="tests",
        description="",
        importance="",
        documented=False,
        outdated=False,
        changed=False,
        security_critical=False,
        risk="medium",
        size_bytes=1,
        modified_at=0,
        content_hash="y",
        tests=[
            IndexedTest(
                name="test_authenticate_user",
                framework="pytest",
                calls=[
                    "authenticate_user",
                ],
                target_candidates=[
                    "authenticate_user",
                ],
            ),
        ],
    )

    index = ArchitectureIndex(
        repository_root=Path("."),
        files=[
            target,
            test_file,
        ],
        changed_paths=set(),
    )

    _link_test_targets(index)

    assert any(
        relation["type"] == "tests"
        and relation["target_path"]
        == "BE/services/auth.py"
        and relation["target_function"]
        == "authenticate_user"
        for relation in test_file.relations
    )