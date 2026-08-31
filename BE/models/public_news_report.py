from datetime import datetime, timezone

from sqlalchemy import CheckConstraint, Column, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import relationship

from core.database import Base


def utc_now():
    return datetime.now(timezone.utc)


class PublicNewsReport(Base):
    __tablename__ = "public_news_reports"

    id = Column(Integer, primary_key=True, index=True)
    news_id = Column(Integer, ForeignKey("public_news.id", ondelete="CASCADE"), nullable=False, index=True)
    reporter_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    reported_author_user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    reason = Column(String(100), nullable=False, index=True)
    description = Column(Text, nullable=True)
    status = Column(String(30), nullable=False, default="pending", index=True)
    moderation_action = Column(String(40), nullable=False, default="none")
    moderation_note = Column(Text, nullable=True)
    reviewed_by_user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    reviewed_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, index=True)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, onupdate=utc_now)

    news = relationship("PublicNews", foreign_keys=[news_id])
    reporter = relationship("User", foreign_keys=[reporter_user_id])
    reported_author = relationship("User", foreign_keys=[reported_author_user_id])
    reviewer = relationship("User", foreign_keys=[reviewed_by_user_id])

    __table_args__ = (
        UniqueConstraint("news_id", "reporter_user_id", name="uq_public_news_report_user"),
        CheckConstraint(
            "reason IN ('spam', 'harassment', 'hate', 'privacy', 'illegal_content', 'other')",
            name="chk_public_news_report_reason",
        ),
        CheckConstraint(
            "status IN ('pending', 'under_review', 'resolved', 'dismissed')",
            name="chk_public_news_report_status",
        ),
        CheckConstraint(
            "moderation_action IN ('none', 'hide_news', 'remove_news', 'warn_user', 'suspend_user', 'deactivate_user')",
            name="chk_public_news_report_action",
        ),
    )
