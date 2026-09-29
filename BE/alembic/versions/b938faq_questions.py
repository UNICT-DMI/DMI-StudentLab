"""Domande degli studenti: domande, risposte (anche di ospiti), voti,
racconti d'esame. Solo tabelle nuove.

Revision ID: b938faq
Revises: b937teacherprivateshare
"""
from alembic import op
import sqlalchemy as sa

revision = 'b938faq'
down_revision = 'b937teacherprivateshare'
branch_labels = None
depends_on = None


def _tables():
    return set(sa.inspect(op.get_bind()).get_table_names())


def upgrade():
    tables = _tables()
    if 'faq_questions' not in tables:
        op.create_table('faq_questions',
            sa.Column('id', sa.Integer(), primary_key=True),
            sa.Column('author_user_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
            sa.Column('university', sa.String(255), nullable=True),
            sa.Column('department', sa.String(255), nullable=True),
            sa.Column('course', sa.String(255), nullable=True),
            sa.Column('subject_id', sa.Integer(), sa.ForeignKey('subjects.id', ondelete='SET NULL'), nullable=True),
            sa.Column('category', sa.String(30), nullable=False, server_default='other'),
            sa.Column('title', sa.String(200), nullable=False),
            sa.Column('body', sa.Text(), nullable=True),
            sa.Column('is_anonymous', sa.Boolean(), nullable=False, server_default=sa.false()),
            sa.Column('author_label', sa.String(80), nullable=True),
            sa.Column('ask_teacher', sa.Boolean(), nullable=False, server_default=sa.false()),
            sa.Column('status', sa.String(20), nullable=False, server_default='pending'),
            sa.Column('moderation_note', sa.Text(), nullable=True),
            sa.Column('moderated_by', sa.Integer(), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
            sa.Column('moderated_at', sa.DateTime(timezone=True), nullable=True),
            sa.Column('useful_count', sa.Integer(), nullable=False, server_default='0'),
            sa.Column('same_doubt_count', sa.Integer(), nullable=False, server_default='0'),
            sa.Column('answers_count', sa.Integer(), nullable=False, server_default='0'),
            sa.Column('accepted_answer_id', sa.Integer(), nullable=True),
            sa.Column('has_verified_answer', sa.Boolean(), nullable=False, server_default=sa.false()),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
            sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
            sa.CheckConstraint("status IN ('pending','published','rejected','removed')", name='chk_faq_question_status'),
        )
        for col in ('author_user_id', 'university', 'department', 'course', 'subject_id', 'category',
                    'status', 'has_verified_answer', 'created_at'):
            op.create_index(f'ix_faq_questions_{col}', 'faq_questions', [col])
    if 'faq_answers' not in tables:
        op.create_table('faq_answers',
            sa.Column('id', sa.Integer(), primary_key=True),
            sa.Column('question_id', sa.Integer(), sa.ForeignKey('faq_questions.id', ondelete='CASCADE'), nullable=False),
            sa.Column('author_user_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
            sa.Column('guest_name', sa.String(60), nullable=True),
            sa.Column('guest_key_hash', sa.String(64), nullable=True),
            sa.Column('guest_ip_hash', sa.String(64), nullable=True),
            sa.Column('author_role', sa.String(20), nullable=False, server_default='student'),
            sa.Column('body', sa.Text(), nullable=False),
            sa.Column('public_material_id', sa.Integer(), sa.ForeignKey('public_materials.id', ondelete='SET NULL'), nullable=True),
            sa.Column('file_stored_name', sa.String(500), nullable=True),
            sa.Column('file_original_name', sa.String(255), nullable=True),
            sa.Column('file_mime_type', sa.String(120), nullable=True),
            sa.Column('file_size', sa.Integer(), nullable=True),
            sa.Column('file_hash', sa.String(64), nullable=True),
            sa.Column('status', sa.String(20), nullable=False, server_default='pending'),
            sa.Column('moderation_note', sa.Text(), nullable=True),
            sa.Column('moderated_by', sa.Integer(), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
            sa.Column('moderated_at', sa.DateTime(timezone=True), nullable=True),
            sa.Column('is_verified', sa.Boolean(), nullable=False, server_default=sa.false()),
            sa.Column('is_accepted', sa.Boolean(), nullable=False, server_default=sa.false()),
            sa.Column('useful_count', sa.Integer(), nullable=False, server_default='0'),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
            sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
            sa.CheckConstraint("status IN ('pending','published','rejected','removed')", name='chk_faq_answer_status'),
        )
        for col in ('question_id', 'author_user_id', 'guest_key_hash', 'guest_ip_hash', 'status', 'created_at'):
            op.create_index(f'ix_faq_answers_{col}', 'faq_answers', [col])
    if 'faq_votes' not in tables:
        op.create_table('faq_votes',
            sa.Column('id', sa.Integer(), primary_key=True),
            sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
            sa.Column('target_type', sa.String(20), nullable=False),
            sa.Column('target_id', sa.Integer(), nullable=False),
            sa.Column('kind', sa.String(20), nullable=False),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
            sa.UniqueConstraint('user_id', 'target_type', 'target_id', 'kind', name='uq_faq_vote'),
            sa.CheckConstraint("target_type IN ('question','answer')", name='chk_faq_vote_target'),
            sa.CheckConstraint("kind IN ('useful','same_doubt')", name='chk_faq_vote_kind'),
        )
        op.create_index('ix_faq_votes_user_id', 'faq_votes', ['user_id'])
        op.create_index('ix_faq_votes_target_id', 'faq_votes', ['target_id'])
    if 'faq_exam_reports' not in tables:
        op.create_table('faq_exam_reports',
            sa.Column('id', sa.Integer(), primary_key=True),
            sa.Column('author_user_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
            sa.Column('subject_id', sa.Integer(), sa.ForeignKey('subjects.id', ondelete='CASCADE'), nullable=False),
            sa.Column('exam_date', sa.Date(), nullable=False),
            sa.Column('exam_format', sa.String(20), nullable=False),
            sa.Column('duration_minutes', sa.Integer(), nullable=True),
            sa.Column('difficulty', sa.Integer(), nullable=False),
            sa.Column('topics_json', sa.Text(), nullable=False, server_default='[]'),
            sa.Column('body', sa.Text(), nullable=True),
            sa.Column('is_anonymous', sa.Boolean(), nullable=False, server_default=sa.false()),
            sa.Column('author_label', sa.String(80), nullable=True),
            sa.Column('status', sa.String(20), nullable=False, server_default='pending'),
            sa.Column('moderation_note', sa.Text(), nullable=True),
            sa.Column('moderated_by', sa.Integer(), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
            sa.Column('moderated_at', sa.DateTime(timezone=True), nullable=True),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
            sa.CheckConstraint("status IN ('pending','published','rejected','removed')", name='chk_faq_report_status'),
            sa.CheckConstraint("exam_format IN ('scritto','orale','scritto_orale','progetto')", name='chk_faq_report_format'),
            sa.CheckConstraint('difficulty BETWEEN 1 AND 5', name='chk_faq_report_difficulty'),
        )
        for col in ('author_user_id', 'subject_id', 'status', 'created_at'):
            op.create_index(f'ix_faq_exam_reports_{col}', 'faq_exam_reports', [col])


def downgrade():
    tables = _tables()
    for table in ('faq_exam_reports', 'faq_votes', 'faq_answers', 'faq_questions'):
        if table in tables:
            op.drop_table(table)
