from datetime import datetime, timezone

from sqlalchemy.orm import Session

from models.public_news_report import PublicNewsReport
from models.user import User
from schemas.public_news_report import PublicNewsReportCreate, PublicNewsReportModerationRequest
from services.public_news import get_public_news_by_id, moderate_public_news


def utc_now():
    return datetime.now(timezone.utc)


def create_public_news_report(
    db: Session,
    *,
    news_id: int,
    reporter: User,
    data: PublicNewsReportCreate,
):
    news = get_public_news_by_id(db, news_id)

    if news is None:
        raise ValueError("News non trovata.")

    if news.status != "active":
        raise ValueError("La news non è più disponibile.")

    if news.author_user_id == reporter.id:
        raise ValueError("Non puoi segnalare una tua news.")

    existing = (
        db.query(PublicNewsReport)
        .filter(
            PublicNewsReport.news_id == news.id,
            PublicNewsReport.reporter_user_id == reporter.id,
        )
        .first()
    )

    if existing is not None:
        raise ValueError("Hai già segnalato questa news.")

    report = PublicNewsReport(
        news_id=news.id,
        reporter_user_id=reporter.id,
        reported_author_user_id=news.author_user_id,
        reason=data.reason,
        description=data.description.strip() or None,
        status="pending",
        moderation_action="none",
    )

    try:
        db.add(report)
        db.commit()
        db.refresh(report)
        return report
    except Exception:
        db.rollback()
        raise


def get_public_news_reports(
    db: Session,
    *,
    status: str | None = None,
    limit: int = 50,
    offset: int = 0,
):
    safe_limit = max(1, min(limit, 100))
    safe_offset = max(0, offset)

    query = db.query(PublicNewsReport)

    if status:
        query = query.filter(PublicNewsReport.status == status)

    total = query.count()
    items = (
        query
        .order_by(PublicNewsReport.created_at.desc())
        .offset(safe_offset)
        .limit(safe_limit)
        .all()
    )

    return items, total, safe_limit, safe_offset


def moderate_public_news_report(
    db: Session,
    *,
    report_id: int,
    reviewer: User,
    data: PublicNewsReportModerationRequest,
):
    if reviewer.role not in {"admin", "creator"} or not reviewer.is_active:
        raise PermissionError("Permessi insufficienti.")

    report = (
        db.query(PublicNewsReport)
        .filter(PublicNewsReport.id == report_id)
        .first()
    )

    if report is None:
        raise ValueError("Segnalazione non trovata.")

    if data.action == "remove_news":
        news = get_public_news_by_id(db, report.news_id)
        if news is not None and news.status == "active":
            moderate_public_news(
                db,
                news,
                reviewer,
                data.note.strip() or "Contenuto rimosso in seguito a segnalazione.",
            )

    if data.action in {"suspend_user", "deactivate_user"}:
        if report.reported_author_user_id is not None:
            user = (
                db.query(User)
                .filter(User.id == report.reported_author_user_id)
                .first()
            )
            if user is not None and user.id != reviewer.id:
                user.is_active = False

    report.status = data.status
    report.moderation_action = data.action
    report.moderation_note = data.note.strip() or None
    report.reviewed_by_user_id = reviewer.id
    report.reviewed_at = utc_now()
    report.updated_at = utc_now()

    db.commit()
    db.refresh(report)
    return report
