from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from models.group import StudyGroup
from models.group_report import GroupReport
from models.user import User
from schemas.group_report import (
    GroupReportCreate,
    GroupReportModerationUpdate,
)


VALID_GROUP_REPORT_REASONS = {
    "spam",
    "inappropriate_content",
    "harassment",
    "hate_speech",
    "misleading_information",
    "illegal_content",
    "impersonation",
    "other",
}

VALID_GROUP_REPORT_STATUSES = {
    "pending",
    "reviewing",
    "resolved",
    "rejected",
}


def create_group_report(
    db: Session,
    current_user: User,
    payload: GroupReportCreate,
) -> GroupReport:
    if payload.reason not in VALID_GROUP_REPORT_REASONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Motivo della segnalazione non valido.",
        )

    group = (
        db.query(StudyGroup)
        .filter(
            StudyGroup.id == payload.group_id,
            StudyGroup.status != "deleted",
        )
        .first()
    )

    if group is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Gruppo non trovato.",
        )

    existing_report = (
        db.query(GroupReport)
        .filter(
            GroupReport.reporter_user_id == current_user.id,
            GroupReport.group_id == group.id,
            GroupReport.status.in_(
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
            detail="Hai già una segnalazione attiva per questo gruppo.",
        )

    report = GroupReport(
        reporter_user_id=current_user.id,
        group_id=group.id,
        reason=payload.reason,
        description=payload.description.strip(),
        status="pending",
        reviewed_by=None,
        reviewed_at=None,
        moderation_note="",
    )

    db.add(report)
    db.commit()
    db.refresh(report)

    return report


def get_my_group_reports(
    db: Session,
    current_user: User,
) -> list[GroupReport]:
    return (
        db.query(GroupReport)
        .filter(
            GroupReport.reporter_user_id == current_user.id,
        )
        .order_by(
            GroupReport.created_at.desc(),
        )
        .all()
    )


def get_group_report_by_id(
    db: Session,
    report_id: int,
    current_user: User,
) -> GroupReport:
    report = (
        db.query(GroupReport)
        .filter(
            GroupReport.id == report_id,
        )
        .first()
    )

    if report is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Segnalazione gruppo non trovata.",
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


def get_pending_group_reports(
    db: Session,
) -> list[GroupReport]:
    return (
        db.query(GroupReport)
        .filter(
            GroupReport.status.in_(
                [
                    "pending",
                    "reviewing",
                ]
            ),
        )
        .order_by(
            GroupReport.created_at.asc(),
        )
        .all()
    )


def get_all_group_reports(
    db: Session,
    report_status: str | None = None,
    reason: str | None = None,
) -> list[GroupReport]:
    query = db.query(GroupReport)

    if report_status is not None:
        if report_status not in VALID_GROUP_REPORT_STATUSES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Stato della segnalazione non valido.",
            )

        query = query.filter(
            GroupReport.status == report_status,
        )

    if reason is not None:
        if reason not in VALID_GROUP_REPORT_REASONS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Motivo della segnalazione non valido.",
            )

        query = query.filter(
            GroupReport.reason == reason,
        )

    return (
        query
        .order_by(
            GroupReport.created_at.desc(),
        )
        .all()
    )


def moderate_group_report(
    db: Session,
    report_id: int,
    moderator_user: User,
    payload: GroupReportModerationUpdate,
) -> GroupReport:
    if payload.status not in VALID_GROUP_REPORT_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Stato della segnalazione non valido.",
        )

    report = (
        db.query(GroupReport)
        .filter(
            GroupReport.id == report_id,
        )
        .first()
    )

    if report is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Segnalazione gruppo non trovata.",
        )

    now = datetime.now(
        timezone.utc,
    )

    report.status = payload.status
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