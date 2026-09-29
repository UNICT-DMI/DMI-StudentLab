"""Track optional Drive copies of public materials, without changing Blob records.

Revision ID: b925drive
Revises: b924catalog
"""
from alembic import op
import sqlalchemy as sa

revision = 'b925drive'
down_revision = 'b924catalog'
branch_labels = None
depends_on = None


def upgrade():
    columns = {column['name'] for column in sa.inspect(op.get_bind()).get_columns('public_materials')}
    if 'drive_file_id' not in columns:
        op.add_column('public_materials', sa.Column('drive_file_id', sa.String(128), nullable=True))
    if 'drive_copied_at' not in columns:
        op.add_column('public_materials', sa.Column('drive_copied_at', sa.DateTime(timezone=True), nullable=True))


def downgrade():
    columns = {column['name'] for column in sa.inspect(op.get_bind()).get_columns('public_materials')}
    if 'drive_copied_at' in columns:
        op.drop_column('public_materials', 'drive_copied_at')
    if 'drive_file_id' in columns:
        op.drop_column('public_materials', 'drive_file_id')
