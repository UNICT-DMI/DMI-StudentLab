from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from core.config import settings
from core.database import get_db
from core.security import get_current_user
from models.user import User
from schemas.auth import (
    EmailChangeCompleteRequest,
    EmailChangeCompleteResponse,
    EmailChangeStartRequest,
    EmailChangeStartResponse,
    PasswordChangeRequest,
    PasswordChangeResponse,
    PasswordResetCompleteRequest,
    PasswordResetCompleteResponse,
    PasswordResetStartRequest,
    PasswordResetStartResponse,
    PendingRegistrationEmailUpdateRequest,
    PendingRegistrationUpdateResponse,
)
from services.account_security import (
    begin_email_change,
    begin_password_reset,
    change_password,
    complete_email_change,
    complete_password_reset,
    update_pending_registration_email,
)


router = APIRouter(prefix="/auth", tags=["account-security"])


@router.post(
    "/password/forgot",
    response_model=PasswordResetStartResponse,
)
def api_password_forgot(
    request: PasswordResetStartRequest,
    db: Session = Depends(get_db),
):
    try:
        request_id = begin_password_reset(
            db,
            email=request.email,
            secret_key=settings.secret_key,
        )
    except RuntimeError:
        raise HTTPException(
            status_code=503,
            detail="Non è stato possibile inviare il codice di recupero. Riprova.",
        )

    return PasswordResetStartResponse(
        request_id=request_id,
        message=(
            "Se l'email è associata a un account StudentLab, "
            "riceverai un codice per impostare una nuova password."
        ),
    )


@router.post(
    "/password/reset",
    response_model=PasswordResetCompleteResponse,
)
def api_password_reset(
    request: PasswordResetCompleteRequest,
    db: Session = Depends(get_db),
):
    try:
        complete_password_reset(
            db,
            request_id=request.request_id,
            code=request.code,
            new_password=request.new_password,
            secret_key=settings.secret_key,
        )
    except ValueError as exception:
        raise HTTPException(
            status_code=400,
            detail=str(exception),
        )

    return PasswordResetCompleteResponse(
        success=True,
        message="Password aggiornata. Ora puoi accedere con la nuova password.",
    )


@router.post(
    "/password/change",
    response_model=PasswordChangeResponse,
)
def api_password_change(
    request: PasswordChangeRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        change_password(
            db,
            user=current_user,
            current_password=request.current_password,
            new_password=request.new_password,
        )
    except ValueError as exception:
        raise HTTPException(
            status_code=400,
            detail=str(exception),
        )

    return PasswordChangeResponse(
        success=True,
        message="Password aggiornata.",
    )


@router.post(
    "/email/change/start",
    response_model=EmailChangeStartResponse,
)
def api_email_change_start(
    request: EmailChangeStartRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        request_id, new_email = begin_email_change(
            db,
            user=current_user,
            current_password=request.current_password,
            new_email=request.new_email,
            secret_key=settings.secret_key,
        )
    except ValueError as exception:
        raise HTTPException(
            status_code=400,
            detail=str(exception),
        )
    except RuntimeError:
        raise HTTPException(
            status_code=503,
            detail="Non è stato possibile inviare il codice alla nuova email. Riprova.",
        )

    return EmailChangeStartResponse(
        request_id=request_id,
        new_email=new_email,
        message="Codice inviato alla nuova email.",
    )


@router.post(
    "/email/change/complete",
    response_model=EmailChangeCompleteResponse,
)
def api_email_change_complete(
    request: EmailChangeCompleteRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        email = complete_email_change(
            db,
            user=current_user,
            request_id=request.request_id,
            code=request.code,
            secret_key=settings.secret_key,
        )
    except ValueError as exception:
        raise HTTPException(
            status_code=400,
            detail=str(exception),
        )

    return EmailChangeCompleteResponse(
        success=True,
        email=email,
        message="Email aggiornata e verificata.",
    )


@router.post(
    "/registration/email/change",
    response_model=PendingRegistrationUpdateResponse,
)
def api_pending_registration_email_change(
    request: PendingRegistrationEmailUpdateRequest,
    db: Session = Depends(get_db),
):
    try:
        user, expires_in = update_pending_registration_email(
            db,
            registration_id=request.registration_id,
            current_password=request.current_password,
            new_email=request.new_email,
            secret_key=settings.secret_key,
        )
    except ValueError as exception:
        raise HTTPException(
            status_code=400,
            detail=str(exception),
        )
    except RuntimeError:
        raise HTTPException(
            status_code=503,
            detail="Non è stato possibile inviare il codice alla nuova email. Riprova.",
        )

    return PendingRegistrationUpdateResponse(
        registration_id=request.registration_id,
        email=user.email,
        expires_in=expires_in,
        message="Email aggiornata. Inserisci il codice inviato al nuovo indirizzo.",
    )
