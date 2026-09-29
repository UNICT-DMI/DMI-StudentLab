"""Recover staging Blobs from public materials already confirmed on Drive.

Usage: python scripts/retire_copied_public_blobs.py [--apply] [--limit 100]
Dry run by default. Uses the same database and Blob/Drive configuration as BE.
"""
import argparse
import asyncio
import importlib
import pkgutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import and_

import models
from core.database import SessionLocal
from models.public_material import PublicMaterial
from services.public_drive_blob_retirement import retire_public_staging_blob_best_effort


def import_all_models():
    """Register every relationship target, as BE/alembic/env.py does."""
    for info in pkgutil.walk_packages(models.__path__, prefix=f'{models.__name__}.'):
        importlib.import_module(info.name)


async def run(apply: bool, limit: int):
    import_all_models()
    db = SessionLocal()
    try:
        rows = db.query(PublicMaterial).filter(and_(
            PublicMaterial.drive_file_id.isnot(None),
            PublicMaterial.drive_copied_at.isnot(None),
            PublicMaterial.drive_activation_pending.is_(False),
        )).order_by(PublicMaterial.id).limit(limit).all()
        print(f'Materiali pubblici già copiati su Drive: {len(rows)}')
        for material in rows:
            if not apply:
                print(f'{material.id}: candidato; nessun file modificato')
                continue
            result = await retire_public_staging_blob_best_effort(db, material)
            print(f'{material.id}: {result}')
    finally:
        db.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true', help='Verifica Drive e rimuove i soli Blob non condivisi')
    parser.add_argument('--limit', type=int, default=100)
    args = parser.parse_args()
    if args.limit < 1 or args.limit > 1000:
        parser.error('--limit deve essere tra 1 e 1000')
    asyncio.run(run(args.apply, args.limit))
