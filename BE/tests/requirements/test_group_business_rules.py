from types import SimpleNamespace

import pytest

from fastapi import HTTPException

import main as main_module


class FakeDB:
    def __init__(self):
        self.rolled_back = False

    def rollback(self):
        self.rolled_back = True


def make_user(
    *,
    user_id=1,
    active=True,
):
    return SimpleNamespace(
        id=user_id,
        is_active=active,
    )


def make_member(
    *,
    user_id=1,
    group_id=10,
    role="member",
):
    return SimpleNamespace(
        user_id=user_id,
        group_id=group_id,
        role=role,
    )


def make_group(
    *,
    group_id=10,
    is_private=False,
):
    return SimpleNamespace(
        id=group_id,
        is_private=is_private,
    )


def make_join_request(
    *,
    request_id=1,
    group_id=10,
    user_id=20,
    status="pending",
):
    return SimpleNamespace(
        id=request_id,
        group_id=group_id,
        user_id=user_id,
        status=status,
    )


def test_require_group_member_rejects_non_member(
    monkeypatch,
):
    db = FakeDB()

    monkeypatch.setattr(
        main_module,
        "get_group_member",
        lambda db, group_id, user_id: None,
    )

    with pytest.raises(
        HTTPException,
    ) as exc:
        main_module.require_group_member(
            db,
            10,
            20,
        )

    assert exc.value.status_code == 403


def test_require_group_member_returns_member(
    monkeypatch,
):
    db = FakeDB()

    member = make_member()

    monkeypatch.setattr(
        main_module,
        "get_group_member",
        lambda db, group_id, user_id: member,
    )

    result = main_module.require_group_member(
        db,
        10,
        1,
    )

    assert result is member


def test_normal_member_is_not_group_manager(
    monkeypatch,
):
    db = FakeDB()

    member = make_member(
        role="member",
    )

    monkeypatch.setattr(
        main_module,
        "get_group_member",
        lambda db, group_id, user_id: member,
    )

    with pytest.raises(
        HTTPException,
    ) as exc:
        main_module.require_group_manager(
            db,
            10,
            1,
        )

    assert exc.value.status_code == 403


@pytest.mark.parametrize(
    "role",
    [
        "owner",
        "admin",
    ],
)
def test_owner_and_admin_are_group_managers(
    role,
    monkeypatch,
):
    db = FakeDB()

    member = make_member(
        role=role,
    )

    monkeypatch.setattr(
        main_module,
        "get_group_member",
        lambda db, group_id, user_id: member,
    )

    result = main_module.require_group_manager(
        db,
        10,
        1,
    )

    assert result is member


def test_only_owner_can_delete_group(
    monkeypatch,
):
    db = FakeDB()

    current_user = make_user()

    group = make_group()

    member = make_member(
        role="admin",
    )

    monkeypatch.setattr(
        main_module,
        "get_group_by_id",
        lambda db, group_id: group,
    )

    monkeypatch.setattr(
        main_module,
        "get_group_member",
        lambda db, group_id, user_id: member,
    )

    with pytest.raises(
        HTTPException,
    ) as exc:
        main_module.api_delete_group(
            group_id=group.id,
            current_user=current_user,
            db=db,
        )

    assert exc.value.status_code == 403


def test_owner_can_delete_group(
    monkeypatch,
):
    db = FakeDB()

    current_user = make_user()

    group = make_group()

    owner = make_member(
        role="owner",
    )

    monkeypatch.setattr(
        main_module,
        "get_group_by_id",
        lambda db, group_id: group,
    )

    monkeypatch.setattr(
        main_module,
        "get_group_member",
        lambda db, group_id, user_id: owner,
    )

    deleted = {}

    def fake_delete_group(
        db,
        target_group,
    ):
        deleted["group"] = target_group

    monkeypatch.setattr(
        main_module,
        "delete_group",
        fake_delete_group,
    )

    result = main_module.api_delete_group(
        group_id=group.id,
        current_user=current_user,
        db=db,
    )

    assert result["success"] is True
    assert deleted["group"] is group


def test_owner_cannot_be_removed_from_group(
    monkeypatch,
):
    db = FakeDB()

    current_user = make_user()

    group = make_group()

    owner = make_member(
        user_id=2,
        role="owner",
    )

    monkeypatch.setattr(
        main_module,
        "get_group_by_id",
        lambda db, group_id: group,
    )

    monkeypatch.setattr(
        main_module,
        "require_group_manager",
        lambda db, group_id, user_id: make_member(
            role="admin",
        ),
    )

    monkeypatch.setattr(
        main_module,
        "get_group_member",
        lambda db, group_id, user_id: owner,
    )

    with pytest.raises(
        HTTPException,
    ) as exc:
        main_module.api_remove_group_member(
            group_id=group.id,
            user_id=owner.user_id,
            current_user=current_user,
            db=db,
        )

    assert exc.value.status_code == 400


def test_group_owner_role_cannot_be_changed(
    monkeypatch,
):
    db = FakeDB()

    current_user = make_user()

    owner = make_member(
        user_id=2,
        role="owner",
    )

    monkeypatch.setattr(
        main_module,
        "require_group_manager",
        lambda db, group_id, user_id: make_member(
            role="admin",
        ),
    )

    monkeypatch.setattr(
        main_module,
        "get_group_member",
        lambda db, group_id, user_id: owner,
    )

    request = SimpleNamespace(
        role="member",
    )

    with pytest.raises(
        HTTPException,
    ) as exc:
        main_module.api_update_group_member_role(
            group_id=10,
            user_id=owner.user_id,
            request=request,
            current_user=current_user,
            db=db,
        )

    assert exc.value.status_code == 400


@pytest.mark.parametrize(
    "role",
    [
        "owner",
        "creator",
        "teacher",
        "student",
        "moderator",
        "",
    ],
)
def test_invalid_group_member_role_is_rejected(
    role,
    monkeypatch,
):
    db = FakeDB()

    current_user = make_user()

    member = make_member(
        user_id=2,
        role="member",
    )

    monkeypatch.setattr(
        main_module,
        "require_group_manager",
        lambda db, group_id, user_id: make_member(
            role="owner",
        ),
    )

    monkeypatch.setattr(
        main_module,
        "get_group_member",
        lambda db, group_id, user_id: member,
    )

    request = SimpleNamespace(
        role=role,
    )

    with pytest.raises(
        HTTPException,
    ) as exc:
        main_module.api_update_group_member_role(
            group_id=10,
            user_id=member.user_id,
            request=request,
            current_user=current_user,
            db=db,
        )

    assert exc.value.status_code == 400


@pytest.mark.parametrize(
    "role",
    [
        "admin",
        "member",
    ],
)
def test_valid_group_member_role_is_accepted(
    role,
    monkeypatch,
):
    db = FakeDB()

    current_user = make_user()

    member = make_member(
        user_id=2,
        role="member",
    )

    monkeypatch.setattr(
        main_module,
        "require_group_manager",
        lambda db, group_id, user_id: make_member(
            role="owner",
        ),
    )

    monkeypatch.setattr(
        main_module,
        "get_group_member",
        lambda db, group_id, user_id: member,
    )

    captured = {}

    def fake_update_role(
        db,
        target_member,
        new_role,
    ):
        captured["member"] = target_member
        captured["role"] = new_role
        target_member.role = new_role
        return target_member

    monkeypatch.setattr(
        main_module,
        "update_group_member_role",
        fake_update_role,
    )

    request = SimpleNamespace(
        role=role,
    )

    result = main_module.api_update_group_member_role(
        group_id=10,
        user_id=member.user_id,
        request=request,
        current_user=current_user,
        db=db,
    )

    assert result is member
    assert captured["member"] is member
    assert captured["role"] == role
    assert member.role == role


def test_existing_group_member_cannot_request_join(
    monkeypatch,
):
    db = FakeDB()

    current_user = make_user(
        user_id=20,
    )

    group = make_group()

    member = make_member(
        user_id=current_user.id,
    )

    monkeypatch.setattr(
        main_module,
        "get_group_by_id",
        lambda db, group_id: group,
    )

    monkeypatch.setattr(
        main_module,
        "get_group_member",
        lambda db, group_id, user_id: member,
    )

    with pytest.raises(
        HTTPException,
    ) as exc:
        main_module.api_request_join_group(
            group_id=group.id,
            request=SimpleNamespace(),
            current_user=current_user,
            db=db,
        )

    assert exc.value.status_code == 409


def test_duplicate_pending_join_request_is_rejected(
    monkeypatch,
):
    db = FakeDB()

    current_user = make_user(
        user_id=20,
    )

    group = make_group(
        is_private=True,
    )

    pending_request = make_join_request(
        group_id=group.id,
        user_id=current_user.id,
        status="pending",
    )

    monkeypatch.setattr(
        main_module,
        "get_group_by_id",
        lambda db, group_id: group,
    )

    monkeypatch.setattr(
        main_module,
        "get_group_member",
        lambda db, group_id, user_id: None,
    )

    monkeypatch.setattr(
        main_module,
        "get_group_join_request",
        lambda db, group_id, user_id: pending_request,
    )

    with pytest.raises(
        HTTPException,
    ) as exc:
        main_module.api_request_join_group(
            group_id=group.id,
            request=SimpleNamespace(),
            current_user=current_user,
            db=db,
        )

    assert exc.value.status_code == 409


def test_public_group_join_adds_user_immediately(
    monkeypatch,
):
    db = FakeDB()

    current_user = make_user(
        user_id=20,
    )

    group = make_group(
        is_private=False,
    )

    monkeypatch.setattr(
        main_module,
        "get_group_by_id",
        lambda db, group_id: group,
    )

    monkeypatch.setattr(
        main_module,
        "get_group_member",
        lambda db, group_id, user_id: None,
    )

    monkeypatch.setattr(
        main_module,
        "get_group_join_request",
        lambda db, group_id, user_id: None,
    )

    captured = {}

    def fake_add_group_member(
        db,
        group_id,
        user_id,
        role,
    ):
        captured["group_id"] = group_id
        captured["user_id"] = user_id
        captured["role"] = role

    monkeypatch.setattr(
        main_module,
        "add_group_member",
        fake_add_group_member,
    )

    result = main_module.api_request_join_group(
        group_id=group.id,
        request=SimpleNamespace(),
        current_user=current_user,
        db=db,
    )

    assert result.joined is True
    assert result.pending is False

    assert captured == {
        "group_id":
            group.id,
        "user_id":
            current_user.id,
        "role":
            "member",
    }


def test_private_group_join_creates_pending_request(
    monkeypatch,
):
    db = FakeDB()

    current_user = make_user(
        user_id=20,
    )

    group = make_group(
        is_private=True,
    )

    monkeypatch.setattr(
        main_module,
        "get_group_by_id",
        lambda db, group_id: group,
    )

    monkeypatch.setattr(
        main_module,
        "get_group_member",
        lambda db, group_id, user_id: None,
    )

    monkeypatch.setattr(
        main_module,
        "get_group_join_request",
        lambda db, group_id, user_id: None,
    )

    captured = {}

    def fake_create_join_request(
        db,
        group_id,
        user_id,
    ):
        captured["group_id"] = group_id
        captured["user_id"] = user_id

    monkeypatch.setattr(
        main_module,
        "create_group_join_request",
        fake_create_join_request,
    )

    result = main_module.api_request_join_group(
        group_id=group.id,
        request=SimpleNamespace(),
        current_user=current_user,
        db=db,
    )

    assert result.joined is False
    assert result.pending is True

    assert captured == {
        "group_id":
            group.id,
        "user_id":
            current_user.id,
    }


@pytest.mark.parametrize(
    "status",
    [
        "accepted",
        "rejected",
    ],
)
def test_processed_join_request_cannot_be_accepted_again(
    status,
    monkeypatch,
):
    db = FakeDB()

    current_user = make_user()

    join_request = make_join_request(
        status=status,
    )

    monkeypatch.setattr(
        main_module,
        "get_group_join_request_by_id",
        lambda db, request_id: join_request,
    )

    monkeypatch.setattr(
        main_module,
        "require_group_manager",
        lambda db, group_id, user_id: make_member(
            role="owner",
        ),
    )

    with pytest.raises(
        HTTPException,
    ) as exc:
        main_module.api_accept_group_request(
            request_id=join_request.id,
            current_user=current_user,
            db=db,
        )

    assert exc.value.status_code == 400


def test_join_request_cannot_be_accepted_if_user_is_already_member(
    monkeypatch,
):
    db = FakeDB()

    current_user = make_user()

    join_request = make_join_request(
        status="pending",
    )

    existing_member = make_member(
        user_id=join_request.user_id,
        group_id=join_request.group_id,
    )

    monkeypatch.setattr(
        main_module,
        "get_group_join_request_by_id",
        lambda db, request_id: join_request,
    )

    monkeypatch.setattr(
        main_module,
        "require_group_manager",
        lambda db, group_id, user_id: make_member(
            role="owner",
        ),
    )

    monkeypatch.setattr(
        main_module,
        "get_group_member",
        lambda db, group_id, user_id: existing_member,
    )

    with pytest.raises(
        HTTPException,
    ) as exc:
        main_module.api_accept_group_request(
            request_id=join_request.id,
            current_user=current_user,
            db=db,
        )

    assert exc.value.status_code == 409


@pytest.mark.parametrize(
    "status",
    [
        "accepted",
        "rejected",
    ],
)
def test_processed_join_request_cannot_be_rejected_again(
    status,
    monkeypatch,
):
    db = FakeDB()

    current_user = make_user()

    join_request = make_join_request(
        status=status,
    )

    monkeypatch.setattr(
        main_module,
        "get_group_join_request_by_id",
        lambda db, request_id: join_request,
    )

    monkeypatch.setattr(
        main_module,
        "require_group_manager",
        lambda db, group_id, user_id: make_member(
            role="owner",
        ),
    )

    with pytest.raises(
        HTTPException,
    ) as exc:
        main_module.api_reject_group_request(
            request_id=join_request.id,
            current_user=current_user,
            db=db,
        )

    assert exc.value.status_code == 400