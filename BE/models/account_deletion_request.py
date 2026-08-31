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


class AccountDeletionRequest(Base):
    __tablename__ = "account_deletion_requests"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
        index=True,
    )

    user_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    status: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default="pending",
        index=True,
    )

    reason: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
        default="user_request",
    )

    note: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        default="",
    )

    requested_at: Mapped[datetime] = mapped_column(
        DateTime(
            timezone=True,
        ),
        nullable=False,
        default=datetime.utcnow,
    )

    ownership_resolution_deadline: Mapped[
        datetime | None
    ] = mapped_column(
        DateTime(
            timezone=True,
        ),
        nullable=True,
        index=True,
    )

    completed_at: Mapped[
        datetime | None
    ] = mapped_column(
        DateTime(
            timezone=True,
        ),
        nullable=True,
    )

    cancelled_at: Mapped[
        datetime | None
    ] = mapped_column(
        DateTime(
            timezone=True,
        ),
        nullable=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(
            timezone=True,
        ),
        nullable=False,
        default=datetime.utcnow,
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(
            timezone=True,
        ),
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    user = relationship(
        "User",
        back_populates="account_deletion_requests",
        foreign_keys=[
            user_id,
        ],
    )

    __table_args__ = (
        CheckConstraint(
            "status IN ("
            "'pending', "
            "'waiting_group_transfer', "
            "'ready_for_deletion', "
            "'completed', "
            "'cancelled'"
            ")",
            name="chk_account_deletion_request_status",
        ),
        CheckConstraint(
            "reason IN ("
            "'user_request', "
            "'privacy', "
            "'unused_account', "
            "'duplicate_account', "
            "'other'"
            ")",
            name="chk_account_deletion_request_reason",
        ),
    )