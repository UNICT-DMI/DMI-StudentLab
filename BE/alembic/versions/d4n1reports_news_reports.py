"""add news reports with consented disclosure

Revision ID: d4n1reports
Revises: c9k1registry
Create Date: 2026-08-26
"""

from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "d4n1reports"
down_revision: Union[str, Sequence[str], None] = "c9k1registry"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_table(name: str) -> bool:
    return sa.inspect(op.get_bind()).has_table(name)


def upgrade() -> None:
    if _has_table("news_reports"):
        return

    op.create_table(
        "news_reports",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("category", sa.String(20), nullable=False),
        sa.Column("news_id", sa.String(64), nullable=False),
        sa.Column("group_id", sa.Integer(), nullable=True),
        sa.Column("conversation_id", sa.String(64), nullable=True),
        sa.Column(
            "reporter_user_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "reported_user_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("reason", sa.String(100), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("status", sa.String(30), nullable=False),
        sa.Column("moderation_action", sa.String(40), nullable=False),
        sa.Column("moderation_note", sa.Text(), nullable=True),
        sa.Column(
            "reviewed_by_user_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("disclosed_content_key", sa.String(512), nullable=True),
        sa.Column(
            "disclosure_consent_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.Column(
            "disclosure_opened_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.Column(
            "disclosure_opened_by_user_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint(
            "category",
            "news_id",
            "reporter_user_id",
            name="uq_news_report_reporter",
        ),
        sa.CheckConstraint(
            "category IN ('avvisi', 'gruppi', 'private')",
            name="chk_news_report_category",
        ),
        sa.CheckConstraint(
            "reason IN ('spam', 'harassment', 'hate', 'privacy', "
            "'illegal_content', 'other')",
            name="chk_news_report_reason",
        ),
        sa.CheckConstraint(
            "status IN ('pending', 'under_review', 'resolved', 'dismissed')",
            name="chk_news_report_status",
        ),
        sa.CheckConstraint(
            "moderation_action IN ('none', 'hide_news', 'remove_news')",
            name="chk_news_report_action",
        ),
    )

    for name, column in [
        ("ix_news_reports_id", "id"),
        ("ix_news_reports_category", "category"),
        ("ix_news_reports_news_id", "news_id"),
        ("ix_news_reports_group_id", "group_id"),
        ("ix_news_reports_conversation_id", "conversation_id"),
        ("ix_news_reports_reporter_user_id", "reporter_user_id"),
        ("ix_news_reports_reported_user_id", "reported_user_id"),
        ("ix_news_reports_reason", "reason"),
        ("ix_news_reports_status", "status"),
        ("ix_news_reports_reviewed_by_user_id", "reviewed_by_user_id"),
        ("ix_news_reports_created_at", "created_at"),
    ]:
        op.create_index(name, "news_reports", [column])


def downgrade() -> None:
    if not _has_table("news_reports"):
        return

    for name in [
        "ix_news_reports_created_at",
        "ix_news_reports_reviewed_by_user_id",
        "ix_news_reports_status",
        "ix_news_reports_reason",
        "ix_news_reports_reported_user_id",
        "ix_news_reports_reporter_user_id",
        "ix_news_reports_conversation_id",
        "ix_news_reports_group_id",
        "ix_news_reports_news_id",
        "ix_news_reports_category",
        "ix_news_reports_id",
    ]:
        op.drop_index(name, table_name="news_reports")

    op.drop_table("news_reports")
