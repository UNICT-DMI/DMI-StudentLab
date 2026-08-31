from datetime import (
    datetime,
    timezone,
)

from types import (
    SimpleNamespace,
)

import pytest

from fastapi import (
    HTTPException,
)

import core.security as security


def make_user(
    *,
    user_id: int = 1,
    role: str = "student",
    teacher_verification_status: str = "not_required",
    is_active: bool = True,
    email_verified: bool = True,
):
    return SimpleNamespace(
        id=user_id,
        role=role,
        teacher_verification_status=(
            teacher_verification_status
        ),
        is_active=is_active,
        email_verified_at=(
            datetime.now(
                timezone.utc,
            )
            if email_verified
            else None
        ),
    )


@pytest.fixture
def fake_db():
    return object()


@pytest.fixture
def mock_user_lookup(
    monkeypatch,
):
    def apply(
        user,
    ):
        monkeypatch.setattr(
            security,
            "get_user_by_id",
            lambda db, user_id: user,
        )

    return apply


def test_student_cannot_access_admin_gate(
    fake_db,
    mock_user_lookup,
):
    student = make_user(
        role="student",
    )

    mock_user_lookup(
        student,
    )

    with pytest.raises(
        HTTPException,
    ) as exception_info:
        security.get_admin_user(
            current_user=student,
            db=fake_db,
        )

    assert (
        exception_info.value.status_code
        == 403
    )


def test_verified_teacher_cannot_access_admin_gate(
    fake_db,
    mock_user_lookup,
):
    teacher = make_user(
        role="teacher",
        teacher_verification_status=(
            "verified"
        ),
    )

    mock_user_lookup(
        teacher,
    )

    with pytest.raises(
        HTTPException,
    ) as exception_info:
        security.get_admin_user(
            current_user=teacher,
            db=fake_db,
        )

    assert (
        exception_info.value.status_code
        == 403
    )


def test_admin_can_access_admin_gate(
    fake_db,
    mock_user_lookup,
):
    admin = make_user(
        role="admin",
    )

    mock_user_lookup(
        admin,
    )

    result = security.get_admin_user(
        current_user=admin,
        db=fake_db,
    )

    assert result is admin

    assert result.role == "admin"


def test_creator_can_access_admin_gate(
    fake_db,
    mock_user_lookup,
):
    creator = make_user(
        role="creator",
    )

    mock_user_lookup(
        creator,
    )

    result = security.get_admin_user(
        current_user=creator,
        db=fake_db,
    )

    assert result is creator

    assert result.role == "creator"


@pytest.mark.parametrize(
    "role",
    [
        "student",
        "teacher",
        "admin",
    ],
)
def test_non_creator_cannot_access_creator_gate(
    role,
    fake_db,
    mock_user_lookup,
):
    user = make_user(
        role=role,
        teacher_verification_status=(
            "verified"
            if role == "teacher"
            else "not_required"
        ),
    )

    mock_user_lookup(
        user,
    )

    with pytest.raises(
        HTTPException,
    ) as exception_info:
        security.get_creator_user(
            current_user=user,
            db=fake_db,
        )

    assert (
        exception_info.value.status_code
        == 403
    )


def test_creator_can_access_creator_gate(
    fake_db,
    mock_user_lookup,
):
    creator = make_user(
        role="creator",
    )

    mock_user_lookup(
        creator,
    )

    result = security.get_creator_user(
        current_user=creator,
        db=fake_db,
    )

    assert result is creator


def test_student_cannot_access_teacher_gate(
    fake_db,
    mock_user_lookup,
):
    student = make_user(
        role="student",
    )

    mock_user_lookup(
        student,
    )

    with pytest.raises(
        HTTPException,
    ) as exception_info:
        security.get_verified_teacher_user(
            current_user=student,
            db=fake_db,
        )

    assert (
        exception_info.value.status_code
        == 403
    )


def test_pending_teacher_cannot_access_teacher_gate(
    fake_db,
    mock_user_lookup,
):
    teacher = make_user(
        role="teacher",
        teacher_verification_status=(
            "pending"
        ),
    )

    mock_user_lookup(
        teacher,
    )

    with pytest.raises(
        HTTPException,
    ) as exception_info:
        security.get_verified_teacher_user(
            current_user=teacher,
            db=fake_db,
        )

    assert (
        exception_info.value.status_code
        == 403
    )


def test_rejected_teacher_cannot_access_teacher_gate(
    fake_db,
    mock_user_lookup,
):
    teacher = make_user(
        role="teacher",
        teacher_verification_status=(
            "rejected"
        ),
    )

    mock_user_lookup(
        teacher,
    )

    with pytest.raises(
        HTTPException,
    ) as exception_info:
        security.get_verified_teacher_user(
            current_user=teacher,
            db=fake_db,
        )

    assert (
        exception_info.value.status_code
        == 403
    )


def test_verified_teacher_can_access_teacher_gate(
    fake_db,
    mock_user_lookup,
):
    teacher = make_user(
        role="teacher",
        teacher_verification_status=(
            "verified"
        ),
    )

    mock_user_lookup(
        teacher,
    )

    result = security.get_verified_teacher_user(
        current_user=teacher,
        db=fake_db,
    )

    assert result is teacher

    assert result.role == "teacher"

    assert (
        result.teacher_verification_status
        == "verified"
    )


def test_teacher_not_required_status_is_not_verified(
    fake_db,
    mock_user_lookup,
):
    teacher = make_user(
        role="teacher",
        teacher_verification_status=(
            "not_required"
        ),
    )

    mock_user_lookup(
        teacher,
    )

    with pytest.raises(
        HTTPException,
    ) as exception_info:
        security.get_verified_teacher_user(
            current_user=teacher,
            db=fake_db,
        )

    assert (
        exception_info.value.status_code
        == 403
    )


@pytest.mark.parametrize(
    "role",
    [
        "",
        "unknown",
        "moderator",
        "superuser",
        "root",
    ],
)
def test_unknown_roles_cannot_access_admin_gate(
    role,
    fake_db,
    mock_user_lookup,
):
    user = make_user(
        role=role,
    )

    mock_user_lookup(
        user,
    )

    with pytest.raises(
        HTTPException,
    ) as exception_info:
        security.get_admin_user(
            current_user=user,
            db=fake_db,
        )

    assert (
        exception_info.value.status_code
        == 403
    )


@pytest.mark.parametrize(
    "role",
    [
        "",
        "unknown",
        "moderator",
        "superuser",
        "root",
    ],
)
def test_unknown_roles_cannot_access_teacher_gate(
    role,
    fake_db,
    mock_user_lookup,
):
    user = make_user(
        role=role,
        teacher_verification_status=(
            "verified"
        ),
    )

    mock_user_lookup(
        user,
    )

    with pytest.raises(
        HTTPException,
    ) as exception_info:
        security.get_verified_teacher_user(
            current_user=user,
            db=fake_db,
        )

    assert (
        exception_info.value.status_code
        == 403
    )


def test_unverified_email_student_cannot_access_admin_gate(
    fake_db,
    mock_user_lookup,
):
    student = make_user(
        role="student",
        email_verified=False,
    )

    mock_user_lookup(
        student,
    )

    with pytest.raises(
        HTTPException,
    ) as exception_info:
        security.get_admin_user(
            current_user=student,
            db=fake_db,
        )

    assert (
        exception_info.value.status_code
        in {
            401,
            403,
        }
    )


def test_unverified_email_admin_cannot_access_admin_gate(
    fake_db,
    mock_user_lookup,
):
    admin = make_user(
        role="admin",
        email_verified=False,
    )

    mock_user_lookup(
        admin,
    )

    with pytest.raises(
        HTTPException,
    ) as exception_info:
        security.get_admin_user(
            current_user=admin,
            db=fake_db,
        )

    assert (
        exception_info.value.status_code
        in {
            401,
            403,
        }
    )


def test_unverified_email_creator_cannot_access_creator_gate(
    fake_db,
    mock_user_lookup,
):
    creator = make_user(
        role="creator",
        email_verified=False,
    )

    mock_user_lookup(
        creator,
    )

    with pytest.raises(
        HTTPException,
    ) as exception_info:
        security.get_creator_user(
            current_user=creator,
            db=fake_db,
        )

    assert (
        exception_info.value.status_code
        in {
            401,
            403,
        }
    )


def test_unverified_email_teacher_cannot_access_teacher_gate(
    fake_db,
    mock_user_lookup,
):
    teacher = make_user(
        role="teacher",
        teacher_verification_status=(
            "verified"
        ),
        email_verified=False,
    )

    mock_user_lookup(
        teacher,
    )

    with pytest.raises(
        HTTPException,
    ) as exception_info:
        security.get_verified_teacher_user(
            current_user=teacher,
            db=fake_db,
        )

    assert (
        exception_info.value.status_code
        in {
            401,
            403,
        }
    )


def test_inactive_admin_cannot_access_admin_gate(
    fake_db,
    mock_user_lookup,
):
    admin = make_user(
        role="admin",
        is_active=False,
    )

    mock_user_lookup(
        admin,
    )

    with pytest.raises(
        HTTPException,
    ) as exception_info:
        security.get_admin_user(
            current_user=admin,
            db=fake_db,
        )

    assert (
        exception_info.value.status_code
        in {
            401,
            403,
        }
    )


def test_inactive_creator_cannot_access_creator_gate(
    fake_db,
    mock_user_lookup,
):
    creator = make_user(
        role="creator",
        is_active=False,
    )

    mock_user_lookup(
        creator,
    )

    with pytest.raises(
        HTTPException,
    ) as exception_info:
        security.get_creator_user(
            current_user=creator,
            db=fake_db,
        )

    assert (
        exception_info.value.status_code
        in {
            401,
            403,
        }
    )


def test_inactive_verified_teacher_cannot_access_teacher_gate(
    fake_db,
    mock_user_lookup,
):
    teacher = make_user(
        role="teacher",
        teacher_verification_status=(
            "verified"
        ),
        is_active=False,
    )

    mock_user_lookup(
        teacher,
    )

    with pytest.raises(
        HTTPException,
    ) as exception_info:
        security.get_verified_teacher_user(
            current_user=teacher,
            db=fake_db,
        )

    assert (
        exception_info.value.status_code
        in {
            401,
            403,
        }
    )