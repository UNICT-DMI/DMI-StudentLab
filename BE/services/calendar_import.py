"""Lettura dei calendari accademici da PDF (tabelle), CSV, iCal, JSON e pagine
web (tabelle HTML). Tutto viene normalizzato in eventi con gli stessi campi;
le righe dubbie portano degli avvisi e vanno confermate prima dell'import."""
import csv
import io
import json
import re
from datetime import date, datetime, time, timedelta
from html.parser import HTMLParser

MONTHS = {'gennaio': 1, 'febbraio': 2, 'marzo': 3, 'aprile': 4, 'maggio': 5, 'giugno': 6, 'luglio': 7,
          'agosto': 8, 'settembre': 9, 'ottobre': 10, 'novembre': 11, 'dicembre': 12,
          'gen': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'mag': 5, 'giu': 6, 'lug': 7, 'ago': 8, 'set': 9,
          'ott': 10, 'nov': 11, 'dic': 12}

# Intestazioni riconosciute (in minuscolo, senza accenti) -> campo
HEADERS = {
    'date': ('data', 'giorno', 'date', 'data appello', 'data esame', 'dal', 'inizio'),
    'end_date': ('al', 'fine', 'data fine', 'end'),
    'time': ('ora', 'orario', 'ore', 'time', 'ora inizio', 'inizio ore'),
    'end_time': ('ora fine', 'fino alle', 'end time'),
    'subject': ('materia', 'insegnamento', 'corso', 'disciplina', 'esame', 'subject', 'modulo'),
    'kind': ('tipo', 'tipologia', 'evento', 'type', 'categoria'),
    'format': ('modalita', 'prova', 'forma', 'format'),
    'room': ('aula', 'luogo', 'sede', 'room', 'location', 'aula/sede'),
    'teachers': ('docente', 'docenti', 'commissione', 'presidente', 'teacher', 'teachers'),
    'notes': ('note', 'descrizione', 'notes', 'description', 'info'),
    'booking_url': ('prenotazione', 'link', 'iscrizione', 'url'),
    'booking_deadline': ('scadenza', 'prenotazioni entro', 'entro', 'deadline'),
}


def _plain(text) -> str:
    value = str(text or '').strip().lower()
    for a, b in (('à', 'a'), ('è', 'e'), ('é', 'e'), ('ì', 'i'), ('ò', 'o'), ('ù', 'u')):
        value = value.replace(a, b)
    return re.sub(r'\s+', ' ', value)


def parse_date(text, default_year: int | None = None) -> date | None:
    value = _plain(text)
    if not value:
        return None
    m = re.search(r'(\d{4})-(\d{1,2})-(\d{1,2})', value)
    if m:
        return _safe_date(int(m.group(1)), int(m.group(2)), int(m.group(3)))
    m = re.search(r'(\d{1,2})[/.\-](\d{1,2})(?:[/.\-](\d{2,4}))?', value)
    if m:
        year = int(m.group(3)) if m.group(3) else (default_year or date.today().year)
        year = year + 2000 if year < 100 else year
        return _safe_date(year, int(m.group(2)), int(m.group(1)))
    m = re.search(r'(\d{1,2})\s+([a-z]{3,9})\.?(?:\s+(\d{4}))?', value)
    if m and m.group(2) in MONTHS:
        return _safe_date(int(m.group(3)) if m.group(3) else (default_year or date.today().year),
                          MONTHS[m.group(2)], int(m.group(1)))
    return None


def _safe_date(y, m, d):
    try:
        return date(y, m, d)
    except ValueError:
        return None


def parse_time(text) -> time | None:
    m = re.search(r'(?<!\d)(\d{1,2})(?:[:.h](\d{2}))?(?!\d)', _plain(text).replace('ore', ' '))
    if not m:
        return None
    hour, minute = int(m.group(1)), int(m.group(2) or 0)
    return time(hour, minute) if 0 <= hour <= 23 and 0 <= minute <= 59 else None


def guess_kind(*texts) -> str:
    value = ' '.join(_plain(t) for t in texts if t)
    if 'straordin' in value:
        return 'extraordinary'
    if any(w in value for w in ('chiusur', 'festa', 'festivit', 'vacanz', 'sospension', 'ponte')):
        return 'closure'
    if 'session' in value:
        return 'session'
    if 'lezion' in value or 'semestre' in value or 'periodo didattic' in value:
        return 'lessons'
    if any(w in value for w in ('appello', 'esame', 'prova', 'scritto', 'orale')):
        return 'exam'
    if any(w in value for w in ('laurea', 'seminario', 'evento', 'open day', 'workshop')):
        return 'event'
    return 'exam'


def guess_format(*texts) -> str | None:
    value = ' '.join(_plain(t) for t in texts if t)
    written, oral = 'scritt' in value, 'oral' in value
    if 'progett' in value:
        return 'progetto'
    if written and oral:
        return 'scritto_orale'
    return 'scritto' if written else ('orale' if oral else None)


def _field_for(header: str) -> str | None:
    value = _plain(header).strip(':')
    for field, names in HEADERS.items():
        if value in names:
            return field
    for field, names in HEADERS.items():
        if any(value.startswith(n) for n in names if len(n) > 3):
            return field
    return None


def rows_to_events(rows: list[list[str]], source: str, default_year: int | None = None) -> list[dict]:
    """Tabelle (PDF, CSV, HTML): trova la riga di intestazione e mappa le colonne."""
    rows = [[str(c or '').strip() for c in r] for r in rows if any(str(c or '').strip() for c in r)]
    if not rows:
        return []
    header_index, mapping = 0, {}
    for index, row in enumerate(rows[:6]):
        candidate = {i: _field_for(c) for i, c in enumerate(row)}
        candidate = {i: f for i, f in candidate.items() if f}
        if 'date' in candidate.values() and len(candidate) >= 2:
            header_index, mapping = index, candidate
            break
    if not mapping:
        # Senza intestazione: la prima colonna con una data è la data, la più lunga il titolo.
        return [e for e in (_loose_row(r, source, default_year) for r in rows) if e]
    events = []
    for number, row in enumerate(rows[header_index + 1:], start=header_index + 2):
        data = {}
        for i, field in mapping.items():
            if i < len(row) and row[i]:
                data[field] = f'{data[field]} {row[i]}'.strip() if field in data else row[i]
        event = _build(data, source, f'riga {number}', default_year)
        if event:
            events.append(event)
    return events


def _loose_row(row: list[str], source: str, default_year) -> dict | None:
    day = next((parse_date(c, default_year) for c in row if parse_date(c, default_year)), None)
    if day is None:
        return None
    text_cells = [c for c in row if not parse_date(c, default_year) and len(c) > 2]
    data = {'date': day.isoformat(), 'subject': max(text_cells, key=len) if text_cells else '',
            'notes': ' · '.join(c for c in text_cells if c != (max(text_cells, key=len) if text_cells else ''))}
    for cell in row:
        if parse_time(cell) and re.search(r'\d[:.]\d{2}|ore', cell):
            data['time'] = cell
            break
    return _build(data, source, 'riga senza intestazione', default_year)


def _build(data: dict, source: str, ref: str, default_year) -> dict | None:
    day = parse_date(data.get('date'), default_year)
    if day is None:
        return None
    warnings = []
    start_time = parse_time(data['time']) if data.get('time') else None
    end_day = parse_date(data.get('end_date'), default_year) if data.get('end_date') else None
    end_time = parse_time(data['end_time']) if data.get('end_time') else None
    # Un intervallo "9:30-11:30" nella stessa cella.
    if data.get('time') and end_time is None:
        m = re.search(r'(\d{1,2}[:.]\d{2})\s*[-–]\s*(\d{1,2}[:.]\d{2})', data['time'])
        if m:
            end_time = parse_time(m.group(2))
    subject = (data.get('subject') or '').strip()
    kind = guess_kind(data.get('kind'), subject, data.get('notes'))
    if kind == 'exam' and not subject:
        warnings.append('Materia mancante')
    starts_at = datetime.combine(day, start_time or time(0, 0))
    ends_at = None
    if end_day and end_day >= day:
        ends_at = datetime.combine(end_day, end_time or time(23, 59))
    elif end_time:
        ends_at = datetime.combine(day, end_time)
    title = subject or (data.get('kind') or {'session': 'Sessione', 'lessons': 'Lezioni', 'closure': 'Chiusura',
                                             'extraordinary': 'Sessione straordinaria', 'event': 'Evento'}.get(kind, 'Appello'))
    deadline = parse_date(data.get('booking_deadline'), default_year) if data.get('booking_deadline') else None
    url_match = re.search(r'https?://\S+', ' '.join(str(v) for v in data.values()))
    teachers = [t.strip() for t in re.split(r'[;,/]| e ', data.get('teachers') or '') if t.strip()]
    return {
        'title': title[:200], 'subject_name': subject[:200] or None, 'kind': kind,
        'exam_format': guess_format(data.get('format'), data.get('kind'), subject, data.get('notes')) if kind in ('exam', 'extraordinary') else None,
        'starts_at': starts_at.isoformat(), 'ends_at': ends_at.isoformat() if ends_at else None,
        'all_day': start_time is None, 'room': (data.get('room') or '')[:200] or None,
        'teachers': teachers[:10], 'notes': (data.get('notes') or '')[:2000] or None,
        'booking_url': url_match.group(0)[:500] if url_match else None,
        'booking_deadline': deadline.isoformat() if deadline else None,
        'source': source, 'source_ref': ref, 'warnings': warnings,
    }


# ---------------------------------------------------------------------------
# Formati
# ---------------------------------------------------------------------------

def parse_csv(content: bytes, default_year=None) -> list[dict]:
    text = content.decode('utf-8-sig', errors='replace')
    try:
        dialect = csv.Sniffer().sniff(text[:4000], delimiters=';,\t|')
    except csv.Error:
        dialect = csv.excel
    return rows_to_events(list(csv.reader(io.StringIO(text), dialect)), 'csv', default_year)


def parse_pdf(content: bytes, default_year=None) -> list[dict]:
    events = []
    try:
        import pdfplumber
        with pdfplumber.open(io.BytesIO(content)) as pdf:
            header = None
            for page in pdf.pages[:60]:
                for table in page.extract_tables() or []:
                    # Tabelle spezzate su più pagine: riusa l'intestazione precedente.
                    if header and table and not any(_field_for(c) for c in table[0]):
                        table = [header] + table
                    elif table:
                        header = table[0]
                    events.extend(rows_to_events(table, 'pdf', default_year))
            if events:
                return events
            # Tabelle senza linee: colonne ricavate dall'allineamento del testo.
            for page in pdf.pages[:60]:
                for table in page.extract_tables({'vertical_strategy': 'text', 'horizontal_strategy': 'text'}) or []:
                    events.extend(rows_to_events(table, 'pdf', default_year))
            if events:
                return events
            lines = '\n'.join((p.extract_text() or '') for p in pdf.pages[:60]).splitlines()
    except ImportError:
        from pypdf import PdfReader
        reader = PdfReader(io.BytesIO(content))
        lines = '\n'.join((p.extract_text() or '') for p in reader.pages[:60]).splitlines()
    rows = [re.split(r'\s{2,}|\t|\s\|\s', line.strip()) for line in lines if line.strip()]
    return rows_to_events(rows, 'pdf', default_year)


class _TableParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.tables, self._rows, self._row, self._cell, self._in_cell = [], None, None, [], False

    def handle_starttag(self, tag, attrs):
        if tag == 'table':
            self._rows = []
        elif tag == 'tr' and self._rows is not None:
            self._row = []
        elif tag in ('td', 'th') and self._row is not None:
            self._in_cell, self._cell = True, []
        elif tag == 'a' and self._in_cell:
            href = dict(attrs).get('href') or ''
            if href.startswith('http'):
                self._cell.append(f' {href} ')

    def handle_endtag(self, tag):
        if tag in ('td', 'th') and self._row is not None:
            self._row.append(' '.join(''.join(self._cell).split()))
            self._in_cell = False
        elif tag == 'tr' and self._rows is not None and self._row is not None:
            self._rows.append(self._row)
            self._row = None
        elif tag == 'table' and self._rows is not None:
            self.tables.append(self._rows)
            self._rows = None

    def handle_data(self, data):
        if self._in_cell:
            self._cell.append(data)


def parse_html(text: str, default_year=None) -> list[dict]:
    parser = _TableParser()
    parser.feed(text)
    events = []
    for table in parser.tables:
        events.extend(rows_to_events(table, 'web', default_year))
    return events


def _unfold(text: str) -> list[str]:
    lines = []
    for raw in text.replace('\r\n', '\n').split('\n'):
        if raw.startswith((' ', '\t')) and lines:
            lines[-1] += raw[1:]
        else:
            lines.append(raw)
    return lines


def _ics_value(value: str) -> str:
    return value.replace('\\n', '\n').replace('\\,', ',').replace('\\;', ';').replace('\\\\', '\\')


def _ics_datetime(value: str) -> tuple[datetime | None, bool]:
    value = value.strip()
    try:
        if len(value) == 8:
            return datetime.strptime(value, '%Y%m%d'), True
        return datetime.strptime(value.rstrip('Z')[:15], '%Y%m%dT%H%M%S'), False
    except ValueError:
        return None, False


def parse_ics(content: bytes) -> list[dict]:
    text = content.decode('utf-8', errors='replace')
    events, current = [], None
    for line in _unfold(text):
        if line == 'BEGIN:VEVENT':
            current = {}
        elif line == 'END:VEVENT' and current is not None:
            start, all_day = _ics_datetime(current.get('DTSTART', ''))
            end, _ = _ics_datetime(current.get('DTEND', '')) if current.get('DTEND') else (None, False)
            if start is not None:
                summary = _ics_value(current.get('SUMMARY', 'Evento'))
                description = _ics_value(current.get('DESCRIPTION', ''))
                kind = guess_kind(summary, description, current.get('CATEGORIES', ''))
                if all_day and end is not None:
                    end = end - timedelta(days=1)   # in iCal la fine di un evento a giornata intera è esclusa
                url = re.search(r'https?://\S+', description or current.get('URL', ''))
                events.append({
                    'title': summary[:200], 'subject_name': summary[:200] if kind in ('exam', 'extraordinary') else None,
                    'kind': kind, 'exam_format': guess_format(summary, description),
                    'starts_at': start.isoformat(), 'ends_at': end.isoformat() if end else None, 'all_day': all_day,
                    'room': _ics_value(current.get('LOCATION', ''))[:200] or None, 'teachers': [],
                    'notes': description[:2000] or None, 'booking_url': url.group(0)[:500] if url else None,
                    'booking_deadline': None, 'source': 'ics', 'source_ref': current.get('UID'), 'warnings': [],
                })
            current = None
        elif current is not None and ':' in line:
            key, value = line.split(':', 1)
            current[key.split(';', 1)[0].upper()] = value
    return events


def parse_json(content: bytes) -> list[dict]:
    data = json.loads(content.decode('utf-8'))
    items = data.get('events') if isinstance(data, dict) else data
    rows = []
    for item in items or []:
        if not isinstance(item, dict):
            continue
        event = _build({
            'date': item.get('date') or item.get('starts_at', '')[:10], 'time': item.get('time') or (item.get('starts_at', '')[11:16]),
            'end_date': item.get('end_date') or (item.get('ends_at') or '')[:10] or None,
            'end_time': item.get('end_time') or (item.get('ends_at') or '')[11:16] or None,
            'subject': item.get('subject') or item.get('title'), 'kind': item.get('kind') or item.get('type'),
            'format': item.get('format') or item.get('exam_format'), 'room': item.get('room'),
            'teachers': ', '.join(item.get('teachers') or []) if isinstance(item.get('teachers'), list) else item.get('teachers'),
            'notes': item.get('notes'), 'booking_url': item.get('booking_url'), 'booking_deadline': item.get('booking_deadline'),
        }, 'json', str(item.get('id') or ''), None)
        if event:
            if item.get('kind') in ('lessons', 'session', 'exam', 'extraordinary', 'closure', 'event'):
                event['kind'] = item['kind']
            rows.append(event)
    return rows


def parse_upload(filename: str, content: bytes, default_year=None) -> list[dict]:
    name = (filename or '').lower()
    if name.endswith('.pdf') or content[:4] == b'%PDF':
        return parse_pdf(content, default_year)
    if name.endswith(('.ics', '.ical')) or b'BEGIN:VCALENDAR' in content[:200]:
        return parse_ics(content)
    if name.endswith('.json'):
        return parse_json(content)
    if name.endswith(('.htm', '.html')):
        return parse_html(content.decode('utf-8', errors='replace'), default_year)
    return parse_csv(content, default_year)
