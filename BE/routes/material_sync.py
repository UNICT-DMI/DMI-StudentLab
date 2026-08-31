from datetime import datetime, timezone
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Path, Query, status
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_current_user
from models.user import User
from schemas.material_sync import MaterialSyncManifestResponse
from services.material_download import get_downloadable_material
from services.material_sync import build_material_sync_manifest
from services.private_blob import private_blob_response

MaterialDownloadSource = Literal["public", "teacher", "group"]

router = APIRouter(
    prefix="/materials",
    tags=["materials-sync"],
)


def _normalize_since(
    since: datetime | None,
):
    if since is None:
        return None
    if since.tzinfo is None:
        return since.replace(
            tzinfo=timezone.utc,
        )
    return since.astimezone(
        timezone.utc,
    )


@router.get(
    "/sync-manifest",
    response_model=MaterialSyncManifestResponse,
)
def material_sync_manifest(
    since: datetime | None = Query(
        default=None,
        description=(
            "Restituisce solo i materiali modificati "
            "dopo questo timestamp ISO-8601."
        ),
    ),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return build_material_sync_manifest(
        db,
        user_id=current_user.id,
        since=_normalize_since(since),
    )


@router.get("/{source}/{material_id}/download")
async def material_sync_download(
    source: MaterialDownloadSource,
    material_id: int = Path(gt=0),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        material = get_downloadable_material(
            db,
            source=source,
            material_id=material_id,
            user_id=current_user.id,
        )
    except PermissionError:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Materiale non trovato.",
        )
    except ValueError as exception:
        message = str(exception)
        raise HTTPException(
            status_code=(
                status.HTTP_404_NOT_FOUND
                if message in {
                    "Materiale non trovato.",
                    "Gruppo non trovato.",
                }
                else status.HTTP_400_BAD_REQUEST
            ),
            detail=message,
        )

    return await private_blob_response(
        stored_name=material["stored_name"],
        original_name=material["original_name"],
        mime_type=material["mime_type"],
        inline=False,
    )
