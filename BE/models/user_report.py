from datetime import datetime

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from core.database import Base

class UserReport(Base):
    __tablename__ = "user_reports"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        index=True,
    )

    reporter_user_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    reported_user_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    reason: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )

    description: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        default="",
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

    moderation_note: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        default="",
    )

    is_active: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=True,
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

    reporter = relationship(
        "User",
        back_populates="sent_user_reports",
        foreign_keys=[
            reporter_user_id,
        ],
    )

    reported_user = relationship(
        "User",
        back_populates="received_user_reports",
        foreign_keys=[
            reported_user_id,
        ],
    )

    reviewer = relationship(
        "User",
        back_populates="reviewed_user_reports",
        foreign_keys=[
            reviewed_by,
        ],
    )

    __table_args__ = (
        CheckConstraint(
            "reporter_user_id <> reported_user_id",
            name="chk_user_report_not_self",
        ),
        CheckConstraint(
            "status IN ('pending', 'reviewing', 'resolved', 'rejected')",
            name="chk_user_report_status",
        ),
        CheckConstraint(
            "reason IN ("
            "'fake_profile', "
            "'false_information', "
            "'inappropriate_behavior', "
            "'spam', "
            "'offensive_content', "
            "'harassment', "
            "'impersonation', "
            "'other'"
            ")",
            name="chk_user_report_reason",
        ),
    )