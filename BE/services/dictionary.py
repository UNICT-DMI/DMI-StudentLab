"""Dizionario delle materie: regole comuni (permessi, abbinamento materia,
importazione JSON, scelta della versione per anno, PDF)."""
import json
import re
import unicodedata
from datetime import datetime, timezone
from pathlib import Path

from sqlalchemy.orm import Session

from core.security import ADMIN_ROLES
from models.dictionary import DictionaryEntry, DictionaryTopic, DictionaryVersion
from models.subject import Subject
from models.teacher_assignment import TeacherAssignment
from models.user import User

SCHEMA = 'studentlab.dictionary/1'
DATA_ROOT = Path(__file__).resolve().parent.parent / 'data'
CONTENT_FIELDS = ('formal_definition', 'informal_definition', 'examples', 'exercises', 'exam_questions',
                  'related', 'resources', 'quiz_question_ids')
STOPWORDS = {'e', 'ed', 'di', 'del', 'dello', 'della', 'dei', 'degli', 'delle', 'la', 'il', 'lo', 'le', 'gli', 'i',
             'a', 'al', 'allo', 'alla', 'ai', 'agli', 'alle', 'in', 'con', 'per', 'da', 'dal', 'dalla', 'su', 'and'}


def utc_now():
    return datetime.now(timezone.utc)


def current_academic_year() -> str:
    now = utc_now()
    start = now.year if now.month >= 9 else now.year - 1
    return f'{start}/{start + 1}'


def normalize_year(value: str | None) -> str | None:
    """'2025/26', '2025-2026', '2025/2026' -> '2025/2026'."""
    if not value:
        return None
    match = re.search(r'(20\d{2})\s*[/-]\s*(\d{2,4})', str(value))
    if not match:
        return None
    start = int(match.group(1))
    return f'{start}/{start + 1}'


def slugify(text: str) -> str:
    value = unicodedata.normalize('NFKD', text or '').encode('ascii', 'ignore').decode().lower()
    return re.sub(r'[^a-z0-9]+', '-', value).strip('-')[:110] or 'termine'


def tokens(text: str | None) -> set[str]:
    value = unicodedata.normalize('NFKD', text or '').encode('ascii', 'ignore').decode().lower()
    return {w for w in re.split(r'[^a-z0-9]+', value) if w and w not in STOPWORDS}


def display_name(user: User | None) -> str:
    if user is None:
        return 'StudentLab'
    return f'{user.first_name or ""} {user.last_name or ""}'.strip() or 'StudentLab'


def is_admin(user: User | None) -> bool:
    return user is not None and (user.role or '') in ADMIN_ROLES


def is_verified_teacher(user: User | None) -> bool:
    """Ruolo docente e profilo docente verificato (come nei quiz)."""
    return (user is not None and str(user.role or '').strip().lower() == 'teacher'
            and str(getattr(user, 'teacher_verification_status', '') or '').strip().lower() == 'verified')


def teacher_subject_ids(db: Session, user: User | None) -> set[int]:
    """Materie con assegnazione corrente e verificata di un docente verificato."""
    if not is_verified_teacher(user):
        return set()
    rows = db.query(TeacherAssignment.subject_id).join(Subject, Subject.id == TeacherAssignment.subject_id).filter(
        TeacherAssignment.user_id == user.id, TeacherAssignment.verification_status == 'verified',
        TeacherAssignment.is_current.is_(True), Subject.is_active.is_(True)).all()
    return {r[0] for r in rows}


def is_teacher_of(db: Session, user: User | None, subject_id: int) -> bool:
    return subject_id in teacher_subject_ids(db, user)


def can_edit(db: Session, user: User | None, subject_id: int) -> bool:
    return is_admin(user) or is_teacher_of(db, user, subject_id)


def subject_teachers(db: Session, subject_id: int) -> list[dict]:
    rows = db.query(TeacherAssignment.user_id).filter(TeacherAssignment.subject_id == subject_id,
        TeacherAssignment.verification_status == 'verified').distinct().all()
    result = []
    for (user_id,) in rows:
        user = db.query(User).filter(User.id == user_id).first()
        if user is not None:
            result.append({'id': user.id, 'name': display_name(user)})
    return result


def match_subject(db: Session, metadata: dict) -> tuple[Subject | None, list[Subject]]:
    """Trova la materia del file: codice del corso e del dipartimento (se ci sono),
    poi le parole del nome. Restituisce (materia sicura, candidati)."""
    wanted = tokens(metadata.get('subject'))
    if not wanted:
        return None, []
    query = db.query(Subject).filter(Subject.is_active.is_(True))
    course_code = metadata.get('course_code') or ''
    if not course_code:
        match = re.search(r'\b([A-Z]{1,3}M?-\d{1,3})\b', str(metadata.get('course') or ''), re.I)
        course_code = match.group(1) if match else ''
    subjects = query.all()
    if course_code:
        in_course = [s for s in subjects if (s.course_code or '').casefold() == course_code.casefold()]
        subjects = in_course or subjects
    department_code = (metadata.get('department_code') or '').casefold()
    if department_code:
        in_department = [s for s in subjects if (s.department_code or '').casefold() == department_code]
        subjects = in_department or subjects
    scored = []
    for subject in subjects:
        have = tokens(subject.name)
        if not have:
            continue
        overlap = len(wanted & have)
        score = overlap / len(wanted)
        scored.append((score, -len(have - wanted), subject))
    scored.sort(key=lambda item: (item[0], item[1]), reverse=True)
    candidates = [s for score, _, s in scored if score >= 0.5][:5]
    if scored and scored[0][0] >= 0.75 and (len(scored) == 1 or scored[1][0] < scored[0][0] or scored[1][1] < scored[0][1]):
        return scored[0][2], candidates
    return None, candidates


def _list(value) -> list:
    return value if isinstance(value, list) else []


def _clean_items(items, keys: tuple[str, ...]) -> list[dict]:
    result = []
    for item in _list(items)[:50]:
        if isinstance(item, str):
            item = {keys[0]: item}
        if not isinstance(item, dict):
            continue
        clean = {k: str(item[k]).strip()[:4000] for k in keys if item.get(k) not in (None, '')}
        if 'difficulty' in item:
            try:
                clean['difficulty'] = max(1, min(5, int(item['difficulty'])))
            except (TypeError, ValueError):
                pass
        for extra in ('material_id', 'calendar_event_id'):
            if isinstance(item.get(extra), int):
                clean[extra] = item[extra]
        if isinstance(item.get('catalog_path'), list):
            clean['catalog_path'] = [str(p)[:120] for p in item['catalog_path'][:10]]
        if clean:
            result.append(clean)
    return result


def clean_content(data: dict) -> dict:
    return {
        'formal_definition': (data.get('formal_definition') or '').strip()[:8000] or None,
        'informal_definition': (data.get('informal_definition') or '').strip()[:8000] or None,
        'examples': _clean_items(data.get('examples'), ('title', 'body')),
        'exercises': _clean_items(data.get('exercises'), ('text', 'solution', 'difficulty')),
        # kind: past (esame passato) | possible (domanda possibile) | reports (dai racconti)
        'exam_questions': _clean_items(data.get('exam_questions'),
                                       ('text', 'kind', 'source', 'solution', 'exam_date', 'format', 'teacher')),
        'related': [slugify(str(r)) for r in _list(data.get('related'))[:30] if str(r).strip()],
        'resources': _clean_items(data.get('resources'), ('type', 'title', 'url')),
        'quiz_source': (str(data.get('quiz_source') or '').strip()[:500] or None),
        'quiz_question_ids': [q for q in _list(data.get('quiz_question_ids'))[:200] if isinstance(q, (int, str))],
    }


def public_content(content: dict) -> dict:
    """Contenuto per gli studenti: senza i riferimenti interni alle fonti."""
    return {**content, 'resources': [r for r in content.get('resources') or [] if r.get('type') != 'source']}


def version_content(version: DictionaryVersion) -> dict:
    return {
        'formal_definition': version.formal_definition,
        'informal_definition': version.informal_definition,
        'examples': json.loads(version.examples_json or '[]'),
        'exercises': json.loads(version.exercises_json or '[]'),
        'exam_questions': json.loads(version.exam_questions_json or '[]'),
        'related': json.loads(version.related_json or '[]'),
        'resources': json.loads(version.resources_json or '[]'),
        'quiz_question_ids': json.loads(version.quiz_question_ids_json or '[]'),
    }


def apply_content(version: DictionaryVersion, content: dict):
    version.formal_definition = content['formal_definition']
    version.informal_definition = content['informal_definition']
    version.examples_json = json.dumps(content['examples'], ensure_ascii=False)
    version.exercises_json = json.dumps(content['exercises'], ensure_ascii=False)
    version.exam_questions_json = json.dumps(content['exam_questions'], ensure_ascii=False)
    version.related_json = json.dumps(content['related'], ensure_ascii=False)
    version.resources_json = json.dumps(content['resources'], ensure_ascii=False)
    version.quiz_question_ids_json = json.dumps(content['quiz_question_ids'], ensure_ascii=False)


def previous_version(db: Session, entry_id: int, year: str) -> DictionaryVersion | None:
    return db.query(DictionaryVersion).filter(DictionaryVersion.entry_id == entry_id,
        DictionaryVersion.academic_year < year).order_by(DictionaryVersion.academic_year.desc()).first()


def version_for_year(db: Session, entry_id: int, year: str) -> DictionaryVersion | None:
    """La versione dell'anno, o la più recente degli anni precedenti."""
    exact = db.query(DictionaryVersion).filter(DictionaryVersion.entry_id == entry_id,
                                               DictionaryVersion.academic_year == year).first()
    return exact or previous_version(db, entry_id, year)


PUBLIC_REVIEW_STATES = ('confirmed', 'same_as_previous', 'changed')


def public_version_for_year(db: Session, entry_id: int, year: str) -> DictionaryVersion | None:
    """Latest reviewed version no later than the selected academic year."""
    return (db.query(DictionaryVersion).filter(
        DictionaryVersion.entry_id == entry_id,
        DictionaryVersion.academic_year <= year,
        DictionaryVersion.review_state.in_(PUBLIC_REVIEW_STATES),
    ).order_by(DictionaryVersion.academic_year.desc()).first())


def auto_review_state(db: Session, version: DictionaryVersion) -> str:
    """Import and edit always require an administrator review before publication."""
    return 'to_review'


def upsert_version(db: Session, entry: DictionaryEntry, year: str, content: dict, author: User | None,
                   role: str, teachers: list[str] | None = None, quiz_source: str | None = None) -> tuple[DictionaryVersion, bool]:
    version = db.query(DictionaryVersion).filter(DictionaryVersion.entry_id == entry.id,
                                                 DictionaryVersion.academic_year == year).first()
    created = version is None
    if created:
        version = DictionaryVersion(entry_id=entry.id, academic_year=year)
        db.add(version)
    apply_content(version, content)
    if teachers is not None:
        version.teachers_json = json.dumps(teachers, ensure_ascii=False)
    if quiz_source is not None:
        version.quiz_source = quiz_source
    version.author_user_id = author.id if author else None
    version.author_name = display_name(author) if role != 'import' else (display_name(author) + ' (import)')
    version.author_role = role
    version.updated_at = utc_now()
    db.flush()
    version.review_state = auto_review_state(db, version)
    return version, created


def import_dictionary(db: Session, data: dict, user: User, subject: Subject, year_override: str | None,
                      source=None) -> dict:
    """Un dizionario JSON diventa un insieme di BOZZE da moderare: nessun
    termine è visibile agli studenti prima dell'approvazione (admin o docente
    verificato della materia)."""
    from services.dictionary_moderation import drafts_from_dictionary
    return drafts_from_dictionary(db, data, user, subject, year_override, source)


def quiz_questions(version: DictionaryVersion, limit: int = 20) -> list[dict]:
    """Domande del quiz collegate al termine, lette dal file sorgente."""
    ids = json.loads(version.quiz_question_ids_json or '[]')
    if not ids or not version.quiz_source:
        return []
    path = (DATA_ROOT / version.quiz_source).resolve()
    if DATA_ROOT not in path.parents or not path.exists():
        return []
    try:
        items = json.loads(path.read_text(encoding='utf-8'))
    except (OSError, json.JSONDecodeError):
        return []
    wanted = {str(i) for i in ids}
    result = []
    for q in items if isinstance(items, list) else []:
        if str(q.get('id_question') or q.get('id')) in wanted:
            result.append({'id': q.get('id_question') or q.get('id'), 'text': q.get('text'),
                           'options': q.get('option') or [], 'correct': q.get('id_correct'),
                           'explanation': q.get('formal_explanation')})
            if len(result) >= limit:
                break
    return result


# ---------------------------------------------------------------------------
# PDF di un argomento
# ---------------------------------------------------------------------------

_REPLACE = {'′': "'", '≤': '<=', '≥': '>=', '≠': '!=', '→': '->', '←': '<-', '∞': 'inf', '∈': 'in',
            '∪': 'U', '∩': 'n', '⊆': 'sottoinsieme di', '∀': 'per ogni', '∃': 'esiste', '¬': 'non'}


def _text(value: str | None) -> str:
    """Testo sicuro per i font standard del PDF (Windows-1252) e per i tag."""
    raw = ''.join(_REPLACE.get(ch, ch) for ch in (value or ''))
    raw = raw.encode('cp1252', 'replace').decode('cp1252')
    return raw.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('\n', '<br/>')


def topic_pdf(subject: Subject, topic: DictionaryTopic, year: str, rows: list[tuple[DictionaryEntry, DictionaryVersion]],
              teachers: list[str]) -> bytes:
    from io import BytesIO

    from reportlab.lib import colors
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
    from reportlab.lib.units import mm
    from reportlab.platypus import KeepTogether, Paragraph, SimpleDocTemplate, Spacer

    buffer = BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=A4, leftMargin=18 * mm, rightMargin=18 * mm,
                            topMargin=16 * mm, bottomMargin=16 * mm,
                            title=f'{subject.name} - {topic.title}', author='StudentLab')
    base = getSampleStyleSheet()
    small = ParagraphStyle('small', parent=base['Normal'], fontSize=8.5, textColor=colors.HexColor('#555555'))
    body = ParagraphStyle('body', parent=base['Normal'], fontSize=10, leading=14)
    label = ParagraphStyle('label', parent=base['Normal'], fontName='Helvetica-Bold', fontSize=9,
                           textColor=colors.HexColor('#1F4E79'), spaceBefore=4)
    term_style = ParagraphStyle('term', parent=base['Heading2'], fontSize=14, spaceBefore=10, spaceAfter=2)
    title_style = ParagraphStyle('title', parent=base['Title'], fontSize=20, alignment=0, spaceAfter=4)
    story = [
        Paragraph(_text(f'{subject.course or ""} - {subject.name}'), small),
        Paragraph(_text(topic.title), title_style),
        Paragraph(_text(f'Anno accademico {year}' + (f' - Docenti: {", ".join(teachers)}' if teachers else '')), small),
        Spacer(1, 6 * mm),
    ]
    for entry, version in rows:
        content = version_content(version)
        block = [Paragraph(_text(entry.term), term_style)]
        if version.academic_year != year:
            block.append(Paragraph(_text(f"Contenuto dell'A.A. {version.academic_year}"), small))
        if content['formal_definition']:
            block += [Paragraph('Definizione formale', label), Paragraph(_text(content['formal_definition']), body)]
        if content['informal_definition']:
            block += [Paragraph('In parole semplici', label), Paragraph(_text(content['informal_definition']), body)]
        story.append(KeepTogether(block))
        for title, items, key in (('Esempi', content['examples'], 'body'),
                                  ('Esercizi', content['exercises'], 'text'),
                                  ("Domande d'esame possibili", content['exam_questions'], 'text')):
            if not items:
                continue
            story.append(Paragraph(title, label))
            for i, item in enumerate(items, 1):
                head = f"<b>{_text(item['title'])}:</b> " if item.get('title') else ''
                story.append(Paragraph(f'{i}. {head}{_text(item.get(key))}', body))
                if key == 'text' and item.get('solution'):
                    story.append(Paragraph('<i>Soluzione:</i> ' + _text(item['solution']), body))
        if content['resources']:
            story.append(Paragraph('Materiali collegati', label))
            for item in content['resources']:
                text = _text(item.get('title') or item.get('url') or 'Materiale')
                if item.get('url'):
                    text += f' ({_text(item["url"])})'
                story.append(Paragraph('- ' + text, body))
        updated = version.updated_at.strftime('%d/%m/%Y') if version.updated_at else ''
        story.append(Paragraph(_text(f'Scritto da {version.author_name or "StudentLab"} - aggiornato il {updated}'), small))
    story += [Spacer(1, 8 * mm), Paragraph(_text(f'Generato da StudentLab il {utc_now().strftime("%d/%m/%Y")}.'), small)]
    doc.build(story)
    return buffer.getvalue()
