"""Calendario accademico: lezioni, sessioni, appelli, chiusure ed eventi per
ateneo, dipartimento, corso e materia.

Lettura per tutti (anche ospiti). Scrivono gli admin (tutto) e i docenti
verificati (appelli ed eventi delle loro materie). Import da PDF, CSV, iCal,
JSON e pagine web; lo studente segue gli appelli e sceglie i promemoria
(standard: 7 e 1 giorno prima).
"""
import hmac
import ipaddress
import json
import re
import socket
from datetime import date, datetime, timedelta, timezone
from urllib.parse import urlparse

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, Request, UploadFile
from fastapi.responses import Response
from pydantic import BaseModel, Field
from sqlalchemy import and_, or_, true
from sqlalchemy.orm import Session

from core.config import settings
from core.database import SessionLocal, get_db
from core.security import ADMIN_ROLES, get_current_user, get_optional_current_user
from models.academic_calendar import EVENT_KINDS, CalendarEvent, CalendarFollow, CalendarSettings
from models.subject import Subject
from models.teacher_assignment import TeacherAssignment
from models.user import User
from services.calendar_import import parse_upload
from services.notification import create_notification
from services.news_filter_scope import COURSES, DEPARTMENTS, UNIVERSITIES, code, matches

router = APIRouter(prefix='/calendar', tags=['calendar'])

PERIOD_KINDS = ('lessons', 'session', 'extraordinary', 'closure')
TEACHER_KINDS = ('exam', 'extraordinary', 'event')
DEFAULT_REMINDERS = [7, 1]
KIND_LABELS = {'lessons': 'Lezioni', 'session': 'Sessione', 'exam': 'Appello', 'extraordinary': 'Sessione straordinaria',
               'closure': 'Chiusura', 'event': 'Evento'}


def _now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _name(user: User | None) -> str:
    if user is None:
        return 'StudentLab'
    return f'{user.first_name or ""} {user.last_name or ""}'.strip() or 'StudentLab'


def _is_admin(user: User | None) -> bool:
    return user is not None and (user.role or '') in ADMIN_ROLES


def _teacher_subject_ids(db: Session, user: User | None) -> set[int]:
    if user is None:
        return set()
    return {r[0] for r in db.query(TeacherAssignment.subject_id).filter(
        TeacherAssignment.user_id == user.id, TeacherAssignment.verification_status == 'verified',
        TeacherAssignment.is_current.is_(True)).all()}


def _can_manage(db: Session, user: User | None, kind: str, subject_id: int | None) -> bool:
    if _is_admin(user):
        return True
    return kind in TEACHER_KINDS and subject_id is not None and subject_id in _teacher_subject_ids(db, user)


def _reminders(value) -> list[int]:
    days = sorted({int(d) for d in (value or []) if str(d).isdigit() and 0 <= int(d) <= 60}, reverse=True)
    return days[:5]


def _serialize(db: Session, event: CalendarEvent, viewer: User | None = None, follow: CalendarFollow | None = None,
               subjects: dict | None = None) -> dict:
    subject = None
    if event.subject_id:
        subject = (subjects or {}).get(event.subject_id) or db.query(Subject).filter(Subject.id == event.subject_id).first()
    return {
        'id': event.id, 'kind': event.kind, 'kind_label': KIND_LABELS.get(event.kind, event.kind), 'title': event.title,
        'starts_at': event.starts_at.isoformat(), 'ends_at': event.ends_at.isoformat() if event.ends_at else None,
        'all_day': event.all_day, 'exam_format': event.exam_format, 'room': event.room,
        'teachers': json.loads(event.teachers_json or '[]'), 'booking_url': event.booking_url,
        'booking_deadline': event.booking_deadline.isoformat() if event.booking_deadline else None,
        'notes': event.notes, 'status': event.status, 'source': event.source,
        'curricula': json.loads(event.curricula_json or '[]'),
        'university': event.university or (subject.university if subject else None),
        'department': event.department or (subject.department if subject else None),
        'course': event.course or (subject.course if subject else None),
        'subject_id': event.subject_id, 'subject_name': subject.name if subject else None,
        'updated_by_name': event.updated_by_name or event.created_by_name, 'updated_at': event.updated_at,
        'followed': follow is not None,
        'remind_days': json.loads(follow.remind_days_json) if follow else None,
        'can_edit': _can_manage(db, viewer, event.kind, event.subject_id) if viewer else False,
    }


def _context_filter(db: Session, university: str | None, department: str | None, course: str | None,
                    subject_id: int | None):
    """Eventi dell'ambito e di quelli più ampi (ateneo > dipartimento > corso > materia)."""
    def wide(column, value):
        if not value:
            return true()
        dimension = column.key
        known = code(value, dimension)
        aliases = {'university': UNIVERSITIES, 'department': DEPARTMENTS, 'course': COURSES}[dimension]
        options = (aliases[known][1] if dimension == 'course' else aliases[known]) if known else ()
        names = (known, *options) if known else (value,)
        return or_(column.is_(None), *(column.ilike(name) for name in names))

    subject = db.query(Subject).filter(Subject.id == subject_id).first() if subject_id else None
    if subject is not None:
        university, department, course = subject.university, subject.department, subject.course
    general = and_(CalendarEvent.subject_id.is_(None), wide(CalendarEvent.university, university),
                   wide(CalendarEvent.department, department), wide(CalendarEvent.course, course))
    if subject is not None:
        return or_(general, CalendarEvent.subject_id == subject.id)
    subject_query = db.query(Subject.id).filter(Subject.is_active.is_(True))
    if university:
        subject_query = subject_query.filter(matches(Subject.university, Subject.university_code, university, 'university'))
    if department:
        subject_query = subject_query.filter(matches(Subject.department, Subject.department_code, department, 'department'))
    if course:
        subject_query = subject_query.filter(matches(Subject.course, Subject.course_code, course, 'course'))
    ids = [r[0] for r in subject_query.limit(2000).all()] if (university or department or course) else None
    return or_(general, CalendarEvent.subject_id.in_(ids)) if ids is not None else true()


# ---------------------------------------------------------------------------
# Lettura (anche ospiti)
# ---------------------------------------------------------------------------

@router.get('/events')
def list_events(university: str | None = None, department: str | None = None, course: str | None = None,
                subject_id: int | None = None, kind: str | None = None, curriculum: str | None = None,
                start: date | None = Query(default=None, alias='from'), end: date | None = Query(default=None, alias='to'),
                include_cancelled: bool = False, exclude_timetable: bool = False,
                timetable_only: bool = False, viewer: User | None = Depends(get_optional_current_user),
                db: Session = Depends(get_db)):
    start = start or (date.today() - timedelta(days=1))
    end = end or (date.today() + timedelta(days=500))
    query = db.query(CalendarEvent).filter(_context_filter(db, university, department, course, subject_id),
        or_(CalendarEvent.starts_at >= datetime.combine(start, datetime.min.time()),
            CalendarEvent.ends_at >= datetime.combine(start, datetime.min.time())),
        CalendarEvent.starts_at <= datetime.combine(end, datetime.max.time()))
    if viewer is None:
        query = query.filter(CalendarEvent.kind.in_(('lessons', 'session', 'closure')),
                             CalendarEvent.department.is_(None), CalendarEvent.course.is_(None),
                             CalendarEvent.subject_id.is_(None))
    if exclude_timetable:
        query = query.filter(or_(CalendarEvent.kind != 'lessons',
            and_(CalendarEvent.course.is_(None), CalendarEvent.subject_id.is_(None))))
    if timetable_only:
        query = query.filter(CalendarEvent.kind == 'lessons',
            or_(CalendarEvent.course.isnot(None), CalendarEvent.subject_id.isnot(None)))
    if kind in EVENT_KINDS:
        query = query.filter(CalendarEvent.kind == kind)
    if curriculum:
        query = query.filter(or_(CalendarEvent.curricula_json.is_(None),
                                 CalendarEvent.curricula_json.contains(json.dumps(curriculum))))
    if not include_cancelled:
        query = query.filter(CalendarEvent.status != 'cancelled')
    events = query.order_by(CalendarEvent.starts_at).limit(1500).all()
    follows = {}
    if viewer is not None and events:
        follows = {f.event_id: f for f in db.query(CalendarFollow).filter(CalendarFollow.user_id == viewer.id,
                   CalendarFollow.event_id.in_([e.id for e in events])).all()}
    subject_ids = {e.subject_id for e in events if e.subject_id}
    subjects = {s.id: s for s in db.query(Subject).filter(Subject.id.in_(subject_ids)).all()} if subject_ids else {}
    return [_serialize(db, e, viewer, follows.get(e.id), subjects) for e in events]


@router.get('/current-periods')
def current_periods(university: str | None = None, department: str | None = None, course: str | None = None,
                    viewer: User | None = Depends(get_optional_current_user), db: Session = Depends(get_db)):
    """Periodi in corso (lezioni, sessione, straordinaria, chiusura)."""
    now = _now()
    rows = db.query(CalendarEvent).filter(_context_filter(db, university, department, course, None),
        CalendarEvent.kind.in_(PERIOD_KINDS), CalendarEvent.status != 'cancelled',
        or_(CalendarEvent.kind != 'lessons', CalendarEvent.subject_id.is_(None)),
        CalendarEvent.starts_at <= now, or_(CalendarEvent.ends_at >= now,
        and_(CalendarEvent.ends_at.is_(None), CalendarEvent.starts_at >= now - timedelta(days=1)))).all()
    if viewer is None:
        rows = [row for row in rows if row.department is None and row.course is None and
                row.subject_id is None and row.kind in ('lessons', 'session', 'closure')]
    priority = {'closure': 0, 'extraordinary': 1, 'session': 2, 'lessons': 3}
    rows.sort(key=lambda e: priority.get(e.kind, 9))
    return [_serialize(db, e) for e in rows]


@router.get('/events/{event_id}')
def event_detail(event_id: int, viewer: User | None = Depends(get_optional_current_user), db: Session = Depends(get_db)):
    event = db.query(CalendarEvent).filter(CalendarEvent.id == event_id).first()
    if event is None or (viewer is None and (event.kind not in ('lessons', 'session', 'closure')
                        or event.department or event.course or event.subject_id)):
        raise HTTPException(404, 'Evento non trovato.')
    follow = db.query(CalendarFollow).filter(CalendarFollow.user_id == viewer.id,
                                             CalendarFollow.event_id == event.id).first() if viewer else None
    data = _serialize(db, event, viewer, follow)
    data['followers'] = db.query(CalendarFollow).filter(CalendarFollow.event_id == event.id).count()
    return data


def _ics_text(value: str | None) -> str:
    return (value or '').replace('\\', '\\\\').replace(',', '\\,').replace(';', '\\;').replace('\n', '\\n')


def _ics(events: list[CalendarEvent], db: Session) -> str:
    lines = ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//StudentLab//Calendario//IT', 'CALSCALE:GREGORIAN']
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    for e in events:
        subject = db.query(Subject).filter(Subject.id == e.subject_id).first() if e.subject_id else None
        lines += ['BEGIN:VEVENT', f'UID:studentlab-calendar-{e.id}@studentlab', f'DTSTAMP:{stamp}']
        if e.all_day:
            end = (e.ends_at or e.starts_at).date() + timedelta(days=1)
            lines += [f'DTSTART;VALUE=DATE:{e.starts_at:%Y%m%d}', f'DTEND;VALUE=DATE:{end:%Y%m%d}']
        else:
            end = e.ends_at or (e.starts_at + timedelta(hours=2))
            lines += [f'DTSTART;TZID=Europe/Rome:{e.starts_at:%Y%m%dT%H%M%S}', f'DTEND;TZID=Europe/Rome:{end:%Y%m%dT%H%M%S}']
        title = f'{KIND_LABELS.get(e.kind, "")}: {e.title}' if e.kind == 'exam' else e.title
        lines.append(f'SUMMARY:{_ics_text(title)}')
        if e.room:
            lines.append(f'LOCATION:{_ics_text(e.room)}')
        details = [subject.name if subject else '', e.notes or '', e.booking_url or '']
        lines.append(f'DESCRIPTION:{_ics_text(chr(10).join(d for d in details if d))}')
        if e.status == 'cancelled':
            lines.append('STATUS:CANCELLED')
        lines.append('END:VEVENT')
    lines.append('END:VCALENDAR')
    return '\r\n'.join(lines) + '\r\n'


@router.get('/events/{event_id}/ics')
def event_ics(event_id: int, viewer: User | None = Depends(get_optional_current_user), db: Session = Depends(get_db)):
    event = db.query(CalendarEvent).filter(CalendarEvent.id == event_id).first()
    if event is None or (viewer is None and (event.kind not in ('lessons', 'session', 'closure')
                        or event.department or event.course or event.subject_id)):
        raise HTTPException(404, 'Evento non trovato.')
    return Response(content=_ics([event], db), media_type='text/calendar; charset=utf-8',
                    headers={'Content-Disposition': f'attachment; filename="studentlab-{event.id}.ics"'})


# ---------------------------------------------------------------------------
# Seguire e promemoria
# ---------------------------------------------------------------------------

class FollowRequest(BaseModel):
    remind_days: list[int] | None = None


class SettingsRequest(BaseModel):
    remind_days: list[int] = Field(default_factory=lambda: list(DEFAULT_REMINDERS))


def _default_reminders(db: Session, user: User) -> list[int]:
    row = db.query(CalendarSettings).filter(CalendarSettings.user_id == user.id).first()
    return json.loads(row.remind_days_json) if row else list(DEFAULT_REMINDERS)


@router.get('/settings')
def get_settings(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return {'remind_days': _default_reminders(db, current_user)}


@router.put('/settings')
def put_settings(data: SettingsRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    days = _reminders(data.remind_days)
    row = db.query(CalendarSettings).filter(CalendarSettings.user_id == current_user.id).first()
    if row is None:
        row = CalendarSettings(user_id=current_user.id)
        db.add(row)
    row.remind_days_json = json.dumps(days)
    db.commit()
    return {'remind_days': days}


@router.post('/events/{event_id}/follow')
def follow_event(event_id: int, data: FollowRequest, current_user: User = Depends(get_current_user),
                 db: Session = Depends(get_db)):
    event = db.query(CalendarEvent).filter(CalendarEvent.id == event_id).first()
    if event is None:
        raise HTTPException(404, 'Evento non trovato.')
    days = _reminders(data.remind_days) if data.remind_days is not None else _default_reminders(db, current_user)
    follow = db.query(CalendarFollow).filter(CalendarFollow.user_id == current_user.id,
                                             CalendarFollow.event_id == event.id).first()
    if follow is None:
        follow = CalendarFollow(user_id=current_user.id, event_id=event.id, sent_days_json='[]')
        db.add(follow)
    follow.remind_days_json = json.dumps(days)
    db.commit()
    return _serialize(db, event, current_user, follow)


@router.delete('/events/{event_id}/follow')
def unfollow_event(event_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    db.query(CalendarFollow).filter(CalendarFollow.user_id == current_user.id,
                                    CalendarFollow.event_id == event_id).delete()
    db.commit()
    return {'followed': False}


@router.get('/followed')
def followed(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    rows = db.query(CalendarFollow, CalendarEvent).join(CalendarEvent, CalendarEvent.id == CalendarFollow.event_id).filter(
        CalendarFollow.user_id == current_user.id, CalendarEvent.starts_at >= _now() - timedelta(days=1)).order_by(
        CalendarEvent.starts_at).all()
    return [_serialize(db, e, current_user, f) for f, e in rows]


# ---------------------------------------------------------------------------
# Scrittura: admin (tutto) e docenti (appelli ed eventi delle loro materie)
# ---------------------------------------------------------------------------

class EventWrite(BaseModel):
    kind: str = Field(pattern='^(lessons|session|exam|extraordinary|closure|event)$')
    title: str = Field(min_length=1, max_length=200)
    university: str | None = Field(default=None, max_length=255)
    department: str | None = Field(default=None, max_length=255)
    course: str | None = Field(default=None, max_length=255)
    subject_id: int | None = None
    starts_at: datetime
    ends_at: datetime | None = None
    all_day: bool = False
    exam_format: str | None = Field(default=None, pattern='^(scritto|orale|scritto_orale|progetto)$')
    room: str | None = Field(default=None, max_length=200)
    teachers: list[str] = Field(default_factory=list, max_length=10)
    booking_url: str | None = Field(default=None, max_length=500)
    booking_deadline: date | None = None
    notes: str | None = Field(default=None, max_length=2000)
    status: str = Field(default='confirmed', pattern='^(confirmed|provisional|cancelled)$')
    source: str = Field(default='manual', pattern='^(manual|pdf|csv|ics|json|web)$')
    source_ref: str | None = Field(default=None, max_length=500)


@router.get('/manageable')
def manageable(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Cosa può gestire l'utente: admin tutto, docente le sue materie."""
    admin = _is_admin(current_user)
    ids = _teacher_subject_ids(db, current_user)
    subjects = db.query(Subject).filter(Subject.id.in_(ids)).order_by(Subject.name).all() if ids else []
    return {'is_admin': admin, 'can_write': admin or bool(subjects),
            'subjects': [{'id': s.id, 'name': s.name, 'course': s.course, 'department': s.department,
                          'university': s.university} for s in subjects]}


def _apply(db: Session, event: CalendarEvent, data: EventWrite, user: User):
    if data.booking_url and not data.booking_url.startswith(('http://', 'https://')):
        raise HTTPException(400, 'Il link di prenotazione deve iniziare con http:// o https://')
    if data.ends_at and data.ends_at < data.starts_at:
        raise HTTPException(400, 'La fine non può essere prima dell’inizio.')
    subject = db.query(Subject).filter(Subject.id == data.subject_id).first() if data.subject_id else None
    if data.subject_id and subject is None:
        raise HTTPException(400, 'Materia non trovata.')
    event.kind, event.title = data.kind, data.title.strip()
    if subject is not None:
        event.university, event.department, event.course = subject.university, subject.department, subject.course
    else:
        event.university, event.department, event.course = data.university, data.department, data.course
    event.subject_id = data.subject_id
    event.starts_at = data.starts_at.replace(tzinfo=None)
    event.ends_at = data.ends_at.replace(tzinfo=None) if data.ends_at else None
    event.all_day, event.exam_format = data.all_day, data.exam_format
    event.room = (data.room or '').strip() or None
    event.teachers_json = json.dumps([t.strip() for t in data.teachers if t.strip()], ensure_ascii=False)
    event.booking_url, event.booking_deadline = data.booking_url, data.booking_deadline
    event.notes = (data.notes or '').strip() or None
    event.status, event.source, event.source_ref = data.status, data.source, data.source_ref
    event.updated_by_name = _name(user)


@router.post('/events')
def create_event(data: EventWrite, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    if not _can_manage(db, current_user, data.kind, data.subject_id):
        raise HTTPException(403, 'Puoi inserire solo appelli ed eventi delle materie che insegni.')
    event = CalendarEvent(created_by=current_user.id, created_by_name=_name(current_user))
    _apply(db, event, data, current_user)
    db.add(event)
    db.commit()
    db.refresh(event)
    return _serialize(db, event, current_user)


def _notify_change(db: Session, event: CalendarEvent, what: str, actor: User):
    for (user_id,) in db.query(CalendarFollow.user_id).filter(CalendarFollow.event_id == event.id).limit(5000).all():
        create_notification(db, user_id=user_id, notification_type='system',
                            title=f'Cambiato: {event.title}'[:120], message=what[:500],
                            actor_user_id=actor.id, commit=False)


@router.put('/events/{event_id}')
def update_event(event_id: int, data: EventWrite, current_user: User = Depends(get_current_user),
                 db: Session = Depends(get_db)):
    event = db.query(CalendarEvent).filter(CalendarEvent.id == event_id).with_for_update().first()
    if event is None:
        raise HTTPException(404, 'Evento non trovato.')
    if not _can_manage(db, current_user, event.kind, event.subject_id) or \
            not _can_manage(db, current_user, data.kind, data.subject_id):
        raise HTTPException(403, 'Puoi modificare solo appelli ed eventi delle materie che insegni.')
    before = (event.starts_at, event.ends_at, event.room, event.status)
    _apply(db, event, data, current_user)
    changes = []
    if before[0] != event.starts_at or before[1] != event.ends_at:
        changes.append(f'nuova data: {event.starts_at:%d/%m/%Y}' + ('' if event.all_day else f' alle {event.starts_at:%H:%M}'))
    if before[2] != event.room:
        changes.append(f'aula: {event.room or "da definire"}')
    if before[3] != event.status:
        changes.append({'cancelled': 'annullato', 'provisional': 'da confermare', 'confirmed': 'confermato'}[event.status])
    if changes:
        _notify_change(db, event, 'Aggiornamento: ' + ', '.join(changes) + '.', current_user)
        # I promemoria ripartono dalla nuova data.
        db.query(CalendarFollow).filter(CalendarFollow.event_id == event.id).update({'sent_days_json': '[]'})
    db.commit()
    return _serialize(db, event, current_user)


@router.delete('/events/{event_id}')
def delete_event(event_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    event = db.query(CalendarEvent).filter(CalendarEvent.id == event_id).first()
    if event is None:
        raise HTTPException(404, 'Evento non trovato.')
    if not _can_manage(db, current_user, event.kind, event.subject_id):
        raise HTTPException(403, 'Non puoi eliminare questo evento.')
    if db.query(CalendarFollow.id).filter(CalendarFollow.event_id == event.id).first():
        # Chi lo seguiva viene avvisato: l'evento resta come "annullato".
        event.status = 'cancelled'
        event.updated_by_name = _name(current_user)
        _notify_change(db, event, 'L’evento è stato annullato.', current_user)
    else:
        db.delete(event)
    db.commit()
    return {'id': event_id}


# ---------------------------------------------------------------------------
# Import: PDF, CSV, iCal, JSON, pagina web
# ---------------------------------------------------------------------------

MAX_IMPORT_BYTES = 4 * 1024 * 1024


def _check_public_url(url: str) -> None:
    """Blocca indirizzi interni (localhost, reti private) per evitare abusi."""
    parsed = urlparse(url)
    if parsed.scheme not in ('http', 'https') or not parsed.hostname:
        raise HTTPException(400, 'Indica un indirizzo http:// o https:// valido.')
    try:
        addresses = {info[4][0] for info in socket.getaddrinfo(parsed.hostname, None)}
    except socket.gaierror as exc:
        raise HTTPException(400, 'Indirizzo non raggiungibile.') from exc
    for address in addresses:
        ip = ipaddress.ip_address(address)
        if ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_reserved or ip.is_multicast:
            raise HTTPException(400, 'Indirizzo non consentito.')


async def _download(url: str) -> tuple[str, bytes]:
    import httpx
    _check_public_url(url)
    async with httpx.AsyncClient(timeout=15, follow_redirects=False, headers={'User-Agent': 'StudentLab-Calendario/1.0'}) as client:
        response = await client.get(url)
        if response.status_code in (301, 302, 303, 307, 308) and response.headers.get('location'):
            target = response.headers['location']
            _check_public_url(target)
            response = await client.get(target)
    if response.status_code >= 400:
        raise HTTPException(400, f'La pagina ha risposto con errore {response.status_code}.')
    content = response.content[:MAX_IMPORT_BYTES]
    kind = (response.headers.get('content-type') or '').lower()
    name = urlparse(url).path.rsplit('/', 1)[-1] or 'pagina.html'
    if 'html' in kind and not name.endswith(('.htm', '.html')):
        name += '.html'
    elif 'calendar' in kind and not name.endswith('.ics'):
        name += '.ics'
    elif 'pdf' in kind and not name.endswith('.pdf'):
        name += '.pdf'
    return name, content


def _tokens(text: str | None) -> set[str]:
    return {w for w in re.split(r'[^a-z0-9àèéìòù]+', (text or '').lower()) if len(w) > 2 and w not in ('del', 'della', 'dei', 'delle', 'con')}


def _match_subject(subjects: list[Subject], name: str | None) -> Subject | None:
    wanted = _tokens(name)
    if not wanted:
        return None
    best, best_score = None, 0.0
    for subject in subjects:
        have = _tokens(subject.name)
        if not have:
            continue
        score = len(wanted & have) / max(len(have), 1)
        if score > best_score:
            best, best_score = subject, score
    return best if best_score >= 0.6 else None


@router.post('/import/preview')
async def import_preview(file: UploadFile | None = File(default=None), url: str | None = Form(default=None),
                         university: str | None = Form(default=None), department: str | None = Form(default=None),
                         course: str | None = Form(default=None), default_year: int | None = Form(default=None),
                         current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    admin = _is_admin(current_user)
    teacher_ids = _teacher_subject_ids(db, current_user)
    if not admin and not teacher_ids:
        raise HTTPException(403, 'Solo admin e docenti possono importare calendari.')
    if file is not None and (file.filename or '').strip():
        content = await file.read(MAX_IMPORT_BYTES + 1)
        if len(content) > MAX_IMPORT_BYTES:
            raise HTTPException(400, 'Il file supera 4 MB.')
        name = file.filename
    elif url:
        name, content = await _download(url.strip())
    else:
        raise HTTPException(400, 'Carica un file o indica un indirizzo web.')
    try:
        events = parse_upload(name, content, default_year)
    except Exception as exc:
        raise HTTPException(400, 'Non riesco a leggere questo file: controlla il formato.') from exc
    subjects_query = db.query(Subject).filter(Subject.is_active.is_(True))
    if course:
        subjects_query = subjects_query.filter(Subject.course == course)
    if department:
        subjects_query = subjects_query.filter(Subject.department == department)
    subjects = subjects_query.limit(3000).all()
    if not admin:
        subjects = [s for s in subjects if s.id in teacher_ids] or \
            db.query(Subject).filter(Subject.id.in_(teacher_ids)).all()
    for event in events:
        match = _match_subject(subjects, event.get('subject_name')) if event.get('subject_name') else None
        event['subject_id'] = match.id if match else None
        event['subject_match'] = match.name if match else None
        if event['kind'] in ('exam', 'extraordinary') and match is None and event.get('subject_name'):
            event['warnings'].append('Materia non riconosciuta: sceglila')
        if not admin and (event['kind'] not in TEACHER_KINDS or match is None):
            event['warnings'].append('Come docente puoi importare solo appelli ed eventi delle tue materie')
    return {'source': name, 'events': events[:500], 'count': len(events),
            'subjects': [{'id': s.id, 'name': s.name, 'course': s.course} for s in subjects[:500]]}


class ImportCommit(BaseModel):
    events: list[EventWrite] = Field(max_length=500)


@router.post('/import/commit')
def import_commit(data: ImportCommit, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    created, skipped = 0, []
    for index, item in enumerate(data.events):
        if not _can_manage(db, current_user, item.kind, item.subject_id):
            skipped.append({'index': index, 'reason': 'non autorizzato'})
            continue
        # Evita doppioni: stesso titolo, materia e inizio.
        exists = db.query(CalendarEvent.id).filter(CalendarEvent.title == item.title.strip(),
            CalendarEvent.starts_at == item.starts_at.replace(tzinfo=None),
            CalendarEvent.subject_id.is_(None) if item.subject_id is None else CalendarEvent.subject_id == item.subject_id).first()
        if exists:
            skipped.append({'index': index, 'reason': 'già presente'})
            continue
        event = CalendarEvent(created_by=current_user.id, created_by_name=_name(current_user))
        _apply(db, event, item, current_user)
        db.add(event)
        created += 1
    db.commit()
    return {'created': created, 'skipped': skipped}


# ---------------------------------------------------------------------------
# Promemoria (Vercel Cron, una volta al giorno)
# ---------------------------------------------------------------------------

@router.get('/internal/reminders')
def send_reminders(request: Request):
    secret = settings.drive_cron_secret
    bearer = request.headers.get('authorization', '')
    if not secret or not hmac.compare_digest(bearer, f'Bearer {secret}'):
        raise HTTPException(401, 'Accesso negato.')
    db = SessionLocal()
    sent = 0
    try:
        today = date.today()
        rows = db.query(CalendarFollow, CalendarEvent).join(CalendarEvent, CalendarEvent.id == CalendarFollow.event_id).filter(
            CalendarEvent.status != 'cancelled',
            CalendarEvent.starts_at >= datetime.combine(today, datetime.min.time()),
            CalendarEvent.starts_at <= datetime.combine(today + timedelta(days=61), datetime.max.time())).all()
        for follow, event in rows:
            days_left = (event.starts_at.date() - today).days
            wanted = json.loads(follow.remind_days_json or '[]')
            done = set(json.loads(follow.sent_days_json or '[]'))
            # Il promemoria più vicino non ancora inviato (se il cron salta un giorno, arriva il giorno dopo).
            due = [d for d in wanted if d not in done and 0 <= days_left <= d and d - days_left <= 1]
            if not due:
                continue
            when = 'domani' if days_left == 1 else ('oggi' if days_left == 0 else f'tra {days_left} giorni')
            at = '' if event.all_day else f' alle {event.starts_at:%H:%M}'
            create_notification(db, user_id=follow.user_id, notification_type='system',
                                title=f'{KIND_LABELS.get(event.kind, "Evento")} {when}'[:120],
                                message=f'{event.title}: {event.starts_at:%d/%m}{at}{" · " + event.room if event.room else ""}.'[:500],
                                commit=False)
            follow.sent_days_json = json.dumps(sorted(done | set(due)))
            sent += 1
        db.commit()
    finally:
        db.close()
    return {'sent': sent}
