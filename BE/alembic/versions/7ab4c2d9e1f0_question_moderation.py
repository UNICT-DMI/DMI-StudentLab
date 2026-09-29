from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "7ab4c2d9e1f0"
down_revision: Union[str, Sequence[str], None] = "62ebe54d89b6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "question_moderation_items",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("source_type", sa.String(length=20), nullable=False),
        sa.Column("department", sa.String(length=100), nullable=False),
        sa.Column("course", sa.String(length=100), nullable=False),
        sa.Column("subject", sa.String(length=255), nullable=False),
        sa.Column("question_id", sa.String(length=100), nullable=True),
        sa.Column("proposed_question_payload", sa.JSON(), nullable=True),
        sa.Column("report_reason", sa.String(length=60), nullable=True),
        sa.Column("report_message", sa.Text(), nullable=True),
        sa.Column("created_by", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(length=30), server_default="pending", nullable=False),
        sa.Column("reviewed_by", sa.Integer(), nullable=True),
        sa.Column("reviewer_role", sa.String(length=30), nullable=True),
        sa.Column("resolution_note", sa.Text(), nullable=True),
        sa.Column("review_started_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint("source_type IN ('proposal','report')", name="chk_question_moderation_source_type"),
        sa.CheckConstraint("status IN ('pending','under_review','approved','rejected')", name="chk_question_moderation_status"),
        sa.ForeignKeyConstraint(["created_by"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["reviewed_by"], ["users.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    for name in ["id", "source_type", "department", "course", "subject", "question_id", "created_by", "status", "reviewed_by"]:
        op.create_index(op.f(f"ix_question_moderation_items_{name}"), "question_moderation_items", [name], unique=False)


def downgrade() -> None:
    op.drop_table("question_moderation_items")
