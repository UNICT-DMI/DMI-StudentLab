"""Add non-destructive logical public material paths.

Revision ID: b924catalog
Revises: 74c56a670ea1
"""
from alembic import op
import sqlalchemy as sa

revision = 'b924catalog'
down_revision = '74c56a670ea1'
branch_labels = None
depends_on = None


def upgrade():
    columns = {column['name'] for column in sa.inspect(op.get_bind()).get_columns('public_materials')}
    if 'catalog_path_json' not in columns:
        op.add_column('public_materials', sa.Column('catalog_path_json', sa.Text(),
            nullable=False, server_default='[]'))
    if 'visibility_state' not in columns:
        op.add_column('public_materials', sa.Column('visibility_state', sa.String(20),
            nullable=False, server_default='visible'))


def downgrade():
    # Rollback of this migration loses logical folder locations, never files.
    columns = {column['name'] for column in sa.inspect(op.get_bind()).get_columns('public_materials')}
    if 'visibility_state' in columns:
        op.drop_column('public_materials', 'visibility_state')
    if 'catalog_path_json' in columns:
        op.drop_column('public_materials', 'catalog_path_json')
