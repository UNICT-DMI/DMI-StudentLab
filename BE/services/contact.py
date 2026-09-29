"""Inoltro richieste tra utenti: email privata e notifica nella app."""

from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session

from models.notification import Notification
from models.subject import UserSubject
from models.user import User
from schemas.contact import ContactUserRequest, ContactUserResponse
from services.mail_service import send_transactional_email
from services.notification import create_notification
from services.user_block import is_block_relationship_present


def send_contact_request(db: Session, *, sender: User, recipient_user_id: int,
                         data: ContactUserRequest) -> ContactUserResponse:
    if sender.id == recipient_user_id:
        raise ValueError('Non puoi contattare te stesso.')
    recipient = (db.query(User).filter(User.id == recipient_user_id,
                                       User.is_active.is_(True),
                                       User.email_verified_at.is_not(None)).first())
    if recipient is None:
        raise ValueError("L'utente non è disponibile.")
    if is_block_relationship_present(db, sender.id, recipient.id):
        raise PermissionError('Non puoi contattare questo utente.')
    recent = (db.query(Notification.id).filter(
        Notification.user_id == recipient.id,
        Notification.actor_user_id == sender.id,
        Notification.title.like('%ti ha contattato'),
        Notification.created_at >= datetime.now(timezone.utc) - timedelta(minutes=5),
    ).first())
    if recent is not None:
        raise PermissionError('Attendi cinque minuti prima di ricontattare questo utente.')

    allowed = {'general': recipient.available, 'help': recipient.available_for_help,
               'private_lesson': recipient.available_for_private_lessons,
               'institutional_tutoring': recipient.institutional_tutor_status == 'verified'}
    if not allowed.get(data.request_type):
        raise PermissionError("L'utente non è disponibile per questo tipo di richiesta.")
    if data.request_type in {'help', 'private_lesson', 'institutional_tutoring'}:
        link = (db.query(UserSubject).filter(UserSubject.user_id == recipient.id,
                                            UserSubject.subject_id == data.subject_id).first())
        if link is None or not (link.can_help if data.request_type in {'help', 'institutional_tutoring'}
                                else link.can_give_private_lessons):
            raise PermissionError('La materia non è disponibile per questa richiesta.')

    sender_name = f'{sender.first_name} {sender.last_name}'.strip()
    subject = data.subject.strip()
    body = (f'{sender_name} ti ha contattato tramite StudentLab.\n'
            f'Motivo: {subject}\n\n{data.message.strip()}')
    send_transactional_email(to_email=recipient.email,
                             subject=f'StudentLab · {subject}', text=body)
    try:
        create_notification(db, user_id=recipient.id, notification_type='system',
                            title=f'{sender_name} ti ha contattato', message=f'{subject}\n{data.message.strip()}',
                            actor_user_id=sender.id, resource_type='user', resource_id=sender.id,
                            action_type='open_profile', action_resource_id=sender.id)
    except Exception:
        db.rollback()
        raise
    return ContactUserResponse(success=True, message='Richiesta inviata.')
