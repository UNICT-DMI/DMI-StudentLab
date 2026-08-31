from typing import (
    Sequence,
    Union,
)

from alembic import (
    op,
)

import sqlalchemy as sa


revision: str = (
    "2afa84133894"
)

down_revision: Union[
    str,
    Sequence[str],
    None,
] = (
    "e913275afd2b"
)

branch_labels: Union[
    str,
    Sequence[str],
    None,
] = None

depends_on: Union[
    str,
    Sequence[str],
    None,
] = None


def upgrade() -> None:
    op.create_table(
        "group_news",
        sa.Column(
            "id",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "group_id",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "author_user_id",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "recipient_user_id",
            sa.Integer(),
            nullable=True,
        ),
        sa.Column(
            "parent_news_id",
            sa.Integer(),
            nullable=True,
        ),
        sa.Column(
            "visibility",
            sa.String(
                length=20,
            ),
            nullable=False,
        ),
        sa.Column(
            "content",
            sa.Text(),
            nullable=False,
        ),
        sa.Column(
            "status",
            sa.String(
                length=40,
            ),
            nullable=False,
        ),
        sa.Column(
            "deleted_by_user_id",
            sa.Integer(),
            nullable=True,
        ),
        sa.Column(
            "deleted_at",
            sa.DateTime(
                timezone=True,
            ),
            nullable=True,
        ),
        sa.Column(
            "moderated_by_user_id",
            sa.Integer(),
            nullable=True,
        ),
        sa.Column(
            "moderated_at",
            sa.DateTime(
                timezone=True,
            ),
            nullable=True,
        ),
        sa.Column(
            "moderation_reason",
            sa.Text(),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(
                timezone=True,
            ),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(
                timezone=True,
            ),
            nullable=False,
        ),
        sa.Column(
            "expires_at",
            sa.DateTime(
                timezone=True,
            ),
            nullable=False,
        ),
        sa.CheckConstraint(
            (
                "visibility IN "
                "('group', 'private')"
            ),
            name=(
                "chk_group_news_visibility"
            ),
        ),
        sa.CheckConstraint(
            (
                "status IN ("
                "'active', "
                "'deleted_by_author', "
                "'removed_by_group_owner', "
                "'removed_by_group_admin', "
                "'removed_by_platform_moderator', "
                "'expired'"
                ")"
            ),
            name=(
                "chk_group_news_status"
            ),
        ),
        sa.CheckConstraint(
            (
                "("
                "visibility = 'group' "
                "AND recipient_user_id IS NULL"
                ") OR ("
                "visibility = 'private' "
                "AND recipient_user_id IS NOT NULL"
                ")"
            ),
            name=(
                "chk_group_news_recipient"
            ),
        ),
        sa.CheckConstraint(
            "length(trim(content)) > 0",
            name=(
                "chk_group_news_content"
            ),
        ),
        sa.ForeignKeyConstraint(
            [
                "author_user_id",
            ],
            [
                "users.id",
            ],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            [
                "deleted_by_user_id",
            ],
            [
                "users.id",
            ],
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            [
                "group_id",
            ],
            [
                "study_groups.id",
            ],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            [
                "moderated_by_user_id",
            ],
            [
                "users.id",
            ],
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            [
                "parent_news_id",
            ],
            [
                "group_news.id",
            ],
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            [
                "recipient_user_id",
            ],
            [
                "users.id",
            ],
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint(
            "id",
        ),
    )

    op.create_index(
        op.f(
            "ix_group_news_id"
        ),
        "group_news",
        [
            "id",
        ],
        unique=False,
    )

    op.create_index(
        op.f(
            "ix_group_news_group_id"
        ),
        "group_news",
        [
            "group_id",
        ],
        unique=False,
    )

    op.create_index(
        op.f(
            "ix_group_news_author_user_id"
        ),
        "group_news",
        [
            "author_user_id",
        ],
        unique=False,
    )

    op.create_index(
        op.f(
            "ix_group_news_recipient_user_id"
        ),
        "group_news",
        [
            "recipient_user_id",
        ],
        unique=False,
    )

    op.create_index(
        op.f(
            "ix_group_news_parent_news_id"
        ),
        "group_news",
        [
            "parent_news_id",
        ],
        unique=False,
    )

    op.create_index(
        op.f(
            "ix_group_news_visibility"
        ),
        "group_news",
        [
            "visibility",
        ],
        unique=False,
    )

    op.create_index(
        op.f(
            "ix_group_news_status"
        ),
        "group_news",
        [
            "status",
        ],
        unique=False,
    )

    op.create_index(
        op.f(
            "ix_group_news_deleted_by_user_id"
        ),
        "group_news",
        [
            "deleted_by_user_id",
        ],
        unique=False,
    )

    op.create_index(
        op.f(
            "ix_group_news_deleted_at"
        ),
        "group_news",
        [
            "deleted_at",
        ],
        unique=False,
    )

    op.create_index(
        op.f(
            "ix_group_news_moderated_by_user_id"
        ),
        "group_news",
        [
            "moderated_by_user_id",
        ],
        unique=False,
    )

    op.create_index(
        op.f(
            "ix_group_news_moderated_at"
        ),
        "group_news",
        [
            "moderated_at",
        ],
        unique=False,
    )

    op.create_index(
        op.f(
            "ix_group_news_created_at"
        ),
        "group_news",
        [
            "created_at",
        ],
        unique=False,
    )

    op.create_index(
        op.f(
            "ix_group_news_expires_at"
        ),
        "group_news",
        [
            "expires_at",
        ],
        unique=False,
    )

    op.create_table(
        "user_blocks",
        sa.Column(
            "id",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "blocker_user_id",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "blocked_user_id",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(
                timezone=True,
            ),
            nullable=False,
        ),
        sa.CheckConstraint(
            (
                "blocker_user_id "
                "<> "
                "blocked_user_id"
            ),
            name=(
                "chk_user_block_not_self"
            ),
        ),
        sa.ForeignKeyConstraint(
            [
                "blocked_user_id",
            ],
            [
                "users.id",
            ],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            [
                "blocker_user_id",
            ],
            [
                "users.id",
            ],
            ondelete="CASCADE",
        ),
        sa.PrimaryKeyConstraint(
            "id",
        ),
        sa.UniqueConstraint(
            "blocker_user_id",
            "blocked_user_id",
            name=(
                "uq_user_block"
            ),
        ),
    )

    op.create_index(
        op.f(
            "ix_user_blocks_id"
        ),
        "user_blocks",
        [
            "id",
        ],
        unique=False,
    )

    op.create_index(
        op.f(
            "ix_user_blocks_blocker_user_id"
        ),
        "user_blocks",
        [
            "blocker_user_id",
        ],
        unique=False,
    )

    op.create_index(
        op.f(
            "ix_user_blocks_blocked_user_id"
        ),
        "user_blocks",
        [
            "blocked_user_id",
        ],
        unique=False,
    )

    op.create_index(
        op.f(
            "ix_user_blocks_created_at"
        ),
        "user_blocks",
        [
            "created_at",
        ],
        unique=False,
    )

    op.create_table(
        "group_news_reports",
        sa.Column(
            "id",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "news_id",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "group_id",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "reporter_user_id",
            sa.Integer(),
            nullable=False,
        ),
        sa.Column(
            "reported_author_user_id",
            sa.Integer(),
            nullable=True,
        ),
        sa.Column(
            "reason",
            sa.String(
                length=100,
            ),
            nullable=False,
        ),
        sa.Column(
            "description",
            sa.Text(),
            nullable=True,
        ),
        sa.Column(
            "status",
            sa.String(
                length=30,
            ),
            nullable=False,
        ),
        sa.Column(
            "moderation_action",
            sa.String(
                length=40,
            ),
            nullable=False,
        ),
        sa.Column(
            "moderation_note",
            sa.Text(),
            nullable=True,
        ),
        sa.Column(
            "reviewed_by_user_id",
            sa.Integer(),
            nullable=True,
        ),
        sa.Column(
            "reviewed_at",
            sa.DateTime(
                timezone=True,
            ),
            nullable=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(
                timezone=True,
            ),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(
                timezone=True,
            ),
            nullable=False,
        ),
        sa.CheckConstraint(
            (
                "reason IN ("
                "'spam', "
                "'harassment', "
                "'hate_speech', "
                "'sexual_content', "
                "'violence', "
                "'misinformation', "
                "'privacy_violation', "
                "'impersonation', "
                "'illegal_content', "
                "'other'"
                ")"
            ),
            name=(
                "chk_group_news_report_reason"
            ),
        ),
        sa.CheckConstraint(
            (
                "status IN ("
                "'pending', "
                "'under_review', "
                "'resolved', "
                "'rejected'"
                ")"
            ),
            name=(
                "chk_group_news_report_status"
            ),
        ),
        sa.CheckConstraint(
            (
                "moderation_action IN ("
                "'none', "
                "'hide_news', "
                "'remove_news', "
                "'warn_user', "
                "'remove_user_from_group', "
                "'suspend_user', "
                "'deactivate_user'"
                ")"
            ),
            name=(
                "chk_group_news_report_action"
            ),
        ),
        sa.ForeignKeyConstraint(
            [
                "group_id",
            ],
            [
                "study_groups.id",
            ],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            [
                "news_id",
            ],
            [
                "group_news.id",
            ],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            [
                "reported_author_user_id",
            ],
            [
                "users.id",
            ],
            ondelete="SET NULL",
        ),
        sa.ForeignKeyConstraint(
            [
                "reporter_user_id",
            ],
            [
                "users.id",
            ],
            ondelete="CASCADE",
        ),
        sa.ForeignKeyConstraint(
            [
                "reviewed_by_user_id",
            ],
            [
                "users.id",
            ],
            ondelete="SET NULL",
        ),
        sa.PrimaryKeyConstraint(
            "id",
        ),
    )

    op.create_index(
        op.f(
            "ix_group_news_reports_id"
        ),
        "group_news_reports",
        [
            "id",
        ],
        unique=False,
    )

    op.create_index(
        op.f(
            "ix_group_news_reports_news_id"
        ),
        "group_news_reports",
        [
            "news_id",
        ],
        unique=False,
    )

    op.create_index(
        op.f(
            "ix_group_news_reports_group_id"
        ),
        "group_news_reports",
        [
            "group_id",
        ],
        unique=False,
    )

    op.create_index(
        op.f(
            "ix_group_news_reports_reporter_user_id"
        ),
        "group_news_reports",
        [
            "reporter_user_id",
        ],
        unique=False,
    )

    op.create_index(
        op.f(
            "ix_group_news_reports_reported_author_user_id"
        ),
        "group_news_reports",
        [
            "reported_author_user_id",
        ],
        unique=False,
    )

    op.create_index(
        op.f(
            "ix_group_news_reports_reason"
        ),
        "group_news_reports",
        [
            "reason",
        ],
        unique=False,
    )

    op.create_index(
        op.f(
            "ix_group_news_reports_status"
        ),
        "group_news_reports",
        [
            "status",
        ],
        unique=False,
    )

    op.create_index(
        op.f(
            "ix_group_news_reports_moderation_action"
        ),
        "group_news_reports",
        [
            "moderation_action",
        ],
        unique=False,
    )

    op.create_index(
        op.f(
            "ix_group_news_reports_reviewed_by_user_id"
        ),
        "group_news_reports",
        [
            "reviewed_by_user_id",
        ],
        unique=False,
    )

    op.create_index(
        op.f(
            "ix_group_news_reports_reviewed_at"
        ),
        "group_news_reports",
        [
            "reviewed_at",
        ],
        unique=False,
    )

    op.create_index(
        op.f(
            "ix_group_news_reports_created_at"
        ),
        "group_news_reports",
        [
            "created_at",
        ],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index(
        op.f(
            "ix_group_news_reports_created_at"
        ),
        table_name=(
            "group_news_reports"
        ),
    )

    op.drop_index(
        op.f(
            "ix_group_news_reports_reviewed_at"
        ),
        table_name=(
            "group_news_reports"
        ),
    )

    op.drop_index(
        op.f(
            "ix_group_news_reports_reviewed_by_user_id"
        ),
        table_name=(
            "group_news_reports"
        ),
    )

    op.drop_index(
        op.f(
            "ix_group_news_reports_moderation_action"
        ),
        table_name=(
            "group_news_reports"
        ),
    )

    op.drop_index(
        op.f(
            "ix_group_news_reports_status"
        ),
        table_name=(
            "group_news_reports"
        ),
    )

    op.drop_index(
        op.f(
            "ix_group_news_reports_reason"
        ),
        table_name=(
            "group_news_reports"
        ),
    )

    op.drop_index(
        op.f(
            "ix_group_news_reports_reported_author_user_id"
        ),
        table_name=(
            "group_news_reports"
        ),
    )

    op.drop_index(
        op.f(
            "ix_group_news_reports_reporter_user_id"
        ),
        table_name=(
            "group_news_reports"
        ),
    )

    op.drop_index(
        op.f(
            "ix_group_news_reports_group_id"
        ),
        table_name=(
            "group_news_reports"
        ),
    )

    op.drop_index(
        op.f(
            "ix_group_news_reports_news_id"
        ),
        table_name=(
            "group_news_reports"
        ),
    )

    op.drop_index(
        op.f(
            "ix_group_news_reports_id"
        ),
        table_name=(
            "group_news_reports"
        ),
    )

    op.drop_table(
        "group_news_reports"
    )

    op.drop_index(
        op.f(
            "ix_user_blocks_created_at"
        ),
        table_name=(
            "user_blocks"
        ),
    )

    op.drop_index(
        op.f(
            "ix_user_blocks_blocked_user_id"
        ),
        table_name=(
            "user_blocks"
        ),
    )

    op.drop_index(
        op.f(
            "ix_user_blocks_blocker_user_id"
        ),
        table_name=(
            "user_blocks"
        ),
    )

    op.drop_index(
        op.f(
            "ix_user_blocks_id"
        ),
        table_name=(
            "user_blocks"
        ),
    )

    op.drop_table(
        "user_blocks"
    )

    op.drop_index(
        op.f(
            "ix_group_news_expires_at"
        ),
        table_name=(
            "group_news"
        ),
    )

    op.drop_index(
        op.f(
            "ix_group_news_created_at"
        ),
        table_name=(
            "group_news"
        ),
    )

    op.drop_index(
        op.f(
            "ix_group_news_moderated_at"
        ),
        table_name=(
            "group_news"
        ),
    )

    op.drop_index(
        op.f(
            "ix_group_news_moderated_by_user_id"
        ),
        table_name=(
            "group_news"
        ),
    )

    op.drop_index(
        op.f(
            "ix_group_news_deleted_at"
        ),
        table_name=(
            "group_news"
        ),
    )

    op.drop_index(
        op.f(
            "ix_group_news_deleted_by_user_id"
        ),
        table_name=(
            "group_news"
        ),
    )

    op.drop_index(
        op.f(
            "ix_group_news_status"
        ),
        table_name=(
            "group_news"
        ),
    )

    op.drop_index(
        op.f(
            "ix_group_news_visibility"
        ),
        table_name=(
            "group_news"
        ),
    )

    op.drop_index(
        op.f(
            "ix_group_news_parent_news_id"
        ),
        table_name=(
            "group_news"
        ),
    )

    op.drop_index(
        op.f(
            "ix_group_news_recipient_user_id"
        ),
        table_name=(
            "group_news"
        ),
    )

    op.drop_index(
        op.f(
            "ix_group_news_author_user_id"
        ),
        table_name=(
            "group_news"
        ),
    )

    op.drop_index(
        op.f(
            "ix_group_news_group_id"
        ),
        table_name=(
            "group_news"
        ),
    )

    op.drop_index(
        op.f(
            "ix_group_news_id"
        ),
        table_name=(
            "group_news"
        ),
    )

    op.drop_table(
        "group_news"
    )