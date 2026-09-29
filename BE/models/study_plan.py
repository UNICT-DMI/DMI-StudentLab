from datetime import datetime, timezone

from sqlalchemy import Boolean, CheckConstraint, Column, DateTime, Float, ForeignKey, Integer, JSON, String, Text, UniqueConstraint
from sqlalchemy.orm import relationship

from core.database import Base


def utc_now():
    return datetime.now(timezone.utc)


class StudyPlanItem(Base):
    __tablename__ = "study_plan_items"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "department",
            "course",
            "subject",
            "question_id",
            name="uq_study_plan_item_question",
        ),
        CheckConstraint(
            "status IN ('review','improving','consolidated')",
            name="chk_study_plan_item_status",
        ),
    )

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    department = Column(String(100), nullable=False, index=True)
    course = Column(String(100), nullable=False, index=True)
    subject = Column(String(255), nullable=False, index=True)
    argument = Column(String(255), nullable=True, index=True)
    question_id = Column(String(100), nullable=False, index=True)
    question_text = Column(Text, nullable=False, default="")
    options_snapshot = Column(JSON, nullable=False, default=list)
    correct_option_id = Column(String(100), nullable=True)
    correct_option_text = Column(Text, nullable=True)
    formal_explanation = Column(Text, nullable=True)
    informal_explanation = Column(Text, nullable=True)
    correct_answer_explanation = Column(Text, nullable=True)
    # v18 · tipo dell'elemento del ripasso ("multiple_choice" per le domande di sempre).
    question_type = Column(String(30), nullable=False, default="multiple_choice", server_default="multiple_choice")
    correct_payload = Column(JSON, nullable=True)
    mastery_percentage = Column(Float, nullable=False, default=0.0)
    status = Column(String(20), nullable=False, default="review", index=True)
    first_seen_at = Column(DateTime(timezone=True), nullable=False, default=utc_now)
    last_seen_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, index=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=utc_now)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, onupdate=utc_now)

    contributions = relationship(
        "StudyPlanContribution",
        back_populates="item",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )
    progress = relationship(
        "StudyPlanProgress",
        back_populates="item",
        cascade="all, delete-orphan",
        passive_deletes=True,
        uselist=False,
    )


class StudyPlanContribution(Base):
    __tablename__ = "study_plan_contributions"
    __table_args__ = (
        UniqueConstraint("item_id", "device_session_id", name="uq_study_plan_contribution_source"),
        UniqueConstraint("contribution_uuid", name="uq_study_plan_contribution_uuid"),
        CheckConstraint("source_type IN ('guest','authenticated')", name="chk_study_plan_contribution_source_type"),
        CheckConstraint("correct_count >= 0", name="chk_study_plan_contribution_correct"),
        CheckConstraint("wrong_count >= 0", name="chk_study_plan_contribution_wrong"),
        CheckConstraint("unanswered_count >= 0", name="chk_study_plan_contribution_unanswered"),
        CheckConstraint("review_count >= 0", name="chk_study_plan_contribution_review"),
        CheckConstraint("client_revision >= 0", name="chk_study_plan_contribution_revision"),
    )

    id = Column(Integer, primary_key=True, index=True)
    contribution_uuid = Column(String(128), nullable=False, index=True)
    item_id = Column(Integer, ForeignKey("study_plan_items.id", ondelete="CASCADE"), nullable=False, index=True)
    device_session_id = Column(Integer, ForeignKey("device_sessions.id", ondelete="CASCADE"), nullable=False, index=True)
    source_type = Column(String(20), nullable=False, index=True)
    source_user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    correct_count = Column(Integer, nullable=False, default=0)
    wrong_count = Column(Integer, nullable=False, default=0)
    unanswered_count = Column(Integer, nullable=False, default=0)
    review_count = Column(Integer, nullable=False, default=0)
    last_is_correct = Column(Boolean, nullable=True)
    last_selected_option_id = Column(String(100), nullable=True)
    last_selected_option_text = Column(Text, nullable=True)
    last_selected_answer_explanation = Column(Text, nullable=True)
    first_seen_at = Column(DateTime(timezone=True), nullable=False, default=utc_now)
    last_answered_at = Column(DateTime(timezone=True), nullable=True, index=True)
    client_revision = Column(Integer, nullable=False, default=0)
    created_at = Column(DateTime(timezone=True), nullable=False, default=utc_now)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, onupdate=utc_now)

    item = relationship("StudyPlanItem", back_populates="contributions")
    device_session = relationship("DeviceSession", back_populates="contributions")


class StudyPlanProgress(Base):
    __tablename__ = "study_plan_progress"
    __table_args__ = (
        UniqueConstraint("user_id", "item_id", name="uq_study_plan_progress_item"),
        CheckConstraint("total_reviews >= 0", name="chk_study_plan_progress_reviews"),
        CheckConstraint("successful_reviews >= 0", name="chk_study_plan_progress_success"),
        CheckConstraint("consecutive_correct >= 0", name="chk_study_plan_progress_streak"),
    )

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    item_id = Column(Integer, ForeignKey("study_plan_items.id", ondelete="CASCADE"), nullable=False, index=True)
    total_reviews = Column(Integer, nullable=False, default=0)
    successful_reviews = Column(Integer, nullable=False, default=0)
    consecutive_correct = Column(Integer, nullable=False, default=0)
    mastery_percentage = Column(Float, nullable=False, default=0.0)
    last_reviewed_at = Column(DateTime(timezone=True), nullable=True, index=True)
    completed_at = Column(DateTime(timezone=True), nullable=True, index=True)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, onupdate=utc_now)

    item = relationship("StudyPlanItem", back_populates="progress")
