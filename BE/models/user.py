from sqlalchemy import (
    Boolean,
    Column,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
)

from sqlalchemy.orm import relationship

from core.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(
        Integer,
        primary_key=True,
        index=True,
    )

    first_name = Column(
        String(100),
        nullable=False,
    )

    last_name = Column(
        String(100),
        nullable=False,
    )

    date_of_birth = Column(
        Date,
        nullable=True,
        index=True,
    )

    email = Column(
        String(255),
        nullable=False,
        unique=True,
        index=True,
    )

    password_hash = Column(
        String(255),
        nullable=False,
    )

    email_verified_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=True,
        index=True,
    )

    email_verification_id = Column(
        String(64),
        nullable=True,
        unique=True,
        index=True,
    )

    email_verification_code_hash = Column(
        String(255),
        nullable=True,
    )

    email_verification_expires_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=True,
        index=True,
    )

    email_verification_attempts = Column(
        Integer,
        nullable=False,
        default=0,
    )

    email_verification_resend_count = Column(
        Integer,
        nullable=False,
        default=0,
    )

    email_verification_last_sent_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=True,
    )

    university = Column(
        String(200),
        nullable=True,
    )

    department = Column(
        String(150),
        nullable=True,
    )

    course = Column(
        String(150),
        nullable=True,
    )

    description = Column(
        Text,
        nullable=True,
    )

    role = Column(
        String(30),
        nullable=False,
        default="student",
        index=True,
    )

    teacher_verification_status = Column(
        String(30),
        nullable=False,
        default="not_required",
        index=True,
    )

    teacher_verified_by = Column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="SET NULL",
        ),
        nullable=True,
    )

    teacher_verified_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=True,
    )

    available = Column(
        Boolean,
        nullable=False,
        default=False,
    )

    available_for_help = Column(
        Boolean,
        nullable=False,
        default=False,
    )

    available_for_private_lessons = Column(
        Boolean,
        nullable=False,
        default=False,
    )

    willing_to_teach = Column(
        Boolean,
        nullable=False,
        default=False,
    )

    is_active = Column(
        Boolean,
        nullable=False,
        default=True,
        index=True,
    )

    subjects = relationship(
        "UserSubject",
        back_populates="user",
        cascade="all, delete-orphan",
    )

    academic_paths = relationship(
        "UserAcademicPath",
        back_populates="user",
        cascade="all, delete-orphan",
        order_by="UserAcademicPath.id",
        foreign_keys="UserAcademicPath.user_id",
    )

    teacher_assignments = relationship(
        "TeacherAssignment",
        back_populates="user",
        cascade="all, delete-orphan",
        foreign_keys="TeacherAssignment.user_id",
        order_by="TeacherAssignment.id",
    )

    sent_user_reports = relationship(
        "UserReport",
        back_populates="reporter",
        foreign_keys="UserReport.reporter_user_id",
        cascade="all, delete-orphan",
        order_by="UserReport.id",
    )

    received_user_reports = relationship(
        "UserReport",
        back_populates="reported_user",
        foreign_keys="UserReport.reported_user_id",
        cascade="all, delete-orphan",
        order_by="UserReport.id",
    )

    reviewed_user_reports = relationship(
        "UserReport",
        back_populates="reviewer",
        foreign_keys="UserReport.reviewed_by",
        order_by="UserReport.id",
    )

    profile_error_reports = relationship(
        "ProfileErrorReport",
        back_populates="user",
        foreign_keys="ProfileErrorReport.user_id",
        cascade="all, delete-orphan",
        order_by="ProfileErrorReport.id",
    )

    reviewed_profile_error_reports = relationship(
        "ProfileErrorReport",
        back_populates="reviewer",
        foreign_keys="ProfileErrorReport.reviewed_by",
        order_by="ProfileErrorReport.id",
    )

    account_deletion_requests = relationship(
        "AccountDeletionRequest",
        back_populates="user",
        foreign_keys="AccountDeletionRequest.user_id",
        cascade="all, delete-orphan",
        order_by="AccountDeletionRequest.id",
    )

    outgoing_group_ownership_transfers = relationship(
        "GroupOwnershipTransfer",
        back_populates="current_owner",
        foreign_keys="GroupOwnershipTransfer.current_owner_id",
        order_by="GroupOwnershipTransfer.id",
    )

    incoming_group_ownership_transfers = relationship(
        "GroupOwnershipTransfer",
        back_populates="proposed_owner",
        foreign_keys="GroupOwnershipTransfer.proposed_owner_id",
        order_by="GroupOwnershipTransfer.id",
    )

    notifications = relationship(
        "Notification",
        back_populates="user",
        foreign_keys="Notification.user_id",
        cascade="all, delete-orphan",
        order_by="Notification.created_at.desc()",
    )

    notification_actions = relationship(
        "Notification",
        back_populates="actor",
        foreign_keys="Notification.actor_user_id",
        order_by="Notification.created_at.desc()",
    )

    group_reports = relationship(
        "GroupReport",
        back_populates="reporter",
        foreign_keys="GroupReport.reporter_user_id",
        cascade="all, delete-orphan",
        order_by="GroupReport.id",
    )

    reviewed_group_reports = relationship(
        "GroupReport",
        back_populates="reviewer",
        foreign_keys="GroupReport.reviewed_by",
        order_by="GroupReport.id",
    )

    group_content_reports = relationship(
        "GroupContentReport",
        back_populates="reporter",
        foreign_keys="GroupContentReport.reporter_user_id",
        cascade="all, delete-orphan",
        order_by="GroupContentReport.id",
    )

    authored_reported_group_content = relationship(
        "GroupContentReport",
        back_populates="author",
        foreign_keys="GroupContentReport.author_user_id",
        order_by="GroupContentReport.id",
    )

    reviewed_group_content_reports = relationship(
        "GroupContentReport",
        back_populates="reviewer",
        foreign_keys="GroupContentReport.reviewed_by",
        order_by="GroupContentReport.id",
    )

    policy_acceptances = relationship(
        "UserPolicyAcceptance",
        back_populates="user",
        cascade="all, delete-orphan",
        order_by="UserPolicyAcceptance.accepted_at.desc()",
    )

    authored_group_news = relationship(
        "GroupNews",
        foreign_keys="GroupNews.author_user_id",
        cascade="all, delete-orphan",
        order_by="GroupNews.created_at.desc()",
    )

    received_private_group_news = relationship(
        "GroupNews",
        foreign_keys="GroupNews.recipient_user_id",
        order_by="GroupNews.created_at.desc()",
    )

    deleted_group_news = relationship(
        "GroupNews",
        foreign_keys="GroupNews.deleted_by_user_id",
        order_by="GroupNews.deleted_at.desc()",
    )

    moderated_group_news = relationship(
        "GroupNews",
        foreign_keys="GroupNews.moderated_by_user_id",
        order_by="GroupNews.moderated_at.desc()",
    )

    sent_group_news_reports = relationship(
        "GroupNewsReport",
        foreign_keys="GroupNewsReport.reporter_user_id",
        cascade="all, delete-orphan",
        order_by="GroupNewsReport.created_at.desc()",
    )

    received_group_news_reports = relationship(
        "GroupNewsReport",
        foreign_keys="GroupNewsReport.reported_author_user_id",
        order_by="GroupNewsReport.created_at.desc()",
    )

    reviewed_group_news_reports = relationship(
        "GroupNewsReport",
        foreign_keys="GroupNewsReport.reviewed_by_user_id",
        order_by="GroupNewsReport.reviewed_at.desc()",
    )

    blocked_users = relationship(
        "UserBlock",
        foreign_keys="UserBlock.blocker_user_id",
        cascade="all, delete-orphan",
        order_by="UserBlock.created_at.desc()",
    )

    blocked_by_users = relationship(
        "UserBlock",
        foreign_keys="UserBlock.blocked_user_id",
        cascade="all, delete-orphan",
        order_by="UserBlock.created_at.desc()",
    )


class UserAcademicPath(Base):
    __tablename__ = "user_academic_paths"

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

    university = Column(
        String(200),
        nullable=False,
    )

    university_code = Column(
        String(50),
        nullable=False,
    )

    department = Column(
        String(200),
        nullable=False,
    )

    department_code = Column(
        String(50),
        nullable=False,
    )

    course = Column(
        String(200),
        nullable=False,
    )

    course_code = Column(
        String(50),
        nullable=False,
    )

    degree_type = Column(
        String(50),
        nullable=True,
    )

    status = Column(
        String(30),
        nullable=False,
        default="enrolled",
        index=True,
    )

    verification_status = Column(
        String(30),
        nullable=False,
        default="not_required",
        index=True,
    )

    verified_by = Column(
        Integer,
        ForeignKey(
            "users.id",
            ondelete="SET NULL",
        ),
        nullable=True,
    )

    verified_at = Column(
        DateTime(
            timezone=True,
        ),
        nullable=True,
    )

    start_year = Column(
        Integer,
        nullable=True,
    )

    graduation_year = Column(
        Integer,
        nullable=True,
    )

    is_current = Column(
        Boolean,
        nullable=False,
        default=False,
        index=True,
    )

    is_primary = Column(
        Boolean,
        nullable=False,
        default=False,
        index=True,
    )

    user = relationship(
        "User",
        back_populates="academic_paths",
        foreign_keys=[
            user_id,
        ],
    )