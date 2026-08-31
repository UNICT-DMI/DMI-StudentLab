from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Table,
    Text,
    UniqueConstraint,
)

from sqlalchemy.orm import relationship

from core.database import Base


subject_offering_teachers = Table(
    "subject_offering_teachers",
    Base.metadata,

    Column(
        "offering_id",
        Integer,
        ForeignKey(
            "subject_offerings.id",
            ondelete="CASCADE",
        ),
        primary_key=True,
    ),

    Column(
        "teacher_id",
        Integer,
        ForeignKey(
            "academic_teachers.id",
            ondelete="CASCADE",
        ),
        primary_key=True,
    ),
)


class Subject(Base):
    __tablename__ = "subjects"

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    code = Column(
        String(50),
        nullable=True,
        index=True,
    )

    name = Column(
        String(200),
        nullable=False,
    )

    university = Column(
        String(200),
        nullable=False,
        default="Università degli Studi di Catania",
        index=True,
    )

    university_code = Column(
        String(30),
        nullable=False,
        default="UNICT",
        index=True,
    )

    department = Column(
        String(200),
        nullable=False,
        index=True,
    )

    department_code = Column(
        String(30),
        nullable=True,
        index=True,
    )

    course = Column(
        String(200),
        nullable=False,
        index=True,
    )

    course_code = Column(
        String(30),
        nullable=True,
        index=True,
    )

    degree_type = Column(
        String(50),
        nullable=True,
    )

    study_year = Column(
        Integer,
        nullable=True,
        index=True,
    )

    is_active = Column(
        Boolean,
        nullable=False,
        default=True,
        index=True,
    )

    offerings = relationship(
        "SubjectOffering",
        back_populates="subject",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )

    users = relationship(
        "UserSubject",
        back_populates="subject",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )

    teacher_assignments = relationship(
        "TeacherAssignment",
        back_populates="subject",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )

    __table_args__ = (
        UniqueConstraint(
            "university_code",
            "department",
            "course",
            "code",
            name="uq_subject_catalog_code",
        ),
    )


class SubjectOffering(Base):
    __tablename__ = "subject_offerings"

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    subject_id = Column(
        Integer,
        ForeignKey(
            "subjects.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    module = Column(
        String(200),
        nullable=True,
    )

    channel = Column(
        String(30),
        nullable=True,
    )

    academic_year = Column(
        String(20),
        nullable=True,
        index=True,
    )

    source_url = Column(
        Text,
        nullable=True,
    )

    is_active = Column(
        Boolean,
        nullable=False,
        default=True,
    )

    subject = relationship(
        "Subject",
        back_populates="offerings",
    )

    teachers = relationship(
        "AcademicTeacher",
        secondary=subject_offering_teachers,
        back_populates="offerings",
    )

    teacher_assignments = relationship(
        "TeacherAssignment",
        back_populates="offering",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )

    __table_args__ = (
        UniqueConstraint(
            "subject_id",
            "module",
            "channel",
            "academic_year",
            name="uq_subject_offering",
        ),
    )


class AcademicTeacher(Base):
    __tablename__ = "academic_teachers"

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    name = Column(
        String(200),
        nullable=False,
        unique=True,
        index=True,
    )

    user_id = Column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="SET NULL",
        ),
        nullable=True,
        unique=True,
        index=True,
    )

    is_active = Column(
        Boolean,
        nullable=False,
        default=True,
    )

    offerings = relationship(
        "SubjectOffering",
        secondary=subject_offering_teachers,
        back_populates="teachers",
    )


class UserSubject(Base):
    __tablename__ = "user_subjects"

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    user_id = Column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    subject_id = Column(
        Integer,
        ForeignKey(
            "subjects.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    grade = Column(
        Integer,
        nullable=True,
    )

    grade_status = Column(
        String(30),
        nullable=False,
        default="none",
        index=True,
    )

    grade_verified_by = Column(
        Integer,
        nullable=True,
    )

    grade_verified_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=True,
    )

    note = Column(
        Text,
        nullable=True,
    )

    can_help = Column(
        Boolean,
        nullable=False,
        default=False,
    )

    can_give_private_lessons = Column(
        Boolean,
        nullable=False,
        default=False,
    )

    user = relationship(
        "User",
        back_populates="subjects",
    )

    subject = relationship(
        "Subject",
        back_populates="users",
    )

    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "subject_id",
            name="uq_user_subject",
        ),
    )