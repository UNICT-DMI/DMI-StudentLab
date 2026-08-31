"""teacher material assignments

Revision ID: a031e252e978
Revises: 2c9d0baa1255
Create Date: 2026-08-20
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "a031e252e978"
down_revision: Union[str, Sequence[str], None] = "2c9d0baa1255"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "teacher_material_assignments",
        sa.Column(
            "id",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "material_id",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "assigned_by",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "user_id",
            sa.Integer(),
            nullable=True,
        ),
        sa.Column(
            "group_id",
            sa.Integer(),
            nullable=True,
        ),
        sa.Column(
            "status",
            sa.String(length=30),
            server_default="active",
            nullable=False,
        ),
        sa.Column(
            "revoked_by",
            sa.Integer(),
            nullable=True,
        ),
        sa.Column(
            "assigned_at",
            sa.DateTime(timezone=True),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
        ),
        sa.Column(
            "revoked_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.CheckConstraint(
            "(status != 'revoked') OR (revoked_at IS NOT NULL)",
            name="chk_teacher_material_assignment_revoked_at",
        ),
        sa.CheckConstraint(
            "status IN ('active', 'revoked')",
            name="chk_teacher_material_assignment_status",
        ),
        sa.CheckConstraint(
            "((user_id IS NOT NULL AND group_id IS NULL) "
            "OR (user_id IS NULL AND group_id IS NOT NULL))",
            name="chk_teacher_material_assignment_target",
        ),
        sa.ForeignKeyConstraint(
            ["assigned_by"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["group_id"],
            ["study_groups.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["material_id"],
            ["teacher_materials.id"],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["revoked_by"],
            ["users.id"],
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "id",
        ),
        sa.UniqueConstraint(
            "material_id",
            "group_id",
            name="uq_teacher_material_assignment_group",
        ),
        sa.UniqueConstraint(
            "material_id",
            "user_id",
            name="uq_teacher_material_assignment_user",
        ),
    )

    op.create_index(
        "ix_teacher_material_assignments_id",
        "teacher_material_assignments",
        ["id"],
        unique=False,
    )
    op.create_index(
        "ix_teacher_material_assignments_material_id",
        "teacher_material_assignments",
        ["material_id"],
        unique=False,
    )
    op.create_index(
        "ix_teacher_material_assignments_assigned_by",
        "teacher_material_assignments",
        ["assigned_by"],
        unique=False,
    )
    op.create_index(
        "ix_teacher_material_assignments_user_id",
        "teacher_material_assignments",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        "ix_teacher_material_assignments_group_id",
        "teacher_material_assignments",
        ["group_id"],
        unique=False,
    )
    op.create_index(
        "ix_teacher_material_assignments_status",
        "teacher_material_assignments",
        ["status"],
        unique=False,
    )
    op.create_index(
        "ix_teacher_material_assignments_revoked_by",
        "teacher_material_assignments",
        ["revoked_by"],
        unique=False,
    )
    op.create_index(
        "ix_teacher_material_assignments_assigned_at",
        "teacher_material_assignments",
        ["assigned_at"],
        unique=False,
    )
    op.create_index(
        "ix_teacher_material_assignments_updated_at",
        "teacher_material_assignments",
        ["updated_at"],
        unique=False,
    )
    op.create_index(
        "ix_teacher_material_assignments_revoked_at",
        "teacher_material_assignments",
        ["revoked_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_table(
        "teacher_material_assignments",
    )