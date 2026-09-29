"""Esercizi dei nuovi tipi, flashcard e banca esercizi (v18).

Studente e ospite: catalogo, esercitazione libera, correzione di un esercizio,
flashcard. Utente registrato: tentativi salvati (come i quiz), esecuzione del
codice, ripetizione dilazionata delle flashcard.
Docente verificato della materia e admin: banca esercizi (crea, modifica,
importa, nascondi, elimina) e anteprima.
"""
from __future__ import annotations

import json
import random
import threading
import time
from copy import deepcopy
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import func
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_current_user, get_optional_current_user
from models.quiz_assignment import QuizAssignment
from models.quiz_attempt import QuizAttempt
from models.subject import Subject
from models.teacher_assignment import TeacherAssignment
from models.user import User
from services import code_runner, exercise_areas, exercise_bank, exercise_items, flashcards
from services.exercise_generators import available as available_generators
from services.exercise_types import TYPES
from services.quiz_attempt_service import _create_quiz_attempt, _is_exercise

router = APIRouter(prefix='/exercises', tags=['exercises'])
question_content_router = APIRouter(prefix='/question-attachments', tags=['question-attachments'])

INLINE_TYPES = {'image/png', 'image/jpeg', 'image/webp', 'application/pdf', 'text/plain'}


# ----------------------------------------------------------------- richieste
class SubjectRef(BaseModel):
    department: str = Field(min_length=1, max_length=100)
    course: str = Field(min_length=1, max_length=100)
    subject: str = Field(min_length=1, max_length=255)


class HistoryEntry(BaseModel):
    """Senza account lo storico è sul telefono: l'app manda solo id, tipo ed esito."""
    id: str = Field(min_length=1, max_length=160)
    type: str | None = Field(default=None, max_length=30)
    score: float | None = Field(default=None, ge=0, le=1)
    correct: bool | None = None
    at: str | None = Field(default=None, max_length=40)


class ChoiceFilters(SubjectRef):
    arguments: list[str] = Field(default_factory=list, max_length=50)
    max_seconds: int | None = Field(default=None, ge=10, le=3600)
    only_new: bool = False
    only_mistakes: bool = False
    history: list[HistoryEntry] = Field(default_factory=list, max_length=3000)


class PracticeRequest(ChoiceFilters):
    types: list[str] = Field(default_factory=list, max_length=13)
    count: int = Field(default=10, ge=1, le=30)
    item_ids: list[str] = Field(default_factory=list, max_length=30)


class StartRequest(PracticeRequest):
    time_limit_seconds: int | None = Field(default=None, gt=0, le=4 * 3600)
    # "Crea un quiz": correzione solo alla consegna (execution_mode = simulation).
    # Resta un quiz personale: non blocca gli esercizi per gli altri studenti.
    quiz: bool = False


def _limit_json(value: Any, limit: int) -> Any:
    if value is not None and len(json.dumps(value, default=str)) > limit:
        raise ValueError('Risposta troppo lunga.')
    return value


class CheckRequest(SubjectRef):
    item_id: str = Field(min_length=3, max_length=160)
    answer: dict[str, Any] = Field(default_factory=dict)
    scope: dict[str, Any] | None = None

    @field_validator('answer')
    @classmethod
    def _answer_size(cls, value):
        return _limit_json(value, 20000)

    @field_validator('scope')
    @classmethod
    def _scope_size(cls, value):
        return _limit_json(value, 500)


class AttemptCheckRequest(BaseModel):
    item_id: str = Field(min_length=3, max_length=160)
    answer: dict[str, Any] = Field(default_factory=dict)
    scope: dict[str, Any] | None = None

    @field_validator('answer')
    @classmethod
    def _answer_size(cls, value):
        return _limit_json(value, 20000)

    @field_validator('scope')
    @classmethod
    def _scope_size(cls, value):
        return _limit_json(value, 500)


class RunRequest(SubjectRef):
    item_id: str = Field(min_length=3, max_length=160)
    code: str = Field(default='', max_length=code_runner.MAX_CODE)


class DeckRequest(SubjectRef):
    arguments: list[str] = Field(default_factory=list, max_length=50)
    limit: int = Field(default=20, ge=1, le=100)


class ReviewRequest(SubjectRef):
    card_id: str = Field(min_length=3, max_length=120)
    grade: int = Field(ge=0, le=3)


class ManageRequest(SubjectRef):
    exercise: dict[str, Any]


class ImportRequest(SubjectRef):
    payload: Any
    dry_run: bool = False


class StatusRequest(BaseModel):
    is_active: bool | None = None
    is_hidden: bool | None = None


# ----------------------------------------------------------------- utilità
def _clean_ref(ref: SubjectRef) -> tuple[str, str, str]:
    values = tuple(v.strip() for v in (ref.department, ref.course, ref.subject))
    for value in values:
        if not value or '..' in value or '/' in value or '\\' in value or '\x00' in value:
            raise HTTPException(400, 'Materia non valida.')
    return values  # type: ignore[return-value]


def _bad(exc: Exception):
    raise HTTPException(status_code=400, detail=str(exc)) from exc


def _subject(db: Session, department: str, course: str, subject: str) -> Subject | None:
    return (db.query(Subject)
            .filter(func.lower(Subject.department_code) == department.lower(),
                    func.lower(Subject.course_code) == course.lower(),
                    func.lower(Subject.name) == subject.lower(),
                    Subject.is_active.is_(True))
            .first())


def _area(db: Session, department: str, course: str, subject: str | None = None) -> dict:
    """Area didattica del corso (tipi di esercizio consigliati). Usa anche i nomi completi
    di dipartimento e corso salvati nella materia, perché i codici da soli dicono poco."""
    record = _subject(db, department, course, subject) if subject else None
    if record is None:
        record = (db.query(Subject)
                  .filter(func.lower(Subject.department_code) == department.lower(),
                          func.lower(Subject.course_code) == course.lower(), Subject.is_active.is_(True))
                  .first())
    return exercise_areas.resolve(department, course,
                                  department_name=getattr(record, 'department', '') or '',
                                  course_name=getattr(record, 'course', '') or '')


def _require_admin(user: User) -> None:
    if (user.role or '').strip().lower() not in {'admin', 'creator'}:
        raise HTTPException(403, 'Solo l’admin può cambiare le aree degli esercizi.')


def _require_manager(db: Session, user: User, department: str, course: str, subject: str) -> Subject:
    """Admin/creator: tutte le materie. Docente: profilo verificato + assegnazione
    corrente e verificata per QUESTA materia (codici dipartimento/corso)."""
    record = _subject(db, department, course, subject)
    if record is None:
        raise HTTPException(404, 'Materia non trovata.')
    role = (user.role or '').strip().lower()
    if role in {'admin', 'creator'}:
        return record
    if role != 'teacher':
        raise HTTPException(403, 'Non puoi gestire gli esercizi.')
    if (user.teacher_verification_status or '').strip().lower() != 'verified':
        raise HTTPException(403, 'Il profilo docente non è verificato.')
    assignment = (db.query(TeacherAssignment)
                  .filter(TeacherAssignment.user_id == user.id, TeacherAssignment.subject_id == record.id,
                          TeacherAssignment.verification_status == 'verified',
                          TeacherAssignment.is_current.is_(True))
                  .first())
    if assignment is None:
        raise HTTPException(403, 'Non sei docente verificato di questa materia.')
    return record


def _name(user: User) -> str:
    return ' '.join(v.strip() for v in (user.first_name or '', user.last_name or '') if v and v.strip()) or 'Docente'


_lock_cache: dict[str, Any] = {'at': 0.0, 'ids': set()}
_lock_guard = threading.Lock()
LOCK_CACHE_SECONDS = 15


def _history(db: Session, user: User | None, request: ChoiceFilters, department: str, course: str,
             subject: str) -> dict:
    if user is not None:
        return exercise_items.user_history(db, user.id, department, course, subject)
    return exercise_items.history_from_rows((h.id, h.type, h.score, h.correct, h.at) for h in request.history)


def _filters(request: ChoiceFilters, history: dict) -> exercise_items.Filters:
    filters = exercise_items.Filters(arguments=request.arguments, max_seconds=request.max_seconds)
    if request.only_mistakes:
        filters.include = set(history['wrong'])
    if request.only_new:
        filters.exclude = set(history['seen'])
    return filters


def _public(item: dict, rng: random.Random) -> dict:
    if item.get('type') == exercise_items.MULTIPLE_CHOICE:
        return exercise_items.public_multiple_choice(item['question'])
    return exercise_items.public_item(item, rng)


def _locked_item_ids(db: Session) -> set[str]:
    """Esercizi della banca che sono in una prova con voto in corso (simulazione o compito
    assegnato): la correzione libera non li rivela e l'esercitazione libera non li propone.
    Per un modello generato si blocca il modello (ex:<id>), quindi tutte le sue varianti."""
    now = time.monotonic()
    with _lock_guard:
        if now - _lock_cache['at'] < LOCK_CACHE_SECONDS:
            return set(_lock_cache['ids'])
    since = datetime.now(timezone.utc) - timedelta(hours=12)
    rows = (db.query(QuizAttempt.question_ids)
            .filter(QuizAttempt.status == 'in_progress', QuizAttempt.is_deleted.is_(False),
                    QuizAttempt.started_at >= since,
                    # solo le prove assegnate: un quiz creato dallo studente non deve poter
                    # bloccare gli esercizi a tutti gli altri
                    QuizAttempt.assignment_id.isnot(None))
            .all())
    locked: set[str] = set()
    for (ids,) in rows:
        for value in ids or []:
            value = str(value)
            if value.startswith('ex:'):
                locked.add(value)
                if value.count(':') == 2:
                    locked.add(value.rsplit(':', 1)[0])
    with _lock_guard:
        _lock_cache.update(at=now, ids=locked)
    return set(locked)


def _is_locked(item_id: str, locked: set[str]) -> bool:
    return item_id in locked or (item_id.count(':') == 2 and item_id.rsplit(':', 1)[0] in locked)


# ----------------------------------------------------------------- studente
@router.get('/types')
def exercise_types():
    return {'types': [{'type': k, **v} for k, v in TYPES.items()], 'generators': available_generators(),
            'code_runner': code_runner.configured()}


@router.get('/areas')
def exercise_areas_config():
    """Aree didattiche: dipartimenti UniCT → area → tipi di esercizio consigliati."""
    return exercise_areas.public_config()


@router.get('/areas/resolve')
def exercise_area_resolve(department: str = Query(min_length=1, max_length=100), course: str = Query(min_length=1, max_length=100),
                          subject: str | None = Query(default=None, max_length=255), db: Session = Depends(get_db)):
    department, course, _ = _clean_ref(SubjectRef(department=department, course=course, subject=subject or 'x'))
    return _area(db, department, course, subject.strip() if subject else None)


@router.put('/areas')
def exercise_areas_save(body: dict[str, Any], user: User = Depends(get_current_user)):
    _require_admin(user)
    if len(json.dumps(body, ensure_ascii=False)) > 200_000:
        raise HTTPException(413, 'Configurazione troppo grande.')
    try:
        exercise_areas.save(body)
    except ValueError as exc:
        _bad(exc)
    return exercise_areas.public_config()


@router.delete('/areas')
def exercise_areas_reset(user: User = Depends(get_current_user)):
    _require_admin(user)
    exercise_areas.reset()
    return exercise_areas.public_config()


@router.post('/catalog')
def exercise_catalog(request: SubjectRef, db: Session = Depends(get_db)):
    department, course, subject = _clean_ref(request)
    try:
        return exercise_items.catalog(db, department, course, subject, code_runner=code_runner.configured())
    except ValueError as exc:
        _bad(exc)


@router.post('/practice')
def exercise_practice(request: PracticeRequest, db: Session = Depends(get_db),
                      user: User | None = Depends(get_optional_current_user)):
    """Esercitazione libera (anche senza account): esercizi senza soluzione.
    Si correggono uno alla volta con /exercises/check."""
    department, course, subject = _clean_ref(request)
    rng = random.Random()
    locked = _locked_item_ids(db)
    try:
        if request.item_ids:
            items = []
            for item_id in request.item_ids:
                if _is_locked(item_id.strip(), locked):
                    continue
                item = exercise_items.resolve(db, department, course, subject, item_id)
                if item is None and item_id.startswith('ex:') and item_id.count(':') == 1:
                    item = exercise_items.resolve(db, department, course, subject,
                                                  f'{item_id}:{rng.randint(1, 2 ** 31 - 2)}')
                if item is not None:
                    items.append(item)
        else:
            history = _history(db, user, request, department, course, subject)
            items = exercise_items.pick(db, department, course, subject, types=request.types or list(TYPES),
                                        arguments=request.arguments, count=request.count, rng=rng,
                                        code_runner=code_runner.configured(), exclude=locked,
                                        filters=_filters(request, history))
    except ValueError as exc:
        _bad(exc)
    if not items:
        raise HTTPException(404, 'Nessun esercizio disponibile con questi filtri.')
    return {'items': [_public(i, rng) for i in items]}


@router.post('/overview')
def exercise_overview(request: ChoiceFilters, db: Session = Depends(get_db),
                      user: User | None = Depends(get_optional_current_user)):
    """Scelta degli esercizi in due passi: l'app manda i filtri e riceve, per ogni tipo di
    esercizio (e per le domande a risposta multipla), quanti ce ne sono, per quali argomenti,
    durata media, difficoltà e com'è andata finora. I conteggi dei filtri servono a mostrare
    accanto a ogni argomento/difficoltà quanti esercizi si otterrebbero."""
    department, course, subject = _clean_ref(request)
    history = _history(db, user, request, department, course, subject)
    filters = exercise_items.Filters(arguments=request.arguments, max_seconds=request.max_seconds,
                                     exclude=_locked_item_ids(db))
    try:
        data = exercise_items.overview(db, department, course, subject, filters=filters,
                                       code_runner=code_runner.configured(), history=history,
                                       only_new=request.only_new, only_mistakes=request.only_mistakes)
    except ValueError as exc:
        _bad(exc)
    data['history_source'] = 'account' if user is not None else ('telefono' if request.history else None)
    area = _area(db, department, course, subject)
    for card in data.get('types') or []:
        card['in_area'] = card.get('type') in area['types']
    data['area'] = area
    return data


@router.post('/check')
def exercise_check(request: CheckRequest, db: Session = Depends(get_db),
                   user: User | None = Depends(get_optional_current_user)):
    department, course, subject = _clean_ref(request)
    item_id = request.item_id.strip()
    if _is_locked(item_id, _locked_item_ids(db)):
        raise HTTPException(409, 'Questo esercizio è in una prova in corso: la correzione arriva alla consegna.')
    item = exercise_items.resolve(db, department, course, subject, item_id)
    if item is None:
        raise HTTPException(404, 'Esercizio non disponibile.')
    run = None
    if item['type'] == 'codice':
        if user is None:
            raise HTTPException(401, 'Accedi per far eseguire il codice.')
        if code_runner.rate_limited(user.id):
            raise HTTPException(429, 'Hai eseguito molto codice di recente: riprova tra qualche minuto.')
        run = code_runner.run_tests(item['data'], str(request.answer.get('code') or ''), include_hidden=True)
    return _part_only(exercise_items.grade_item(item, request.answer, request.scope, run=run), request.scope)


def _part_only(result: dict, scope: Any) -> dict:
    """Controllo di una parte (riga di Traccia, passo di un Caso): niente spiegazione né soluzione."""
    if scope:
        result['explanation'] = ''
        result['solution_text'] = ''
        result['correct_payload'] = None
    return result


@router.post('/run')
def exercise_run(request: RunRequest, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    """Pulsante "Esegui": solo i test visibili, nessun voto."""
    department, course, subject = _clean_ref(request)
    item = exercise_items.resolve(db, department, course, subject, request.item_id)
    if item is None or item['type'] != 'codice':
        raise HTTPException(404, 'Esercizio di codice non disponibile.')
    if code_runner.rate_limited(user.id):
        raise HTTPException(429, 'Hai eseguito molto codice di recente: riprova tra qualche minuto.')
    return code_runner.run_tests(item['data'], request.code, include_hidden=False)


@router.post('/start')
def exercise_start(request: StartRequest, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    """Esercitazione salvata nello storico (come un quiz): si consegna con
    POST /quiz-attempts/{id}/complete mandando answer_payload per ogni esercizio."""
    department, course, subject = _clean_ref(request)
    rng = random.Random()
    # Le flashcard sono autovalutazione: si ripassano da /flashcards, non entrano nello storico.
    types = [t for t in (request.types or list(TYPES)) if t != 'flashcard']
    try:
        history = _history(db, user, request, department, course, subject)
        items = exercise_items.pick(db, department, course, subject, types=types,
                                    arguments=request.arguments, count=request.count, rng=rng,
                                    code_runner=code_runner.configured(), exclude=_locked_item_ids(db),
                                    filters=_filters(request, history))
        if not items:
            raise ValueError('Nessun esercizio disponibile con questi filtri.')
        # le domande a risposta multipla entrano nello snapshot come nei quiz di sempre
        questions = [i['question'] if i.get('type') == exercise_items.MULTIPLE_CHOICE else exercise_items.snapshot(i, rng)
                     for i in items]
        return _create_quiz_attempt(db, user, department=department, course=course, subject=subject,
                                    questions=questions, time_limit_seconds=request.time_limit_seconds,
                                    execution_mode='simulation' if request.quiz else 'practice')
    except ValueError as exc:
        _bad(exc)


def _without_solution(kind: str, result: dict) -> dict:
    """Esito di un tentativo intermedio: dice cosa è giusto, non qual è la risposta giusta."""
    result = deepcopy(result)
    result['correct_payload'] = None
    result['solution_text'] = ''
    result['explanation'] = ''
    feedback = result.get('feedback') or {}
    if kind == 'scelta':
        chosen = set(feedback.get('selected') or [])
        feedback.pop('missed', None)
        feedback['explanations'] = {k: v for k, v in (feedback.get('explanations') or {}).items() if k in chosen}
    elif kind == 'diagramma':
        chosen = set(feedback.get('chosen') or [])
        feedback['notes'] = {k: v for k, v in (feedback.get('notes') or {}).items() if k in chosen}
    elif kind == 'caso':
        feedback.pop('notes', None)          # le note dei passi spiegano la risposta giusta
    elif kind in ('vero_falso', 'categorizza'):
        # con due sole scelte (vero/falso, due categorie) dire cosa è sbagliato direbbe la risposta:
        # nei tentativi intermedi resta solo il punteggio
        feedback.pop('explanations', None)
        feedback.pop('claims', None)
        feedback.pop('items', None)
    result['feedback'] = feedback
    return result


@router.post('/attempts/{attempt_id}/check')
def attempt_check(attempt_id: int, request: AttemptCheckRequest, db: Session = Depends(get_db),
                  user: User = Depends(get_current_user)):
    """Controllo di un esercizio DENTRO un tentativo salvato (esercitazione o compito assegnato
    in modalità esercitazione). Il server conta i tentativi: nei compiti assegnati la soluzione
    si vede solo a risposta giusta o a tentativi finiti, e da lì la risposta resta quella."""
    attempt = (db.query(QuizAttempt).filter(QuizAttempt.id == attempt_id).with_for_update().first())
    if attempt is None or attempt.is_deleted or attempt.user_id != user.id:
        raise HTTPException(404, 'Tentativo non trovato.')
    if attempt.status != 'in_progress':
        raise HTTPException(409, 'Questo tentativo è già stato consegnato.')
    if attempt.execution_mode == 'simulation':
        raise HTTPException(409, 'In simulazione la correzione arriva alla consegna.')
    snapshots = list(attempt.questions_snapshot or [])
    index = next((i for i, q in enumerate(snapshots) if isinstance(q, dict)
                  and str(q.get('id_question')) == request.item_id.strip() and _is_exercise(q)), None)
    if index is None:
        raise HTTPException(404, 'Esercizio non presente in questo tentativo.')
    snap = dict(snapshots[index])
    item = exercise_items.item_from_snapshot(snap)
    if item['type'] == 'flashcard':
        raise HTTPException(400, 'Le flashcard non si correggono.')
    limit = None
    if attempt.assignment_id is not None:
        assignment = db.query(QuizAssignment).filter(QuizAssignment.id == attempt.assignment_id).first()
        limit = (assignment.attempts_per_item if assignment is not None else None) or 2
    state = dict(snap.get('_checks') or {})
    if state.get('final'):
        return {**state['final']['result'], 'tries': state.get('tries', 0), 'max_tries': limit, 'final': True}
    if request.scope:
        # controllo di una riga (Traccia): nei compiti assegnati la tabella si consegna intera
        if limit is not None:
            raise HTTPException(409, 'In un compito assegnato la tabella si controlla tutta insieme.')
        return _part_only(exercise_items.grade_item(item, request.answer, request.scope), request.scope)
    run = None
    if item['type'] == 'codice':
        if code_runner.rate_limited(user.id):
            raise HTTPException(429, 'Hai eseguito molto codice di recente: riprova tra qualche minuto.')
        run = code_runner.run_tests(item['data'], str(request.answer.get('code') or ''), include_hidden=True)
    result = exercise_items.grade_item(item, request.answer, None, run=run)
    tries = int(state.get('tries') or 0) + 1
    final = bool(result.get('is_correct')) or (limit is not None and tries >= limit)
    state['tries'] = tries
    if final:
        answer = dict(request.answer)
        if run is not None:
            answer['_run'] = run          # la consegna non riesegue il codice
        state['final'] = {'answer': answer, 'result': result}
    snap['_checks'] = state
    snapshots[index] = snap
    attempt.questions_snapshot = snapshots        # nuova lista: SQLAlchemy registra la modifica
    db.commit()
    shown = result if (final or limit is None) else _without_solution(item['type'], result)
    return {**shown, 'tries': tries, 'max_tries': limit, 'final': final}


@router.get('/attachments/{department}/{course}/{subject}/{item_id}/{attachment_id}')
async def exercise_attachment(department: str, course: str, subject: str, item_id: str, attachment_id: str,
                              db: Session = Depends(get_db)):
    """Allegato di un esercizio disponibile (immagine, PDF, testo, DOCX, PPTX).
    Il percorso nello storage si legge dal file della banca, mai dalla richiesta."""
    from services.private_blob import private_blob_response
    ref = SubjectRef(department=department, course=course, subject=subject)
    department, course, subject = _clean_ref(ref)
    item = exercise_items.resolve(db, department, course, subject, item_id)
    if item is None:
        raise HTTPException(404, 'Allegato non disponibile.')
    attachment = next((a for a in item.get('attachments') or [] if a.get('id') == attachment_id), None)
    if attachment is None or not attachment.get('stored_name') or attachment.get('role') == 'solution':
        raise HTTPException(404, 'Allegato non disponibile.')
    return await private_blob_response(stored_name=attachment['stored_name'],
                                       original_name=attachment.get('original_name') or 'allegato',
                                       mime_type=attachment.get('mime_type') or 'application/octet-stream',
                                       inline=attachment.get('mime_type') in INLINE_TYPES)


@question_content_router.get('/content/{department}/{course}/{subject}/{question_id}/{attachment_id}')
async def question_attachment_content(department: str, course: str, subject: str, question_id: str,
                                      attachment_id: str):
    """Allegati delle domande a risposta multipla (usato dall'app: QuestionAttachmentApiService).
    Registrato solo se la tua versione non ha già questa route."""
    from services.private_blob import private_blob_response
    from services.quiz_service import find_question
    ref = SubjectRef(department=department, course=course, subject=subject)
    department, course, subject = _clean_ref(ref)
    question = find_question(id_question=question_id, department=department, course=course, subject=subject)
    if question is None:
        raise HTTPException(404, 'Allegato non disponibile.')
    attachment = next((a for a in question.get('attachments') or []
                       if isinstance(a, dict) and str(a.get('id')) == attachment_id), None)
    if attachment is None or not attachment.get('stored_name'):
        raise HTTPException(404, 'Allegato non disponibile.')
    mime = str(attachment.get('mime_type') or 'application/octet-stream')
    return await private_blob_response(stored_name=str(attachment['stored_name']),
                                       original_name=str(attachment.get('original_name') or 'allegato'),
                                       mime_type=mime, inline=mime in INLINE_TYPES)


# ----------------------------------------------------------------- flashcard
@router.post('/flashcards/deck')
def flashcard_deck(request: DeckRequest, db: Session = Depends(get_db),
                   user: User | None = Depends(get_optional_current_user)):
    """Senza account: le schede (la programmazione resta sul telefono).
    Con account: prima le schede scadute, poi le nuove, con lo stato di ognuna."""
    department, course, subject = _clean_ref(request)
    cards = exercise_items.dictionary_flashcards(db, department, course, subject, request.arguments)
    if user is None:
        random.shuffle(cards)
        return {'cards': [exercise_items.public_item(c) for c in cards[:request.limit]], 'synced': False,
                'total': len(cards)}
    state = flashcards.states(db, user.id, department, course, subject)
    ordered = flashcards.due_order(cards, state, request.limit)
    return {'cards': [{**exercise_items.public_item(c), 'state': flashcards.serialize_state(state.get(c['id']))}
                      for c in ordered],
            'synced': True, 'total': len(cards),
            'due': flashcards.count_due(state),
            'new': sum(1 for c in cards if c['id'] not in state)}


@router.post('/flashcards/review')
def flashcard_review(request: ReviewRequest, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    department, course, subject = _clean_ref(request)
    item = exercise_items.resolve(db, department, course, subject, request.card_id)
    if item is None or item['type'] != 'flashcard':
        raise HTTPException(404, 'Scheda non disponibile.')
    row = flashcards.review(db, user.id, department=department, course=course, subject=subject,
                            card_id=item['id'], grade=request.grade, argument=item.get('argument'))
    return {'card_id': item['id'], 'state': flashcards.serialize_state(row)}


# ----------------------------------------------------------------- banca esercizi
@router.get('/subjects')
def manageable_subjects(q: str | None = Query(default=None, max_length=100), db: Session = Depends(get_db),
                        user: User = Depends(get_current_user)):
    """Materie in cui l'utente può gestire e assegnare esercizi (admin: tutte)."""
    role = (user.role or '').strip().lower()
    query = db.query(Subject).filter(Subject.is_active.is_(True))
    if role not in {'admin', 'creator'}:
        if role != 'teacher' or (user.teacher_verification_status or '').strip().lower() != 'verified':
            return []
        query = (query.join(TeacherAssignment, TeacherAssignment.subject_id == Subject.id)
                 .filter(TeacherAssignment.user_id == user.id, TeacherAssignment.verification_status == 'verified',
                         TeacherAssignment.is_current.is_(True)))
    if q and q.strip():
        query = query.filter(func.lower(Subject.name).like(f'%{q.strip().lower()}%'))
    rows = query.order_by(Subject.name).limit(300).all()
    return [{'id': s.id, 'name': s.name, 'department': s.department, 'department_code': s.department_code,
             'course': s.course, 'course_code': s.course_code, 'university': getattr(s, 'university', None),
             'university_code': getattr(s, 'university_code', None)}
            for s in rows if s.department_code and s.course_code]


@router.get('/generators')
def generators():
    return available_generators()


@router.get('/manage')
def manage_list(department: str, course: str, subject: str, type: str | None = None, argument: str | None = None,
                q: str | None = Query(default=None, max_length=200), db: Session = Depends(get_db),
                user: User = Depends(get_current_user)):
    department, course, subject = _clean_ref(SubjectRef(department=department, course=course, subject=subject))
    _require_manager(db, user, department, course, subject)
    try:
        items = exercise_bank.list_for_management(department, course, subject, kind=type, argument=argument, q=q)
    except ValueError as exc:
        _bad(exc)
    return {'items': items, 'arguments': exercise_bank.arguments(department, course, subject),
            'code_runner': code_runner.configured(), 'area': _area(db, department, course, subject)}


@router.post('/manage/preview')
def manage_preview(request: ManageRequest, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    """Valida senza salvare e mostra l'esercizio come lo vedrà lo studente."""
    department, course, subject = _clean_ref(request)
    _require_manager(db, user, department, course, subject)
    try:
        record = exercise_bank.clean_record(request.exercise, department=department, course=course,
                                            subject=subject, actor_id=user.id, actor_name=_name(user))
        record['id_exercise'] = 'anteprima'
        item = exercise_items.item_from_record(record)
    except (ValueError, TypeError) as exc:
        _bad(exc)
    return {'item': exercise_items.public_item(item), 'solution': exercise_items.types_.solution_summary(
        item['type'], item['data'])}


@router.post('/manage')
def manage_create(request: ManageRequest, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    department, course, subject = _clean_ref(request)
    _require_manager(db, user, department, course, subject)
    try:
        return exercise_bank.create_exercise(department, course, subject, request.exercise, actor_id=user.id,
                                             actor_name=_name(user))
    except (ValueError, TypeError) as exc:
        _bad(exc)


@router.post('/manage/import')
def manage_import(request: ImportRequest, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    department, course, subject = _clean_ref(request)
    _require_manager(db, user, department, course, subject)
    try:
        return exercise_bank.import_exercises(department, course, subject, request.payload, actor_id=user.id,
                                              actor_name=_name(user), dry_run=request.dry_run)
    except (ValueError, TypeError) as exc:
        _bad(exc)


@router.get('/manage/{department}/{course}/{subject}/{exercise_id}')
def manage_get(department: str, course: str, subject: str, exercise_id: str, db: Session = Depends(get_db),
               user: User = Depends(get_current_user)):
    department, course, subject = _clean_ref(SubjectRef(department=department, course=course, subject=subject))
    _require_manager(db, user, department, course, subject)
    record = exercise_bank.get_exercise(department, course, subject, exercise_id)
    if record is None:
        raise HTTPException(404, 'Esercizio non trovato.')
    return record


@router.put('/manage/{department}/{course}/{subject}/{exercise_id}')
def manage_update(department: str, course: str, subject: str, exercise_id: str, body: dict[str, Any],
                  db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    department, course, subject = _clean_ref(SubjectRef(department=department, course=course, subject=subject))
    _require_manager(db, user, department, course, subject)
    try:
        return exercise_bank.update_exercise(department, course, subject, exercise_id, body, actor_id=user.id,
                                             actor_name=_name(user))
    except (ValueError, TypeError) as exc:
        _bad(exc)


@router.post('/manage/{department}/{course}/{subject}/{exercise_id}/status')
def manage_status(department: str, course: str, subject: str, exercise_id: str, body: StatusRequest,
                  db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    department, course, subject = _clean_ref(SubjectRef(department=department, course=course, subject=subject))
    _require_manager(db, user, department, course, subject)
    try:
        return exercise_bank.set_status(department, course, subject, exercise_id, is_active=body.is_active,
                                        is_hidden=body.is_hidden, actor_name=_name(user))
    except ValueError as exc:
        _bad(exc)


@router.delete('/manage/{department}/{course}/{subject}/{exercise_id}')
def manage_delete(department: str, course: str, subject: str, exercise_id: str, db: Session = Depends(get_db),
                  user: User = Depends(get_current_user)):
    department, course, subject = _clean_ref(SubjectRef(department=department, course=course, subject=subject))
    _require_manager(db, user, department, course, subject)
    try:
        removed = exercise_bank.delete_exercise(department, course, subject, exercise_id)
    except ValueError as exc:
        _bad(exc)
    # Si eliminano dallo storage solo i file che nessun altro esercizio usa.
    try:
        from services.private_blob import delete_private_blob_sync
        in_use = exercise_bank.stored_names_in_use(department, course, subject)
        for attachment in removed.get('attachments') or []:
            stored = attachment.get('stored_name')
            if stored and stored not in in_use and stored.startswith('questions/tmp/'):
                delete_private_blob_sync(stored)
    except Exception:
        pass
    return {'success': True, 'message': 'Esercizio eliminato.'}
