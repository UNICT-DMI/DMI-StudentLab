
from datetime import datetime, timezone

from sqlalchemy import BigInteger, Boolean, CheckConstraint, Column, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import relationship

from core.database import Base


def utc_now():
    return datetime.now(timezone.utc)


class PersonalSyncedMaterial(Base):
    __tablename__ = "personal_synced_materials"

    id = Column(Integer, primary_key=True, index=True)
    owner_user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    subject_id = Column(Integer, ForeignKey("subjects.id", ondelete="SET NULL"), nullable=True, index=True)
    university = Column(String(255), nullable=True)
    department = Column(String(255), nullable=True)
    course = Column(String(255), nullable=True)
    subject_name = Column(String(255), nullable=True)
    original_name = Column(String(255), nullable=False)
    stored_name = Column(String(700), nullable=False, unique=True)
    mime_type = Column(String(255), nullable=False)
    size = Column(BigInteger, nullable=False)
    file_hash = Column(String(64), nullable=False, index=True)
    version = Column(Integer, nullable=False, default=1, server_default="1")
    status = Column(String(30), nullable=False, default="active", server_default="active", index=True)
    retention_status = Column(String(30), nullable=False, default="active", server_default="active", index=True)
    retention_warning_at = Column(DateTime(timezone=True), nullable=True, index=True)
    retention_expires_at = Column(DateTime(timezone=True), nullable=True, index=True)
    last_owner_activity_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, index=True)
    last_downloaded_at = Column(DateTime(timezone=True), nullable=True, index=True)
    deleted_at = Column(DateTime(timezone=True), nullable=True, index=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, index=True)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, onupdate=utc_now, index=True)

    owner = relationship("User", foreign_keys=[owner_user_id])
    subject = relationship("Subject")

    __table_args__ = (
        CheckConstraint("status IN ('active','removed')", name="chk_personal_synced_material_status"),
        CheckConstraint("retention_status IN ('active','warning','expired','deleted')", name="chk_personal_synced_material_retention_status"),
        CheckConstraint("size > 0", name="chk_personal_synced_material_size"),
        UniqueConstraint("owner_user_id","file_hash",name="uq_personal_synced_material_owner_hash"),
    )
