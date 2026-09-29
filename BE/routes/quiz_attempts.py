from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_current_user
from models.user import User
from schemas.quiz_attempt import (
    QuizAttemptDetailResponse,
    QuizAttemptHistoryResponse,
    QuizAttemptResponse,
    QuizAttemptStart,
    QuizAttemptSubmit,
)
from services.quiz_attempt_service import (
    complete_quiz_attempt,
    delete_quiz_attempt,
    get_quiz_attempt_by_id,
    get_student_quiz_history,
    hide_quiz_attempt_from_history,
    register_attempt_interruption,
    restore_quiz_attempt_to_history,
    resume_quiz_attempt,
    start_assigned_quiz_attempt,
    start_quiz_attempt,
)


router = APIRouter(prefix="/quiz-attempts", tags=["quiz-attempts"])


def _raise(exc: Exception):
    if isinstance(exc, PermissionError):
        raise HTTPException(status_code=403, detail=str(exc)) from exc
    raise HTTPException(status_code=400, detail=str(exc)) from exc


def _raise_internal(db: Session, message: str):
    db.rollback()
    raise HTTPException(status_code=500, detail=message)


@router.post("/start")
def api_start_quiz_attempt(
    data: QuizAttemptStart,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        return start_quiz_attempt(db, current_user, data)
    except (ValueError, PermissionError) as exc:
        _raise(exc)
    except Exception:
        _raise_internal(db, "Non è stato possibile avviare il quiz.")


@router.post("/assignments/{assignment_id}/start")
def api_start_assigned_quiz_attempt(
    assignment_id: int,
    supported_types: str | None = Query(default=None, max_length=400),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # v18: l'app dichiara quali tipi di esercizio sa mostrare (es. "ordina,abbina,grafo").
    # Le versioni precedenti non lo mandano e ricevono solo domande a risposta multipla.
    supported = {value.strip() for value in (supported_types or "").split(",") if value.strip()}
    try:
        return start_assigned_quiz_attempt(db, current_user, assignment_id, supported)
    except (ValueError, PermissionError) as exc:
        _raise(exc)
    except Exception:
        _raise_internal(db, "Non è stato possibile avviare il quiz assegnato.")


@router.get("/{attempt_id}/resume")
def api_resume_quiz_attempt(
    attempt_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        return resume_quiz_attempt(db, current_user, attempt_id)
    except (ValueError, PermissionError) as exc:
        _raise(exc)
    except Exception:
        _raise_internal(db, "Non è stato possibile riprendere il quiz.")


@router.post("/{attempt_id}/interruption", response_model=QuizAttemptResponse)
def api_register_quiz_interruption(
    attempt_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        return register_attempt_interruption(db, current_user, attempt_id)
    except (ValueError, PermissionError) as exc:
        _raise(exc)
    except Exception:
        _raise_internal(db, "Non è stato possibile registrare l'interruzione del quiz.")


@router.post("/{attempt_id}/complete", response_model=QuizAttemptDetailResponse)
def api_complete_quiz_attempt(
    attempt_id: int,
    data: QuizAttemptSubmit,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        return complete_quiz_attempt(db, current_user, attempt_id, data)
    except (ValueError, PermissionError) as exc:
        _raise(exc)
    except Exception:
        _raise_internal(db, "Non è stato possibile completare il quiz.")


@router.get("/me", response_model=QuizAttemptHistoryResponse)
def api_my_quiz_history(
    include_hidden: bool = Query(False),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        return get_student_quiz_history(
            db,
            current_user.id,
            include_hidden=include_hidden,
            limit=limit,
            offset=offset,
        )
    except Exception:
        _raise_internal(db, "Non è stato possibile caricare lo storico dei quiz.")


@router.get("/{attempt_id}", response_model=QuizAttemptDetailResponse)
def api_get_quiz_attempt(
    attempt_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        attempt = get_quiz_attempt_by_id(db, attempt_id)
        if attempt is None or attempt.is_deleted:
            raise HTTPException(status_code=404, detail="Tentativo non trovato.")
        if attempt.user_id != current_user.id and current_user.role not in {"admin", "creator", "teacher"}:
            raise HTTPException(status_code=403, detail="Non puoi visualizzare questo tentativo.")
        return attempt
    except HTTPException:
        raise
    except Exception:
        _raise_internal(db, "Non è stato possibile caricare il tentativo.")


@router.post("/{attempt_id}/hide", response_model=QuizAttemptResponse)
def api_hide_quiz_attempt(
    attempt_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    attempt = get_quiz_attempt_by_id(db, attempt_id)
    if attempt is None or attempt.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Tentativo non trovato.")
    try:
        return hide_quiz_attempt_from_history(db, attempt, current_user)
    except (ValueError, PermissionError) as exc:
        _raise(exc)
    except Exception:
        _raise_internal(db, "Non è stato possibile nascondere il tentativo.")


@router.post("/{attempt_id}/restore", response_model=QuizAttemptResponse)
def api_restore_quiz_attempt(
    attempt_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    attempt = get_quiz_attempt_by_id(db, attempt_id)
    if attempt is None or attempt.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Tentativo non trovato.")
    try:
        return restore_quiz_attempt_to_history(db, attempt)
    except (ValueError, PermissionError) as exc:
        _raise(exc)
    except Exception:
        _raise_internal(db, "Non è stato possibile ripristinare il tentativo.")


@router.delete("/{attempt_id}")
def api_delete_quiz_attempt(
    attempt_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    attempt = get_quiz_attempt_by_id(db, attempt_id)
    if attempt is None or attempt.user_id != current_user.id:
        raise HTTPException(status_code=404, detail="Tentativo non trovato.")
    try:
        delete_quiz_attempt(db, attempt, current_user)
    except (ValueError, PermissionError) as exc:
        _raise(exc)
    except Exception:
        _raise_internal(db, "Non è stato possibile eliminare il tentativo.")
    return {"success": True}
