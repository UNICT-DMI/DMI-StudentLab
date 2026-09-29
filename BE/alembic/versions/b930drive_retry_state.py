"""Schedule safe retries of interrupted Drive copies.

Revision ID: b930driveretry
Revises: b929drivepaths
"""
from alembic import op
import sqlalchemy as sa

revision = 'b930driveretry'
down_revision = 'b929drivepaths'
branch_labels = None
depends_on = None


def upgrade():
    columns = {c['name'] for c in sa.inspect(op.get_bind()).get_columns('public_materials')}
    if 'drive_retry_after' not in columns:
        op.add_column('public_materials', sa.Column('drive_retry_after',
            sa.DateTime(timezone=True), nullable=True))
    if 'drive_retry_attempts' not in columns:
        op.add_column('public_materials', sa.Column('drive_retry_attempts',
            sa.Integer(), nullable=False, server_default='0'))


def downgrade():
    columns = {c['name'] for c in sa.inspect(op.get_bind()).get_columns('public_materials')}
    if 'drive_retry_attempts' in columns:
        op.drop_column('public_materials', 'drive_retry_attempts')
    if 'drive_retry_after' in columns:
        op.drop_column('public_materials', 'drive_retry_after')
