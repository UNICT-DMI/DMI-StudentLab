from datetime import (
    datetime,
    timezone,
)

from sqlalchemy import (
    CheckConstraint,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
)

from sqlalchemy.orm import (
    relationship,
)

from core.database import (
    Base,
)


def utc_now():
    return datetime.now(
        timezone.utc,
    )


class GroupNewsReport(Base):
    __tablename__ = (
        "group_news_reports"
    )

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    news_id = Column(
        Integer,
        ForeignKey(
            "group_news.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    group_id = Column(
        Integer,
        ForeignKey(
            "study_groups.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    reporter_user_id = Column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    reported_author_user_id = Column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="SET NULL",
        ),
        nullable=True,
        index=True,
    )

    reason = Column(
        String(100),
        nullable=False,
        index=True,
    )

    description = Column(
        Text,
        nullable=True,
    )

    status = Column(
        String(30),
        nullable=False,
        default="pending",
        index=True,
    )

    moderation_action = Column(
        String(40),
        nullable=False,
        default="none",
        index=True,
    )

    moderation_note = Column(
        Text,
        nullable=True,
    )

    reviewed_by_user_id = Column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="SET NULL",
        ),
        nullable=True,
        index=True,
    )

    reviewed_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=True,
        index=True,
    )

    created_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=False,
        default=utc_now,
        index=True,
    )

    updated_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=False,
        default=utc_now,
        onupdate=utc_now,
    )

    news = relationship(
        "GroupNews",
        foreign_keys=[
            news_id,
        ],
        back_populates="reports",
    )

    group = relationship(
        "StudyGroup",
        foreign_keys=[
            group_id,
        ],
        back_populates="news_reports",
    )

    reporter = relationship(
        "User",
        foreign_keys=[
            reporter_user_id,
        ],
        back_populates="sent_group_news_reports",
    )

    reported_author = relationship(
        "User",
        foreign_keys=[
            reported_author_user_id,
        ],
        back_populates="received_group_news_reports",
    )

    reviewer = relationship(
        "User",
        foreign_keys=[
            reviewed_by_user_id,
        ],
        back_populates="reviewed_group_news_reports",
    )

    __table_args__ = (
        CheckConstraint(
            "reason IN ("
            "'spam', "
            "'harassment', "
            "'hate_speech', "
            "'sexual_content', "
            "'violence', "
            "'misinformation', "
            "'privacy_violation', "
            "'impersonation', "
            "'illegal_content', "
            "'other'"
            ")",
            name=(
                "chk_group_news_report_reason"
            ),
        ),
        CheckConstraint(
            "status IN ("
            "'pending', "
            "'under_review', "
            "'resolved', "
            "'rejected'"
            ")",
            name=(
                "chk_group_news_report_status"
            ),
        ),
        CheckConstraint(
            "moderation_action IN ("
            "'none', "
            "'hide_news', "
            "'remove_news', "
            "'warn_user', "
            "'remove_user_from_group', "
            "'suspend_user', "
            "'deactivate_user'"
            ")",
            name=(
                "chk_group_news_report_action"
            ),
        ),
    )