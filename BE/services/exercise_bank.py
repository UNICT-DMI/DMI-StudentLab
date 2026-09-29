"""Banca degli esercizi: data/<dipartimento>/<corso>/exercise/<materia>.json

Stesso meccanismo delle domande (data/**/question/*.json): un file per
materia, scrittura atomica in locale e Blob privato su Vercel. Le domande a risposta multipla restano nei loro
file e non vengono toccate.
"""
from __future__ import annotations

import contextlib
import json
import os
import re
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from services.exercise_generators import GENERATORS
from services.exercise_types import TYPES, clean_data
from services.quiz_service import DATA_ROOT, _normalize_directory, _normalize_subject
from core.config import settings

SCHEMA = 'studentlab.exercise/1'
MAX_EXERCISES_PER_FILE = 3000
MAX_IMPORT = 1000
ATTACHMENT_ROLES = ('statement', 'option', 'diagram', 'solution')
ALLOWED_MIME = {
    'image/png': 'image', 'image/jpeg': 'image', 'image/webp': 'image',
    'application/pdf': 'document', 'text/plain': 'document',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'document',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation': 'document',
}

try:  # stessa normalizzazione dei percorsi degli allegati delle domande
    from services.question_attachment import _normalize_slug as _attachment_slug
except Exception:  # pragma: no cover - fallback se il modulo cambia
    def _attachment_slug(value: str) -> str:
        value = str(value).strip().lower()
        if not value or '..' in value or '/' in value or '\\' in value or '\x00' in value:
            raise ValueError('Percorso non valido.')
        value = re.sub(r'[\s\-]+', '_', value)
        value = re.sub(r'[^a-z0-9_]', '', value)
        return re.sub(r'_+', '_', value).strip('_') or 'x'


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def exercise_file(department: str, course: str, subject: str) -> Path:
    return (DATA_ROOT / _normalize_directory(department) / _normalize_directory(course) / 'exercise'
            / f'{_normalize_subject(subject)}.json')


def _safe_path(path: Path) -> Path:
    root = DATA_ROOT.resolve()
    resolved = path.resolve()
    if root not in resolved.parents:
        raise ValueError('Percorso della materia non valido.')
    return path


def read_exercises(department: str, course: str, subject: str) -> list[dict[str, Any]]:
    path = _safe_path(exercise_file(department, course, subject))
    if settings.is_vercel and settings.blob_read_write_token:
        from vercel.blob import BlobClient, BlobNotFoundError
        try:
            with BlobClient(token=settings.blob_read_write_token) as client:
                response = client.get(_blob_path(path), access='private', use_cache=False)
        except BlobNotFoundError:
            response = None
        except Exception as exc:
            raise ValueError('Non riesco a leggere la banca esercizi.') from exc
        if response is not None and response.status_code == 200:
            try:
                data = json.loads(response.content)
            except (TypeError, ValueError) as exc:
                raise ValueError('L’archivio degli esercizi non è valido.') from exc
            if isinstance(data, dict):
                data = data.get('exercises')
            if not isinstance(data, list):
                raise ValueError('L’archivio degli esercizi non è valido.')
            return [e for e in data if isinstance(e, dict)]
    if not path.is_file():
        return []
    try:
        data = json.loads(path.read_text(encoding='utf-8'))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError('L’archivio degli esercizi non è valido.') from exc
    if isinstance(data, dict):
        data = data.get('exercises')
    return [e for e in data if isinstance(e, dict)] if isinstance(data, list) else []


def _blob_path(path: Path) -> str:
    relative = _safe_path(path).relative_to(DATA_ROOT)
    return 'quiz-exercise-banks/v1/' + relative.as_posix()


@contextlib.contextmanager
def _locked(path: Path):
    if settings.is_vercel:
        # Vercel non permette lock file sul progetto: lo storage è su Blob.
        yield
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    lock_path = path.with_suffix('.lock')
    handle = open(lock_path, 'a+')
    try:
        try:
            import fcntl
            fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
        except (ImportError, OSError):
            pass
        yield
    finally:
        try:
            import fcntl
            fcntl.flock(handle.fileno(), fcntl.LOCK_UN)
        except (ImportError, OSError):
            pass
        handle.close()


def _write(path: Path, exercises: list[dict]) -> None:
    if settings.is_vercel:
        if not settings.blob_read_write_token:
            raise ValueError('Lo storage degli esercizi non è configurato.')
        from vercel.blob import BlobClient
        content = json.dumps(exercises, ensure_ascii=False, indent=2).encode('utf-8')
        if len(content) > 8 * 1024 * 1024:
            raise ValueError('Archivio esercizi troppo grande.')
        try:
            with BlobClient(token=settings.blob_read_write_token) as client:
                client.put(_blob_path(path), content, access='private',
                           content_type='application/json', add_random_suffix=False,
                           overwrite=True, cache_control_max_age=60)
        except Exception as exc:
            raise ValueError('Impossibile salvare gli esercizi in questo momento.') from exc
        return
    temporary = None
    try:
        with tempfile.NamedTemporaryFile('w', encoding='utf-8', dir=path.parent, prefix=f'.{path.stem}_',
                                         suffix='.tmp', delete=False) as handle:
            temporary = Path(handle.name)
            json.dump(exercises, handle, ensure_ascii=False, indent=2)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    except (OSError, TypeError, ValueError) as exc:
        if temporary is not None:
            with contextlib.suppress(OSError):
                temporary.unlink(missing_ok=True)
        raise ValueError('Impossibile salvare gli esercizi in questo momento.') from exc


def _next_id(exercises: list[dict]) -> str:
    numbers = [int(e['id_exercise']) for e in exercises if str(e.get('id_exercise', '')).isdigit()]
    return str(max(numbers, default=0) + 1)


# ----------------------------------------------------------------- allegati
def clean_attachments(raw: Any, *, department: str, course: str, subject: str, actor_id: int | None,
                      previous: list[dict] | None = None) -> list[dict]:
    """Gli allegati si caricano con il flusso esistente delle domande
    (/question-attachments/upload-request … /complete). Qui si accettano solo
    file caricati per QUESTA materia: un allegato non può puntare a un file
    privato di qualcun altro."""
    if raw in (None, ''):
        return []
    if not isinstance(raw, list) or len(raw) > 12:
        raise ValueError('Allegati: al massimo 12.')
    known = {a.get('stored_name'): a for a in previous or [] if isinstance(a, dict)}
    slugs = '/'.join(_attachment_slug(x) for x in (department, course, subject))
    # Solo file appena caricati da CHI salva, per questa materia (o già presenti nel record).
    # I file delle domande (questions/<materia>/<domanda>/…) non si possono riusare qui.
    allowed_prefixes = [f'questions/tmp/{int(actor_id)}/{slugs}/'] if actor_id else []
    result, ids = [], set()
    for item in raw:
        if not isinstance(item, dict):
            raise ValueError('Allegato non valido.')
        attachment_id = str(item.get('id') or '').strip()
        stored = str(item.get('stored_name') or '').strip()
        mime = str(item.get('mime_type') or '').strip().lower()
        if not re.fullmatch(r'[A-Za-z0-9_-]{6,64}', attachment_id) or attachment_id in ids:
            raise ValueError('Identificativo dell’allegato non valido.')
        if mime not in ALLOWED_MIME:
            raise ValueError('Tipo di allegato non ammesso (immagini PNG/JPEG/WebP, PDF, TXT, DOCX, PPTX).')
        if '..' in stored or stored.startswith('/') or '\\' in stored:
            raise ValueError('Percorso dell’allegato non valido.')
        if stored not in known and not any(stored.startswith(p) for p in allowed_prefixes):
            raise ValueError('L’allegato non appartiene a questa materia: caricalo di nuovo da qui.')
        role = item.get('role') if item.get('role') in ATTACHMENT_ROLES else 'statement'
        name = str(item.get('original_name') or 'allegato').replace('/', '_').replace('\\', '_').strip()[:255]
        result.append({'id': attachment_id, 'type': ALLOWED_MIME[mime], 'mime_type': mime, 'original_name': name,
                       'stored_name': stored, 'role': role, 'caption': str(item.get('caption') or '').strip()[:200]})
        ids.add(attachment_id)
    return result


def public_attachments(record: dict) -> list[dict]:
    """Mai il percorso di storage verso il client, e mai gli allegati con la soluzione."""
    return [{k: a.get(k) for k in ('id', 'type', 'mime_type', 'original_name', 'role', 'caption')}
            for a in record.get('attachments') or [] if isinstance(a, dict) and a.get('role') != 'solution']


def stored_names_in_use(department: str, course: str, subject: str) -> set[str]:
    return {str(a.get('stored_name')) for record in read_exercises(department, course, subject)
            for a in record.get('attachments') or [] if isinstance(a, dict) and a.get('stored_name')}


# ----------------------------------------------------------------- record
def clean_record(raw: dict, *, department: str, course: str, subject: str, actor_id: int | None = None,
                 actor_name: str | None = None, previous: dict | None = None) -> dict:
    if not isinstance(raw, dict):
        raise ValueError('Esercizio non valido.')
    kind = str(raw.get('type') or '').strip()
    if kind not in TYPES:
        raise ValueError(f'Tipo non valido: usa uno tra {", ".join(TYPES)}.')
    text = str(raw.get('text') or '').strip()[:4000]
    metadata_in = raw.get('metadata') if isinstance(raw.get('metadata'), dict) else {}
    argument = str(metadata_in.get('argoment') or metadata_in.get('argument') or raw.get('argument') or '').strip()[:255]
    if not argument:
        raise ValueError('Indica l’argomento (metadata.argoment).')
    teachers = metadata_in.get('teacher') or []
    if isinstance(teachers, str):
        teachers = [teachers]
    try:
        difficulty = max(1, min(5, int(metadata_in.get('difficulty') or raw.get('difficulty') or 2)))
    except (TypeError, ValueError):
        difficulty = 2
    record: dict[str, Any] = {
        'id_exercise': str(raw.get('id_exercise') or '').strip()[:40],
        'type': kind,
        'text': text,
        'hint': str(raw.get('hint') or '').strip()[:1000],
        'explanation': str(raw.get('explanation') or '').strip()[:4000],
        'estimed_time': max(10, min(3600, int(raw.get('estimed_time') or 60))),
        'metadata': {'argoment': argument, 'teacher': [str(t).strip()[:120] for t in teachers if str(t).strip()][:10],
                     'year_of_validity': str(metadata_in.get('year_of_validity') or '').strip()[:9],
                     'difficulty': difficulty},
        'attachments': clean_attachments(raw.get('attachments'), department=department, course=course,
                                         subject=subject, actor_id=actor_id,
                                         previous=(previous or {}).get('attachments')),
        'is_active': raw.get('is_active', True) is not False,
        'is_hidden': bool(raw.get('is_hidden', False)),
    }
    generator = raw.get('generator')
    if generator:
        name = generator.get('name') if isinstance(generator, dict) else None
        if name not in GENERATORS or GENERATORS[name][0] != kind:
            raise ValueError('Generatore non valido per questo tipo.')
        record['generator'] = {'name': name, 'difficulty': max(1, min(3, int(generator.get('difficulty') or 2)))}
    else:
        if not text and kind == 'flashcard':
            text = record['text'] = 'Ricordi il significato?'
        if not text:
            raise ValueError('Scrivi la consegna dell’esercizio.')
        record['data'] = clean_data(kind, raw.get('data'))
    attachment_ids = {a['id'] for a in record['attachments']}
    data = record.get('data') or {}
    for option in data.get('options') or []:
        if option.get('attachment_id') and option['attachment_id'] not in attachment_ids:
            raise ValueError('Un’immagine di risposta non è tra gli allegati.')
    if data.get('image_attachment_id') and data['image_attachment_id'] not in attachment_ids:
        raise ValueError('L’immagine del diagramma non è tra gli allegati.')
    now = utc_now()
    record['created_at'] = (previous or {}).get('created_at') or raw.get('created_at') or now
    record['created_by'] = (previous or {}).get('created_by') or actor_name or raw.get('created_by')
    record['updated_at'] = now
    if actor_name:
        record['updated_by'] = actor_name
    return record


# ----------------------------------------------------------------- gestione
def list_for_management(department: str, course: str, subject: str, *, kind: str | None = None,
                        argument: str | None = None, q: str | None = None, include_hidden: bool = True) -> list[dict]:
    result = []
    needle = (q or '').strip().casefold()
    for record in read_exercises(department, course, subject):
        if kind and record.get('type') != kind:
            continue
        if argument and (record.get('metadata') or {}).get('argoment', '').casefold() != argument.casefold():
            continue
        if not include_hidden and (record.get('is_hidden') or record.get('is_active') is False):
            continue
        if needle and needle not in (record.get('text') or '').casefold():
            continue
        result.append(record)
    return result


def get_exercise(department: str, course: str, subject: str, exercise_id: str) -> dict | None:
    for record in read_exercises(department, course, subject):
        if str(record.get('id_exercise')) == str(exercise_id):
            return record
    return None


def create_exercise(department: str, course: str, subject: str, raw: dict, *, actor_id: int, actor_name: str) -> dict:
    path = _safe_path(exercise_file(department, course, subject))
    with _locked(path):
        exercises = read_exercises(department, course, subject)
        if len(exercises) >= MAX_EXERCISES_PER_FILE:
            raise ValueError('Troppi esercizi per questa materia.')
        record = clean_record(raw, department=department, course=course, subject=subject,
                              actor_id=actor_id, actor_name=actor_name)
        record['id_exercise'] = _next_id(exercises)
        exercises.append(record)
        _write(path, exercises)
    return record


def update_exercise(department: str, course: str, subject: str, exercise_id: str, raw: dict, *,
                    actor_id: int, actor_name: str) -> dict:
    path = _safe_path(exercise_file(department, course, subject))
    with _locked(path):
        exercises = read_exercises(department, course, subject)
        for index, previous in enumerate(exercises):
            if str(previous.get('id_exercise')) == str(exercise_id):
                record = clean_record({**previous, **raw}, department=department, course=course, subject=subject,
                                      actor_id=actor_id, actor_name=actor_name, previous=previous)
                record['id_exercise'] = previous['id_exercise']
                exercises[index] = record
                _write(path, exercises)
                return record
    raise ValueError('Esercizio non trovato.')


def set_status(department: str, course: str, subject: str, exercise_id: str, *, is_active: bool | None = None,
               is_hidden: bool | None = None, actor_name: str | None = None) -> dict:
    path = _safe_path(exercise_file(department, course, subject))
    with _locked(path):
        exercises = read_exercises(department, course, subject)
        for record in exercises:
            if str(record.get('id_exercise')) == str(exercise_id):
                if is_active is not None:
                    record['is_active'] = bool(is_active)
                if is_hidden is not None:
                    record['is_hidden'] = bool(is_hidden)
                record['updated_at'] = utc_now()
                if actor_name:
                    record['updated_by'] = actor_name
                _write(path, exercises)
                return record
    raise ValueError('Esercizio non trovato.')


def delete_exercise(department: str, course: str, subject: str, exercise_id: str) -> dict:
    path = _safe_path(exercise_file(department, course, subject))
    with _locked(path):
        exercises = read_exercises(department, course, subject)
        remaining = [e for e in exercises if str(e.get('id_exercise')) != str(exercise_id)]
        if len(remaining) == len(exercises):
            raise ValueError('Esercizio non trovato.')
        removed = next(e for e in exercises if str(e.get('id_exercise')) == str(exercise_id))
        _write(path, remaining)
    return removed


def import_exercises(department: str, course: str, subject: str, payload: Any, *, actor_id: int, actor_name: str,
                     dry_run: bool = False) -> dict:
    """Importa un file JSON: lista di esercizi o {"schema": ..., "exercises": [...]}.
    Ogni esercizio viene validato; gli errori non bloccano gli altri."""
    items = payload.get('exercises') if isinstance(payload, dict) else payload
    if not isinstance(items, list) or not items:
        raise ValueError('Il file deve contenere un elenco di esercizi.')
    if len(items) > MAX_IMPORT:
        raise ValueError(f'Al massimo {MAX_IMPORT} esercizi per file.')
    path = _safe_path(exercise_file(department, course, subject))
    report = {'created': 0, 'skipped_duplicates': 0, 'errors': []}
    with _locked(path):
        exercises = read_exercises(department, course, subject)
        signatures = {json.dumps([e.get('type'), e.get('text'), e.get('data'), e.get('generator')], sort_keys=True,
                                 ensure_ascii=False) for e in exercises}
        for index, raw in enumerate(items, 1):
            try:
                # Negli import gli allegati non sono ammessi: si aggiungono dall'app.
                record = clean_record({**raw, 'attachments': []} if isinstance(raw, dict) else raw,
                                      department=department, course=course, subject=subject,
                                      actor_id=actor_id, actor_name=actor_name)
            except (ValueError, TypeError) as exc:
                report['errors'].append({'index': index, 'message': str(exc)})
                continue
            signature = json.dumps([record['type'], record['text'], record.get('data'), record.get('generator')],
                                   sort_keys=True, ensure_ascii=False)
            if signature in signatures:
                report['skipped_duplicates'] += 1
                continue
            signatures.add(signature)
            record['id_exercise'] = _next_id(exercises)
            exercises.append(record)
            report['created'] += 1
        if not dry_run and report['created']:
            _write(path, exercises)
    return report


def arguments(department: str, course: str, subject: str) -> list[str]:
    seen = []
    for record in read_exercises(department, course, subject):
        argument = (record.get('metadata') or {}).get('argoment')
        if argument and argument not in seen and record.get('is_active', True) and not record.get('is_hidden'):
            seen.append(argument)
    return seen
