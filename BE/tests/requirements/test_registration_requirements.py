from datetime import (
    date,
)

from types import (
    SimpleNamespace,
)

import pytest

from fastapi import (
    HTTPException,
)

from fastapi.testclient import (
    TestClient,
)

from core.database import (
    get_db,
)

from main import (
    app,
)

import main as main_module

from services.registration import (
    validate_policy_acceptance,
    validate_registration_age,
)


client = TestClient(
    app,
)


class FakeQuery:
    def __init__(
        self,
        result=None,
    ):
        self.result = result

    def filter(
        self,
        *args,
        **kwargs,
    ):
        return self

    def first(
        self,
    ):
        return self.result


class FakeDB:
    def __init__(
        self,
    ):
        self.objects = []
        self.committed = False
        self.rolled_back = False
        self.refreshed = []

    def add(
        self,
        obj,
    ):
        self.objects.append(
            obj,
        )

    def flush(
        self,
    ):
        for index, obj in enumerate(
            self.objects,
            start=1,
        ):
            if getattr(
                obj,
                "id",
                None,
            ) is None:
                try:
                    obj.id = index
                except Exception:
                    pass

    def commit(
        self,
    ):
        self.committed = True

    def rollback(
        self,
    ):
        self.rolled_back = True

    def refresh(
        self,
        obj,
    ):
        self.refreshed.append(
            obj,
        )

    def query(
        self,
        *args,
        **kwargs,
    ):
        return FakeQuery()


@pytest.fixture(
    autouse=True,
)
def clear_dependency_overrides():
    app.dependency_overrides.clear()

    yield

    app.dependency_overrides.clear()


@pytest.fixture
def fake_db():
    return FakeDB()


@pytest.fixture
def registration_overrides(
    monkeypatch,
    fake_db,
):
    def override_db():
        yield fake_db

    app.dependency_overrides[
        get_db
    ] = override_db

    monkeypatch.setattr(
        main_module,
        "get_user_by_email",
        lambda db, email: None,
    )

    monkeypatch.setattr(
        main_module,
        "hash_password",
        lambda password: "hashed-password",
    )

    def fake_begin_email_verification(
        db,
        *,
        user,
        secret_key,
    ):
        user.email_verification_id = (
            "registration-test-id"
        )

        return 600

    monkeypatch.setattr(
        main_module,
        "begin_email_verification",
        fake_begin_email_verification,
    )

    return fake_db


def valid_payload(
    **overrides,
):
    payload = {
        "first_name":
            "Mario",
        "last_name":
            "Rossi",
        "email":
            "mario.rossi@studentlab.test",
        "password":
            "Password123!",
        "date_of_birth":
            "2000-01-01",
        "role":
            "student",
        "available":
            True,
        "available_for_help":
            False,
        "available_for_private_lessons":
            False,
        "academic_status":
            "enrolled",
        "policy_version":
            main_module.settings.current_policy_version,
        "privacy_acknowledged":
            True,
        "terms_accepted":
            True,
    }

    payload.update(
        overrides,
    )

    return payload


def academic_payload(
    **overrides,
):
    payload = valid_payload(
        university=(
            "Università degli Studi di Catania"
        ),
        university_code="UNICT",
        department=(
            "Dipartimento di Matematica e Informatica"
        ),
        department_code="DMI",
        course=(
            "Scienze e tecnologie informatiche"
        ),
        course_code="L-31",
        degree_type=(
            "Laurea triennale"
        ),
        start_year=2023,
    )

    payload.update(
        overrides,
    )

    return payload


def test_valid_policy_acceptance():
    validate_policy_acceptance(
        policy_version=(
            main_module.settings.current_policy_version
        ),
        current_policy_version=(
            main_module.settings.current_policy_version
        ),
        privacy_acknowledged=True,
        terms_accepted=True,
    )


def test_privacy_acknowledgement_is_required():
    with pytest.raises(
        ValueError,
    ):
        validate_policy_acceptance(
            policy_version=(
                main_module.settings.current_policy_version
            ),
            current_policy_version=(
                main_module.settings.current_policy_version
            ),
            privacy_acknowledged=False,
            terms_accepted=True,
        )


def test_terms_acceptance_is_required():
    with pytest.raises(
        ValueError,
    ):
        validate_policy_acceptance(
            policy_version=(
                main_module.settings.current_policy_version
            ),
            current_policy_version=(
                main_module.settings.current_policy_version
            ),
            privacy_acknowledged=True,
            terms_accepted=False,
        )


def test_policy_version_must_match_current_version():
    with pytest.raises(
        ValueError,
    ):
        validate_policy_acceptance(
            policy_version="old-policy-version",
            current_policy_version=(
                main_module.settings.current_policy_version
            ),
            privacy_acknowledged=True,
            terms_accepted=True,
        )


def test_valid_registration_age():
    validate_registration_age(
        date(
            2000,
            1,
            1,
        ),
        main_module.settings.minimum_registration_age,
    )


def test_underage_registration_is_rejected():
    today = date.today()

    underage_birth_date = date(
        today.year
        - main_module.settings.minimum_registration_age
        + 1,
        today.month,
        min(
            today.day,
            28,
        ),
    )

    with pytest.raises(
        ValueError,
    ):
        validate_registration_age(
            underage_birth_date,
            main_module.settings.minimum_registration_age,
        )


def test_valid_student_registration(
    registration_overrides,
):
    response = client.post(
        "/register",
        json=valid_payload(),
    )

    assert response.status_code == 200

    body = response.json()

    assert (
        body[
            "email_verification_required"
        ]
        is True
    )

    assert (
        body[
            "registration_id"
        ]
        == "registration-test-id"
    )


def test_teacher_registration_starts_pending(
    registration_overrides,
):
    db = registration_overrides

    response = client.post(
        "/register",
        json=valid_payload(
            email=(
                "teacher@studentlab.test"
            ),
            role="teacher",
        ),
    )

    assert response.status_code == 200

    users = [
        obj
        for obj in db.objects
        if hasattr(
            obj,
            "teacher_verification_status",
        )
    ]

    assert len(
        users,
    ) >= 1

    user = users[
        0
    ]

    assert user.role == "teacher"

    assert (
        user.teacher_verification_status
        == "pending"
    )


def test_student_registration_does_not_require_teacher_verification(
    registration_overrides,
):
    db = registration_overrides

    response = client.post(
        "/register",
        json=valid_payload(
            email=(
                "student@studentlab.test"
            ),
            role="student",
        ),
    )

    assert response.status_code == 200

    users = [
        obj
        for obj in db.objects
        if hasattr(
            obj,
            "teacher_verification_status",
        )
    ]

    assert len(
        users,
    ) >= 1

    user = users[
        0
    ]

    assert user.role == "student"

    assert (
        user.teacher_verification_status
        == "not_required"
    )


def test_registration_without_privacy_is_rejected(
    registration_overrides,
):
    response = client.post(
        "/register",
        json=valid_payload(
            privacy_acknowledged=False,
        ),
    )

    assert response.status_code == 400


def test_registration_without_terms_is_rejected(
    registration_overrides,
):
    response = client.post(
        "/register",
        json=valid_payload(
            terms_accepted=False,
        ),
    )

    assert response.status_code == 400


def test_registration_with_old_policy_version_is_rejected(
    registration_overrides,
):
    response = client.post(
        "/register",
        json=valid_payload(
            policy_version=(
                "old-policy-version"
            ),
        ),
    )

    assert response.status_code == 400


def test_incomplete_academic_path_is_rejected(
    registration_overrides,
):
    response = client.post(
        "/register",
        json=valid_payload(
            university=(
                "Università degli Studi di Catania"
            ),
            university_code="UNICT",
            department=(
                "Dipartimento di Matematica e Informatica"
            ),
        ),
    )

    assert response.status_code == 400


def test_graduated_path_requires_graduation_year(
    registration_overrides,
):
    response = client.post(
        "/register",
        json=academic_payload(
            email=(
                "graduated@studentlab.test"
            ),
            academic_status="graduated",
            graduation_year=None,
        ),
    )

    assert response.status_code == 400


def test_graduation_year_cannot_precede_start_year(
    registration_overrides,
):
    response = client.post(
        "/register",
        json=academic_payload(
            email=(
                "invalid-years@studentlab.test"
            ),
            academic_status="graduated",
            start_year=2024,
            graduation_year=2023,
        ),
    )

    assert response.status_code == 400


def test_non_graduated_path_cannot_have_graduation_year(
    registration_overrides,
):
    response = client.post(
        "/register",
        json=academic_payload(
            email=(
                "invalid-graduation@studentlab.test"
            ),
            academic_status="enrolled",
            graduation_year=2025,
        ),
    )

    assert response.status_code == 400


def test_graduated_academic_path_starts_pending_verification(
    registration_overrides,
):
    db = registration_overrides

    response = client.post(
        "/register",
        json=academic_payload(
            email=(
                "degree@studentlab.test"
            ),
            academic_status="graduated",
            start_year=2020,
            graduation_year=2023,
        ),
    )

    assert response.status_code == 200

    academic_paths = [
        obj
        for obj in db.objects
        if hasattr(
            obj,
            "verification_status",
        )
        and hasattr(
            obj,
            "course_code",
        )
    ]

    assert len(
        academic_paths,
    ) >= 1

    academic_path = academic_paths[
        0
    ]

    assert (
        academic_path.status
        == "graduated"
    )

    assert (
        academic_path.verification_status
        == "pending"
    )


def test_enrolled_academic_path_does_not_require_verification(
    registration_overrides,
):
    db = registration_overrides

    response = client.post(
        "/register",
        json=academic_payload(
            email=(
                "enrolled@studentlab.test"
            ),
            academic_status="enrolled",
        ),
    )

    assert response.status_code == 200

    academic_paths = [
        obj
        for obj in db.objects
        if hasattr(
            obj,
            "verification_status",
        )
        and hasattr(
            obj,
            "course_code",
        )
    ]

    assert len(
        academic_paths,
    ) >= 1

    academic_path = academic_paths[
        0
    ]

    assert (
        academic_path.status
        == "enrolled"
    )

    assert (
        academic_path.verification_status
        == "not_required"
    )


def test_duplicate_email_is_rejected(
    monkeypatch,
    fake_db,
):
    def override_db():
        yield fake_db

    app.dependency_overrides[
        get_db
    ] = override_db

    existing_user = SimpleNamespace(
        id=99,
        email=(
            "duplicate@studentlab.test"
        ),
    )

    monkeypatch.setattr(
        main_module,
        "get_user_by_email",
        lambda db, email: (
            existing_user
        ),
    )

    response = client.post(
        "/register",
        json=valid_payload(
            email=(
                "duplicate@studentlab.test"
            ),
        ),
    )

    assert response.status_code == 409


def test_registration_email_is_normalized(
    registration_overrides,
):
    db = registration_overrides

    response = client.post(
        "/register",
        json=valid_payload(
            email=(
                "  USER@StudentLab.Test  "
            ),
        ),
    )

    assert response.status_code == 200

    users = [
        obj
        for obj in db.objects
        if hasattr(
            obj,
            "email",
        )
        and hasattr(
            obj,
            "password_hash",
        )
    ]

    assert len(
        users,
    ) >= 1

    assert (
        users[
            0
        ].email
        == "user@studentlab.test"
    )


def test_policy_acceptance_is_persisted(
    registration_overrides,
):
    db = registration_overrides

    response = client.post(
        "/register",
        json=valid_payload(
            email=(
                "policy@studentlab.test"
            ),
        ),
    )

    assert response.status_code == 200

    policy_records = [
        obj
        for obj in db.objects
        if hasattr(
            obj,
            "policy_version",
        )
        and hasattr(
            obj,
            "privacy_acknowledged",
        )
        and hasattr(
            obj,
            "terms_accepted",
        )
    ]

    assert len(
        policy_records,
    ) >= 1

    policy_record = policy_records[
        0
    ]

    assert (
        policy_record.policy_version
        == main_module.settings.current_policy_version
    )

    assert (
        policy_record.privacy_acknowledged
        is True
    )

    assert (
        policy_record.terms_accepted
        is True
    )


def test_registration_starts_email_verification(
    registration_overrides,
):
    response = client.post(
        "/register",
        json=valid_payload(
            email=(
                "verify@studentlab.test"
            ),
        ),
    )

    assert response.status_code == 200

    body = response.json()

    assert (
        body[
            "email_verification_required"
        ]
        is True
    )

    assert (
        body[
            "registration_id"
        ]
        == "registration-test-id"
    )

    assert (
        body[
            "expires_in"
        ]
        == 600
    )
    