"""Track teacher decline while a request remains available to StudentLab.

Revision ID: b935teacherfallback
Revises: b934requestpublic
"""
from alembic import op
import sqlalchemy as sa

revision = 'b935teacherfallback'
down_revision = 'b934requestpublic'
branch_labels = None
depends_on = None

def upgrade():
    op.add_column('teacher_material_requests', sa.Column('teacher_declined_at',
        sa.DateTime(timezone=True), nullable=True))

def downgrade():
    op.drop_column('teacher_material_requests', 'teacher_declined_at')
