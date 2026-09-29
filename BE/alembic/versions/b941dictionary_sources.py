"""Dizionario: registro delle fonti e bozze da moderare.

Solo aggiunte, nessun dato esistente modificato:
- tabella dictionary_sources (registro: metadati, indirizzo, estratto del testo);
- tabella dictionary_drafts (termini trovati o modifiche proposte, da moderare);
- dictionary_versions.source_id e dictionary_versions.source_ref (nulle).

I PDF e le pagine web si leggono in locale (scripts/fonti_dizionario.py):
al server arrivano solo i risultati in JSON, mai i file.

Revision ID: b941dictionary_sources
Revises: b940calendar
"""
from alembic import op
import sqlalchemy as sa

revision = 'b941dictionary_sources'
down_revision = 'b940calendar'
branch_labels = None
depends_on = None


def _inspector():
    return sa.inspect(op.get_bind())


def upgrade():
    inspector = _inspector()
    tables = set(inspector.get_table_names())

    if 'dictionary_sources' not in tables:
        op.create_table(
            'dictionary_sources',
            sa.Column('id', sa.Integer(), primary_key=True),
            sa.Column('kind', sa.String(20), nullable=False),
            sa.Column('label', sa.String(300), nullable=False),
            sa.Column('location', sa.String(1000), nullable=True),
            sa.Column('subject_id', sa.Integer(), sa.ForeignKey('subjects.id', ondelete='CASCADE'), nullable=True),
            sa.Column('academic_year', sa.String(9), nullable=True),
            sa.Column('topic_title', sa.String(200), nullable=True),
            sa.Column('teacher_user_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
            sa.Column('sha256', sa.String(64), nullable=True),
            sa.Column('etag', sa.String(300), nullable=True),
            sa.Column('last_modified', sa.String(100), nullable=True),
            sa.Column('recheck', sa.String(10), nullable=False, server_default='none'),
            sa.Column('selector', sa.String(200), nullable=True),
            sa.Column('status', sa.String(20), nullable=False, server_default='new'),
            sa.Column('entries_found', sa.Integer(), nullable=False, server_default='0'),
            sa.Column('error', sa.Text(), nullable=True),
            sa.Column('text_excerpt', sa.Text(), nullable=True),
            sa.Column('metadata_json', sa.Text(), nullable=False, server_default='{}'),
            sa.Column('last_read_at', sa.DateTime(timezone=True), nullable=True),
            sa.Column('created_by', sa.Integer(), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
            sa.Column('created_by_name', sa.String(200), nullable=True),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
            sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
            sa.CheckConstraint("kind IN ('json','pdf','web','question_bank','local','text','manual')",
                               name='chk_dictionary_source_kind'),
            sa.CheckConstraint("status IN ('new','read','unchanged','no_terms','error')",
                               name='chk_dictionary_source_status'),
            sa.CheckConstraint("recheck IN ('none','daily','weekly','monthly')",
                               name='chk_dictionary_source_recheck'),
        )
        for column in ('id', 'kind', 'subject_id', 'status'):
            op.create_index(f'ix_dictionary_sources_{column}', 'dictionary_sources', [column])

    if 'dictionary_drafts' not in tables:
        op.create_table(
            'dictionary_drafts',
            sa.Column('id', sa.Integer(), primary_key=True),
            sa.Column('subject_id', sa.Integer(), sa.ForeignKey('subjects.id', ondelete='CASCADE'), nullable=False),
            sa.Column('source_id', sa.Integer(), sa.ForeignKey('dictionary_sources.id', ondelete='SET NULL'), nullable=True),
            sa.Column('target_entry_id', sa.Integer(), sa.ForeignKey('dictionary_entries.id', ondelete='SET NULL'),
                      nullable=True),
            sa.Column('academic_year', sa.String(9), nullable=False),
            sa.Column('term', sa.String(200), nullable=False),
            sa.Column('slug', sa.String(120), nullable=False),
            sa.Column('aliases_json', sa.Text(), nullable=False, server_default='[]'),
            sa.Column('topic_id', sa.Integer(), sa.ForeignKey('dictionary_topics.id', ondelete='SET NULL'), nullable=True),
            sa.Column('topic_title', sa.String(200), nullable=True),
            sa.Column('content_json', sa.Text(), nullable=False, server_default='{}'),
            sa.Column('content_hash', sa.String(64), nullable=False),
            sa.Column('teachers_json', sa.Text(), nullable=False, server_default='[]'),
            sa.Column('assigned_teacher_user_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='SET NULL'),
                      nullable=True),
            sa.Column('assigned_teacher_name', sa.String(200), nullable=True),
            sa.Column('quiz_source', sa.String(500), nullable=True),
            sa.Column('source_ref', sa.String(200), nullable=True),
            sa.Column('source_excerpt', sa.Text(), nullable=True),
            sa.Column('status', sa.String(20), nullable=False, server_default='pending'),
            sa.Column('author_user_id', sa.Integer(), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
            sa.Column('author_name', sa.String(200), nullable=True),
            sa.Column('author_role', sa.String(20), nullable=False, server_default='import'),
            sa.Column('reviewed_by', sa.Integer(), sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
            sa.Column('reviewed_by_name', sa.String(200), nullable=True),
            sa.Column('reviewed_at', sa.DateTime(timezone=True), nullable=True),
            sa.Column('review_note', sa.Text(), nullable=True),
            sa.Column('published_version_id', sa.Integer(),
                      sa.ForeignKey('dictionary_versions.id', ondelete='SET NULL'), nullable=True),
            sa.Column('created_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
            sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False, server_default=sa.text('now()')),
            sa.CheckConstraint("status IN ('pending','approved','rejected')", name='chk_dictionary_draft_status'),
            sa.CheckConstraint("author_role IN ('admin','teacher','import')", name='chk_dictionary_draft_author_role'),
        )
        for column in ('id', 'subject_id', 'source_id', 'target_entry_id', 'slug', 'content_hash', 'status',
                       'created_at'):
            op.create_index(f'ix_dictionary_drafts_{column}', 'dictionary_drafts', [column])

    version_columns = {c['name'] for c in _inspector().get_columns('dictionary_versions')}
    if 'source_id' not in version_columns:
        op.add_column('dictionary_versions', sa.Column('source_id', sa.Integer(), nullable=True))
        op.create_foreign_key('fk_dictionary_versions_source_id', 'dictionary_versions', 'dictionary_sources',
                              ['source_id'], ['id'], ondelete='SET NULL')
    if 'source_ref' not in version_columns:
        op.add_column('dictionary_versions', sa.Column('source_ref', sa.String(200), nullable=True))


def downgrade():
    inspector = _inspector()
    version_columns = {c['name'] for c in inspector.get_columns('dictionary_versions')}
    if 'source_ref' in version_columns:
        op.drop_column('dictionary_versions', 'source_ref')
    if 'source_id' in version_columns:
        foreign_keys = {fk.get('name') for fk in inspector.get_foreign_keys('dictionary_versions')}
        if 'fk_dictionary_versions_source_id' in foreign_keys:
            op.drop_constraint('fk_dictionary_versions_source_id', 'dictionary_versions', type_='foreignkey')
        op.drop_column('dictionary_versions', 'source_id')
    tables = set(inspector.get_table_names())
    if 'dictionary_drafts' in tables:
        op.drop_table('dictionary_drafts')
    if 'dictionary_sources' in tables:
        op.drop_table('dictionary_sources')
