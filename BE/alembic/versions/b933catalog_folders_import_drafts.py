"""Store empty catalog folders and Drive imports before publication.

Revision ID: b933catalogimports
Revises: b932catalogdraft
"""
from alembic import op
import sqlalchemy as sa

revision = 'b933catalogimports'
down_revision = 'b932catalogdraft'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table('material_catalog_folders',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('subject_id', sa.Integer(), sa.ForeignKey('subjects.id'), nullable=False),
        sa.Column('path_json', sa.Text(), nullable=False),
        sa.Column('visibility_state', sa.String(20), nullable=False, server_default='visible'),
        sa.Column('draft_admin_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=True),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False))
    op.create_index('ix_catalog_folders_subject', 'material_catalog_folders', ['subject_id'])
    op.create_index('ix_catalog_folders_admin', 'material_catalog_folders', ['draft_admin_id'])
    op.create_table('material_catalog_import_drafts',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('admin_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('drive_file_id', sa.String(128), nullable=False),
        sa.Column('subject_id', sa.Integer(), sa.ForeignKey('subjects.id'), nullable=False),
        sa.Column('path_json', sa.Text(), nullable=False),
        sa.Column('audience_type', sa.String(20), nullable=False, server_default='public'),
        sa.Column('audience_id', sa.Integer(), nullable=True),
        sa.Column('original_name', sa.String(255), nullable=False),
        sa.Column('mime_type', sa.String(150), nullable=False),
        sa.Column('size', sa.Integer(), nullable=False),
        sa.Column('allow_duplicate', sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint('admin_id', 'drive_file_id', name='uq_catalog_import_admin_drive'))
    op.create_index('ix_catalog_import_admin', 'material_catalog_import_drafts', ['admin_id'])


def downgrade():
    op.drop_index('ix_catalog_import_admin', table_name='material_catalog_import_drafts')
    op.drop_table('material_catalog_import_drafts')
    op.drop_index('ix_catalog_folders_admin', table_name='material_catalog_folders')
    op.drop_index('ix_catalog_folders_subject', table_name='material_catalog_folders')
    op.drop_table('material_catalog_folders')
