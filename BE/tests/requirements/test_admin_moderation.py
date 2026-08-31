from types import SimpleNamespace

import pytest

from fastapi import HTTPException

import main as main_module


class FakeDB:
    def __init__(self):
        self.committed = False
        self.refreshed = []

    def commit(self):
        self.committed = True

    def refresh(self, obj):
        self.refreshed.append(obj)


def make_admin(
    *,
    user_id=1,
    role="admin",
):
    return SimpleNamespace(
        id=user_id,
        role=role,
    )


def make_teacher(
    *,
    user_id=10,
    status="pending",
):
    return SimpleNamespace(
        id=user_id,
        role="teacher",
        teacher_verification_status=status,
    )


def make_student(
    *,
    user_id=20,
):
    return SimpleNamespace(
        id=user_id,
        role="student",
    )


def make_user_subject(
    *,
    grade=27,
    grade_status="pending",
):
    return SimpleNamespace(
        id=1,
        user_id=20,
        subject_id=30,
        grade=grade,
        grade_status=grade_status,
        grade_verified_by=None,
        grade_verified_at=None,
    )


def test_admin_verifies_teacher(
    monkeypatch,
):
    db = FakeDB()
    admin = make_admin(
        user_id=100,
    )
    teacher = make_teacher()

    monkeypatch.setattr(
        main_module,
        "get_user_by_id",
        lambda db, user_id: teacher,
    )

    captured = {}

    def fake_verify_teacher(
        db,
        user,
        reviewer_id,
    ):
        captured["user"] = user
        captured["reviewer_id"] = reviewer_id
        user.teacher_verification_status = "verified"
        return user

    monkeypatch.setattr(
        main_module,
        "verify_teacher",
        fake_verify_teacher,
    )

    request = SimpleNamespace(
        status="verified",
    )

    result = main_module.api_admin_teacher_verification(
        user_id=teacher.id,
        request=request,
        current_user=admin,
        db=db,
    )

    assert result is teacher
    assert teacher.teacher_verification_status == "verified"
    assert captured["reviewer_id"] == admin.id
    assert captured["user"] is teacher


def test_admin_rejects_teacher(
    monkeypatch,
):
    db = FakeDB()
    admin = make_admin(
        user_id=100,
    )
    teacher = make_teacher()

    monkeypatch.setattr(
        main_module,
        "get_user_by_id",
        lambda db, user_id: teacher,
    )

    captured = {}

    def fake_reject_teacher(
        db,
        user,
        reviewer_id,
    ):
        captured["user"] = user
        captured["reviewer_id"] = reviewer_id
        user.teacher_verification_status = "rejected"
        return user

    monkeypatch.setattr(
        main_module,
        "reject_teacher",
        fake_reject_teacher,
    )

    request = SimpleNamespace(
        status="rejected",
    )

    result = main_module.api_admin_teacher_verification(
        user_id=teacher.id,
        request=request,
        current_user=admin,
        db=db,
    )

    assert result is teacher
    assert teacher.teacher_verification_status == "rejected"
    assert captured["reviewer_id"] == admin.id
    assert captured["user"] is teacher


def test_teacher_verification_user_not_found(
    monkeypatch,
):
    db = FakeDB()
    admin = make_admin()

    monkeypatch.setattr(
        main_module,
        "get_user_by_id",
        lambda db, user_id: None,
    )

    request = SimpleNamespace(
        status="verified",
    )

    with pytest.raises(
        HTTPException,
    ) as exc:
        main_module.api_admin_teacher_verification(
            user_id=999,
            request=request,
            current_user=admin,
            db=db,
        )

    assert exc.value.status_code == 404


def test_non_teacher_cannot_be_teacher_verified(
    monkeypatch,
):
    db = FakeDB()
    admin = make_admin()
    student = make_student()

    monkeypatch.setattr(
        main_module,
        "get_user_by_id",
        lambda db, user_id: student,
    )

    request = SimpleNamespace(
        status="verified",
    )

    with pytest.raises(
        HTTPException,
    ) as exc:
        main_module.api_admin_teacher_verification(
            user_id=student.id,
            request=request,
            current_user=admin,
            db=db,
        )

    assert exc.value.status_code == 400


def test_teacher_verification_service_error_becomes_400(
    monkeypatch,
):
    db = FakeDB()
    admin = make_admin()
    teacher = make_teacher()

    monkeypatch.setattr(
        main_module,
        "get_user_by_id",
        lambda db, user_id: teacher,
    )

    def fail(
        db,
        user,
        reviewer_id,
    ):
        raise ValueError(
            "Stato docente non valido.",
        )

    monkeypatch.setattr(
        main_module,
        "verify_teacher",
        fail,
    )

    request = SimpleNamespace(
        status="verified",
    )

    with pytest.raises(
        HTTPException,
    ) as exc:
        main_module.api_admin_teacher_verification(
            user_id=teacher.id,
            request=request,
            current_user=admin,
            db=db,
        )

    assert exc.value.status_code == 400


def test_admin_verifies_pending_grade(
    monkeypatch,
):
    db = FakeDB()
    admin = make_admin(
        user_id=100,
    )
    user_subject = make_user_subject(
        grade=28,
    )

    monkeypatch.setattr(
        main_module,
        "get_user_subject",
        lambda db, user_id, subject_id: user_subject,
    )

    result = main_module.api_admin_verify_grade(
        user_id=20,
        subject_id=30,
        current_user=admin,
        db=db,
    )

    assert result["success"] is True
    assert result["grade"] == 28
    assert result["grade_status"] == "verified"
    assert result["grade_verified_by"] == admin.id
    assert result["grade_verified_at"] is not None

    assert user_subject.grade_status == "verified"
    assert user_subject.grade_verified_by == admin.id
    assert user_subject.grade_verified_at is not None

    assert db.committed is True
    assert user_subject in db.refreshed


def test_admin_rejects_pending_grade(
    monkeypatch,
):
    db = FakeDB()
    admin = make_admin(
        user_id=101,
    )
    user_subject = make_user_subject(
        grade=21,
    )

    monkeypatch.setattr(
        main_module,
        "get_user_subject",
        lambda db, user_id, subject_id: user_subject,
    )

    result = main_module.api_admin_reject_grade(
        user_id=20,
        subject_id=30,
        current_user=admin,
        db=db,
    )

    assert result["success"] is True
    assert result["grade"] == 21
    assert result["grade_status"] == "rejected"
    assert result["grade_verified_by"] == admin.id
    assert result["grade_verified_at"] is not None

    assert user_subject.grade_status == "rejected"
    assert user_subject.grade_verified_by == admin.id
    assert user_subject.grade_verified_at is not None

    assert db.committed is True
    assert user_subject in db.refreshed


@pytest.mark.parametrize(
    "endpoint",
    [
        "verify",
        "reject",
    ],
)
def test_grade_moderation_returns_404_when_subject_assignment_missing(
    endpoint,
    monkeypatch,
):
    db = FakeDB()
    admin = make_admin()

    monkeypatch.setattr(
        main_module,
        "get_user_subject",
        lambda db, user_id, subject_id: None,
    )

    function = (
        main_module.api_admin_verify_grade
        if endpoint == "verify"
        else main_module.api_admin_reject_grade
    )

    with pytest.raises(
        HTTPException,
    ) as exc:
        function(
            user_id=20,
            subject_id=30,
            current_user=admin,
            db=db,
        )

    assert exc.value.status_code == 404
    assert db.committed is False


@pytest.mark.parametrize(
    "endpoint",
    [
        "verify",
        "reject",
    ],
)
def test_grade_moderation_requires_grade(
    endpoint,
    monkeypatch,
):
    db = FakeDB()
    admin = make_admin()

    user_subject = make_user_subject(
        grade=None,
    )

    monkeypatch.setattr(
        main_module,
        "get_user_subject",
        lambda db, user_id, subject_id: user_subject,
    )

    function = (
        main_module.api_admin_verify_grade
        if endpoint == "verify"
        else main_module.api_admin_reject_grade
    )

    with pytest.raises(
        HTTPException,
    ) as exc:
        function(
            user_id=20,
            subject_id=30,
            current_user=admin,
            db=db,
        )

    assert exc.value.status_code == 400
    assert db.committed is False


def test_admin_cannot_deactivate_own_account(
    monkeypatch,
):
    db = FakeDB()
    admin = make_admin(
        user_id=100,
    )

    monkeypatch.setattr(
        main_module,
        "get_user_by_id",
        lambda db, user_id: admin,
    )

    request = SimpleNamespace(
        is_active=False,
    )

    with pytest.raises(
        HTTPException,
    ) as exc:
        main_module.api_admin_user_active_status(
            user_id=admin.id,
            request=request,
            current_user=admin,
            db=db,
        )

    assert exc.value.status_code == 400


@pytest.mark.parametrize(
    "target_role",
    [
        "admin",
        "creator",
    ],
)
def test_admin_cannot_change_privileged_account_status(
    target_role,
    monkeypatch,
):
    db = FakeDB()

    current_admin = make_admin(
        user_id=100,
        role="admin",
    )

    target = make_admin(
        user_id=200,
        role=target_role,
    )

    monkeypatch.setattr(
        main_module,
        "get_user_by_id",
        lambda db, user_id: target,
    )

    request = SimpleNamespace(
        is_active=False,
    )

    with pytest.raises(
        HTTPException,
    ) as exc:
        main_module.api_admin_user_active_status(
            user_id=target.id,
            request=request,
            current_user=current_admin,
            db=db,
        )

    assert exc.value.status_code == 403


def test_creator_can_change_admin_account_status(
    monkeypatch,
):
    db = FakeDB()

    creator = make_admin(
        user_id=1,
        role="creator",
    )

    target_admin = make_admin(
        user_id=2,
        role="admin",
    )

    target_admin.is_active = True

    monkeypatch.setattr(
        main_module,
        "get_user_by_id",
        lambda db, user_id: target_admin,
    )

    captured = {}

    def fake_set_user_active_status(
        db,
        user,
        is_active,
    ):
        captured["user"] = user
        captured["is_active"] = is_active
        user.is_active = is_active
        return user

    monkeypatch.setattr(
        main_module,
        "set_user_active_status",
        fake_set_user_active_status,
    )

    request = SimpleNamespace(
        is_active=False,
    )

    result = main_module.api_admin_user_active_status(
        user_id=target_admin.id,
        request=request,
        current_user=creator,
        db=db,
    )

    assert result is target_admin
    assert target_admin.is_active is False
    assert captured["user"] is target_admin
    assert captured["is_active"] is False


def test_admin_can_change_student_account_status(
    monkeypatch,
):
    db = FakeDB()

    admin = make_admin(
        user_id=100,
        role="admin",
    )

    student = make_student(
        user_id=200,
    )

    student.is_active = True

    monkeypatch.setattr(
        main_module,
        "get_user_by_id",
        lambda db, user_id: student,
    )

    def fake_set_user_active_status(
        db,
        user,
        is_active,
    ):
        user.is_active = is_active
        return user

    monkeypatch.setattr(
        main_module,
        "set_user_active_status",
        fake_set_user_active_status,
    )

    request = SimpleNamespace(
        is_active=False,
    )

    result = main_module.api_admin_user_active_status(
        user_id=student.id,
        request=request,
        current_user=admin,
        db=db,
    )

    assert result is student
    assert student.is_active is False


def test_account_status_user_not_found(
    monkeypatch,
):
    db = FakeDB()

    admin = make_admin()

    monkeypatch.setattr(
        main_module,
        "get_user_by_id",
        lambda db, user_id: None,
    )

    request = SimpleNamespace(
        is_active=False,
    )

    with pytest.raises(
        HTTPException,
    ) as exc:
        main_module.api_admin_user_active_status(
            user_id=999,
            request=request,
            current_user=admin,
            db=db,
        )

    assert exc.value.status_code == 404