from datetime import datetime

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from core.database import Base

class Notification(Base):
    __tablename__ = "notifications"

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

    actor_user_id: Mapped[int | None] = mapped_column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="SET NULL",
        ),
        nullable=True,
        index=True,
    )

    type: Mapped[str] = mapped_column(
        String(50),
        nullable=False,
        index=True,
    )

    title: Mapped[str] = mapped_column(
        String(150),
        nullable=False,
    )

    message: Mapped[str] = mapped_column(
        Text,
        nullable=False,
        default="",
    )

    resource_type: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
        index=True,
    )

    resource_id: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
        index=True,
    )

    action_type: Mapped[str | None] = mapped_column(
        String(50),
        nullable=True,
    )

    action_resource_id: Mapped[int | None] = mapped_column(
        Integer,
        nullable=True,
        index=True,
    )

    action_status: Mapped[str] = mapped_column(
        String(30),
        nullable=False,
        default="none",
        index=True,
    )

    is_read: Mapped[bool] = mapped_column(
        Boolean,
        nullable=False,
        default=False,
        index=True,
    )

    read_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
        index=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=datetime.utcnow,
        index=True,
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    user = relationship(
        "User",
        back_populates="notifications",
        foreign_keys=[
            user_id,
        ],
    )

    actor = relationship(
        "User",
        back_populates="notification_actions",
        foreign_keys=[
            actor_user_id,
        ],
    )

    __table_args__ = (
        CheckConstraint(
            "type IN ("
            "'group_ownership_transfer', "
            "'group_join_request', "
            "'group_join_accepted', "
            "'group_join_rejected', "
            "'group_deleted', "
            "'group_report_update', "
            "'profile_report_update', "
            "'profile_error_update', "
            "'teacher_verification_update', "
            "'teacher_assignment_update', "
            "'academic_path_verification_update', "
            "'grade_verification_update', "
            "'material_publication_request', "
            "'material_publication_approved', "
            "'material_publication_rejected', "
            "'system'"
            ")",
            name="chk_notification_type",
        ),
        CheckConstraint(
            "resource_type IS NULL OR resource_type IN ("
            "'user', "
            "'group', "
            "'group_join_request', "
            "'group_ownership_transfer', "
            "'teacher_assignment', "
            "'academic_path', "
            "'subject', "
            "'material', "
            "'profile_report', "
            "'profile_error_report'"
            ")",
            name="chk_notification_resource_type",
        ),
        CheckConstraint(
            "action_type IS NULL OR action_type IN ("
            "'accept_reject_group_ownership', "
            "'accept_reject_group_join', "
            "'open_profile', "
            "'open_group', "
            "'open_material', "
            "'open_admin_review'"
            ")",
            name="chk_notification_action_type",
        ),
        CheckConstraint(
            "action_status IN ("
            "'none', "
            "'pending', "
            "'accepted', "
            "'rejected', "
            "'expired', "
            "'completed', "
            "'cancelled'"
            ")",
            name="chk_notification_action_status",
        ),
    )