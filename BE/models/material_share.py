
from datetime import datetime, timezone

from sqlalchemy import BigInteger, CheckConstraint, Column, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from core.database import Base


def utc_now():
    return datetime.now(timezone.utc)


class MaterialShare(Base):
    __tablename__ = "material_shares"

    id = Column(Integer, primary_key=True, index=True)
    sender_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    recipient_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    subject_id = Column(Integer, ForeignKey("subjects.id", ondelete="SET NULL"), nullable=True, index=True)
    original_name = Column(String(255), nullable=False)
    stored_name = Column(String(700), nullable=False, index=True)
    mime_type = Column(String(255), nullable=False)
    size = Column(BigInteger, nullable=False)
    file_hash = Column(String(64), nullable=False, index=True)
    message = Column(Text, nullable=True)
    status = Column(String(30), nullable=False, default="pending", server_default="pending", index=True)
    cloud_expires_at = Column(DateTime(timezone=True), nullable=False, index=True)
    accepted_at = Column(DateTime(timezone=True), nullable=True)
    delivered_at = Column(DateTime(timezone=True), nullable=True)
    rejected_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, index=True)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, onupdate=utc_now, index=True)

    sender = relationship("User", foreign_keys=[sender_user_id])
    recipient = relationship("User", foreign_keys=[recipient_user_id])
    subject = relationship("Subject")

    __table_args__ = (
        CheckConstraint("status IN ('pending','accepted','delivered','rejected','expired')", name="chk_material_share_status"),
        CheckConstraint("size > 0", name="chk_material_share_size"),
        CheckConstraint("sender_user_id != recipient_user_id", name="chk_material_share_different_users"),
    )
