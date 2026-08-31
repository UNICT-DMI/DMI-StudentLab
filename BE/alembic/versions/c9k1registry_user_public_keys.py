"""add user public key registry

Revision ID: c9k1registry
Revises: b824support
Create Date: 2026-08-26
"""

from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "c9k1registry"
down_revision: Union[str, Sequence[str], None] = "b824support"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_table(name: str) -> bool:
    return sa.inspect(op.get_bind()).has_table(name)


def upgrade() -> None:
    if _has_table("user_public_keys"):
        return

    op.create_table(
        "user_public_keys",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "user_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("device_id", sa.String(64), nullable=False),
        sa.Column("device_label", sa.String(100), nullable=True),
        sa.Column("algo", sa.String(32), nullable=False),
        sa.Column("public_key", sa.String(512), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("rotated_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint(
            "user_id",
            "device_id",
            name="uq_user_public_key_device",
        ),
        sa.CheckConstraint(
            "algo IN ('x25519')",
            name="chk_user_public_key_algo",
        ),
    )

    for name, column in [
        ("ix_user_public_keys_id", "id"),
        ("ix_user_public_keys_user_id", "user_id"),
        ("ix_user_public_keys_device_id", "device_id"),
        ("ix_user_public_keys_created_at", "created_at"),
        ("ix_user_public_keys_revoked_at", "revoked_at"),
    ]:
        op.create_index(name, "user_public_keys", [column])


def downgrade() -> None:
    if not _has_table("user_public_keys"):
        return

    for name in [
        "ix_user_public_keys_revoked_at",
        "ix_user_public_keys_created_at",
        "ix_user_public_keys_device_id",
        "ix_user_public_keys_user_id",
        "ix_user_public_keys_id",
    ]:
        op.drop_index(name, table_name="user_public_keys")

    op.drop_table("user_public_keys")
