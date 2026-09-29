"""Dizionario delle materie: argomenti, termini e una versione del contenuto
per ogni anno accademico (definizioni, esempi, esercizi, domande d'esame,
collegamenti). Chi scrive (admin o docente) resta registrato con nome e data
anche quando non insegna più la materia."""
from datetime import datetime, timezone

from sqlalchemy import CheckConstraint, Column, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint

from core.database import Base


def utc_now():
    return datetime.now(timezone.utc)


class DictionaryTopic(Base):
    __tablename__ = 'dictionary_topics'

    id = Column(Integer, primary_key=True, index=True)
    subject_id = Column(Integer, ForeignKey('subjects.id', ondelete='CASCADE'), nullable=False, index=True)
    slug = Column(String(120), nullable=False)
    title = Column(String(200), nullable=False)
    sort_order = Column(Integer, nullable=False, default=0, server_default='0')
    created_at = Column(DateTime(timezone=True), nullable=False, default=utc_now)

    __table_args__ = (UniqueConstraint('subject_id', 'slug', name='uq_dictionary_topic_slug'),)


class DictionaryEntry(Base):
    __tablename__ = 'dictionary_entries'

    id = Column(Integer, primary_key=True, index=True)
    subject_id = Column(Integer, ForeignKey('subjects.id', ondelete='CASCADE'), nullable=False, index=True)
    topic_id = Column(Integer, ForeignKey('dictionary_topics.id', ondelete='SET NULL'), nullable=True, index=True)
    slug = Column(String(120), nullable=False)
    term = Column(String(200), nullable=False, index=True)
    aliases_json = Column(Text, nullable=False, default='[]')
    created_at = Column(DateTime(timezone=True), nullable=False, default=utc_now)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, onupdate=utc_now)

    __table_args__ = (UniqueConstraint('subject_id', 'slug', name='uq_dictionary_entry_slug'),)


REVIEW_STATES = ('to_review', 'confirmed', 'same_as_previous', 'changed')


class DictionaryVersion(Base):
    __tablename__ = 'dictionary_versions'

    id = Column(Integer, primary_key=True, index=True)
    entry_id = Column(Integer, ForeignKey('dictionary_entries.id', ondelete='CASCADE'), nullable=False, index=True)
    academic_year = Column(String(9), nullable=False, index=True)
    formal_definition = Column(Text, nullable=True)
    informal_definition = Column(Text, nullable=True)
    examples_json = Column(Text, nullable=False, default='[]')
    exercises_json = Column(Text, nullable=False, default='[]')
    exam_questions_json = Column(Text, nullable=False, default='[]')
    related_json = Column(Text, nullable=False, default='[]')
    resources_json = Column(Text, nullable=False, default='[]')
    quiz_question_ids_json = Column(Text, nullable=False, default='[]')
    quiz_source = Column(String(500), nullable=True)
    teachers_json = Column(Text, nullable=False, default='[]')
    # Chi ha scritto: nome e ruolo salvati così come erano (restano anche dopo).
    author_user_id = Column(Integer, ForeignKey('users.id', ondelete='SET NULL'), nullable=True)
    author_name = Column(String(200), nullable=True)
    author_role = Column(String(20), nullable=False, default='admin', server_default='admin')
    assigned_teacher_user_id = Column(Integer, ForeignKey('users.id', ondelete='SET NULL'), nullable=True)
    assigned_teacher_name = Column(String(200), nullable=True)
    review_state = Column(String(20), nullable=False, default='to_review', server_default='to_review', index=True)
    # Provenienza della versione pubblicata (b941dictionary_sources).
    source_id = Column(Integer, ForeignKey('dictionary_sources.id', ondelete='SET NULL'), nullable=True)
    source_ref = Column(String(200), nullable=True)
    reviewed_by = Column(Integer, ForeignKey('users.id', ondelete='SET NULL'), nullable=True)
    reviewed_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=utc_now)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, onupdate=utc_now)

    __table_args__ = (
        UniqueConstraint('entry_id', 'academic_year', name='uq_dictionary_version_year'),
        CheckConstraint("review_state IN ('to_review','confirmed','same_as_previous','changed')",
                        name='chk_dictionary_review_state'),
        CheckConstraint("author_role IN ('admin','teacher','import')", name='chk_dictionary_author_role'),
    )


# ---------------------------------------------------------------------------
# Fonti e bozze da moderare (b941dictionary_sources)
# ---------------------------------------------------------------------------

SOURCE_KINDS = ('json', 'pdf', 'web', 'question_bank', 'local', 'text', 'manual')
SOURCE_STATUSES = ('new', 'read', 'unchanged', 'no_terms', 'error')
DRAFT_STATUSES = ('pending', 'approved', 'rejected')


class DictionarySource(Base):
    """Una fonte del Dizionario. PDF, pagine web e cartelle si leggono in
    locale con scripts/fonti_dizionario.py: al server arrivano solo i risultati
    (termini in JSON), i metadati, l'indirizzo e un estratto del testo letto.
    Il file originale non viene mai caricato né conservato."""
    __tablename__ = 'dictionary_sources'

    id = Column(Integer, primary_key=True, index=True)
    kind = Column(String(20), nullable=False, index=True)
    label = Column(String(300), nullable=False)
    location = Column(String(1000), nullable=True)
    subject_id = Column(Integer, ForeignKey('subjects.id', ondelete='CASCADE'), nullable=True, index=True)
    academic_year = Column(String(9), nullable=True)
    topic_title = Column(String(200), nullable=True)
    teacher_user_id = Column(Integer, ForeignKey('users.id', ondelete='SET NULL'), nullable=True)
    sha256 = Column(String(64), nullable=True)
    etag = Column(String(300), nullable=True)
    last_modified = Column(String(100), nullable=True)
    recheck = Column(String(10), nullable=False, default='none', server_default='none')
    selector = Column(String(200), nullable=True)
    status = Column(String(20), nullable=False, default='new', server_default='new', index=True)
    entries_found = Column(Integer, nullable=False, default=0, server_default='0')
    error = Column(Text, nullable=True)
    # Cosa mostra il registro: estratto del testo letto (max 20.000 caratteri)
    # e metadati (pagine, titolo, autore del PDF, tipo rilevato, script usato…).
    text_excerpt = Column(Text, nullable=True)
    metadata_json = Column(Text, nullable=False, default='{}')
    last_read_at = Column(DateTime(timezone=True), nullable=True)
    created_by = Column(Integer, ForeignKey('users.id', ondelete='SET NULL'), nullable=True)
    created_by_name = Column(String(200), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=utc_now)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, onupdate=utc_now)

    __table_args__ = (
        CheckConstraint("kind IN ('json','pdf','web','question_bank','local','text','manual')",
                        name='chk_dictionary_source_kind'),
        CheckConstraint("status IN ('new','read','unchanged','no_terms','error')", name='chk_dictionary_source_status'),
        CheckConstraint("recheck IN ('none','daily','weekly','monthly')", name='chk_dictionary_source_recheck'),
    )


class DictionaryDraft(Base):
    """Termine trovato in una fonte (o modifica proposta) in attesa di
    moderazione. Non è visibile agli studenti finché non viene approvato: solo
    allora diventa una DictionaryVersion confermata."""
    __tablename__ = 'dictionary_drafts'

    id = Column(Integer, primary_key=True, index=True)
    subject_id = Column(Integer, ForeignKey('subjects.id', ondelete='CASCADE'), nullable=False, index=True)
    source_id = Column(Integer, ForeignKey('dictionary_sources.id', ondelete='SET NULL'), nullable=True, index=True)
    target_entry_id = Column(Integer, ForeignKey('dictionary_entries.id', ondelete='SET NULL'), nullable=True, index=True)
    academic_year = Column(String(9), nullable=False)
    term = Column(String(200), nullable=False)
    slug = Column(String(120), nullable=False, index=True)
    aliases_json = Column(Text, nullable=False, default='[]')
    topic_id = Column(Integer, ForeignKey('dictionary_topics.id', ondelete='SET NULL'), nullable=True)
    topic_title = Column(String(200), nullable=True)
    content_json = Column(Text, nullable=False, default='{}')
    content_hash = Column(String(64), nullable=False, index=True)
    teachers_json = Column(Text, nullable=False, default='[]')
    assigned_teacher_user_id = Column(Integer, ForeignKey('users.id', ondelete='SET NULL'), nullable=True)
    assigned_teacher_name = Column(String(200), nullable=True)
    quiz_source = Column(String(500), nullable=True)
    source_ref = Column(String(200), nullable=True)
    source_excerpt = Column(Text, nullable=True)
    status = Column(String(20), nullable=False, default='pending', server_default='pending', index=True)
    author_user_id = Column(Integer, ForeignKey('users.id', ondelete='SET NULL'), nullable=True)
    author_name = Column(String(200), nullable=True)
    author_role = Column(String(20), nullable=False, default='import', server_default='import')
    reviewed_by = Column(Integer, ForeignKey('users.id', ondelete='SET NULL'), nullable=True)
    reviewed_by_name = Column(String(200), nullable=True)
    reviewed_at = Column(DateTime(timezone=True), nullable=True)
    review_note = Column(Text, nullable=True)
    published_version_id = Column(Integer, ForeignKey('dictionary_versions.id', ondelete='SET NULL'), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, index=True)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, onupdate=utc_now)

    __table_args__ = (
        CheckConstraint("status IN ('pending','approved','rejected')", name='chk_dictionary_draft_status'),
        CheckConstraint("author_role IN ('admin','teacher','import')", name='chk_dictionary_draft_author_role'),
    )
