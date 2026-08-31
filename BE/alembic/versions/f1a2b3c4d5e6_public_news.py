from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "f1a2b3c4d5e6"
down_revision: Union[str, Sequence[str], None] = "e913275afd2b"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "public_news",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("author_user_id", sa.Integer(), nullable=False),
        sa.Column("subject_id", sa.Integer(), nullable=True),
        sa.Column("target_type", sa.String(length=30), nullable=False),
        sa.Column("title", sa.String(length=160), nullable=False),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("city", sa.String(length=160), nullable=True),
        sa.Column("university", sa.String(length=255), nullable=True),
        sa.Column("university_code", sa.String(length=100), nullable=True),
        sa.Column("department", sa.String(length=255), nullable=True),
        sa.Column("department_code", sa.String(length=100), nullable=True),
        sa.Column("course", sa.String(length=255), nullable=True),
        sa.Column("course_code", sa.String(length=100), nullable=True),
        sa.Column("subject_name", sa.String(length=255), nullable=True),
        sa.Column("status", sa.String(length=40), nullable=False, server_default="active"),
        sa.Column("deleted_by_user_id", sa.Integer(), nullable=True),
        sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("moderated_by_user_id", sa.Integer(), nullable=True),
        sa.Column("moderated_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("moderation_reason", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "target_type IN ('all', 'university', 'department', 'course', 'subject')",
            name="chk_public_news_target_type",
        ),
        sa.CheckConstraint(
            "status IN ('active', 'deleted_by_author', 'removed_by_platform_moderator')",
            name="chk_public_news_status",
        ),
        sa.CheckConstraint("length(trim(title)) > 0", name="chk_public_news_title"),
        sa.CheckConstraint("length(trim(content)) > 0", name="chk_public_news_content"),
        sa.CheckConstraint(
            "(target_type != 'subject') OR (subject_id IS NOT NULL)",
            name="chk_public_news_subject_target",
        ),
        sa.ForeignKeyConstraint(["author_user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["subject_id"], ["subjects.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["deleted_by_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["moderated_by_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )

    for column in [
        "id",
        "author_user_id",
        "subject_id",
        "target_type",
        "city",
        "university",
        "university_code",
        "department",
        "department_code",
        "course",
        "course_code",
        "status",
        "created_at",
    ]:
        op.create_index(f"ix_public_news_{column}", "public_news", [column], unique=False)

    op.create_table(
        "public_news_reports",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("news_id", sa.Integer(), nullable=False),
        sa.Column("reporter_user_id", sa.Integer(), nullable=False),
        sa.Column("reported_author_user_id", sa.Integer(), nullable=True),
        sa.Column("reason", sa.String(length=100), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("status", sa.String(length=30), nullable=False, server_default="pending"),
        sa.Column("moderation_action", sa.String(length=40), nullable=False, server_default="none"),
        sa.Column("moderation_note", sa.Text(), nullable=True),
        sa.Column("reviewed_by_user_id", sa.Integer(), nullable=True),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "reason IN ('spam', 'harassment', 'hate', 'privacy', 'illegal_content', 'other')",
            name="chk_public_news_report_reason",
        ),
        sa.CheckConstraint(
            "status IN ('pending', 'under_review', 'resolved', 'dismissed')",
            name="chk_public_news_report_status",
        ),
        sa.CheckConstraint(
            "moderation_action IN ('none', 'hide_news', 'remove_news', 'warn_user', 'suspend_user', 'deactivate_user')",
            name="chk_public_news_report_action",
        ),
        sa.ForeignKeyConstraint(["news_id"], ["public_news.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["reporter_user_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["reported_author_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["reviewed_by_user_id"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("news_id", "reporter_user_id", name="uq_public_news_report_user"),
    )

    for column in [
        "id",
        "news_id",
        "reporter_user_id",
        "reported_author_user_id",
        "reason",
        "status",
        "reviewed_by_user_id",
        "created_at",
    ]:
        op.create_index(
            f"ix_public_news_reports_{column}",
            "public_news_reports",
            [column],
            unique=False,
        )


def downgrade() -> None:
    for column in [
        "created_at",
        "reviewed_by_user_id",
        "status",
        "reason",
        "reported_author_user_id",
        "reporter_user_id",
        "news_id",
        "id",
    ]:
        op.drop_index(f"ix_public_news_reports_{column}", table_name="public_news_reports")

    op.drop_table("public_news_reports")

    for column in [
        "created_at",
        "status",
        "course_code",
        "course",
        "department_code",
        "department",
        "university_code",
        "university",
        "city",
        "target_type",
        "subject_id",
        "author_user_id",
        "id",
    ]:
        op.drop_index(f"ix_public_news_{column}", table_name="public_news")

    op.drop_table("public_news")
