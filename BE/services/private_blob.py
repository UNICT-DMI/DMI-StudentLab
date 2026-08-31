from fastapi import HTTPException
from fastapi.responses import Response
from vercel.blob import AsyncBlobClient, BlobClient

from core.config import settings


def require_blob_storage():
    if not settings.blob_read_write_token:
        raise HTTPException(
            status_code=503,
            detail="Il servizio dei materiali è temporaneamente non disponibile.",
        )


def safe_download_name(original_name: str) -> str:
    value = (
        original_name.replace('"', "").replace("\r", "").replace("\n", "").strip()
    )
    return value if value else "materiale"


async def get_private_blob(stored_name: str):
    require_blob_storage()
    try:
        async with AsyncBlobClient(token=settings.blob_read_write_token) as client:
            result = await client.get(stored_name, access="private")
    except Exception as exception:
        raise HTTPException(
            status_code=503,
            detail="Il file è temporaneamente non disponibile.",
        ) from exception

    if result is None or result.status_code != 200:
        raise HTTPException(status_code=404, detail="File non disponibile.")
    return result


async def verify_private_blob(
    *,
    stored_name: str,
    expected_size: int,
    expected_mime_type: str,
):
    require_blob_storage()
    try:
        async with AsyncBlobClient(token=settings.blob_read_write_token) as client:
            result = await client.get(stored_name, access="private")
    except Exception as exception:
        raise HTTPException(
            status_code=400,
            detail="Il file non risulta caricato correttamente.",
        ) from exception

    if result is None or result.status_code != 200:
        raise HTTPException(
            status_code=400,
            detail="Il file caricato non è disponibile.",
        )

    if result.size is not None and result.size != expected_size:
        raise HTTPException(
            status_code=400,
            detail="La dimensione del file caricato non corrisponde alla richiesta.",
        )

    if result.content_type is not None:
        actual_content_type = result.content_type.split(";", 1)[0].strip().lower()
        expected_content_type = expected_mime_type.strip().lower()
        if actual_content_type != expected_content_type:
            raise HTTPException(
                status_code=400,
                detail="Il tipo del file caricato non corrisponde alla richiesta.",
            )
    return result


async def private_blob_response(
    *,
    stored_name: str,
    original_name: str,
    mime_type: str,
    inline: bool = False,
):
    result = await get_private_blob(stored_name)
    disposition = "inline" if inline else "attachment"
    filename = safe_download_name(original_name)
    response_mime_type = result.content_type if result.content_type else mime_type
    headers = {
        "Content-Disposition": f'{disposition}; filename="{filename}"',
        "X-Content-Type-Options": "nosniff",
        "Cache-Control": "private, no-store",
    }
    return Response(
        content=result.content,
        media_type=response_mime_type,
        headers=headers,
    )


async def list_private_blobs(prefix: str | None = None):
    require_blob_storage()
    blobs = []
    cursor = None

    try:
        async with AsyncBlobClient(token=settings.blob_read_write_token) as client:
            while True:
                kwargs = {"limit": 1000}
                if prefix:
                    kwargs["prefix"] = prefix
                if cursor:
                    kwargs["cursor"] = cursor

                result = await client.list_objects(**kwargs)
                blobs.extend(result.blobs)

                cursor = getattr(result, "cursor", None)
                has_more = bool(getattr(result, "has_more", False))
                if not has_more or not cursor:
                    break
    except Exception as exception:
        raise HTTPException(
            status_code=503,
            detail="Impossibile leggere lo storage dei materiali.",
        ) from exception

    return blobs


async def find_private_blob(stored_name: str):
    normalized = stored_name.strip()
    if not normalized:
        return None

    blobs = await list_private_blobs(prefix=normalized)
    for blob in blobs:
        if getattr(blob, "pathname", None) == normalized:
            return blob
    return None


async def private_blob_exists(stored_name: str) -> bool:
    return await find_private_blob(stored_name) is not None


async def delete_private_blob(stored_name: str) -> bool:
    require_blob_storage()
    blob = await find_private_blob(stored_name)
    if blob is None:
        return False

    url = getattr(blob, "url", None)
    if not url:
        raise HTTPException(
            status_code=503,
            detail="Il file non può essere eliminato dallo storage.",
        )

    try:
        async with AsyncBlobClient(token=settings.blob_read_write_token) as client:
            await client.delete([url])
    except Exception as exception:
        raise HTTPException(
            status_code=503,
            detail="Impossibile eliminare il file dallo storage.",
        ) from exception
    return True


def delete_private_blob_sync(stored_name: str) -> bool:
    require_blob_storage()
    normalized = stored_name.strip()
    if not normalized:
        return False

    try:
        with BlobClient(token=settings.blob_read_write_token) as client:
            cursor = None
            while True:
                kwargs = {"limit": 1000, "prefix": normalized}
                if cursor:
                    kwargs["cursor"] = cursor
                result = client.list_objects(**kwargs)

                for blob in result.blobs:
                    if getattr(blob, "pathname", None) == normalized:
                        url = getattr(blob, "url", None)
                        if not url:
                            raise RuntimeError("URL Blob non disponibile.")
                        client.delete([url])
                        return True

                cursor = getattr(result, "cursor", None)
                has_more = bool(getattr(result, "has_more", False))
                if not has_more or not cursor:
                    break
    except HTTPException:
        raise
    except Exception as exception:
        raise HTTPException(
            status_code=503,
            detail="Impossibile eliminare il file dallo storage.",
        ) from exception

    return False