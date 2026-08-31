from datetime import (
    datetime,
    timezone,
)

from sqlalchemy.exc import (
    IntegrityError,
)

from sqlalchemy.orm import (
    Session,
)

from models.news_report import (
    NewsReport,
)

from models.user import (
    User,
)

from schemas.news_report import (
    NewsReportCreate,
    NewsReportModerationRequest,
)

from services import (
    news_crypto,
    news_store,
)

from services.group_news import (
    require_group_news_member,
)

from services.private_news_disclosure import (
    DisclosureError,
    decrypt_with_content_key,
    wrap_targets,
)


_ACTION_STATUS = {
    "hide_news": "hidden",
    "remove_news": "removed",
}


def _now():
    return datetime.now(
        timezone.utc,
    )


def _load_target(
    db: Session,
    reporter: User,
    request: NewsReportCreate,
) -> tuple[dict, str | None]:
    if request.category == "gruppi":
        require_group_news_member(
            db,
            request.group_id,
            reporter.id,
        )

        record = news_store.get_record(
            category="gruppi",
            news_id=request.news_id,
            group_id=request.group_id,
        )

        return record, None

    if request.category == "private":
        conversation = news_store.conversation_id(
            reporter.id,
            request.other_user_id,
        )

        record = news_store.get_record(
            category="private",
            news_id=request.news_id,
            conversation_id=conversation,
        )

        participants = {
            int(
                record.get(
                    "sender_id",
                    0,
                )
                or 0,
            ),
            int(
                record.get(
                    "recipient_id",
                    0,
                )
                or 0,
            ),
        }

        if reporter.id not in participants:
            raise PermissionError(
                "Non fai parte di questa conversazione.",
            )

        return record, conversation

    record = news_store.get_record(
        category="avvisi",
        news_id=request.news_id,
    )

    return record, None


def create_news_report(
    db: Session,
    reporter: User,
    request: NewsReportCreate,
) -> NewsReport:
    record, conversation = _load_target(
        db,
        reporter,
        request,
    )

    author_id = int(
        record.get(
            "author_id",
            0,
        )
        or 0,
    )

    if request.category != "private" and author_id == reporter.id:
        raise ValueError(
            "Non puoi segnalare un contenuto che hai pubblicato tu.",
        )

    disclosed_key = None
    consent_at = None

    if request.category == "private":
        content_key = (
            request.disclosed_content_key or ""
        ).strip()

        try:
            decrypt_with_content_key(
                ciphertext=record.get(
                    "ciphertext",
                    "",
                ),
                metadata=record.get(
                    "metadata",
                )
                or {},
                content_key=content_key,
            )
        except DisclosureError as exception:
            raise ValueError(
                str(
                    exception,
                ),
            )

        disclosed_key = news_crypto.encrypt_at_rest(
            content_key,
        )

        consent_at = _now()

    report = NewsReport(
        category=request.category,
        news_id=request.news_id,
        group_id=request.group_id,
        conversation_id=conversation,
        reporter_user_id=reporter.id,
        reported_user_id=author_id or None,
        reason=request.reason,
        description=request.description or None,
        status="pending",
        moderation_action="none",
        disclosed_content_key=disclosed_key,
        disclosure_consent_at=consent_at,
        created_at=_now(),
        updated_at=_now(),
    )

    db.add(
        report,
    )

    try:
        db.commit()
    except IntegrityError:
        db.rollback()

        raise ValueError(
            "Hai già segnalato questo contenuto.",
        )

    db.refresh(
        report,
    )

    return report


def get_news_report(
    db: Session,
    report_id: int,
) -> NewsReport | None:
    if report_id <= 0:
        return None

    return (
        db.query(
            NewsReport,
        )
        .filter(
            NewsReport.id
            ==
            report_id,
        )
        .first()
    )


def list_news_reports(
    db: Session,
    *,
    status: str | None = None,
    category: str | None = None,
    reporter_user_id: int | None = None,
    limit: int = 50,
    offset: int = 0,
) -> tuple[list[NewsReport], int]:
    query = db.query(
        NewsReport,
    )

    if status:
        query = query.filter(
            NewsReport.status
            ==
            status,
        )

    if reporter_user_id is not None:
        query = query.filter(
            NewsReport.reporter_user_id
            ==
            reporter_user_id,
        )

    if category:
        query = query.filter(
            NewsReport.category
            ==
            category,
        )

    total = query.count()

    items = (
        query.order_by(
            NewsReport.created_at.desc(),
        )
        .limit(
            limit,
        )
        .offset(
            offset,
        )
        .all()
    )

    return items, total


def moderate_news_report(
    db: Session,
    report: NewsReport,
    moderator: User,
    request: NewsReportModerationRequest,
) -> NewsReport:
    target_status = _ACTION_STATUS.get(
        request.action,
    )

    if target_status is not None:
        if not request.note:
            raise ValueError(
                "Per nascondere o rimuovere un contenuto serve una "
                "motivazione.",
            )

        news_store.set_status(
            category=report.category,
            news_id=report.news_id,
            status=target_status,
            moderated_by=moderator.id,
            reason=request.note,
            group_id=report.group_id,
            conversation_id=report.conversation_id,
        )

    report.status = request.status
    report.moderation_action = request.action
    report.moderation_note = request.note or None
    report.reviewed_by_user_id = moderator.id
    report.reviewed_at = _now()
    report.updated_at = _now()

    db.commit()
    db.refresh(
        report,
    )

    return report


def open_report_disclosure(
    db: Session,
    report: NewsReport,
    moderator: User,
) -> dict:
    record = news_store.get_record(
        category=report.category,
        news_id=report.news_id,
        group_id=report.group_id,
        conversation_id=report.conversation_id,
    )

    if report.category == "private":
        stored_key = report.disclosed_content_key

        if not stored_key:
            raise ValueError(
                "Questa segnalazione non contiene una chiave di "
                "disclosure: il contenuto non è leggibile.",
            )

        content_key = news_crypto.decrypt_at_rest(
            stored_key,
        )

        try:
            content = decrypt_with_content_key(
                ciphertext=record.get(
                    "ciphertext",
                    "",
                ),
                metadata=record.get(
                    "metadata",
                )
                or {},
                content_key=content_key,
            )
        except DisclosureError as exception:
            raise ValueError(
                str(
                    exception,
                ),
            )

        targets = wrap_targets(
            record.get(
                "metadata",
            )
            or {},
        )
    elif report.category == "avvisi":
        title = record.get(
            "title",
            "",
        )

        body = record.get(
            "content",
            "",
        )

        content = f"{title}\n\n{body}".strip()
        targets = []
    else:
        content = record.get(
            "content",
            "",
        )

        targets = []

    report.disclosure_opened_at = _now()
    report.disclosure_opened_by_user_id = moderator.id
    report.updated_at = _now()

    db.commit()
    db.refresh(
        report,
    )

    return {
        "report_id": report.id,
        "category": report.category,
        "news_id": report.news_id,
        "author_id": record.get(
            "author_id",
        ),
        "author_name": record.get(
            "author_name",
            "",
        ),
        "created_at": record.get(
            "created_at",
        ),
        "content": content,
        "verified": True,
        "wrap_targets": targets,
    }
