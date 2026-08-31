from datetime import (
    datetime,
    timezone,
)

from sqlalchemy.orm import (
    Session,
)

from models.group import (
    GroupMember,
    StudyGroup,
)

from models.material import (
    GroupMaterial,
)

from models.public_material import (
    PublicMaterial,
)

from models.teacher_material import (
    TeacherMaterial,
)

from schemas.material_sync import (
    MaterialSyncItem,
    MaterialSyncManifestResponse,
)

from services.teacher_material_assignment import (
    get_accessible_teacher_material_ids,
)


def utc_now():
    return datetime.now(
        timezone.utc,
    )


def _to_utc(
    value: datetime | None,
):
    if value is None:
        return None

    if value.tzinfo is None:
        return value.replace(
            tzinfo=timezone.utc,
        )

    return value.astimezone(
        timezone.utc,
    )


def _normalize_status(
    status: str | None,
    *,
    is_active: bool,
):
    normalized = (
        status
        or (
            "active"
            if is_active
            else "removed"
        )
    )

    normalized = (
        normalized
        .strip()
        .lower()
    )

    if normalized not in {
        "active",
        "hidden",
        "removed",
    }:
        return (
            "active"
            if is_active
            else "removed"
        )

    return normalized


def _changed_since(
    *,
    updated_at: datetime | None,
    removed_at: datetime | None,
    created_at: datetime | None,
    since: datetime | None,
):
    if since is None:
        return True

    normalized_since = _to_utc(
        since,
    )

    candidates = [
        _to_utc(
            value,
        )
        for value in (
            updated_at,
            removed_at,
            created_at,
        )
        if value is not None
    ]

    if not candidates:
        return False

    return any(
        value >
        normalized_since
        for value in candidates
    )


def _public_material_to_sync_item(
    material: PublicMaterial,
):
    is_visible = bool(
        getattr(
            material,
            "is_visible",
            True,
        )
    )

    raw_active = bool(
        getattr(
            material,
            "is_active",
            is_visible,
        )
    )

    status = _normalize_status(
        getattr(
            material,
            "status",
            None,
        ),
        is_active=(
            raw_active
            and is_visible
        ),
    )

    is_active = (
        status ==
        "active"
        and raw_active
        and is_visible
    )

    return MaterialSyncItem(
        key=(
            f"public:{material.id}"
        ),
        source="public",
        material_id=material.id,
        subject_id=(
            getattr(
                material,
                "subject_id",
                None,
            )
        ),
        group_id=None,
        version=(
            getattr(
                material,
                "version",
                1,
            )
            or 1
        ),
        status=status,
        is_active=is_active,
        is_visible=is_visible,
        is_tombstone=(
            not is_active
        ),
        original_name=(
            None
            if not is_active
            else getattr(
                material,
                "original_name",
                None,
            )
        ),
        mime_type=(
            None
            if not is_active
            else getattr(
                material,
                "mime_type",
                None,
            )
        ),
        size=(
            None
            if not is_active
            else getattr(
                material,
                "size",
                None,
            )
        ),
        file_hash=(
            None
            if not is_active
            else getattr(
                material,
                "file_hash",
                None,
            )
        ),
        updated_at=(
            _to_utc(
                getattr(
                    material,
                    "updated_at",
                    None,
                )
            )
        ),
        removed_at=(
            _to_utc(
                getattr(
                    material,
                    "removed_at",
                    None,
                )
            )
        ),
    )


def _teacher_material_to_sync_item(
    material: TeacherMaterial,
    *,
    visible: bool,
):
    raw_active = bool(
        material.is_active
    )

    status = _normalize_status(
        material.status,
        is_active=raw_active,
    )

    is_active = (
        status ==
        "active"
        and raw_active
        and visible
    )

    return MaterialSyncItem(
        key=(
            f"teacher:{material.id}"
        ),
        source="teacher",
        material_id=material.id,
        subject_id=material.subject_id,
        group_id=None,
        version=(
            material.version
            or 1
        ),
        status=status,
        is_active=is_active,
        is_visible=visible,
        is_tombstone=(
            not is_active
        ),
        original_name=(
            None
            if not is_active
            else material.original_name
        ),
        mime_type=(
            None
            if not is_active
            else material.mime_type
        ),
        size=(
            None
            if not is_active
            else material.size
        ),
        file_hash=(
            None
            if not is_active
            else material.file_hash
        ),
        updated_at=(
            _to_utc(
                getattr(
                    material,
                    "updated_at",
                    None,
                )
            )
        ),
        removed_at=(
            _to_utc(
                getattr(
                    material,
                    "removed_at",
                    None,
                )
            )
        ),
    )


def _group_material_to_sync_item(
    material: GroupMaterial,
    *,
    visible: bool,
    subject_id: int | None,
):
    raw_active = bool(
        material.is_active
    )

    status = _normalize_status(
        material.status,
        is_active=raw_active,
    )

    is_active = (
        status ==
        "active"
        and raw_active
        and visible
    )

    return MaterialSyncItem(
        key=(
            f"group:{material.id}"
        ),
        source="group",
        material_id=material.id,
        subject_id=subject_id,
        group_id=material.group_id,
        version=(
            material.version
            or 1
        ),
        status=status,
        is_active=is_active,
        is_visible=visible,
        is_tombstone=(
            not is_active
        ),
        original_name=(
            None
            if not is_active
            else material.original_name
        ),
        mime_type=(
            None
            if not is_active
            else material.mime_type
        ),
        size=(
            None
            if not is_active
            else material.size
        ),
        file_hash=(
            None
            if not is_active
            else material.file_hash
        ),
        updated_at=(
            _to_utc(
                getattr(
                    material,
                    "updated_at",
                    None,
                )
            )
        ),
        removed_at=(
            _to_utc(
                getattr(
                    material,
                    "removed_at",
                    None,
                )
            )
        ),
    )


def _get_user_group_ids(
    db: Session,
    user_id: int,
):
    return {
        group_id
        for (
            group_id,
        ) in (
            db.query(
                GroupMember.group_id,
            )
            .join(
                StudyGroup,
                StudyGroup.id ==
                GroupMember.group_id,
            )
            .filter(
                GroupMember.user_id ==
                user_id,
                StudyGroup.status ==
                "active",
            )
            .all()
        )
    }


def _get_public_group_ids(
    db: Session,
):
    return {
        group_id
        for (
            group_id,
        ) in (
            db.query(
                StudyGroup.id,
            )
            .filter(
                StudyGroup.is_private.is_(
                    False,
                ),
                StudyGroup.status ==
                "active",
            )
            .all()
        )
    }


def _get_visible_group_subjects(
    db: Session,
    group_ids: set[int],
):
    if not group_ids:
        return {}

    rows = (
        db.query(
            StudyGroup.id,
            StudyGroup.subject_id,
        )
        .filter(
            StudyGroup.id.in_(
                group_ids,
            ),
            StudyGroup.status ==
            "active",
        )
        .all()
    )

    return {
        group_id: subject_id
        for (
            group_id,
            subject_id,
        ) in rows
    }


def _get_visible_teacher_material_ids(
    db: Session,
    user_id: int,
):
    assigned_ids = (
        get_accessible_teacher_material_ids(
            db,
            user_id,
        )
    )

    student_visible_ids = {
        material_id
        for (
            material_id,
        ) in (
            db.query(
                TeacherMaterial.id,
            )
            .filter(
                TeacherMaterial.visibility ==
                "students",
                TeacherMaterial.status ==
                "active",
                TeacherMaterial.is_active.is_(
                    True,
                ),
            )
            .all()
        )
    }

    owned_ids = {
        material_id
        for (
            material_id,
        ) in (
            db.query(
                TeacherMaterial.id,
            )
            .filter(
                TeacherMaterial.uploaded_by ==
                user_id,
                TeacherMaterial.status ==
                "active",
                TeacherMaterial.is_active.is_(
                    True,
                ),
            )
            .all()
        )
    }

    return (
        assigned_ids
        | student_visible_ids
        | owned_ids
    )


def build_material_sync_manifest(
    db: Session,
    *,
    user_id: int,
    since: datetime | None = None,
):
    generated_at = utc_now()

    normalized_since = _to_utc(
        since,
    )

    visible_keys: set[str] = set()

    items: list[
        MaterialSyncItem
    ] = []

    public_materials = (
        db.query(
            PublicMaterial,
        )
        .order_by(
            PublicMaterial.id.asc(),
        )
        .all()
    )

    for material in public_materials:
        item = (
            _public_material_to_sync_item(
                material,
            )
        )

        if item.is_active:
            visible_keys.add(
                item.key,
            )

        if _changed_since(
            updated_at=(
                item.updated_at
            ),
            removed_at=(
                item.removed_at
            ),
            created_at=(
                _to_utc(
                    getattr(
                        material,
                        "created_at",
                        None,
                    )
                )
            ),
            since=normalized_since,
        ):
            items.append(
                item,
            )

    visible_teacher_ids = (
        _get_visible_teacher_material_ids(
            db,
            user_id,
        )
    )

    teacher_materials = (
        db.query(
            TeacherMaterial,
        )
        .order_by(
            TeacherMaterial.id.asc(),
        )
        .all()
    )

    for material in teacher_materials:
        visible = (
            material.id
            in visible_teacher_ids
        )

        if not visible:
            continue

        item = (
            _teacher_material_to_sync_item(
                material,
                visible=True,
            )
        )

        if item.is_active:
            visible_keys.add(
                item.key,
            )

        if _changed_since(
            updated_at=(
                item.updated_at
            ),
            removed_at=(
                item.removed_at
            ),
            created_at=(
                _to_utc(
                    getattr(
                        material,
                        "created_at",
                        None,
                    )
                )
            ),
            since=normalized_since,
        ):
            items.append(
                item,
            )

    user_group_ids = (
        _get_user_group_ids(
            db,
            user_id,
        )
    )

    public_group_ids = (
        _get_public_group_ids(
            db,
        )
    )

    visible_group_ids = (
        user_group_ids
        | public_group_ids
    )

    group_subjects = (
        _get_visible_group_subjects(
            db,
            visible_group_ids,
        )
    )

    if visible_group_ids:
        group_materials = (
            db.query(
                GroupMaterial,
            )
            .filter(
                GroupMaterial.group_id.in_(
                    visible_group_ids,
                )
            )
            .order_by(
                GroupMaterial.id.asc(),
            )
            .all()
        )
    else:
        group_materials = []

    for material in group_materials:
        item = (
            _group_material_to_sync_item(
                material,
                visible=True,
                subject_id=(
                    group_subjects.get(
                        material.group_id,
                    )
                ),
            )
        )

        if item.is_active:
            visible_keys.add(
                item.key,
            )

        if _changed_since(
            updated_at=(
                item.updated_at
            ),
            removed_at=(
                item.removed_at
            ),
            created_at=(
                _to_utc(
                    getattr(
                        material,
                        "created_at",
                        None,
                    )
                )
            ),
            since=normalized_since,
        ):
            items.append(
                item,
            )

    items.sort(
        key=lambda item: (
            item.source,
            item.material_id,
        )
    )

    return MaterialSyncManifestResponse(
        generated_at=generated_at,
        since=normalized_since,
        incremental=(
            normalized_since
            is not None
        ),
        visible_keys=sorted(
            visible_keys,
        ),
        items=items,
    )