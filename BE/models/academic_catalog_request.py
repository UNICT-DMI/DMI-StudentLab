"""Course catalogue entries and unresolved academic paths declared by students."""
from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, ForeignKey, Integer, String, Text, UniqueConstraint

from core.database import Base


def now():
    return datetime.now(timezone.utc)


class AcademicCatalogCourse(Base):
    __tablename__ = 'academic_catalog_courses'
    id = Column(Integer, primary_key=True)
    university = Column(String(200), nullable=False)
    university_code = Column(String(50), nullable=False)
    department = Column(String(200), nullable=False)
    department_code = Column(String(50), nullable=False)
    course = Column(String(200), nullable=False)
    course_code = Column(String(50), nullable=False)
    degree_type = Column(String(50))
    created_by = Column(Integer, ForeignKey('users.id', ondelete='SET NULL'))
    created_at = Column(DateTime(timezone=True), nullable=False, default=now)

    __table_args__ = (UniqueConstraint('university_code', 'department_code', 'course_code',
                                      name='uq_academic_catalog_course'),)


class AcademicCatalogRequest(Base):
    __tablename__ = 'academic_catalog_requests'
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    academic_path_id = Column(Integer, ForeignKey('user_academic_paths.id', ondelete='CASCADE'),
                              nullable=False, unique=True)
    university = Column(String(200), nullable=False)
    university_code = Column(String(50), nullable=False, default='')
    department = Column(String(200), nullable=False)
    department_code = Column(String(50), nullable=False, default='')
    course = Column(String(200), nullable=False)
    course_code = Column(String(50), nullable=False, default='')
    status = Column(String(20), nullable=False, default='pending', index=True)
    admin_note = Column(Text)
    decided_by = Column(Integer, ForeignKey('users.id', ondelete='SET NULL'))
    created_at = Column(DateTime(timezone=True), nullable=False, default=now)
    decided_at = Column(DateTime(timezone=True))
