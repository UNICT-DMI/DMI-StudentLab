import logging

import hostinger_mail_api

from core.config import settings


logger = logging.getLogger(__name__)


def _configuration() -> hostinger_mail_api.Configuration:
    token = settings.hostinger_mail_api_token
    if not token:
        raise RuntimeError(
            "Hostinger Mail API non configurata: HOSTINGER_MAIL_API_TOKEN mancante."
        )

    return hostinger_mail_api.Configuration(
        access_token=token,
    )


def _mailbox_resource_id() -> str:
    resource_id = settings.hostinger_mailbox_resource_id
    if not resource_id:
        raise RuntimeError(
            "Hostinger Mail API non configurata: "
            "HOSTINGER_MAILBOX_RESOURCE_ID mancante."
        )
    return resource_id


def send_transactional_email(
    *,
    to_email: str,
    subject: str,
    text: str,
    html: str | None = None,
) -> None:
    recipient = to_email.strip().lower()
    if not recipient:
        raise ValueError("Destinatario email non valido.")

    request = hostinger_mail_api.V1SendRequest(
        to=[recipient],
        display_name=settings.mail_from_name or "StudentLab",
        subject=subject,
        text=text,
        html=html,
    )

    try:
        configuration = _configuration()
        mailbox_resource_id = _mailbox_resource_id()

        with hostinger_mail_api.ApiClient(configuration) as api_client:
            api = hostinger_mail_api.SendApi(api_client)
            api.send_email(
                mailbox_resource_id,
                request,
            )
    except Exception as exception:
        logger.exception(
            "Invio Hostinger Mail API fallito: from=%s mailbox_resource_id=%s "
            "recipient_domain=%s error_type=%s",
            settings.mail_from_email,
            settings.hostinger_mailbox_resource_id,
            recipient.rsplit("@", 1)[-1] if "@" in recipient else "invalid",
            type(exception).__name__,
        )
        raise RuntimeError(
            "Non è stato possibile inviare l'email StudentLab."
        ) from exception