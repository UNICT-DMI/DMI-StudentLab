from datetime import datetime, timezone

from sqlalchemy import Boolean, CheckConstraint, Column, DateTime, Float, ForeignKey, Integer, JSON, String, Text, UniqueConstraint
from sqlalchemy.orm import relationship

from core.database import Base


def utc_now():
    return datetime.now(timezone.utc)


class QuizAttempt(Base):
    __tablename__ = "quiz_attempts"
    __table_args__ = (
        UniqueConstraint("user_id", "assignment_id", name="uq_quiz_attempt_user_assignment"),
        CheckConstraint("execution_mode IN ('practice','simulation')", name="chk_quiz_attempt_execution_mode"),
        CheckConstraint("external_activity_policy IN ('disabled','structured_devices')", name="chk_quiz_attempt_external_activity_policy"),
        CheckConstraint(
            "completion_reason IS NULL OR completion_reason IN ('completed','time_expired','user_confirmed_exit','app_backgrounded','external_activity_detected','session_abandoned')",
            name="chk_quiz_attempt_completion_reason",
        ),
        CheckConstraint("interruption_count >= 0", name="chk_quiz_attempt_interruption_count"),
    )

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    assignment_id = Column(Integer, ForeignKey("quiz_assignments.id", ondelete="SET NULL"), nullable=True, index=True)
    department = Column(String(100), nullable=False, index=True)
    course = Column(String(100), nullable=False, index=True)
    subject = Column(String(255), nullable=False, index=True)
    selected_arguments = Column(JSON, nullable=False, default=list)
    question_ids = Column(JSON, nullable=False, default=list)
    questions_snapshot = Column(JSON, nullable=False, default=list)
    question_count = Column(Integer, nullable=False)
    correct_count = Column(Integer, nullable=False, default=0)
    wrong_count = Column(Integer, nullable=False, default=0)
    unanswered_count = Column(Integer, nullable=False, default=0)
    percentage = Column(Float, nullable=False, default=0.0)
    time_limit_seconds = Column(Integer, nullable=True)
    elapsed_seconds = Column(Integer, nullable=True)
    execution_mode = Column(String(20), nullable=False, default="practice", server_default="practice", index=True)
    external_activity_policy = Column(String(30), nullable=False, default="disabled", server_default="disabled", index=True)
    completion_reason = Column(String(40), nullable=True, index=True)
    interruption_count = Column(Integer, nullable=False, default=0, server_default="0")
    last_interrupted_at = Column(DateTime(timezone=True), nullable=True)
    status = Column(String(30), nullable=False, default="in_progress", index=True)
    started_at = Column(DateTime(timezone=True), nullable=False, default=utc_now)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    is_hidden_from_history = Column(Boolean, nullable=False, default=False, index=True)
    hidden_from_history_at = Column(DateTime(timezone=True), nullable=True)
    hidden_from_history_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    is_deleted = Column(Boolean, nullable=False, default=False, index=True)
    deleted_at = Column(DateTime(timezone=True), nullable=True)
    deleted_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=utc_now)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, onupdate=utc_now)

    answers = relationship("QuizAttemptAnswer", cascade="all, delete-orphan", passive_deletes=True)


class QuizAttemptAnswer(Base):
    __tablename__ = "quiz_attempt_answers"
    __table_args__ = (UniqueConstraint("attempt_id", "question_id", name="uq_quiz_attempt_answer_question"),)

    id = Column(Integer, primary_key=True, index=True)
    attempt_id = Column(Integer, ForeignKey("quiz_attempts.id", ondelete="CASCADE"), nullable=False, index=True)
    question_id = Column(String(100), nullable=False, index=True)
    argument = Column(String(255), nullable=True, index=True)
    question_text = Column(Text, nullable=False)
    attachments_snapshot = Column(JSON, nullable=False, default=list)
    options_snapshot = Column(JSON, nullable=False, default=list)
    selected_option_id = Column(String(100), nullable=True)
    selected_option_text = Column(Text, nullable=True)
    correct_option_id = Column(String(100), nullable=False)
    correct_option_text = Column(Text, nullable=False)
    is_answered = Column(Boolean, nullable=False, default=False)
    is_correct = Column(Boolean, nullable=False, default=False)
    response_time_seconds = Column(Integer, nullable=True)
    formal_explanation = Column(Text, nullable=True)
    informal_explanation = Column(Text, nullable=True)
    selected_answer_explanation = Column(Text, nullable=True)
    correct_answer_explanation = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=utc_now)