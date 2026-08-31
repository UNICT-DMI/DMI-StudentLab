from datetime import (
    datetime,
    timezone,
)

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
)

from sqlalchemy.orm import relationship

from core.database import Base


class UserPolicyAcceptance(Base):
    __tablename__ = (
        "user_policy_acceptances"
    )

    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "policy_version",
            name=(
                "uq_user_policy_"
                "acceptance_version"
            ),
        ),
    )

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

    policy_version = Column(
        String(30),
        nullable=False,
        index=True,
    )

    privacy_acknowledged = Column(
        Boolean,
        nullable=False,
        default=False,
    )

    terms_accepted = Column(
        Boolean,
        nullable=False,
        default=False,
    )

    accepted_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=False,
        default=lambda: datetime.now(
            timezone.utc,
        ),
        index=True,
    )

    user = relationship(
        "User",
        back_populates="policy_acceptances",
    )