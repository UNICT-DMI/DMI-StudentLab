from datetime import (
    datetime,
    timezone,
)

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
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


class StudyGroup(Base):
    __tablename__ = (
        "study_groups"
    )

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    name = Column(
        String(150),
        nullable=False,
    )

    description = Column(
        Text,
        nullable=True,
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

    university = Column(
        String(150),
        nullable=False,
        default="",
    )

    department = Column(
        String(150),
        nullable=False,
    )

    course = Column(
        String(150),
        nullable=False,
    )

    is_private = Column(
        Boolean,
        nullable=False,
        default=False,
        index=True,
    )

    status = Column(
        String(30),
        nullable=False,
        default="active",
        index=True,
    )

    deletion_requested_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=True,
    )

    deletion_deadline = Column(
        DateTime(
            timezone=True,
        ),
        nullable=True,
        index=True,
    )

    created_by = Column(
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
    )

    updated_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=False,
        default=utc_now,
        onupdate=utc_now,
    )

    subject = relationship(
        "Subject",
    )

    creator = relationship(
        "User",
        foreign_keys=[
            created_by,
        ],
    )

    members = relationship(
        "GroupMember",
        back_populates="group",
        cascade=(
            "all, delete-orphan"
        ),
        order_by=(
            "GroupMember.id"
        ),
    )

    join_requests = relationship(
        "GroupJoinRequest",
        back_populates="group",
        cascade=(
            "all, delete-orphan"
        ),
        order_by=(
            "GroupJoinRequest.id"
        ),
    )

    materials = relationship(
        "GroupMaterial",
        back_populates="group",
        foreign_keys=(
            "GroupMaterial.group_id"
        ),
        cascade=(
            "all, delete-orphan"
        ),
        order_by=(
            "GroupMaterial.id"
        ),
    )

    ownership_transfers = relationship(
        "GroupOwnershipTransfer",
        back_populates="group",
        foreign_keys=(
            "GroupOwnershipTransfer.group_id"
        ),
        cascade=(
            "all, delete-orphan"
        ),
        order_by=(
            "GroupOwnershipTransfer.id"
        ),
    )

    reports = relationship(
        "GroupReport",
        back_populates="group",
        foreign_keys=(
            "GroupReport.group_id"
        ),
        cascade=(
            "all, delete-orphan"
        ),
        order_by=(
            "GroupReport.id"
        ),
    )

    content_reports = relationship(
        "GroupContentReport",
        back_populates="group",
        foreign_keys=(
            "GroupContentReport.group_id"
        ),
        cascade=(
            "all, delete-orphan"
        ),
        order_by=(
            "GroupContentReport.id"
        ),
    )

    news = relationship(
        "GroupNews",
        back_populates="group",
        foreign_keys=(
            "GroupNews.group_id"
        ),
        cascade=(
            "all, delete-orphan"
        ),
        order_by=(
            "GroupNews.created_at.desc()"
        ),
    )

    news_reports = relationship(
        "GroupNewsReport",
        back_populates="group",
        foreign_keys=(
            "GroupNewsReport.group_id"
        ),
        cascade=(
            "all, delete-orphan"
        ),
        order_by=(
            "GroupNewsReport.created_at.desc()"
        ),
    )

    __table_args__ = (
        CheckConstraint(
            "status IN ("
            "'active', "
            "'pending_deletion', "
            "'deleted'"
            ")",
            name=(
                "chk_study_group_status"
            ),
        ),
    )


class GroupMember(Base):
    __tablename__ = (
        "group_members"
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

    user_id = Column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    role = Column(
        String(20),
        nullable=False,
        default="member",
        index=True,
    )

    joined_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=False,
        default=utc_now,
    )

    group = relationship(
        "StudyGroup",
        back_populates="members",
    )

    user = relationship(
        "User",
    )

    __table_args__ = (
        UniqueConstraint(
            "group_id",
            "user_id",
            name=(
                "uq_group_member"
            ),
        ),
        CheckConstraint(
            "role IN ("
            "'owner', "
            "'admin', "
            "'member'"
            ")",
            name=(
                "chk_group_member_role"
            ),
        ),
    )


class GroupJoinRequest(Base):
    __tablename__ = (
        "group_join_requests"
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

    user_id = Column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="CASCADE",
        ),
        nullable=False,
        index=True,
    )

    status = Column(
        String(20),
        nullable=False,
        default="pending",
        index=True,
    )

    reviewed_by = Column(
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

    created_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=False,
        default=utc_now,
    )

    updated_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=False,
        default=utc_now,
        onupdate=utc_now,
    )

    group = relationship(
        "StudyGroup",
        back_populates=(
            "join_requests"
        ),
    )

    user = relationship(
        "User",
        foreign_keys=[
            user_id,
        ],
    )

    reviewer = relationship(
        "User",
        foreign_keys=[
            reviewed_by,
        ],
    )

    __table_args__ = (
        UniqueConstraint(
            "group_id",
            "user_id",
            name=(
                "uq_group_join_request"
            ),
        ),
        CheckConstraint(
            "status IN ("
            "'pending', "
            "'accepted', "
            "'rejected', "
            "'cancelled'"
            ")",
            name=(
                "chk_group_join_request_status"
            ),
        ),
    )