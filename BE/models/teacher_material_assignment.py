from datetime import (
    datetime,
    timezone,
)

from sqlalchemy import (
    CheckConstraint,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
)

from sqlalchemy.orm import (
    relationship,
)

from core.database import (
    Base,
)


def utc_now():
    return datetime.now(
        timezone.utc,
    )


class TeacherMaterialAssignment(
    Base,
):
    __tablename__ = (
        "teacher_material_assignments"
    )

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    material_id = Column(
        Integer,
        ForeignKey(
            "teacher_materials.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    assigned_by = Column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    user_id = Column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="CASCADE",
        ),
        nullable=True,
        index=True,
    )

    group_id = Column(
        Integer,
        ForeignKey(
            "study_groups.id",
            ondelete="CASCADE",
        ),
        nullable=True,
        index=True,
    )

    status = Column(
        String(
            30,
        ),
        nullable=False,
        default="active",
        server_default="active",
        index=True,
    )

    revoked_by = Column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="SET NULL",
        ),
        nullable=True,
        index=True,
    )

    assigned_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=False,
        default=utc_now,
        index=True,
    )

    updated_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=False,
        default=utc_now,
        onupdate=utc_now,
        index=True,
    )

    revoked_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=True,
        index=True,
    )

    material = relationship(
        "TeacherMaterial",
        foreign_keys=[
            material_id,
        ],
    )

    assigner = relationship(
        "User",
        foreign_keys=[
            assigned_by,
        ],
    )

    user = relationship(
        "User",
        foreign_keys=[
            user_id,
        ],
    )

    group = relationship(
        "StudyGroup",
        foreign_keys=[
            group_id,
        ],
    )

    revoker = relationship(
        "User",
        foreign_keys=[
            revoked_by,
        ],
    )

    __table_args__ = (
        CheckConstraint(
            (
                "("
                "(user_id IS NOT NULL "
                "AND group_id IS NULL)"
                " OR "
                "(user_id IS NULL "
                "AND group_id IS NOT NULL)"
                ")"
            ),
            name=(
                "chk_teacher_material_assignment_target"
            ),
        ),
        CheckConstraint(
            (
                "status IN "
                "('active', 'revoked')"
            ),
            name=(
                "chk_teacher_material_assignment_status"
            ),
        ),
        CheckConstraint(
            (
                "(status != 'revoked') "
                "OR "
                "(revoked_at IS NOT NULL)"
            ),
            name=(
                "chk_teacher_material_assignment_revoked_at"
            ),
        ),
        UniqueConstraint(
            "material_id",
            "user_id",
            name=(
                "uq_teacher_material_assignment_user"
            ),
        ),
        UniqueConstraint(
            "material_id",
            "group_id",
            name=(
                "uq_teacher_material_assignment_group"
            ),
        ),
    )