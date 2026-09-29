from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, SmallInteger, String, UniqueConstraint

from core.database import Base


def utc_now():
    return datetime.now(timezone.utc)


class FlashcardReview(Base):
    """Stato della ripetizione dilazionata di una flashcard per uno studente (v18)."""
    __tablename__ = "flashcard_reviews"
    __table_args__ = (
        UniqueConstraint("user_id", "department", "course", "subject", "card_id", name="uq_flashcard_review_card"),
    )

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    department = Column(String(100), nullable=False)
    course = Column(String(100), nullable=False)
    subject = Column(String(255), nullable=False)
    card_id = Column(String(120), nullable=False)
    argument = Column(String(255), nullable=True)
    ease = Column(Float, nullable=False, default=2.5, server_default="2.5")
    interval_days = Column(Integer, nullable=False, default=0, server_default="0")
    due_at = Column(DateTime(timezone=True), nullable=True, index=True)
    reviews = Column(Integer, nullable=False, default=0, server_default="0")
    lapses = Column(Integer, nullable=False, default=0, server_default="0")
    last_grade = Column(SmallInteger, nullable=True)
    last_reviewed_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=utc_now)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, onupdate=utc_now)
