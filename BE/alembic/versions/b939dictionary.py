"""Dizionario delle materie: argomenti, termini, versioni per anno accademico.
Solo tabelle nuove.

Revision ID: b939dictionary
Revises: b938faq
"""
from alembic import op
import sqlalchemy as sa

revision = 'b939dictionary'
down_revision = 'b938faq'
branch_labels = None
depends_on = None


def upgrade():
    tables = set(sa.inspect(op.get_bind()).get_table_names())
    if 'dictionary_topics' not in tables:
        op.create_table('dictionary_topics',
            sa.Column('id', sa.Integer(), primary_key=True),
            sa.Column('subject_id', sa.Integer(), sa.ForeignKey('subjects.id', ondelete='CASCADE'), nullable=False),
            sa.Column('slug', sa.String(120), nullable=False),
            sa.Column('title', sa.String(200), nullable=False),
            sa.Column('sort_order', sa.Integer(), nullable=False, server_default='0'),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
            sa.UniqueConstraint('subject_id', 'slug', name='uq_dictionary_topic_slug'))
        op.create_index('ix_dictionary_topics_subject_id', 'dictionary_topics', ['subject_id'])
    if 'dictionary_entries' not in tables:
        op.create_table('dictionary_entries',
            sa.Column('id', sa.Integer(), primary_key=True),
            sa.Column('subject_id', sa.Integer(), sa.ForeignKey('subjects.id', ondelete='CASCADE'), nullable=False),
            sa.Column('topic_id', sa.Integer(), sa.ForeignKey('dictionary_topics.id', ondelete='SET NULL'), nullable=True),
            sa.Column('slug', sa.String(120), nullable=False),
            sa.Column('term', sa.String(200), nullable=False),
            sa.Column('aliases_json', sa.Text(), nullable=False, server_default='[]'),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
            sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
            sa.UniqueConstraint('subject_id', 'slug', name='uq_dictionary_entry_slug'))
        for col in ('subject_id', 'topic_id', 'term'):
            op.create_index(f'ix_dictionary_entries_{col}', 'dictionary_entries', [col])
    if 'dictionary_versions' not in tables:
        op.create_table('dictionary_versions',
            sa.Column('id', sa.Integer(), primary_key=True),
            sa.Column('entry_id', sa.Integer(), sa.ForeignKey('dictionary_entries.id', ondelete='CASCADE'), nullable=False),
            sa.Column('academic_year', sa.String(9), nullable=False),
            sa.Column('formal_definition', sa.Text(), nullable=True),
            sa.Column('informal_definition', sa.Text(), nullable=True),
            sa.Column('examples_json', sa.Text(), nullable=False, server_default='[]'),
            sa.Column('exercises_json', sa.Text(), nullable=False, server_default='[]'),
            sa.Column('exam_questions_json', sa.Text(), nullable=False, server_default='[]'),
            sa.Column('related_json', sa.Text(), nullable=False, server_default='[]'),
            sa.Column('resources_json', sa.Text(), nullable=False, server_default='[]'),
            sa.Column('quiz_question_ids_json', sa.Text(), nullable=False, server_default='[]'),
            sa.Column('quiz_source', sa.String(500), nullable=True),
            sa.Column('teachers_json', sa.Text(), nullable=False, server_default='[]'),
            sa.Column('author_user_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
            sa.Column('author_name', sa.String(200), nullable=True),
            sa.Column('author_role', sa.String(20), nullable=False, server_default='admin'),
            sa.Column('assigned_teacher_user_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
            sa.Column('assigned_teacher_name', sa.String(200), nullable=True),
            sa.Column('review_state', sa.String(20), nullable=False, server_default='to_review'),
            sa.Column('reviewed_by', sa.Integer(), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
            sa.Column('reviewed_at', sa.DateTime(timezone=True), nullable=True),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
            sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
            sa.UniqueConstraint('entry_id', 'academic_year', name='uq_dictionary_version_year'),
            sa.CheckConstraint("review_state IN ('to_review','confirmed','same_as_previous','changed')",
                               name='chk_dictionary_review_state'),
            sa.CheckConstraint("author_role IN ('admin','teacher','import')", name='chk_dictionary_author_role'))
        for col in ('entry_id', 'academic_year', 'review_state'):
            op.create_index(f'ix_dictionary_versions_{col}', 'dictionary_versions', [col])


def downgrade():
    tables = set(sa.inspect(op.get_bind()).get_table_names())
    for table in ('dictionary_versions', 'dictionary_entries', 'dictionary_topics'):
        if table in tables:
            op.drop_table(table)
