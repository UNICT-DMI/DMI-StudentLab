from datetime import datetime, timezone

from sqlalchemy import CheckConstraint, Column, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from core.database import Base


def utc_now():
    return datetime.now(timezone.utc)


class StudentMaterialRequest(Base):
    __tablename__ = "student_material_requests"

    id = Column(Integer, primary_key=True, index=True)
    requester_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    recipient_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    subject_id = Column(Integer, ForeignKey("subjects.id", ondelete="SET NULL"), nullable=True, index=True)
    topic = Column(String(255), nullable=True)
    message = Column(Text, nullable=False)
    status = Column(String(30), nullable=False, default="pending", server_default="pending", index=True)
    fulfilled_share_id = Column(Integer, ForeignKey("material_shares.id", ondelete="SET NULL"), nullable=True, index=True)
    resolved_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, index=True)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, onupdate=utc_now, index=True)

    requester = relationship("User", foreign_keys=[requester_user_id])
    recipient = relationship("User", foreign_keys=[recipient_user_id])
    subject = relationship("Subject")
    fulfilled_share = relationship("MaterialShare")

    @property
    def subject_name(self):
        return self.subject.name if self.subject else None

    @property
    def recipient_name(self):
        return f"{self.recipient.first_name} {self.recipient.last_name}".strip() if self.recipient else None

    @property
    def requester_name(self):
        return f"{self.requester.first_name} {self.requester.last_name}".strip() if self.requester else None

    __table_args__ = (
        CheckConstraint("requester_user_id != recipient_user_id", name="chk_student_material_request_different_users"),
        CheckConstraint("status IN ('pending','fulfilled','declined','cancelled')", name="chk_student_material_request_status"),
    )
