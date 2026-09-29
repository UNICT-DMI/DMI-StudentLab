"""Domande degli studenti (FAQ universitaria): domande, risposte, voti e
racconti d'esame. Ogni domanda, risposta e racconto è moderato prima di
essere visibile agli altri."""
from datetime import datetime, timezone

from sqlalchemy import (Boolean, CheckConstraint, Column, Date, DateTime, ForeignKey, Integer,
                        String, Text, UniqueConstraint, false)

from core.database import Base


def utc_now():
    return datetime.now(timezone.utc)


FAQ_CATEGORIES = ('exams', 'topics', 'materials', 'study_plan', 'thesis', 'campus_life', 'other')
FAQ_STATUSES = ('pending', 'published', 'rejected', 'removed')


class FaqQuestion(Base):
    __tablename__ = 'faq_questions'

    id = Column(Integer, primary_key=True, index=True)
    author_user_id = Column(Integer, ForeignKey('users.id', ondelete='SET NULL'), nullable=True, index=True)
    # Contesto per i filtri (come nelle Dispense): ateneo, dipartimento, corso, materia.
    university = Column(String(255), nullable=True, index=True)
    department = Column(String(255), nullable=True, index=True)
    course = Column(String(255), nullable=True, index=True)
    subject_id = Column(Integer, ForeignKey('subjects.id', ondelete='SET NULL'), nullable=True, index=True)
    category = Column(String(30), nullable=False, default='other', server_default='other', index=True)
    title = Column(String(200), nullable=False)
    body = Column(Text, nullable=True)
    is_anonymous = Column(Boolean, nullable=False, default=True, server_default=false())
    author_label = Column(String(80), nullable=True)
    ask_teacher = Column(Boolean, nullable=False, default=False, server_default=false())
    status = Column(String(20), nullable=False, default='pending', server_default='pending', index=True)
    moderation_note = Column(Text, nullable=True)
    moderated_by = Column(Integer, ForeignKey('users.id', ondelete='SET NULL'), nullable=True)
    moderated_at = Column(DateTime(timezone=True), nullable=True)
    useful_count = Column(Integer, nullable=False, default=0, server_default='0')
    same_doubt_count = Column(Integer, nullable=False, default=0, server_default='0')
    answers_count = Column(Integer, nullable=False, default=0, server_default='0')
    accepted_answer_id = Column(Integer, nullable=True)
    has_verified_answer = Column(Boolean, nullable=False, default=False, server_default=false(), index=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, index=True)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, onupdate=utc_now)

    __table_args__ = (
        CheckConstraint("status IN ('pending','published','rejected','removed')", name='chk_faq_question_status'),
    )


class FaqAnswer(Base):
    __tablename__ = 'faq_answers'

    id = Column(Integer, primary_key=True, index=True)
    question_id = Column(Integer, ForeignKey('faq_questions.id', ondelete='CASCADE'), nullable=False, index=True)
    author_user_id = Column(Integer, ForeignKey('users.id', ondelete='SET NULL'), nullable=True, index=True)
    # Risposte degli ospiti: nome facoltativo e chiave del dispositivo (solo
    # l'hash) per mostrare all'ospite le sue risposte in attesa.
    guest_name = Column(String(60), nullable=True)
    guest_key_hash = Column(String(64), nullable=True, index=True)
    guest_ip_hash = Column(String(64), nullable=True, index=True)
    author_role = Column(String(20), nullable=False, default='student', server_default='student')
    body = Column(Text, nullable=False)
    # Materiale allegato: un file caricato o un materiale delle Dispense.
    public_material_id = Column(Integer, ForeignKey('public_materials.id', ondelete='SET NULL'), nullable=True)
    file_stored_name = Column(String(500), nullable=True)
    file_original_name = Column(String(255), nullable=True)
    file_mime_type = Column(String(120), nullable=True)
    file_size = Column(Integer, nullable=True)
    file_hash = Column(String(64), nullable=True)
    status = Column(String(20), nullable=False, default='pending', server_default='pending', index=True)
    moderation_note = Column(Text, nullable=True)
    moderated_by = Column(Integer, ForeignKey('users.id', ondelete='SET NULL'), nullable=True)
    moderated_at = Column(DateTime(timezone=True), nullable=True)
    is_verified = Column(Boolean, nullable=False, default=False, server_default=false())
    is_accepted = Column(Boolean, nullable=False, default=False, server_default=false())
    useful_count = Column(Integer, nullable=False, default=0, server_default='0')
    created_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, index=True)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, onupdate=utc_now)

    __table_args__ = (
        CheckConstraint("status IN ('pending','published','rejected','removed')", name='chk_faq_answer_status'),
    )


class FaqVote(Base):
    """Voti: 'useful' su domande e risposte, 'same_doubt' sulle domande."""
    __tablename__ = 'faq_votes'

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    target_type = Column(String(20), nullable=False)
    target_id = Column(Integer, nullable=False, index=True)
    kind = Column(String(20), nullable=False)
    created_at = Column(DateTime(timezone=True), nullable=False, default=utc_now)

    __table_args__ = (
        UniqueConstraint('user_id', 'target_type', 'target_id', 'kind', name='uq_faq_vote'),
        CheckConstraint("target_type IN ('question','answer')", name='chk_faq_vote_target'),
        CheckConstraint("kind IN ('useful','same_doubt')", name='chk_faq_vote_kind'),
    )


class FaqExamReport(Base):
    """Racconto di un appello già sostenuto (argomenti chiesti, formato, difficoltà)."""
    __tablename__ = 'faq_exam_reports'

    id = Column(Integer, primary_key=True, index=True)
    author_user_id = Column(Integer, ForeignKey('users.id', ondelete='SET NULL'), nullable=True, index=True)
    subject_id = Column(Integer, ForeignKey('subjects.id', ondelete='CASCADE'), nullable=False, index=True)
    exam_date = Column(Date, nullable=False)
    exam_format = Column(String(20), nullable=False)
    duration_minutes = Column(Integer, nullable=True)
    difficulty = Column(Integer, nullable=False)
    topics_json = Column(Text, nullable=False, default='[]')
    body = Column(Text, nullable=True)
    is_anonymous = Column(Boolean, nullable=False, default=True, server_default=false())
    author_label = Column(String(80), nullable=True)
    status = Column(String(20), nullable=False, default='pending', server_default='pending', index=True)
    moderation_note = Column(Text, nullable=True)
    moderated_by = Column(Integer, ForeignKey('users.id', ondelete='SET NULL'), nullable=True)
    moderated_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, index=True)

    __table_args__ = (
        CheckConstraint("status IN ('pending','published','rejected','removed')", name='chk_faq_report_status'),
        CheckConstraint("exam_format IN ('scritto','orale','scritto_orale','progetto')", name='chk_faq_report_format'),
        CheckConstraint('difficulty BETWEEN 1 AND 5', name='chk_faq_report_difficulty'),
    )
