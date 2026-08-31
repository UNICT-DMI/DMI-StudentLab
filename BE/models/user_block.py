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
    UniqueConstraint,
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


class UserBlock(Base):
    __tablename__ = (
        "user_blocks"
    )

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    blocker_user_id = Column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    blocked_user_id = Column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="CASCADE",
        ),
        nullable=False,
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

    blocker = relationship(
        "User",
        foreign_keys=[
            blocker_user_id,
        ],
        back_populates="blocked_users",
    )

    blocked = relationship(
        "User",
        foreign_keys=[
            blocked_user_id,
        ],
        back_populates="blocked_by_users",
    )

    __table_args__ = (
        UniqueConstraint(
            "blocker_user_id",
            "blocked_user_id",
            name=(
                "uq_user_block"
            ),
        ),
        CheckConstraint(
            "blocker_user_id <> blocked_user_id",
            name=(
                "chk_user_block_not_self"
            ),
        ),
    )