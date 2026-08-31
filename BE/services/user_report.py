from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from models.user import User
from models.user_report import UserReport
from schemas.user_report import (
    UserReportCreate,
    UserReportModerationUpdate,
)


VALID_USER_REPORT_REASONS = {
    "fake_profile",
    "false_information",
    "inappropriate_behavior",
    "spam",
    "offensive_content",
    "harassment",
    "impersonation",
    "other",
}

VALID_USER_REPORT_STATUSES = {
    "pending",
    "reviewing",
    "resolved",
    "rejected",
}


def create_user_report(
    db: Session,
    reporter_user: User,
    payload: UserReportCreate,
) -> UserReport:
    if reporter_user.id == payload.reported_user_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Non puoi segnalare il tuo stesso profilo.",
        )

    if payload.reason not in VALID_USER_REPORT_REASONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Motivo della segnalazione non valido.",
        )

    reported_user = (
        db.query(User)
        .filter(
            User.id == payload.reported_user_id,
            User.is_active.is_(True),
        )
        .first()
    )

    if reported_user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Utente da segnalare non trovato.",
        )

    existing_report = (
        db.query(UserReport)
        .filter(
            UserReport.reporter_user_id == reporter_user.id,
            UserReport.reported_user_id == payload.reported_user_id,
            UserReport.status.in_(
                [
                    "pending",
                    "reviewing",
                ]
            ),
            UserReport.is_active.is_(True),
        )
        .first()
    )

    if existing_report is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Hai già una segnalazione attiva per questo profilo.",
        )

    report = UserReport(
        reporter_user_id=reporter_user.id,
        reported_user_id=payload.reported_user_id,
        reason=payload.reason,
        description=payload.description.strip(),
        status="pending",
        reviewed_by=None,
        reviewed_at=None,
        moderation_note="",
        is_active=True,
    )

    db.add(report)
    db.commit()
    db.refresh(report)

    return report


def get_my_user_reports(
    db: Session,
    current_user: User,
) -> list[UserReport]:
    return (
        db.query(UserReport)
        .filter(
            UserReport.reporter_user_id == current_user.id,
            UserReport.is_active.is_(True),
        )
        .order_by(
            UserReport.created_at.desc(),
        )
        .all()
    )


def get_user_report_by_id(
    db: Session,
    report_id: int,
    current_user: User,
) -> UserReport:
    report = (
        db.query(UserReport)
        .filter(
            UserReport.id == report_id,
            UserReport.is_active.is_(True),
        )
        .first()
    )

    if report is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Segnalazione non trovata.",
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


def get_pending_user_reports(
    db: Session,
) -> list[UserReport]:
    return (
        db.query(UserReport)
        .filter(
            UserReport.status.in_(
                [
                    "pending",
                    "reviewing",
                ]
            ),
            UserReport.is_active.is_(True),
        )
        .order_by(
            UserReport.created_at.asc(),
        )
        .all()
    )


def get_all_user_reports(
    db: Session,
    report_status: str | None = None,
) -> list[UserReport]:
    query = (
        db.query(UserReport)
        .filter(
            UserReport.is_active.is_(True),
        )
    )

    if report_status is not None:
        if report_status not in VALID_USER_REPORT_STATUSES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Stato della segnalazione non valido.",
            )

        query = query.filter(
            UserReport.status == report_status,
        )

    return (
        query
        .order_by(
            UserReport.created_at.desc(),
        )
        .all()
    )


def moderate_user_report(
    db: Session,
    report_id: int,
    moderator_user: User,
    payload: UserReportModerationUpdate,
) -> UserReport:
    if payload.status not in VALID_USER_REPORT_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Stato della segnalazione non valido.",
        )

    report = (
        db.query(UserReport)
        .filter(
            UserReport.id == report_id,
            UserReport.is_active.is_(True),
        )
        .first()
    )

    if report is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Segnalazione non trovata.",
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


def deactivate_user_report(
    db: Session,
    report_id: int,
    current_user: User,
) -> UserReport:
    report = (
        db.query(UserReport)
        .filter(
            UserReport.id == report_id,
            UserReport.is_active.is_(True),
        )
        .first()
    )

    if report is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Segnalazione non trovata.",
        )

    if report.reporter_user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Non sei autorizzato a rimuovere questa segnalazione.",
        )

    if report.status not in {
        "pending",
        "reviewing",
    }:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Una segnalazione già conclusa non può essere rimossa.",
        )

    report.is_active = False
    report.updated_at = datetime.now(
        timezone.utc,
    )

    db.commit()
    db.refresh(report)

    return report