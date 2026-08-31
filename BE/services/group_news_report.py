from datetime import (
    datetime,
    timezone,
)

from sqlalchemy.orm import (
    Session,
    joinedload,
)

from models.group import (
    GroupMember,
)

from models.group_news import (
    GroupNews,
)

from models.group_news_report import (
    GroupNewsReport,
)

from models.user import (
    User,
)

from schemas.group_news_report import (
    GroupNewsPlatformModerationRequest,
    GroupNewsReportCreate,
    GroupNewsReportModerationRequest,
)

from services.group import (
    get_group_member,
    remove_group_member,
)

from services.group_news import (
    get_group_news_by_id,
    moderate_group_news,
    platform_moderate_group_news,
)


def utc_now():
    return datetime.now(
        timezone.utc,
    )


def get_group_news_report_by_id(
    db: Session,
    report_id: int,
):
    if report_id <= 0:
        return None

    return (
        db.query(
            GroupNewsReport,
        )
        .options(
            joinedload(
                GroupNewsReport.news,
            ),
            joinedload(
                GroupNewsReport.group,
            ),
            joinedload(
                GroupNewsReport.reporter,
            ),
            joinedload(
                GroupNewsReport.reported_author,
            ),
            joinedload(
                GroupNewsReport.reviewer,
            ),
        )
        .filter(
            GroupNewsReport.id ==
            report_id,
        )
        .first()
    )


def get_existing_group_news_report(
    db: Session,
    news_id: int,
    reporter_user_id: int,
):
    if (
        news_id <= 0
        or reporter_user_id <= 0
    ):
        return None

    return (
        db.query(
            GroupNewsReport,
        )
        .filter(
            GroupNewsReport.news_id ==
            news_id,
            GroupNewsReport.reporter_user_id ==
            reporter_user_id,
            GroupNewsReport.status.in_(
                [
                    "pending",
                    "under_review",
                ]
            ),
        )
        .first()
    )


def create_group_news_report(
    db: Session,
    news_id: int,
    reporter_user_id: int,
    data: GroupNewsReportCreate,
):
    news = get_group_news_by_id(
        db,
        news_id,
    )

    if news is None:
        raise ValueError(
            "News non trovata.",
        )

    if (
        news.status !=
        "active"
    ):
        raise ValueError(
            "La news non è più disponibile.",
        )

    if (
        news.author_user_id ==
        reporter_user_id
    ):
        raise ValueError(
            "Non puoi segnalare una tua news.",
        )

    reporter_member = (
        get_group_member(
            db,
            news.group_id,
            reporter_user_id,
        )
    )

    if reporter_member is None:
        raise PermissionError(
            "Non appartieni a questo gruppo.",
        )

    if (
        news.visibility ==
        "private"
        and reporter_user_id
        not in {
            news.author_user_id,
            news.recipient_user_id,
        }
    ):
        raise PermissionError(
            "Non puoi segnalare questa news privata.",
        )

    existing = (
        get_existing_group_news_report(
            db,
            news_id,
            reporter_user_id,
        )
    )

    if existing is not None:
        raise ValueError(
            "Hai già segnalato questa news.",
        )

    report = GroupNewsReport(
        news_id=news.id,
        group_id=news.group_id,
        reporter_user_id=(
            reporter_user_id
        ),
        reported_author_user_id=(
            news.author_user_id
        ),
        reason=data.reason,
        description=(
            data.description
        ),
        status="pending",
        moderation_action="none",
    )

    try:
        db.add(
            report,
        )

        db.commit()

        db.refresh(
            report,
        )

        return get_group_news_report_by_id(
            db,
            report.id,
        )

    except Exception:
        db.rollback()
        raise


def get_group_news_reports(
    db: Session,
    group_id: int,
    reviewer_user_id: int,
    status: str | None = None,
    limit: int = 50,
    offset: int = 0,
):
    member = get_group_member(
        db,
        group_id,
        reviewer_user_id,
    )

    if (
        member is None
        or member.role
        not in {
            "owner",
            "admin",
        }
    ):
        raise PermissionError(
            "Permessi insufficienti.",
        )

    safe_limit = max(
        1,
        min(
            limit,
            100,
        ),
    )

    safe_offset = max(
        0,
        offset,
    )

    query = (
        db.query(
            GroupNewsReport,
        )
        .options(
            joinedload(
                GroupNewsReport.reporter,
            ),
            joinedload(
                GroupNewsReport.reported_author,
            ),
            joinedload(
                GroupNewsReport.reviewer,
            ),
            joinedload(
                GroupNewsReport.news,
            ),
        )
        .filter(
            GroupNewsReport.group_id ==
            group_id,
        )
    )

    if status is not None:
        query = query.filter(
            GroupNewsReport.status ==
            status,
        )

    total = query.count()

    items = (
        query
        .order_by(
            GroupNewsReport.created_at.desc(),
        )
        .offset(
            safe_offset,
        )
        .limit(
            safe_limit,
        )
        .all()
    )

    return (
        items,
        total,
        safe_limit,
        safe_offset,
    )


def get_platform_group_news_reports(
    db: Session,
    reviewer_user_id: int,
    status: str | None = None,
    group_id: int | None = None,
    limit: int = 50,
    offset: int = 0,
):
    reviewer = (
        db.query(
            User,
        )
        .filter(
            User.id ==
            reviewer_user_id,
            User.role.in_(
                [
                    "admin",
                    "creator",
                ]
            ),
            User.is_active.is_(
                True,
            ),
        )
        .first()
    )

    if reviewer is None:
        raise PermissionError(
            "Permessi di moderazione insufficienti.",
        )

    safe_limit = max(
        1,
        min(
            limit,
            100,
        ),
    )

    safe_offset = max(
        0,
        offset,
    )

    query = (
        db.query(
            GroupNewsReport,
        )
        .options(
            joinedload(
                GroupNewsReport.reporter,
            ),
            joinedload(
                GroupNewsReport.reported_author,
            ),
            joinedload(
                GroupNewsReport.reviewer,
            ),
            joinedload(
                GroupNewsReport.news,
            ),
            joinedload(
                GroupNewsReport.group,
            ),
        )
    )

    if status is not None:
        query = query.filter(
            GroupNewsReport.status ==
            status,
        )

    if group_id is not None:
        query = query.filter(
            GroupNewsReport.group_id ==
            group_id,
        )

    total = query.count()

    items = (
        query
        .order_by(
            GroupNewsReport.created_at.desc(),
        )
        .offset(
            safe_offset,
        )
        .limit(
            safe_limit,
        )
        .all()
    )

    return (
        items,
        total,
        safe_limit,
        safe_offset,
    )


def _set_report_review_state(
    report: GroupNewsReport,
    reviewer_user_id: int,
    status: str,
    moderation_action: str,
    moderation_note: str | None,
):
    report.status = (
        status
    )

    report.moderation_action = (
        moderation_action
    )

    report.moderation_note = (
        moderation_note
    )

    report.reviewed_by_user_id = (
        reviewer_user_id
    )

    report.reviewed_at = (
        utc_now()
    )


def moderate_group_news_report(
    db: Session,
    report: GroupNewsReport,
    reviewer_user_id: int,
    data: GroupNewsReportModerationRequest,
):
    member = get_group_member(
        db,
        report.group_id,
        reviewer_user_id,
    )

    if (
        member is None
        or member.role
        not in {
            "owner",
            "admin",
        }
    ):
        raise PermissionError(
            "Permessi insufficienti.",
        )

    news = get_group_news_by_id(
        db,
        report.news_id,
    )

    action = (
        data.moderation_action
    )

    if (
        action in {
            "hide_news",
            "remove_news",
        }
    ):
        if news is None:
            raise ValueError(
                "News non trovata.",
            )

        if (
            news.visibility ==
            "private"
            and reviewer_user_id
            not in {
                news.author_user_id,
                news.recipient_user_id,
            }
        ):
            raise PermissionError(
                "La news privata non può essere moderata direttamente dall'amministrazione del gruppo.",
            )

        moderate_group_news(
            db,
            news,
            reviewer_user_id,
            data.moderation_note
            or "Moderazione della news.",
        )

    elif (
        action ==
        "remove_user_from_group"
    ):
        reported_author_id = (
            report.reported_author_user_id
        )

        if reported_author_id is None:
            raise ValueError(
                "Autore segnalato non disponibile.",
            )

        target_member = (
            get_group_member(
                db,
                report.group_id,
                reported_author_id,
            )
        )

        if target_member is None:
            raise ValueError(
                "L'utente non appartiene più al gruppo.",
            )

        if (
            target_member.role ==
            "owner"
        ):
            raise ValueError(
                "Il proprietario del gruppo non può essere rimosso.",
            )

        remove_group_member(
            db,
            target_member,
        )

    elif (
        action ==
        "warn_user"
    ):
        pass

    elif (
        action !=
        "none"
    ):
        raise ValueError(
            "Azione di moderazione non valida.",
        )

    try:
        _set_report_review_state(
            report,
            reviewer_user_id,
            data.status,
            action,
            data.moderation_note,
        )

        db.commit()

        db.refresh(
            report,
        )

        return get_group_news_report_by_id(
            db,
            report.id,
        )

    except Exception:
        db.rollback()
        raise


def platform_moderate_group_news_report(
    db: Session,
    report: GroupNewsReport,
    reviewer_user_id: int,
    data: GroupNewsPlatformModerationRequest,
):
    reviewer = (
        db.query(
            User,
        )
        .filter(
            User.id ==
            reviewer_user_id,
            User.role.in_(
                [
                    "admin",
                    "creator",
                ]
            ),
            User.is_active.is_(
                True,
            ),
        )
        .first()
    )

    if reviewer is None:
        raise PermissionError(
            "Permessi di moderazione insufficienti.",
        )

    news = get_group_news_by_id(
        db,
        report.news_id,
    )

    action = (
        data.moderation_action
    )

    if (
        action in {
            "hide_news",
            "remove_news",
        }
    ):
        if news is None:
            raise ValueError(
                "News non trovata.",
            )

        platform_moderate_group_news(
            db,
            news,
            reviewer_user_id,
            data.moderation_note
            or "Moderazione della piattaforma.",
        )

    elif (
        action ==
        "remove_user_from_group"
    ):
        reported_author_id = (
            report.reported_author_user_id
        )

        if reported_author_id is None:
            raise ValueError(
                "Autore segnalato non disponibile.",
            )

        target_member = (
            get_group_member(
                db,
                report.group_id,
                reported_author_id,
            )
        )

        if target_member is not None:
            if (
                target_member.role ==
                "owner"
            ):
                raise ValueError(
                    "Il proprietario del gruppo non può essere rimosso senza trasferimento di proprietà.",
                )

            remove_group_member(
                db,
                target_member,
            )

    elif (
        action in {
            "suspend_user",
            "deactivate_user",
        }
    ):
        reported_author_id = (
            report.reported_author_user_id
        )

        if reported_author_id is None:
            raise ValueError(
                "Autore segnalato non disponibile.",
            )

        target_user = (
            db.query(
                User,
            )
            .filter(
                User.id ==
                reported_author_id,
            )
            .first()
        )

        if target_user is None:
            raise ValueError(
                "Utente segnalato non trovato.",
            )

        if (
            target_user.role ==
            "creator"
        ):
            raise PermissionError(
                "Il creator non può essere sospeso tramite questa procedura.",
            )

        if (
            target_user.role ==
            "admin"
            and reviewer.role !=
            "creator"
        ):
            raise PermissionError(
                "Solo il creator può intervenire su un amministratore.",
            )

        target_user.is_active = (
            False
        )

    elif (
        action ==
        "warn_user"
    ):
        pass

    elif (
        action !=
        "none"
    ):
        raise ValueError(
            "Azione di moderazione non valida.",
        )

    try:
        _set_report_review_state(
            report,
            reviewer_user_id,
            data.status,
            action,
            data.moderation_note,
        )

        db.commit()

        db.refresh(
            report,
        )

        return get_group_news_report_by_id(
            db,
            report.id,
        )

    except Exception:
        db.rollback()
        raise


def mark_group_news_report_under_review(
    db: Session,
    report: GroupNewsReport,
    reviewer_user_id: int,
):
    if (
        report.status !=
        "pending"
    ):
        raise ValueError(
            "La segnalazione è già stata elaborata.",
        )

    report.status = (
        "under_review"
    )

    report.reviewed_by_user_id = (
        reviewer_user_id
    )

    report.reviewed_at = (
        utc_now()
    )

    try:
        db.commit()

        db.refresh(
            report,
        )

        return report

    except Exception:
        db.rollback()
        raise