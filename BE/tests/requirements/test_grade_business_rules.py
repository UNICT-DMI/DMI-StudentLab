
from types import SimpleNamespace

import services.user as user_service


class FakeDB:
    def __init__(self):
        self.added = []
        self.commits = 0
        self.refreshed = []

    def add(self, value):
        self.added.append(value)

    def commit(self):
        self.commits += 1

    def refresh(self, value):
        self.refreshed.append(value)


class FakeUserSubject:
    def __init__(self, **kwargs):
        for key, value in kwargs.items():
            setattr(self, key, value)


class FakeCreate:
    def __init__(
        self,
        *,
        subject_id=10,
        grade=None,
        note=None,
        can_help=False,
        can_give_private_lessons=False,
    ):
        self.subject_id = subject_id
        self.grade = grade
        self.note = note
        self.can_help = can_help
        self.can_give_private_lessons = can_give_private_lessons


class FakeUpdate:
    def __init__(self, values):
        self.values = values

    def model_dump(self, exclude_unset=True):
        return dict(self.values)


def test_subject_without_grade_requires_no_grade_verification(monkeypatch):
    db = FakeDB()
    monkeypatch.setattr(user_service, "get_user_subject", lambda *args, **kwargs: None)
    monkeypatch.setattr(user_service, "UserSubject", FakeUserSubject)

    result = user_service.add_subject_to_user(
        db,
        user_id=1,
        data=FakeCreate(grade=None),
    )

    assert result.grade is None
    assert result.grade_status == "none"


def test_declared_grade_starts_pending(monkeypatch):
    db = FakeDB()
    monkeypatch.setattr(user_service, "get_user_subject", lambda *args, **kwargs: None)
    monkeypatch.setattr(user_service, "UserSubject", FakeUserSubject)

    result = user_service.add_subject_to_user(
        db,
        user_id=1,
        data=FakeCreate(grade=27),
    )

    assert result.grade == 27
    assert result.grade_status == "pending"


def test_changing_verified_grade_returns_to_pending():
    db = FakeDB()
    relation = SimpleNamespace(
        grade=27,
        grade_status="verified",
        grade_verified_by=99,
        grade_verified_at=object(),
        note=None,
        can_help=False,
        can_give_private_lessons=False,
    )

    result = user_service.update_user_subject(
        db,
        relation,
        FakeUpdate({"grade": 28}),
    )

    assert result.grade == 28
    assert result.grade_status == "pending"
    assert result.grade_verified_by is None
    assert result.grade_verified_at is None


def test_removing_grade_resets_verification():
    db = FakeDB()
    relation = SimpleNamespace(
        grade=27,
        grade_status="verified",
        grade_verified_by=99,
        grade_verified_at=object(),
        note=None,
        can_help=False,
        can_give_private_lessons=False,
    )

    result = user_service.update_user_subject(
        db,
        relation,
        FakeUpdate({"grade": None}),
    )

    assert result.grade is None
    assert result.grade_status == "none"
    assert result.grade_verified_by is None
    assert result.grade_verified_at is None


def test_unchanged_verified_grade_stays_verified():
    db = FakeDB()
    marker = object()
    relation = SimpleNamespace(
        grade=27,
        grade_status="verified",
        grade_verified_by=99,
        grade_verified_at=marker,
        note=None,
        can_help=False,
        can_give_private_lessons=False,
    )

    result = user_service.update_user_subject(
        db,
        relation,
        FakeUpdate({"grade": 27}),
    )

    assert result.grade_status == "verified"
    assert result.grade_verified_by == 99
    assert result.grade_verified_at is marker
