"""Domande degli studenti: regole comuni (ruoli, etichette, serializzazione,
contatori, allegati). Le route sono in routes/faq.py."""
import hashlib
import hmac
import json
import re
import uuid
from datetime import datetime, timezone

from sqlalchemy.orm import Session
from vercel.blob import AsyncBlobClient

from core.config import settings
from core.security import ADMIN_ROLES
from models.faq import FaqAnswer, FaqQuestion, FaqVote
from models.public_material import PublicMaterial
from models.subject import Subject
from models.teacher_assignment import TeacherAssignment
from models.user import User, UserAcademicPath
from services.notification import create_notification
from services.private_blob import require_blob_storage


def utc_now():
    return datetime.now(timezone.utc)


CATEGORY_LABELS = {
    'exams': 'Esami e appelli',
    'topics': 'Argomenti e lezioni',
    'materials': 'Materiali',
    'study_plan': 'Piano di studi',
    'thesis': 'Tirocinio e tesi',
    'campus_life': 'Vita universitaria',
    'other': 'Altro',
}

# Allegati alle risposte: la richiesta passa dal backend (limite Vercel ~4,5 MB).
MAX_FILE_USER = 4 * 1024 * 1024
MAX_FILE_GUEST = 2 * 1024 * 1024
ALLOWED_FILES = {
    '.pdf': ('application/pdf', [b'%PDF']),
    '.png': ('image/png', [b'\x89PNG']),
    '.jpg': ('image/jpeg', [b'\xff\xd8\xff']),
    '.jpeg': ('image/jpeg', [b'\xff\xd8\xff']),
    '.txt': ('text/plain', []),
    '.docx': ('application/vnd.openxmlformats-officedocument.wordprocessingml.document', [b'PK']),
    '.pptx': ('application/vnd.openxmlformats-officedocument.presentationml.presentation', [b'PK']),
}
GUEST_FILES = {'.pdf', '.png', '.jpg', '.jpeg'}


def is_admin(user: User | None) -> bool:
    return user is not None and (user.role or '') in ADMIN_ROLES


def is_teacher_of(db: Session, user: User | None, subject_id: int | None) -> bool:
    if user is None or subject_id is None:
        return False
    return db.query(TeacherAssignment.id).filter(
        TeacherAssignment.user_id == user.id, TeacherAssignment.subject_id == subject_id,
        TeacherAssignment.verification_status == 'verified',
        TeacherAssignment.is_current.is_(True)).first() is not None


def author_role(db: Session, user: User | None, subject_id: int | None) -> str:
    if user is None:
        return 'guest'
    if is_admin(user):
        return 'studentlab'
    if is_teacher_of(db, user, subject_id):
        return 'teacher'
    return 'student'


def student_label(db: Session, user: User) -> str:
    """"Studente del 2° anno" dal percorso corrente (anno accademico da settembre)."""
    if is_admin(user):
        return 'StudentLab'
    if (user.role or '') == 'teacher':
        return 'Docente'
    path = db.query(UserAcademicPath).filter(UserAcademicPath.user_id == user.id,
        UserAcademicPath.status == 'enrolled').order_by(UserAcademicPath.is_current.desc()).first()
    if path is None or not path.start_year:
        return 'Studente'
    now = utc_now()
    academic_start = now.year if now.month >= 9 else now.year - 1
    year = academic_start - int(path.start_year) + 1
    return f'Studente del {year}° anno' if 1 <= year <= 8 else 'Studente'


def display_name(user: User | None) -> str:
    if user is None:
        return 'Utente'
    name = f'{user.first_name or ""} {user.last_name or ""}'.strip()
    return name or 'Utente'


def guest_hash(value: str | None) -> str | None:
    if not value:
        return None
    secret = (settings.secret_key or 'studentlab').encode()
    return hmac.new(secret, f'faq:{value}'.encode(), hashlib.sha256).hexdigest()


def search_words(text: str | None) -> list[str]:
    return [w for w in re.split(r'[^0-9a-zA-ZÀ-ÿ]+', (text or '').casefold()) if len(w) >= 3][:8]


def my_votes(db: Session, user: User | None, target_type: str, ids: list[int]) -> dict[int, set[str]]:
    if user is None or not ids:
        return {}
    result: dict[int, set[str]] = {}
    for vote in db.query(FaqVote).filter(FaqVote.user_id == user.id, FaqVote.target_type == target_type,
                                         FaqVote.target_id.in_(ids)).all():
        result.setdefault(vote.target_id, set()).add(vote.kind)
    return result


def serialize_question(db: Session, q: FaqQuestion, viewer: User | None, votes: set[str] | None = None,
                       admin_view: bool = False) -> dict:
    subject = db.query(Subject).filter(Subject.id == q.subject_id).first() if q.subject_id else None
    author = db.query(User).filter(User.id == q.author_user_id).first() if q.author_user_id else None
    public_name = q.author_label if q.is_anonymous else display_name(author)
    data = {
        'id': q.id, 'title': q.title, 'body': q.body, 'category': q.category,
        'category_label': CATEGORY_LABELS.get(q.category, 'Altro'),
        'university': q.university, 'department': q.department, 'course': q.course,
        'subject_id': q.subject_id, 'subject_name': subject.name if subject else None,
        'author_label': public_name or 'Studente', 'is_anonymous': q.is_anonymous,
        'is_mine': viewer is not None and q.author_user_id == viewer.id,
        'status': q.status, 'useful_count': q.useful_count, 'same_doubt_count': q.same_doubt_count,
        'answers_count': q.answers_count, 'accepted_answer_id': q.accepted_answer_id,
        'has_verified_answer': q.has_verified_answer, 'ask_teacher': q.ask_teacher,
        'my_votes': sorted(votes or []), 'created_at': q.created_at,
    }
    if admin_view:
        data['author_real_name'] = display_name(author) if author else None
        data['moderation_note'] = q.moderation_note
    return data


def serialize_answer(db: Session, a: FaqAnswer, viewer: User | None, votes: set[str] | None = None,
                     guest_key_hash: str | None = None, admin_view: bool = False) -> dict:
    author = db.query(User).filter(User.id == a.author_user_id).first() if a.author_user_id else None
    if a.author_role == 'guest':
        name = (a.guest_name or '').strip() or 'Ospite'
    elif a.author_role == 'studentlab':
        name = 'StudentLab'
    else:
        name = display_name(author)
    attachment = None
    if a.file_stored_name:
        attachment = {'type': 'file', 'name': a.file_original_name, 'size': a.file_size,
                      'mime_type': a.file_mime_type, 'url': f'/faq/answers/{a.id}/file'}
    elif a.public_material_id:
        material = db.query(PublicMaterial).filter(PublicMaterial.id == a.public_material_id).first()
        if material is not None:
            attachment = {'type': 'material', 'material_id': material.id, 'name': material.title,
                          'path_segments': json.loads(material.catalog_path_json or '[]')}
    mine = (viewer is not None and a.author_user_id == viewer.id) or (
        guest_key_hash is not None and a.guest_key_hash == guest_key_hash)
    data = {
        'id': a.id, 'question_id': a.question_id, 'body': a.body, 'author_name': name,
        'author_role': a.author_role, 'is_verified': a.is_verified, 'is_accepted': a.is_accepted,
        'useful_count': a.useful_count, 'my_votes': sorted(votes or []), 'is_mine': mine,
        'status': a.status, 'attachment': attachment, 'created_at': a.created_at,
    }
    if admin_view:
        data['author_real_name'] = display_name(author) if author else f'Ospite: {a.guest_name or "senza nome"}'
        data['moderation_note'] = a.moderation_note
    return data


def refresh_question_counters(db: Session, question: FaqQuestion):
    published = db.query(FaqAnswer).filter(FaqAnswer.question_id == question.id,
                                           FaqAnswer.status == 'published').all()
    question.answers_count = len(published)
    question.has_verified_answer = any(a.is_verified for a in published)
    if question.accepted_answer_id and not any(a.id == question.accepted_answer_id for a in published):
        question.accepted_answer_id = None


def check_file(name: str, content: bytes, guest: bool) -> tuple[str, str]:
    """Estensione, tipo e firma del file. Restituisce (estensione, mime)."""
    lower = (name or '').strip().casefold()
    extension = next((ext for ext in ALLOWED_FILES if lower.endswith(ext)), None)
    if extension is None or (guest and extension not in GUEST_FILES):
        allowed = 'PDF, PNG o JPG' if guest else 'PDF, immagini, TXT, DOCX o PPTX'
        raise ValueError(f'Formato non ammesso: puoi allegare {allowed}.')
    limit = MAX_FILE_GUEST if guest else MAX_FILE_USER
    if len(content) == 0:
        raise ValueError('Il file è vuoto.')
    if len(content) > limit:
        raise ValueError(f'Il file supera {limit // (1024 * 1024)} MB.')
    mime, signatures = ALLOWED_FILES[extension]
    if signatures and not any(content.startswith(sig) for sig in signatures):
        raise ValueError('Il contenuto del file non corrisponde al formato.')
    return extension, mime


async def store_answer_file(content: bytes, extension: str, mime: str) -> str:
    """Salva l'allegato su Blob privato. Non è scaricabile finché la risposta
    non è approvata (vedi la route del file)."""
    require_blob_storage()
    stored = f'faq/answers/{uuid.uuid4().hex}{extension}'
    async with AsyncBlobClient(token=settings.blob_read_write_token) as client:
        try:
            await client.put(stored, content, access='private', content_type=mime, add_random_suffix=False)
        except TypeError:
            # Versioni della libreria con meno parametri.
            await client.put(stored, content, access='private')
    return stored


def notify(db: Session, user_id: int | None, title: str, message: str, actor_id: int | None = None):
    """Notifica semplice (tipo 'system': nessun vincolo nuovo sulle notifiche)."""
    if user_id is None:
        return
    create_notification(db, user_id=user_id, notification_type='system', title=title,
                        message=message[:500], actor_user_id=actor_id, commit=False)


def teachers_of_subject(db: Session, subject_id: int | None) -> list[int]:
    if subject_id is None:
        return []
    rows = db.query(TeacherAssignment.user_id).filter(TeacherAssignment.subject_id == subject_id,
        TeacherAssignment.verification_status == 'verified', TeacherAssignment.is_current.is_(True)).all()
    return sorted({row[0] for row in rows})
