"""Richieste di materiale: inoltro ai docenti, richieste dell'admin, scadenza
e collegamento a un materiale StudentLab.

Solo colonne aggiunte e facoltative: i record esistenti restano invariati.

Revision ID: b934requestforward
Revises: b933catalogimports
"""
from alembic import op
import sqlalchemy as sa

revision = 'b936requestforward'
down_revision = 'b935teacherfallback'
branch_labels = None
depends_on = None

TABLE = 'teacher_material_requests'


def _columns():
    return {column['name'] for column in sa.inspect(op.get_bind()).get_columns(TABLE)}


def upgrade():
    columns = _columns()
    if 'parent_request_id' not in columns:
        op.add_column(TABLE, sa.Column('parent_request_id', sa.Integer(),
            sa.ForeignKey(f'{TABLE}.id', ondelete='SET NULL'), nullable=True))
        op.create_index('ix_teacher_material_requests_parent_request_id', TABLE, ['parent_request_id'])
    if 'requested_by_admin' not in columns:
        op.add_column(TABLE, sa.Column('requested_by_admin', sa.Boolean(), nullable=False,
            server_default=sa.false()))
    if 'due_date' not in columns:
        op.add_column(TABLE, sa.Column('due_date', sa.Date(), nullable=True))
    if 'fulfilled_public_material_id' not in columns:
        op.add_column(TABLE, sa.Column('fulfilled_public_material_id', sa.Integer(),
            sa.ForeignKey('public_materials.id', ondelete='SET NULL'), nullable=True))


def downgrade():
    columns = _columns()
    if 'fulfilled_public_material_id' in columns:
        op.drop_column(TABLE, 'fulfilled_public_material_id')
    if 'due_date' in columns:
        op.drop_column(TABLE, 'due_date')
    if 'requested_by_admin' in columns:
        op.drop_column(TABLE, 'requested_by_admin')
    if 'parent_request_id' in columns:
        op.drop_index('ix_teacher_material_requests_parent_request_id', table_name=TABLE)
        op.drop_column(TABLE, 'parent_request_id')
