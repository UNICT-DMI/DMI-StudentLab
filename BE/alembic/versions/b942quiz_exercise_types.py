"""Tipi di esercizio e flashcard.

Solo aggiunte, nessun dato esistente modificato:
- quiz_attempt_answers: question_type (default 'multiple_choice'), answer_payload,
  correct_payload, score. correct_option_id resta NOT NULL ('' per i nuovi tipi).
- quiz_assignments: question_types (NULL = solo risposta multipla, come prima),
  attempts_per_item, assigned_by_role ('teacher' | 'admin').
- study_plan_items: question_type (default 'multiple_choice'), correct_payload.
- nuova tabella flashcard_reviews (ripetizione dilazionata per studente).

I tentativi esistenti restano validi: valgono come 'multiple_choice'.

Revision ID: b942quiz_exercise_types
Revises: b941dictionary_sources
"""
from alembic import op
import sqlalchemy as sa

revision = 'b942quiz_exercise_types'
down_revision = 'b941dictionary_sources'
branch_labels = None
depends_on = None


def _columns(table: str) -> set[str]:
    return {c['name'] for c in sa.inspect(op.get_bind()).get_columns(table)}


def _tables() -> set[str]:
    return set(sa.inspect(op.get_bind()).get_table_names())


def upgrade():
    answers = _columns('quiz_attempt_answers')
    if 'question_type' not in answers:
        op.add_column('quiz_attempt_answers', sa.Column('question_type', sa.String(30), nullable=False,
                                                        server_default='multiple_choice'))
        op.create_index('ix_quiz_attempt_answers_question_type', 'quiz_attempt_answers', ['question_type'])
    if 'answer_payload' not in answers:
        op.add_column('quiz_attempt_answers', sa.Column('answer_payload', sa.JSON(), nullable=True))
    if 'correct_payload' not in answers:
        op.add_column('quiz_attempt_answers', sa.Column('correct_payload', sa.JSON(), nullable=True))
    if 'score' not in answers:
        op.add_column('quiz_attempt_answers', sa.Column('score', sa.Float(), nullable=True))

    assignments = _columns('quiz_assignments')
    if 'question_types' not in assignments:
        op.add_column('quiz_assignments', sa.Column('question_types', sa.JSON(), nullable=True))
    if 'attempts_per_item' not in assignments:
        op.add_column('quiz_assignments', sa.Column('attempts_per_item', sa.Integer(), nullable=True))
        op.create_check_constraint('chk_quiz_assignment_attempts_per_item', 'quiz_assignments',
                                   'attempts_per_item IS NULL OR attempts_per_item BETWEEN 1 AND 5')
    if 'assigned_by_role' not in assignments:
        op.add_column('quiz_assignments', sa.Column('assigned_by_role', sa.String(20), nullable=False,
                                                    server_default='teacher'))
        op.create_check_constraint('chk_quiz_assignment_assigned_by_role', 'quiz_assignments',
                                   "assigned_by_role IN ('teacher','admin')")

    if 'study_plan_items' in _tables():
        items = _columns('study_plan_items')
        if 'question_type' not in items:
            op.add_column('study_plan_items', sa.Column('question_type', sa.String(30), nullable=False,
                                                        server_default='multiple_choice'))
        if 'correct_payload' not in items:
            op.add_column('study_plan_items', sa.Column('correct_payload', sa.JSON(), nullable=True))

    if 'flashcard_reviews' not in _tables():
        op.create_table(
            'flashcard_reviews',
            sa.Column('id', sa.Integer(), primary_key=True),
            sa.Column('user_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
            sa.Column('department', sa.String(100), nullable=False),
            sa.Column('course', sa.String(100), nullable=False),
            sa.Column('subject', sa.String(255), nullable=False),
            sa.Column('card_id', sa.String(120), nullable=False),
            sa.Column('argument', sa.String(255), nullable=True),
            sa.Column('ease', sa.Float(), nullable=False, server_default='2.5'),
            sa.Column('interval_days', sa.Integer(), nullable=False, server_default='0'),
            sa.Column('due_at', sa.DateTime(timezone=True), nullable=True),
            sa.Column('reviews', sa.Integer(), nullable=False, server_default='0'),
            sa.Column('lapses', sa.Integer(), nullable=False, server_default='0'),
            sa.Column('last_grade', sa.SmallInteger(), nullable=True),
            sa.Column('last_reviewed_at', sa.DateTime(timezone=True), nullable=True),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
            sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
            sa.UniqueConstraint('user_id', 'department', 'course', 'subject', 'card_id',
                                name='uq_flashcard_review_card'),
        )
        op.create_index('ix_flashcard_reviews_id', 'flashcard_reviews', ['id'])
        op.create_index('ix_flashcard_reviews_user_id', 'flashcard_reviews', ['user_id'])
        op.create_index('ix_flashcard_reviews_due_at', 'flashcard_reviews', ['due_at'])


def downgrade():
    if 'flashcard_reviews' in _tables():
        op.drop_table('flashcard_reviews')
    if 'study_plan_items' in _tables():
        items = _columns('study_plan_items')
        for column in ('correct_payload', 'question_type'):
            if column in items:
                op.drop_column('study_plan_items', column)
    assignments = _columns('quiz_assignments')
    checks = {c.get('name') for c in sa.inspect(op.get_bind()).get_check_constraints('quiz_assignments')}
    for name in ('chk_quiz_assignment_assigned_by_role', 'chk_quiz_assignment_attempts_per_item'):
        if name in checks:
            op.drop_constraint(name, 'quiz_assignments', type_='check')
    for column in ('assigned_by_role', 'attempts_per_item', 'question_types'):
        if column in assignments:
            op.drop_column('quiz_assignments', column)
    answers = _columns('quiz_attempt_answers')
    indexes = {i.get('name') for i in sa.inspect(op.get_bind()).get_indexes('quiz_attempt_answers')}
    if 'ix_quiz_attempt_answers_question_type' in indexes:
        op.drop_index('ix_quiz_attempt_answers_question_type', table_name='quiz_attempt_answers')
    for column in ('score', 'correct_payload', 'answer_payload', 'question_type'):
        if column in answers:
            op.drop_column('quiz_attempt_answers', column)
