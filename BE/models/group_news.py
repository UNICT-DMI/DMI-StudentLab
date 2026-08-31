from datetime import (
    datetime,
    timedelta,
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


def news_expiration_time():
    return utc_now() + timedelta(
        days=7,
    )


class GroupNews(Base):
    __tablename__ = (
        "group_news"
    )

    id = Column(
        Integer,
        primary_key=True,
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

    author_user_id = Column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    recipient_user_id = Column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="SET NULL",
        ),
        nullable=True,
        index=True,
    )

    parent_news_id = Column(
        Integer,
        ForeignKey(
            "group_news.id",
            ondelete="SET NULL",
        ),
        nullable=True,
        index=True,
    )

    visibility = Column(
        String(20),
        nullable=False,
        default="group",
        index=True,
    )

    content = Column(
        Text,
        nullable=False,
    )

    status = Column(
        String(40),
        nullable=False,
        default="active",
        index=True,
    )

    deleted_by_user_id = Column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="SET NULL",
        ),
        nullable=True,
        index=True,
    )

    deleted_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=True,
        index=True,
    )

    moderated_by_user_id = Column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="SET NULL",
        ),
        nullable=True,
        index=True,
    )

    moderated_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=True,
        index=True,
    )

    moderation_reason = Column(
        Text,
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

    expires_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=False,
        default=news_expiration_time,
        index=True,
    )

    group = relationship(
        "StudyGroup",
        foreign_keys=[
            group_id,
        ],
        back_populates="news",
    )

    author = relationship(
        "User",
        foreign_keys=[
            author_user_id,
        ],
        back_populates="authored_group_news",
    )

    recipient = relationship(
        "User",
        foreign_keys=[
            recipient_user_id,
        ],
        back_populates="received_private_group_news",
    )

    deleted_by = relationship(
        "User",
        foreign_keys=[
            deleted_by_user_id,
        ],
        back_populates="deleted_group_news",
    )

    moderated_by = relationship(
        "User",
        foreign_keys=[
            moderated_by_user_id,
        ],
        back_populates="moderated_group_news",
    )

    parent = relationship(
        "GroupNews",
        remote_side=[
            id,
        ],
        foreign_keys=[
            parent_news_id,
        ],
        back_populates="replies",
    )

    replies = relationship(
        "GroupNews",
        foreign_keys=[
            parent_news_id,
        ],
        back_populates="parent",
        order_by=(
            "GroupNews.created_at"
        ),
    )

    reports = relationship(
        "GroupNewsReport",
        foreign_keys=(
            "GroupNewsReport.news_id"
        ),
        back_populates="news",
        cascade=(
            "all, delete-orphan"
        ),
        order_by=(
            "GroupNewsReport.created_at.desc()"
        ),
    )

    __table_args__ = (
        CheckConstraint(
            "visibility IN ("
            "'group', "
            "'private'"
            ")",
            name=(
                "chk_group_news_visibility"
            ),
        ),
        CheckConstraint(
            "status IN ("
            "'active', "
            "'deleted_by_author', "
            "'removed_by_group_owner', "
            "'removed_by_group_admin', "
            "'removed_by_platform_moderator', "
            "'expired'"
            ")",
            name=(
                "chk_group_news_status"
            ),
        ),
        CheckConstraint(
            "("
            "visibility = 'group' "
            "AND recipient_user_id IS NULL"
            ") OR ("
            "visibility = 'private' "
            "AND recipient_user_id IS NOT NULL"
            ")",
            name=(
                "chk_group_news_recipient"
            ),
        ),
        CheckConstraint(
            "length(trim(content)) > 0",
            name=(
                "chk_group_news_content"
            ),
        ),
    )