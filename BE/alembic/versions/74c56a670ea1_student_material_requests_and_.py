"""student material requests and notification types

Revision ID: 74c56a670ea1
Revises: 2d9f40a8c7b1
Create Date: 2026-09-07 23:05:21.859485

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "74c56a670ea1"
down_revision: Union[str, Sequence[str], None] = "2d9f40a8c7b1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


_NOTIFICATION_TYPES = (
    "group_ownership_transfer",
    "group_join_request",
    "group_join_accepted",
    "group_join_rejected",
    "group_deleted",
    "group_report_update",
    "profile_report_update",
    "profile_error_update",
    "teacher_verification_update",
    "teacher_assignment_update",
    "academic_path_verification_update",
    "grade_verification_update",
    "material_publication_request",
    "material_publication_approved",
    "material_publication_rejected",
    "quiz_assignment",
    "teacher_material_request",
    "teacher_material_request_resolved",
    "student_material_request",
    "student_material_request_resolved",
    "student_material_request_cancelled",
    "material_share",
    "system",
)

_NOTIFICATION_RESOURCE_TYPES = (
    "user",
    "group",
    "group_join_request",
    "group_ownership_transfer",
    "teacher_assignment",
    "academic_path",
    "subject",
    "material",
    "profile_report",
    "profile_error_report",
    "quiz_assignment",
    "teacher_material_request",
    "student_material_request",
    "material_share",
)

_NOTIFICATION_ACTION_TYPES = (
    "accept_reject_group_ownership",
    "accept_reject_group_join",
    "open_profile",
    "open_group",
    "open_material",
    "open_admin_review",
    "quiz_assignment",
    "teacher_material_request",
    "student_material_request",
    "material_share",
)


def _sql_string_list(values: tuple[str, ...]) -> str:
    return ", ".join(f"'{value}'" for value in values)


def _drop_constraint_if_exists(table_name: str, constraint_name: str) -> None:
    # table_name e constraint_name provengono solo da costanti interne
    # definite in questa migration.
    op.execute(
        sa.text(
            f'ALTER TABLE "{table_name}" '
            f'DROP CONSTRAINT IF EXISTS "{constraint_name}"'
        )
    )


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "student_material_requests",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("requester_user_id", sa.Integer(), nullable=False),
        sa.Column("recipient_user_id", sa.Integer(), nullable=False),
        sa.Column("subject_id", sa.Integer(), nullable=True),
        sa.Column("topic", sa.String(length=255), nullable=True),
        sa.Column("message", sa.Text(), nullable=False),
        sa.Column(
            "status",
            sa.String(length=30),
            nullable=False,
            server_default="pending",
        ),
        sa.Column("fulfilled_share_id", sa.Integer(), nullable=True),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
        sa.CheckConstraint(
            "requester_user_id != recipient_user_id",
            name="chk_student_material_request_different_users",
        ),
        sa.CheckConstraint(
            "status IN ('pending','fulfilled','declined','cancelled')",
            name="chk_student_material_request_status",
        ),
        sa.ForeignKeyConstraint(
            ["requester_user_id"],
            ["users.id"],
            name="fk_student_material_requests_requester",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["recipient_user_id"],
            ["users.id"],
            name="fk_student_material_requests_recipient",
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            ["subject_id"],
            ["subjects.id"],
            name="fk_student_material_requests_subject",
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            ["fulfilled_share_id"],
            ["material_shares.id"],
            name="fk_student_material_requests_fulfilled_share",
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_index(
        "ix_student_material_requests_requester_user_id",
        "student_material_requests",
        ["requester_user_id"],
        unique=False,
    )
    op.create_index(
        "ix_student_material_requests_recipient_user_id",
        "student_material_requests",
        ["recipient_user_id"],
        unique=False,
    )
    op.create_index(
        "ix_student_material_requests_subject_id",
        "student_material_requests",
        ["subject_id"],
        unique=False,
    )
    op.create_index(
        "ix_student_material_requests_status",
        "student_material_requests",
        ["status"],
        unique=False,
    )
    op.create_index(
        "ix_student_material_requests_fulfilled_share_id",
        "student_material_requests",
        ["fulfilled_share_id"],
        unique=False,
    )
    op.create_index(
        "ix_student_material_requests_created_at",
        "student_material_requests",
        ["created_at"],
        unique=False,
    )
    op.create_index(
        "ix_student_material_requests_updated_at",
        "student_material_requests",
        ["updated_at"],
        unique=False,
    )

    # Rimuove in modo sicuro i vecchi CHECK, se presenti.
    _drop_constraint_if_exists("notifications", "chk_notification_type")
    _drop_constraint_if_exists("notifications", "chk_notification_resource_type")
    _drop_constraint_if_exists("notifications", "chk_notification_action_type")

    op.create_check_constraint(
        "chk_notification_type",
        "notifications",
        f"type IN ({_sql_string_list(_NOTIFICATION_TYPES)})",
    )
    op.create_check_constraint(
        "chk_notification_resource_type",
        "notifications",
        "resource_type IS NULL OR "
        f"resource_type IN ({_sql_string_list(_NOTIFICATION_RESOURCE_TYPES)})",
    )
    op.create_check_constraint(
        "chk_notification_action_type",
        "notifications",
        "action_type IS NULL OR "
        f"action_type IN ({_sql_string_list(_NOTIFICATION_ACTION_TYPES)})",
    )


def downgrade() -> None:
    """Downgrade schema."""
    # Le notifiche introdotte da questa revisione non sono compatibili
    # con i CHECK della revisione precedente.
    op.execute(
        sa.text(
            """
            DELETE FROM notifications
            WHERE type IN (
                'quiz_assignment',
                'teacher_material_request',
                'teacher_material_request_resolved',
                'student_material_request',
                'student_material_request_resolved',
                'student_material_request_cancelled',
                'material_share'
            )
            OR resource_type IN (
                'quiz_assignment',
                'teacher_material_request',
                'student_material_request',
                'material_share'
            )
            OR action_type IN (
                'quiz_assignment',
                'teacher_material_request',
                'student_material_request',
                'material_share'
            );
            """
        )
    )

    _drop_constraint_if_exists("notifications", "chk_notification_type")
    _drop_constraint_if_exists("notifications", "chk_notification_resource_type")
    _drop_constraint_if_exists("notifications", "chk_notification_action_type")

    op.create_check_constraint(
        "chk_notification_type",
        "notifications",
        "type IN ("
        "'group_ownership_transfer', "
        "'group_join_request', "
        "'group_join_accepted', "
        "'group_join_rejected', "
        "'group_deleted', "
        "'group_report_update', "
        "'profile_report_update', "
        "'profile_error_update', "
        "'teacher_verification_update', "
        "'teacher_assignment_update', "
        "'academic_path_verification_update', "
        "'grade_verification_update', "
        "'material_publication_request', "
        "'material_publication_approved', "
        "'material_publication_rejected', "
        "'system'"
        ")",
    )
    op.create_check_constraint(
        "chk_notification_resource_type",
        "notifications",
        "resource_type IS NULL OR resource_type IN ("
        "'user', "
        "'group', "
        "'group_join_request', "
        "'group_ownership_transfer', "
        "'teacher_assignment', "
        "'academic_path', "
        "'subject', "
        "'material', "
        "'profile_report', "
        "'profile_error_report'"
        ")",
    )
    op.create_check_constraint(
        "chk_notification_action_type",
        "notifications",
        "action_type IS NULL OR action_type IN ("
        "'accept_reject_group_ownership', "
        "'accept_reject_group_join', "
        "'open_profile', "
        "'open_group', "
        "'open_material', "
        "'open_admin_review'"
        ")",
    )

    op.drop_index(
        "ix_student_material_requests_updated_at",
        table_name="student_material_requests",
    )
    op.drop_index(
        "ix_student_material_requests_created_at",
        table_name="student_material_requests",
    )
    op.drop_index(
        "ix_student_material_requests_fulfilled_share_id",
        table_name="student_material_requests",
    )
    op.drop_index(
        "ix_student_material_requests_status",
        table_name="student_material_requests",
    )
    op.drop_index(
        "ix_student_material_requests_subject_id",
        table_name="student_material_requests",
    )
    op.drop_index(
        "ix_student_material_requests_recipient_user_id",
        table_name="student_material_requests",
    )
    op.drop_index(
        "ix_student_material_requests_requester_user_id",
        table_name="student_material_requests",
    )
    op.drop_table("student_material_requests")
