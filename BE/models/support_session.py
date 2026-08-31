from datetime import datetime, timezone

from sqlalchemy import CheckConstraint, Column, DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import relationship

from core.database import Base


def utc_now():
    return datetime.now(timezone.utc)


class SupportSession(Base):
    __tablename__ = "support_sessions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    assigned_admin_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    issue_summary = Column(String(500), nullable=False)
    issue_details = Column(Text, nullable=True)
    status = Column(String(30), nullable=False, default="requested", index=True)
    consent_scope = Column(String(30), nullable=True)
    consent_granted_at = Column(DateTime(timezone=True), nullable=True)
    consent_revoked_at = Column(DateTime(timezone=True), nullable=True)
    last_heartbeat_at = Column(DateTime(timezone=True), nullable=True, index=True)
    expires_at = Column(DateTime(timezone=True), nullable=True, index=True)
    closed_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, index=True)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, onupdate=utc_now, index=True)

    user = relationship("User", foreign_keys=[user_id])
    assigned_admin = relationship("User", foreign_keys=[assigned_admin_id])
    snapshots = relationship(
        "SupportDiagnosticSnapshot",
        back_populates="session",
        cascade="all, delete-orphan",
        order_by="SupportDiagnosticSnapshot.created_at.desc()",
    )
    actions = relationship(
        "SupportRemoteAction",
        back_populates="session",
        cascade="all, delete-orphan",
        order_by="SupportRemoteAction.created_at.desc()",
    )

    __table_args__ = (
        CheckConstraint(
            "status IN ('requested','waiting_consent','active','disconnected','resolved','cancelled','expired')",
            name="chk_support_session_status",
        ),
        CheckConstraint(
            "consent_scope IS NULL OR consent_scope IN ('diagnostic','full_sqlite')",
            name="chk_support_session_consent_scope",
        ),
    )


class SupportDiagnosticSnapshot(Base):
    __tablename__ = "support_diagnostic_snapshots"

    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("support_sessions.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    app_version = Column(String(100), nullable=True)
    platform = Column(String(100), nullable=True)
    database_version = Column(Integer, nullable=True)
    payload_json = Column(Text, nullable=False)
    created_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, index=True)

    session = relationship("SupportSession", back_populates="snapshots")
    user = relationship("User", foreign_keys=[user_id])


class SupportRemoteAction(Base):
    __tablename__ = "support_remote_actions"

    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("support_sessions.id", ondelete="CASCADE"), nullable=False, index=True)
    action = Column(String(60), nullable=False, index=True)
    payload_json = Column(Text, nullable=True)
    status = Column(String(30), nullable=False, default="pending", index=True)
    issued_by = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    result_json = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, index=True)
    started_at = Column(DateTime(timezone=True), nullable=True)
    completed_at = Column(DateTime(timezone=True), nullable=True)

    session = relationship("SupportSession", back_populates="actions")
    issuer = relationship("User", foreign_keys=[issued_by])

    __table_args__ = (
        CheckConstraint(
            "action IN ('collect_diagnostics','force_material_sync','clear_remote_cache','purge_stale_remote_materials','refresh_manifest')",
            name="chk_support_remote_action_type",
        ),
        CheckConstraint(
            "status IN ('pending','running','completed','failed','rejected')",
            name="chk_support_remote_action_status",
        ),
    )
