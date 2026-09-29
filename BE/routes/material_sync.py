
from datetime import datetime, timezone
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Path, Query, status
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_optional_current_user
from models.material_share import MaterialShare
from models.personal_material import PersonalSyncedMaterial
from models.user import User
from schemas.material_sync import MaterialSyncManifestResponse
from services.material_download import get_downloadable_material
from services.material_sync import build_material_sync_manifest
from services.private_blob import private_blob_response
from services.drive_material_storage import public_drive_response

MaterialDownloadSource=Literal["public","teacher","group","personal_sync","shared_user"]
router=APIRouter(prefix="/materials",tags=["materials-sync"])


def _since(value):
    if value is None:
        return None
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)


@router.get("/sync-manifest",response_model=MaterialSyncManifestResponse)
def manifest(since:datetime|None=Query(default=None),current_user:User|None=Depends(get_optional_current_user),db:Session=Depends(get_db)):
    return build_material_sync_manifest(db,user_id=(current_user.id if current_user else None),since=_since(since))


@router.get("/{source}/{material_id}/download")
async def download(source:MaterialDownloadSource,material_id:int=Path(gt=0),current_user:User|None=Depends(get_optional_current_user),db:Session=Depends(get_db)):
    if source=="public":
        try:
            material=get_downloadable_material(db,source="public",material_id=material_id,user_id=(current_user.id if current_user else None))
        except (PermissionError,ValueError):
            raise HTTPException(status_code=404,detail="Materiale non trovato.")
    elif current_user is None:
        raise HTTPException(status_code=404,detail="Materiale non trovato.")
    elif source=="personal_sync":
        record=db.query(PersonalSyncedMaterial).filter(PersonalSyncedMaterial.id==material_id,PersonalSyncedMaterial.owner_user_id==current_user.id,PersonalSyncedMaterial.status=="active").first()
        if record is None:
            raise HTTPException(status_code=404,detail="Materiale non trovato.")
        material={"stored_name":record.stored_name,"original_name":record.original_name,"mime_type":record.mime_type}
    elif source=="shared_user":
        record=db.query(MaterialShare).filter(MaterialShare.id==material_id,MaterialShare.recipient_user_id==current_user.id,MaterialShare.status.in_(["accepted","delivered"])).first()
        if record is None:
            raise HTTPException(status_code=404,detail="Materiale non trovato.")
        material={"stored_name":record.stored_name,"original_name":record.original_name,"mime_type":record.mime_type}
    else:
        try:
            material=get_downloadable_material(db,source=source,material_id=material_id,user_id=current_user.id)
        except (PermissionError,ValueError):
            raise HTTPException(status_code=404,detail="Materiale non trovato.")
    if source == 'public' and material.get('drive_file_id'):
        return await public_drive_response(drive_file_id=material['drive_file_id'],
            original_name=material['original_name'], mime_type=material['mime_type'])
    return await private_blob_response(stored_name=material["stored_name"],original_name=material["original_name"],mime_type=material["mime_type"],inline=False)
