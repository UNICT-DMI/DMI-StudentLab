"""Link a public Drive material when fulfilling a StudentLab request.

Revision ID: b934requestpublic
Revises: b933catalogimports
"""
from alembic import op
import sqlalchemy as sa

revision = 'b934requestpublic'
down_revision = 'b933catalogimports'
branch_labels = None
depends_on = None

def upgrade():
    op.add_column('teacher_material_requests', sa.Column('public_material_id', sa.Integer(),
        sa.ForeignKey('public_materials.id', ondelete='SET NULL'), nullable=True))
    op.add_column('teacher_material_requests', sa.Column('fulfilled_share_id', sa.Integer(),
        sa.ForeignKey('material_shares.id', ondelete='SET NULL'), nullable=True))
    op.create_index('ix_teacher_request_public_material', 'teacher_material_requests',
        ['public_material_id'])

def downgrade():
    op.drop_index('ix_teacher_request_public_material', table_name='teacher_material_requests')
    op.drop_column('teacher_material_requests', 'fulfilled_share_id')
    op.drop_column('teacher_material_requests', 'public_material_id')
