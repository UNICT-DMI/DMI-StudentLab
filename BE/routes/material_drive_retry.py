"""Authenticated scheduled retry for durable, approved Drive uploads."""
import hmac
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, HTTPException, Request

from core.config import settings
from core.database import SessionLocal
from models.public_material import PublicMaterial
from services.admin_material_storage import record_storage_event, utc_now
from services.drive_material_storage import copy_public_material, mark_retry
from services.public_drive_blob_retirement import retire_public_staging_blob_best_effort
from sqlalchemy import or_

router = APIRouter(prefix='/internal/materials', tags=['materials-maintenance'])


@router.get('/drive-retry')
async def retry_drive_upload(request: Request):
    secret = settings.drive_cron_secret
    bearer = request.headers.get('authorization', '')
    if not secret or not hmac.compare_digest(bearer, f'Bearer {secret}'):
        raise HTTPException(401, 'Accesso negato.')
    if not all((settings.drive_client_id, settings.drive_client_secret,
                settings.drive_refresh_token)):
        raise HTTPException(503, 'Google Drive non configurato.')
    copied = 0
    failed = 0
    db = SessionLocal()
    deadline = datetime.now(timezone.utc) + timedelta(seconds=170)
    try:
        ids = [row.id for row in db.query(PublicMaterial.id).filter(
            PublicMaterial.drive_activation_pending.is_(True),
            PublicMaterial.drive_file_id.is_(None),
            or_(PublicMaterial.drive_retry_after.is_(None),
                PublicMaterial.drive_retry_after <= datetime.now(timezone.utc)),
            PublicMaterial.status == 'hidden').order_by(PublicMaterial.id).limit(20).all()]
        for material_id in ids:
            if datetime.now(timezone.utc) >= deadline:
                break
            row = db.query(PublicMaterial).filter(PublicMaterial.id == material_id,
                PublicMaterial.drive_activation_pending.is_(True)).with_for_update(skip_locked=True).first()
            if row is None:
                continue
            try:
                drive_id = await copy_public_material(row)
                row.drive_file_id = drive_id
                row.drive_copied_at = utc_now()
                row.drive_activation_pending = False
                row.drive_retry_after = None
                row.status = 'published'
                row.is_visible = True
                row.visibility_state = 'visible'
                row.version = (row.version or 1) + 1
                row.updated_at = utc_now()
                record_storage_event(db, source='public', material_id=row.id,
                    action='drive_copied', actor_id=None, blob_path=row.stored_name,
                    original_name=row.original_name, size=row.size,
                    details={'source': 'scheduled_retry'}, commit=False)
                db.commit()
                await retire_public_staging_blob_best_effort(db, row)
                copied += 1
            except Exception as exc:
                db.rollback()
                failed_row = db.query(PublicMaterial).filter(PublicMaterial.id == material_id).first()
                if failed_row is not None and failed_row.drive_activation_pending:
                    state = mark_retry(failed_row, exc)
                    record_storage_event(db, source='public', material_id=material_id,
                        action='drive_copy_pending', actor_id=None,
                        details={'state': state}, commit=False)
                    db.commit()
                failed += 1
    finally:
        db.close()
    return {'copied': copied, 'pending_attempts_failed': failed}
