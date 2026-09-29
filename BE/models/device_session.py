from datetime import datetime, timezone

from sqlalchemy import Boolean, CheckConstraint, Column, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from core.database import Base


def utc_now():
    return datetime.now(timezone.utc)


class DeviceSession(Base):
    __tablename__ = "device_sessions"
    __table_args__ = (
        CheckConstraint("source_type IN ('guest','authenticated')", name="chk_device_session_source_type"),
    )

    id = Column(Integer, primary_key=True, index=True)
    session_uuid = Column(String(64), nullable=False, unique=True, index=True)
    device_id = Column(String(64), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    device_label = Column(String(100), nullable=True)
    source_type = Column(String(20), nullable=False, default="authenticated", index=True)
    contribution_enabled = Column(Boolean, nullable=False, default=True, index=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=utc_now)
    last_activity_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, index=True)
    associated_at = Column(DateTime(timezone=True), nullable=False, default=utc_now)
    dissociated_at = Column(DateTime(timezone=True), nullable=True, index=True)

    contributions = relationship(
        "StudyPlanContribution",
        back_populates="device_session",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
