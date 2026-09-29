
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_admin_user
from models.user import User
from services.material_share import process_expired_shares
from services.personal_material import process_personal_retention

router=APIRouter(prefix="/admin/material-lifecycle",tags=["admin-material-lifecycle"])


@router.post("/run")
def run_lifecycle(current_user:User=Depends(get_admin_user),db:Session=Depends(get_db)):
    return {
        "personal":process_personal_retention(db),
        "expired_shares":process_expired_shares(db),
    }
