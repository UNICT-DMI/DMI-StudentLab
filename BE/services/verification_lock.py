"""Blocca le credenziali identificative durante le verifiche accademiche."""

from sqlalchemy.orm import Session

from models.subject import UserSubject
from models.user import User, UserAcademicPath

PENDING_MESSAGE = ('Hai dati accademici in verifica. Nome, cognome, email e password '
                   'potranno essere modificati dopo la conclusione della verifica.')


def has_pending_verifications(db: Session, user: User) -> bool:
    if user.role != 'student':
        return False
    if (user.teacher_verification_status or '').lower() == 'pending':
        return True
    if (user.institutional_tutor_status or '').lower() == 'pending':
        return True
    if (user.student_verification_status or '').lower() == 'pending':
        return True
    if db.query(UserAcademicPath.id).filter(UserAcademicPath.user_id == user.id,
                                            UserAcademicPath.verification_status == 'pending').first():
        return True
    return db.query(UserSubject.id).filter(UserSubject.user_id == user.id,
                                           UserSubject.grade_status == 'pending').first() is not None


def require_identifiers_editable(db: Session, user: User) -> None:
    if has_pending_verifications(db, user):
        raise ValueError(PENDING_MESSAGE)
