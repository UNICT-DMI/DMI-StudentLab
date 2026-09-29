from datetime import date, datetime, timezone

from sqlalchemy import Column, Date, DateTime, Integer, String, Text

from core.database import Base


def utc_now():
    return datetime.now(timezone.utc)


class DmiExternalNotice(Base):
    __tablename__ = "dmi_external_notices"

    id = Column(Integer, primary_key=True)
    external_id = Column(String(64), nullable=False, unique=True, index=True)
    source_kind = Column(String(16), nullable=False)
    university = Column(String(255), nullable=False, default="Università di Catania")
    department = Column(String(255), nullable=True)
    course = Column(String(255), nullable=True)
    title = Column(String(160), nullable=False)
    content = Column(Text, nullable=False)
    teacher = Column(String(255), nullable=True)
    category = Column(String(40), nullable=False, default="altro")
    published_on = Column(Date, nullable=False, index=True)
    original_url = Column(Text, nullable=False)
    source_url = Column(Text, nullable=True)
    content_hash = Column(String(64), nullable=False)
    created_at = Column(DateTime(timezone=True), nullable=False, default=utc_now)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, onupdate=utc_now)
    last_seen_at = Column(DateTime(timezone=True), nullable=False, default=utc_now)
