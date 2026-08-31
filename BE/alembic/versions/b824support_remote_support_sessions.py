"""add remote support sessions

Revision ID: b824support
Revises: a82401storage
Create Date: 2026-08-24
"""

from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "b824support"
down_revision: Union[str, Sequence[str], None] = "a82401storage"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_table(name: str) -> bool:
    return sa.inspect(op.get_bind()).has_table(name)


def upgrade() -> None:
    if not _has_table("support_sessions"):
        op.create_table(
            "support_sessions",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
            sa.Column("assigned_admin_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
            sa.Column("issue_summary", sa.String(500), nullable=False),
            sa.Column("issue_details", sa.Text(), nullable=True),
            sa.Column("status", sa.String(30), nullable=False),
            sa.Column("consent_scope", sa.String(30), nullable=True),
            sa.Column("consent_granted_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("consent_revoked_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("last_heartbeat_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("closed_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
            sa.CheckConstraint(
                "status IN ('requested','waiting_consent','active','disconnected','resolved','cancelled','expired')",
                name="chk_support_session_status",
            ),
            sa.CheckConstraint(
                "consent_scope IS NULL OR consent_scope IN ('diagnostic','full_sqlite')",
                name="chk_support_session_consent_scope",
            ),
        )
        for name, column in [
            ("ix_support_sessions_id", "id"),
            ("ix_support_sessions_user_id", "user_id"),
            ("ix_support_sessions_assigned_admin_id", "assigned_admin_id"),
            ("ix_support_sessions_status", "status"),
            ("ix_support_sessions_last_heartbeat_at", "last_heartbeat_at"),
            ("ix_support_sessions_expires_at", "expires_at"),
            ("ix_support_sessions_created_at", "created_at"),
            ("ix_support_sessions_updated_at", "updated_at"),
        ]:
            op.create_index(name, "support_sessions", [column])

    if not _has_table("support_diagnostic_snapshots"):
        op.create_table(
            "support_diagnostic_snapshots",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("session_id", sa.Integer(), sa.ForeignKey("support_sessions.id", ondelete="CASCADE"), nullable=False),
            sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
            sa.Column("app_version", sa.String(100), nullable=True),
            sa.Column("platform", sa.String(100), nullable=True),
            sa.Column("database_version", sa.Integer(), nullable=True),
            sa.Column("payload_json", sa.Text(), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        )
        for name, column in [
            ("ix_support_diagnostic_snapshots_id", "id"),
            ("ix_support_diagnostic_snapshots_session_id", "session_id"),
            ("ix_support_diagnostic_snapshots_user_id", "user_id"),
            ("ix_support_diagnostic_snapshots_created_at", "created_at"),
        ]:
            op.create_index(name, "support_diagnostic_snapshots", [column])

    if not _has_table("support_remote_actions"):
        op.create_table(
            "support_remote_actions",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("session_id", sa.Integer(), sa.ForeignKey("support_sessions.id", ondelete="CASCADE"), nullable=False),
            sa.Column("action", sa.String(60), nullable=False),
            sa.Column("payload_json", sa.Text(), nullable=True),
            sa.Column("status", sa.String(30), nullable=False),
            sa.Column("issued_by", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
            sa.Column("result_json", sa.Text(), nullable=True),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("started_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
            sa.CheckConstraint(
                "action IN ('collect_diagnostics','force_material_sync','clear_remote_cache','purge_stale_remote_materials','refresh_manifest')",
                name="chk_support_remote_action_type",
            ),
            sa.CheckConstraint(
                "status IN ('pending','running','completed','failed','rejected')",
                name="chk_support_remote_action_status",
            ),
        )
        for name, column in [
            ("ix_support_remote_actions_id", "id"),
            ("ix_support_remote_actions_session_id", "session_id"),
            ("ix_support_remote_actions_action", "action"),
            ("ix_support_remote_actions_status", "status"),
            ("ix_support_remote_actions_issued_by", "issued_by"),
            ("ix_support_remote_actions_created_at", "created_at"),
        ]:
            op.create_index(name, "support_remote_actions", [column])


def downgrade() -> None:
    if _has_table("support_remote_actions"):
        op.drop_table("support_remote_actions")
    if _has_table("support_diagnostic_snapshots"):
        op.drop_table("support_diagnostic_snapshots")
    if _has_table("support_sessions"):
        op.drop_table("support_sessions")
