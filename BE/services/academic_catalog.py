"""Conservative course lookup and review of unmatched student declarations."""
import re
import unicodedata
from datetime import datetime, timezone
from difflib import SequenceMatcher

from sqlalchemy.orm import Session

from models.academic_catalog_request import AcademicCatalogCourse, AcademicCatalogRequest
from models.subject import Subject
from models.user import User, UserAcademicPath
from services.notification import create_notification


def key(value: str | None) -> str:
    value = unicodedata.normalize('NFKD', (value or '').casefold())
    return re.sub(r'[^a-z0-9]+', ' ', ''.join(c for c in value if not unicodedata.combining(c))).strip()


def _university(value: str | None) -> str:
    text = key(value)
    return 'unict' if text in ('unict', 'universita di catania', 'universita degli studi di catania') else text


def _department(value: str | None) -> str:
    text = key(value)
    if text in ('dmi', 'dipartimento di matematica e informatica'):
        return 'dmi'
    if text in ('dsbga', 'dipartimento di scienze biologiche geologiche e ambientali'):
        return 'dsbga'
    return text


def course_options(db: Session) -> list[dict]:
    result = {}
    for s in db.query(Subject).filter(Subject.is_active.is_(True), Subject.course_code.isnot(None)).all():
        if s.university_code and s.department_code and s.course_code:
            result.setdefault((key(s.university_code), key(s.department_code), key(s.course_code)), {
                'university': s.university, 'university_code': s.university_code,
                'department': s.department, 'department_code': s.department_code,
                'course': s.course, 'course_code': s.course_code, 'degree_type': s.degree_type})
    for c in db.query(AcademicCatalogCourse).all():
        result[(key(c.university_code), key(c.department_code), key(c.course_code))] = {
            'university': c.university, 'university_code': c.university_code,
            'department': c.department, 'department_code': c.department_code,
            'course': c.course, 'course_code': c.course_code, 'degree_type': c.degree_type}
    return list(result.values())


def _parent_matches(option: dict, path: UserAcademicPath) -> bool:
    same_uni = (key(path.university_code) and key(path.university_code) == key(option['university_code'])) or (
        _university(path.university) == _university(option['university']))
    same_dept = (key(path.department_code) and key(path.department_code) == key(option['department_code'])) or (
        _department(path.department) == _department(option['department']))
    return bool(same_uni and same_dept)


def resolve(db: Session, path: UserAcademicPath) -> dict | None:
    """Only exact course code/name inside a matched institution and department."""
    candidates = [option for option in course_options(db) if _parent_matches(option, path) and (
        key(path.course_code) and key(path.course_code) == key(option['course_code']) or
        key(path.course) == key(option['course']))]
    codes = {(key(c['university_code']), key(c['department_code']), key(c['course_code']))
             for c in candidates}
    return candidates[0] if len(codes) == 1 else None


def suggestions(db: Session, path: UserAcademicPath) -> list[dict]:
    matches = []
    for option in course_options(db):
        if not _parent_matches(option, path):
            continue
        score = SequenceMatcher(None, key(path.course), key(option['course'])).ratio()
        if score >= 0.55:
            matches.append((score, option))
    return [option for _, option in sorted(matches, key=lambda p: p[0], reverse=True)[:5]]


def _apply(path: UserAcademicPath, option: dict) -> None:
    for field in ('university', 'university_code', 'department', 'department_code',
                  'course', 'course_code', 'degree_type'):
        setattr(path, field, option.get(field))


def classify_path(db: Session, user: User, path: UserAcademicPath) -> AcademicCatalogRequest | None:
    """Called in the registration transaction and on subsequent path changes."""
    option = resolve(db, path)
    existing = db.query(AcademicCatalogRequest).filter(AcademicCatalogRequest.academic_path_id == path.id).first()
    if option is not None:
        _apply(path, option)
        if existing and existing.status == 'pending':
            existing.status = 'assigned'
            existing.decided_at = datetime.now(timezone.utc)
            existing.admin_note = 'Corrispondenza esatta trovata nel catalogo.'
        if path.is_primary:
            user.university, user.department, user.course = path.university, path.department, path.course
        return existing

    if existing is None:
        existing = AcademicCatalogRequest(user_id=user.id, academic_path_id=path.id,
            university=path.university, university_code=path.university_code or '',
            department=path.department, department_code=path.department_code or '',
            course=path.course, course_code=path.course_code or '')
        db.add(existing)
        db.flush()
        for admin in db.query(User).filter(User.role.in_(('admin', 'creator')), User.is_active.is_(True)).all():
            create_notification(db, user_id=admin.id, notification_type='system',
                title='Nuovo corso da associare',
                message=f'{user.first_name} {user.last_name}: {path.course} · {path.department}',
                actor_user_id=user.id, resource_type='academic_catalog_request',
                resource_id=existing.id, commit=False)
    elif existing.status != 'pending':
        existing.status = 'pending'
        existing.decided_at = None
        existing.decided_by = None
        existing.admin_note = None
    existing.university, existing.university_code = path.university, path.university_code or ''
    existing.department, existing.department_code = path.department, path.department_code or ''
    existing.course, existing.course_code = path.course, path.course_code or ''
    # User-supplied institution/department codes remain provisional until matched.
    parents = {(key(option['university_code']), key(option['department_code'])): option
               for option in course_options(db) if _parent_matches(option, path)}
    if len(parents) == 1:
        parent = next(iter(parents.values()))
        path.university_code = parent['university_code']
        path.department_code = parent['department_code']
    else:
        path.university_code = ''
        path.department_code = ''
    # A user-supplied course code cannot grant a course context before recognition.
    path.course_code = ''
    return existing


def request_data(row: AcademicCatalogRequest, user: User, path: UserAcademicPath, db: Session,
                 include_suggestions: bool = False) -> dict:
    return {'id': row.id, 'user_id': user.id, 'name': f'{user.first_name} {user.last_name}',
            'email': user.email, 'academic_path_id': row.academic_path_id,
            'university': row.university, 'university_code': row.university_code,
            'department': row.department, 'department_code': row.department_code,
            'course': row.course, 'course_code': row.course_code,
            'status': row.status, 'admin_note': row.admin_note,
            'created_at': row.created_at.isoformat() if row.created_at else None,
            'suggestions': suggestions(db, path) if include_suggestions else []}
