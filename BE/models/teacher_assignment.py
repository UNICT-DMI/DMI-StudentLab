from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Column,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    text,
)

from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from core.database import Base


class TeacherAssignment(Base):
    __tablename__ = "teacher_assignments"

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

    offering_id = Column(
        Integer,
        ForeignKey(
            "subject_offerings.id",
            ondelete="CASCADE",
        ),
        nullable=True,
        index=True,
    )

    verification_status = Column(
        String(30),
        nullable=False,
        default="pending",
        index=True,
    )

    verified_by = Column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="SET NULL",
        ),
        nullable=True,
    )

    verified_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=True,
    )

    is_current = Column(
        Boolean,
        nullable=False,
        default=True,
        index=True,
    )

    created_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=False,
        server_default=func.now(),
    )

    updated_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )

    user = relationship(
        "User",
        foreign_keys=[
            user_id,
        ],
        back_populates="teacher_assignments",
    )

    subject = relationship(
        "Subject",
        back_populates="teacher_assignments",
    )

    offering = relationship(
        "SubjectOffering",
        back_populates="teacher_assignments",
    )

    verifier = relationship(
        "User",
        foreign_keys=[
            verified_by,
        ],
    )

    __table_args__ = (
        CheckConstraint(
            "verification_status IN ('pending', 'verified', 'rejected')",
            name="chk_teacher_assignment_verification_status",
        ),
        Index(
            "uq_teacher_assignment_subject",
            "user_id",
            "subject_id",
            unique=True,
            postgresql_where=text(
                "offering_id IS NULL"
            ),
        ),
        Index(
            "uq_teacher_assignment_offering",
            "user_id",
            "offering_id",
            unique=True,
            postgresql_where=text(
                "offering_id IS NOT NULL"
            ),
        ),
    )