"""Add restricted audiences for published materials; legacy rows stay public.

Revision ID: b926audience
Revises: b925drive
"""
from alembic import op
import sqlalchemy as sa

revision = 'b926audience'
down_revision = 'b925drive'
branch_labels = None
depends_on = None


def upgrade():
    columns = {item['name'] for item in sa.inspect(op.get_bind()).get_columns('public_materials')}
    if 'audience_type' not in columns:
        op.add_column('public_materials', sa.Column('audience_type', sa.String(20),
            nullable=False, server_default='public'))
    if 'audience_id' not in columns:
        op.add_column('public_materials', sa.Column('audience_id', sa.Integer(), nullable=True))
    op.execute("UPDATE public_materials SET visibility_state = 'hidden' WHERE status = 'hidden' AND visibility_state = 'visible'")
    op.execute("UPDATE public_materials SET visibility_state = 'archived' WHERE status = 'removed' AND visibility_state = 'visible'")


def downgrade():
    columns = {item['name'] for item in sa.inspect(op.get_bind()).get_columns('public_materials')}
    if 'audience_id' in columns:
        op.drop_column('public_materials', 'audience_id')
    if 'audience_type' in columns:
        op.drop_column('public_materials', 'audience_type')
