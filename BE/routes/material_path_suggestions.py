from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from core.database import get_db
from models.subject import Subject
from services.material_path_suggestions import suggest_subject_paths

router = APIRouter(prefix='/materials', tags=['material-paths'])


class PathSuggestionRequest(BaseModel):
    university: str = Field(min_length=1, max_length=200)
    department: str = Field(min_length=1, max_length=200)
    course: str = Field(min_length=1, max_length=200)
    subject: str | None = Field(default=None, max_length=200)


@router.post('/path-suggestions')
def suggest_path(request: PathSuggestionRequest, db: Session = Depends(get_db)):
    catalog = db.query(Subject).filter(Subject.is_active.is_(True)).all()
    results = suggest_subject_paths(
        catalog,
        university=request.university,
        department=request.department,
        course=request.course,
        subject=request.subject,
    )
    unique = {(r['university'], r['department'], r['course'], r['subject']): r for r in results}
    return list(unique.values())[:5]
