"""Queue additional academic courses for administrator review.

Revision ID: b928courses
Revises: b927driveprimary
"""
from alembic import op
import sqlalchemy as sa

revision = 'b928courses'
down_revision = 'b927driveprimary'
branch_labels = None
depends_on = None


def upgrade():
    tables = sa.inspect(op.get_bind()).get_table_names()
    if 'material_course_proposals' not in tables:
        op.create_table('material_course_proposals',
            sa.Column('id', sa.Integer(), primary_key=True),
            sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
            sa.Column('university', sa.String(200), nullable=False),
            sa.Column('department', sa.String(200), nullable=False),
            sa.Column('course', sa.String(200), nullable=False),
            sa.Column('status', sa.String(20), nullable=False, server_default='pending'),
            sa.Column('approved_subject_id', sa.Integer(), sa.ForeignKey('subjects.id', ondelete='SET NULL'), nullable=True),
            sa.Column('rejection_reason', sa.String(1000), nullable=True),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
            sa.Column('reviewed_at', sa.DateTime(timezone=True), nullable=True))


def downgrade():
    if 'material_course_proposals' in sa.inspect(op.get_bind()).get_table_names():
        op.drop_table('material_course_proposals')
