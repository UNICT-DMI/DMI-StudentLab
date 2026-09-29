"""Requests for unknown courses and admin-approved course catalogue.

Revision ID: b947academic_catalog
Revises: b946lm40_l31_times
"""
from alembic import op
import sqlalchemy as sa

revision = 'b947academic_catalog'
down_revision = 'b946lm40_l31_times'
branch_labels = None
depends_on = None


def upgrade():
    op.create_table('academic_catalog_courses',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('university', sa.String(200), nullable=False),
        sa.Column('university_code', sa.String(50), nullable=False),
        sa.Column('department', sa.String(200), nullable=False),
        sa.Column('department_code', sa.String(50), nullable=False),
        sa.Column('course', sa.String(200), nullable=False),
        sa.Column('course_code', sa.String(50), nullable=False),
        sa.Column('degree_type', sa.String(50)),
        sa.Column('created_by', sa.Integer(), sa.ForeignKey('users.id', ondelete='SET NULL')),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint('university_code', 'department_code', 'course_code',
                            name='uq_academic_catalog_course'))
    op.create_table('academic_catalog_requests',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('academic_path_id', sa.Integer(), sa.ForeignKey('user_academic_paths.id', ondelete='CASCADE'),
                  nullable=False, unique=True),
        sa.Column('university', sa.String(200), nullable=False),
        sa.Column('university_code', sa.String(50), nullable=False, server_default=''),
        sa.Column('department', sa.String(200), nullable=False),
        sa.Column('department_code', sa.String(50), nullable=False, server_default=''),
        sa.Column('course', sa.String(200), nullable=False),
        sa.Column('course_code', sa.String(50), nullable=False, server_default=''),
        sa.Column('status', sa.String(20), nullable=False, server_default='pending'),
        sa.Column('admin_note', sa.Text()),
        sa.Column('decided_by', sa.Integer(), sa.ForeignKey('users.id', ondelete='SET NULL')),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('decided_at', sa.DateTime(timezone=True)))
    op.create_index('ix_academic_catalog_requests_user_id', 'academic_catalog_requests', ['user_id'])
    op.create_index('ix_academic_catalog_requests_status', 'academic_catalog_requests', ['status'])


def downgrade():
    op.drop_index('ix_academic_catalog_requests_status', table_name='academic_catalog_requests')
    op.drop_index('ix_academic_catalog_requests_user_id', table_name='academic_catalog_requests')
    op.drop_table('academic_catalog_requests')
    op.drop_table('academic_catalog_courses')
