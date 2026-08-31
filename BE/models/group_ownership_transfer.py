from datetime import datetime

from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    String,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from core.database import Base

class GroupOwnershipTransfer(Base):
    __tablename__ = "group_ownership_transfers"

    id: Mapped[int] = mapped_column(
        Integer,
        primary_key=True,
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

    current_owner_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    proposed_owner_id: Mapped[int] = mapped_column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    account_deletion_request_id: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey(
            "account_deletion_requests.id",
            ondelete="SET NULL",
        ),
        nullable=True,
        index=True,
    )

    status: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default="pending",
        index=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=datetime.utcnow,
    )

    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        index=True,
    )

    responded_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    accepted_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    rejected_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    expired_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    completed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    cancelled_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    current_owner = relationship(
        "User",
        back_populates="outgoing_group_ownership_transfers",
        foreign_keys=[
            current_owner_id,
        ],
    )

    proposed_owner = relationship(
        "User",
        back_populates="incoming_group_ownership_transfers",
        foreign_keys=[
            proposed_owner_id,
        ],
    )

    group = relationship(
        "StudyGroup",
        back_populates="ownership_transfers",
        foreign_keys=[
            group_id,
        ],
    )

    account_deletion_request = relationship(
        "AccountDeletionRequest",
        foreign_keys=[
            account_deletion_request_id,
        ],
    )

    __table_args__ = (
        CheckConstraint(
            "current_owner_id <> proposed_owner_id",
            name="chk_group_ownership_transfer_different_users",
        ),
        CheckConstraint(
            "status IN ("
            "'pending', "
            "'accepted', "
            "'rejected', "
            "'expired', "
            "'completed', "
            "'cancelled'"
            ")",
            name="chk_group_ownership_transfer_status",
        ),
    )