"""Route teacher material requests to teachers or StudentLab.

Revision ID: b931requestinbox
Revises: b930driveretry
"""
from alembic import op
import sqlalchemy as sa

revision = 'b931requestinbox'
down_revision = 'b930driveretry'
branch_labels = None
depends_on = None


def upgrade():
    if 'recipient_kind' not in {c['name'] for c in sa.inspect(op.get_bind()).get_columns('teacher_material_requests')}:
        op.add_column('teacher_material_requests', sa.Column('recipient_kind',
            sa.String(20), nullable=False, server_default='teachers'))
        op.create_index('ix_teacher_material_requests_recipient_kind',
            'teacher_material_requests', ['recipient_kind'])
    if 'staff_response' not in {c['name'] for c in sa.inspect(op.get_bind()).get_columns('teacher_material_requests')}:
        op.add_column('teacher_material_requests', sa.Column('staff_response', sa.Text(), nullable=True))


def downgrade():
    if 'staff_response' in {c['name'] for c in sa.inspect(op.get_bind()).get_columns('teacher_material_requests')}:
        op.drop_column('teacher_material_requests', 'staff_response')
    if 'recipient_kind' in {c['name'] for c in sa.inspect(op.get_bind()).get_columns('teacher_material_requests')}:
        op.drop_index('ix_teacher_material_requests_recipient_kind', table_name='teacher_material_requests')
        op.drop_column('teacher_material_requests', 'recipient_kind')
