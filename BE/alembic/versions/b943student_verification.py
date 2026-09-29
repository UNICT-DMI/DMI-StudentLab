"""Student profile verification requests.

Revision ID: b943student_verification
Revises: b942quiz_exercise_types
"""
from alembic import op
import sqlalchemy as sa

revision = 'b943student_verification'
down_revision = 'b942quiz_exercise_types'
branch_labels = None
depends_on = None


def upgrade():
    columns = {column['name'] for column in sa.inspect(op.get_bind()).get_columns('users')}
    if 'student_verification_status' not in columns:
        op.add_column('users', sa.Column('student_verification_status', sa.String(30),
                                         nullable=False, server_default='none'))
    indexes = {index['name'] for index in sa.inspect(op.get_bind()).get_indexes('users')}
    if 'ix_users_student_verification_status' not in indexes:
        op.create_index('ix_users_student_verification_status', 'users', ['student_verification_status'])


def downgrade():
    op.drop_index('ix_users_student_verification_status', table_name='users')
    op.drop_column('users', 'student_verification_status')
