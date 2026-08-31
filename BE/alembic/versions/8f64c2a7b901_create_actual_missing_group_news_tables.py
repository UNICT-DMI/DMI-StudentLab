"""create actual missing group news tables

Revision ID: 8f64c2a7b901
Revises: 520c65835e7a
Create Date: 2026-08-21
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "8f64c2a7b901"
down_revision: Union[str, Sequence[str], None] = "520c65835e7a"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_table(name: str) -> bool:
    inspector = sa.inspect(op.get_bind())
    return inspector.has_table(name)


def upgrade() -> None:
    if not _has_table("user_blocks"):
        op.create_table(
            "user_blocks",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column(
                "blocker_user_id",
                sa.Integer(),
                sa.ForeignKey("users.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column(
                "blocked_user_id",
                sa.Integer(),
                sa.ForeignKey("users.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column(
                "created_at",
                sa.DateTime(timezone=True),
                nullable=False,
            ),
            sa.UniqueConstraint(
                "blocker_user_id",
                "blocked_user_id",
                name="uq_user_block",
            ),
            sa.CheckConstraint(
                "blocker_user_id <> blocked_user_id",
                name="chk_user_block_not_self",
            ),
        )
        op.create_index(
            "ix_user_blocks_id",
            "user_blocks",
            ["id"],
        )
        op.create_index(
            "ix_user_blocks_blocker_user_id",
            "user_blocks",
            ["blocker_user_id"],
        )
        op.create_index(
            "ix_user_blocks_blocked_user_id",
            "user_blocks",
            ["blocked_user_id"],
        )
        op.create_index(
            "ix_user_blocks_created_at",
            "user_blocks",
            ["created_at"],
        )

    if not _has_table("group_news"):
        op.create_table(
            "group_news",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column(
                "group_id",
                sa.Integer(),
                sa.ForeignKey("study_groups.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column(
                "author_user_id",
                sa.Integer(),
                sa.ForeignKey("users.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column(
                "recipient_user_id",
                sa.Integer(),
                sa.ForeignKey("users.id", ondelete="SET NULL"),
                nullable=True,
            ),
            sa.Column(
                "parent_news_id",
                sa.Integer(),
                sa.ForeignKey("group_news.id", ondelete="SET NULL"),
                nullable=True,
            ),
            sa.Column("visibility", sa.String(20), nullable=False),
            sa.Column("content", sa.Text(), nullable=False),
            sa.Column("status", sa.String(40), nullable=False),
            sa.Column(
                "deleted_by_user_id",
                sa.Integer(),
                sa.ForeignKey("users.id", ondelete="SET NULL"),
                nullable=True,
            ),
            sa.Column(
                "deleted_at",
                sa.DateTime(timezone=True),
                nullable=True,
            ),
            sa.Column(
                "moderated_by_user_id",
                sa.Integer(),
                sa.ForeignKey("users.id", ondelete="SET NULL"),
                nullable=True,
            ),
            sa.Column(
                "moderated_at",
                sa.DateTime(timezone=True),
                nullable=True,
            ),
            sa.Column("moderation_reason", sa.Text(), nullable=True),
            sa.Column(
                "created_at",
                sa.DateTime(timezone=True),
                nullable=False,
            ),
            sa.Column(
                "updated_at",
                sa.DateTime(timezone=True),
                nullable=False,
            ),
            sa.Column(
                "expires_at",
                sa.DateTime(timezone=True),
                nullable=False,
            ),
            sa.CheckConstraint(
                "visibility IN ('group', 'private')",
                name="chk_group_news_visibility",
            ),
            sa.CheckConstraint(
                "status IN ('active', 'deleted_by_author', "
                "'removed_by_group_owner', 'removed_by_group_admin', "
                "'removed_by_platform_moderator', 'expired')",
                name="chk_group_news_status",
            ),
            sa.CheckConstraint(
                "(visibility = 'group' AND recipient_user_id IS NULL) OR "
                "(visibility = 'private' AND recipient_user_id IS NOT NULL)",
                name="chk_group_news_recipient",
            ),
            sa.CheckConstraint(
                "length(trim(content)) > 0",
                name="chk_group_news_content",
            ),
        )
        for name, column in [
            ("ix_group_news_id", "id"),
            ("ix_group_news_group_id", "group_id"),
            ("ix_group_news_author_user_id", "author_user_id"),
            ("ix_group_news_recipient_user_id", "recipient_user_id"),
            ("ix_group_news_parent_news_id", "parent_news_id"),
            ("ix_group_news_visibility", "visibility"),
            ("ix_group_news_status", "status"),
            ("ix_group_news_deleted_by_user_id", "deleted_by_user_id"),
            ("ix_group_news_deleted_at", "deleted_at"),
            ("ix_group_news_moderated_by_user_id", "moderated_by_user_id"),
            ("ix_group_news_moderated_at", "moderated_at"),
            ("ix_group_news_created_at", "created_at"),
            ("ix_group_news_expires_at", "expires_at"),
        ]:
            op.create_index(name, "group_news", [column])

    if not _has_table("group_news_reports"):
        op.create_table(
            "group_news_reports",
            sa.Column("id", sa.Integer(), primary_key=True),
            sa.Column(
                "news_id",
                sa.Integer(),
                sa.ForeignKey("group_news.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column(
                "group_id",
                sa.Integer(),
                sa.ForeignKey("study_groups.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column(
                "reporter_user_id",
                sa.Integer(),
                sa.ForeignKey("users.id", ondelete="CASCADE"),
                nullable=False,
            ),
            sa.Column(
                "reported_author_user_id",
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
            sa.Column(
                "reviewed_at",
                sa.DateTime(timezone=True),
                nullable=True,
            ),
            sa.Column(
                "created_at",
                sa.DateTime(timezone=True),
                nullable=False,
            ),
            sa.Column(
                "updated_at",
                sa.DateTime(timezone=True),
                nullable=False,
            ),
            sa.CheckConstraint(
                "status IN ('pending', 'under_review', 'resolved', 'rejected')",
                name="chk_group_news_report_status",
            ),
            sa.CheckConstraint(
                "moderation_action IN ('none', 'hide_news', 'remove_news', "
                "'warn_user', 'remove_user_from_group', 'suspend_user', "
                "'deactivate_user')",
                name="chk_group_news_report_action",
            ),
        )
        for name, column in [
            ("ix_group_news_reports_id", "id"),
            ("ix_group_news_reports_news_id", "news_id"),
            ("ix_group_news_reports_group_id", "group_id"),
            ("ix_group_news_reports_reporter_user_id", "reporter_user_id"),
            (
                "ix_group_news_reports_reported_author_user_id",
                "reported_author_user_id",
            ),
            ("ix_group_news_reports_reason", "reason"),
            ("ix_group_news_reports_status", "status"),
            (
                "ix_group_news_reports_moderation_action",
                "moderation_action",
            ),
            (
                "ix_group_news_reports_reviewed_by_user_id",
                "reviewed_by_user_id",
            ),
            ("ix_group_news_reports_reviewed_at", "reviewed_at"),
            ("ix_group_news_reports_created_at", "created_at"),
        ]:
            op.create_index(name, "group_news_reports", [column])


def downgrade() -> None:
    if _has_table("group_news_reports"):
        op.drop_table("group_news_reports")
    if _has_table("group_news"):
        op.drop_table("group_news")
    if _has_table("user_blocks"):
        op.drop_table("user_blocks")
