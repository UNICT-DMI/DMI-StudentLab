"""Keep new approved materials private until their primary Drive copy is ready.

Revision ID: b927driveprimary
Revises: b926audience
"""
from alembic import op
import sqlalchemy as sa

revision = 'b927driveprimary'
down_revision = 'b926audience'
branch_labels = None
depends_on = None


def upgrade():
    columns = {item['name'] for item in sa.inspect(op.get_bind()).get_columns('public_materials')}
    if 'drive_activation_pending' not in columns:
        op.add_column('public_materials', sa.Column('drive_activation_pending',
            sa.Boolean(), nullable=False, server_default=sa.false()))


def downgrade():
    columns = {item['name'] for item in sa.inspect(op.get_bind()).get_columns('public_materials')}
    if 'drive_activation_pending' in columns:
        op.drop_column('public_materials', 'drive_activation_pending')
