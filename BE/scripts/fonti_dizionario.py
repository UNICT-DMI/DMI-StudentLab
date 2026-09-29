#!/usr/bin/env python3
"""Fonti del Dizionario: legge JSON, PDF, pagine web e banche domande e
prepara BOZZE da moderare. Gira in locale: sul server arriva solo JSON.

Il tipo di ogni fonte si riconosce da solo:
  - JSON con "schema": "studentlab.dictionary/1"  -> dizionario (solo controllato)
  - JSON con domande (lista con "text"/"option")  -> banca domande (termini da
    "term", "metadata.term" o dal testo, come genera_dizionario_da_domande.py)
  - PDF con testo selezionabile (anche OCR)       -> definizioni riconosciute nei paragrafi
    (blocchi "Definizione", verbi definitori, glossari, indice analitico: vedi
    estrazione_termini.py). PDF solo immagine: segnalati, serve prima un OCR.
  - pagina web (http/https) o file .html          -> <dl>, tabelle a 2 colonne,
    righe "Termine: definizione"
  - .txt / .md                                    -> come i PDF (paragrafi, non righe)

Ogni fonte viene registrata (percorso o indirizzo, impronta sha256, ETag, esito,
bozza prodotta). Una fonte invariata non si rilegge; una cambiata produce una
bozza nuova. Le bozze NON vanno in data/**/dictionary/: finiscono nella cartella
delle bozze e, con --invia, arrivano al server come "da moderare".

Esempi (dalla cartella BE/):
  # un file o una cartella (sottocartelle comprese)
  python3 scripts/fonti_dizionario.py ~/Corsi/Reti/ --materia "Reti di calcolatori" \\
      --dipartimento DMI --corso L-31 --anno 2025/2026
  # un elenco di fonti (JSON, vedi --esempio-elenco)
  python3 scripts/fonti_dizionario.py --elenco fonti.json
  # ricontrolla solo le fonti web registrate
  python3 scripts/fonti_dizionario.py --ricontrolla-web
  # stato delle fonti
  python3 scripts/fonti_dizionario.py --stato
  # invia le bozze al server (restano da moderare)
  STUDENTLAB_API=https://… STUDENTLAB_TOKEN=… python3 scripts/fonti_dizionario.py --elenco fonti.json --invia
"""
from __future__ import annotations

import argparse
import hashlib
import html
import json
import os
import re
import sqlite3
import subprocess
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
import urllib.robotparser
from dataclasses import dataclass, field
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path

SCHEMA = 'studentlab.dictionary/1'
USER_AGENT = 'StudentLab-Dizionario/1.0 (+https://studentlab.net)'
MAX_DOWNLOAD = 15 * 1024 * 1024
WEB_PAUSE_SECONDS = 1.0
BE_DIR = Path(__file__).resolve().parent.parent
DEFAULT_REGISTRY = BE_DIR / 'data' / '_fonti' / 'registro.sqlite'
DEFAULT_DRAFTS = BE_DIR / 'data' / '_bozze_dizionario'

sys.path.insert(0, str(Path(__file__).resolve().parent))
import estrazione_termini as et  # noqa: E402
try:  # stesso riconoscimento dei termini dello script delle domande
    from genera_dizionario_da_domande import find_term as question_term
except ImportError:  # pragma: no cover
    question_term = None


# ---------------------------------------------------------------------------
# Utilità
# ---------------------------------------------------------------------------

def now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec='seconds')


def slug(text: str) -> str:
    value = unicodedata.normalize('NFKD', text or '').encode('ascii', 'ignore').decode().lower()
    return re.sub(r'[^a-z0-9]+', '-', value).strip('-')[:80] or 'termine'


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def normalize_year(value: str | None) -> str | None:
    match = re.search(r'(20\d{2})\s*[/-]\s*(\d{2,4})', str(value or ''))
    if not match:
        return None
    start = int(match.group(1))
    return f'{start}/{start + 1}'


DEFINITION = re.compile(
    r"^(?P<term>[\wÀ-ÿ][\wÀ-ÿ '’\-/()+.#]{1,75}?)\s*"
    r"(?::|\s+[–—-]\s+|\s+(?:è|sono|indica|consiste in|si definisce|si dice)\s+)"
    r"\s*(?P<description>\S.{24,})$", re.I,
)
NOISE = re.compile(r'^(?:slide|pagina|pag\.|lezione|esercizio|esempio|nota|figura|fig\.|tabella|capitolo|'
                   r'sommario|indice|domanda|risposta|soluzione|http|www)\b', re.I)


def definition_from_line(line: str) -> tuple[str, str] | None:
    line = re.sub(r'\s+', ' ', line).strip(' •·-*\t')
    match = DEFINITION.fullmatch(line)
    if not match:
        return None
    term = match['term'].strip(' :.-')
    text = match['description'].strip()
    if (NOISE.match(term) or len(term.split()) > 7 or len(text) > 900
            or sum(ch.isalpha() for ch in text) < 25 or term.isdigit()):
        return None
    return term[0].upper() + term[1:], text


@dataclass
class Candidate:
    term: str
    formal: str = ''
    informal: str = ''
    where: str = ''                 # "pagina 12", "riga 40", "domanda 1204"
    quiz_ids: list = field(default_factory=list)
    topic: str | None = None
    excerpt: str = ''               # riga o paragrafo originale, per chi modera
    aliases: list = field(default_factory=list)
    confidence: float | None = None  # 0-1, solo per PDF e testi
    flags: list = field(default_factory=list)
    method: str = ''


# ---------------------------------------------------------------------------
# Lettori
# ---------------------------------------------------------------------------

def _candidates(terms: list) -> list[Candidate]:
    return [Candidate(t.term, formal=t.definition, where=t.where, topic=t.topic, excerpt=t.excerpt,
                      aliases=list(t.aliases), confidence=t.confidence, flags=list(t.flags), method=t.method)
            for t in terms]


def read_text(text: str, diagnostics: list | None = None) -> list[Candidate]:
    return _candidates(et.extract_terms(et.text_pages(text), diagnostics=diagnostics))


def read_text_lines(lines: list[str], where_prefix: str) -> list[Candidate]:
    """Compatibilità: righe singole "Termine: definizione" (usato solo dal lettore HTML)."""
    found = []
    for number, line in enumerate(lines, start=1):
        pair = definition_from_line(line)
        if pair:
            found.append(Candidate(pair[0], formal=pair[1], where=f'{where_prefix} {number}', excerpt=line.strip()[:600]))
    return found


def read_pdf(data: bytes, path: Path | None, diagnostics: list | None = None) -> tuple[list[Candidate], list[str]]:
    pages = et.pdf_pages(data, path)
    texts = ['\n'.join(p.lines) for p in pages]
    if len(''.join(texts).strip()) < 80:
        raise RuntimeError('Testo non estraibile: il PDF sembra una scansione, serve OCR (es. ocrmypdf).')
    return _candidates(et.extract_terms(pages, diagnostics=diagnostics)), texts


class _HtmlDefinitions(HTMLParser):
    """<dl><dt><dd>, tabelle a due colonne e paragrafi "Termine: definizione"."""

    SKIP = {'script', 'style', 'nav', 'footer', 'header', 'noscript', 'form'}
    VOID = {'br', 'img', 'hr', 'meta', 'link', 'input', 'wbr', 'source', 'col', 'area', 'base', 'embed', 'track'}

    def __init__(self, selector_id: str | None):
        super().__init__(convert_charrefs=True)
        self.selector_id = selector_id
        self.selection_depth = 0      # >0 dentro l'elemento scelto con --selettore
        self.skip = 0
        self.candidates: list[Candidate] = []
        self.title = ''
        self._in_title = False
        self._dt: str | None = None
        self._buffer: list[str] = []
        self._row: list[str] | None = None
        self._cell: list[str] | None = None
        self.visible: list[str] = []
        self._current_heading = None

    def _active(self) -> bool:
        return (not self.selector_id or self.selection_depth > 0) and self.skip == 0

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag not in self.VOID:
            if self.selection_depth:
                self.selection_depth += 1
            elif self.selector_id and attrs.get('id') == self.selector_id:
                self.selection_depth = 1
        if tag in self.SKIP:
            self.skip += 1
        if tag == 'title':
            self._in_title = True
        if tag in ('dt', 'dd', 'p', 'li', 'h2', 'h3', 'h4'):
            self._buffer = []
        if tag == 'tr':
            self._row = []
        if tag in ('td', 'th') and self._row is not None:
            self._cell = []
        if tag == 'br':
            self._buffer.append('\n')

    def handle_endtag(self, tag):
        text = ' '.join(''.join(self._buffer).split())
        if self._active():
            if tag == 'dt':
                self._dt = text
            elif tag == 'dd' and self._dt:
                if len(text) >= 20:
                    self.candidates.append(Candidate(self._dt[:120], formal=text, where='elenco di definizioni',
                                                     excerpt=f'{self._dt}: {text}'[:600],
                                                     topic=self._current_heading))
                self._dt = None
            elif tag in ('p', 'li'):
                for chunk in text.split('\n'):
                    pair = definition_from_line(chunk)
                    if pair:
                        self.candidates.append(Candidate(pair[0], formal=pair[1], where='paragrafo',
                                                         excerpt=chunk.strip()[:600],
                                                         topic=self._current_heading))
            elif tag in ('h2', 'h3') and text:
                self._current_heading = text[:120]
        if tag in ('td', 'th') and self._cell is not None and self._row is not None:
            self._row.append(' '.join(''.join(self._cell).split()))
            self._cell = None
        if tag == 'tr' and self._row is not None:
            row = [c for c in self._row if c]
            if self._active() and len(row) == 2 and 2 <= len(row[0]) <= 80 and len(row[1]) >= 20 \
                    and not NOISE.match(row[0]) and row[0].lower() not in ('termine', 'voce', 'parola'):
                self.candidates.append(Candidate(row[0], formal=row[1], where='tabella', topic=self._current_heading,
                                                 excerpt=f'{row[0]} | {row[1]}'[:600]))
            self._row = None
        if tag == 'title':
            self._in_title = False
        if tag in self.SKIP and self.skip:
            self.skip -= 1
        if self.selection_depth and tag not in self.VOID:
            self.selection_depth -= 1

    def handle_data(self, data):
        if self._in_title:
            self.title += data
        if self._active() and data.strip():
            self.visible.append(data.strip())
        self._buffer.append(data)
        if self._cell is not None:
            self._cell.append(data)


def read_html(text: str, selector: str | None) -> tuple[list[Candidate], str, str]:
    selector_id = selector[1:] if selector and selector.startswith('#') else None
    parser = _HtmlDefinitions(selector_id)
    parser.feed(text)
    parser.close()
    return parser.candidates, html.unescape(parser.title.strip()), '\n'.join(parser.visible)


def read_question_bank(items: list[dict]) -> list[Candidate]:
    found: dict[str, Candidate] = {}
    for q in items:
        if not isinstance(q, dict):
            continue
        term = question_term(q) if question_term else (q.get('term') or (q.get('metadata') or {}).get('term'))
        if not term:
            continue
        key = slug(term)
        candidate = found.get(key)
        if candidate is None:
            candidate = found[key] = Candidate(term, where=f'domanda {q.get("id_question") or q.get("id")}',
                                               excerpt=str(q.get('text') or '')[:600],
                                               topic=((q.get('metadata') or {}).get('argoment') or None))
        candidate.formal = candidate.formal or (q.get('formal_explanation') or '').strip()
        candidate.informal = candidate.informal or (q.get('informal_explanation') or '').strip()
        qid = q.get('id_question') or q.get('id')
        if qid is not None and qid not in candidate.quiz_ids:
            candidate.quiz_ids.append(qid)
    return [c for c in found.values() if c.formal or c.informal]


def detect_json(data: bytes) -> tuple[str, object]:
    parsed = json.loads(data.decode('utf-8-sig'))
    if isinstance(parsed, dict) and parsed.get('schema') == SCHEMA:
        return 'dictionary', parsed
    items = parsed.get('questions') if isinstance(parsed, dict) else parsed
    if isinstance(items, list) and any(isinstance(q, dict) and ('text' in q or 'option' in q) for q in items[:20]):
        return 'question_bank', items
    raise RuntimeError('JSON non riconosciuto: né un dizionario StudentLab né una banca domande.')


# ---------------------------------------------------------------------------
# Web (con robots.txt, pausa tra richieste, ETag)
# ---------------------------------------------------------------------------

_robots: dict[str, urllib.robotparser.RobotFileParser] = {}
_last_request = [0.0]


def _allowed(url: str) -> bool:
    parts = urllib.parse.urlsplit(url)
    base = f'{parts.scheme}://{parts.netloc}'
    parser = _robots.get(base)
    if parser is None:
        parser = urllib.robotparser.RobotFileParser(base + '/robots.txt')
        try:
            parser.read()
        except (urllib.error.URLError, OSError):
            parser = None  # robots.txt irraggiungibile: si procede con prudenza
        _robots[base] = parser
    return parser is None or parser.can_fetch(USER_AGENT, url)


def fetch(url: str, etag: str | None, modified: str | None) -> tuple[int, bytes, dict]:
    parts = urllib.parse.urlsplit(url)
    if parts.scheme not in ('http', 'https') or not parts.netloc:
        raise RuntimeError('Indirizzo non valido: usa http:// o https://')
    if not _allowed(url):
        raise RuntimeError('robots.txt del sito non consente la lettura di questa pagina.')
    wait = WEB_PAUSE_SECONDS - (time.monotonic() - _last_request[0])
    if wait > 0:
        time.sleep(wait)
    headers = {'User-Agent': USER_AGENT, 'Accept': 'text/html,application/pdf,application/json;q=0.9,*/*;q=0.5'}
    if etag:
        headers['If-None-Match'] = etag
    if modified:
        headers['If-Modified-Since'] = modified
    request = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            _last_request[0] = time.monotonic()
            data = response.read(MAX_DOWNLOAD + 1)
            if len(data) > MAX_DOWNLOAD:
                raise RuntimeError('La risorsa supera 15 MB.')
            return response.status, data, {k.lower(): v for k, v in response.headers.items()}
    except urllib.error.HTTPError as exc:
        _last_request[0] = time.monotonic()
        if exc.code == 304:
            return 304, b'', {k.lower(): v for k, v in exc.headers.items()}
        raise RuntimeError(f'Il sito ha risposto con errore {exc.code}.') from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f'Sito non raggiungibile: {exc.reason}') from exc


# ---------------------------------------------------------------------------
# Registro delle fonti (SQLite locale)
# ---------------------------------------------------------------------------

REGISTRY_COLUMNS = ['source', 'kind', 'detected', 'subject', 'academic_year', 'sha256', 'etag', 'last_modified',
                    'status', 'entries', 'draft', 'processed_at', 'error', 'recheck', 'extractor']


def open_registry(path: Path) -> sqlite3.Connection:
    path.parent.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(path)
    db.execute('''CREATE TABLE IF NOT EXISTS sources (
        source TEXT NOT NULL, kind TEXT NOT NULL, detected TEXT, subject TEXT NOT NULL, academic_year TEXT NOT NULL,
        sha256 TEXT, etag TEXT, last_modified TEXT, status TEXT NOT NULL, entries INTEGER NOT NULL DEFAULT 0,
        draft TEXT, processed_at TEXT NOT NULL, error TEXT, recheck TEXT,
        PRIMARY KEY (source, subject, academic_year))''')
    columns = {row[1] for row in db.execute('PRAGMA table_info(sources)')}
    if 'extractor' not in columns:
        db.execute('ALTER TABLE sources ADD COLUMN extractor TEXT')     # registri creati prima della v19
        db.commit()
    return db


def registry_get(db: sqlite3.Connection, source: str, subject: str, year: str) -> dict | None:
    row = db.execute(f'SELECT {", ".join(REGISTRY_COLUMNS)} FROM sources WHERE source=? AND subject=? AND academic_year=?',
                     (source, subject, year)).fetchone()
    return dict(zip(REGISTRY_COLUMNS, row)) if row else None


def registry_put(db: sqlite3.Connection, record: dict) -> None:
    values = [record.get(c) for c in REGISTRY_COLUMNS]
    db.execute(f'''INSERT INTO sources ({", ".join(REGISTRY_COLUMNS)}) VALUES ({", ".join("?" * len(REGISTRY_COLUMNS))})
        ON CONFLICT(source, subject, academic_year) DO UPDATE SET
        {", ".join(f"{c}=excluded.{c}" for c in REGISTRY_COLUMNS[1:])}''', values)
    db.commit()


# ---------------------------------------------------------------------------
# Bozze
# ---------------------------------------------------------------------------

FLAG_LABELS = {'incompleto': 'definizione forse incompleta', 'ocr_rumoroso': 'testo OCR rovinato',
               'termine_da_verificare': 'termine da verificare', 'da_verificare_indice': 'trovato dall’indice analitico'}


def draft_document(candidates: list[Candidate], meta: dict, source_label: str, kind: str) -> dict:
    topics: dict[str, dict] = {}
    entries: dict[str, dict] = {}
    default_topic = slug(meta.get('topic') or 'Da classificare')
    for c in sorted(candidates, key=lambda c: -(c.confidence if c.confidence is not None else 1)):
        topic_title = meta.get('topic') or c.topic or 'Da classificare'
        topic_id = slug(topic_title)
        topics.setdefault(topic_id, {'id': topic_id, 'title': topic_title, 'order': len(topics) + 1})
        key = slug(c.term)
        resource = {'type': 'source', 'title': f'{source_label}{", " + c.where if c.where else ""}', 'url': meta.get('url') or ''}
        if key in entries:
            entry = entries[key]
            if resource not in entry['resources']:
                entry['resources'].append(resource)
            entry['quiz_question_ids'] += [q for q in c.quiz_ids if q not in entry['quiz_question_ids']]
            continue
        where = c.where
        if c.confidence is not None:
            # il server mostra "where" a chi modera: affidabilità e segnalazioni si vedono lì
            notes = [f'affidabilità {round(c.confidence * 100)}%'] + [FLAG_LABELS.get(f, f) for f in c.flags]
            where = f'{c.where} · ' + ' · '.join(notes)
        entries[key] = {
            'id': key, 'term': c.term, 'aliases': list(c.aliases)[:10], 'topic': topic_id or default_topic,
            'formal_definition': c.formal, 'informal_definition': c.informal,
            'examples': [], 'exercises': [], 'exam_questions': [], 'related': [],
            'resources': [resource], 'quiz_question_ids': list(c.quiz_ids),
            '_review': {'source': source_label, 'where': where[:200], 'kind': kind, 'needs_review': True,
                        'excerpt': c.excerpt, 'affidabilita': c.confidence, 'segnalazioni': list(c.flags),
                        'metodo': c.method},
        }
    return {
        'schema': SCHEMA,
        'metadata': {
            'university': meta.get('university'), 'department': meta.get('department_name'),
            'department_code': meta.get('department'), 'course_code': meta.get('course'),
            'course': meta.get('course_name'), 'subject': meta['subject'],
            'academic_year': meta['academic_year'], 'teachers': meta.get('teachers') or [],
            'source': meta.get('question_source') or source_label, 'source_kind': kind,
            'generated_at': now(), 'needs_review': True,
        },
        'topics': list(topics.values()),
        'entries': list(entries.values()),
    }


def write_draft(doc: dict, drafts: Path, source: str, checksum: str) -> Path:
    if drafts.name == 'dictionary' or 'dictionary' in drafts.parts[-2:]:
        raise RuntimeError('Le bozze non vanno in data/**/dictionary/: scegli una cartella di bozze.')
    drafts.mkdir(parents=True, exist_ok=True)
    name = f'{slug(doc["metadata"]["subject"])}--{slug(Path(urllib.parse.urlsplit(source).path).stem or source)[:40]}' \
           f'--{checksum[:10]}.json'
    target = drafts / name
    tmp = target.with_suffix('.tmp')
    tmp.write_text(json.dumps(doc, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    tmp.replace(target)
    return target


# ---------------------------------------------------------------------------
# Server: al server arrivano solo risultati, metadati ed estratti
# ---------------------------------------------------------------------------

def api_request(api: str, token: str, method: str, path: str, body: dict | None = None) -> object:
    request = urllib.request.Request(
        api.rstrip('/') + path, method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={'Content-Type': 'application/json', 'Accept': 'application/json',
                 'Authorization': f'Bearer {token}', 'User-Agent': USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            raw = response.read().decode()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode(errors='replace')[:400]
        try:
            detail = json.loads(detail).get('detail') or detail
        except (ValueError, AttributeError):
            pass
        raise RuntimeError(f'Il server ha risposto {exc.code}: {detail}') from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f'Server non raggiungibile: {exc.reason}') from exc


SERVER_STATUS = {'read': 'read', 'unchanged': 'unchanged', 'no_terms': 'no_terms', 'error': 'error'}


def send_results(api: str, token: str, record: dict, meta: dict, server_source_id: int | None,
                 subject_id: int | None) -> dict:
    """Invia il risultato di una fonte letta in locale: registro (metadati,
    indirizzo, estratto del testo) e, se ci sono, i termini come bozze."""
    doc = None
    if record['status'] == 'read' and record.get('draft'):
        doc = json.loads(Path(record['draft']).read_text(encoding='utf-8'))
        doc.pop('_source', None)
    is_url = record['source'].startswith(('http://', 'https://'))
    kind = {'pdf': 'pdf', 'html': 'web' if is_url else 'text', 'text': 'text', 'question_bank': 'question_bank',
            'dictionary': 'json'}.get(record.get('detected') or '', 'web' if is_url else 'local')
    body = {
        'status': SERVER_STATUS.get(record['status'], 'error'),
        'kind': kind, 'label': record.get('label') or Path(urllib.parse.urlsplit(record['source']).path).name
        or record['source'],
        'sha256': record.get('sha256'), 'etag': record.get('etag'), 'last_modified': record.get('last_modified'),
        'entries_found': record.get('entries') or 0, 'error': record.get('error'),
        'text_excerpt': (record.get('text_excerpt') or '')[:20000] or None,
        'metadata': record.get('metadata') or {}, 'academic_year': meta.get('academic_year'),
    }
    if doc is not None:
        body['dictionary'] = doc
    body = {k: v for k, v in body.items() if v is not None}
    if server_source_id:
        return api_request(api, token, 'POST', f'/dictionary/sources/{server_source_id}/results', body)
    body['source'] = {'kind': kind, 'label': body['label'], 'location': record['source'],
                      'academic_year': meta.get('academic_year'), 'topic_title': meta.get('topic'),
                      'selector': meta.get('selector'), 'recheck': meta.get('recheck') or 'none'}
    body['source'] = {k: v for k, v in body['source'].items() if v is not None}
    if subject_id:
        body['subject_id'] = subject_id
    return api_request(api, token, 'POST', '/dictionary/sources/results', body)


# ---------------------------------------------------------------------------
# Elaborazione di una fonte
# ---------------------------------------------------------------------------

def expand_local(path: Path) -> list[Path]:
    path = path.expanduser().resolve()
    if path.is_dir():
        return sorted(p for p in path.rglob('*') if p.is_file()
                      and p.suffix.lower() in ('.json', '.pdf', '.html', '.htm', '.txt', '.md')
                      and '_bozze_dizionario' not in p.parts and 'dictionary' not in p.parts
                      and '_fonti' not in p.parts)
    if path.is_file():
        return [path]
    raise RuntimeError(f'Percorso inesistente: {path}')


def _pdf_info(data: bytes) -> dict:
    try:
        import io
        from pypdf import PdfReader
        reader = PdfReader(io.BytesIO(data))
        info = reader.metadata or {}
        return {k: str(v)[:200] for k, v in {'pdf_title': info.get('/Title'), 'pdf_author': info.get('/Author'),
                                            'pdf_created': info.get('/CreationDate')}.items() if v}
    except Exception:   # i metadati sono facoltativi
        return {}


def process(source: str, meta: dict, db: sqlite3.Connection, drafts: Path, force: bool, dry: bool,
            threshold: float = 0.5, diagnostics: Path | None = None) -> dict:
    subject, year = meta['subject'], meta['academic_year']
    notes: list[str] = []
    old = registry_get(db, source, subject, year)
    is_url = source.startswith(('http://', 'https://'))
    record = {'source': source, 'kind': 'web' if is_url else 'file', 'subject': subject, 'academic_year': year,
              'processed_at': now(), 'recheck': meta.get('recheck') or (old or {}).get('recheck'),
              'entries': 0, 'error': None, 'draft': None, 'detected': None, 'sha256': None,
              'etag': meta.get('etag') if not force else None, 'last_modified': None,
              'label': None, 'text_excerpt': None, 'metadata': {'script': 'fonti_dizionario.py', 'extractor': et.VERSION},
              'extractor': et.VERSION}
    try:
        if is_url:
            status, data, headers = fetch(source, None if force else ((old or {}).get('etag') or meta.get('etag')),
                                          None if force else ((old or {}).get('last_modified') or meta.get('last_modified')))
            if status == 304:
                if old:
                    record.update({k: old[k] for k in ('sha256', 'etag', 'last_modified', 'detected', 'entries', 'draft')})
                record['status'] = 'unchanged'
                if not dry:
                    registry_put(db, record)
                return record
            record['etag'] = headers.get('etag')
            record['last_modified'] = headers.get('last-modified')
            content_type = (headers.get('content-type') or '').lower()
            record['metadata'].update({'content_type': content_type[:100], 'size_bytes': len(data)})
            label = source
            local_path = None
        else:
            local_path = Path(source)
            data = local_path.read_bytes()
            content_type = ''
            label = local_path.name
            record['metadata'].update({'file_name': local_path.name, 'size_bytes': len(data)})
        checksum = sha256(data)
        record['sha256'] = checksum
        if old and not force and old.get('sha256') == checksum and old.get('status') in ('read', 'no_terms', 'unchanged') \
                and old.get('extractor') == et.VERSION and (not old.get('draft') or Path(old['draft']).exists()):
            record.update({k: old[k] for k in ('detected', 'entries', 'draft')})
            record['status'] = 'unchanged'
            if not dry:
                registry_put(db, record)
            return record

        suffix = Path(urllib.parse.urlsplit(source).path).suffix.lower()
        if data[:5] == b'%PDF-' or 'pdf' in content_type or suffix == '.pdf':
            record['detected'] = 'pdf'
            candidates, pages = read_pdf(data, local_path, notes)
            record['text_excerpt'] = '\n\n'.join(f'[pagina {i}]\n{p.strip()}' for i, p in enumerate(pages, 1) if p.strip())
            record['metadata'].update({'pages': len(pages), **_pdf_info(data)})
        elif suffix == '.json' or 'json' in content_type or data.lstrip()[:1] in (b'{', b'['):
            kind, parsed = detect_json(data)
            record['detected'] = kind
            if kind == 'dictionary':
                entries = [e for e in parsed.get('entries', []) if isinstance(e, dict) and e.get('term')]
                record['entries'] = len(entries)
                record['status'] = 'read' if entries else 'no_terms'
                record['text_excerpt'] = '\n'.join(f'{e["term"]}: {e.get("formal_definition") or ""}'
                                                   for e in entries[:300])
                record['metadata'].update({'schema': parsed.get('schema'),
                                           **{f'json_{k}': v for k, v in (parsed.get('metadata') or {}).items()
                                              if isinstance(v, (str, int, float))}})
                if entries and not dry:
                    record['draft'] = str(write_draft(parsed, drafts, source, checksum))
                if not dry:
                    registry_put(db, record)
                return record
            candidates = read_question_bank(parsed)
            record['text_excerpt'] = '\n'.join(str(q.get('text') or '') for q in parsed[:300] if isinstance(q, dict))
            record['metadata'].update({'questions': len(parsed)})
            if local_path is not None:
                try:
                    meta = {**meta, 'question_source': str(local_path.resolve().relative_to(BE_DIR / 'data'))}
                except ValueError:
                    pass
        elif suffix in ('.html', '.htm') or 'html' in content_type:
            record['detected'] = 'html'
            text = data.decode(_charset(content_type), errors='replace')
            candidates, title, visible = read_html(text, meta.get('selector'))
            label = title or label
            record['text_excerpt'] = visible
            record['metadata'].update({'title': title[:200], 'selector': meta.get('selector')})
        else:
            record['detected'] = 'text'
            text = data.decode('utf-8', errors='replace')
            candidates = read_text(text, notes)
            record['text_excerpt'] = text
        record['label'] = label
        found = len(candidates)
        candidates = [c for c in candidates if c.confidence is None or c.confidence >= threshold]
        record['metadata']['below_threshold'] = found - len(candidates)
        if diagnostics is not None:
            _write_diagnostics(diagnostics, source, notes, candidates, threshold)
        record['entries'] = len({slug(c.term) for c in candidates})
        if not candidates:
            record['status'] = 'no_terms'
        else:
            record['status'] = 'read'
            if not dry:
                doc = draft_document(candidates, {**meta, 'url': source if is_url else ''}, label, record['detected'])
                record['draft'] = str(write_draft(doc, drafts, source, checksum))
    except (OSError, RuntimeError, ValueError, json.JSONDecodeError) as exc:
        record['status'] = 'error'
        record['error'] = str(exc)[:500]
    if record.get('text_excerpt'):
        record['text_excerpt'] = record['text_excerpt'][:20000]
    if not dry:
        registry_put(db, record)
    return record


def _write_diagnostics(folder: Path, source: str, notes: list[str], candidates: list[Candidate], threshold: float) -> None:
    folder.mkdir(parents=True, exist_ok=True)
    name = slug(Path(urllib.parse.urlsplit(source).path).stem or source)[:60]
    lines = [f'# {source}', f'# soglia di affidabilità: {threshold}', '',
             '## Voci tenute (affidabilità, metodo, termine, segnalazioni)']
    lines += [f'{c.confidence if c.confidence is not None else "-"}\t{c.method}\t{c.term}\t{",".join(c.flags)}\t{c.where}'
              for c in candidates]
    lines += ['', '## Motivazioni (+ trovato, - scartato)'] + notes
    (folder / f'{name}.txt').write_text('\n'.join(lines) + '\n', encoding='utf-8')


def _charset(content_type: str) -> str:
    match = re.search(r'charset=([\w-]+)', content_type or '')
    return match.group(1) if match else 'utf-8'


# ---------------------------------------------------------------------------
# Riga di comando
# ---------------------------------------------------------------------------

EXAMPLE_LIST = {
    'defaults': {'university': 'UNICT', 'department': 'DMI', 'course': 'L-31', 'academic_year': '2025/2026'},
    'sources': [
        {'path': '~/Corsi/Reti/slide', 'subject': 'Reti di calcolatori', 'subject_id': 42},
        {'path': 'data/dmi/l-31/question/strutture_discrete.json', 'subject': 'Strutture discrete'},
        {'url': 'https://example.org/reti/glossario', 'subject': 'Reti di calcolatori',
         'selector': '#glossario', 'recheck': 'weekly', 'topic': 'Glossario'},
    ],
}

RECHECK_DAYS = {'daily': 1, 'weekly': 7, 'monthly': 30}


def load_list(path: Path) -> list[dict]:
    text = path.read_text(encoding='utf-8-sig')
    if path.suffix.lower() == '.json':
        data = json.loads(text)
        defaults = data.get('defaults') or {}
        return [{**defaults, **item} for item in data.get('sources', [])]
    items = []  # TXT: un percorso o indirizzo per riga, # per i commenti
    for row in text.splitlines():
        row = row.strip()
        if row and not row.startswith('#'):
            items.append({'url': row} if row.startswith(('http://', 'https://')) else
                         {'path': row if Path(row).expanduser().is_absolute() else str(path.parent / row)})
    return items


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('fonti', nargs='*', help='file, cartelle o indirizzi web')
    parser.add_argument('--elenco', type=Path, help='elenco delle fonti: JSON (vedi --esempio-elenco) o TXT')
    parser.add_argument('--materia', help='nome della materia (come in StudentLab)')
    parser.add_argument('--materia-id', type=int, help='id della materia su StudentLab (consigliato con --invia)')
    parser.add_argument('--ateneo', default=None)
    parser.add_argument('--dipartimento', help='codice del dipartimento, es. DMI')
    parser.add_argument('--corso', help='codice del corso, es. L-31')
    parser.add_argument('--anno', help='anno accademico, es. 2025/2026')
    parser.add_argument('--argomento', help='argomento proposto per i termini trovati')
    parser.add_argument('--selettore', help='solo per il web: parte della pagina, es. #glossario')
    parser.add_argument('--ricontrolla', choices=['none', 'daily', 'weekly', 'monthly'],
                        help='solo per il web: ogni quanto ricontrollare la pagina')
    parser.add_argument('--registro', type=Path, default=DEFAULT_REGISTRY)
    parser.add_argument('--bozze', type=Path, default=DEFAULT_DRAFTS)
    parser.add_argument('--forza', action='store_true', help='rilegge anche le fonti invariate')
    parser.add_argument('--prova', action='store_true', help='non scrive bozze né registro e non invia nulla')
    parser.add_argument('--ricontrolla-web', action='store_true', help='rilegge le fonti web del registro locale quando è ora')
    parser.add_argument('--sincronizza', action='store_true',
                        help='legge le pagine web aggiunte dall’app (Dizionario › Fonti) e invia i risultati')
    parser.add_argument('--stato', action='store_true', help='mostra il registro locale delle fonti')
    parser.add_argument('--invia', action='store_true',
                        help='invia risultati, metadati ed estratti al server (servono STUDENTLAB_API e STUDENTLAB_TOKEN)')
    parser.add_argument('--esempio-elenco', action='store_true', help='stampa un elenco di esempio')
    parser.add_argument('--soglia', type=float, default=0.5,
                        help='affidabilità minima (0-1) delle voci da PDF/testo; 0 = tutte (default 0.5)')
    parser.add_argument('--diagnosi', type=Path,
                        help='cartella dove scrivere, per ogni fonte, voci trovate e motivi degli scarti')
    args = parser.parse_args()

    if args.esempio_elenco:
        print(json.dumps(EXAMPLE_LIST, ensure_ascii=False, indent=2))
        return 0
    db = open_registry(args.registro)

    if args.stato:
        rows = db.execute('SELECT source, detected, subject, academic_year, status, entries, processed_at, error '
                          'FROM sources ORDER BY processed_at DESC').fetchall()
        if not rows:
            print('Registro vuoto.')
        for source, detected, subject, year, status, entries, when, error in rows:
            print(f'{status:10} {detected or "-":14} {entries:5} termini  {subject} {year}  {when}\n'
                  f'           {source}' + (f'\n           ✗ {error}' if error else ''))
        return 0

    api, token = os.environ.get('STUDENTLAB_API'), os.environ.get('STUDENTLAB_TOKEN')
    send = (args.invia or args.sincronizza) and not args.prova
    if send and not (api and token):
        parser.error('--invia e --sincronizza richiedono le variabili STUDENTLAB_API e STUDENTLAB_TOKEN.')

    jobs: list[dict] = []
    if args.elenco:
        jobs.extend(load_list(args.elenco))
    for item in args.fonti:
        jobs.append({'url': item} if item.startswith(('http://', 'https://')) else {'path': item})
    if args.ricontrolla_web:
        for source, subject, year, recheck, when in db.execute(
                "SELECT source, subject, academic_year, recheck, processed_at FROM sources WHERE kind='web'"):
            days = RECHECK_DAYS.get(recheck or '', 0)
            last = datetime.fromisoformat(when) if when else None
            if days and (last is None or (datetime.now(timezone.utc) - last).days >= days):
                jobs.append({'url': source, 'subject': subject, 'academic_year': year, 'recheck': recheck})
    if args.sincronizza:
        due = api_request(api, token, 'GET', '/dictionary/sources/due') or []
        print(f'Pagine web da leggere richieste dall’app: {len(due)}')
        for item in due:
            if item.get('url') and item.get('subject') and item.get('academic_year'):
                jobs.append({'url': item['url'], 'subject': item['subject'], 'subject_id': item.get('subject_id'),
                             'academic_year': item['academic_year'], 'selector': item.get('selector'),
                             'topic': item.get('topic'), 'recheck': item.get('recheck'),
                             'department': item.get('department_code'), 'course': item.get('course_code'),
                             'server_source_id': item['id'], 'etag': item.get('etag'),
                             'last_modified': item.get('last_modified')})
    if not jobs:
        parser.error('Indica almeno una fonte, --elenco, --ricontrolla-web o --sincronizza.')

    failed = False
    summary = {'read': 0, 'unchanged': 0, 'no_terms': 0, 'error': 0, 'sent': 0}
    for job in jobs:
        meta = {
            'subject': job.get('subject') or args.materia,
            'academic_year': normalize_year(job.get('academic_year') or args.anno),
            'university': job.get('university') or args.ateneo,
            'department': job.get('department') or args.dipartimento,
            'course': job.get('course') or args.corso,
            'topic': job.get('topic') or args.argomento,
            'selector': job.get('selector') or args.selettore,
            'teachers': job.get('teachers') or [],
            'recheck': job.get('recheck') or args.ricontrolla,
            'etag': job.get('etag'), 'last_modified': job.get('last_modified'),
        }
        if not meta['subject'] or not meta['academic_year']:
            print(f'✗ {job.get("path") or job.get("url")}: indica materia e anno (es. --materia … --anno 2025/2026)')
            failed = True
            continue
        if 'url' in job:
            sources = [job['url']]
        else:
            try:
                sources = [str(p) for p in expand_local(Path(job['path']))]
            except RuntimeError as exc:
                print(f'✗ {exc}')
                failed = True
                continue
        for source in sources:
            record = process(source, meta, db, args.bozze, args.forza, args.prova, args.soglia, args.diagnosi)
            status = record['status']
            summary[status] = summary.get(status, 0) + 1
            mark = {'read': '✓', 'unchanged': '=', 'no_terms': '·', 'error': '✗'}.get(status, '?')
            below = (record.get('metadata') or {}).get('below_threshold')
            detail = record['error'] if status == 'error' else f'{record["entries"]} termini' + (
                f' ({below} sotto la soglia {args.soglia}, non inclusi)' if below else '')
            print(f'{mark} [{record.get("detected") or "?"}] {source}\n    {detail}'
                  + (f' → {record["draft"]}' if record.get('draft') and status == 'read' else ''))
            if status == 'error':
                failed = True
            if not send or (status == 'unchanged' and not job.get('server_source_id')):
                continue
            try:
                result = send_results(api, token, record, meta, job.get('server_source_id'),
                                      job.get('subject_id') or args.materia_id)
                if isinstance(result, dict) and result.get('saved') is False:
                    names = ', '.join(f'{c["id"]}={c["name"]}' for c in result.get('candidates') or []) or 'nessuna'
                    print(f'    ! Materia non riconosciuta dal server: usa --materia-id (candidate: {names}).')
                    continue
                report = (result or {}).get('report') or {}
                summary['sent'] += 1
                print(f'    inviata: {report.get("created", 0)} bozze nuove, {report.get("updated", 0)} aggiornate, '
                      f'{report.get("already_published", 0)} già pubblicate · da moderare in app'
                      if report and status == 'read' else '    registro aggiornato sul server')
            except RuntimeError as exc:
                print(f'    ✗ {exc}')
                failed = True
    print('\nRiepilogo: ' + ', '.join(f'{k} {v}' for k, v in summary.items() if v))
    if not send and summary['read']:
        print(f'Bozze in {args.bozze}. Caricale dall’app (Dizionario › Fonti › Carica JSON) oppure rilancia con --invia.')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
