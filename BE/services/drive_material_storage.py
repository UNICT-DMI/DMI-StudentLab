"""Copy approved public material to Drive, keeping private Blob as staging."""
import hashlib
import json
import logging
from datetime import datetime, timedelta, timezone
from urllib.parse import urlparse

import httpx
from fastapi import HTTPException
from fastapi.responses import StreamingResponse
from vercel.blob import AsyncBlobClient

from core.config import settings
from services.drive_material_catalog import _children, clean_path, default_path, ensure_path, preview, existing_copy, verify_under_root
from services.private_blob import safe_download_name

API = 'https://www.googleapis.com/drive/v3'
UPLOAD = 'https://www.googleapis.com/upload/drive/v3/files'
TOKEN = 'https://oauth2.googleapis.com/token'
CHUNK = 8 * 1024 * 1024  # Drive resumable chunks must be multiples of 256 KiB.
logger = logging.getLogger(__name__)


def _configured():
    return all((settings.drive_folder_id, settings.drive_client_id,
                settings.drive_client_secret, settings.drive_refresh_token))


async def _access_token(client):
    if not _configured():
        raise HTTPException(503, 'Google Drive non è ancora configurato.')
    try:
        response = await client.post(TOKEN, data={
            'grant_type': 'refresh_token', 'client_id': settings.drive_client_id,
            'client_secret': settings.drive_client_secret,
            'refresh_token': settings.drive_refresh_token,
        })
        response.raise_for_status()
        return response.json()['access_token']
    except (httpx.HTTPError, KeyError, ValueError) as exc:
        raise HTTPException(503, 'Autorizzazione Google Drive non disponibile.') from exc


async def _session():
    return httpx.AsyncClient(timeout=httpx.Timeout(90, connect=10),
                             follow_redirects=False)


async def drive_status():
    if not _configured():
        return {'configured': False, 'folder_id': settings.drive_folder_id}
    async with await _session() as client:
        token = await _access_token(client)
        try:
            response = await client.get(f'{API}/about',
                headers={'Authorization': f'Bearer {token}'},
                params={'fields': 'user(emailAddress),storageQuota(limit,usage,usageInDrive)'})
            response.raise_for_status()
            data = response.json()
            account = data.get('user', {}).get('emailAddress', '')
            if account.lower() != settings.drive_account_email.lower():
                raise HTTPException(503, 'L’account Google collegato non corrisponde a quello configurato.')
            folder = await client.get(f'{API}/files/{settings.drive_folder_id}',
                headers={'Authorization': f'Bearer {token}'},
                params={'fields': 'id,mimeType,capabilities(canAddChildren)'})
            folder.raise_for_status()
            item = folder.json()
            if item.get('mimeType') != 'application/vnd.google-apps.folder' or not item.get('capabilities', {}).get('canAddChildren'):
                raise HTTPException(503, 'L’account collegato non può caricare nella cartella Drive.')
            quota = data.get('storageQuota', {})
            return {'configured': True, 'folder_id': settings.drive_folder_id,
                    'account': account, 'limit_bytes': quota.get('limit'),
                    'used_bytes': quota.get('usage'),
                    'drive_used_bytes': quota.get('usageInDrive')}
        except httpx.HTTPError as exc:
            raise HTTPException(503, 'Cartella o quota Google Drive non disponibili.') from exc


async def _existing(client, headers, material, nodes=None):
    # This also makes an upload retry safe if Drive succeeded but the SQL commit failed.
    for item, _ in nodes if nodes is not None else await scan_tree(client, headers):
        props = item.get('appProperties') or {}
        if (item.get('mimeType') != 'application/vnd.google-apps.folder' and
                props.get('studentlab_public_id') == str(material.id)
                and props.get('sha256', '').lower() == material.file_hash.lower()):
            return item['id']
    return None


async def preview_public_material(material, path=None):
    """Read only: no folder/file is created by the admin preflight."""
    await drive_status()
    stored_path = getattr(material, 'drive_path_json', None)
    selected = clean_path(path if path is not None else
        json.loads(stored_path) if stored_path else default_path(material))
    async with await _session() as client:
        token = await _access_token(client)
        return await preview(client, {'Authorization': f'Bearer {token}'}, material, selected)


def mark_retry(material, exception):
    """Leave staged bytes untouched; collisions wait for an admin decision."""
    material.drive_retry_attempts = (material.drive_retry_attempts or 0) + 1
    collision = isinstance(exception, HTTPException) and exception.status_code == 409
    material.drive_retry_after = datetime.now(timezone.utc) + (
        timedelta(days=365) if collision else timedelta(hours=1))
    return 'awaiting_admin' if collision else 'retry_scheduled'


async def _put(client, url, headers, payload, start, total):
    parsed = urlparse(url)
    if parsed.scheme != 'https' or parsed.netloc != 'www.googleapis.com' or not parsed.path.startswith('/upload/drive/v3/files'):
        raise HTTPException(503, 'Sessione di caricamento Drive non valida.')
    last = start + len(payload) == total
    response = await client.put(url, headers={**headers,
        'Content-Type': 'application/octet-stream',
        'Content-Length': str(len(payload)),
        'Content-Range': f'bytes {start}-{start + len(payload) - 1}/{total}'},
        content=payload)
    if last and response.status_code in (200, 201):
        file_id = response.json().get('id')
        if isinstance(file_id, str) and file_id:
            return file_id
    if not last and response.status_code == 308:
        expected = f'bytes=0-{start + len(payload) - 1}'
        if response.headers.get('Range') == expected:
            return None
    raise HTTPException(503, 'Copia Drive interrotta; riprova dalla pagina Storage.')


async def _blob_chunks(result):
    """Support both the installed SDK (content) and the streaming SDK (stream)."""
    stream = getattr(result, 'stream', None)
    if stream is not None:
        async for piece in stream:
            yield piece
        return
    content = getattr(result, 'content', None)
    if not isinstance(content, (bytes, bytearray, memoryview)):
        raise HTTPException(503, 'Il contenuto del Blob non è disponibile.')
    for start in range(0, len(content), CHUNK):
        yield memoryview(content)[start:start + CHUNK]


async def copy_public_material(material):
    if material.drive_file_id:
        return material.drive_file_id
    if material.status not in {'published', 'hidden'} or material.size <= 0:
        raise HTTPException(400, 'Puoi copiare soltanto materiale pubblico approvato.')
    if not settings.blob_read_write_token:
        raise HTTPException(503, 'Storage Blob temporaneamente non disponibile.')
    # Verify account, folder and permissions before touching the source Blob.
    state = await drive_status()
    limit = state.get('limit_bytes')
    used = state.get('used_bytes')
    if limit is not None and used is not None and int(limit) - int(used) < material.size:
        raise HTTPException(409, 'Spazio Google Drive insufficiente per questa copia.')
    async with await _session() as client:
        token = await _access_token(client)
        headers = {'Authorization': f'Bearer {token}'}
        try:
            selected = clean_path(json.loads(material.drive_path_json)
                if material.drive_path_json else default_path(material))
            found = await existing_copy(client, headers, material)
            if found:
                return found
            inspection = await preview(client, headers, material, selected)
            conflicts = inspection['conflicts']
            if any(item['same_folder'] and item['name'].casefold() ==
                   material.original_name.casefold() for item in conflicts):
                raise HTTPException(409, 'Il file esiste già nella cartella Drive selezionata. Scegli un’altra cartella.')
            if conflicts and not material.drive_allow_duplicate:
                raise HTTPException(409, 'Possibile duplicato su Drive: verifica i dettagli e scegli un percorso.')
            folder_id = await ensure_path(client, headers, selected)
            # A new file could have appeared while folders were being created.
            if any(item.get('name', '').casefold() == material.original_name.casefold()
                   for item in [e async for e in _children(client, headers, folder_id)]):
                raise HTTPException(409, 'Un altro file con lo stesso nome è arrivato nella cartella Drive.')
            metadata = {'name': material.original_name,
                'parents': [folder_id],
                'appProperties': {'studentlab_public_id': str(material.id),
                                  'sha256': material.file_hash}}
            response = await client.post(UPLOAD, headers={**headers,
                'Content-Type': 'application/json',
                'X-Upload-Content-Type': material.mime_type,
                'X-Upload-Content-Length': str(material.size)},
                params={'uploadType': 'resumable', 'fields': 'id',
                        'supportsAllDrives': 'true'}, json=metadata)
            response.raise_for_status()
            session_url = response.headers.get('Location', '')
        except httpx.HTTPError as exc:
            raise HTTPException(503, 'Non è stato possibile iniziare la copia Drive.') from exc
        digest = hashlib.sha256()
        offset = 0
        buffer = bytearray()
        file_id = None
        stage = 'lettura_blob'
        try:
            async with AsyncBlobClient(token=settings.blob_read_write_token) as blob:
                result = await blob.get(material.stored_name, access='private')
                if result is None or result.status_code != 200:
                    raise HTTPException(503, 'Il file sorgente non è disponibile nello storage Blob.')
                async for piece in _blob_chunks(result):
                    if not isinstance(piece, (bytes, bytearray, memoryview)):
                        raise HTTPException(503, 'Il file sorgente non è leggibile.')
                    digest.update(piece)
                    buffer.extend(piece)
                    if offset + len(buffer) > material.size:
                        raise HTTPException(503, 'La dimensione del Blob non corrisponde al database.')
                    while len(buffer) >= CHUNK:
                        part = bytes(buffer[:CHUNK]); del buffer[:CHUNK]
                        stage = 'invio_blocco_drive'
                        file_id = await _put(client, session_url, headers, part,
                                             offset, material.size) or file_id
                        offset += len(part)
                        stage = 'lettura_blob'
                if buffer:
                    stage = 'invio_ultimo_blocco_drive'
                    file_id = await _put(client, session_url, headers,
                        bytes(buffer), offset, material.size) or file_id
                    offset += len(buffer)
        except Exception as exc:
            # Do not log signed Blob/Drive URLs or OAuth credentials.
            code = exc.response.status_code if isinstance(exc, httpx.HTTPStatusError) else None
            logger.error('drive_copy_failed material_id=%s stage=%s error_type=%s upstream_status=%s offset=%s size=%s',
                         material.id, stage, type(exc).__name__, code, offset, material.size)
            if isinstance(exc, HTTPException):
                raise
            raise HTTPException(503, 'Copia Drive interrotta. Il file originale è conservato; riprova dalla pagina Storage.') from exc
        if offset != material.size or digest.hexdigest().lower() != material.file_hash.lower():
            if file_id:
                try:
                    await client.delete(f'{API}/files/{file_id}', headers=headers)
                except httpx.HTTPError:
                    pass
            raise HTTPException(503, 'Verifica del file non riuscita: la copia Drive non è stata registrata.')
        if not file_id:
            raise HTTPException(503, 'Drive non ha confermato il completamento della copia.')
        return file_id


async def delete_public_drive_copy(material):
    """Delete only this app's confirmed copy after explicit admin confirmation."""
    if not material.drive_file_id:
        raise HTTPException(404, 'Nessuna copia Drive collegata.')
    await drive_status()
    async with await _session() as client:
        token = await _access_token(client)
        headers = {'Authorization': f'Bearer {token}'}
        try:
            data = await verify_under_root(client, headers, material.drive_file_id)
            properties = data.get('appProperties', {})
            if properties.get('studentlab_public_id') != str(material.id):
                raise HTTPException(409, 'La copia Drive non corrisponde al materiale selezionato.')
            deleted = await client.delete(f'{API}/files/{material.drive_file_id}',
                headers=headers, params={'supportsAllDrives': 'true'})
            if deleted.status_code not in (204, 404):
                deleted.raise_for_status()
        except httpx.HTTPError as exc:
            raise HTTPException(503, 'Non è stato possibile eliminare la copia Drive.') from exc


async def public_drive_response(*, drive_file_id: str, original_name: str,
                                mime_type: str, inline: bool = False):
    """Stream a private Drive file through the already-authorized API route."""
    client = await _session()
    try:
        token = await _access_token(client)
        request = client.build_request('GET', f'{API}/files/{drive_file_id}',
            headers={'Authorization': f'Bearer {token}'},
            params={'alt': 'media', 'supportsAllDrives': 'true'})
        response = await client.send(request, stream=True)
        if response.status_code != 200:
            await response.aclose()
            await client.aclose()
            raise HTTPException(503, 'Il materiale Drive non è disponibile.')
    except Exception:
        await client.aclose()
        raise

    async def chunks():
        try:
            async for piece in response.aiter_bytes(chunk_size=1024 * 1024):
                yield piece
        finally:
            await response.aclose()
            await client.aclose()

    disposition = 'inline' if inline else 'attachment'
    return StreamingResponse(chunks(), media_type=mime_type,
        headers={'Content-Disposition': f'{disposition}; filename="{safe_download_name(original_name)}"',
                 'X-Content-Type-Options': 'nosniff', 'Cache-Control': 'private, no-store'})
