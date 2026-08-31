from datetime import (
    datetime,
    timedelta,
    timezone,
)

from email.message import (
    EmailMessage,
)

import hashlib
import hmac
import secrets
import smtplib
import ssl

from uuid import uuid4

from jose import (
    JWTError,
    jwt,
)

from passlib.context import (
    CryptContext,
)

from sqlalchemy.orm import (
    Session,
)

from core.config import (
    settings,
)

from models.user import (
    User,
)


pwd_context = CryptContext(
    schemes=[
        "bcrypt",
    ],
    deprecated="auto",
)


ACCESS_TOKEN_EXPIRE_MINUTES = (
    settings.access_token_expire_minutes
)

EMAIL_VERIFICATION_CODE_LENGTH = 6

EMAIL_VERIFICATION_EXPIRE_MINUTES = (
    settings.email_verification_expire_minutes
)

EMAIL_VERIFICATION_MAX_ATTEMPTS = (
    settings.email_verification_max_attempts
)

EMAIL_VERIFICATION_RESEND_COOLDOWN_SECONDS = (
    settings.email_verification_resend_cooldown_seconds
)

EMAIL_VERIFICATION_MAX_RESENDS = (
    settings.email_verification_max_resends
)

EMAIL_VERIFICATION_RESEND_WINDOW_SECONDS = 3600


def normalize_email(
    email: str,
) -> str:
    return (
        email
        .strip()
        .lower()
    )


def hash_password(
    password: str,
) -> str:
    return pwd_context.hash(
        password,
    )


def verify_password(
    plain_password: str,
    password_hash: str,
) -> bool:
    try:
        return pwd_context.verify(
            plain_password,
            password_hash,
        )

    except Exception:
        return False


def authenticate_user(
    db: Session,
    email: str,
    password: str,
) -> User | None:
    normalized_email = (
        normalize_email(
            email,
        )
    )

    user = (
        db.query(
            User,
        )
        .filter(
            User.email ==
            normalized_email,
        )
        .first()
    )

    if user is None:
        return None

    if not user.is_active:
        return None

    if not verify_password(
        password,
        user.password_hash,
    ):
        return None

    return user


def create_access_token(
    *,
    user_id: int,
    secret_key: str,
    expires_delta: timedelta | None = None,
) -> str:
    now = datetime.now(
        timezone.utc,
    )

    expire = (
        now + expires_delta
        if expires_delta is not None
        else now + timedelta(
            minutes=(
                ACCESS_TOKEN_EXPIRE_MINUTES
            ),
        )
    )

    payload = {
        "sub":
            str(
                user_id,
            ),
        "iat":
            now,
        "exp":
            expire,
    }

    return jwt.encode(
        payload,
        secret_key,
        algorithm="HS256",
    )


def decode_access_token(
    *,
    token: str,
    secret_key: str,
) -> int | None:
    try:
        payload = jwt.decode(
            token,
            secret_key,
            algorithms=[
                "HS256",
            ],
        )

        subject = payload.get(
            "sub",
        )

        if subject is None:
            return None

        user_id = int(
            subject,
        )

        if user_id <= 0:
            return None

        return user_id

    except (
        JWTError,
        TypeError,
        ValueError,
    ):
        return None


def generate_email_verification_code() -> str:
    upper_bound = (
        10 **
        EMAIL_VERIFICATION_CODE_LENGTH
    )

    value = secrets.randbelow(
        upper_bound,
    )

    return str(
        value,
    ).zfill(
        EMAIL_VERIFICATION_CODE_LENGTH,
    )


def generate_email_verification_id() -> str:
    return uuid4().hex


def _verification_secret(
    secret_key: str,
) -> bytes:
    effective_secret = (
        settings.email_verification_secret
        or secret_key
    )

    return effective_secret.encode(
        "utf-8",
    )


def hash_email_verification_code(
    *,
    code: str,
    registration_id: str,
    secret_key: str,
) -> str:
    message = (
        f"{registration_id}:{code}"
    ).encode(
        "utf-8",
    )

    return hmac.new(
        _verification_secret(
            secret_key,
        ),
        message,
        hashlib.sha256,
    ).hexdigest()


def verify_email_verification_code_hash(
    *,
    code: str,
    registration_id: str,
    expected_hash: str,
    secret_key: str,
) -> bool:
    actual_hash = (
        hash_email_verification_code(
            code=code,
            registration_id=(
                registration_id
            ),
            secret_key=(
                secret_key
            ),
        )
    )

    return hmac.compare_digest(
        actual_hash,
        expected_hash,
    )


def _smtp_port() -> int:
    return settings.smtp_port


def _smtp_use_tls() -> bool:
    return settings.smtp_use_tls


def _smtp_use_ssl() -> bool:
    return settings.smtp_use_ssl


def send_email_verification_code(
    *,
    email: str,
    code: str,
) -> None:
    smtp_host = settings.smtp_host

    smtp_username = (
        settings.smtp_username
    )

    smtp_password = (
        settings.smtp_password
    )

    smtp_from_email = (
        settings.smtp_from_email
    )

    smtp_from_name = (
        settings.smtp_from_name
    )

    if not smtp_host:
        raise RuntimeError(
            "Email service not configured.",
        )

    if not smtp_from_email:
        raise RuntimeError(
            "Email sender not configured.",
        )

    message = EmailMessage()

    message[
        "Subject"
    ] = "Conferma la tua email StudentLab"

    message[
        "From"
    ] = (
        f"{smtp_from_name} "
        f"<{smtp_from_email}>"
    )

    message[
        "To"
    ] = email

    message.set_content(
        (
            "Benvenuto su StudentLab.\n\n"
            "Il tuo codice di verifica è:\n\n"
            f"{code}\n\n"
            "Il codice è valido per "
            f"{EMAIL_VERIFICATION_EXPIRE_MINUTES} "
            "minuti.\n\n"
            "Se non hai richiesto questa "
            "registrazione, puoi ignorare "
            "questa email."
        ),
    )

    port = _smtp_port()

    if _smtp_use_ssl():
        context = (
            ssl.create_default_context()
        )

        with smtplib.SMTP_SSL(
            smtp_host,
            port,
            context=context,
            timeout=20,
        ) as smtp:
            if smtp_username:
                smtp.login(
                    smtp_username,
                    smtp_password,
                )

            smtp.send_message(
                message,
            )

        return

    with smtplib.SMTP(
        smtp_host,
        port,
        timeout=20,
    ) as smtp:
        smtp.ehlo()

        if _smtp_use_tls():
            context = (
                ssl.create_default_context()
            )

            smtp.starttls(
                context=context,
            )

            smtp.ehlo()

        if smtp_username:
            smtp.login(
                smtp_username,
                smtp_password,
            )

        smtp.send_message(
            message,
        )


def prepare_email_verification(
    *,
    user: User,
    secret_key: str,
) -> str:
    code = (
        generate_email_verification_code()
    )

    registration_id = (
        user.email_verification_id
    )

    if not registration_id:
        registration_id = (
            generate_email_verification_id()
        )

        user.email_verification_id = (
            registration_id
        )

    now = datetime.now(
        timezone.utc,
    )

    user.email_verification_code_hash = (
        hash_email_verification_code(
            code=code,
            registration_id=(
                registration_id
            ),
            secret_key=(
                secret_key
            ),
        )
    )

    user.email_verification_expires_at = (
        now +
        timedelta(
            minutes=(
                EMAIL_VERIFICATION_EXPIRE_MINUTES
            ),
        )
    )

    user.email_verification_attempts = 0

    user.email_verification_last_sent_at = (
        now
    )

    return code


def begin_email_verification(
    db: Session,
    *,
    user: User,
    secret_key: str,
) -> int:
    if user.email_verified_at is not None:
        raise ValueError(
            "L'email è già stata verificata.",
        )

    code = prepare_email_verification(
        user=user,
        secret_key=secret_key,
    )

    user.email_verification_resend_count = 0

    try:
        db.commit()

        db.refresh(
            user,
        )

    except Exception:
        db.rollback()

        raise

    try:
        send_email_verification_code(
            email=user.email,
            code=code,
        )

    except Exception:
        user.email_verification_code_hash = (
            None
        )

        user.email_verification_expires_at = (
            None
        )

        user.email_verification_attempts = 0

        try:
            db.commit()

        except Exception:
            db.rollback()

        raise RuntimeError(
            "Non è stato possibile inviare il codice di verifica.",
        )

    return (
        EMAIL_VERIFICATION_EXPIRE_MINUTES
        * 60
    )


def get_user_by_registration_id(
    db: Session,
    registration_id: str,
) -> User | None:
    return (
        db.query(
            User,
        )
        .filter(
            User.email_verification_id ==
            registration_id,
        )
        .first()
    )


def verify_user_email(
    db: Session,
    *,
    registration_id: str,
    code: str,
    secret_key: str,
) -> User:
    user = (
        get_user_by_registration_id(
            db,
            registration_id,
        )
    )

    if user is None:
        raise ValueError(
            "Richiesta di verifica non valida.",
        )

    if user.email_verified_at is not None:
        return user

    if (
        user.email_verification_code_hash
        is None
    ):
        raise ValueError(
            "Richiedi un nuovo codice di verifica.",
        )

    expires_at = (
        user.email_verification_expires_at
    )

    if expires_at is None:
        raise ValueError(
            "Richiedi un nuovo codice di verifica.",
        )

    now = datetime.now(
        timezone.utc,
    )

    if (
        expires_at.tzinfo is None
    ):
        expires_at = (
            expires_at.replace(
                tzinfo=timezone.utc,
            )
        )

    if now >= expires_at:
        raise ValueError(
            "Il codice è scaduto. Richiedine uno nuovo.",
        )

    attempts = (
        user.email_verification_attempts
        or 0
    )

    if (
        attempts >=
        EMAIL_VERIFICATION_MAX_ATTEMPTS
    ):
        raise ValueError(
            "Hai effettuato troppi tentativi. Richiedi un nuovo codice.",
        )

    valid = (
        verify_email_verification_code_hash(
            code=code,
            registration_id=(
                registration_id
            ),
            expected_hash=(
                user.email_verification_code_hash
            ),
            secret_key=(
                secret_key
            ),
        )
    )

    if not valid:
        user.email_verification_attempts = (
            attempts + 1
        )

        try:
            db.commit()

        except Exception:
            db.rollback()

            raise

        remaining_attempts = (
            EMAIL_VERIFICATION_MAX_ATTEMPTS
            - user.email_verification_attempts
        )

        if remaining_attempts <= 0:
            raise ValueError(
                "Hai effettuato troppi tentativi. Richiedi un nuovo codice.",
            )

        raise ValueError(
            "Il codice non è corretto.",
        )

    user.email_verified_at = now

    user.email_verification_code_hash = (
        None
    )

    user.email_verification_expires_at = (
        None
    )

    user.email_verification_attempts = 0

    user.email_verification_resend_count = 0

    user.email_verification_last_sent_at = (
        None
    )

    user.email_verification_id = None

    try:
        db.commit()

        db.refresh(
            user,
        )

    except Exception:
        db.rollback()

        raise

    return user

def get_email_verification_expires_in(
    user: User,
) -> int:
    expires_at = (
        user.email_verification_expires_at
    )

    if expires_at is None:
        return 0

    if expires_at.tzinfo is None:
        expires_at = (
            expires_at.replace(
                tzinfo=timezone.utc,
            )
        )

    now = datetime.now(
        timezone.utc,
    )

    remaining = int(
        (
            expires_at - now
        ).total_seconds()
    )

    return max(
        0,
        remaining,
    )


def resend_email_verification(
    db: Session,
    *,
    registration_id: str,
    secret_key: str,
) -> tuple[
    User,
    int,
]:
    user = (
        get_user_by_registration_id(
            db,
            registration_id,
        )
    )

    if user is None:
        raise ValueError(
            "Richiesta di verifica non valida.",
        )

    if user.email_verified_at is not None:
        raise ValueError(
            "L'email è già stata verificata.",
        )

    now = datetime.now(
        timezone.utc,
    )

    last_sent_at = (
        user.email_verification_last_sent_at
    )

    if last_sent_at is not None:
        if last_sent_at.tzinfo is None:
            last_sent_at = (
                last_sent_at.replace(
                    tzinfo=timezone.utc,
                )
            )

        elapsed = (
            now -
            last_sent_at
        ).total_seconds()

        if (
            elapsed <
            EMAIL_VERIFICATION_RESEND_COOLDOWN_SECONDS
        ):
            remaining = max(
                1,
                (
                    EMAIL_VERIFICATION_RESEND_COOLDOWN_SECONDS
                    - int(
                        elapsed,
                    )
                ),
            )

            raise ValueError(
                "Attendi "
                f"{remaining} secondi "
                "prima di richiedere "
                "un nuovo codice.",
            )

        if (
            elapsed >=
            EMAIL_VERIFICATION_RESEND_WINDOW_SECONDS
        ):
            user.email_verification_resend_count = 0

    resend_count = (
        user.email_verification_resend_count
        or 0
    )

    if (
        resend_count >=
        EMAIL_VERIFICATION_MAX_RESENDS
    ):
        raise ValueError(
            "Hai richiesto troppi codici. Riprova tra un'ora.",
        )

    previous_code_hash = (
        user.email_verification_code_hash
    )

    previous_expires_at = (
        user.email_verification_expires_at
    )

    previous_attempts = (
        user.email_verification_attempts
    )

    previous_last_sent_at = (
        user.email_verification_last_sent_at
    )

    previous_resend_count = (
        user.email_verification_resend_count
    )

    code = prepare_email_verification(
        user=user,
        secret_key=secret_key,
    )

    user.email_verification_resend_count = (
        resend_count + 1
    )

    try:
        db.commit()

        db.refresh(
            user,
        )

    except Exception:
        db.rollback()

        raise

    try:
        send_email_verification_code(
            email=user.email,
            code=code,
        )

    except Exception:
        user.email_verification_code_hash = (
            previous_code_hash
        )

        user.email_verification_expires_at = (
            previous_expires_at
        )

        user.email_verification_attempts = (
            previous_attempts
        )

        user.email_verification_last_sent_at = (
            previous_last_sent_at
        )

        user.email_verification_resend_count = (
            previous_resend_count
        )

        try:
            db.commit()

            db.refresh(
                user,
            )

        except Exception:
            db.rollback()

        raise RuntimeError(
            "Non è stato possibile inviare il codice di verifica.",
        )

    return (
        user,
        EMAIL_VERIFICATION_EXPIRE_MINUTES
        * 60,
    )
