"""Persist administrator catalog drafts without altering stored student files.

Revision ID: b932catalogdraft
Revises: b931requestinbox
"""
from alembic import op
import sqlalchemy as sa

revision = 'b932catalogdraft'
down_revision = 'b931requestinbox'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table('material_catalog_drafts',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('admin_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('material_id', sa.Integer(), sa.ForeignKey('public_materials.id', ondelete='CASCADE'), nullable=False),
        sa.Column('base_version', sa.Integer(), nullable=False),
        sa.Column('subject_id', sa.Integer(), sa.ForeignKey('subjects.id'), nullable=False),
        sa.Column('path_json', sa.Text(), nullable=False),
        sa.Column('visibility_state', sa.String(20), nullable=False),
        sa.Column('audience_type', sa.String(20), nullable=False),
        sa.Column('audience_id', sa.Integer(), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint('admin_id', 'material_id', name='uq_catalog_draft_admin_material'))
    op.create_index('ix_catalog_draft_admin', 'material_catalog_drafts', ['admin_id'])
    op.create_index('ix_catalog_draft_material', 'material_catalog_drafts', ['material_id'])


def downgrade():
    op.drop_index('ix_catalog_draft_material', table_name='material_catalog_drafts')
    op.drop_index('ix_catalog_draft_admin', table_name='material_catalog_drafts')
    op.drop_table('material_catalog_drafts')
