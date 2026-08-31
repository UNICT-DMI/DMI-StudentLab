from datetime import datetime, timezone

from sqlalchemy import Boolean, CheckConstraint, Column, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from core.database import Base


def utc_now():
    return datetime.now(timezone.utc)


class PublicNews(Base):
    __tablename__ = "public_news"

    id = Column(Integer, primary_key=True, index=True)
    author_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    subject_id = Column(Integer, ForeignKey("subjects.id", ondelete="SET NULL"), nullable=True, index=True)
    target_type = Column(String(30), nullable=False, index=True)
    title = Column(String(160), nullable=False)
    content = Column(Text, nullable=False)
    city = Column(String(160), nullable=True, index=True)
    university = Column(String(255), nullable=True, index=True)
    university_code = Column(String(100), nullable=True, index=True)
    department = Column(String(255), nullable=True, index=True)
    department_code = Column(String(100), nullable=True, index=True)
    course = Column(String(255), nullable=True, index=True)
    course_code = Column(String(100), nullable=True, index=True)
    subject_name = Column(String(255), nullable=True)
    status = Column(String(40), nullable=False, default="active", index=True)
    deleted_by_user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    deleted_at = Column(DateTime(timezone=True), nullable=True)
    moderated_by_user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    moderated_at = Column(DateTime(timezone=True), nullable=True)
    moderation_reason = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, index=True)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, onupdate=utc_now)

    author = relationship("User", foreign_keys=[author_user_id])
    subject = relationship("Subject", foreign_keys=[subject_id])
    deleted_by = relationship("User", foreign_keys=[deleted_by_user_id])
    moderated_by = relationship("User", foreign_keys=[moderated_by_user_id])

    __table_args__ = (
        CheckConstraint(
            "target_type IN ('all', 'university', 'department', 'course', 'subject')",
            name="chk_public_news_target_type",
        ),
        CheckConstraint(
            "status IN ('active', 'deleted_by_author', 'removed_by_platform_moderator')",
            name="chk_public_news_status",
        ),
        CheckConstraint(
            "length(trim(title)) > 0",
            name="chk_public_news_title",
        ),
        CheckConstraint(
            "length(trim(content)) > 0",
            name="chk_public_news_content",
        ),
        CheckConstraint(
            "(target_type != 'subject') OR (subject_id IS NOT NULL)",
            name="chk_public_news_subject_target",
        ),
    )
