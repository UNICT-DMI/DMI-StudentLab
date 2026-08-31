from sqlalchemy import (
    CheckConstraint,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import relationship

from core.database import Base


class Review(Base):
    __tablename__ = "reviews"

    __table_args__ = (
        CheckConstraint(
            "rating >= 1 AND rating <= 5",
            name="chk_reviews_rating",
        ),
        CheckConstraint(
            "reviewer_id <> reviewed_user_id",
            name="chk_reviews_not_self",
        ),
        CheckConstraint(
            "moderation_status IN ('pending', 'approved', 'rejected', 'hidden')",
            name="chk_reviews_moderation_status",
        ),
        UniqueConstraint(
            "reviewer_id",
            "reviewed_user_id",
            name="uq_reviews_reviewer_reviewed",
        ),
    )

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    reviewer_id = Column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    reviewed_user_id = Column(
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
            ondelete="SET NULL",
        ),
        nullable=True,
        index=True,
    )

    rating = Column(
        Integer,
        nullable=False,
    )

    comment = Column(
        Text,
        nullable=False,
        default="",
    )

    moderation_status = Column(
        String(30),
        nullable=False,
        default="pending",
        server_default="pending",
        index=True,
    )

    moderated_by = Column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="SET NULL",
        ),
        nullable=True,
    )

    moderated_at = Column(
        DateTime(timezone=True),
        nullable=True,
    )

    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
    )

    updated_at = Column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )

    reviewer = relationship(
        "User",
        foreign_keys=[
            reviewer_id,
        ],
    )

    reviewed_user = relationship(
        "User",
        foreign_keys=[
            reviewed_user_id,
        ],
    )

    moderator = relationship(
        "User",
        foreign_keys=[
            moderated_by,
        ],
    )

    subject = relationship(
        "Subject",
        foreign_keys=[
            subject_id,
        ],
    )