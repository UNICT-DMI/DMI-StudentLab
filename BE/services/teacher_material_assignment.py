from datetime import (
    datetime,
    timezone,
)

from sqlalchemy.orm import (
    Session,
)

from models.group import (
    StudyGroup,
)

from models.group import (
    GroupMember,
)

from models.teacher_material import (
    TeacherMaterial,
)

from models.teacher_material_assignment import (
    TeacherMaterialAssignment,
)

from models.user import (
    User,
)

from schemas.teacher_material_assignment import (
    TeacherMaterialAssignmentBulkCreate,
    TeacherMaterialAssignmentCreate,
)


def utc_now():
    return datetime.now(
        timezone.utc,
    )


def get_teacher_material_assignment_by_id(
    db: Session,
    assignment_id: int,
):
    return (
        db.query(
            TeacherMaterialAssignment,
        )
        .filter(
            TeacherMaterialAssignment.id ==
            assignment_id,
        )
        .first()
    )


def get_teacher_material_assignments(
    db: Session,
    material_id: int,
    *,
    include_revoked: bool = False,
):
    query = (
        db.query(
            TeacherMaterialAssignment,
        )
        .filter(
            TeacherMaterialAssignment.material_id ==
            material_id,
        )
    )

    if not include_revoked:
        query = query.filter(
            TeacherMaterialAssignment.status ==
            "active",
        )

    return (
        query
        .order_by(
            TeacherMaterialAssignment.assigned_at.desc(),
            TeacherMaterialAssignment.id.desc(),
        )
        .all()
    )


def get_teacher_material_assignment_for_user(
    db: Session,
    material_id: int,
    user_id: int,
):
    return (
        db.query(
            TeacherMaterialAssignment,
        )
        .filter(
            TeacherMaterialAssignment.material_id ==
            material_id,
            TeacherMaterialAssignment.user_id ==
            user_id,
        )
        .first()
    )


def get_teacher_material_assignment_for_group(
    db: Session,
    material_id: int,
    group_id: int,
):
    return (
        db.query(
            TeacherMaterialAssignment,
        )
        .filter(
            TeacherMaterialAssignment.material_id ==
            material_id,
            TeacherMaterialAssignment.group_id ==
            group_id,
        )
        .first()
    )


def require_assignable_teacher_material(
    db: Session,
    material_id: int,
    teacher_id: int,
):
    material = (
        db.query(
            TeacherMaterial,
        )
        .filter(
            TeacherMaterial.id ==
            material_id,
        )
        .first()
    )

    if material is None:
        raise ValueError(
            "Materiale non trovato.",
        )

    if (
        material.uploaded_by !=
        teacher_id
    ):
        raise PermissionError(
            "Non puoi assegnare questo materiale.",
        )

    if (
        material.status !=
        "active"
        or not material.is_active
    ):
        raise ValueError(
            "Il materiale non è disponibile.",
        )

    return material


def require_assignable_user(
    db: Session,
    user_id: int,
):
    user = (
        db.query(
            User,
        )
        .filter(
            User.id ==
            user_id,
            User.is_active.is_(
                True,
            ),
        )
        .first()
    )

    if user is None:
        raise ValueError(
            "Studente non trovato.",
        )

    return user


def require_assignable_group(
    db: Session,
    group_id: int,
    teacher_id: int,
):
    group = (
        db.query(
            StudyGroup,
        )
        .filter(
            StudyGroup.id ==
            group_id,
            StudyGroup.status ==
            "active",
        )
        .first()
    )

    if group is None:
        raise ValueError(
            "Gruppo non trovato.",
        )

    membership = (
        db.query(
            GroupMember,
        )
        .filter(
            GroupMember.group_id ==
            group_id,
            GroupMember.user_id ==
            teacher_id,
        )
        .first()
    )

    if membership is None:
        raise PermissionError(
            "Non appartieni a questo gruppo.",
        )

    if membership.role not in [
        "owner",
        "admin",
    ]:
        raise PermissionError(
            "Non puoi assegnare materiali a questo gruppo.",
        )

    return group


def validate_assignment_target(
    data: TeacherMaterialAssignmentCreate,
):
    has_user = (
        data.user_id is not None
    )

    has_group = (
        data.group_id is not None
    )

    if has_user == has_group:
        raise ValueError(
            "Indica uno studente oppure un gruppo.",
        )


def create_teacher_material_assignment(
    db: Session,
    *,
    material_id: int,
    teacher_id: int,
    data: TeacherMaterialAssignmentCreate,
):
    validate_assignment_target(
        data,
    )

    require_assignable_teacher_material(
        db,
        material_id,
        teacher_id,
    )

    if data.user_id is not None:
        require_assignable_user(
            db,
            data.user_id,
        )

        existing = (
            get_teacher_material_assignment_for_user(
                db,
                material_id,
                data.user_id,
            )
        )

        if existing is not None:
            if (
                existing.status ==
                "active"
            ):
                raise ValueError(
                    "Materiale già assegnato allo studente.",
                )

            existing.status = (
                "active"
            )
            existing.assigned_by = (
                teacher_id
            )
            existing.revoked_by = None
            existing.revoked_at = None
            existing.assigned_at = (
                utc_now()
            )
            existing.updated_at = (
                utc_now()
            )

            db.commit()

            db.refresh(
                existing,
            )

            return existing

        assignment = (
            TeacherMaterialAssignment(
                material_id=(
                    material_id
                ),
                assigned_by=(
                    teacher_id
                ),
                user_id=(
                    data.user_id
                ),
                group_id=None,
                status="active",
                assigned_at=(
                    utc_now()
                ),
                updated_at=(
                    utc_now()
                ),
            )
        )

    else:
        require_assignable_group(
            db,
            data.group_id,
            teacher_id,
        )

        existing = (
            get_teacher_material_assignment_for_group(
                db,
                material_id,
                data.group_id,
            )
        )

        if existing is not None:
            if (
                existing.status ==
                "active"
            ):
                raise ValueError(
                    "Materiale già assegnato al gruppo.",
                )

            existing.status = (
                "active"
            )
            existing.assigned_by = (
                teacher_id
            )
            existing.revoked_by = None
            existing.revoked_at = None
            existing.assigned_at = (
                utc_now()
            )
            existing.updated_at = (
                utc_now()
            )

            db.commit()

            db.refresh(
                existing,
            )

            return existing

        assignment = (
            TeacherMaterialAssignment(
                material_id=(
                    material_id
                ),
                assigned_by=(
                    teacher_id
                ),
                user_id=None,
                group_id=(
                    data.group_id
                ),
                status="active",
                assigned_at=(
                    utc_now()
                ),
                updated_at=(
                    utc_now()
                ),
            )
        )

    db.add(
        assignment,
    )

    db.commit()

    db.refresh(
        assignment,
    )

    return assignment


def create_teacher_material_assignments_bulk(
    db: Session,
    *,
    material_id: int,
    teacher_id: int,
    data: TeacherMaterialAssignmentBulkCreate,
):
    require_assignable_teacher_material(
        db,
        material_id,
        teacher_id,
    )

    user_ids = list(
        dict.fromkeys(
            data.user_ids,
        )
    )

    group_ids = list(
        dict.fromkeys(
            data.group_ids,
        )
    )

    if (
        not user_ids
        and not group_ids
    ):
        raise ValueError(
            "Seleziona almeno uno studente o un gruppo.",
        )

    created = []

    for user_id in user_ids:
        assignment = (
            create_teacher_material_assignment(
                db,
                material_id=(
                    material_id
                ),
                teacher_id=(
                    teacher_id
                ),
                data=(
                    TeacherMaterialAssignmentCreate(
                        user_id=user_id,
                    )
                ),
            )
        )

        created.append(
            assignment,
        )

    for group_id in group_ids:
        assignment = (
            create_teacher_material_assignment(
                db,
                material_id=(
                    material_id
                ),
                teacher_id=(
                    teacher_id
                ),
                data=(
                    TeacherMaterialAssignmentCreate(
                        group_id=group_id,
                    )
                ),
            )
        )

        created.append(
            assignment,
        )

    return created


def revoke_teacher_material_assignment(
    db: Session,
    *,
    assignment_id: int,
    actor: User,
):
    assignment = (
        get_teacher_material_assignment_by_id(
            db,
            assignment_id,
        )
    )

    if assignment is None:
        raise ValueError(
            "Assegnazione non trovata.",
        )

    material = (
        db.query(
            TeacherMaterial,
        )
        .filter(
            TeacherMaterial.id ==
            assignment.material_id,
        )
        .first()
    )

    if material is None:
        raise ValueError(
            "Materiale non trovato.",
        )

    can_revoke = (
        material.uploaded_by ==
        actor.id
        or actor.role in [
            "admin",
            "creator",
        ]
    )

    if not can_revoke:
        raise PermissionError(
            "Non puoi revocare questa assegnazione.",
        )

    if (
        assignment.status ==
        "revoked"
    ):
        return assignment

    assignment.status = (
        "revoked"
    )

    assignment.revoked_by = (
        actor.id
    )

    assignment.revoked_at = (
        utc_now()
    )

    assignment.updated_at = (
        utc_now()
    )

    db.commit()

    db.refresh(
        assignment,
    )

    return assignment


def get_teacher_material_assignments_for_user(
    db: Session,
    user_id: int,
):
    return (
        db.query(
            TeacherMaterialAssignment,
        )
        .join(
            TeacherMaterial,
            TeacherMaterial.id ==
            TeacherMaterialAssignment.material_id,
        )
        .filter(
            TeacherMaterialAssignment.user_id ==
            user_id,
            TeacherMaterialAssignment.status ==
            "active",
            TeacherMaterial.status ==
            "active",
            TeacherMaterial.is_active.is_(
                True,
            ),
        )
        .order_by(
            TeacherMaterialAssignment.updated_at.desc(),
        )
        .all()
    )


def get_teacher_material_assignments_for_group_member(
    db: Session,
    user_id: int,
):
    group_ids = [
        group_id
        for (group_id,) in (
            db.query(
                GroupMember.group_id,
            )
            .filter(
                GroupMember.user_id ==
                user_id,
            )
            .all()
        )
    ]

    if not group_ids:
        return []

    return (
        db.query(
            TeacherMaterialAssignment,
        )
        .join(
            TeacherMaterial,
            TeacherMaterial.id ==
            TeacherMaterialAssignment.material_id,
        )
        .filter(
            TeacherMaterialAssignment.group_id.in_(
                group_ids,
            ),
            TeacherMaterialAssignment.status ==
            "active",
            TeacherMaterial.status ==
            "active",
            TeacherMaterial.is_active.is_(
                True,
            ),
        )
        .order_by(
            TeacherMaterialAssignment.updated_at.desc(),
        )
        .all()
    )


def get_accessible_teacher_material_ids(
    db: Session,
    user_id: int,
):
    direct_ids = {
        assignment.material_id
        for assignment in (
            get_teacher_material_assignments_for_user(
                db,
                user_id,
            )
        )
    }

    group_ids = {
        assignment.material_id
        for assignment in (
            get_teacher_material_assignments_for_group_member(
                db,
                user_id,
            )
        )
    }

    return (
        direct_ids
        | group_ids
    )


def can_user_access_teacher_material(
    db: Session,
    *,
    user_id: int,
    material_id: int,
):
    return (
        material_id
        in get_accessible_teacher_material_ids(
            db,
            user_id,
        )
    )

def get_accessible_teacher_materials_for_user(
    db: Session,
    user_id: int,
    subject_id: int,
):
    material_ids = get_accessible_teacher_material_ids(
        db,
        user_id=user_id,
        subject_id=subject_id,
    )

    if not material_ids:
        return []

    return (
        db.query(
            TeacherMaterial,
        )
        .filter(
            TeacherMaterial.id.in_(
                material_ids,
            ),
            TeacherMaterial.status ==
            "active",
            TeacherMaterial.is_active.is_(
                True,
            ),
        )
        .order_by(
            TeacherMaterial.created_at.desc(),
        )
        .all()
    )