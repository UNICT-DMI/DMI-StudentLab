"""Aree didattiche degli esercizi: quali tipi di esercizio servono a ogni dipartimento e corso.

Niente database: la configurazione predefinita è qui sotto (i 17 dipartimenti dell'Università di
Catania e le due Strutture Didattiche Speciali); l'admin può cambiarla dall'app e la versione
modificata si salva in data/exercise_areas.json in locale o in un Blob privato su Vercel.

Serve a due cose:
  * lo studente non vede le schede di tipi estranei al suo corso (es. "Scrivi il codice" a
    Giurisprudenza), a meno che il docente non abbia comunque caricato esercizi di quel tipo;
  * il docente, quando crea un esercizio, vede prima i tipi consigliati per il suo corso.
Non blocca nulla: un tipo fuori area resta creabile e, se ha esercizi, visibile.
"""
from __future__ import annotations

import contextlib
import json
import os
import re
import tempfile
import threading
import unicodedata
from copy import deepcopy
from pathlib import Path
from typing import Any

from services.exercise_types import TYPES
from core.config import settings

try:
    from services.quiz_service import DATA_ROOT
except Exception:  # pragma: no cover - test senza il resto del backend
    DATA_ROOT = Path(__file__).resolve().parent.parent / 'data'

CONFIG_FILE = 'exercise_areas.json'
CONFIG_BLOB = 'exercise-config/v1/exercise_areas.json'
MULTIPLE_CHOICE = 'multiple_choice'

# Tipi adatti a qualunque materia: il contenuto lo scrive il docente.
GENERIC = ['scelta', 'vero_falso', 'caso', 'categorizza', 'ordina', 'abbina', 'completa',
           'risposta_breve']

DEFAULT_CONFIG: dict[str, Any] = {
    'version': 1,
    'areas': {
        'informatica': {
            'label': 'Informatica',
            'types': GENERIC + ['errore', 'diagramma', 'numerica', 'traccia', 'grafo', 'codice'],
            'examples': 'Ordina i passi di Dijkstra · codice con test · traccia lo scheduling',
        },
        'matematica_fisica': {
            'label': 'Matematica e fisica',
            'types': GENERIC + ['numerica', 'errore', 'diagramma'],
            'examples': 'Vero/falso motivato su un teorema · numerica con unità e tolleranza · trova l’errore nella dimostrazione',
        },
        'ingegneria': {
            'label': 'Ingegneria e architettura',
            'types': GENERIC + ['numerica', 'diagramma', 'errore', 'traccia'],
            'examples': 'Numerica a passi (verifica di una trave) · tocca sulla pianta · trova l’errore nel calcolo',
        },
        'scienze': {
            'label': 'Chimica, biologia, geologia, agraria',
            'types': GENERIC + ['numerica', 'diagramma', 'linea_tempo', 'errore'],
            'examples': 'Categorizza procarioti/eucarioti · stechiometria a passi · ere geologiche in ordine',
        },
        'salute': {
            'label': 'Medicina, professioni sanitarie, farmacia',
            'types': GENERIC + ['numerica', 'diagramma'],
            'examples': 'Caso clinico a passi · calcolo del dosaggio · tocca sull’immagine anatomica',
        },
        'giuridico_economico': {
            'label': 'Giurisprudenza, economia, scienze politiche',
            'types': GENERIC + ['linea_tempo', 'numerica', 'errore'],
            'examples': 'Caso pratico: individua l’istituto · linea del tempo del processo · indici di bilancio',
        },
        'umanistica': {
            'label': 'Lettere, lingue, formazione',
            'types': GENERIC + ['linea_tempo', 'diagramma', 'errore'],
            'examples': 'Linea del tempo letteraria · trova l’errore grammaticale · caso didattico in classe',
        },
        'generale': {
            'label': 'Altri corsi',
            'types': GENERIC + ['numerica', 'linea_tempo', 'diagramma', 'errore'],
            'examples': 'Tipi generici: vanno bene per ogni materia',
        },
    },
    # Dipartimenti UniCT: "match" sono parole cercate nel codice o nel nome del dipartimento.
    'departments': [
        {'code': 'DI3A', 'name': 'Agricoltura, Alimentazione e Ambiente', 'group': 'Scientifica',
         'area': 'scienze', 'match': ['di3a', 'agricoltura', 'agraria']},
        {'code': 'CHIRMED', 'name': 'Chirurgia generale e specialità medico-chirurgiche', 'group': 'Medica',
         'area': 'salute', 'match': ['chirmed', 'chirurgia generale']},
        {'code': 'DEI', 'name': 'Economia e Impresa', 'group': 'Economica, giuridica, politico-sociale',
         'area': 'giuridico_economico', 'match': ['dei', 'economia e impresa', 'economia']},
        {'code': 'DFA', 'name': 'Fisica e Astronomia “Ettore Majorana”', 'group': 'Scientifica',
         'area': 'matematica_fisica', 'match': ['dfa', 'fisica e astronomia', 'fisica']},
        {'code': 'DSG', 'name': 'Giurisprudenza', 'group': 'Economica, giuridica, politico-sociale',
         'area': 'giuridico_economico', 'match': ['dsg', 'giurisprudenza', 'diritto']},
        {'code': 'DICAR', 'name': 'Ingegneria Civile e Architettura', 'group': 'Ingegneria',
         'area': 'ingegneria', 'match': ['dicar', 'ingegneria civile']},
        {'code': 'DIEEI', 'name': 'Ingegneria Elettrica, Elettronica e Informatica', 'group': 'Ingegneria',
         'area': 'ingegneria', 'match': ['dieei', 'ingegneria elettrica']},
        {'code': 'DMI', 'name': 'Matematica e Informatica', 'group': 'Scientifica',
         'area': 'matematica_fisica', 'match': ['dmi', 'matematica e informatica']},
        {'code': 'MEDCLIN', 'name': 'Medicina Clinica e Sperimentale', 'group': 'Medica',
         'area': 'salute', 'match': ['medclin', 'medicina clinica']},
        {'code': 'DSBGA', 'name': 'Scienze Biologiche, Geologiche e Ambientali', 'group': 'Scientifica',
         'area': 'scienze', 'match': ['dsbga', 'scienze biologiche', 'geologiche']},
        {'code': 'BIOMETEC', 'name': 'Scienze Biomediche e Biotecnologiche', 'group': 'Medica',
         'area': 'salute', 'match': ['biometec', 'biomediche', 'biotecnologiche']},
        {'code': 'DSC', 'name': 'Scienze Chimiche', 'group': 'Scientifica',
         'area': 'scienze', 'match': ['dsc', 'scienze chimiche', 'chimica']},
        {'code': 'DSFS', 'name': 'Scienze del Farmaco e della Salute', 'group': 'Medica',
         'area': 'salute', 'match': ['dsfs', 'farmaco', 'farmacia']},
        {'code': 'DISFOR', 'name': 'Scienze della Formazione', 'group': 'Umanistica e formazione',
         'area': 'umanistica', 'match': ['disfor', 'formazione']},
        {'code': 'DSPS', 'name': 'Scienze Politiche e Sociali', 'group': 'Economica, giuridica, politico-sociale',
         'area': 'giuridico_economico', 'match': ['dsps', 'scienze politiche', 'sociali']},
        {'code': 'DISUM', 'name': 'Scienze Umanistiche', 'group': 'Umanistica e formazione',
         'area': 'umanistica', 'match': ['disum', 'scienze umanistiche', 'lettere']},
        {'code': 'INGRASSIA', 'name': 'Scienze Mediche, Chirurgiche e Tecnologie Avanzate “G.F. Ingrassia”',
         'group': 'Medica', 'area': 'salute', 'match': ['ingrassia', 'tecnologie avanzate']},
        {'code': 'SDS-RG', 'name': 'Struttura Didattica Speciale di Ragusa (Lingue e letterature straniere)',
         'group': 'Umanistica e formazione', 'area': 'umanistica', 'match': ['ragusa', 'sds rg', 'sdsrg']},
        {'code': 'SDS-SR', 'name': 'Struttura Didattica Speciale di Siracusa (Architettura)',
         'group': 'Ingegneria', 'area': 'ingegneria', 'match': ['siracusa', 'sds sr', 'sdssr']},
    ],
    # Regole sul nome del corso: valgono prima di quelle del dipartimento
    # (es. Informatica al DMI e Ingegneria informatica al DIEEI → area informatica).
    'courses': [
        {'match': ['informatic', 'computer science', 'data science'], 'area': 'informatica'},
        {'match': ['infermier', 'ostetric', 'fisioterap', 'logoped', 'tecniche di', 'igiene dentale',
                   'medicina e chirurgia', 'odontoiatria', 'farmacia'], 'area': 'salute'},
        {'match': ['matematic', 'fisica'], 'area': 'matematica_fisica'},
        {'match': ['architettur', 'ingegneria'], 'area': 'ingegneria'},
        {'match': ['giurisprudenza', 'economia', 'scienze politiche', 'servizio sociale'], 'area': 'giuridico_economico'},
        {'match': ['lingue', 'lettere', 'filosofia', 'storia', 'scienze dell educazione', 'formazione primaria'],
         'area': 'umanistica'},
    ],
    'default_area': 'generale',
}

_lock = threading.Lock()
_cache: dict[str, Any] = {'mtime': None, 'config': None}


def _fold(value: Any) -> str:
    text = unicodedata.normalize('NFKD', str(value or '')).casefold()
    text = ''.join(ch for ch in text if not unicodedata.combining(ch))
    return ' '.join(re.sub(r'[^a-z0-9]+', ' ', text).split())


def _path() -> Path:
    return Path(DATA_ROOT) / CONFIG_FILE


def validate(config: Any) -> dict:
    """Controlla una configurazione (quella dell'admin) e la restituisce pulita."""
    if not isinstance(config, dict):
        raise ValueError('Configurazione non valida.')
    areas_in = config.get('areas')
    if not isinstance(areas_in, dict) or not (1 <= len(areas_in) <= 30):
        raise ValueError('Servono da 1 a 30 aree.')
    areas = {}
    for key, area in areas_in.items():
        key = str(key).strip()
        if not re.fullmatch(r'[a-z0-9_]{2,40}', key) or not isinstance(area, dict):
            raise ValueError(f'Area “{key}” non valida: usa lettere minuscole, numeri e _.')
        types = [t for t in dict.fromkeys(str(t) for t in (area.get('types') or []))
                 if t in TYPES and t != 'flashcard']
        if not types:
            raise ValueError(f'L’area “{key}” non ha tipi di esercizio validi.')
        areas[key] = {'label': str(area.get('label') or key).strip()[:80], 'types': types,
                      'examples': str(area.get('examples') or '').strip()[:300]}
    default_area = str(config.get('default_area') or '')
    if default_area not in areas:
        raise ValueError('L’area predefinita deve essere una delle aree.')

    def rules(items: Any, name: str, with_names: bool) -> list[dict]:
        if not isinstance(items, list) or len(items) > 200:
            raise ValueError(f'{name}: serve un elenco (massimo 200).')
        result = []
        for raw in items:
            if not isinstance(raw, dict) or str(raw.get('area')) not in areas:
                raise ValueError(f'{name}: ogni voce deve indicare un’area esistente.')
            match = [_fold(m) for m in (raw.get('match') or []) if _fold(m)][:20]
            if not match:
                raise ValueError(f'{name}: ogni voce ha almeno una parola da cercare.')
            rule = {'area': str(raw['area']), 'match': match}
            if with_names:
                rule.update({'code': str(raw.get('code') or '').strip()[:20],
                             'name': str(raw.get('name') or '').strip()[:160],
                             'group': str(raw.get('group') or '').strip()[:80]})
            result.append(rule)
        return result

    return {'version': 1, 'areas': areas, 'default_area': default_area,
            'departments': rules(config.get('departments') or [], 'Dipartimenti', True),
            'courses': rules(config.get('courses') or [], 'Corsi', False)}


def load() -> dict:
    """Configurazione attuale: quella salvata dall'admin, altrimenti quella predefinita."""
    if settings.is_vercel and settings.blob_read_write_token:
        from vercel.blob import BlobClient, BlobNotFoundError
        try:
            with BlobClient(token=settings.blob_read_write_token) as client:
                response = client.get(CONFIG_BLOB, access='private', use_cache=False)
            if response is not None and response.status_code == 200:
                return validate(json.loads(response.content))
        except (BlobNotFoundError, ValueError, json.JSONDecodeError):
            pass
        except Exception as exc:
            raise ValueError('Configurazione delle aree non disponibile.') from exc
        return validate(DEFAULT_CONFIG)
    path = _path()
    try:
        mtime = path.stat().st_mtime
    except OSError:
        mtime = None
    with _lock:
        if _cache['config'] is not None and _cache['mtime'] == mtime:
            return deepcopy(_cache['config'])
        config = None
        if mtime is not None:
            try:
                config = validate(json.loads(path.read_text(encoding='utf-8')))
            except (OSError, ValueError, json.JSONDecodeError):
                config = None          # file rovinato: si usa quella predefinita
        if config is None:
            config = validate(DEFAULT_CONFIG)
        _cache.update({'mtime': mtime, 'config': config})
        return deepcopy(config)


def save(config: Any) -> dict:
    clean = validate(config)
    if settings.is_vercel:
        if not settings.blob_read_write_token:
            raise ValueError('Storage della configurazione non disponibile.')
        from vercel.blob import BlobClient
        try:
            with BlobClient(token=settings.blob_read_write_token) as client:
                client.put(CONFIG_BLOB, json.dumps(clean, ensure_ascii=False).encode('utf-8'),
                           access='private', content_type='application/json',
                           add_random_suffix=False, overwrite=True, cache_control_max_age=60)
        except Exception as exc:
            raise ValueError('Non riesco a salvare la configurazione.') from exc
        return clean
    path = _path()
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile('w', encoding='utf-8', dir=path.parent, prefix='.exercise_areas_',
                                         suffix='.tmp', delete=False) as handle:
            temporary = Path(handle.name)
            json.dump(clean, handle, ensure_ascii=False, indent=2)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    except OSError as exc:
        if temporary is not None:
            with contextlib.suppress(OSError):
                temporary.unlink()
        raise ValueError('Non riesco a salvare la configurazione.') from exc
    with _lock:
        _cache.update({'mtime': None, 'config': None})
    return clean


def reset() -> dict:
    if settings.is_vercel:
        return save(DEFAULT_CONFIG)
    with contextlib.suppress(OSError):
        _path().unlink()
    with _lock:
        _cache.update({'mtime': None, 'config': None})
    return load()


def _is_code(word: str) -> bool:
    return ' ' not in word and len(word) <= 5


def _matches(text: str, words: list[str]) -> bool:
    """Parole lunghe o frasi: inizio di parola (informatic → informatica)."""
    padded = f' {text} '
    return any(f' {w}' in padded for w in words if not _is_code(w))


def _department_matches(rule: dict, code_text: str, name_text: str) -> bool:
    # i codici brevi (dei, dsg, dmi…) valgono solo come codice intero, mai dentro un nome:
    # "dei" è anche una parola italiana
    codes = {_fold(rule.get('code'))} | {w for w in rule['match'] if _is_code(w)}
    if code_text and code_text in codes:
        return True
    return _matches(code_text, rule['match']) or _matches(name_text, rule['match'])


def resolve(department: str = '', course: str = '', *, department_name: str = '', course_name: str = '',
            config: dict | None = None) -> dict:
    """Area del corso: prima le regole sul corso, poi quelle sul dipartimento, poi l'area predefinita."""
    config = config or load()
    course_text = _fold(f'{course} {course_name}')
    code_text, name_text = _fold(department), _fold(department_name)
    area_key, matched = None, 'default'
    department_rule = next((r for r in config['departments'] if _department_matches(r, code_text, name_text)), None)
    for rule in config['courses']:
        if course_text and _matches(course_text, rule['match']):
            area_key, matched = rule['area'], 'course'
            break
    if area_key is None and department_rule is not None:
        area_key, matched = department_rule['area'], 'department'
    area_key = area_key or config['default_area']
    area = config['areas'][area_key]
    return {'id': area_key, 'label': area['label'], 'types': [MULTIPLE_CHOICE] + area['types'],
            'examples': area['examples'], 'matched': matched,
            'department': ({'code': department_rule.get('code'), 'name': department_rule.get('name'),
                            'group': department_rule.get('group')} if department_rule else None)}


def public_config() -> dict:
    config = load()
    return {**config, 'all_types': [{'type': k, **v} for k, v in TYPES.items() if k != 'flashcard']}
