from datetime import datetime

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
)

from sqlalchemy.orm import (
    Mapped,
    mapped_column,
    relationship,
)

from core.database import Base


class GroupContentReport(Base):
    __tablename__ = "group_content_reports"

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

    content_type: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        index=True,
    )

    content_id: Mapped[int] = mapped_column(
        Integer,
        nullable=False,
        index=True,
    )

    author_user_id: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="SET NULL",
        ),
        nullable=True,
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
        DateTime(
            timezone=True,
        ),
        nullable=True,
    )

    moderation_action: Mapped[str] = mapped_column(
        String(40),
        nullable=False,
        default="none",
    )

    moderation_note: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        default="",
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(
            timezone=True,
        ),
        nullable=False,
        default=datetime.utcnow,
        index=True,
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(
            timezone=True,
        ),
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    reporter = relationship(
        "User",
        back_populates="group_content_reports",
        foreign_keys=[
            reporter_user_id,
        ],
    )

    author = relationship(
        "User",
        back_populates="authored_reported_group_content",
        foreign_keys=[
            author_user_id,
        ],
    )

    reviewer = relationship(
        "User",
        back_populates="reviewed_group_content_reports",
        foreign_keys=[
            reviewed_by,
        ],
    )

    group = relationship(
        "StudyGroup",
        back_populates="content_reports",
        foreign_keys=[
            group_id,
        ],
    )

    __table_args__ = (
        CheckConstraint(
            "content_type IN ("
            "'message', "
            "'material', "
            "'post'"
            ")",
            name="chk_group_content_report_type",
        ),
        CheckConstraint(
            "reason IN ("
            "'spam', "
            "'inappropriate_content', "
            "'harassment', "
            "'hate_speech', "
            "'misleading_information', "
            "'illegal_content', "
            "'copyright', "
            "'malware', "
            "'other'"
            ")",
            name="chk_group_content_report_reason",
        ),
        CheckConstraint(
            "status IN ("
            "'pending', "
            "'reviewing', "
            "'resolved', "
            "'rejected'"
            ")",
            name="chk_group_content_report_status",
        ),
        CheckConstraint(
            "moderation_action IN ("
            "'none', "
            "'content_kept', "
            "'content_hidden', "
            "'content_removed', "
            "'user_warned', "
            "'user_suspended'"
            ")",
            name="chk_group_content_report_moderation_action",
        ),
    )