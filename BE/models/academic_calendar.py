"""Calendario accademico: periodi (lezioni, sessioni, chiusure), appelli ed
eventi per ateneo, dipartimento, corso e materia; chi li segue e i promemoria."""
from datetime import datetime, timezone

from sqlalchemy import (Boolean, CheckConstraint, Column, Date, DateTime, ForeignKey, Integer, String, Text,
                        UniqueConstraint, false)

from core.database import Base


def utc_now():
    return datetime.now(timezone.utc)


EVENT_KINDS = ('lessons', 'session', 'exam', 'extraordinary', 'closure', 'event')


class CalendarEvent(Base):
    __tablename__ = 'calendar_events'

    id = Column(Integer, primary_key=True, index=True)
    # Ambito: più è vuoto, più è ampio (ateneo > dipartimento > corso > materia).
    university = Column(String(255), nullable=True, index=True)
    department = Column(String(255), nullable=True, index=True)
    course = Column(String(255), nullable=True, index=True)
    subject_id = Column(Integer, ForeignKey('subjects.id', ondelete='CASCADE'), nullable=True, index=True)
    kind = Column(String(20), nullable=False, index=True)
    title = Column(String(200), nullable=False)
    starts_at = Column(DateTime(timezone=False), nullable=False, index=True)
    ends_at = Column(DateTime(timezone=False), nullable=True)
    all_day = Column(Boolean, nullable=False, default=False, server_default=false())
    exam_format = Column(String(20), nullable=True)
    room = Column(String(200), nullable=True)
    teachers_json = Column(Text, nullable=False, default='[]')
    booking_url = Column(String(500), nullable=True)
    booking_deadline = Column(Date, nullable=True)
    notes = Column(Text, nullable=True)
    status = Column(String(20), nullable=False, default='confirmed', server_default='confirmed', index=True)
    source = Column(String(20), nullable=False, default='manual', server_default='manual')
    source_ref = Column(String(500), nullable=True)
    curricula_json = Column(Text, nullable=True)
    created_by = Column(Integer, ForeignKey('users.id', ondelete='SET NULL'), nullable=True)
    created_by_name = Column(String(200), nullable=True)
    updated_by_name = Column(String(200), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=utc_now)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, onupdate=utc_now)

    __table_args__ = (
        CheckConstraint("kind IN ('lessons','session','exam','extraordinary','closure','event')", name='chk_calendar_kind'),
        CheckConstraint("status IN ('confirmed','provisional','cancelled')", name='chk_calendar_status'),
    )


class CalendarFollow(Base):
    """Appello o evento seguito: promemoria e avvisi di modifica."""
    __tablename__ = 'calendar_follows'

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    event_id = Column(Integer, ForeignKey('calendar_events.id', ondelete='CASCADE'), nullable=False, index=True)
    remind_days_json = Column(Text, nullable=False, default='[7, 1]')
    sent_days_json = Column(Text, nullable=False, default='[]')
    created_at = Column(DateTime(timezone=True), nullable=False, default=utc_now)

    __table_args__ = (UniqueConstraint('user_id', 'event_id', name='uq_calendar_follow'),)


class CalendarSettings(Base):
    """Promemoria predefiniti dello studente (standard: 7 e 1 giorno prima)."""
    __tablename__ = 'calendar_settings'

    user_id = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), primary_key=True)
    remind_days_json = Column(Text, nullable=False, default='[7, 1]')
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, onupdate=utc_now)
