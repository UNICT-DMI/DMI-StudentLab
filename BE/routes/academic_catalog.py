"""Review unknown university courses without blocking registration."""
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_admin_user, get_current_user
from models.academic_catalog_request import AcademicCatalogCourse, AcademicCatalogRequest
from models.user import User, UserAcademicPath
from services.academic_catalog import classify_path, course_options, key, request_data, resolve
from services.notification import create_notification

router = APIRouter(prefix='/academic-catalog', tags=['academic-catalog'])


class Decision(BaseModel):
    status: str = Field(pattern='^(assigned|rejected)$')
    university: str | None = Field(default=None, max_length=200)
    university_code: str | None = Field(default=None, max_length=50)
    department: str | None = Field(default=None, max_length=200)
    department_code: str | None = Field(default=None, max_length=50)
    course: str | None = Field(default=None, max_length=200)
    course_code: str | None = Field(default=None, max_length=50)
    degree_type: str | None = Field(default=None, max_length=50)
    note: str | None = Field(default=None, max_length=1000)


@router.get('/requests/me')
def my_requests(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    rows = (db.query(AcademicCatalogRequest, UserAcademicPath)
            .join(UserAcademicPath, UserAcademicPath.id == AcademicCatalogRequest.academic_path_id)
            .filter(AcademicCatalogRequest.user_id == user.id)
            .order_by(AcademicCatalogRequest.id.desc()).all())
    return [request_data(row, user, path, db) for row, path in rows]


@router.get('/admin/requests')
def pending_requests(status: str = 'pending', db: Session = Depends(get_db),
                     admin: User = Depends(get_admin_user)):
    if status not in ('pending', 'assigned', 'rejected', 'all'):
        raise HTTPException(400, 'Stato richieste non valido.')
    query = (db.query(AcademicCatalogRequest, User, UserAcademicPath)
             .join(User, User.id == AcademicCatalogRequest.user_id)
             .join(UserAcademicPath, UserAcademicPath.id == AcademicCatalogRequest.academic_path_id))
    if status != 'all':
        query = query.filter(AcademicCatalogRequest.status == status)
    return [request_data(row, user, path, db, True)
            for row, user, path in query.order_by(AcademicCatalogRequest.id.desc()).limit(200).all()]


@router.post('/admin/requests/{request_id}/auto')
def retry_match(request_id: int, db: Session = Depends(get_db), admin: User = Depends(get_admin_user)):
    row = db.query(AcademicCatalogRequest).filter(AcademicCatalogRequest.id == request_id).first()
    if row is None or row.status != 'pending':
        raise HTTPException(404, 'Richiesta in attesa non trovata.')
    path = db.query(UserAcademicPath).filter(UserAcademicPath.id == row.academic_path_id).first()
    user = db.query(User).filter(User.id == row.user_id).first()
    if path is None or user is None:
        raise HTTPException(404, 'Percorso non più disponibile.')
    if resolve(db, path) is None:
        raise HTTPException(409, 'Il corso non ha ancora una corrispondenza univoca nel catalogo.')
    classify_path(db, user, path)
    row.decided_by = admin.id
    create_notification(db, user_id=user.id, notification_type='system',
        title='Corso universitario riconosciuto',
        message=f'Il corso {path.course} è stato associato al tuo profilo.',
        actor_user_id=admin.id, resource_type='academic_catalog_request', resource_id=row.id,
        commit=False)
    db.commit()
    return request_data(row, user, path, db)


@router.patch('/admin/requests/{request_id}')
def decide(request_id: int, decision: Decision, db: Session = Depends(get_db),
           admin: User = Depends(get_admin_user)):
    row = db.query(AcademicCatalogRequest).filter(AcademicCatalogRequest.id == request_id).first()
    if row is None or row.status != 'pending':
        raise HTTPException(404, 'Richiesta in attesa non trovata.')
    path = db.query(UserAcademicPath).filter(UserAcademicPath.id == row.academic_path_id).first()
    user = db.query(User).filter(User.id == row.user_id).first()
    if path is None or user is None:
        raise HTTPException(404, 'Percorso non più disponibile.')
    if decision.status == 'assigned':
        provided = {field: (getattr(decision, field) or '').strip() for field in
                    ('university', 'university_code', 'department', 'department_code',
                     'course', 'course_code')}
        if any(provided.values()) and not all(provided.values()):
            raise HTTPException(400, 'Compila ateneo, dipartimento, corso e tutti e tre i codici.')
        if all(provided.values()):
            canonical = {**provided, 'degree_type': (decision.degree_type or '').strip() or None}
            existing = next((option for option in course_options(db) if
                key(option['university_code']) == key(provided['university_code']) and
                key(option['department_code']) == key(provided['department_code']) and
                key(option['course_code']) == key(provided['course_code'])), None)
            if existing is not None and key(existing['course']) != key(provided['course']):
                raise HTTPException(409, 'Il codice corso appartiene a un altro corso. Seleziona il corso corretto.')
            if existing is None:
                db.add(AcademicCatalogCourse(**canonical, created_by=admin.id))
            else:
                canonical = existing
        else:
            canonical = resolve(db, path)
            if canonical is None:
                raise HTTPException(400, 'Inserisci ateneo, dipartimento, corso e i loro codici verificati.')
        for field in ('university', 'university_code', 'department', 'department_code',
                      'course', 'course_code', 'degree_type'):
            setattr(path, field, canonical.get(field))
        if path.is_primary:
            user.university, user.department, user.course = path.university, path.department, path.course
    row.status = decision.status
    row.decided_by = admin.id
    row.decided_at = datetime.now(timezone.utc)
    row.admin_note = decision.note
    if row.status == 'assigned':
        db.flush()
        # A newly approved course can settle identical waiting requests.
        others = (db.query(AcademicCatalogRequest)
                  .filter(AcademicCatalogRequest.id != row.id,
                          AcademicCatalogRequest.status == 'pending').limit(500).all())
        for other in others:
            other_path = db.query(UserAcademicPath).filter(UserAcademicPath.id == other.academic_path_id).first()
            other_user = db.query(User).filter(User.id == other.user_id).first()
            if other_path is None or other_user is None or resolve(db, other_path) is None:
                continue
            classify_path(db, other_user, other_path)
            create_notification(db, user_id=other_user.id, notification_type='system',
                title='Corso universitario riconosciuto',
                message=f'Il corso {other_path.course} è stato associato al tuo profilo.',
                actor_user_id=admin.id, resource_type='academic_catalog_request', resource_id=other.id,
                commit=False)
    create_notification(db, user_id=user.id, notification_type='system',
        title='Percorso universitario aggiornato',
        message=(f'Il corso {path.course} è stato associato al tuo profilo.'
                 if row.status == 'assigned' else
                 'Il percorso dichiarato richiede una correzione: consulta il tuo profilo.'),
        actor_user_id=admin.id, resource_type='academic_catalog_request', resource_id=row.id,
        commit=False)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(409, 'Il corso o il codice sono già presenti nel catalogo.')
    return request_data(row, user, path, db)
