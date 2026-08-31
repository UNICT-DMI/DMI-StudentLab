from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from models.group import StudyGroup
from models.group_content_report import GroupContentReport
from models.user import User
from schemas.group_content_report import (
    GroupContentReportCreate,
    GroupContentReportModerationUpdate,
)


VALID_GROUP_CONTENT_TYPES = {
    "message",
    "material",
    "post",
}

VALID_GROUP_CONTENT_REPORT_REASONS = {
    "spam",
    "inappropriate_content",
    "harassment",
    "hate_speech",
    "misleading_information",
    "illegal_content",
    "copyright",
    "malware",
    "other",
}

VALID_GROUP_CONTENT_REPORT_STATUSES = {
    "pending",
    "reviewing",
    "resolved",
    "rejected",
}

VALID_GROUP_CONTENT_MODERATION_ACTIONS = {
    "none",
    "content_kept",
    "content_hidden",
    "content_removed",
    "user_warned",
    "user_suspended",
}


def _get_group(
    db: Session,
    group_id: int,
) -> StudyGroup:
    group = (
        db.query(StudyGroup)
        .filter(
            StudyGroup.id == group_id,
            StudyGroup.status != "deleted",
        )
        .first()
    )

    if group is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Gruppo non trovato.",
        )

    return group


def _get_author(
    db: Session,
    author_user_id: int | None,
) -> User | None:
    if author_user_id is None:
        return None

    author = (
        db.query(User)
        .filter(
            User.id == author_user_id,
        )
        .first()
    )

    if author is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Autore del contenuto non trovato.",
        )

    return author


def create_group_content_report(
    db: Session,
    current_user: User,
    payload: GroupContentReportCreate,
) -> GroupContentReport:
    if payload.content_type not in VALID_GROUP_CONTENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Tipo di contenuto non valido.",
        )

    if payload.reason not in VALID_GROUP_CONTENT_REPORT_REASONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Motivo della segnalazione non valido.",
        )

    if payload.content_id <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Identificativo del contenuto non valido.",
        )

    group = _get_group(
        db,
        payload.group_id,
    )

    author = _get_author(
        db,
        payload.author_user_id,
    )

    existing_report = (
        db.query(GroupContentReport)
        .filter(
            GroupContentReport.reporter_user_id == current_user.id,
            GroupContentReport.group_id == group.id,
            GroupContentReport.content_type == payload.content_type,
            GroupContentReport.content_id == payload.content_id,
            GroupContentReport.status.in_(
                [
                    "pending",
                    "reviewing",
                ]
            ),
        )
        .first()
    )

    if existing_report is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Hai già una segnalazione attiva per questo contenuto.",
        )

    report = GroupContentReport(
        reporter_user_id=current_user.id,
        group_id=group.id,
        content_type=payload.content_type,
        content_id=payload.content_id,
        author_user_id=(
            author.id
            if author is not None
            else None
        ),
        reason=payload.reason,
        description=payload.description.strip(),
        status="pending",
        reviewed_by=None,
        reviewed_at=None,
        moderation_action="none",
        moderation_note="",
    )

    db.add(report)
    db.commit()
    db.refresh(report)

    return report


def get_my_group_content_reports(
    db: Session,
    current_user: User,
) -> list[GroupContentReport]:
    return (
        db.query(GroupContentReport)
        .filter(
            GroupContentReport.reporter_user_id == current_user.id,
        )
        .order_by(
            GroupContentReport.created_at.desc(),
        )
        .all()
    )


def get_group_content_report_by_id(
    db: Session,
    report_id: int,
    current_user: User,
) -> GroupContentReport:
    report = (
        db.query(GroupContentReport)
        .filter(
            GroupContentReport.id == report_id,
        )
        .first()
    )

    if report is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Segnalazione contenuto non trovata.",
        )

    if (
        current_user.role not in {
            "admin",
            "creator",
        }
        and report.reporter_user_id != current_user.id
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Non sei autorizzato a visualizzare questa segnalazione.",
        )

    return report


def get_pending_group_content_reports(
    db: Session,
) -> list[GroupContentReport]:
    return (
        db.query(GroupContentReport)
        .filter(
            GroupContentReport.status.in_(
                [
                    "pending",
                    "reviewing",
                ]
            ),
        )
        .order_by(
            GroupContentReport.created_at.asc(),
        )
        .all()
    )


def get_all_group_content_reports(
    db: Session,
    report_status: str | None = None,
    content_type: str | None = None,
    reason: str | None = None,
    group_id: int | None = None,
) -> list[GroupContentReport]:
    query = db.query(
        GroupContentReport
    )

    if report_status is not None:
        if report_status not in VALID_GROUP_CONTENT_REPORT_STATUSES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Stato della segnalazione non valido.",
            )

        query = query.filter(
            GroupContentReport.status == report_status,
        )

    if content_type is not None:
        if content_type not in VALID_GROUP_CONTENT_TYPES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Tipo di contenuto non valido.",
            )

        query = query.filter(
            GroupContentReport.content_type == content_type,
        )

    if reason is not None:
        if reason not in VALID_GROUP_CONTENT_REPORT_REASONS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Motivo della segnalazione non valido.",
            )

        query = query.filter(
            GroupContentReport.reason == reason,
        )

    if group_id is not None:
        query = query.filter(
            GroupContentReport.group_id == group_id,
        )

    return (
        query
        .order_by(
            GroupContentReport.created_at.desc(),
        )
        .all()
    )


def moderate_group_content_report(
    db: Session,
    report_id: int,
    moderator_user: User,
    payload: GroupContentReportModerationUpdate,
) -> GroupContentReport:
    if payload.status not in VALID_GROUP_CONTENT_REPORT_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Stato della segnalazione non valido.",
        )

    if (
        payload.moderation_action
        not in VALID_GROUP_CONTENT_MODERATION_ACTIONS
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Azione di moderazione non valida.",
        )

    report = (
        db.query(GroupContentReport)
        .filter(
            GroupContentReport.id == report_id,
        )
        .first()
    )

    if report is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Segnalazione contenuto non trovata.",
        )

    now = datetime.now(
        timezone.utc,
    )

    report.status = payload.status
    report.moderation_action = payload.moderation_action
    report.moderation_note = payload.moderation_note.strip()
    report.reviewed_by = moderator_user.id

    if payload.status in {
        "resolved",
        "rejected",
    }:
        report.reviewed_at = now
    else:
        report.reviewed_at = None

    report.updated_at = now

    db.commit()
    db.refresh(report)

    return report