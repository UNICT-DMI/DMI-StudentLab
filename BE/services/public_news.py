from datetime import datetime, timezone

from sqlalchemy import or_
from sqlalchemy.orm import Session, joinedload

from models.public_news import PublicNews
from models.subject import Subject
from models.teacher_assignment import TeacherAssignment
from models.user import User
from schemas.public_news import PublicNewsCreate
from services.user_block import get_blocked_user_ids


def utc_now():
    return datetime.now(timezone.utc)


def get_public_news_by_id(db: Session, news_id: int):
    if news_id <= 0:
        return None

    return (
        db.query(PublicNews)
        .options(
            joinedload(PublicNews.author),
            joinedload(PublicNews.subject),
        )
        .filter(PublicNews.id == news_id)
        .first()
    )


def _require_active_actor(actor: User):
    if not actor.is_active:
        raise PermissionError("Account non attivo.")


def _require_subject(db: Session, subject_id: int):
    subject = (
        db.query(Subject)
        .filter(
            Subject.id == subject_id,
            Subject.is_active.is_(True),
        )
        .first()
    )

    if subject is None:
        raise ValueError("Materia non trovata.")

    return subject


def _require_teacher_subject(db: Session, teacher: User, subject_id: int):
    if teacher.role != "teacher":
        raise PermissionError("Permessi insufficienti.")

    if teacher.teacher_verification_status != "verified":
        raise PermissionError("Il profilo docente non è verificato.")

    subject = _require_subject(db, subject_id)

    assignment = (
        db.query(TeacherAssignment)
        .filter(
            TeacherAssignment.user_id == teacher.id,
            TeacherAssignment.subject_id == subject.id,
            TeacherAssignment.verification_status == "verified",
            TeacherAssignment.is_current.is_(True),
        )
        .first()
    )

    if assignment is None:
        raise PermissionError(
            "Il docente non possiede un insegnamento verificato per questa materia."
        )

    return subject


def _subject_snapshot(subject: Subject):
    return {
        "subject_id": subject.id,
        "city": None,
        "university": subject.university,
        "university_code": subject.university_code,
        "department": subject.department,
        "department_code": subject.department_code,
        "course": subject.course,
        "course_code": subject.course_code,
        "subject_name": subject.name,
    }


def _admin_snapshot(db: Session, data: PublicNewsCreate):
    if data.target_type == "all":
        return {
            "subject_id": None,
            "city": None,
            "university": None,
            "university_code": None,
            "department": None,
            "department_code": None,
            "course": None,
            "course_code": None,
            "subject_name": None,
        }

    if data.target_type == "subject":
        subject = _require_subject(db, data.subject_id)
        snapshot = _subject_snapshot(subject)
        snapshot["city"] = data.city
        return snapshot

    return {
        "subject_id": None,
        "city": data.city,
        "university": data.university,
        "university_code": data.university_code,
        "department": data.department if data.target_type in {"department", "course"} else None,
        "department_code": data.department_code if data.target_type in {"department", "course"} else None,
        "course": data.course if data.target_type == "course" else None,
        "course_code": data.course_code if data.target_type == "course" else None,
        "subject_name": None,
    }


def create_public_news(db: Session, actor: User, data: PublicNewsCreate):
    _require_active_actor(actor)

    if actor.role in {"admin", "creator"}:
        snapshot = _admin_snapshot(db, data)
    elif actor.role == "teacher":
        if data.target_type != "subject" or data.subject_id is None:
            raise PermissionError(
                "Un docente può pubblicare news soltanto per una propria materia verificata."
            )
        subject = _require_teacher_subject(db, actor, data.subject_id)
        snapshot = _subject_snapshot(subject)
        snapshot["city"] = data.city
    else:
        raise PermissionError("Gli studenti non possono pubblicare news pubbliche.")

    news = PublicNews(
        author_user_id=actor.id,
        target_type=data.target_type,
        title=data.title.strip(),
        content=data.content.strip(),
        status="active",
        **snapshot,
    )

    try:
        db.add(news)
        db.commit()
        db.refresh(news)
        return get_public_news_by_id(db, news.id)
    except Exception:
        db.rollback()
        raise


def get_public_news_feed(
    db: Session,
    *,
    viewer_user_id: int | None = None,
    search: str | None = None,
    city: str | None = None,
    university: str | None = None,
    department: str | None = None,
    course: str | None = None,
    subject_id: int | None = None,
    limit: int = 50,
    offset: int = 0,
):
    safe_limit = max(1, min(limit, 100))
    safe_offset = max(0, offset)

    query = (
        db.query(PublicNews)
        .options(
            joinedload(PublicNews.author),
            joinedload(PublicNews.subject),
        )
        .filter(PublicNews.status == "active")
    )

    if viewer_user_id is not None:
        blocked_ids = set(get_blocked_user_ids(db, viewer_user_id))
        if blocked_ids:
            query = query.filter(
                or_(
                    PublicNews.author_user_id == viewer_user_id,
                    PublicNews.author_user_id.notin_(blocked_ids),
                )
            )

    if city:
        query = query.filter(PublicNews.city.ilike(city.strip()))
    if university:
        query = query.filter(PublicNews.university.ilike(university.strip()))
    if department:
        query = query.filter(PublicNews.department.ilike(department.strip()))
    if course:
        query = query.filter(PublicNews.course.ilike(course.strip()))
    if subject_id is not None:
        query = query.filter(PublicNews.subject_id == subject_id)

    normalized_search = (search or "").strip()
    if normalized_search:
        pattern = f"%{normalized_search}%"
        query = query.join(User, User.id == PublicNews.author_user_id).filter(
            or_(
                PublicNews.title.ilike(pattern),
                PublicNews.content.ilike(pattern),
                PublicNews.city.ilike(pattern),
                PublicNews.university.ilike(pattern),
                PublicNews.department.ilike(pattern),
                PublicNews.course.ilike(pattern),
                PublicNews.subject_name.ilike(pattern),
                User.first_name.ilike(pattern),
                User.last_name.ilike(pattern),
            )
        )

    total = query.count()
    items = (
        query
        .order_by(PublicNews.created_at.desc())
        .offset(safe_offset)
        .limit(safe_limit)
        .all()
    )

    return items, total, safe_limit, safe_offset


def can_delete_public_news(news: PublicNews, actor: User):
    if news.status != "active":
        return False
    return news.author_user_id == actor.id or actor.role in {"admin", "creator"}


def can_moderate_public_news(news: PublicNews, actor: User):
    return (
        news.status == "active"
        and actor.role in {"admin", "creator"}
        and news.author_user_id != actor.id
    )


def delete_public_news(db: Session, news: PublicNews, actor: User):
    if news.status != "active":
        raise ValueError("La news non è più disponibile.")

    if not can_delete_public_news(news, actor):
        raise PermissionError("Non puoi eliminare questa news.")

    news.status = (
        "deleted_by_author"
        if news.author_user_id == actor.id
        else "removed_by_platform_moderator"
    )
    news.deleted_by_user_id = actor.id
    news.deleted_at = utc_now()
    news.updated_at = utc_now()

    db.commit()
    db.refresh(news)
    return news


def moderate_public_news(db: Session, news: PublicNews, actor: User, reason: str):
    if news.status != "active":
        raise ValueError("La news non è più disponibile.")

    if actor.role not in {"admin", "creator"}:
        raise PermissionError("Permessi insufficienti.")

    normalized_reason = reason.strip()
    if not normalized_reason:
        raise ValueError("Inserisci il motivo della moderazione.")

    news.status = "removed_by_platform_moderator"
    news.moderated_by_user_id = actor.id
    news.moderated_at = utc_now()
    news.moderation_reason = normalized_reason
    news.updated_at = utc_now()

    db.commit()
    db.refresh(news)
    return news
