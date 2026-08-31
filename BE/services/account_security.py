from datetime import datetime, timezone
from email.message import EmailMessage
import smtplib
import ssl
from uuid import uuid4

from sqlalchemy.orm import Session

from core.config import settings
from models.account_security import EmailChangeRequest, PasswordResetRequest
from models.user import User
from services.auth import (
    generate_email_verification_code,
    get_user_by_registration_id,
    hash_email_verification_code,
    hash_password,
    normalize_email,
    prepare_email_verification,
    send_email_verification_code,
    verify_email_verification_code_hash,
    verify_password,
)
from services.password_policy import validate_password_policy


SECURITY_CODE_MAX_ATTEMPTS = 5
PASSWORD_RESET_RESEND_COOLDOWN_SECONDS = 60


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _send_security_code(
    *,
    email: str,
    code: str,
    subject: str,
    intro: str,
) -> None:
    smtp_host = settings.smtp_host
    smtp_username = settings.smtp_username
    smtp_password = settings.smtp_password
    smtp_from_email = settings.smtp_from_email
    smtp_from_name = settings.smtp_from_name

    if not smtp_host:
        raise RuntimeError("Email service not configured.")
    if not smtp_from_email:
        raise RuntimeError("Email sender not configured.")

    message = EmailMessage()
    message["Subject"] = subject
    message["From"] = f"{smtp_from_name} <{smtp_from_email}>"
    message["To"] = email
    message.set_content(
        f"{intro}\n\n"
        f"Codice StudentLab:\n\n{code}\n\n"
        "Questo codice non ha una scadenza temporale, ma è monouso. "
        "Se richiedi un nuovo codice, quello precedente viene invalidato.\n\n"
        "Se non hai richiesto questa operazione, ignora questa email."
    )

    if settings.smtp_use_ssl:
        context = ssl.create_default_context()
        with smtplib.SMTP_SSL(
            smtp_host,
            settings.smtp_port,
            context=context,
            timeout=20,
        ) as smtp:
            if smtp_username:
                smtp.login(smtp_username, smtp_password)
            smtp.send_message(message)
        return

    with smtplib.SMTP(
        smtp_host,
        settings.smtp_port,
        timeout=20,
    ) as smtp:
        smtp.ehlo()
        if settings.smtp_use_tls:
            context = ssl.create_default_context()
            smtp.starttls(context=context)
            smtp.ehlo()
        if smtp_username:
            smtp.login(smtp_username, smtp_password)
        smtp.send_message(message)


def _invalidate_password_reset_requests(
    db: Session,
    user_id: int,
) -> None:
    now = _now()
    (
        db.query(PasswordResetRequest)
        .filter(
            PasswordResetRequest.user_id == user_id,
            PasswordResetRequest.used_at.is_(None),
            PasswordResetRequest.invalidated_at.is_(None),
        )
        .update(
            {"invalidated_at": now},
            synchronize_session=False,
        )
    )


def _invalidate_email_change_requests(
    db: Session,
    user_id: int,
) -> None:
    now = _now()
    (
        db.query(EmailChangeRequest)
        .filter(
            EmailChangeRequest.user_id == user_id,
            EmailChangeRequest.used_at.is_(None),
            EmailChangeRequest.invalidated_at.is_(None),
        )
        .update(
            {"invalidated_at": now},
            synchronize_session=False,
        )
    )


def begin_password_reset(
    db: Session,
    *,
    email: str,
    secret_key: str,
) -> str:
    normalized_email = normalize_email(email)
    user = (
        db.query(User)
        .filter(User.email == normalized_email)
        .first()
    )

    if user is None or not user.is_active:
        return uuid4().hex

    latest = (
        db.query(PasswordResetRequest)
        .filter(
            PasswordResetRequest.user_id == user.id,
            PasswordResetRequest.used_at.is_(None),
            PasswordResetRequest.invalidated_at.is_(None),
        )
        .order_by(PasswordResetRequest.created_at.desc())
        .first()
    )

    if latest is not None:
        last_sent = latest.last_sent_at
        if last_sent.tzinfo is None:
            last_sent = last_sent.replace(tzinfo=timezone.utc)
        elapsed = (_now() - last_sent).total_seconds()
        if elapsed < PASSWORD_RESET_RESEND_COOLDOWN_SECONDS:
            return latest.request_id

    _invalidate_password_reset_requests(
        db,
        user.id,
    )

    request_id = uuid4().hex
    code = generate_email_verification_code()
    request = PasswordResetRequest(
        request_id=request_id,
        user_id=user.id,
        code_hash=hash_email_verification_code(
            code=code,
            registration_id=request_id,
            secret_key=secret_key,
        ),
        attempts=0,
        last_sent_at=_now(),
    )

    try:
        db.add(request)
        db.commit()
        db.refresh(request)
    except Exception:
        db.rollback()
        raise

    try:
        _send_security_code(
            email=user.email,
            code=code,
            subject="Recupero password StudentLab",
            intro="Hai richiesto di impostare una nuova password per il tuo account StudentLab.",
        )
    except Exception:
        request.invalidated_at = _now()
        try:
            db.commit()
        except Exception:
            db.rollback()
        raise RuntimeError("Non è stato possibile inviare il codice di recupero.")

    return request_id


def complete_password_reset(
    db: Session,
    *,
    request_id: str,
    code: str,
    new_password: str,
    secret_key: str,
) -> User:
    validate_password_policy(new_password)

    request = (
        db.query(PasswordResetRequest)
        .filter(PasswordResetRequest.request_id == request_id)
        .first()
    )

    if (
        request is None
        or request.used_at is not None
        or request.invalidated_at is not None
    ):
        raise ValueError("Codice di recupero non valido.")

    if request.attempts >= SECURITY_CODE_MAX_ATTEMPTS:
        request.invalidated_at = _now()
        db.commit()
        raise ValueError("Hai effettuato troppi tentativi. Richiedi un nuovo codice.")

    valid = verify_email_verification_code_hash(
        code=code,
        registration_id=request.request_id,
        expected_hash=request.code_hash,
        secret_key=secret_key,
    )

    if not valid:
        request.attempts += 1
        if request.attempts >= SECURITY_CODE_MAX_ATTEMPTS:
            request.invalidated_at = _now()
        db.commit()
        raise ValueError("Il codice non è corretto.")

    user = (
        db.query(User)
        .filter(User.id == request.user_id)
        .first()
    )

    if user is None or not user.is_active:
        raise ValueError("Account non disponibile.")

    user.password_hash = hash_password(new_password)
    request.used_at = _now()

    _invalidate_password_reset_requests(
        db,
        user.id,
    )
    request.used_at = _now()
    request.invalidated_at = None

    try:
        db.commit()
        db.refresh(user)
    except Exception:
        db.rollback()
        raise

    return user


def change_password(
    db: Session,
    *,
    user: User,
    current_password: str,
    new_password: str,
) -> None:
    validate_password_policy(new_password)

    if not verify_password(
        current_password,
        user.password_hash,
    ):
        raise ValueError("La password attuale non è corretta.")

    if verify_password(
        new_password,
        user.password_hash,
    ):
        raise ValueError("La nuova password deve essere diversa da quella attuale.")

    user.password_hash = hash_password(new_password)
    _invalidate_password_reset_requests(
        db,
        user.id,
    )

    try:
        db.commit()
    except Exception:
        db.rollback()
        raise


def begin_email_change(
    db: Session,
    *,
    user: User,
    current_password: str,
    new_email: str,
    secret_key: str,
) -> tuple[str, str]:
    if not verify_password(
        current_password,
        user.password_hash,
    ):
        raise ValueError("La password attuale non è corretta.")

    normalized_email = normalize_email(new_email)

    if normalized_email == user.email:
        raise ValueError("La nuova email coincide con quella attuale.")

    existing = (
        db.query(User)
        .filter(
            User.email == normalized_email,
            User.id != user.id,
        )
        .first()
    )
    if existing is not None:
        raise ValueError("Email già registrata.")

    _invalidate_email_change_requests(
        db,
        user.id,
    )

    request_id = uuid4().hex
    code = generate_email_verification_code()
    request = EmailChangeRequest(
        request_id=request_id,
        user_id=user.id,
        new_email=normalized_email,
        code_hash=hash_email_verification_code(
            code=code,
            registration_id=request_id,
            secret_key=secret_key,
        ),
        attempts=0,
        last_sent_at=_now(),
    )

    try:
        db.add(request)
        db.commit()
        db.refresh(request)
    except Exception:
        db.rollback()
        raise

    try:
        _send_security_code(
            email=normalized_email,
            code=code,
            subject="Conferma nuova email StudentLab",
            intro="Usa questo codice per confermare la nuova email del tuo account StudentLab.",
        )
    except Exception:
        request.invalidated_at = _now()
        try:
            db.commit()
        except Exception:
            db.rollback()
        raise RuntimeError("Non è stato possibile inviare il codice alla nuova email.")

    return request_id, normalized_email


def complete_email_change(
    db: Session,
    *,
    user: User,
    request_id: str,
    code: str,
    secret_key: str,
) -> str:
    request = (
        db.query(EmailChangeRequest)
        .filter(
            EmailChangeRequest.request_id == request_id,
            EmailChangeRequest.user_id == user.id,
        )
        .first()
    )

    if (
        request is None
        or request.used_at is not None
        or request.invalidated_at is not None
    ):
        raise ValueError("Richiesta di cambio email non valida.")

    if request.attempts >= SECURITY_CODE_MAX_ATTEMPTS:
        request.invalidated_at = _now()
        db.commit()
        raise ValueError("Hai effettuato troppi tentativi. Avvia una nuova richiesta.")

    valid = verify_email_verification_code_hash(
        code=code,
        registration_id=request.request_id,
        expected_hash=request.code_hash,
        secret_key=secret_key,
    )

    if not valid:
        request.attempts += 1
        if request.attempts >= SECURITY_CODE_MAX_ATTEMPTS:
            request.invalidated_at = _now()
        db.commit()
        raise ValueError("Il codice non è corretto.")

    existing = (
        db.query(User)
        .filter(
            User.email == request.new_email,
            User.id != user.id,
        )
        .first()
    )
    if existing is not None:
        request.invalidated_at = _now()
        db.commit()
        raise ValueError("Email già registrata.")

    user.email = request.new_email
    user.email_verified_at = _now()
    request.used_at = _now()

    try:
        db.commit()
        db.refresh(user)
    except Exception:
        db.rollback()
        raise

    return user.email


def update_pending_registration_password(
    db: Session,
    *,
    registration_id: str,
    current_password: str,
    new_password: str,
) -> User:
    validate_password_policy(new_password)

    user = get_user_by_registration_id(
        db,
        registration_id,
    )

    if user is None or user.email_verified_at is not None:
        raise ValueError("Registrazione non disponibile.")

    if not verify_password(
        current_password,
        user.password_hash,
    ):
        raise ValueError("La password attuale non è corretta.")

    if verify_password(
        new_password,
        user.password_hash,
    ):
        raise ValueError("La nuova password deve essere diversa da quella attuale.")

    user.password_hash = hash_password(new_password)

    try:
        db.commit()
        db.refresh(user)
    except Exception:
        db.rollback()
        raise

    return user


def update_pending_registration_email(
    db: Session,
    *,
    registration_id: str,
    current_password: str,
    new_email: str,
    secret_key: str,
) -> tuple[User, int]:
    user = get_user_by_registration_id(
        db,
        registration_id,
    )

    if user is None or user.email_verified_at is not None:
        raise ValueError("Registrazione non disponibile.")

    if not verify_password(
        current_password,
        user.password_hash,
    ):
        raise ValueError("La password attuale non è corretta.")

    normalized_email = normalize_email(new_email)

    if normalized_email == user.email:
        raise ValueError("La nuova email coincide con quella attuale.")

    existing = (
        db.query(User)
        .filter(
            User.email == normalized_email,
            User.id != user.id,
        )
        .first()
    )

    if existing is not None:
        raise ValueError("Email già registrata.")

    old_email = user.email
    old_hash = user.email_verification_code_hash
    old_expires = user.email_verification_expires_at
    old_attempts = user.email_verification_attempts
    old_last_sent = user.email_verification_last_sent_at
    old_resends = user.email_verification_resend_count

    user.email = normalized_email
    code = prepare_email_verification(
        user=user,
        secret_key=secret_key,
    )
    user.email_verification_resend_count = 0

    try:
        db.commit()
        db.refresh(user)
    except Exception:
        db.rollback()
        raise

    try:
        send_email_verification_code(
            email=user.email,
            code=code,
        )
    except Exception:
        user.email = old_email
        user.email_verification_code_hash = old_hash
        user.email_verification_expires_at = old_expires
        user.email_verification_attempts = old_attempts
        user.email_verification_last_sent_at = old_last_sent
        user.email_verification_resend_count = old_resends
        try:
            db.commit()
            db.refresh(user)
        except Exception:
            db.rollback()
        raise RuntimeError("Non è stato possibile inviare il codice alla nuova email.")

    expires_in = 0
    if user.email_verification_expires_at is not None:
        expires_at = user.email_verification_expires_at
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        expires_in = max(
            0,
            int((expires_at - _now()).total_seconds()),
        )

    return user, expires_in