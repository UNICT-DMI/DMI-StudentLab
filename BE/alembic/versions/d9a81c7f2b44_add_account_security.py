from alembic import op
import sqlalchemy as sa


revision = "d9a81c7f2b44"
down_revision = "c42f71ab9d03"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "password_reset_requests",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("request_id", sa.String(length=64), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("code_hash", sa.String(length=255), nullable=False),
        sa.Column("attempts", sa.Integer(), nullable=False),
        sa.Column("last_sent_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("invalidated_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("request_id"),
    )
    op.create_index(op.f("ix_password_reset_requests_request_id"), "password_reset_requests", ["request_id"], unique=True)
    op.create_index(op.f("ix_password_reset_requests_user_id"), "password_reset_requests", ["user_id"], unique=False)
    op.create_index(op.f("ix_password_reset_requests_used_at"), "password_reset_requests", ["used_at"], unique=False)
    op.create_index(op.f("ix_password_reset_requests_invalidated_at"), "password_reset_requests", ["invalidated_at"], unique=False)

    op.create_table(
        "email_change_requests",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("request_id", sa.String(length=64), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("new_email", sa.String(length=255), nullable=False),
        sa.Column("code_hash", sa.String(length=255), nullable=False),
        sa.Column("attempts", sa.Integer(), nullable=False),
        sa.Column("last_sent_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("invalidated_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("request_id"),
    )
    op.create_index(op.f("ix_email_change_requests_request_id"), "email_change_requests", ["request_id"], unique=True)
    op.create_index(op.f("ix_email_change_requests_user_id"), "email_change_requests", ["user_id"], unique=False)
    op.create_index(op.f("ix_email_change_requests_new_email"), "email_change_requests", ["new_email"], unique=False)
    op.create_index(op.f("ix_email_change_requests_used_at"), "email_change_requests", ["used_at"], unique=False)
    op.create_index(op.f("ix_email_change_requests_invalidated_at"), "email_change_requests", ["invalidated_at"], unique=False)


def downgrade():
    op.drop_index(op.f("ix_email_change_requests_invalidated_at"), table_name="email_change_requests")
    op.drop_index(op.f("ix_email_change_requests_used_at"), table_name="email_change_requests")
    op.drop_index(op.f("ix_email_change_requests_new_email"), table_name="email_change_requests")
    op.drop_index(op.f("ix_email_change_requests_user_id"), table_name="email_change_requests")
    op.drop_index(op.f("ix_email_change_requests_request_id"), table_name="email_change_requests")
    op.drop_table("email_change_requests")

    op.drop_index(op.f("ix_password_reset_requests_invalidated_at"), table_name="password_reset_requests")
    op.drop_index(op.f("ix_password_reset_requests_used_at"), table_name="password_reset_requests")
    op.drop_index(op.f("ix_password_reset_requests_user_id"), table_name="password_reset_requests")
    op.drop_index(op.f("ix_password_reset_requests_request_id"), table_name="password_reset_requests")
    op.drop_table("password_reset_requests")
