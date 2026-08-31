import json
from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session

from models.support_session import SupportDiagnosticSnapshot, SupportRemoteAction, SupportSession
from models.user import User

ONLINE_WINDOW = timedelta(seconds=90)


def utc_now():
    return datetime.now(timezone.utc)


def _json_dump(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"), sort_keys=True)


def _json_load(value):
    if not value:
        return None
    try:
        return json.loads(value)
    except Exception:
        return None


def _is_online(session: SupportSession):
    if session.status != "active" or session.last_heartbeat_at is None:
        return False
    heartbeat = session.last_heartbeat_at
    if heartbeat.tzinfo is None:
        heartbeat = heartbeat.replace(tzinfo=timezone.utc)
    return utc_now() - heartbeat <= ONLINE_WINDOW


def serialize_session(session: SupportSession):
    return {
        "id": session.id,
        "user_id": session.user_id,
        "assigned_admin_id": session.assigned_admin_id,
        "issue_summary": session.issue_summary,
        "issue_details": session.issue_details,
        "status": session.status,
        "consent_scope": session.consent_scope,
        "consent_granted_at": session.consent_granted_at,
        "consent_revoked_at": session.consent_revoked_at,
        "last_heartbeat_at": session.last_heartbeat_at,
        "expires_at": session.expires_at,
        "closed_at": session.closed_at,
        "created_at": session.created_at,
        "updated_at": session.updated_at,
        "is_online": _is_online(session),
    }


def serialize_action(action: SupportRemoteAction):
    return {
        "id": action.id,
        "session_id": action.session_id,
        "action": action.action,
        "status": action.status,
        "payload": _json_load(action.payload_json),
        "result": _json_load(action.result_json),
        "issued_by": action.issued_by,
        "created_at": action.created_at,
        "started_at": action.started_at,
        "completed_at": action.completed_at,
    }


def serialize_snapshot(snapshot: SupportDiagnosticSnapshot):
    return {
        "id": snapshot.id,
        "session_id": snapshot.session_id,
        "user_id": snapshot.user_id,
        "app_version": snapshot.app_version,
        "platform": snapshot.platform,
        "database_version": snapshot.database_version,
        "payload": _json_load(snapshot.payload_json) or {},
        "created_at": snapshot.created_at,
    }


def create_support_session(db: Session, *, user: User, issue_summary: str, issue_details: str | None):
    open_session = (
        db.query(SupportSession)
        .filter(
            SupportSession.user_id == user.id,
            SupportSession.status.in_(["requested", "waiting_consent", "active", "disconnected"]),
        )
        .order_by(SupportSession.id.desc())
        .first()
    )
    if open_session is not None:
        return open_session

    session = SupportSession(
        user_id=user.id,
        issue_summary=issue_summary.strip(),
        issue_details=issue_details.strip() if issue_details else None,
        status="requested",
    )
    db.add(session)
    db.commit()
    db.refresh(session)
    return session


def get_support_session(db: Session, session_id: int):
    return db.query(SupportSession).filter(SupportSession.id == session_id).first()


def require_user_session(session: SupportSession | None, user_id: int):
    if session is None or session.user_id != user_id:
        raise ValueError("Sessione di assistenza non trovata.")
    return session


def list_user_sessions(db: Session, user_id: int):
    return db.query(SupportSession).filter(SupportSession.user_id == user_id).order_by(SupportSession.created_at.desc()).all()


def list_admin_sessions(db: Session, status: str | None = None):
    query = db.query(SupportSession)
    if status:
        query = query.filter(SupportSession.status == status)
    return query.order_by(SupportSession.updated_at.desc()).all()


def accept_support_session(db: Session, *, session: SupportSession, admin: User, session_minutes: int):
    if session.status not in {"requested", "disconnected"}:
        raise ValueError("La richiesta non può essere accettata nello stato attuale.")
    now = utc_now()
    session.assigned_admin_id = admin.id
    session.status = "waiting_consent"
    session.expires_at = now + timedelta(minutes=session_minutes)
    session.updated_at = now
    db.commit()
    db.refresh(session)
    return session


def apply_consent(db: Session, *, session: SupportSession, accepted: bool, scope: str):
    if session.status not in {"waiting_consent", "active", "disconnected"}:
        raise ValueError("La sessione non è in attesa di consenso.")
    now = utc_now()
    if not accepted:
        session.status = "cancelled"
        session.consent_revoked_at = now
        session.closed_at = now
    else:
        session.status = "active"
        session.consent_scope = scope
        session.consent_granted_at = now
        session.consent_revoked_at = None
        session.last_heartbeat_at = now
    session.updated_at = now
    db.commit()
    db.refresh(session)
    return session


def heartbeat_support_session(db: Session, *, session: SupportSession):
    now = utc_now()
    if session.expires_at is not None:
        expires = session.expires_at
        if expires.tzinfo is None:
            expires = expires.replace(tzinfo=timezone.utc)
        if now >= expires:
            session.status = "expired"
            session.closed_at = now
            session.updated_at = now
            db.commit()
            db.refresh(session)
            raise ValueError("La sessione di assistenza è scaduta.")
    if session.status not in {"active", "disconnected"}:
        raise ValueError("La sessione di assistenza non è attiva.")
    if session.consent_granted_at is None or session.consent_revoked_at is not None:
        raise PermissionError("Il consenso diagnostico non è attivo.")
    session.status = "active"
    session.last_heartbeat_at = now
    session.updated_at = now
    db.commit()
    db.refresh(session)
    return session


def revoke_support_consent(db: Session, *, session: SupportSession):
    now = utc_now()
    session.status = "cancelled"
    session.consent_revoked_at = now
    session.closed_at = now
    session.updated_at = now
    db.commit()
    db.refresh(session)
    return session


def close_support_session(db: Session, *, session: SupportSession, resolved: bool):
    now = utc_now()
    session.status = "resolved" if resolved else "cancelled"
    session.closed_at = now
    session.updated_at = now
    db.commit()
    db.refresh(session)
    return session


def create_snapshot(db: Session, *, session: SupportSession, user_id: int, app_version: str | None, platform: str | None, database_version: int | None, payload: dict):
    if session.status != "active":
        raise ValueError("La sessione di assistenza non è attiva.")
    if session.consent_granted_at is None or session.consent_revoked_at is not None:
        raise PermissionError("Il consenso diagnostico non è attivo.")
    encoded = _json_dump(payload)
    if len(encoded.encode("utf-8")) > 1_500_000:
        raise ValueError("Snapshot diagnostico troppo grande.")
    snapshot = SupportDiagnosticSnapshot(
        session_id=session.id,
        user_id=user_id,
        app_version=app_version,
        platform=platform,
        database_version=database_version,
        payload_json=encoded,
    )
    db.add(snapshot)
    db.commit()
    db.refresh(snapshot)
    return snapshot


def get_latest_snapshot(db: Session, session_id: int):
    return db.query(SupportDiagnosticSnapshot).filter(SupportDiagnosticSnapshot.session_id == session_id).order_by(SupportDiagnosticSnapshot.created_at.desc()).first()


def create_remote_action(db: Session, *, session: SupportSession, admin: User, action: str, payload: dict | None):
    if session.status not in {"active", "disconnected"}:
        raise ValueError("La sessione non è attiva.")
    if session.consent_granted_at is None or session.consent_revoked_at is not None:
        raise PermissionError("Il consenso diagnostico non è attivo.")
    remote_action = SupportRemoteAction(
        session_id=session.id,
        action=action,
        payload_json=_json_dump(payload) if payload else None,
        status="pending",
        issued_by=admin.id,
    )
    db.add(remote_action)
    db.commit()
    db.refresh(remote_action)
    return remote_action


def get_pending_actions(db: Session, session_id: int):
    return db.query(SupportRemoteAction).filter(
        SupportRemoteAction.session_id == session_id,
        SupportRemoteAction.status.in_(["pending", "running"]),
    ).order_by(SupportRemoteAction.created_at.asc()).all()


def ack_remote_action(db: Session, *, action: SupportRemoteAction, status: str, result: dict | None):
    now = utc_now()
    action.started_at = action.started_at or now
    if status != "running":
        action.completed_at = now
    action.status = status
    action.result_json = _json_dump(result) if result else None
    db.commit()
    db.refresh(action)
    return action
