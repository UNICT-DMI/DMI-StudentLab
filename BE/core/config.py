import os

from dotenv import load_dotenv


load_dotenv(override=False)


class Settings:
    def __init__(self):
        self.is_vercel = self._env("VERCEL") == "1"
        self.environment = (
            self._env("VERCEL_ENV")
            or self._env("ENVIRONMENT")
            or "development"
        ).strip().lower()

        self.database_url = (
            self._env("StudentLab_DATABASE_URL")
            or self._env("DATABASE_URL")
            or (
                None
                if self.is_vercel
                else "postgresql://postgres:postgres@localhost:5432/studentlab"
            )
        )

        if not self.database_url:
            raise RuntimeError(
                "Database non configurato. Imposta StudentLab_DATABASE_URL "
                "oppure DATABASE_URL nell'ambiente di deploy."
            )

        self.blob_read_write_token = (
            self._env("StudentLab_READ_WRITE_TOKEN")
            or self._env("BLOB_READ_WRITE_TOKEN")
        )

        self.secret_key = (
            self._env("StudentLab_SECRET_KEY")
            or self._env("SECRET_KEY")
        )

        if not self.secret_key:
            raise RuntimeError(
                "StudentLab_SECRET_KEY non configurata. "
                "Impostala nelle Environment Variables del deployment."
            )

        self.current_policy_version = (
            self._env("StudentLab_POLICY_VERSION")
            or "1.0"
        )

        self.minimum_registration_age = self._env_int(
            ("StudentLab_MINIMUM_AGE",),
            default=14,
        )

        self.access_token_expire_minutes = self._env_int(
            (
                "StudentLab_ACCESS_TOKEN_EXPIRE_MINUTES",
                "ACCESS_TOKEN_EXPIRE_MINUTES",
            ),
            default=1440,
        )

        self.email_verification_secret = (
            self._env("StudentLab_EMAIL_VERIFICATION_SECRET")
            or self._env("EMAIL_VERIFICATION_SECRET")
            or self.secret_key
        )

        self.email_verification_expire_minutes = self._env_int(
            (
                "StudentLab_EMAIL_VERIFICATION_EXPIRE_MINUTES",
                "EMAIL_VERIFICATION_EXPIRE_MINUTES",
            ),
            default=10,
        )

        self.email_verification_max_attempts = self._env_int(
            (
                "StudentLab_EMAIL_VERIFICATION_MAX_ATTEMPTS",
                "EMAIL_VERIFICATION_MAX_ATTEMPTS",
            ),
            default=5,
        )

        self.email_verification_resend_cooldown_seconds = self._env_int(
            (
                "StudentLab_EMAIL_VERIFICATION_RESEND_COOLDOWN_SECONDS",
                "EMAIL_VERIFICATION_RESEND_COOLDOWN_SECONDS",
            ),
            default=60,
        )

        self.email_verification_max_resends = self._env_int(
            (
                "StudentLab_EMAIL_VERIFICATION_MAX_RESENDS",
                "EMAIL_VERIFICATION_MAX_RESENDS",
            ),
            default=5,
        )

        self.smtp_host = (
            self._env("StudentLab_SMTP_HOST")
            or self._env("SMTP_HOST")
            or ""
        ).strip()

        self.smtp_port = self._env_int(
            (
                "StudentLab_SMTP_PORT",
                "SMTP_PORT",
            ),
            default=587,
        )

        self.smtp_username = (
            self._env("StudentLab_SMTP_USERNAME")
            or self._env("SMTP_USERNAME")
            or ""
        ).strip()

        self.smtp_password = (
            self._env("StudentLab_SMTP_PASSWORD")
            or self._env("SMTP_PASSWORD")
            or ""
        )

        self.smtp_from_email = (
            self._env("StudentLab_SMTP_FROM_EMAIL")
            or self._env("SMTP_FROM_EMAIL")
            or self.smtp_username
        ).strip()

        self.smtp_from_name = (
            self._env("StudentLab_SMTP_FROM_NAME")
            or self._env("SMTP_FROM_NAME")
            or "StudentLab"
        ).strip()

        self.smtp_use_tls = self._env_bool(
            (
                self._env("StudentLab_SMTP_USE_TLS")
                or self._env("SMTP_USE_TLS")
            ),
            default=True,
        )

        self.smtp_use_ssl = self._env_bool(
            (
                self._env("StudentLab_SMTP_USE_SSL")
                or self._env("SMTP_USE_SSL")
            ),
            default=False,
        )

        self.compliance_key_id = (
            self._env("StudentLab_COMPLIANCE_KEY_ID")
            or self._env("COMPLIANCE_KEY_ID")
            or ""
        ).strip()

        self.compliance_public_key = (
            self._env("StudentLab_COMPLIANCE_PUBLIC_KEY")
            or self._env("COMPLIANCE_PUBLIC_KEY")
            or ""
        ).strip()

        self.compliance_key_algo = (
            self._env("StudentLab_COMPLIANCE_KEY_ALGO")
            or self._env("COMPLIANCE_KEY_ALGO")
            or "x25519"
        ).strip().lower()

    @staticmethod
    def _normalize_env_value(value: str | None) -> str | None:
        if value is None:
            return None
        normalized = value.strip()
        if not normalized:
            return None
        if normalized.upper() in {
            "[SENSITIVE]",
            "<SENSITIVE>",
            "SENSITIVE",
        }:
            return None
        return normalized

    @classmethod
    def _env(cls, name: str) -> str | None:
        return cls._normalize_env_value(os.getenv(name))

    @classmethod
    def _env_int(
        cls,
        names: tuple[str, ...],
        *,
        default: int,
    ) -> int:
        for name in names:
            value = cls._env(name)
            if value is None:
                continue
            try:
                return int(value)
            except ValueError as exception:
                raise RuntimeError(
                    f"{name} deve essere un numero intero."
                ) from exception
        return default

    @staticmethod
    def _env_bool(
        value: str | None,
        *,
        default: bool,
    ) -> bool:
        if value is None:
            return default
        return value.strip().lower() in {
            "1",
            "true",
            "yes",
            "on",
        }


settings = Settings()