"""Student identity badge, always subject to an administrator decision."""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_admin_user, get_current_user
from models.user import User
from services.notification import create_notification

router = APIRouter(prefix='/student-verifications', tags=['Student verifications'])


class Decision(BaseModel):
    approved: bool


@router.post('/request')
def request_verification(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    if user.role != 'student':
        raise HTTPException(403, 'Solo gli studenti possono richiedere il badge studente verificato.')
    if user.student_verification_status in ('pending', 'verified'):
        raise HTTPException(409, 'Verifica già richiesta o completata.')
    if not user.first_name or not user.last_name or not user.email:
        raise HTTPException(400, 'Completa nome, cognome ed email nel profilo.')
    user.student_verification_status = 'pending'
    db.commit()
    return {'status': 'pending'}


@router.get('/admin/pending')
def pending(db: Session = Depends(get_db), admin: User = Depends(get_admin_user)):
    users = db.query(User).filter(User.student_verification_status == 'pending').order_by(User.id).all()
    return [{'id': item.id, 'first_name': item.first_name, 'last_name': item.last_name,
             'email': item.email} for item in users]


@router.patch('/admin/{user_id}')
def decide(user_id: int, decision: Decision, db: Session = Depends(get_db),
           admin: User = Depends(get_admin_user)):
    user = db.query(User).filter(User.id == user_id,
                                 User.role == 'student',
                                 User.student_verification_status == 'pending').first()
    if user is None:
        raise HTTPException(404, 'Richiesta non trovata.')
    user.student_verification_status = 'verified' if decision.approved else 'rejected'
    create_notification(db, user_id=user.id, notification_type='system',
                        title='Verifica profilo studente aggiornata',
                        message='Il tuo profilo studente è stato verificato.' if decision.approved
                        else 'La richiesta di verifica del profilo studente non è stata approvata.',
                        actor_user_id=admin.id, resource_type='user', resource_id=user.id,
                        commit=False)
    db.commit()
    return {'status': user.student_verification_status}
