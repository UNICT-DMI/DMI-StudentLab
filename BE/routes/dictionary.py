"""Dizionario delle materie.

Lettura: tutti, anche gli ospiti. Scrittura (JSON o editor nell'app): admin e
docenti verificati della materia. Revisione tra anni accademici: admin.
"""
import json

from fastapi import APIRouter, Body, Depends, HTTPException, Query
from fastapi.responses import Response
from pydantic import BaseModel, Field
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_admin_user, get_current_user, get_optional_current_user
from models.dictionary import DictionaryEntry, DictionaryTopic, DictionaryVersion, utc_now
from models.subject import Subject
from models.teacher_assignment import TeacherAssignment
from models.user import User
from services.dictionary import (SCHEMA, apply_content, can_edit, clean_content, current_academic_year, display_name,
                                 import_dictionary, is_admin, match_subject, normalize_year, previous_version,
                                 quiz_questions, slugify, subject_teachers, topic_pdf, upsert_version,
                                 PUBLIC_REVIEW_STATES, public_version_for_year, public_content,
                                 teacher_subject_ids, version_content, version_for_year)
from services.dictionary_moderation import ModerationError, draft_from_editor, register_source, teachers_for

router = APIRouter(prefix='/dictionary', tags=['dictionary'])


def _years(db: Session, subject_id: int) -> list[str]:
    rows = (db.query(DictionaryVersion.academic_year)
        .join(DictionaryEntry, DictionaryEntry.id == DictionaryVersion.entry_id)
        .filter(DictionaryEntry.subject_id == subject_id,
                DictionaryVersion.review_state.in_(PUBLIC_REVIEW_STATES))
        .distinct().all())
    return sorted({row[0] for row in rows}, reverse=True)


def _year_or_default(db: Session, subject_id: int, year: str | None) -> str:
    wanted = normalize_year(year)
    if wanted:
        return wanted
    years = _years(db, subject_id)
    current = current_academic_year()
    return current if not years or current >= years[0] else years[0]


def _teachers_for_year(db: Session, subject_id: int, year: str) -> list[str]:
    names: list[str] = []
    rows = db.query(DictionaryVersion.teachers_json).join(DictionaryEntry,
        DictionaryEntry.id == DictionaryVersion.entry_id).filter(DictionaryEntry.subject_id == subject_id,
        DictionaryVersion.academic_year == year,
        DictionaryVersion.review_state.in_(PUBLIC_REVIEW_STATES)).distinct().limit(50).all()
    for (value,) in rows:
        for name in json.loads(value or '[]'):
            if name not in names:
                names.append(name)
    if not names and year == current_academic_year():
        names = [t['name'] for t in subject_teachers(db, subject_id)]
    return names


def _subject_or_404(db: Session, subject_id: int) -> Subject:
    subject = db.query(Subject).filter(Subject.id == subject_id).first()
    if subject is None:
        raise HTTPException(404, 'Materia non trovata.')
    return subject


# ---------------------------------------------------------------------------
# Lettura (anche ospiti)
# ---------------------------------------------------------------------------

@router.get('/subjects')
def dictionary_subjects(db: Session = Depends(get_db)):
    """List only subjects that have a reviewed dictionary version."""
    counts = dict(db.query(DictionaryEntry.subject_id, func.count(func.distinct(DictionaryEntry.id)))
        .join(DictionaryVersion, DictionaryVersion.entry_id == DictionaryEntry.id)
        .filter(DictionaryVersion.review_state.in_(PUBLIC_REVIEW_STATES))
        .group_by(DictionaryEntry.subject_id).all())
    if not counts:
        return []
    topics = dict(db.query(DictionaryEntry.subject_id, func.count(func.distinct(DictionaryEntry.topic_id)))
        .join(DictionaryVersion, DictionaryVersion.entry_id == DictionaryEntry.id)
        .filter(DictionaryVersion.review_state.in_(PUBLIC_REVIEW_STATES))
        .group_by(DictionaryEntry.subject_id).all())
    subjects = db.query(Subject).filter(Subject.id.in_(list(counts))).order_by(Subject.name).all()
    return [{'id': s.id, 'name': s.name, 'university': s.university, 'university_code': s.university_code,
             'department': s.department, 'department_code': s.department_code, 'course': s.course,
             'course_code': s.course_code, 'terms': counts.get(s.id, 0), 'topics': topics.get(s.id, 0)}
            for s in subjects]


@router.get('/subjects/{subject_id}')
def dictionary_subject(subject_id: int, year: str | None = None,
                       viewer: User | None = Depends(get_optional_current_user), db: Session = Depends(get_db)):
    subject = _subject_or_404(db, subject_id)
    selected = _year_or_default(db, subject_id, year)
    topics = db.query(DictionaryTopic).filter(DictionaryTopic.subject_id == subject_id).order_by(
        DictionaryTopic.sort_order, DictionaryTopic.title).all()
    entries = db.query(DictionaryEntry).filter(DictionaryEntry.subject_id == subject_id).order_by(
        func.lower(DictionaryEntry.term)).all()
    by_topic: dict[int | None, list[dict]] = {}
    for entry in entries:
        version = public_version_for_year(db, entry.id, selected)
        if version is None:
            continue   # termine introdotto dopo l'anno scelto
        content = version_content(version)
        by_topic.setdefault(entry.topic_id, []).append({
            'id': entry.id, 'term': entry.term, 'informal': (content['informal_definition'] or content['formal_definition'] or '')[:220],
            'has_exam': bool(content['exam_questions']), 'from_year': version.academic_year,
        })
    result_topics = [{'id': t.id, 'title': t.title, 'entries': by_topic.get(t.id, [])} for t in topics]
    if by_topic.get(None):
        result_topics.append({'id': None, 'title': 'Altri termini', 'entries': by_topic[None]})
    return {
        'subject': {'id': subject.id, 'name': subject.name, 'course': subject.course,
                    'department': subject.department, 'university': subject.university},
        'year': selected, 'years': sorted(set(_years(db, subject_id)) | {selected}, reverse=True),
        'teachers': _teachers_for_year(db, subject_id, selected),
        'topics': [t for t in result_topics if t['entries']],
        'can_edit': can_edit(db, viewer, subject_id), 'is_admin': is_admin(viewer),
    }


@router.get('/search')
def dictionary_search(q: str = Query(min_length=2, max_length=100), subject_id: int | None = None,
                      limit: int = Query(default=30, ge=1, le=100), db: Session = Depends(get_db)):
    like = f'%{q.strip().lower()}%'
    query = db.query(DictionaryEntry, Subject).join(Subject, Subject.id == DictionaryEntry.subject_id).filter(
        or_(func.lower(DictionaryEntry.term).like(like), func.lower(DictionaryEntry.aliases_json).like(like)),
        db.query(DictionaryVersion.id).filter(DictionaryVersion.entry_id == DictionaryEntry.id,
            DictionaryVersion.review_state.in_(PUBLIC_REVIEW_STATES)).exists())
    if subject_id:
        query = query.filter(DictionaryEntry.subject_id == subject_id)
    rows = query.order_by(func.length(DictionaryEntry.term)).limit(limit).all()
    return [{'id': e.id, 'term': e.term, 'subject_id': s.id, 'subject_name': s.name, 'course': s.course}
            for e, s in rows]


@router.get('/entries/{entry_id}')
def dictionary_entry(entry_id: int, year: str | None = None,
                     viewer: User | None = Depends(get_optional_current_user), db: Session = Depends(get_db)):
    entry = db.query(DictionaryEntry).filter(DictionaryEntry.id == entry_id).first()
    if entry is None:
        raise HTTPException(404, 'Termine non trovato.')
    subject = _subject_or_404(db, entry.subject_id)
    selected = _year_or_default(db, entry.subject_id, year)
    editor = can_edit(db, viewer, entry.subject_id)
    version = (version_for_year(db, entry.id, selected) if editor
               else public_version_for_year(db, entry.id, selected))
    if version is None:
        raise HTTPException(404, 'Termine senza contenuto.')
    content = version_content(version) if editor else public_content(version_content(version))
    related = []
    if content['related']:
        for item in db.query(DictionaryEntry).filter(DictionaryEntry.subject_id == entry.subject_id,
                                                     DictionaryEntry.slug.in_(content['related']),
                                                     db.query(DictionaryVersion.id).filter(
                                                         DictionaryVersion.entry_id == DictionaryEntry.id,
                                                         DictionaryVersion.review_state.in_(PUBLIC_REVIEW_STATES)).exists()).all():
            related.append({'id': item.id, 'term': item.term})
    topic = db.query(DictionaryTopic).filter(DictionaryTopic.id == entry.topic_id).first() if entry.topic_id else None
    all_versions_query = db.query(DictionaryVersion).filter(DictionaryVersion.entry_id == entry.id)
    if not editor:
        all_versions_query = all_versions_query.filter(DictionaryVersion.review_state.in_(PUBLIC_REVIEW_STATES))
    all_versions = all_versions_query.order_by(DictionaryVersion.academic_year.desc()).all()
    return {
        'entry': {'id': entry.id, 'term': entry.term, 'aliases': json.loads(entry.aliases_json or '[]'),
                  'topic': topic.title if topic else None, 'topic_id': entry.topic_id,
                  'subject_id': subject.id, 'subject_name': subject.name, 'course': subject.course},
        'year': selected,
        'version': {**content, 'id': version.id, 'academic_year': version.academic_year,
                    'teachers': json.loads(version.teachers_json or '[]'), 'author_name': version.author_name,
                    'author_role': version.author_role, 'assigned_teacher_name': version.assigned_teacher_name,
                    'review_state': version.review_state, 'updated_at': version.updated_at,
                    'quiz_count': len(content['quiz_question_ids'])},
        'years': [{'year': v.academic_year, 'author_name': v.author_name, 'review_state': v.review_state}
                  for v in all_versions],
        'related': related,
        'can_edit': editor,
    }


@router.get('/entries/{entry_id}/quiz')
def dictionary_entry_quiz(entry_id: int, year: str | None = None, db: Session = Depends(get_db)):
    entry = db.query(DictionaryEntry).filter(DictionaryEntry.id == entry_id).first()
    if entry is None:
        raise HTTPException(404, 'Termine non trovato.')
    version = public_version_for_year(db, entry.id, _year_or_default(db, entry.subject_id, year))
    if version is None:
        raise HTTPException(404, 'Termine non disponibile.')
    return quiz_questions(version)


@router.get('/topics/{topic_id}/pdf')
def dictionary_topic_pdf(topic_id: int, year: str | None = None, db: Session = Depends(get_db)):
    """PDF dell'argomento per l'anno scelto (anche per gli ospiti)."""
    topic = db.query(DictionaryTopic).filter(DictionaryTopic.id == topic_id).first()
    if topic is None:
        raise HTTPException(404, 'Argomento non trovato.')
    subject = _subject_or_404(db, topic.subject_id)
    selected = _year_or_default(db, subject.id, year)
    rows = []
    for entry in db.query(DictionaryEntry).filter(DictionaryEntry.topic_id == topic.id).order_by(
            func.lower(DictionaryEntry.term)).all():
        version = public_version_for_year(db, entry.id, selected)
        if version is not None:
            rows.append((entry, version))
    if not rows:
        raise HTTPException(404, 'Nessun termine per questo anno.')
    content = topic_pdf(subject, topic, selected, rows, _teachers_for_year(db, subject.id, selected))
    name = f'Dizionario - {subject.name} - {topic.title} - {selected.replace("/", "-")}.pdf'
    safe = ''.join(ch for ch in name if ch.isalnum() or ch in ' -_.').strip()
    return Response(content=content, media_type='application/pdf',
                    headers={'Content-Disposition': f'attachment; filename="{safe}"', 'Cache-Control': 'no-store'})


# ---------------------------------------------------------------------------
# Scrittura: admin e docenti della materia
# ---------------------------------------------------------------------------

class ImportRequest(BaseModel):
    dictionary: dict
    subject_id: int | None = None
    academic_year: str | None = None
    preview: bool = False
    # Fonte da registrare (nome del file, impronta, metadati, estratto del testo).
    source: dict | None = None


class EntryWrite(BaseModel):
    term: str = Field(min_length=1, max_length=200)
    aliases: list[str] = Field(default_factory=list, max_length=10)
    topic_id: int | None = None
    new_topic_title: str | None = Field(default=None, max_length=200)
    academic_year: str
    formal_definition: str | None = Field(default=None, max_length=8000)
    informal_definition: str | None = Field(default=None, max_length=8000)
    examples: list[dict] = Field(default_factory=list)
    exercises: list[dict] = Field(default_factory=list)
    exam_questions: list[dict] = Field(default_factory=list)
    related: list[str] = Field(default_factory=list)
    resources: list[dict] = Field(default_factory=list)
    teachers: list[str] | None = None
    # True: pubblica subito (solo admin o docente verificato della materia).
    # False: salva una bozza da moderare, il testo pubblicato resta visibile.
    publish: bool = False


@router.get('/editable-subjects')
def editable_subjects(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    query = db.query(Subject).filter(Subject.is_active.is_(True))
    if not is_admin(current_user):
        # Docente con profilo verificato e assegnazione corrente e verificata.
        query = query.filter(Subject.id.in_(teacher_subject_ids(db, current_user) or {-1}))
    return [{'id': s.id, 'name': s.name, 'course': s.course, 'department': s.department,
             'university': s.university} for s in query.order_by(Subject.name).all()]


@router.post('/import')
def dictionary_import(request: ImportRequest, current_user: User = Depends(get_current_user),
                      db: Session = Depends(get_db)):
    data = request.dictionary
    if data.get('schema') not in (SCHEMA, None) or not isinstance(data.get('entries'), list):
        raise HTTPException(400, f'Il file non è un dizionario StudentLab ({SCHEMA}).')
    metadata = data.get('metadata') or {}
    candidates = []
    if request.subject_id is not None:
        subject = _subject_or_404(db, request.subject_id)
    else:
        subject, candidates = match_subject(db, metadata)
    if not request.preview and subject is not None and not can_edit(db, current_user, subject.id):
        raise HTTPException(403, 'Puoi importare solo nelle materie che insegni.')
    entries = [e for e in data['entries'] if isinstance(e, dict)]
    summary = {
        'metadata': {k: metadata.get(k) for k in ('university', 'department', 'course', 'subject', 'academic_year', 'teachers')},
        'academic_year': normalize_year(request.academic_year) or normalize_year(metadata.get('academic_year')) or current_academic_year(),
        'entries': len(entries), 'topics': len(data.get('topics') or []),
        'with_examples': sum(1 for e in entries if e.get('examples')),
        'with_exercises': sum(1 for e in entries if e.get('exercises')),
        'with_exam_questions': sum(1 for e in entries if e.get('exam_questions')),
        'subject': {'id': subject.id, 'name': subject.name, 'course': subject.course} if subject else None,
        'candidates': [{'id': s.id, 'name': s.name, 'course': s.course, 'department': s.department}
                       for s in candidates],
    }
    if request.preview or subject is None:
        return {'preview': True, **summary}
    source = None
    if request.source:
        try:
            payload = {'kind': 'json', 'label': metadata.get('source') or 'JSON caricato dall’app',
                       'academic_year': summary['academic_year'], 'status': 'read', **request.source}
            source = register_source(db, current_user, payload, subject)
        except ModerationError as exc:
            raise HTTPException(exc.status, exc.message)
    report = import_dictionary(db, data, current_user, subject, request.academic_year, source)
    return {'preview': False, **summary, 'report': report}


def _topic_for(db: Session, subject_id: int, data: EntryWrite) -> int | None:
    if data.new_topic_title and data.new_topic_title.strip():
        slug = slugify(data.new_topic_title)
        topic = db.query(DictionaryTopic).filter(DictionaryTopic.subject_id == subject_id,
                                                 DictionaryTopic.slug == slug).first()
        if topic is None:
            count = db.query(DictionaryTopic).filter(DictionaryTopic.subject_id == subject_id).count()
            topic = DictionaryTopic(subject_id=subject_id, slug=slug, title=data.new_topic_title.strip(),
                                    sort_order=count + 1)
            db.add(topic)
            db.flush()
        return topic.id
    if data.topic_id is not None:
        if not db.query(DictionaryTopic.id).filter(DictionaryTopic.id == data.topic_id,
                                                   DictionaryTopic.subject_id == subject_id).first():
            raise HTTPException(400, 'Argomento non valido.')
    return data.topic_id


def _write(db: Session, entry: DictionaryEntry, data: EntryWrite, user: User) -> dict:
    year = normalize_year(data.academic_year)
    if year is None:
        raise HTTPException(400, 'Anno accademico non valido (es. 2025/2026).')
    content = clean_content(data.model_dump())
    if not content['formal_definition'] and not content['informal_definition']:
        raise HTTPException(400, 'Scrivi almeno una definizione.')
    entry.term = data.term.strip()
    entry.aliases_json = json.dumps([a.strip() for a in data.aliases if a.strip()][:10], ensure_ascii=False)
    entry.topic_id = _topic_for(db, entry.subject_id, data)
    db.flush()
    teachers = data.teachers
    if teachers is None:
        existing = db.query(DictionaryVersion).filter(DictionaryVersion.entry_id == entry.id,
                                                      DictionaryVersion.academic_year == year).first()
        teachers = json.loads(existing.teachers_json) if existing else [t['name'] for t in subject_teachers(db, entry.subject_id)]
    version, _ = upsert_version(db, entry, year, content, user, 'admin' if is_admin(user) else 'teacher', teachers)
    # Pubblicazione diretta: chi scrive è già un moderatore della materia.
    version.review_state = 'confirmed'
    version.reviewed_by, version.reviewed_at = user.id, utc_now()
    db.commit()
    return {'entry_id': entry.id, 'version_id': version.id, 'academic_year': year, 'review_state': version.review_state,
            'published': True}


def _save_draft(db: Session, subject_id: int, entry: DictionaryEntry | None, data: EntryWrite, user: User) -> dict:
    year = normalize_year(data.academic_year)
    if year is None:
        raise HTTPException(400, 'Anno accademico non valido (es. 2025/2026).')
    content = clean_content(data.model_dump())
    if not content['formal_definition'] and not content['informal_definition']:
        raise HTTPException(400, 'Scrivi almeno una definizione.')
    aliases = [a.strip() for a in data.aliases if a.strip()][:10]
    if data.topic_id is not None and not db.query(DictionaryTopic.id).filter(
            DictionaryTopic.id == data.topic_id, DictionaryTopic.subject_id == subject_id).first():
        raise HTTPException(400, 'Argomento non valido.')
    draft = draft_from_editor(db, user, subject_id, entry, data.term, aliases, data.topic_id,
                              (data.new_topic_title or '').strip() or None, year, content, data.teachers)
    return {'draft_id': draft.id, 'entry_id': entry.id if entry else None, 'academic_year': year,
            'status': 'pending', 'published': False}


@router.post('/subjects/{subject_id}/entries')
def create_entry(subject_id: int, data: EntryWrite, current_user: User = Depends(get_current_user),
                 db: Session = Depends(get_db)):
    _subject_or_404(db, subject_id)
    if not can_edit(db, current_user, subject_id):
        raise HTTPException(403, 'Puoi scrivere solo nelle materie che insegni.')
    slug = slugify(data.term)
    if db.query(DictionaryEntry.id).filter(DictionaryEntry.subject_id == subject_id, DictionaryEntry.slug == slug).first():
        raise HTTPException(409, 'Questo termine esiste già: aprilo e modificalo.')
    if not data.publish:
        return _save_draft(db, subject_id, None, data, current_user)
    entry = DictionaryEntry(subject_id=subject_id, slug=slug, term=data.term.strip())
    db.add(entry)
    db.flush()
    return _write(db, entry, data, current_user)


@router.put('/entries/{entry_id}')
def update_entry(entry_id: int, data: EntryWrite, current_user: User = Depends(get_current_user),
                 db: Session = Depends(get_db)):
    entry = db.query(DictionaryEntry).filter(DictionaryEntry.id == entry_id).with_for_update().first()
    if entry is None:
        raise HTTPException(404, 'Termine non trovato.')
    if not can_edit(db, current_user, entry.subject_id):
        raise HTTPException(403, 'Puoi modificare solo le materie che insegni.')
    if not data.publish:
        return _save_draft(db, entry.subject_id, entry, data, current_user)
    return _write(db, entry, data, current_user)


@router.delete('/entries/{entry_id}')
def delete_entry(entry_id: int, current_user: User = Depends(get_admin_user), db: Session = Depends(get_db)):
    entry = db.query(DictionaryEntry).filter(DictionaryEntry.id == entry_id).first()
    if entry is None:
        raise HTTPException(404, 'Termine non trovato.')
    db.delete(entry)
    db.commit()
    return {'deleted': entry_id}


@router.get('/subjects/{subject_id}/teachers')
def dictionary_subject_teachers(subject_id: int, current_user: User = Depends(get_current_user),
                                db: Session = Depends(get_db)):
    if not can_edit(db, current_user, subject_id):
        raise HTTPException(403, 'Puoi vedere i docenti solo delle materie che moderi.')
    return teachers_for(db, current_user, subject_id)


# ---------------------------------------------------------------------------
# Revisione tra anni accademici (admin)
# ---------------------------------------------------------------------------

class ReviewRequest(BaseModel):
    action: str = Field(pattern='^(same_as_previous|changed|confirm|assign_teacher|copy_previous)$')
    teacher_user_id: int | None = None


class RolloverRequest(BaseModel):
    from_year: str
    to_year: str


@router.get('/review')
def review_queue(subject_id: int | None = None, state: str = Query(default='to_review',
                 pattern='^(to_review|same_as_previous|changed|confirmed|all)$'), year: str | None = None,
                 current_user: User = Depends(get_admin_user), db: Session = Depends(get_db)):
    query = db.query(DictionaryVersion, DictionaryEntry).join(DictionaryEntry,
        DictionaryEntry.id == DictionaryVersion.entry_id)
    if subject_id:
        query = query.filter(DictionaryEntry.subject_id == subject_id)
    if state != 'all':
        query = query.filter(DictionaryVersion.review_state == state)
    if normalize_year(year):
        query = query.filter(DictionaryVersion.academic_year == normalize_year(year))
    rows = query.order_by(DictionaryVersion.updated_at.desc()).limit(2000).all()
    result = []
    for version, entry in rows:
        previous = previous_version(db, entry.id, version.academic_year)
        subject = db.query(Subject).filter(Subject.id == entry.subject_id).first()
        result.append({
            'version_id': version.id, 'entry_id': entry.id, 'term': entry.term,
            'subject_id': entry.subject_id, 'subject_name': subject.name if subject else None,
            'academic_year': version.academic_year, 'review_state': version.review_state,
            'author_name': version.author_name, 'author_role': version.author_role, 'updated_at': version.updated_at,
            'assigned_teacher_name': version.assigned_teacher_name,
            'current': version_content(version),
            'previous': ({'academic_year': previous.academic_year, 'author_name': previous.author_name,
                          **version_content(previous)} if previous else None),
        })
    counts = dict(db.query(DictionaryVersion.review_state, func.count(DictionaryVersion.id)).group_by(
        DictionaryVersion.review_state).all())
    return {'items': result, 'counts': counts}


@router.post('/versions/{version_id}/review')
def review_version(version_id: int, data: ReviewRequest, current_user: User = Depends(get_admin_user),
                   db: Session = Depends(get_db)):
    version = db.query(DictionaryVersion).filter(DictionaryVersion.id == version_id).with_for_update().first()
    if version is None:
        raise HTTPException(404, 'Versione non trovata.')
    if data.action == 'assign_teacher':
        teacher = db.query(User).filter(User.id == data.teacher_user_id).first() if data.teacher_user_id else None
        if teacher is None:
            raise HTTPException(400, 'Scegli un docente.')
        version.assigned_teacher_user_id = teacher.id
        version.assigned_teacher_name = display_name(teacher)
    elif data.action == 'copy_previous':
        previous = previous_version(db, version.entry_id, version.academic_year)
        if previous is None:
            raise HTTPException(400, "Non c'è un anno precedente da cui copiare.")
        apply_content(version, version_content(previous))
        version.review_state = 'same_as_previous'
    else:
        version.review_state = {'same_as_previous': 'same_as_previous', 'changed': 'changed',
                                'confirm': 'confirmed'}[data.action]
    version.reviewed_by, version.reviewed_at = current_user.id, utc_now()
    db.commit()
    return {'version_id': version.id, 'review_state': version.review_state,
            'assigned_teacher_name': version.assigned_teacher_name}


@router.post('/subjects/{subject_id}/rollover')
def rollover(subject_id: int, data: RolloverRequest, current_user: User = Depends(get_admin_user),
             db: Session = Depends(get_db)):
    """Nuovo anno: copia i termini dall'anno scelto a quello nuovo, da rivedere."""
    source, target = normalize_year(data.from_year), normalize_year(data.to_year)
    if not source or not target or target <= source:
        raise HTTPException(400, "L'anno di destinazione deve essere successivo a quello di partenza.")
    copied = 0
    for entry in db.query(DictionaryEntry).filter(DictionaryEntry.subject_id == subject_id).all():
        origin = db.query(DictionaryVersion).filter(DictionaryVersion.entry_id == entry.id,
                                                    DictionaryVersion.academic_year == source).first()
        exists = db.query(DictionaryVersion.id).filter(DictionaryVersion.entry_id == entry.id,
                                                       DictionaryVersion.academic_year == target).first()
        if origin is None or exists:
            continue
        copy = DictionaryVersion(entry_id=entry.id, academic_year=target, quiz_source=origin.quiz_source,
            teachers_json=json.dumps([t['name'] for t in subject_teachers(db, subject_id)] or json.loads(origin.teachers_json or '[]'),
                                     ensure_ascii=False),
            author_user_id=origin.author_user_id, author_name=origin.author_name, author_role=origin.author_role,
            assigned_teacher_user_id=origin.assigned_teacher_user_id, assigned_teacher_name=origin.assigned_teacher_name,
            review_state='to_review')
        apply_content(copy, version_content(origin))
        db.add(copy)
        copied += 1
    db.commit()
    return {'copied': copied, 'to_year': target}
