"""Persist Drive placement decisions without moving legacy Blob files.

Revision ID: b929drivepaths
Revises: b928courses
"""
from alembic import op
import sqlalchemy as sa

revision = 'b929drivepaths'
down_revision = 'b928courses'
branch_labels = None
depends_on = None


def upgrade():
    columns = {c['name'] for c in sa.inspect(op.get_bind()).get_columns('public_materials')}
    if 'drive_path_json' not in columns:
        op.add_column('public_materials', sa.Column('drive_path_json', sa.Text(), nullable=True))
    if 'drive_allow_duplicate' not in columns:
        op.add_column('public_materials', sa.Column('drive_allow_duplicate',
            sa.Boolean(), nullable=False, server_default=sa.false()))


def downgrade():
    columns = {c['name'] for c in sa.inspect(op.get_bind()).get_columns('public_materials')}
    if 'drive_allow_duplicate' in columns:
        op.drop_column('public_materials', 'drive_allow_duplicate')
    if 'drive_path_json' in columns:
        op.drop_column('public_materials', 'drive_path_json')
