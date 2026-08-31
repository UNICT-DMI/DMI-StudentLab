from datetime import datetime, timezone

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from models.profile_error_report import ProfileErrorReport
from models.user import User
from schemas.profile_error_report import (
    ProfileErrorReportCreate,
    ProfileErrorReportModerationUpdate,
)


VALID_PROFILE_ERROR_CATEGORIES = {
    "personal_data",
    "biography",
    "academic_path",
    "academic_titles",
    "degree_verification",
    "subject",
    "grade_verification",
    "teacher_assignment",
    "teacher_verification",
    "availability",
    "news",
    "groups",
    "materials",
    "quiz",
    "tutor",
    "messages",
    "notifications",
    "account_security",
    "performance",
    "other",
}

VALID_PROFILE_ERROR_STATUSES = {
    "pending",
    "reviewing",
    "resolved",
    "rejected",
}


def create_profile_error_report(
    db: Session,
    current_user: User,
    payload: ProfileErrorReportCreate,
) -> ProfileErrorReport:
    if payload.category not in VALID_PROFILE_ERROR_CATEGORIES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Categoria della segnalazione non valida.",
        )

    description = payload.description.strip()

    if not description:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La descrizione è obbligatoria.",
        )

    existing_report = (
        db.query(ProfileErrorReport)
        .filter(
            ProfileErrorReport.user_id == current_user.id,
            ProfileErrorReport.category == payload.category,
            ProfileErrorReport.status.in_(
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
            detail="Hai già una segnalazione attiva per questa categoria.",
        )

    report = ProfileErrorReport(
        user_id=current_user.id,
        category=payload.category,
        description=description,
        status="pending",
        reviewed_by=None,
        reviewed_at=None,
        resolution_note="",
    )

    db.add(report)
    db.commit()
    db.refresh(report)

    return report


def get_my_profile_error_reports(
    db: Session,
    current_user: User,
) -> list[ProfileErrorReport]:
    return (
        db.query(ProfileErrorReport)
        .filter(
            ProfileErrorReport.user_id == current_user.id,
        )
        .order_by(
            ProfileErrorReport.created_at.desc(),
        )
        .all()
    )


def get_profile_error_report_by_id(
    db: Session,
    report_id: int,
    current_user: User,
) -> ProfileErrorReport:
    report = (
        db.query(ProfileErrorReport)
        .filter(
            ProfileErrorReport.id == report_id,
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
        and report.user_id != current_user.id
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Non sei autorizzato a visualizzare questa segnalazione.",
        )

    return report


def get_pending_profile_error_reports(
    db: Session,
) -> list[ProfileErrorReport]:
    return (
        db.query(ProfileErrorReport)
        .filter(
            ProfileErrorReport.status.in_(
                [
                    "pending",
                    "reviewing",
                ]
            ),
        )
        .order_by(
            ProfileErrorReport.created_at.asc(),
        )
        .all()
    )


def get_all_profile_error_reports(
    db: Session,
    report_status: str | None = None,
    category: str | None = None,
) -> list[ProfileErrorReport]:
    query = db.query(ProfileErrorReport)

    if report_status is not None:
        if report_status not in VALID_PROFILE_ERROR_STATUSES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Stato della segnalazione non valido.",
            )

        query = query.filter(
            ProfileErrorReport.status == report_status,
        )

    if category is not None:
        if category not in VALID_PROFILE_ERROR_CATEGORIES:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Categoria della segnalazione non valida.",
            )

        query = query.filter(
            ProfileErrorReport.category == category,
        )

    return (
        query
        .order_by(
            ProfileErrorReport.created_at.desc(),
        )
        .all()
    )


def moderate_profile_error_report(
    db: Session,
    report_id: int,
    moderator_user: User,
    payload: ProfileErrorReportModerationUpdate,
) -> ProfileErrorReport:
    if payload.status not in VALID_PROFILE_ERROR_STATUSES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Stato della segnalazione non valido.",
        )

    report = (
        db.query(ProfileErrorReport)
        .filter(
            ProfileErrorReport.id == report_id,
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
    report.resolution_note = payload.resolution_note.strip()
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