from datetime import datetime, timezone

from sqlalchemy import CheckConstraint, Column, DateTime, ForeignKey, Integer, JSON, String, Text

from core.database import Base


def utc_now():
    return datetime.now(timezone.utc)


class QuestionModerationItem(Base):
    __tablename__ = "question_moderation_items"
    __table_args__ = (
        CheckConstraint("source_type IN ('proposal','report')", name="chk_question_moderation_source_type"),
        CheckConstraint("status IN ('pending','under_review','approved','rejected')", name="chk_question_moderation_status"),
    )

    id = Column(Integer, primary_key=True, index=True)
    source_type = Column(String(20), nullable=False, index=True)
    department = Column(String(100), nullable=False, index=True)
    course = Column(String(100), nullable=False, index=True)
    subject = Column(String(255), nullable=False, index=True)
    question_id = Column(String(100), nullable=True, index=True)
    proposed_question_payload = Column(JSON, nullable=True)
    report_reason = Column(String(60), nullable=True, index=True)
    report_message = Column(Text, nullable=True)
    created_by = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    status = Column(String(30), nullable=False, default="pending", server_default="pending", index=True)
    reviewed_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    reviewer_role = Column(String(30), nullable=True)
    resolution_note = Column(Text, nullable=True)
    review_started_at = Column(DateTime(timezone=True), nullable=True)
    reviewed_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=utc_now)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, onupdate=utc_now)
