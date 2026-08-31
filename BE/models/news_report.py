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
    UniqueConstraint,
)

from core.database import (
    Base,
)


def utc_now():
    return datetime.now(
        timezone.utc,
    )


class NewsReport(Base):
    __tablename__ = (
        "news_reports"
    )

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    category = Column(
        String(20),
        nullable=False,
        index=True,
    )

    news_id = Column(
        String(64),
        nullable=False,
        index=True,
    )

    group_id = Column(
        Integer,
        nullable=True,
        index=True,
    )

    conversation_id = Column(
        String(64),
        nullable=True,
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

    reported_user_id = Column(
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
    )

    disclosed_content_key = Column(
        String(512),
        nullable=True,
    )

    disclosure_consent_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=True,
    )

    disclosure_opened_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=True,
    )

    disclosure_opened_by_user_id = Column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="SET NULL",
        ),
        nullable=True,
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

    __table_args__ = (
        UniqueConstraint(
            "category",
            "news_id",
            "reporter_user_id",
            name=(
                "uq_news_report_reporter"
            ),
        ),
        CheckConstraint(
            "category IN ('avvisi', 'gruppi', 'private')",
            name=(
                "chk_news_report_category"
            ),
        ),
        CheckConstraint(
            "reason IN ('spam', 'harassment', 'hate', 'privacy', "
            "'illegal_content', 'other')",
            name=(
                "chk_news_report_reason"
            ),
        ),
        CheckConstraint(
            "status IN ('pending', 'under_review', 'resolved', 'dismissed')",
            name=(
                "chk_news_report_status"
            ),
        ),
        CheckConstraint(
            "moderation_action IN ('none', 'hide_news', 'remove_news')",
            name=(
                "chk_news_report_action"
            ),
        ),
    )
