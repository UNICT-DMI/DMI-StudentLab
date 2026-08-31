from datetime import datetime, timezone

from sqlalchemy import BigInteger, Column, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from core.database import Base


def utc_now():
    return datetime.now(timezone.utc)


class MaterialStorageEvent(Base):
    __tablename__ = "material_storage_events"

    id = Column(Integer, primary_key=True, index=True)
    source = Column(String(40), nullable=False, index=True)
    material_id = Column(Integer, nullable=True, index=True)
    action = Column(String(50), nullable=False, index=True)
    blob_path = Column(String(1000), nullable=True, index=True)
    original_name = Column(String(255), nullable=True)
    size = Column(BigInteger, nullable=True)
    actor_id = Column(
        Integer,
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    reason = Column(Text, nullable=True)
    details_json = Column(Text, nullable=True)
    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=utc_now,
        index=True,
    )

    actor = relationship("User", foreign_keys=[actor_id])