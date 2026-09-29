
from datetime import date, datetime

from pydantic import BaseModel, ConfigDict, Field


class TeacherMaterialRequestCreate(BaseModel):
    subject_id: int
    teacher_user_id: int | None = None
    topic: str | None = Field(default=None, max_length=255)
    message: str = Field(min_length=1, max_length=3000)
    # Destinatario scelto dallo studente:
    #   None / "auto" -> docenti della materia se ci sono, altrimenti StudentLab (comportamento storico);
    #   "teachers"    -> solo docenti (errore se la materia non ne ha);
    #   "studentlab"  -> la redazione StudentLab anche se ci sono docenti.
    recipient_kind: str | None = Field(default=None, pattern="^(auto|teachers|studentlab)$")


class AdminTeacherRequestCreate(BaseModel):
    """Richiesta dell'admin a uno o più docenti di una materia."""
    subject_id: int
    teacher_user_ids: list[int] = Field(min_length=1, max_length=20)
    topic: str | None = Field(default=None, max_length=255)
    message: str = Field(min_length=1, max_length=3000)
    due_date: date | None = None
    # Richiesta degli studenti a StudentLab da cui nasce, se c'è.
    parent_request_id: int | None = None


class TeacherMaterialRequestResolve(BaseModel):
    action: str = Field(pattern="^(fulfilled|rejected)$")
    fulfilled_material_id: int | None = None
    fulfilled_share_id: int | None = None


class TeacherMaterialRequestResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    student_user_id: int
    subject_id: int
    subject_name: str | None = None
    teacher_name: str | None = None
    teacher_user_id: int | None
    recipient_kind: str = 'teachers'
    staff_response: str | None = None
    parent_request_id: int | None = None
    requested_by_admin: bool = False
    due_date: date | None = None
    fulfilled_public_material_id: int | None = None
    topic: str | None
    message: str
    status: str
    fulfilled_material_id: int | None
    fulfilled_share_id: int | None = None
    resolved_by: int | None
    resolved_at: datetime | None
    created_at: datetime
    updated_at: datetime
