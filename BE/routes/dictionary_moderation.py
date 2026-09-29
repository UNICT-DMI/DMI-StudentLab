"""Dizionario: registro delle fonti e moderazione delle bozze.

Moderano gli admin (tutte le materie) e i docenti con profilo verificato e
assegnazione corrente e verificata sulla materia (solo quelle materie).
I PDF e le pagine web si leggono in locale con scripts/fonti_dizionario.py:
qui arrivano i risultati in JSON, i metadati, l'indirizzo e un estratto.
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy import func
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_current_user
from models.dictionary import DictionaryDraft, DictionarySource
from models.subject import Subject
from models.user import User
from services.dictionary import SCHEMA, is_admin, match_subject
from services.dictionary_moderation import (ModerationError, approve_draft, draft_detail, drafts_from_dictionary,
                                            list_drafts, list_sources, moderable_subject_ids,
                                            question_bank_search, register_source, reject_draft,
                                            require_moderator, serialize_source, teachers_for, update_draft)

router = APIRouter(prefix='/dictionary', tags=['dictionary-moderation'])


def _raise(exc: ModerationError):
    raise HTTPException(exc.status, exc.message)


def _subject(db: Session, subject_id: int | None) -> Subject | None:
    if subject_id is None:
        return None
    subject = db.query(Subject).filter(Subject.id == subject_id).first()
    if subject is None:
        raise HTTPException(404, 'Materia non trovata.')
    return subject


def _draft(db: Session, draft_id: int, user: User, lock: bool = False) -> DictionaryDraft:
    query = db.query(DictionaryDraft).filter(DictionaryDraft.id == draft_id)
    draft = (query.with_for_update() if lock else query).first()
    if draft is None:
        raise HTTPException(404, 'Bozza non trovata.')
    try:
        require_moderator(db, user, draft.subject_id)
    except ModerationError as exc:
        _raise(exc)
    return draft


def _source(db: Session, source_id: int, user: User) -> DictionarySource:
    source = db.query(DictionarySource).filter(DictionarySource.id == source_id).first()
    if source is None:
        raise HTTPException(404, 'Fonte non trovata.')
    try:
        require_moderator(db, user, source.subject_id)
    except ModerationError as exc:
        _raise(exc)
    return source


# ---------------------------------------------------------------------------
# Cosa posso moderare
# ---------------------------------------------------------------------------

@router.get('/moderation/subjects')
def moderation_subjects(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Materie che l'utente può moderare, con i termini in attesa."""
    ids = moderable_subject_ids(db, current_user)
    if ids is not None and not ids:
        return {'is_admin': False, 'subjects': []}
    pending = dict(db.query(DictionaryDraft.subject_id, func.count(DictionaryDraft.id)).filter(
        DictionaryDraft.status == 'pending').group_by(DictionaryDraft.subject_id).all())
    query = db.query(Subject).filter(Subject.is_active.is_(True))
    if ids is not None:
        query = query.filter(Subject.id.in_(ids))
    else:
        # Admin: prima le materie con qualcosa da moderare, poi tutte le altre.
        query = query.order_by(Subject.name)
    subjects = query.order_by(Subject.name).limit(3000).all()
    items = [{'id': s.id, 'name': s.name, 'university': s.university, 'department': s.department,
              'department_code': s.department_code, 'course': s.course, 'course_code': s.course_code,
              'pending': pending.get(s.id, 0)} for s in subjects]
    items.sort(key=lambda s: (-s['pending'], s['name'] or ''))
    return {'is_admin': is_admin(current_user), 'subjects': items,
            'pending_total': sum(s['pending'] for s in items)}


# ---------------------------------------------------------------------------
# Registro delle fonti
# ---------------------------------------------------------------------------

class SourceWrite(BaseModel):
    kind: str = Field(pattern='^(json|pdf|web|question_bank|local|text|manual)$')
    label: str | None = Field(default=None, max_length=300)
    location: str | None = Field(default=None, max_length=1000)
    subject_id: int | None = None
    academic_year: str | None = Field(default=None, max_length=20)
    topic_title: str | None = Field(default=None, max_length=200)
    teacher_user_id: int | None = None
    recheck: str | None = Field(default=None, pattern='^(none|daily|weekly|monthly)$')
    selector: str | None = Field(default=None, max_length=200)
    reread: bool | None = None   # solo PATCH: chiede allo script di rileggerla al prossimo --sincronizza


class SourceResults(BaseModel):
    """Risultato della lettura fatta in locale dallo script."""
    status: str = Field(pattern='^(read|unchanged|no_terms|error)$')
    kind: str | None = Field(default=None, pattern='^(json|pdf|web|question_bank|local|text|manual)$')
    label: str | None = Field(default=None, max_length=300)
    sha256: str | None = Field(default=None, max_length=64)
    etag: str | None = Field(default=None, max_length=300)
    last_modified: str | None = Field(default=None, max_length=100)
    entries_found: int | None = Field(default=None, ge=0)
    error: str | None = Field(default=None, max_length=2000)
    text_excerpt: str | None = Field(default=None, max_length=200000)
    metadata: dict | None = None
    dictionary: dict | None = None
    academic_year: str | None = Field(default=None, max_length=20)


@router.get('/sources')
def sources(subject_id: int | None = None, status: str | None = Query(default=None, max_length=20),
            kind: str | None = Query(default=None, max_length=20), q: str | None = Query(default=None, max_length=200),
            current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if subject_id is not None:
        try:
            require_moderator(db, current_user, subject_id)
        except ModerationError as exc:
            _raise(exc)
    elif moderable_subject_ids(db, current_user) == set():
        raise HTTPException(403, 'Il registro delle fonti è per admin e docenti verificati.')
    return list_sources(db, current_user, subject_id, status, kind, q)


@router.get('/sources/due')
def sources_due(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Pagine web da leggere o ricontrollare: le legge lo script in locale."""
    from services.dictionary_moderation import is_recheck_due
    query = db.query(DictionarySource).filter(DictionarySource.kind == 'web')
    ids = moderable_subject_ids(db, current_user)
    if ids is not None:
        query = query.filter(DictionarySource.subject_id.in_(ids or {-1}))
    items = []
    for source in query.all():
        if is_recheck_due(source):
            subject = db.query(Subject).filter(Subject.id == source.subject_id).first() if source.subject_id else None
            items.append({'id': source.id, 'url': source.location, 'selector': source.selector,
                          'subject_id': source.subject_id, 'subject': subject.name if subject else None,
                          'department_code': subject.department_code if subject else None,
                          'course_code': subject.course_code if subject else None,
                          'academic_year': source.academic_year, 'topic': source.topic_title,
                          'recheck': source.recheck, 'etag': source.etag, 'last_modified': source.last_modified,
                          'sha256': source.sha256})
    return items


@router.get('/sources/{source_id}')
def source_detail(source_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return serialize_source(db, _source(db, source_id, current_user), with_text=True)


@router.post('/sources')
def create_source(data: SourceWrite, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Aggiunge una fonte al registro (es. una pagina web da far leggere allo
    script, o una cartella). Nessun file viene caricato sul server."""
    try:
        require_moderator(db, current_user, data.subject_id)
        subject = _subject(db, data.subject_id)
        source = register_source(db, current_user, data.model_dump(exclude_none=True), subject)
        db.commit()
    except ModerationError as exc:
        _raise(exc)
    return serialize_source(db, source)


@router.patch('/sources/{source_id}')
def edit_source(source_id: int, data: SourceWrite, current_user: User = Depends(get_current_user),
                db: Session = Depends(get_db)):
    source = _source(db, source_id, current_user)
    try:
        if data.subject_id and data.subject_id != source.subject_id:
            require_moderator(db, current_user, data.subject_id)
        subject = _subject(db, data.subject_id) if data.subject_id else None
        source = register_source(db, current_user, data.model_dump(exclude_none=True), subject, source_id=source.id)
        if data.reread and source.kind == 'web':
            source.status = 'new'      # is_recheck_due la restituisce a /sources/due
        db.commit()
    except ModerationError as exc:
        _raise(exc)
    return serialize_source(db, source)


@router.delete('/sources/{source_id}')
def delete_source(source_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Toglie la fonte dal registro. Le bozze restano (senza fonte); i termini
    già pubblicati non cambiano."""
    source = _source(db, source_id, current_user)
    db.query(DictionaryDraft).filter(DictionaryDraft.source_id == source.id).update({'source_id': None})
    db.delete(source)
    db.commit()
    return {'deleted': source_id}


@router.post('/sources/{source_id}/results')
def source_results(source_id: int, data: SourceResults, current_user: User = Depends(get_current_user),
                   db: Session = Depends(get_db)):
    """Lo script invia il risultato di una fonte letta in locale."""
    source = _source(db, source_id, current_user)
    return _save_results(db, current_user, source, data)


class ResultsWithSource(SourceResults):
    source: SourceWrite
    subject_id: int | None = None


@router.post('/sources/results')
def new_source_results(data: ResultsWithSource, current_user: User = Depends(get_current_user),
                       db: Session = Depends(get_db)):
    """Come sopra, per una fonte nuova: la registra e ne salva i risultati.
    La materia si indica con subject_id o si riconosce dai metadati del JSON."""
    subject_id = data.subject_id or data.source.subject_id
    subject = _subject(db, subject_id) if subject_id else None
    if subject is None and data.dictionary:
        subject, candidates = match_subject(db, (data.dictionary or {}).get('metadata') or {})
        if subject is None:
            return {'saved': False, 'reason': 'subject_not_recognized',
                    'candidates': [{'id': s.id, 'name': s.name, 'course': s.course} for s in candidates]}
    try:
        require_moderator(db, current_user, subject.id if subject else None)
        payload = data.source.model_dump(exclude_none=True)
        payload['academic_year'] = data.academic_year or payload.get('academic_year') or \
            ((data.dictionary or {}).get('metadata') or {}).get('academic_year')
        source = register_source(db, current_user, payload, subject)
        db.flush()
    except ModerationError as exc:
        _raise(exc)
    return _save_results(db, current_user, source, data)


def _save_results(db: Session, user: User, source: DictionarySource, data: SourceResults) -> dict:
    try:
        payload = data.model_dump(exclude_none=True, exclude={'dictionary'})
        source = register_source(db, user, payload, None, source_id=source.id)
        report = None
        if data.status == 'read' and data.dictionary:
            dictionary = data.dictionary
            if dictionary.get('schema') not in (SCHEMA, None) or not isinstance(dictionary.get('entries'), list):
                raise ModerationError(400, f'Il risultato non è un dizionario StudentLab ({SCHEMA}).')
            if source.subject_id is None:
                raise ModerationError(400, 'Indica la materia della fonte prima di inviare i termini.')
            subject = db.query(Subject).filter(Subject.id == source.subject_id).first()
            report = drafts_from_dictionary(db, dictionary, user, subject,
                                            data.academic_year or source.academic_year, source)
        else:
            db.commit()
    except ModerationError as exc:
        db.rollback()
        _raise(exc)
    return {'saved': True, 'source': serialize_source(db, source), 'report': report}


# ---------------------------------------------------------------------------
# Bozze da moderare
# ---------------------------------------------------------------------------

class DraftWrite(BaseModel):
    term: str | None = Field(default=None, max_length=200)
    aliases: list[str] | None = Field(default=None, max_length=10)
    subject_id: int | None = None
    topic_id: int | None = None
    topic_title: str | None = Field(default=None, max_length=200)
    academic_year: str | None = Field(default=None, max_length=20)
    target_entry_id: int | None = None
    assigned_teacher_user_id: int | None = None
    teachers: list[str] | None = Field(default=None, max_length=20)
    content: dict | None = None


class ApproveRequest(BaseModel):
    merge_into_entry_id: int | None = None


class RejectRequest(BaseModel):
    note: str | None = Field(default=None, max_length=1000)


class BulkRequest(BaseModel):
    ids: list[int] = Field(min_length=1, max_length=200)
    action: str = Field(pattern='^(approve|reject)$')
    note: str | None = Field(default=None, max_length=1000)


@router.get('/drafts')
def drafts(subject_id: int | None = None, status: str = Query(default='pending', pattern='^(pending|approved|rejected|all)$'),
           source_id: int | None = None, kind: str | None = Query(default=None, pattern='^(new|update)$'),
           q: str | None = Query(default=None, max_length=200), limit: int = Query(default=100, ge=1, le=500),
           offset: int = Query(default=0, ge=0), current_user: User = Depends(get_current_user),
           db: Session = Depends(get_db)):
    if subject_id is not None:
        try:
            require_moderator(db, current_user, subject_id)
        except ModerationError as exc:
            _raise(exc)
    elif moderable_subject_ids(db, current_user) == set():
        raise HTTPException(403, 'La moderazione è per admin e docenti verificati.')
    return list_drafts(db, current_user, subject_id, status, source_id, kind, q, limit, offset)


@router.get('/drafts/{draft_id}')
def draft(draft_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return draft_detail(db, _draft(db, draft_id, current_user), current_user)


@router.put('/drafts/{draft_id}')
def edit_draft(draft_id: int, data: DraftWrite, current_user: User = Depends(get_current_user),
               db: Session = Depends(get_db)):
    item = _draft(db, draft_id, current_user, lock=True)
    payload = data.model_dump(exclude_unset=True)
    try:
        item = update_draft(db, item, payload, current_user)
    except ModerationError as exc:
        db.rollback()
        _raise(exc)
    return draft_detail(db, item, current_user)


@router.post('/drafts/{draft_id}/approve')
def approve(draft_id: int, data: ApproveRequest, current_user: User = Depends(get_current_user),
            db: Session = Depends(get_db)):
    item = _draft(db, draft_id, current_user, lock=True)
    try:
        return approve_draft(db, item, current_user, data.merge_into_entry_id)
    except ModerationError as exc:
        db.rollback()
        _raise(exc)


@router.post('/drafts/{draft_id}/reject')
def reject(draft_id: int, data: RejectRequest, current_user: User = Depends(get_current_user),
           db: Session = Depends(get_db)):
    item = _draft(db, draft_id, current_user, lock=True)
    try:
        return reject_draft(db, item, current_user, data.note)
    except ModerationError as exc:
        db.rollback()
        _raise(exc)


@router.post('/drafts/bulk')
def bulk(data: BulkRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    done, failed = [], []
    for draft_id in dict.fromkeys(data.ids):
        try:
            item = _draft(db, draft_id, current_user, lock=True)
            if data.action == 'approve':
                approve_draft(db, item, current_user)
            else:
                reject_draft(db, item, current_user, data.note)
            done.append(draft_id)
        except HTTPException as exc:
            db.rollback()
            failed.append({'id': draft_id, 'reason': exc.detail})
        except ModerationError as exc:
            db.rollback()
            failed.append({'id': draft_id, 'reason': exc.message})
    return {'done': done, 'failed': failed}


# ---------------------------------------------------------------------------
# Aiuti per il moderatore
# ---------------------------------------------------------------------------

@router.get('/moderation/teachers')
def moderation_teachers(subject_id: int, current_user: User = Depends(get_current_user),
                        db: Session = Depends(get_db)):
    try:
        require_moderator(db, current_user, subject_id)
    except ModerationError as exc:
        _raise(exc)
    return teachers_for(db, current_user, subject_id)


@router.get('/moderation/question-bank')
def moderation_question_bank(subject_id: int, q: str = Query(default='', max_length=200),
                             current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    try:
        require_moderator(db, current_user, subject_id)
    except ModerationError as exc:
        _raise(exc)
    return question_bank_search(_subject(db, subject_id), q)
