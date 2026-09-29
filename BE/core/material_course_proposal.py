from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, ForeignKey, Integer, String

from core.database import Base


class MaterialCourseProposal(Base):
    __tablename__ = 'material_course_proposals'

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey('users.id', ondelete='SET NULL'), nullable=True)
    university = Column(String(200), nullable=False)
    department = Column(String(200), nullable=False)
    course = Column(String(200), nullable=False)
    status = Column(String(20), nullable=False, default='pending')
    approved_subject_id = Column(Integer, ForeignKey('subjects.id', ondelete='SET NULL'))
    rejection_reason = Column(String(1000))
    created_at = Column(DateTime(timezone=True), nullable=False,
                        default=lambda: datetime.now(timezone.utc))
    reviewed_at = Column(DateTime(timezone=True))
