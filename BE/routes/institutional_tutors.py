"""Richiesta e verifica amministrativa dei tutor dell'ateneo."""

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_admin_user, get_current_user
from models.user import User, UserAcademicPath
from services.notification import create_notification

router = APIRouter(prefix='/institutional-tutors', tags=['Institutional tutors'])


class TutorDecision(BaseModel):
    approved: bool


@router.post('/request')
def request_tutor_verification(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    if user.role != 'student':
        raise HTTPException(403, 'Solo gli studenti possono chiedere la verifica come tutor UNICT.')
    if user.institutional_tutor_status in ('pending', 'verified'):
        raise HTTPException(409, 'La verifica è già stata richiesta o completata.')
    path = (db.query(UserAcademicPath.id).filter(
        UserAcademicPath.user_id == user.id,
        UserAcademicPath.university_code == 'UNICT',
        UserAcademicPath.status == 'enrolled').first())
    if path is None:
        raise HTTPException(400, 'Per richiedere la verifica serve un percorso UNICT attivo.')
    user.institutional_tutor_status = 'pending'
    db.commit()
    return {'status': 'pending'}


@router.get('/admin/pending')
def pending_tutors(db: Session = Depends(get_db), admin: User = Depends(get_admin_user)):
    users = (db.query(User).filter(User.institutional_tutor_status == 'pending')
             .order_by(User.id).all())
    pending = []
    for user in users:
        path = (db.query(UserAcademicPath).filter(
            UserAcademicPath.user_id == user.id,
            UserAcademicPath.university_code == 'UNICT',
            UserAcademicPath.status == 'enrolled').order_by(UserAcademicPath.id.desc()).first())
        pending.append({
            'id': user.id,
            'name': f'{user.first_name} {user.last_name}',
            'university': path.university if path else '',
            'department': path.department if path else '',
            'course': path.course if path else '',
            'academic_path_verification': path.verification_status if path else 'missing',
        })
    return pending


@router.patch('/admin/{user_id}')
def decide_tutor(user_id: int, decision: TutorDecision, db: Session = Depends(get_db),
                 admin: User = Depends(get_admin_user)):
    user = db.query(User).filter(User.id == user_id,
                                 User.institutional_tutor_status == 'pending').first()
    if user is None:
        raise HTTPException(404, 'Richiesta di verifica non trovata.')
    if decision.approved:
        path = (db.query(UserAcademicPath.id).filter(
            UserAcademicPath.user_id == user.id,
            UserAcademicPath.university_code == 'UNICT',
            UserAcademicPath.status == 'enrolled').first())
        if path is None:
            raise HTTPException(409, 'Il percorso UNICT non è più attivo.')
    user.institutional_tutor_status = 'verified' if decision.approved else 'rejected'
    create_notification(db, user_id=user.id, notification_type='system',
                        title='Verifica tutor UNICT aggiornata',
                        message='Sei stato verificato come tutor UNICT.' if decision.approved
                        else 'La verifica come tutor UNICT non è stata approvata.',
                        actor_user_id=admin.id, resource_type='user', resource_id=user.id,
                        commit=False)
    db.commit()
    return {'status': user.institutional_tutor_status}
