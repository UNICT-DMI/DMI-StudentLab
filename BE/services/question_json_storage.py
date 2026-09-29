"""Durable JSON question files for Vercel's read-only function filesystem."""
import json
from pathlib import Path

from core.config import settings

MAX_BANK_BYTES = 8 * 1024 * 1024


def _pathname(path: Path) -> str:
    parts = path.parts
    if not parts or parts[0] != 'data' or '..' in parts or path.suffix != '.json':
        raise ValueError('Percorso archivio domande non valido.')
    return 'quiz-question-banks/v1/' + '/'.join(parts[1:])


def read_question_json(path: Path):
    """Return None only when no saved JSON exists; do not hide storage errors."""
    if not settings.is_vercel or not settings.blob_read_write_token:
        return None
    from vercel.blob import BlobClient, BlobNotFoundError
    try:
        with BlobClient(token=settings.blob_read_write_token) as client:
            response = client.get(_pathname(path), access='private', use_cache=False)
    except BlobNotFoundError:
        return None
    except Exception as exc:
        raise ValueError('Impossibile leggere le domande archiviate in questo momento.') from exc
    if response is None or response.status_code == 404:
        return None
    if response.status_code != 200 or not isinstance(response.content, bytes):
        raise ValueError('Impossibile leggere le domande archiviate in questo momento.')
    if len(response.content) > MAX_BANK_BYTES:
        raise ValueError('Archivio domande troppo grande.')
    try:
        data = json.loads(response.content)
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValueError('L’archivio delle domande salvato non è valido.') from exc
    if not isinstance(data, list) or any(not isinstance(q, dict) for q in data):
        raise ValueError('L’archivio delle domande salvato non è valido.')
    return data


def write_question_json(path: Path, questions: list[dict]) -> bool:
    """Store the *entire JSON file* under a stable, private Blob pathname."""
    if not settings.is_vercel:
        return False
    if not settings.blob_read_write_token:
        raise ValueError('Lo storage delle domande non è configurato.')
    content = json.dumps(questions, ensure_ascii=False, indent=2).encode('utf-8')
    if len(content) > MAX_BANK_BYTES:
        raise ValueError('Archivio domande troppo grande.')
    from vercel.blob import BlobClient
    try:
        with BlobClient(token=settings.blob_read_write_token) as client:
            client.put(_pathname(path), content, access='private',
                       content_type='application/json', add_random_suffix=False,
                       overwrite=True, cache_control_max_age=60)
    except Exception as exc:
        raise ValueError('Impossibile salvare le domande nello storage in questo momento.') from exc
    return True
