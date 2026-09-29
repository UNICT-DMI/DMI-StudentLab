"""Approve academic course folders before they can publish material."""
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_admin_user, get_current_user
from core.material_course_proposal import MaterialCourseProposal
from models.subject import Subject
from models.user import User

router = APIRouter(prefix='/materials/course-proposals', tags=['material-course-proposals'])


class CourseProposalCreate(BaseModel):
    university: str = Field(min_length=2, max_length=200)
    department: str = Field(min_length=2, max_length=200)
    course: str = Field(min_length=2, max_length=200)


class CourseProposalDecision(BaseModel):
    university_code: str = Field(min_length=2, max_length=30)
    department_code: str = Field(min_length=2, max_length=30)
    course_code: str = Field(min_length=2, max_length=30)


class CourseProposalReject(BaseModel):
    reason: str = Field(min_length=3, max_length=1000)


def _item(row):
    return dict(id=row.id, university=row.university, department=row.department,
        course=row.course, status=row.status, subject_id=row.approved_subject_id,
        rejection_reason=row.rejection_reason, created_at=row.created_at,
        reviewed_at=row.reviewed_at)


@router.post('')
def propose(request: CourseProposalCreate, user: User = Depends(get_current_user),
            db: Session = Depends(get_db)):
    values = [part.strip() for part in (request.university, request.department, request.course)]
    existing = db.query(MaterialCourseProposal).filter(
        MaterialCourseProposal.user_id == user.id,
        MaterialCourseProposal.university == values[0],
        MaterialCourseProposal.department == values[1],
        MaterialCourseProposal.course == values[2],
        MaterialCourseProposal.status == 'pending').first()
    if existing:
        return _item(existing)
    row = MaterialCourseProposal(user_id=user.id, university=values[0],
        department=values[1], course=values[2])
    db.add(row); db.commit(); db.refresh(row)
    return _item(row)


@router.get('/mine')
def mine(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return [_item(row) for row in db.query(MaterialCourseProposal).filter(
        MaterialCourseProposal.user_id == user.id).order_by(
        MaterialCourseProposal.id.desc()).all()]


@router.get('/admin')
def admin_list(user: User = Depends(get_admin_user), db: Session = Depends(get_db)):
    return [_item(row) for row in db.query(MaterialCourseProposal).order_by(
        MaterialCourseProposal.id.desc()).all()]


@router.post('/admin/{proposal_id}/approve')
def approve(proposal_id: int, request: CourseProposalDecision,
            user: User = Depends(get_admin_user), db: Session = Depends(get_db)):
    row = db.query(MaterialCourseProposal).filter(
        MaterialCourseProposal.id == proposal_id).with_for_update().first()
    if row is None or row.status != 'pending':
        raise HTTPException(404, 'Proposta non più disponibile.')
    codes = [v.strip().upper() for v in (request.university_code,
                                           request.department_code, request.course_code)]
    existing = db.query(Subject).filter(Subject.university_code == codes[0],
        Subject.department == row.department, Subject.course == row.course,
        Subject.code == 'COURSE-MATERIALS').first()
    if existing is None:
        existing = Subject(code='COURSE-MATERIALS', name='Materiali del corso',
            university=row.university, university_code=codes[0],
            department=row.department, department_code=codes[1],
            course=row.course, course_code=codes[2], is_active=True)
        db.add(existing)
        db.flush()
    row.status = 'approved'; row.approved_subject_id = existing.id
    row.reviewed_at = datetime.now(timezone.utc)
    try:
        db.commit()
    except Exception:
        db.rollback()
        raise
    return _item(row)


@router.post('/admin/{proposal_id}/reject')
def reject(proposal_id: int, request: CourseProposalReject,
           user: User = Depends(get_admin_user), db: Session = Depends(get_db)):
    row = db.query(MaterialCourseProposal).filter(
        MaterialCourseProposal.id == proposal_id).with_for_update().first()
    if row is None or row.status != 'pending':
        raise HTTPException(404, 'Proposta non più disponibile.')
    row.status = 'rejected'; row.rejection_reason = request.reason.strip()
    row.reviewed_at = datetime.now(timezone.utc)
    db.commit()
    return _item(row)
