"""Domande degli studenti (FAQ universitaria).

Visibili a tutti (anche ospiti) solo i contenuti approvati. Domande, risposte
e racconti d'esame nascono "in attesa" e li approva un admin. Le risposte si
possono dare anche da ospite, con testo e un file o un materiale delle Dispense.
"""
import hashlib
import json
from datetime import date, timedelta

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, Request, UploadFile
from pydantic import BaseModel, Field
from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_admin_user, get_current_user, get_optional_current_user
from models.faq import FAQ_CATEGORIES, FaqAnswer, FaqExamReport, FaqQuestion, FaqVote, utc_now
from models.public_material import PublicMaterial
from models.subject import Subject
from models.user import User
from services.faq import (author_role, check_file, display_name, guest_hash, is_admin, my_votes, notify,
                          refresh_question_counters, search_words, serialize_answer, serialize_question,
                          store_answer_file, student_label, teachers_of_subject)
from services.private_blob import private_blob_response
from services.public_material_access import can_read_public_material
from services.news_filter_scope import COURSES, code as academic_code, matches as academic_matches

router = APIRouter(prefix='/faq', tags=['faq'])

GUEST_ANSWERS_PER_HOUR = 5
USER_ANSWERS_PER_HOUR = 20


class QuestionCreate(BaseModel):
    title: str = Field(min_length=8, max_length=200)
    body: str | None = Field(default=None, max_length=5000)
    category: str = 'other'
    subject_id: int | None = None
    university: str | None = Field(default=None, max_length=255)
    department: str | None = Field(default=None, max_length=255)
    course: str | None = Field(default=None, max_length=255)
    is_anonymous: bool = True
    ask_teacher: bool = False


class VoteRequest(BaseModel):
    kind: str = Field(pattern='^(useful|same_doubt)$')


class AcceptRequest(BaseModel):
    answer_id: int | None = None


class ExamReportCreate(BaseModel):
    subject_id: int
    exam_date: date
    exam_format: str = Field(pattern='^(scritto|orale|scritto_orale|progetto)$')
    duration_minutes: int | None = Field(default=None, ge=5, le=600)
    difficulty: int = Field(ge=1, le=5)
    topics: list[str] = Field(default_factory=list, max_length=10)
    body: str | None = Field(default=None, max_length=3000)
    is_anonymous: bool = True


class ModerationRequest(BaseModel):
    action: str = Field(pattern='^(approve|reject|remove)$')
    note: str | None = Field(default=None, max_length=1000)


# ---------------------------------------------------------------------------
# Filtri e ricerca (come le Dispense: ateneo, dipartimento, corso, materia)
# ---------------------------------------------------------------------------

@router.get('/filters')
def faq_filters(db: Session = Depends(get_db)):
    subjects = db.query(Subject).filter(Subject.is_active.is_(True)).order_by(
        Subject.university, Subject.department, Subject.course, Subject.name).all()
    return [{'id': s.id, 'name': s.name, 'university': s.university, 'university_code': s.university_code,
             'department': s.department, 'department_code': s.department_code,
             'course': faq_course_label(s.course)}
            for s in subjects]


def faq_course_label(value: str | None) -> str | None:
    """Collapse only known equivalent programme names for filter display."""
    known = academic_code(value, 'course') if value else None
    return COURSES[known][1][0] if known else value


def _apply_context(query, university, department, course, subject_id):
    if subject_id:
        return query.filter(FaqQuestion.subject_id == subject_id)
    if university:
        query = query.filter(academic_matches(FaqQuestion.university, FaqQuestion.university,
                                               university, 'university'))
    if department:
        query = query.filter(academic_matches(FaqQuestion.department, FaqQuestion.department,
                                               department, 'department'))
    if course:
        known = academic_code(course, 'course')
        if known:
            aliases = (known, *COURSES[known][1])
            query = query.filter(or_(*(FaqQuestion.course.ilike(alias) for alias in aliases)))
        else:
            query = query.filter(FaqQuestion.course == course)
    return query


@router.get('/questions')
def list_questions(university: str | None = None, department: str | None = None, course: str | None = None,
                   subject_id: int | None = None, category: str | None = None,
                   q: str = Query(default='', max_length=200),
                   view: str = Query(default='all', pattern='^(all|unanswered|verified|mine)$'),
                   sort: str = Query(default='useful', pattern='^(useful|recent)$'),
                   limit: int = Query(default=30, ge=1, le=100), offset: int = Query(default=0, ge=0),
                   viewer: User | None = Depends(get_optional_current_user), db: Session = Depends(get_db)):
    if view == 'mine':
        if viewer is None:
            raise HTTPException(401, 'Accedi per vedere le tue domande.')
        query = db.query(FaqQuestion).filter(FaqQuestion.author_user_id == viewer.id,
                                             FaqQuestion.status != 'removed')
    else:
        query = db.query(FaqQuestion).filter(FaqQuestion.status == 'published')
        query = _apply_context(query, university, department, course, subject_id)
        if view == 'unanswered':
            query = query.filter(FaqQuestion.answers_count == 0)
        elif view == 'verified':
            query = query.filter(FaqQuestion.has_verified_answer.is_(True))
    if category and category in FAQ_CATEGORIES:
        query = query.filter(FaqQuestion.category == category)
    for word in search_words(q):
        like = f'%{word}%'
        query = query.filter(or_(func.lower(FaqQuestion.title).like(like),
                                 func.lower(func.coalesce(FaqQuestion.body, '')).like(like)))
    order = ([FaqQuestion.useful_count.desc(), FaqQuestion.same_doubt_count.desc(), FaqQuestion.created_at.desc()]
             if sort == 'useful' else [FaqQuestion.created_at.desc()])
    total = query.count()
    rows = query.order_by(*order).offset(offset).limit(limit).all()
    votes = my_votes(db, viewer, 'question', [r.id for r in rows])
    return {'total': total, 'items': [serialize_question(db, r, viewer, votes.get(r.id)) for r in rows]}


@router.get('/suggestions')
def question_suggestions(q: str = Query(default='', max_length=200), subject_id: int | None = None,
                         db: Session = Depends(get_db)):
    """"Forse ha già una risposta": domande approvate simili (massimo 5)."""
    words = search_words(q)
    if not words:
        return []
    query = db.query(FaqQuestion).filter(FaqQuestion.status == 'published')
    if subject_id:
        query = query.filter(FaqQuestion.subject_id == subject_id)
    rows = query.order_by(FaqQuestion.useful_count.desc()).limit(300).all()
    scored = []
    for row in rows:
        text = f'{row.title} {row.body or ""}'.casefold()
        score = sum(1 for w in words if w in text)
        if score:
            scored.append((score, row))
    scored.sort(key=lambda item: (-item[0], -item[1].useful_count))
    return [{'id': r.id, 'title': r.title, 'answers_count': r.answers_count,
             'has_verified_answer': r.has_verified_answer} for _, r in scored[:5]]


# ---------------------------------------------------------------------------
# Dettaglio, creazione, voti, risposta accettata
# ---------------------------------------------------------------------------

@router.get('/questions/{question_id}')
def question_detail(question_id: int, guest_key: str | None = Query(default=None, max_length=128),
                    viewer: User | None = Depends(get_optional_current_user), db: Session = Depends(get_db)):
    question = db.query(FaqQuestion).filter(FaqQuestion.id == question_id).first()
    mine = viewer is not None and question is not None and question.author_user_id == viewer.id
    if question is None or (question.status != 'published' and not mine and not is_admin(viewer)):
        raise HTTPException(404, 'Domanda non trovata.')
    key_hash = guest_hash(guest_key)
    answers = db.query(FaqAnswer).filter(FaqAnswer.question_id == question.id,
                                         FaqAnswer.status.in_(('published', 'pending', 'rejected'))).all()
    visible = [a for a in answers if a.status == 'published'
               or (viewer is not None and a.author_user_id == viewer.id)
               or (key_hash is not None and a.guest_key_hash == key_hash)]
    visible.sort(key=lambda a: (not a.is_accepted, not a.is_verified, -a.useful_count, a.created_at))
    q_votes = my_votes(db, viewer, 'question', [question.id]).get(question.id)
    a_votes = my_votes(db, viewer, 'answer', [a.id for a in visible])
    return {'question': serialize_question(db, question, viewer, q_votes),
            'answers': [serialize_answer(db, a, viewer, a_votes.get(a.id), key_hash) for a in visible]}


@router.post('/questions')
def create_question(data: QuestionCreate, current_user: User = Depends(get_current_user),
                    db: Session = Depends(get_db)):
    category = data.category if data.category in FAQ_CATEGORIES else 'other'
    university, department, course = data.university, data.department, data.course
    if data.subject_id is not None:
        subject = db.query(Subject).filter(Subject.id == data.subject_id, Subject.is_active.is_(True)).first()
        if subject is None:
            raise HTTPException(400, 'Materia non trovata.')
        university, department, course = subject.university, subject.department, subject.course
    recent = db.query(FaqQuestion).filter(FaqQuestion.author_user_id == current_user.id,
        FaqQuestion.created_at >= utc_now() - timedelta(hours=1)).count()
    if recent >= 10:
        raise HTTPException(429, 'Hai fatto molte domande nell’ultima ora: riprova più tardi.')
    question = FaqQuestion(author_user_id=current_user.id, university=university, department=department,
        course=course, subject_id=data.subject_id, category=category, title=data.title.strip(),
        body=(data.body or '').strip() or None, is_anonymous=data.is_anonymous,
        author_label=student_label(db, current_user),
        ask_teacher=bool(data.ask_teacher and data.subject_id is not None), status='pending')
    db.add(question)
    db.commit()
    db.refresh(question)
    return serialize_question(db, question, current_user)


def _toggle_vote(db: Session, user_id: int, target_type: str, target_id: int, kind: str):
    existing = db.query(FaqVote).filter(FaqVote.user_id == user_id, FaqVote.target_type == target_type,
                                        FaqVote.target_id == target_id, FaqVote.kind == kind).first()
    if existing is not None:
        db.delete(existing)
    else:
        db.add(FaqVote(user_id=user_id, target_type=target_type, target_id=target_id, kind=kind))
    db.flush()


def _count(db: Session, target_type: str, target_id: int, kind: str) -> int:
    return db.query(FaqVote).filter(FaqVote.target_type == target_type, FaqVote.target_id == target_id,
                                    FaqVote.kind == kind).count()


@router.post('/questions/{question_id}/votes')
def vote_question(question_id: int, data: VoteRequest, current_user: User = Depends(get_current_user),
                  db: Session = Depends(get_db)):
    question = db.query(FaqQuestion).filter(FaqQuestion.id == question_id,
                                            FaqQuestion.status == 'published').with_for_update().first()
    if question is None:
        raise HTTPException(404, 'Domanda non trovata.')
    _toggle_vote(db, current_user.id, 'question', question.id, data.kind)
    question.useful_count = _count(db, 'question', question.id, 'useful')
    question.same_doubt_count = _count(db, 'question', question.id, 'same_doubt')
    db.commit()
    votes = my_votes(db, current_user, 'question', [question.id]).get(question.id)
    return serialize_question(db, question, current_user, votes)


@router.post('/answers/{answer_id}/votes')
def vote_answer(answer_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    answer = db.query(FaqAnswer).filter(FaqAnswer.id == answer_id,
                                        FaqAnswer.status == 'published').with_for_update().first()
    if answer is None:
        raise HTTPException(404, 'Risposta non trovata.')
    _toggle_vote(db, current_user.id, 'answer', answer.id, 'useful')
    answer.useful_count = _count(db, 'answer', answer.id, 'useful')
    db.commit()
    votes = my_votes(db, current_user, 'answer', [answer.id]).get(answer.id)
    return serialize_answer(db, answer, current_user, votes)


@router.post('/questions/{question_id}/accept')
def accept_answer(question_id: int, data: AcceptRequest, current_user: User = Depends(get_current_user),
                  db: Session = Depends(get_db)):
    """Chi ha fatto la domanda sceglie la risposta che l'ha aiutato."""
    question = db.query(FaqQuestion).filter(FaqQuestion.id == question_id).with_for_update().first()
    if question is None or question.author_user_id != current_user.id:
        raise HTTPException(403, 'Solo chi ha fatto la domanda può scegliere la risposta.')
    if data.answer_id is not None and not db.query(FaqAnswer.id).filter(FaqAnswer.id == data.answer_id,
            FaqAnswer.question_id == question.id, FaqAnswer.status == 'published').first():
        raise HTTPException(400, 'Risposta non valida.')
    for answer in db.query(FaqAnswer).filter(FaqAnswer.question_id == question.id).all():
        answer.is_accepted = data.answer_id is not None and answer.id == data.answer_id
    question.accepted_answer_id = data.answer_id
    db.commit()
    return {'accepted_answer_id': question.accepted_answer_id}


# ---------------------------------------------------------------------------
# Risposte (anche da ospite), con testo e file o materiale delle Dispense
# ---------------------------------------------------------------------------

def _client_ip(request: Request) -> str:
    forwarded = request.headers.get('x-forwarded-for', '')
    return (forwarded.split(',')[0].strip() if forwarded else '') or (request.client.host if request.client else '')


@router.post('/questions/{question_id}/answers')
async def create_answer(question_id: int, request: Request,
                        body: str = Form(..., min_length=2, max_length=5000),
                        guest_name: str | None = Form(default=None, max_length=60),
                        guest_key: str | None = Form(default=None, max_length=128),
                        public_material_id: int | None = Form(default=None),
                        file: UploadFile | None = File(default=None),
                        viewer: User | None = Depends(get_optional_current_user), db: Session = Depends(get_db)):
    question = db.query(FaqQuestion).filter(FaqQuestion.id == question_id,
                                            FaqQuestion.status == 'published').first()
    if question is None:
        raise HTTPException(404, 'Domanda non trovata.')
    guest = viewer is None
    if guest and (not guest_key or len(guest_key) < 16):
        raise HTTPException(400, 'Identificativo del dispositivo mancante.')
    ip_hash = guest_hash(_client_ip(request)) if guest else None
    since = utc_now() - timedelta(hours=1)
    if guest:
        recent = db.query(FaqAnswer).filter(FaqAnswer.guest_ip_hash == ip_hash, FaqAnswer.created_at >= since).count()
        if recent >= GUEST_ANSWERS_PER_HOUR:
            raise HTTPException(429, 'Troppe risposte da questo dispositivo: riprova più tardi o accedi.')
    else:
        recent = db.query(FaqAnswer).filter(FaqAnswer.author_user_id == viewer.id, FaqAnswer.created_at >= since).count()
        if recent >= USER_ANSWERS_PER_HOUR:
            raise HTTPException(429, 'Hai risposto molte volte nell’ultima ora: riprova più tardi.')
    material_id = None
    if public_material_id is not None:
        material = db.query(PublicMaterial).filter(PublicMaterial.id == public_material_id,
                                                   PublicMaterial.status == 'published').first()
        if material is None or not can_read_public_material(db, material, viewer.id if viewer else None):
            raise HTTPException(400, 'Il materiale scelto non è disponibile.')
        material_id = material.id
    stored = original = mime = digest = None
    size = None
    if file is not None and (file.filename or '').strip():
        try:
            content = await file.read(4 * 1024 * 1024 + 1)
        finally:
            await file.close()
        try:
            extension, mime = check_file(file.filename, content, guest)
        except ValueError as exc:
            raise HTTPException(400, str(exc)) from exc
        digest = hashlib.sha256(content).hexdigest()
        stored = await store_answer_file(content, extension, mime)
        original, size = file.filename.strip()[:255], len(content)
    role = author_role(db, viewer, question.subject_id)
    answer = FaqAnswer(question_id=question.id, author_user_id=viewer.id if viewer else None,
        guest_name=((guest_name or '').strip()[:60] or None) if guest else None,
        guest_key_hash=guest_hash(guest_key) if guest else None, guest_ip_hash=ip_hash,
        author_role=role, body=body.strip(), public_material_id=material_id, file_stored_name=stored,
        file_original_name=original, file_mime_type=mime, file_size=size, file_hash=digest,
        is_verified=role in ('teacher', 'studentlab'), status='pending')
    db.add(answer)
    db.commit()
    db.refresh(answer)
    return serialize_answer(db, answer, viewer, None, guest_hash(guest_key) if guest else None)


@router.get('/answers/{answer_id}/file')
async def answer_file(answer_id: int, viewer: User | None = Depends(get_optional_current_user),
                      db: Session = Depends(get_db)):
    answer = db.query(FaqAnswer).filter(FaqAnswer.id == answer_id).first()
    if answer is None or not answer.file_stored_name:
        raise HTTPException(404, 'File non trovato.')
    # Prima dell'approvazione il file lo vede solo chi modera.
    if answer.status != 'published' and not is_admin(viewer):
        raise HTTPException(404, 'File non ancora disponibile.')
    return await private_blob_response(stored_name=answer.file_stored_name,
        original_name=answer.file_original_name or 'allegato',
        mime_type=answer.file_mime_type or 'application/octet-stream')


# ---------------------------------------------------------------------------
# Com'è l'esame
# ---------------------------------------------------------------------------

@router.get('/exam')
def exam_summary(subject_id: int, viewer: User | None = Depends(get_optional_current_user),
                 db: Session = Depends(get_db)):
    subject = db.query(Subject).filter(Subject.id == subject_id).first()
    if subject is None:
        raise HTTPException(404, 'Materia non trovata.')
    since = date.today() - timedelta(days=3 * 365)
    reports = db.query(FaqExamReport).filter(FaqExamReport.subject_id == subject_id,
        FaqExamReport.status == 'published', FaqExamReport.exam_date >= since).order_by(
        FaqExamReport.exam_date.desc()).all()
    topics: dict[str, int] = {}
    labels: dict[str, str] = {}
    formats: dict[str, int] = {}
    for report in reports:
        formats[report.exam_format] = formats.get(report.exam_format, 0) + 1
        for topic in json.loads(report.topics_json or '[]'):
            key = topic.strip().casefold()
            if key:
                topics[key] = topics.get(key, 0) + 1
                labels.setdefault(key, topic.strip())
    top = sorted(topics.items(), key=lambda item: -item[1])[:8]
    durations = [r.duration_minutes for r in reports if r.duration_minutes]
    teacher_names = []
    for teacher_id in teachers_of_subject(db, subject.id):
        teacher = db.query(User).filter(User.id == teacher_id).first()
        if teacher is not None:
            teacher_names.append(display_name(teacher))
    mine_pending = 0
    if viewer is not None:
        mine_pending = db.query(FaqExamReport).filter(FaqExamReport.subject_id == subject_id,
            FaqExamReport.author_user_id == viewer.id, FaqExamReport.status == 'pending').count()
    return {
        'subject': {'id': subject.id, 'name': subject.name, 'course': subject.course},
        'teachers': teacher_names,
        'reports_count': len(reports),
        'main_format': max(formats, key=formats.get) if formats else None,
        'average_duration': round(sum(durations) / len(durations)) if durations else None,
        'average_difficulty': round(sum(r.difficulty for r in reports) / len(reports), 1) if reports else None,
        'topics': [{'label': labels[key], 'count': count} for key, count in top],
        'mine_pending': mine_pending,
        'reports': [{'id': r.id, 'exam_date': r.exam_date, 'format': r.exam_format,
                     'duration_minutes': r.duration_minutes, 'difficulty': r.difficulty,
                     'topics': json.loads(r.topics_json or '[]'), 'body': r.body,
                     'author': {'name': r.author_label or 'Studente'},
                     'mine': viewer is not None and r.author_user_id == viewer.id} for r in reports[:30]],
    }


@router.post('/exam')
def create_exam_report(data: ExamReportCreate, current_user: User = Depends(get_current_user),
                       db: Session = Depends(get_db)):
    if db.query(Subject.id).filter(Subject.id == data.subject_id, Subject.is_active.is_(True)).first() is None:
        raise HTTPException(400, 'Materia non trovata.')
    today = date.today()
    # Solo appelli già svolti: niente tracce di esami ancora in corso.
    if data.exam_date > today or data.exam_date < today - timedelta(days=3 * 365):
        raise HTTPException(400, 'Indica la data di un appello già svolto negli ultimi tre anni.')
    topics = [t.strip()[:60] for t in data.topics if t and t.strip()][:10]
    report = FaqExamReport(author_user_id=current_user.id, subject_id=data.subject_id, exam_date=data.exam_date,
        exam_format=data.exam_format, duration_minutes=data.duration_minutes, difficulty=data.difficulty,
        topics_json=json.dumps(topics, ensure_ascii=False), body=(data.body or '').strip() or None,
        is_anonymous=data.is_anonymous,
        author_label=student_label(db, current_user) if data.is_anonymous else display_name(current_user),
        status='pending')
    db.add(report)
    db.commit()
    return {'id': report.id, 'status': report.status}


# ---------------------------------------------------------------------------
# I miei contenuti
# ---------------------------------------------------------------------------

@router.get('/mine')
def my_content(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    questions = db.query(FaqQuestion).filter(FaqQuestion.author_user_id == current_user.id,
        FaqQuestion.status != 'removed').order_by(FaqQuestion.created_at.desc()).limit(100).all()
    answers = db.query(FaqAnswer).filter(FaqAnswer.author_user_id == current_user.id,
        FaqAnswer.status != 'removed').order_by(FaqAnswer.created_at.desc()).limit(100).all()
    return {'questions': [serialize_question(db, q, current_user) for q in questions],
            'answers': [serialize_answer(db, a, current_user) for a in answers]}


# ---------------------------------------------------------------------------
# Moderazione (admin): tutto passa da qui prima di essere visibile
# ---------------------------------------------------------------------------

@router.get('/moderation/counts')
def moderation_counts(current_user: User = Depends(get_admin_user), db: Session = Depends(get_db)):
    return {'questions': db.query(FaqQuestion).filter(FaqQuestion.status == 'pending').count(),
            'answers': db.query(FaqAnswer).filter(FaqAnswer.status == 'pending').count(),
            'reports': db.query(FaqExamReport).filter(FaqExamReport.status == 'pending').count()}


@router.get('/moderation/{kind}')
def moderation_queue(kind: str, current_user: User = Depends(get_admin_user), db: Session = Depends(get_db)):
    if kind == 'questions':
        rows = db.query(FaqQuestion).filter(FaqQuestion.status == 'pending').order_by(FaqQuestion.created_at).limit(200).all()
        return [serialize_question(db, r, current_user, admin_view=True) for r in rows]
    if kind == 'answers':
        rows = db.query(FaqAnswer).filter(FaqAnswer.status == 'pending').order_by(FaqAnswer.created_at).limit(200).all()
        result = []
        for row in rows:
            item = serialize_answer(db, row, current_user, admin_view=True)
            question = db.query(FaqQuestion).filter(FaqQuestion.id == row.question_id).first()
            item['question_title'] = question.title if question else None
            result.append(item)
        return result
    if kind == 'reports':
        rows = db.query(FaqExamReport).filter(FaqExamReport.status == 'pending').order_by(FaqExamReport.created_at).limit(200).all()
        result = []
        for r in rows:
            subject = db.query(Subject).filter(Subject.id == r.subject_id).first()
            author = db.query(User).filter(User.id == r.author_user_id).first() if r.author_user_id else None
            result.append({'id': r.id, 'subject_name': subject.name if subject else None, 'exam_date': r.exam_date,
                           'exam_format': r.exam_format, 'duration_minutes': r.duration_minutes,
                           'difficulty': r.difficulty,
                           'topics': json.loads(r.topics_json or '[]'), 'body': r.body,
                           'author_label': r.author_label,
                           'author_real_name': display_name(author) if author else None,
                           'created_at': r.created_at})
        return result
    raise HTTPException(404, 'Coda sconosciuta.')


@router.post('/moderation/{kind}/{item_id}')
def moderate(kind: str, item_id: int, data: ModerationRequest, current_user: User = Depends(get_admin_user),
             db: Session = Depends(get_db)):
    status_for = {'approve': 'published', 'reject': 'rejected', 'remove': 'removed'}[data.action]
    note = (data.note or '').strip() or None
    approve = data.action == 'approve'
    if kind == 'questions':
        item = db.query(FaqQuestion).filter(FaqQuestion.id == item_id).with_for_update().first()
        if item is None:
            raise HTTPException(404, 'Domanda non trovata.')
        was_published = item.status == 'published'
        item.status, item.moderation_note = status_for, note
        item.moderated_by, item.moderated_at = current_user.id, utc_now()
        if approve:
            notify(db, item.author_user_id, 'Domanda pubblicata',
                   f'La tua domanda “{item.title}” è ora visibile agli altri studenti.', current_user.id)
            if item.ask_teacher and not was_published:
                for teacher_id in teachers_of_subject(db, item.subject_id):
                    notify(db, teacher_id, 'Una domanda per te',
                           f'Uno studente chiede: “{item.title}”. Rispondi dalla sezione Domande.', current_user.id)
        else:
            notify(db, item.author_user_id, 'Domanda non pubblicata',
                   note or f'La tua domanda “{item.title}” non rispetta le regole della community.', current_user.id)
    elif kind == 'answers':
        item = db.query(FaqAnswer).filter(FaqAnswer.id == item_id).with_for_update().first()
        if item is None:
            raise HTTPException(404, 'Risposta non trovata.')
        item.status, item.moderation_note = status_for, note
        item.moderated_by, item.moderated_at = current_user.id, utc_now()
        if not approve:
            item.is_accepted = False
        question = db.query(FaqQuestion).filter(FaqQuestion.id == item.question_id).with_for_update().first()
        if question is not None:
            db.flush()
            refresh_question_counters(db, question)
            if approve:
                if question.author_user_id and question.author_user_id != item.author_user_id:
                    notify(db, question.author_user_id, 'Nuova risposta',
                           f'C’è una risposta alla tua domanda “{question.title}”.', current_user.id)
                followers = db.query(FaqVote.user_id).filter(FaqVote.target_type == 'question',
                    FaqVote.target_id == question.id, FaqVote.kind == 'same_doubt').limit(200).all()
                for (follower_id,) in followers:
                    if follower_id not in (question.author_user_id, item.author_user_id):
                        notify(db, follower_id, 'Risposta a un tuo dubbio',
                               f'Nuova risposta a “{question.title}”.', current_user.id)
        if item.author_user_id:
            notify(db, item.author_user_id, 'Risposta pubblicata' if approve else 'Risposta non pubblicata',
                   'La tua risposta è ora visibile.' if approve
                   else (note or 'La tua risposta non rispetta le regole della community.'), current_user.id)
    elif kind == 'reports':
        item = db.query(FaqExamReport).filter(FaqExamReport.id == item_id).with_for_update().first()
        if item is None:
            raise HTTPException(404, 'Racconto non trovato.')
        item.status, item.moderation_note = status_for, note
        item.moderated_by, item.moderated_at = current_user.id, utc_now()
        notify(db, item.author_user_id, 'Racconto d’esame pubblicato' if approve else 'Racconto d’esame non pubblicato',
               'Grazie: il tuo racconto aiuta chi deve sostenere l’esame.' if approve
               else (note or 'Il racconto non rispetta le regole della community.'), current_user.id)
    else:
        raise HTTPException(404, 'Coda sconosciuta.')
    db.commit()
    return {'id': item_id, 'status': status_for}
