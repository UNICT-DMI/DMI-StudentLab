"""add material storage events

Revision ID: a82401storage
Revises: 8f64c2a7b901
Create Date: 2026-08-24
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "a82401storage"
down_revision: Union[str, Sequence[str], None] = "8f64c2a7b901"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_table(name: str) -> bool:
    inspector = sa.inspect(op.get_bind())
    return inspector.has_table(name)


def upgrade() -> None:
    if _has_table("material_storage_events"):
        return

    op.create_table(
        "material_storage_events",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("source", sa.String(length=40), nullable=False),
        sa.Column("material_id", sa.Integer(), nullable=True),
        sa.Column("action", sa.String(length=50), nullable=False),
        sa.Column("blob_path", sa.String(length=1000), nullable=True),
        sa.Column("original_name", sa.String(length=255), nullable=True),
        sa.Column("size", sa.BigInteger(), nullable=True),
        sa.Column(
            "actor_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("reason", sa.Text(), nullable=True),
        sa.Column("details_json", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
        ),
    )

    for name, column in [
        ("ix_material_storage_events_id", "id"),
        ("ix_material_storage_events_source", "source"),
        ("ix_material_storage_events_material_id", "material_id"),
        ("ix_material_storage_events_action", "action"),
        ("ix_material_storage_events_blob_path", "blob_path"),
        ("ix_material_storage_events_actor_id", "actor_id"),
        ("ix_material_storage_events_created_at", "created_at"),
    ]:
        op.create_index(
            name,
            "material_storage_events",
            [column],
        )


def downgrade() -> None:
    if _has_table("material_storage_events"):
        op.drop_table("material_storage_events")