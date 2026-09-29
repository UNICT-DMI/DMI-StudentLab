"""add persistent study plan and device sessions

Revision ID: c9k2studyplan
Revises: c9k1registry
Create Date: 2026-09-05
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "c9k2studyplan"
down_revision: Union[str, Sequence[str], None] = "c9k1registry"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_table(name: str) -> bool:
    return sa.inspect(op.get_bind()).has_table(name)


def upgrade() -> None:
    if not _has_table("device_sessions"):
        op.create_table(
            "device_sessions",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("session_uuid", sa.String(64), nullable=False),
            sa.Column("device_id", sa.String(64), nullable=False),
            sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
            sa.Column("device_label", sa.String(100), nullable=True),
            sa.Column("source_type", sa.String(20), nullable=False),
            sa.Column("contribution_enabled", sa.Boolean(), nullable=False, server_default=sa.true()),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("last_activity_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("associated_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("dissociated_at", sa.DateTime(timezone=True), nullable=True),
            sa.UniqueConstraint("session_uuid", name="uq_device_sessions_session_uuid"),
            sa.CheckConstraint("source_type IN ('guest','authenticated')", name="chk_device_session_source_type"),
        )
        for name, columns in [
            ("ix_device_sessions_id", ["id"]),
            ("ix_device_sessions_session_uuid", ["session_uuid"]),
            ("ix_device_sessions_device_id", ["device_id"]),
            ("ix_device_sessions_user_id", ["user_id"]),
            ("ix_device_sessions_source_type", ["source_type"]),
            ("ix_device_sessions_contribution_enabled", ["contribution_enabled"]),
            ("ix_device_sessions_last_activity_at", ["last_activity_at"]),
            ("ix_device_sessions_dissociated_at", ["dissociated_at"]),
        ]:
            op.create_index(name, "device_sessions", columns)

    if not _has_table("study_plan_items"):
        op.create_table(
            "study_plan_items",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
            sa.Column("department", sa.String(100), nullable=False),
            sa.Column("course", sa.String(100), nullable=False),
            sa.Column("subject", sa.String(255), nullable=False),
            sa.Column("argument", sa.String(255), nullable=True),
            sa.Column("question_id", sa.String(100), nullable=False),
            sa.Column("question_text", sa.Text(), nullable=False, server_default=""),
            sa.Column("options_snapshot", sa.JSON(), nullable=False),
            sa.Column("correct_option_id", sa.String(100), nullable=True),
            sa.Column("correct_option_text", sa.Text(), nullable=True),
            sa.Column("formal_explanation", sa.Text(), nullable=True),
            sa.Column("informal_explanation", sa.Text(), nullable=True),
            sa.Column("correct_answer_explanation", sa.Text(), nullable=True),
            sa.Column("mastery_percentage", sa.Float(), nullable=False, server_default="0"),
            sa.Column("status", sa.String(20), nullable=False, server_default="review"),
            sa.Column("first_seen_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
            sa.UniqueConstraint("user_id", "department", "course", "subject", "question_id", name="uq_study_plan_item_question"),
            sa.CheckConstraint("status IN ('review','improving','consolidated')", name="chk_study_plan_item_status"),
        )
        for name, columns in [
            ("ix_study_plan_items_id", ["id"]),
            ("ix_study_plan_items_user_id", ["user_id"]),
            ("ix_study_plan_items_department", ["department"]),
            ("ix_study_plan_items_course", ["course"]),
            ("ix_study_plan_items_subject", ["subject"]),
            ("ix_study_plan_items_argument", ["argument"]),
            ("ix_study_plan_items_question_id", ["question_id"]),
            ("ix_study_plan_items_status", ["status"]),
            ("ix_study_plan_items_last_seen_at", ["last_seen_at"]),
        ]:
            op.create_index(name, "study_plan_items", columns)

    if not _has_table("study_plan_contributions"):
        op.create_table(
            "study_plan_contributions",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("contribution_uuid", sa.String(128), nullable=False),
            sa.Column("item_id", sa.Integer(), sa.ForeignKey("study_plan_items.id", ondelete="CASCADE"), nullable=False),
            sa.Column("device_session_id", sa.Integer(), sa.ForeignKey("device_sessions.id", ondelete="CASCADE"), nullable=False),
            sa.Column("source_type", sa.String(20), nullable=False),
            sa.Column("source_user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
            sa.Column("correct_count", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("wrong_count", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("unanswered_count", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("review_count", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("last_is_correct", sa.Boolean(), nullable=True),
            sa.Column("last_selected_option_id", sa.String(100), nullable=True),
            sa.Column("last_selected_option_text", sa.Text(), nullable=True),
            sa.Column("last_selected_answer_explanation", sa.Text(), nullable=True),
            sa.Column("first_seen_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("last_answered_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("client_revision", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
            sa.UniqueConstraint("item_id", "device_session_id", name="uq_study_plan_contribution_source"),
            sa.UniqueConstraint("contribution_uuid", name="uq_study_plan_contribution_uuid"),
            sa.CheckConstraint("source_type IN ('guest','authenticated')", name="chk_study_plan_contribution_source_type"),
            sa.CheckConstraint("correct_count >= 0", name="chk_study_plan_contribution_correct"),
            sa.CheckConstraint("wrong_count >= 0", name="chk_study_plan_contribution_wrong"),
            sa.CheckConstraint("unanswered_count >= 0", name="chk_study_plan_contribution_unanswered"),
            sa.CheckConstraint("review_count >= 0", name="chk_study_plan_contribution_review"),
            sa.CheckConstraint("client_revision >= 0", name="chk_study_plan_contribution_revision"),
        )
        for name, columns in [
            ("ix_study_plan_contributions_id", ["id"]),
            ("ix_study_plan_contributions_contribution_uuid", ["contribution_uuid"]),
            ("ix_study_plan_contributions_item_id", ["item_id"]),
            ("ix_study_plan_contributions_device_session_id", ["device_session_id"]),
            ("ix_study_plan_contributions_source_type", ["source_type"]),
            ("ix_study_plan_contributions_source_user_id", ["source_user_id"]),
            ("ix_study_plan_contributions_last_answered_at", ["last_answered_at"]),
        ]:
            op.create_index(name, "study_plan_contributions", columns)

    if not _has_table("study_plan_progress"):
        op.create_table(
            "study_plan_progress",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
            sa.Column("item_id", sa.Integer(), sa.ForeignKey("study_plan_items.id", ondelete="CASCADE"), nullable=False),
            sa.Column("total_reviews", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("successful_reviews", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("consecutive_correct", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("mastery_percentage", sa.Float(), nullable=False, server_default="0"),
            sa.Column("last_reviewed_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
            sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
            sa.UniqueConstraint("user_id", "item_id", name="uq_study_plan_progress_item"),
            sa.CheckConstraint("total_reviews >= 0", name="chk_study_plan_progress_reviews"),
            sa.CheckConstraint("successful_reviews >= 0", name="chk_study_plan_progress_success"),
            sa.CheckConstraint("consecutive_correct >= 0", name="chk_study_plan_progress_streak"),
        )
        for name, columns in [
            ("ix_study_plan_progress_id", ["id"]),
            ("ix_study_plan_progress_user_id", ["user_id"]),
            ("ix_study_plan_progress_item_id", ["item_id"]),
            ("ix_study_plan_progress_last_reviewed_at", ["last_reviewed_at"]),
            ("ix_study_plan_progress_completed_at", ["completed_at"]),
        ]:
            op.create_index(name, "study_plan_progress", columns)


def downgrade() -> None:
    for table in ["study_plan_progress", "study_plan_contributions", "study_plan_items", "device_sessions"]:
        if _has_table(table):
            op.drop_table(table)
