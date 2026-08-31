from datetime import datetime

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from core.database import Base

class ProfileErrorReport(Base):
    __tablename__ = "profile_error_reports"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        index=True,
    )

    user_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    category: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        default="other",
        index=True,
    )

    description: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )

    status: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default="pending",
        index=True,
    )

    reviewed_by: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="SET NULL",
        ),
        nullable=True,
        index=True,
    )

    reviewed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    resolution_note: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        default="",
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=datetime.utcnow,
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    user = relationship(
        "User",
        back_populates="profile_error_reports",
        foreign_keys=[
            user_id,
        ],
    )

    reviewer = relationship(
        "User",
        back_populates="reviewed_profile_error_reports",
        foreign_keys=[
            reviewed_by,
        ],
    )

    __table_args__ = (
        CheckConstraint(
            "category IN ("
            "'personal_data', "
            "'academic_path', "
            "'degree_verification', "
            "'subject', "
            "'grade_verification', "
            "'teacher_assignment', "
            "'teacher_verification', "
            "'availability', "
            "'other'"
            ")",
            name="chk_profile_error_report_category",
        ),
        CheckConstraint(
            "status IN ("
            "'pending', "
            "'reviewing', "
            "'resolved', "
            "'rejected'"
            ")",
            name="chk_profile_error_report_status",
        ),
    )