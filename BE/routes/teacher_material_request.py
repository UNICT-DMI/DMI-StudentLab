import json
import re

from fastapi import Query, APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_current_user, get_verified_teacher_user, get_admin_user
from models.teacher_material_request import TeacherMaterialRequest
from models.user import User
from schemas.teacher_material_request import AdminTeacherRequestCreate, TeacherMaterialRequestCreate, TeacherMaterialRequestResolve, TeacherMaterialRequestResponse
from models.public_material import PublicMaterial
from services.public_material_access import can_read_public_material
from services.teacher_material_request import create_request, resolve_request, available_subjects, utc_now, create_admin_request, teachers_for_subject
from services.notification import create_notification

router=APIRouter(prefix="/teacher-material-requests",tags=["teacher-material-requests"])


class StudentLabReply(BaseModel):
    message: str = Field(min_length=1, max_length=3000)
    action: str = Field(pattern='^(fulfilled|rejected)$')
    # Materiale StudentLab che soddisfa la richiesta ("Collega e chiudi").
    fulfilled_public_material_id: int | None = None


@router.get('/options')
def options(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return available_subjects(db, current_user)


@router.get('/studentlab')
def studentlab_inbox(current_user: User = Depends(get_admin_user), db: Session = Depends(get_db)):
    rows = db.query(TeacherMaterialRequest).filter(TeacherMaterialRequest.recipient_kind == 'studentlab').order_by(
        TeacherMaterialRequest.created_at.desc()).limit(200).all()
    ids = [row.id for row in rows]
    children = {}
    if ids:
        for child in db.query(TeacherMaterialRequest).filter(
                TeacherMaterialRequest.parent_request_id.in_(ids)).order_by(
                TeacherMaterialRequest.created_at).all():
            teacher = db.query(User).filter(User.id == child.teacher_user_id).first() if child.teacher_user_id else None
            children.setdefault(child.parent_request_id, []).append({
                'id': child.id, 'status': child.status, 'created_at': child.created_at,
                'due_date': child.due_date, 'resolved_at': child.resolved_at,
                'teacher_name': (f'{teacher.first_name} {teacher.last_name}'.strip() if teacher else 'Docente')})
    def _name(user_id):
        if user_id is None:
            return None
        user = db.query(User).filter(User.id == user_id).first()
        return f'{user.first_name} {user.last_name}'.strip() if user else None
    return [{'id': row.id, 'student_user_id': row.student_user_id,
        'student_name': f'{row.student.first_name} {row.student.last_name}'.strip(),
        'subject_id': row.subject_id, 'subject_name': row.subject.name,
        'course': row.subject.course,
        'topic': row.topic, 'message': row.message, 'status': row.status,
        'staff_response': row.staff_response, 'created_at': row.created_at,
        'resolved_at': row.resolved_at, 'resolved_by_name': _name(row.resolved_by),
        'fulfilled_public_material_id': row.fulfilled_public_material_id,
        'forwarded': children.get(row.id, [])} for row in rows]


@router.post('/studentlab/{request_id}/reply', response_model=TeacherMaterialRequestResponse)
def studentlab_reply(request_id: int, data: StudentLabReply,
        current_user: User = Depends(get_admin_user), db: Session = Depends(get_db)):
    row = db.query(TeacherMaterialRequest).filter(TeacherMaterialRequest.id == request_id,
        TeacherMaterialRequest.recipient_kind == 'studentlab').with_for_update().first()
    if row is None:
        raise HTTPException(404, 'Richiesta StudentLab non trovata.')
    if row.status != 'pending':
        raise HTTPException(409, 'Questa richiesta è già stata gestita.')
    if data.fulfilled_public_material_id is not None:
        if data.action != 'fulfilled':
            raise HTTPException(400, 'Si collega un materiale solo quando la richiesta è soddisfatta.')
        linked = db.query(PublicMaterial).filter(PublicMaterial.id == data.fulfilled_public_material_id,
            PublicMaterial.subject_id == row.subject_id, PublicMaterial.status != 'removed').first()
        if linked is None:
            raise HTTPException(400, 'Il materiale collegato non appartiene a questa materia.')
        row.fulfilled_public_material_id = linked.id
    row.status = data.action
    row.staff_response = data.message.strip()
    row.resolved_by = current_user.id
    row.resolved_at = utc_now()
    row.updated_at = row.resolved_at
    create_notification(db, user_id=row.student_user_id,
        notification_type='teacher_material_request_resolved',
        title='Risposta alla richiesta di materiale', message=row.staff_response,
        actor_user_id=current_user.id, resource_type='teacher_material_request',
        resource_id=row.id, commit=False)
    db.commit()
    db.refresh(row)
    return row


@router.get('/admin/teachers')
def admin_subject_teachers(subject_id: int = Query(gt=0),
        current_user: User = Depends(get_admin_user), db: Session = Depends(get_db)):
    """Docenti verificati della materia, per "Richiedi a un docente"."""
    return teachers_for_subject(db, subject_id)


@router.post('/admin', response_model=list[TeacherMaterialRequestResponse])
def admin_request_to_teachers(request: AdminTeacherRequestCreate,
        current_user: User = Depends(get_admin_user), db: Session = Depends(get_db)):
    try:
        return create_admin_request(db, current_user, request)
    except ValueError as exc:
        db.rollback()
        raise HTTPException(400, str(exc)) from exc


@router.get('/admin/materials')
def admin_subject_materials(subject_id: int = Query(gt=0), q: str = Query(default='', max_length=200),
        current_user: User = Depends(get_admin_user), db: Session = Depends(get_db)):
    """Materiali StudentLab della materia da collegare a una richiesta."""
    query = db.query(PublicMaterial).filter(PublicMaterial.subject_id == subject_id,
        PublicMaterial.status != 'removed')
    words = [w for w in re.split(r'[^0-9a-zA-ZÀ-ÿ]+', q.casefold()) if len(w) >= 3][:8]
    rows = query.order_by(PublicMaterial.updated_at.desc()).limit(200).all()
    result = []
    for row in rows:
        path = json.loads(row.catalog_path_json or '[]')
        text = ' '.join([row.title or '', row.original_name or '', *path]).casefold()
        if words and not any(w in text for w in words):
            continue
        result.append({'id': row.id, 'title': row.title, 'original_name': row.original_name,
            'path_segments': path, 'visibility_state': row.visibility_state})
    return result[:20]


@router.get('/suggestions')
def material_request_suggestions(subject_id: int = Query(gt=0),
        q: str = Query(default='', max_length=200),
        current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Materiali già disponibili che forse soddisfano la richiesta.

    Restituisce solo materiali pubblicati che questo studente può già leggere
    (stesse regole di download e sincronizzazione), al massimo cinque.
    """
    words = [w for w in re.split(r'[^0-9a-zA-ZÀ-ÿ]+', q.casefold()) if len(w) >= 3][:8]
    rows = db.query(PublicMaterial).filter(PublicMaterial.subject_id == subject_id,
        PublicMaterial.status == 'published', PublicMaterial.is_visible.is_(True)).order_by(
        PublicMaterial.updated_at.desc()).limit(200).all()
    scored = []
    for row in rows:
        path = json.loads(row.catalog_path_json or '[]')
        haystack = ' '.join([row.title or '', row.original_name or '', *path]).casefold()
        score = sum(1 for w in words if w in haystack)
        if words and score == 0:
            continue
        if not can_read_public_material(db, row, current_user.id):
            continue
        scored.append((score, row, path))
    scored.sort(key=lambda item: (-item[0], -(item[1].updated_at.timestamp() if item[1].updated_at else 0)))
    return [{'id': row.id, 'title': row.title, 'original_name': row.original_name,
             'path_segments': path, 'source': 'public'} for _, row, path in scored[:5]]


@router.post("",response_model=TeacherMaterialRequestResponse)
def create(request:TeacherMaterialRequestCreate,current_user:User=Depends(get_current_user),db:Session=Depends(get_db)):
    try:
        return create_request(db,current_user,request)
    except ValueError as exc:
        raise HTTPException(status_code=400,detail=str(exc))


@router.get("/mine",response_model=list[TeacherMaterialRequestResponse])
def mine(current_user:User=Depends(get_current_user),db:Session=Depends(get_db)):
    return db.query(TeacherMaterialRequest).filter(TeacherMaterialRequest.student_user_id==current_user.id).order_by(TeacherMaterialRequest.created_at.desc()).all()


@router.get("/teacher",response_model=list[TeacherMaterialRequestResponse])
def teacher(current_user:User=Depends(get_verified_teacher_user),db:Session=Depends(get_db)):
    from models.teacher_assignment import TeacherAssignment
    subject_ids=[row[0] for row in db.query(TeacherAssignment.subject_id).filter(TeacherAssignment.user_id==current_user.id,TeacherAssignment.verification_status=="verified",TeacherAssignment.is_current.is_(True)).all()]
    return db.query(TeacherMaterialRequest).filter(TeacherMaterialRequest.subject_id.in_(subject_ids),
        TeacherMaterialRequest.recipient_kind == 'teachers',
        (TeacherMaterialRequest.teacher_user_id.is_(None) | (TeacherMaterialRequest.teacher_user_id == current_user.id))).order_by(TeacherMaterialRequest.created_at.desc()).all() if subject_ids else []


@router.post("/{request_id}/cancel",response_model=TeacherMaterialRequestResponse)
def cancel(request_id:int,current_user:User=Depends(get_current_user),db:Session=Depends(get_db)):
    record=db.query(TeacherMaterialRequest).filter(TeacherMaterialRequest.id==request_id,TeacherMaterialRequest.student_user_id==current_user.id).first()
    if record is None:
        raise HTTPException(status_code=404,detail="Richiesta non trovata.")
    if record.status!="pending":
        raise HTTPException(status_code=400,detail="Puoi annullare solo una richiesta ancora in attesa.")
    from datetime import datetime, timezone
    record.status="cancelled"
    record.resolved_at=datetime.now(timezone.utc)
    record.updated_at=record.resolved_at
    db.commit()
    db.refresh(record)
    return record


@router.post("/{request_id}/resolve",response_model=TeacherMaterialRequestResponse)
def resolve(request_id:int,request:TeacherMaterialRequestResolve,current_user:User=Depends(get_verified_teacher_user),db:Session=Depends(get_db)):
    try:
        return resolve_request(db,current_user,request_id,request)
    except PermissionError as exc:
        raise HTTPException(status_code=403,detail=str(exc))
    except ValueError as exc:
        raise HTTPException(status_code=400,detail=str(exc))
