from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_current_user
from models.student_material_request import StudentMaterialRequest
from models.user import User
from schemas.student_material_request import StudentMaterialRequestCreate, StudentMaterialRequestResolve, StudentMaterialRequestResponse
from services.student_material_request import cancel_request, create_request, resolve_request

router = APIRouter(prefix="/student-material-requests", tags=["student-material-requests"])


@router.post("", response_model=StudentMaterialRequestResponse)
def create(data: StudentMaterialRequestCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    try:
        return create_request(db, current_user, data)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.get("/mine", response_model=list[StudentMaterialRequestResponse])
def mine(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return (
        db.query(StudentMaterialRequest)
        .filter(StudentMaterialRequest.requester_user_id == current_user.id)
        .order_by(StudentMaterialRequest.created_at.desc())
        .all()
    )


@router.get("/received", response_model=list[StudentMaterialRequestResponse])
def received(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return (
        db.query(StudentMaterialRequest)
        .filter(StudentMaterialRequest.recipient_user_id == current_user.id)
        .order_by(StudentMaterialRequest.created_at.desc())
        .all()
    )


@router.post("/{request_id}/cancel", response_model=StudentMaterialRequestResponse)
def cancel(request_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    try:
        return cancel_request(db, current_user, request_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))


@router.post("/{request_id}/resolve", response_model=StudentMaterialRequestResponse)
def resolve(request_id: int, data: StudentMaterialRequestResolve, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    try:
        return resolve_request(db, current_user, request_id, data)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
