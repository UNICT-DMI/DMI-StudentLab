"""Retire a public staging Blob only after its Drive copy is durable.

All other materials (personal, groups, teachers, shares) retain their Blobs.
"""
import logging

from sqlalchemy.orm import Session

from models.material import GroupMaterial
from models.material_publication_request import MaterialPublicationRequest
from models.material_share import MaterialShare
from models.personal_material import PersonalSyncedMaterial
from models.public_material import PublicMaterial
from models.teacher_material import TeacherMaterial
from services.admin_material_storage import record_storage_event
from services.drive_material_catalog import verify_under_root
from services.drive_material_storage import _access_token, _session
from services.private_blob import delete_private_blob

logger = logging.getLogger(__name__)


async def retire_public_staging_blob(db: Session, material: PublicMaterial,
                                     actor_id: int | None = None) -> str:
    """Return deleted, already_missing, or skipped; never delete an in-use file.

    The database commit that records drive_file_id must precede this call.
    """
    path = (material.stored_name or '').strip()
    if (not path or path.startswith('drive-import/') or not material.drive_file_id
            or material.drive_activation_pending or not material.drive_copied_at):
        return 'skipped'

    # Public material may share the source path with its approved proposal.
    if db.query(PublicMaterial.id).filter(PublicMaterial.stored_name == path,
            PublicMaterial.id != material.id).first():
        return 'skipped'
    for model in (GroupMaterial, TeacherMaterial, PersonalSyncedMaterial, MaterialShare):
        if db.query(model.id).filter(model.stored_name == path).first():
            return 'skipped'
    proposals = db.query(MaterialPublicationRequest).filter(
        MaterialPublicationRequest.stored_name == path).all()
    if any(p.status != 'approved' or p.approved_public_material_id != material.id
           for p in proposals):
        return 'skipped'

    # Verify the actual copy still exists inside StudentLab's Drive root and
    # belongs to this exact version before removing the only staging source.
    async with await _session() as client:
        token = await _access_token(client)
        data = await verify_under_root(client, {'Authorization': f'Bearer {token}'},
                                       material.drive_file_id)
    props = data.get('appProperties') or {}
    if (props.get('studentlab_public_id') != str(material.id)
            or props.get('sha256', '').lower() != material.file_hash.lower()
            or int(data.get('size', -1)) != material.size):
        logger.warning('drive_blob_retirement_skipped material_id=%s reason=mismatch',
                       material.id)
        return 'skipped'

    deleted = await delete_private_blob(path)
    result = 'deleted' if deleted else 'already_missing'
    record_storage_event(db, source='public', material_id=material.id,
        action='drive_staging_blob_deleted' if deleted else 'drive_staging_blob_missing',
        actor_id=actor_id, blob_path=path, original_name=material.original_name,
        size=material.size, details={'drive_file_id': material.drive_file_id},
        commit=True)
    return result


async def retire_public_staging_blob_best_effort(db: Session,
                                                  material: PublicMaterial,
                                                  actor_id: int | None = None):
    """Never turn a successful Drive publication into a failed approval."""
    try:
        return await retire_public_staging_blob(db, material, actor_id)
    except Exception:
        db.rollback()
        logger.exception('drive_blob_retirement_failed material_id=%s', material.id)
        return 'failed'
