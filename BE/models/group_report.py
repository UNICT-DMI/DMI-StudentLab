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

class GroupReport(Base):
    __tablename__ = "group_reports"

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

    group_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey(
            "study_groups.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    reason: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        index=True,
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

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=datetime.utcnow,
        index=True,
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    reporter = relationship(
        "User",
        back_populates="group_reports",
        foreign_keys=[
            reporter_user_id,
        ],
    )

    group = relationship(
        "StudyGroup",
        back_populates="reports",
        foreign_keys=[
            group_id,
        ],
    )

    reviewer = relationship(
        "User",
        back_populates="reviewed_group_reports",
        foreign_keys=[
            reviewed_by,
        ],
    )

    __table_args__ = (
        CheckConstraint(
            "reason IN ("
            "'spam', "
            "'inappropriate_content', "
            "'harassment', "
            "'hate_speech', "
            "'misleading_information', "
            "'illegal_content', "
            "'impersonation', "
            "'other'"
            ")",
            name="chk_group_report_reason",
        ),
        CheckConstraint(
            "status IN ("
            "'pending', "
            "'reviewing', "
            "'resolved', "
            "'rejected'"
            ")",
            name="chk_group_report_status",
        ),
    )