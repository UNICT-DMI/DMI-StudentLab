"""Calendario accademico: eventi, eventi seguiti, impostazioni dei promemoria.
Solo tabelle nuove.

Revision ID: b940calendar
Revises: b939dictionary
"""
from alembic import op
import sqlalchemy as sa

revision = 'b940calendar'
down_revision = 'b939dictionary'
branch_labels = None
depends_on = None


def upgrade():
    tables = set(sa.inspect(op.get_bind()).get_table_names())
    if 'calendar_events' not in tables:
        op.create_table('calendar_events',
            sa.Column('id', sa.Integer(), primary_key=True),
            sa.Column('university', sa.String(255), nullable=True),
            sa.Column('department', sa.String(255), nullable=True),
            sa.Column('course', sa.String(255), nullable=True),
            sa.Column('subject_id', sa.Integer(), sa.ForeignKey('subjects.id', ondelete='CASCADE'), nullable=True),
            sa.Column('kind', sa.String(20), nullable=False),
            sa.Column('title', sa.String(200), nullable=False),
            sa.Column('starts_at', sa.DateTime(timezone=False), nullable=False),
            sa.Column('ends_at', sa.DateTime(timezone=False), nullable=True),
            sa.Column('all_day', sa.Boolean(), nullable=False, server_default=sa.false()),
            sa.Column('exam_format', sa.String(20), nullable=True),
            sa.Column('room', sa.String(200), nullable=True),
            sa.Column('teachers_json', sa.Text(), nullable=False, server_default='[]'),
            sa.Column('booking_url', sa.String(500), nullable=True),
            sa.Column('booking_deadline', sa.Date(), nullable=True),
            sa.Column('notes', sa.Text(), nullable=True),
            sa.Column('status', sa.String(20), nullable=False, server_default='confirmed'),
            sa.Column('source', sa.String(20), nullable=False, server_default='manual'),
            sa.Column('source_ref', sa.String(500), nullable=True),
            sa.Column('created_by', sa.Integer(), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
            sa.Column('created_by_name', sa.String(200), nullable=True),
            sa.Column('updated_by_name', sa.String(200), nullable=True),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
            sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
            sa.CheckConstraint("kind IN ('lessons','session','exam','extraordinary','closure','event')", name='chk_calendar_kind'),
            sa.CheckConstraint("status IN ('confirmed','provisional','cancelled')", name='chk_calendar_status'))
        for col in ('university', 'department', 'course', 'subject_id', 'kind', 'starts_at', 'status'):
            op.create_index(f'ix_calendar_events_{col}', 'calendar_events', [col])
    if 'calendar_follows' not in tables:
        op.create_table('calendar_follows',
            sa.Column('id', sa.Integer(), primary_key=True),
            sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
            sa.Column('event_id', sa.Integer(), sa.ForeignKey('calendar_events.id', ondelete='CASCADE'), nullable=False),
            sa.Column('remind_days_json', sa.Text(), nullable=False, server_default='[7, 1]'),
            sa.Column('sent_days_json', sa.Text(), nullable=False, server_default='[]'),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
            sa.UniqueConstraint('user_id', 'event_id', name='uq_calendar_follow'))
        op.create_index('ix_calendar_follows_user_id', 'calendar_follows', ['user_id'])
        op.create_index('ix_calendar_follows_event_id', 'calendar_follows', ['event_id'])
    if 'calendar_settings' not in tables:
        op.create_table('calendar_settings',
            sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='CASCADE'), primary_key=True),
            sa.Column('remind_days_json', sa.Text(), nullable=False, server_default='[7, 1]'),
            sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')))


def downgrade():
    tables = set(sa.inspect(op.get_bind()).get_table_names())
    for table in ('calendar_settings', 'calendar_follows', 'calendar_events'):
        if table in tables:
            op.drop_table(table)
