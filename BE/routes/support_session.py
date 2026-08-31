from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_admin_user, get_current_user
from models.support_session import SupportRemoteAction
from models.user import User
from schemas.support_session import (
    SupportConsentRequest,
    SupportHeartbeatRequest,
    SupportRemoteActionAckRequest,
    SupportRemoteActionCreateRequest,
    SupportSessionAcceptRequest,
    SupportSessionCreateRequest,
    SupportSnapshotRequest,
)
from services.support_session import (
    accept_support_session,
    ack_remote_action,
    apply_consent,
    close_support_session,
    create_remote_action,
    create_snapshot,
    create_support_session,
    get_latest_snapshot,
    get_pending_actions,
    get_support_session,
    heartbeat_support_session,
    list_admin_sessions,
    list_user_sessions,
    require_user_session,
    revoke_support_consent,
    serialize_action,
    serialize_session,
    serialize_snapshot,
)

router = APIRouter(prefix="/support", tags=["support"])


def _not_found():
    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sessione di assistenza non trovata.")


@router.post("/sessions")
def create_my_support_session(request: SupportSessionCreateRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return serialize_session(create_support_session(
        db,
        user=current_user,
        issue_summary=request.issue_summary,
        issue_details=request.issue_details,
    ))


@router.get("/sessions/me")
def my_support_sessions(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return [serialize_session(item) for item in list_user_sessions(db, current_user.id)]


@router.get("/sessions/{session_id}")
def my_support_session(session_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    try:
        session = require_user_session(get_support_session(db, session_id), current_user.id)
    except ValueError:
        _not_found()
    return serialize_session(session)


@router.post("/sessions/{session_id}/consent")
def consent_support_session(session_id: int, request: SupportConsentRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    try:
        session = require_user_session(get_support_session(db, session_id), current_user.id)
        return serialize_session(apply_consent(db, session=session, accepted=request.accepted, scope=request.scope))
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.post("/sessions/{session_id}/heartbeat")
def support_heartbeat(session_id: int, request: SupportHeartbeatRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    try:
        session = require_user_session(get_support_session(db, session_id), current_user.id)
        return serialize_session(heartbeat_support_session(db, session=session))
    except PermissionError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.post("/sessions/{session_id}/snapshot")
def upload_support_snapshot(session_id: int, request: SupportSnapshotRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    try:
        session = require_user_session(get_support_session(db, session_id), current_user.id)
        snapshot = create_snapshot(
            db,
            session=session,
            user_id=current_user.id,
            app_version=request.app_version,
            platform=request.platform,
            database_version=request.database_version,
            payload=request.payload,
        )
        return serialize_snapshot(snapshot)
    except PermissionError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.get("/sessions/{session_id}/actions")
def my_pending_support_actions(session_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    try:
        session = require_user_session(get_support_session(db, session_id), current_user.id)
    except ValueError:
        _not_found()
    if session.status not in {"active", "disconnected"}:
        return []
    return [serialize_action(item) for item in get_pending_actions(db, session.id)]


@router.patch("/sessions/{session_id}/actions/{action_id}")
def ack_support_action(session_id: int, action_id: int, request: SupportRemoteActionAckRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    try:
        session = require_user_session(get_support_session(db, session_id), current_user.id)
    except ValueError:
        _not_found()
    action = db.query(SupportRemoteAction).filter(
        SupportRemoteAction.id == action_id,
        SupportRemoteAction.session_id == session.id,
    ).first()
    if action is None:
        raise HTTPException(status_code=404, detail="Azione non trovata.")
    return serialize_action(ack_remote_action(db, action=action, status=request.status, result=request.result))


@router.post("/sessions/{session_id}/revoke")
def revoke_my_support_session(session_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    try:
        session = require_user_session(get_support_session(db, session_id), current_user.id)
    except ValueError:
        _not_found()
    return serialize_session(revoke_support_consent(db, session=session))


@router.get("/admin/sessions")
def admin_support_sessions(session_status: str | None = Query(default=None, alias="status"), current_user: User = Depends(get_admin_user), db: Session = Depends(get_db)):
    return [serialize_session(item) for item in list_admin_sessions(db, session_status)]


@router.get("/admin/sessions/{session_id}")
def admin_support_session(session_id: int, current_user: User = Depends(get_admin_user), db: Session = Depends(get_db)):
    session = get_support_session(db, session_id)
    if session is None:
        _not_found()
    snapshot = get_latest_snapshot(db, session_id)
    return {
        "session": serialize_session(session),
        "latest_snapshot": serialize_snapshot(snapshot) if snapshot is not None else None,
        "pending_actions": [serialize_action(item) for item in get_pending_actions(db, session_id)],
    }


@router.post("/admin/sessions/{session_id}/accept")
def admin_accept_support_session(session_id: int, request: SupportSessionAcceptRequest, current_user: User = Depends(get_admin_user), db: Session = Depends(get_db)):
    session = get_support_session(db, session_id)
    if session is None:
        _not_found()
    try:
        return serialize_session(accept_support_session(db, session=session, admin=current_user, session_minutes=request.session_minutes))
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.post("/admin/sessions/{session_id}/actions")
def admin_create_support_action(session_id: int, request: SupportRemoteActionCreateRequest, current_user: User = Depends(get_admin_user), db: Session = Depends(get_db)):
    session = get_support_session(db, session_id)
    if session is None:
        _not_found()
    try:
        return serialize_action(create_remote_action(db, session=session, admin=current_user, action=request.action, payload=request.payload))
    except PermissionError as exc:
        raise HTTPException(status_code=403, detail=str(exc))
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.post("/admin/sessions/{session_id}/close")
def admin_close_support_session(session_id: int, resolved: bool = Query(default=True), current_user: User = Depends(get_admin_user), db: Session = Depends(get_db)):
    session = get_support_session(db, session_id)
    if session is None:
        _not_found()
    return serialize_session(close_support_session(db, session=session, resolved=resolved))
