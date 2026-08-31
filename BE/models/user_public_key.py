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
    UniqueConstraint,
)

from core.database import (
    Base,
)


def utc_now():
    return datetime.now(
        timezone.utc,
    )


class UserPublicKey(Base):
    __tablename__ = (
        "user_public_keys"
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

    device_id = Column(
        String(64),
        nullable=False,
        index=True,
    )

    device_label = Column(
        String(100),
        nullable=True,
    )

    algo = Column(
        String(32),
        nullable=False,
    )

    public_key = Column(
        String(512),
        nullable=False,
    )

    created_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=False,
        default=utc_now,
        index=True,
    )

    rotated_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=True,
    )

    revoked_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=True,
        index=True,
    )

    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "device_id",
            name=(
                "uq_user_public_key_device"
            ),
        ),
        CheckConstraint(
            "algo IN ('x25519')",
            name=(
                "chk_user_public_key_algo"
            ),
        ),
    )
