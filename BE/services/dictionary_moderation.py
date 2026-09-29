"""Dizionario: registro delle fonti e moderazione delle bozze.

Flusso: le fonti (PDF, pagine web, cartelle, banche domande) si leggono in
locale con scripts/fonti_dizionario.py; al server arrivano i risultati in JSON
insieme a metadati, indirizzo ed estratto del testo. Il server registra la
fonte e crea le BOZZE; un moderatore (admin, oppure docente verificato con
assegnazione corrente e verificata sulla materia) le modifica, le collega e le
approva. Solo allora diventano versioni pubbliche del Dizionario.
"""
import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path

from sqlalchemy import func, or_, text
from sqlalchemy.orm import Session

from models.dictionary import (DictionaryDraft, DictionaryEntry, DictionarySource, DictionaryTopic,
                               DictionaryVersion)
from models.subject import Subject
from models.user import User
from services.dictionary import (DATA_ROOT, PUBLIC_REVIEW_STATES, _list, apply_content, can_edit, clean_content,
                                 current_academic_year, display_name, is_admin, is_verified_teacher,
                                 normalize_year, slugify, subject_teachers, teacher_subject_ids, tokens,
                                 version_content)

MAX_EXCERPT = 20000
MAX_DRAFTS_PER_IMPORT = 5000
RECHECK_DAYS = {'daily': 1, 'weekly': 7, 'monthly': 30}


def utc_now():
    return datetime.now(timezone.utc)


class ModerationError(Exception):
    def __init__(self, status: int, message: str):
        super().__init__(message)
        self.status = status
        self.message = message


# ---------------------------------------------------------------------------
# Permessi
# ---------------------------------------------------------------------------

def moderable_subject_ids(db: Session, user: User | None) -> set[int] | None:
    """None = tutte (admin); altrimenti le materie del docente verificato."""
    if is_admin(user):
        return None
    return teacher_subject_ids(db, user)


def require_moderator(db: Session, user: User | None, subject_id: int | None) -> None:
    if subject_id is None:
        if not is_admin(user):
            raise ModerationError(403, 'Solo un admin può gestire fonti senza materia.')
        return
    if not can_edit(db, user, subject_id):
        raise ModerationError(403, 'Puoi moderare solo le materie con assegnazione verificata.')


def _scope(query, column, ids: set[int] | None):
    if ids is None:
        return query
    return query.filter(column.in_(ids or {-1}))


# ---------------------------------------------------------------------------
# Registro delle fonti
# ---------------------------------------------------------------------------

def _json(value, default):
    try:
        parsed = json.loads(value) if isinstance(value, str) else value
    except (TypeError, ValueError):
        return default
    return parsed if isinstance(parsed, type(default)) else default


def serialize_source(db: Session, source: DictionarySource, with_text: bool = False) -> dict:
    subject = db.query(Subject).filter(Subject.id == source.subject_id).first() if source.subject_id else None
    counts = dict(db.query(DictionaryDraft.status, func.count(DictionaryDraft.id)).filter(
        DictionaryDraft.source_id == source.id).group_by(DictionaryDraft.status).all())
    data = {
        'id': source.id, 'kind': source.kind, 'label': source.label, 'location': source.location,
        'subject_id': source.subject_id, 'subject_name': subject.name if subject else None,
        'course': subject.course if subject else None, 'department_code': subject.department_code if subject else None,
        'academic_year': source.academic_year, 'topic_title': source.topic_title,
        'sha256': source.sha256, 'recheck': source.recheck, 'selector': source.selector,
        'status': source.status, 'entries_found': source.entries_found, 'error': source.error,
        'last_read_at': source.last_read_at, 'created_by_name': source.created_by_name,
        'created_at': source.created_at, 'updated_at': source.updated_at,
        'pending': counts.get('pending', 0), 'approved': counts.get('approved', 0),
        'rejected': counts.get('rejected', 0), 'metadata': _json(source.metadata_json, {}),
        'recheck_due': is_recheck_due(source),
        'has_text': bool(source.text_excerpt),
    }
    if with_text:
        data['text_excerpt'] = source.text_excerpt
    return data


def is_recheck_due(source: DictionarySource) -> bool:
    if source.kind != 'web':
        return False
    if source.status == 'new' or source.last_read_at is None:
        return True
    days = RECHECK_DAYS.get(source.recheck or 'none')
    if not days:
        return False
    last = source.last_read_at if source.last_read_at.tzinfo else source.last_read_at.replace(tzinfo=timezone.utc)
    return (utc_now() - last).days >= days


def register_source(db: Session, user: User, payload: dict, subject: Subject | None,
                    source_id: int | None = None) -> DictionarySource:
    """Crea o aggiorna una fonte. La stessa fonte (indirizzo/percorso o impronta,
    materia, anno) viene riconosciuta e aggiornata, non duplicata."""
    kind = str(payload.get('kind') or 'manual').strip().lower()
    if kind not in ('json', 'pdf', 'web', 'question_bank', 'local', 'text', 'manual'):
        kind = 'manual'
    location = (str(payload.get('location') or '').strip()[:1000]) or None
    if kind == 'web' and location and not location.startswith(('http://', 'https://')):
        raise ModerationError(400, 'Per una pagina web indica un indirizzo http:// o https://')
    year = normalize_year(payload.get('academic_year')) or None
    sha = (str(payload.get('sha256') or '').strip().lower()[:64]) or None
    source = None
    if source_id is not None:
        source = db.query(DictionarySource).filter(DictionarySource.id == source_id).first()
        if source is None:
            raise ModerationError(404, 'Fonte non trovata.')
    else:
        query = db.query(DictionarySource)
        query = (query.filter(DictionarySource.subject_id == subject.id) if subject is not None
                 else query.filter(DictionarySource.subject_id.is_(None)))
        if year:
            query = query.filter(DictionarySource.academic_year == year)
        if location:
            source = query.filter(DictionarySource.location == location).first()
        elif sha:
            source = query.filter(DictionarySource.sha256 == sha).first()
    if source is None:
        source = DictionarySource(kind=kind, created_by=user.id, created_by_name=display_name(user), status='new',
                                  label=(str(payload.get('label') or location or 'Fonte').strip()[:300]) or 'Fonte')
        db.add(source)
    if payload.get('kind'):
        source.kind = kind
    if payload.get('label'):
        source.label = str(payload['label']).strip()[:300] or source.label
    source.location = location or source.location
    if subject is not None:
        source.subject_id = subject.id
    source.academic_year = year or source.academic_year
    for key, limit in (('topic_title', 200), ('selector', 200), ('etag', 300), ('last_modified', 100)):
        if payload.get(key) is not None:
            setattr(source, key, str(payload.get(key)).strip()[:limit] or None)
    if payload.get('recheck') in ('none', 'daily', 'weekly', 'monthly'):
        source.recheck = payload['recheck']
    if sha:
        source.sha256 = sha
    if payload.get('teacher_user_id'):
        source.teacher_user_id = int(payload['teacher_user_id'])
    status = payload.get('status')
    if status in ('new', 'read', 'unchanged', 'no_terms', 'error'):
        source.status = status
        if status != 'new':
            source.last_read_at = utc_now()
    if payload.get('entries_found') is not None:
        try:
            source.entries_found = max(0, int(payload['entries_found']))
        except (TypeError, ValueError):
            pass
    if 'error' in payload:
        source.error = (str(payload.get('error') or '').strip()[:2000]) or None
    if payload.get('text_excerpt') is not None:
        source.text_excerpt = str(payload['text_excerpt'])[:MAX_EXCERPT] or None
    if isinstance(payload.get('metadata'), dict):
        metadata = {str(k)[:60]: v for k, v in list(payload['metadata'].items())[:40]
                    if isinstance(v, (str, int, float, bool)) or v is None}
        source.metadata_json = json.dumps(metadata, ensure_ascii=False)[:8000]
    db.flush()
    return source


def list_sources(db: Session, user: User, subject_id: int | None = None, status: str | None = None,
                 kind: str | None = None, q: str | None = None) -> list[dict]:
    query = db.query(DictionarySource)
    ids = moderable_subject_ids(db, user)
    if ids is not None:
        query = query.filter(DictionarySource.subject_id.in_(ids or {-1}))
    if subject_id:
        query = query.filter(DictionarySource.subject_id == subject_id)
    if status:
        query = query.filter(DictionarySource.status == status)
    if kind:
        query = query.filter(DictionarySource.kind == kind)
    if q and q.strip():
        like = f'%{q.strip().lower()}%'
        query = query.filter(or_(func.lower(DictionarySource.label).like(like),
                                 func.lower(func.coalesce(DictionarySource.location, '')).like(like)))
    rows = query.order_by(DictionarySource.updated_at.desc()).limit(500).all()
    return [serialize_source(db, row) for row in rows]


# ---------------------------------------------------------------------------
# Bozze
# ---------------------------------------------------------------------------

def _content_hash(term: str, aliases: list, content: dict) -> str:
    raw = json.dumps({'term': term.strip().lower(), 'aliases': sorted(a.lower() for a in aliases), **content},
                     sort_keys=True, ensure_ascii=False, default=str)
    return hashlib.sha256(raw.encode()).hexdigest()


def _draft_content(draft: DictionaryDraft) -> dict:
    return clean_content(_json(draft.content_json, {}))


def _published_version(db: Session, entry_id: int, year: str) -> DictionaryVersion | None:
    return db.query(DictionaryVersion).filter(DictionaryVersion.entry_id == entry_id,
        DictionaryVersion.academic_year == year, DictionaryVersion.review_state.in_(PUBLIC_REVIEW_STATES)).first()


def _same_as_published(db: Session, entry_id: int | None, year: str, content: dict) -> bool:
    if entry_id is None:
        return False
    version = _published_version(db, entry_id, year)
    if version is None:
        return False
    current = version_content(version)
    fields = ('formal_definition', 'informal_definition', 'examples', 'exercises', 'exam_questions')
    return all(current.get(f) == content.get(f) for f in fields)


def drafts_from_dictionary(db: Session, data: dict, user: User, subject: Subject, year_override: str | None,
                           source: DictionarySource | None = None) -> dict:
    metadata = data.get('metadata') or {}
    year = normalize_year(year_override) or normalize_year(metadata.get('academic_year')) or current_academic_year()
    teachers = [str(t).strip() for t in _list(metadata.get('teachers')) if str(t).strip()][:20]
    quiz_source = str(metadata.get('source') or '').strip()[:500] or None
    if quiz_source and not quiz_source.endswith('.json'):
        quiz_source = None   # 'source' è un file di domande solo se è un JSON dei quiz
    topics_by_slug = {}
    for raw in _list(data.get('topics')):
        if isinstance(raw, dict) and (raw.get('title') or '').strip():
            topics_by_slug[slugify(raw.get('id') or raw['title'])] = raw['title'].strip()[:200]
    existing_topics = {t.slug: t for t in db.query(DictionaryTopic).filter(DictionaryTopic.subject_id == subject.id).all()}
    role = 'admin' if is_admin(user) else ('teacher' if is_verified_teacher(user) else 'import')
    counts = {'created': 0, 'updated': 0, 'skipped': 0, 'unchanged': 0, 'already_published': 0,
              'rejected_before': 0}
    entries = [e for e in _list(data.get('entries')) if isinstance(e, dict)][:MAX_DRAFTS_PER_IMPORT]
    for raw in entries:
        term = (raw.get('term') or '').strip()[:200]
        if not term:
            counts['skipped'] += 1
            continue
        content = clean_content({**raw, 'quiz_source': raw.get('quiz_source') or quiz_source})
        if not content['formal_definition'] and not content['informal_definition']:
            counts['skipped'] += 1
            continue
        aliases = [str(a).strip()[:200] for a in _list(raw.get('aliases')) if str(a).strip()][:10]
        slug = slugify(raw.get('id') or term)
        review = raw.get('_review') if isinstance(raw.get('_review'), dict) else {}
        topic_slug = slugify(raw.get('topic')) if raw.get('topic') else None
        topic = existing_topics.get(topic_slug) if topic_slug else None
        topic_title = None if topic else (topics_by_slug.get(topic_slug) if topic_slug else None)
        if topic_title and slugify(topic_title) == 'da-classificare':
            topic_title = None
        entry = db.query(DictionaryEntry).filter(DictionaryEntry.subject_id == subject.id,
                                                 DictionaryEntry.slug == slug).first()
        stored_content = {k: v for k, v in content.items()}
        digest = _content_hash(term, aliases, stored_content)
        if _same_as_published(db, entry.id if entry else None, year, content):
            counts['already_published'] += 1
            continue
        same = db.query(DictionaryDraft).filter(DictionaryDraft.subject_id == subject.id,
            DictionaryDraft.slug == slug, DictionaryDraft.academic_year == year).order_by(
            DictionaryDraft.created_at.desc()).all()
        if any(d.status == 'rejected' and d.content_hash == digest for d in same):
            counts['rejected_before'] += 1
            continue
        pending = next((d for d in same if d.status == 'pending'), None)
        if pending is not None and pending.content_hash == digest:
            if source is not None and pending.source_id is None:
                pending.source_id = source.id
            counts['unchanged'] += 1
            continue
        draft = pending or DictionaryDraft(subject_id=subject.id, slug=slug, academic_year=year, status='pending',
                                           author_user_id=user.id, author_name=display_name(user), author_role=role)
        if pending is None:
            db.add(draft)
        draft.term = term
        draft.aliases_json = json.dumps(aliases, ensure_ascii=False)
        draft.topic_id = topic.id if topic else None
        draft.topic_title = topic_title
        draft.content_json = json.dumps(stored_content, ensure_ascii=False)
        draft.content_hash = digest
        draft.teachers_json = json.dumps(teachers, ensure_ascii=False)
        draft.quiz_source = content.get('quiz_source')
        draft.target_entry_id = entry.id if entry else None
        draft.source_id = source.id if source else draft.source_id
        draft.source_ref = (str(review.get('where') or '').strip()[:200]) or draft.source_ref
        excerpt = review.get('excerpt') or review.get('snippet')
        if excerpt:
            draft.source_excerpt = str(excerpt)[:4000]
        counts['updated' if pending else 'created'] += 1
    if source is not None:
        source.entries_found = len(entries)
        if source.status in ('new', None):
            source.status = 'read'
            source.last_read_at = utc_now()
    db.commit()
    return {'subject_id': subject.id, 'subject_name': subject.name, 'academic_year': year,
            'topics': len(topics_by_slug), 'source_id': source.id if source else None, **counts}


def draft_from_editor(db: Session, user: User, subject_id: int, entry: DictionaryEntry | None, term: str,
                      aliases: list[str], topic_id: int | None, topic_title: str | None, year: str, content: dict,
                      teachers: list[str] | None) -> DictionaryDraft:
    """Modifica fatta nell'editor e salvata "da moderare"."""
    slug = entry.slug if entry else slugify(term)
    digest = _content_hash(term, aliases, content)
    draft = db.query(DictionaryDraft).filter(DictionaryDraft.subject_id == subject_id, DictionaryDraft.slug == slug,
        DictionaryDraft.academic_year == year, DictionaryDraft.status == 'pending',
        DictionaryDraft.author_user_id == user.id).first()
    if draft is None:
        draft = DictionaryDraft(subject_id=subject_id, slug=slug, academic_year=year, status='pending',
                                author_user_id=user.id, author_name=display_name(user),
                                author_role='admin' if is_admin(user) else 'teacher')
        db.add(draft)
    draft.term = term.strip()[:200]
    draft.aliases_json = json.dumps(aliases, ensure_ascii=False)
    draft.topic_id, draft.topic_title = topic_id, (topic_title or None)
    draft.content_json = json.dumps(content, ensure_ascii=False)
    draft.content_hash = digest
    draft.teachers_json = json.dumps(teachers or [], ensure_ascii=False)
    draft.target_entry_id = entry.id if entry else None
    draft.source_ref = 'modifica dall’editor'
    db.commit()
    db.refresh(draft)
    return draft


def serialize_draft(db: Session, draft: DictionaryDraft, subjects: dict | None = None,
                    sources: dict | None = None) -> dict:
    subject = (subjects or {}).get(draft.subject_id) or db.query(Subject).filter(Subject.id == draft.subject_id).first()
    source = None
    if draft.source_id:
        source = (sources or {}).get(draft.source_id) or db.query(DictionarySource).filter(
            DictionarySource.id == draft.source_id).first()
    content = _draft_content(draft)
    kind = 'update' if draft.target_entry_id else 'new'
    return {
        'id': draft.id, 'term': draft.term, 'slug': draft.slug, 'status': draft.status, 'kind': kind,
        'subject_id': draft.subject_id, 'subject_name': subject.name if subject else None,
        'course': subject.course if subject else None, 'academic_year': draft.academic_year,
        'topic_id': draft.topic_id, 'topic_title': draft.topic_title,
        'source_id': draft.source_id, 'source_label': source.label if source else None,
        'source_kind': source.kind if source else None, 'source_ref': draft.source_ref,
        'author_name': draft.author_name, 'author_role': draft.author_role,
        'assigned_teacher_name': draft.assigned_teacher_name,
        'preview': (content.get('informal_definition') or content.get('formal_definition') or '')[:200],
        'created_at': draft.created_at, 'updated_at': draft.updated_at,
        'reviewed_by_name': draft.reviewed_by_name, 'reviewed_at': draft.reviewed_at, 'review_note': draft.review_note,
    }


def list_drafts(db: Session, user: User, subject_id: int | None = None, status: str = 'pending',
                source_id: int | None = None, kind: str | None = None, q: str | None = None,
                limit: int = 200, offset: int = 0) -> dict:
    ids = moderable_subject_ids(db, user)
    query = _scope(db.query(DictionaryDraft), DictionaryDraft.subject_id, ids)
    if subject_id:
        query = query.filter(DictionaryDraft.subject_id == subject_id)
    if status != 'all':
        query = query.filter(DictionaryDraft.status == status)
    if source_id:
        query = query.filter(DictionaryDraft.source_id == source_id)
    if kind == 'new':
        query = query.filter(DictionaryDraft.target_entry_id.is_(None))
    elif kind == 'update':
        query = query.filter(DictionaryDraft.target_entry_id.isnot(None))
    if q and q.strip():
        query = query.filter(func.lower(DictionaryDraft.term).like(f'%{q.strip().lower()}%'))
    total = query.count()
    rows = query.order_by(DictionaryDraft.created_at.desc(), DictionaryDraft.id.desc()).offset(offset).limit(limit).all()
    subject_ids = {r.subject_id for r in rows}
    source_ids = {r.source_id for r in rows if r.source_id}
    subjects = {s.id: s for s in db.query(Subject).filter(Subject.id.in_(subject_ids or {-1})).all()}
    sources = {s.id: s for s in db.query(DictionarySource).filter(DictionarySource.id.in_(source_ids or {-1})).all()}
    counts_query = _scope(db.query(DictionaryDraft.status, func.count(DictionaryDraft.id)), DictionaryDraft.subject_id, ids)
    if subject_id:
        counts_query = counts_query.filter(DictionaryDraft.subject_id == subject_id)
    counts = dict(counts_query.group_by(DictionaryDraft.status).all())
    return {'total': total, 'counts': counts, 'items': [serialize_draft(db, r, subjects, sources) for r in rows]}


def find_duplicates(db: Session, draft: DictionaryDraft, limit: int = 5) -> list[dict]:
    wanted = tokens(draft.term)
    aliases = [a.lower() for a in _json(draft.aliases_json, [])]
    result = []
    for entry in db.query(DictionaryEntry).filter(DictionaryEntry.subject_id == draft.subject_id).all():
        if entry.id == draft.target_entry_id:
            continue
        entry_aliases = [a.lower() for a in _json(entry.aliases_json, [])]
        have = tokens(entry.term)
        score = len(wanted & have) / max(len(wanted | have), 1) if wanted and have else 0
        if entry.slug == draft.slug or draft.term.lower() in entry_aliases or entry.term.lower() in aliases:
            score = 1.0
        if score < 0.6:
            continue
        published = db.query(DictionaryVersion).filter(DictionaryVersion.entry_id == entry.id,
            DictionaryVersion.review_state.in_(PUBLIC_REVIEW_STATES)).order_by(
            DictionaryVersion.academic_year.desc()).first()
        result.append({'entry_id': entry.id, 'term': entry.term, 'score': round(score, 2),
                       'published_year': published.academic_year if published else None,
                       'author_name': published.author_name if published else None,
                       'preview': ((published.informal_definition or published.formal_definition or '')[:180]
                                   if published else '')})
    result.sort(key=lambda r: -r['score'])
    return result[:limit]


def past_exams(db: Session, subject_id: int, limit: int = 30) -> list[dict]:
    """Appelli già svolti della materia dal Calendario (se presente)."""
    try:
        rows = db.execute(text(
            "SELECT id, title, starts_at, exam_format FROM calendar_events "
            "WHERE subject_id = :sid AND kind IN ('exam','extraordinary') AND status <> 'cancelled' "
            "AND starts_at <= now() ORDER BY starts_at DESC LIMIT :lim"), {'sid': subject_id, 'lim': limit}).fetchall()
    except Exception:   # calendario non installato: nessun collegamento
        db.rollback()
        return []
    return [{'id': r[0], 'title': r[1], 'date': r[2].date().isoformat() if r[2] else None, 'format': r[3]} for r in rows]


def teachers_for(db: Session, user: User, subject_id: int) -> list[dict]:
    """Docenti a cui affidare il termine: quelli verificati della materia
    (l'admin vede anche gli altri docenti verificati)."""
    listed = subject_teachers(db, subject_id)
    if is_admin(user):
        known = {t['id'] for t in listed}
        for teacher in db.query(User).filter(User.role == 'teacher', User.is_active.is_(True),
                                             User.teacher_verification_status == 'verified').order_by(
                User.last_name).limit(300).all():
            if teacher.id not in known:
                listed.append({'id': teacher.id, 'name': display_name(teacher), 'other_subject': True})
    return listed


def draft_detail(db: Session, draft: DictionaryDraft, user: User) -> dict:
    data = serialize_draft(db, draft)
    subject = db.query(Subject).filter(Subject.id == draft.subject_id).first()
    source = db.query(DictionarySource).filter(DictionarySource.id == draft.source_id).first() if draft.source_id else None
    published = None
    if draft.target_entry_id:
        version = db.query(DictionaryVersion).filter(DictionaryVersion.entry_id == draft.target_entry_id,
            DictionaryVersion.review_state.in_(PUBLIC_REVIEW_STATES)).order_by(
            DictionaryVersion.academic_year.desc()).first()
        if version is not None:
            published = {'academic_year': version.academic_year, 'author_name': version.author_name,
                         'updated_at': version.updated_at, **version_content(version)}
    topics = db.query(DictionaryTopic).filter(DictionaryTopic.subject_id == draft.subject_id).order_by(
        DictionaryTopic.sort_order, DictionaryTopic.title).all()
    data.update({
        'aliases': _json(draft.aliases_json, []), 'content': _draft_content(draft),
        'teachers': _json(draft.teachers_json, []), 'quiz_source': draft.quiz_source,
        'assigned_teacher_user_id': draft.assigned_teacher_user_id, 'target_entry_id': draft.target_entry_id,
        'source_excerpt': draft.source_excerpt,
        'source': serialize_source(db, source) if source else None,
        'subject': {'id': subject.id, 'name': subject.name, 'course': subject.course, 'department': subject.department,
                    'department_code': subject.department_code, 'course_code': subject.course_code,
                    'university': subject.university} if subject else None,
        'published': published,
        'duplicates': find_duplicates(db, draft),
        'topics': [{'id': t.id, 'title': t.title} for t in topics],
        'teachers_available': teachers_for(db, user, draft.subject_id),
        'past_exams': past_exams(db, draft.subject_id),
        'can_moderate': can_edit(db, user, draft.subject_id),
        'is_admin': is_admin(user),
    })
    return data


def update_draft(db: Session, draft: DictionaryDraft, payload: dict, user: User) -> DictionaryDraft:
    if draft.status != 'pending':
        raise ModerationError(409, 'Questa bozza è già stata moderata.')
    new_subject_id = payload.get('subject_id')
    if new_subject_id and int(new_subject_id) != draft.subject_id:
        require_moderator(db, user, int(new_subject_id))
        if db.query(Subject.id).filter(Subject.id == int(new_subject_id), Subject.is_active.is_(True)).first() is None:
            raise ModerationError(400, 'Materia non trovata.')
        draft.subject_id = int(new_subject_id)
        draft.topic_id = None
        draft.target_entry_id = None
    if payload.get('term') is not None:
        term = str(payload['term']).strip()[:200]
        if not term:
            raise ModerationError(400, 'Il termine non può essere vuoto.')
        draft.term = term
        if draft.target_entry_id is None:
            draft.slug = slugify(term)
    if payload.get('aliases') is not None:
        draft.aliases_json = json.dumps([str(a).strip()[:200] for a in _list(payload['aliases']) if str(a).strip()][:10],
                                        ensure_ascii=False)
    if 'topic_id' in payload or 'topic_title' in payload:
        topic_id = payload.get('topic_id')
        if topic_id:
            if not db.query(DictionaryTopic.id).filter(DictionaryTopic.id == int(topic_id),
                                                       DictionaryTopic.subject_id == draft.subject_id).first():
                raise ModerationError(400, 'Argomento non valido per questa materia.')
            draft.topic_id, draft.topic_title = int(topic_id), None
        else:
            draft.topic_id = None
            draft.topic_title = (str(payload.get('topic_title') or '').strip()[:200]) or None
    if payload.get('academic_year') is not None:
        year = normalize_year(payload['academic_year'])
        if year is None:
            raise ModerationError(400, 'Anno accademico non valido (es. 2025/2026).')
        draft.academic_year = year
    if 'target_entry_id' in payload:
        target = payload.get('target_entry_id')
        if target:
            entry = db.query(DictionaryEntry).filter(DictionaryEntry.id == int(target),
                                                     DictionaryEntry.subject_id == draft.subject_id).first()
            if entry is None:
                raise ModerationError(400, 'Il termine da aggiornare non è di questa materia.')
            draft.target_entry_id = entry.id
        else:
            draft.target_entry_id = None
    if 'assigned_teacher_user_id' in payload:
        teacher_id = payload.get('assigned_teacher_user_id')
        if teacher_id:
            allowed = {t['id'] for t in teachers_for(db, user, draft.subject_id)}
            if int(teacher_id) not in allowed:
                raise ModerationError(400, 'Puoi affidare il termine solo a un docente verificato della materia.')
            teacher = db.query(User).filter(User.id == int(teacher_id)).first()
            draft.assigned_teacher_user_id, draft.assigned_teacher_name = teacher.id, display_name(teacher)
        else:
            draft.assigned_teacher_user_id, draft.assigned_teacher_name = None, None
    if payload.get('teachers') is not None:
        draft.teachers_json = json.dumps([str(t).strip()[:120] for t in _list(payload['teachers']) if str(t).strip()][:20],
                                         ensure_ascii=False)
    if isinstance(payload.get('content'), dict):
        content = clean_content({**_draft_content(draft), **payload['content']})
        if not content['formal_definition'] and not content['informal_definition']:
            raise ModerationError(400, 'Scrivi almeno una definizione.')
        draft.content_json = json.dumps(content, ensure_ascii=False)
        draft.quiz_source = content.get('quiz_source') or draft.quiz_source
    draft.content_hash = _content_hash(draft.term, _json(draft.aliases_json, []), _draft_content(draft))
    db.commit()
    db.refresh(draft)
    return draft


def _topic_for_draft(db: Session, draft: DictionaryDraft) -> int | None:
    if draft.topic_id:
        return draft.topic_id
    if draft.topic_title:
        slug = slugify(draft.topic_title)
        topic = db.query(DictionaryTopic).filter(DictionaryTopic.subject_id == draft.subject_id,
                                                 DictionaryTopic.slug == slug).first()
        if topic is None:
            count = db.query(DictionaryTopic).filter(DictionaryTopic.subject_id == draft.subject_id).count()
            topic = DictionaryTopic(subject_id=draft.subject_id, slug=slug, title=draft.topic_title, sort_order=count + 1)
            db.add(topic)
            db.flush()
        return topic.id
    return None


def approve_draft(db: Session, draft: DictionaryDraft, user: User, merge_into: int | None = None) -> dict:
    """Pubblica la bozza. Con merge_into il termine confluisce in un termine
    esistente: il nome della bozza diventa un sinonimo."""
    if draft.status != 'pending':
        raise ModerationError(409, 'Questa bozza è già stata moderata.')
    content = _draft_content(draft)
    if not content['formal_definition'] and not content['informal_definition']:
        raise ModerationError(400, 'Scrivi almeno una definizione prima di pubblicare.')
    target_id = merge_into or draft.target_entry_id
    entry = None
    if target_id:
        entry = db.query(DictionaryEntry).filter(DictionaryEntry.id == target_id,
                                                 DictionaryEntry.subject_id == draft.subject_id).with_for_update().first()
        if entry is None:
            raise ModerationError(400, 'Il termine di destinazione non è di questa materia.')
    if entry is None:
        entry = db.query(DictionaryEntry).filter(DictionaryEntry.subject_id == draft.subject_id,
                                                 DictionaryEntry.slug == draft.slug).first()
    aliases = _json(draft.aliases_json, [])
    if entry is None:
        entry = DictionaryEntry(subject_id=draft.subject_id, slug=draft.slug, term=draft.term)
        db.add(entry)
    existing_aliases = _json(entry.aliases_json, [])
    if merge_into and draft.term.lower() != entry.term.lower():
        aliases = aliases + [draft.term]
    elif not merge_into:
        entry.term = draft.term
    merged_aliases = []
    for alias in existing_aliases + aliases:
        if alias and alias.lower() != entry.term.lower() and alias.lower() not in {a.lower() for a in merged_aliases}:
            merged_aliases.append(alias)
    entry.aliases_json = json.dumps(merged_aliases[:10], ensure_ascii=False)
    topic_id = _topic_for_draft(db, draft)
    if topic_id:
        entry.topic_id = topic_id
    db.flush()
    version = db.query(DictionaryVersion).filter(DictionaryVersion.entry_id == entry.id,
                                                 DictionaryVersion.academic_year == draft.academic_year).first()
    if version is None:
        version = DictionaryVersion(entry_id=entry.id, academic_year=draft.academic_year)
        db.add(version)
    apply_content(version, content)
    teachers = _json(draft.teachers_json, []) or [t['name'] for t in subject_teachers(db, draft.subject_id)]
    version.teachers_json = json.dumps(teachers, ensure_ascii=False)
    if content.get('quiz_source') or draft.quiz_source:
        version.quiz_source = content.get('quiz_source') or draft.quiz_source
    # Chi l'ha scritto resta firmato anche quando non insegna più la materia.
    version.author_user_id = draft.author_user_id
    version.author_name = draft.author_name
    version.author_role = draft.author_role if draft.author_role in ('admin', 'teacher', 'import') else 'import'
    if draft.assigned_teacher_user_id:
        version.assigned_teacher_user_id = draft.assigned_teacher_user_id
        version.assigned_teacher_name = draft.assigned_teacher_name
    version.review_state = 'confirmed'
    version.reviewed_by, version.reviewed_at = user.id, utc_now()
    version.source_id, version.source_ref = draft.source_id, draft.source_ref
    version.updated_at = utc_now()
    db.flush()
    draft.status = 'approved'
    draft.target_entry_id = entry.id
    draft.published_version_id = version.id
    draft.reviewed_by, draft.reviewed_by_name, draft.reviewed_at = user.id, display_name(user), utc_now()
    db.commit()
    _notify_assigned(db, draft, user)
    return {'draft_id': draft.id, 'entry_id': entry.id, 'version_id': version.id, 'status': draft.status}


def reject_draft(db: Session, draft: DictionaryDraft, user: User, note: str | None) -> dict:
    if draft.status != 'pending':
        raise ModerationError(409, 'Questa bozza è già stata moderata.')
    draft.status = 'rejected'
    draft.review_note = (note or '').strip()[:1000] or None
    draft.reviewed_by, draft.reviewed_by_name, draft.reviewed_at = user.id, display_name(user), utc_now()
    db.commit()
    return {'draft_id': draft.id, 'status': draft.status}


def _notify_assigned(db: Session, draft: DictionaryDraft, actor: User) -> None:
    if not draft.assigned_teacher_user_id or draft.assigned_teacher_user_id == actor.id:
        return
    try:
        from services.notification import create_notification
        create_notification(db, user_id=draft.assigned_teacher_user_id, notification_type='system',
                            title='Termine del Dizionario affidato a te'[:120],
                            message=f'“{draft.term}” è stato pubblicato e affidato a te per le prossime revisioni.'[:500],
                            actor_user_id=actor.id)
    except Exception:   # la notifica non deve bloccare la pubblicazione
        db.rollback()


# ---------------------------------------------------------------------------
# Banca domande della materia (per collegare domande al termine)
# ---------------------------------------------------------------------------

def question_bank_search(subject: Subject, q: str, limit: int = 30) -> list[dict]:
    department = (subject.department_code or '').strip().lower()
    course = (subject.course_code or '').strip().lower()
    folder = (DATA_ROOT / department / course / 'question').resolve()
    if not department or not course or DATA_ROOT.resolve() not in folder.parents or not folder.is_dir():
        return []
    wanted = tokens(q)
    subject_words = tokens(subject.name)
    result = []
    for path in sorted(folder.glob('*.json')):
        file_words = tokens(path.stem.replace('_', ' '))
        if subject_words and not (subject_words & file_words):
            continue   # file di un'altra materia dello stesso corso
        try:
            items = json.loads(path.read_text(encoding='utf-8'))
        except (OSError, ValueError):
            continue
        for item in items if isinstance(items, list) else []:
            if not isinstance(item, dict):
                continue
            text_value = str(item.get('text') or '')
            if wanted and not wanted <= tokens(text_value + ' ' + str(item.get('term') or '')):
                continue
            result.append({'id': item.get('id_question') or item.get('id'), 'text': text_value[:300],
                           'argument': (item.get('metadata') or {}).get('argoment'),
                           'quiz_source': str(path.relative_to(DATA_ROOT.resolve()))})
            if len(result) >= limit:
                return result
    return result
