"""Copy approved public materials to Drive from a long-running worker.

Run from BE with the same environment as the API:
  python -m scripts.copy_public_material_to_drive --material-id 123
  python -m scripts.copy_public_material_to_drive --all
"""
import argparse
import asyncio

from core.database import SessionLocal
from models.public_material import PublicMaterial
from services.admin_material_storage import record_storage_event, utc_now
from services.drive_material_storage import copy_public_material, mark_retry


async def main(material_id: int | None, all_public: bool):
    db = SessionLocal()
    try:
        query = db.query(PublicMaterial).filter(
            PublicMaterial.status.in_(['published', 'hidden']),
            PublicMaterial.drive_file_id.is_(None))
        query = query.filter((PublicMaterial.status == 'published') |
                             (PublicMaterial.drive_activation_pending.is_(True)))
        if not all_public:
            query = query.filter(PublicMaterial.id == material_id)
        ids = [row.id for row in query.order_by(PublicMaterial.id).all()]
        if not ids:
            print('Nessun materiale pubblico da copiare.')
            return
        for current_id in ids:
            material = db.query(PublicMaterial).filter(PublicMaterial.id == current_id).first()
            try:
                drive_id = await copy_public_material(material)
                material.drive_file_id = drive_id
                material.drive_copied_at = utc_now()
                material.drive_retry_after = None
                if material.drive_activation_pending:
                    material.drive_activation_pending = False
                    material.status = 'published'
                    material.is_visible = True
                    material.visibility_state = 'visible'
                    material.version = (material.version or 1) + 1
                    material.updated_at = utc_now()
                record_storage_event(db, source='public', material_id=material.id,
                    action='drive_copied', actor_id=None,
                    blob_path=material.stored_name,
                    original_name=material.original_name, size=material.size,
                    details={'drive_file_id': drive_id, 'source': 'worker'}, commit=False)
                db.commit()
                print(f'Materiale {current_id}: copia verificata.')
            except Exception as exc:
                db.rollback()
                if material.drive_activation_pending:
                    state = mark_retry(material, exc)
                    record_storage_event(db, source='public', material_id=material.id,
                        action='drive_copy_pending', actor_id=None,
                        details={'source': 'worker', 'state': state}, commit=False)
                    db.commit()
                print(f'Materiale {current_id}: copia non completata; file Blob invariato.')
                if not all_public:
                    raise
    finally:
        db.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    selection = parser.add_mutually_exclusive_group(required=True)
    selection.add_argument('--material-id', type=int)
    selection.add_argument('--all', action='store_true')
    args = parser.parse_args()
    asyncio.run(main(args.material_id, args.all))
