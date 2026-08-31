from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query,
    status,
)

from sqlalchemy.orm import (
    Session,
)

from core.database import (
    get_db,
)

from core.security import (
    get_current_user,
)

from models.user import (
    User,
)

from schemas.group_news_report import (
    GroupNewsPlatformModerationRequest,
    GroupNewsReportCreate,
    GroupNewsReportDetailResponse,
    GroupNewsReportListResponse,
    GroupNewsReportModerationRequest,
)

from services.group import (
    get_group_member,
)

from services.group_news_report import (
    create_group_news_report,
    get_group_news_report_by_id,
    get_group_news_reports,
    get_platform_group_news_reports,
    mark_group_news_report_under_review,
    moderate_group_news_report,
    platform_moderate_group_news_report,
)


router = APIRouter(
    prefix="/group-news-reports",
    tags=[
        "Group News Reports",
    ],
)


VALID_REPORT_STATUSES = {
    "pending",
    "under_review",
    "resolved",
    "rejected",
}


def _validate_report_status(
    report_status: str | None,
):
    if (
        report_status is not None
        and report_status
        not in VALID_REPORT_STATUSES
    ):
        raise HTTPException(
            status_code=(
                status.HTTP_400_BAD_REQUEST
            ),
            detail=(
                "Stato segnalazione non valido."
            ),
        )


def _can_view_report(
    db: Session,
    report,
    current_user: User,
) -> bool:
    if (
        report.reporter_user_id
        ==
        current_user.id
    ):
        return True

    if (
        current_user.role
        in {
            "admin",
            "creator",
        }
        and current_user.is_active
    ):
        return True

    member = get_group_member(
        db,
        report.group_id,
        current_user.id,
    )

    if member is None:
        return False

    return (
        member.role
        in {
            "owner",
            "admin",
        }
    )


@router.post(
    "/news/{news_id}",
    response_model=(
        GroupNewsReportDetailResponse
    ),
    status_code=(
        status.HTTP_201_CREATED
    ),
)
def api_create_group_news_report(
    news_id: int,
    request: GroupNewsReportCreate,
    db: Session = Depends(
        get_db,
    ),
    current_user: User = Depends(
        get_current_user,
    ),
):
    if news_id <= 0:
        raise HTTPException(
            status_code=(
                status.HTTP_400_BAD_REQUEST
            ),
            detail=(
                "News non valida."
            ),
        )

    try:
        return create_group_news_report(
            db,
            news_id,
            current_user.id,
            request,
        )

    except PermissionError as exception:
        raise HTTPException(
            status_code=(
                status.HTTP_403_FORBIDDEN
            ),
            detail=str(
                exception,
            ),
        )

    except ValueError as exception:
        message = str(
            exception,
        )

        if (
            message
            ==
            "News non trovata."
        ):
            raise HTTPException(
                status_code=(
                    status.HTTP_404_NOT_FOUND
                ),
                detail=message,
            )

        if (
            message
            ==
            "Hai già segnalato questa news."
        ):
            raise HTTPException(
                status_code=(
                    status.HTTP_409_CONFLICT
                ),
                detail=message,
            )

        raise HTTPException(
            status_code=(
                status.HTTP_400_BAD_REQUEST
            ),
            detail=message,
        )

    except Exception:
        db.rollback()

        raise HTTPException(
            status_code=(
                status.HTTP_500_INTERNAL_SERVER_ERROR
            ),
            detail=(
                "Impossibile inviare la segnalazione."
            ),
        )


@router.get(
    "/groups/{group_id}",
    response_model=(
        GroupNewsReportListResponse
    ),
)
def api_get_group_news_reports(
    group_id: int,
    report_status: str | None = Query(
        default=None,
        alias="status",
    ),
    limit: int = Query(
        default=50,
        ge=1,
        le=100,
    ),
    offset: int = Query(
        default=0,
        ge=0,
    ),
    db: Session = Depends(
        get_db,
    ),
    current_user: User = Depends(
        get_current_user,
    ),
):
    if group_id <= 0:
        raise HTTPException(
            status_code=(
                status.HTTP_400_BAD_REQUEST
            ),
            detail=(
                "Gruppo non valido."
            ),
        )

    _validate_report_status(
        report_status,
    )

    try:
        (
            items,
            total,
            safe_limit,
            safe_offset,
        ) = get_group_news_reports(
            db,
            group_id,
            current_user.id,
            report_status,
            limit,
            offset,
        )

        return GroupNewsReportListResponse(
            items=items,
            total=total,
            limit=safe_limit,
            offset=safe_offset,
        )

    except PermissionError as exception:
        raise HTTPException(
            status_code=(
                status.HTTP_403_FORBIDDEN
            ),
            detail=str(
                exception,
            ),
        )

    except ValueError as exception:
        raise HTTPException(
            status_code=(
                status.HTTP_400_BAD_REQUEST
            ),
            detail=str(
                exception,
            ),
        )

    except Exception:
        raise HTTPException(
            status_code=(
                status.HTTP_500_INTERNAL_SERVER_ERROR
            ),
            detail=(
                "Impossibile recuperare le segnalazioni."
            ),
        )


@router.get(
    "/platform",
    response_model=(
        GroupNewsReportListResponse
    ),
)
def api_get_platform_group_news_reports(
    report_status: str | None = Query(
        default=None,
        alias="status",
    ),
    group_id: int | None = Query(
        default=None,
        gt=0,
    ),
    limit: int = Query(
        default=50,
        ge=1,
        le=100,
    ),
    offset: int = Query(
        default=0,
        ge=0,
    ),
    db: Session = Depends(
        get_db,
    ),
    current_user: User = Depends(
        get_current_user,
    ),
):
    _validate_report_status(
        report_status,
    )

    try:
        (
            items,
            total,
            safe_limit,
            safe_offset,
        ) = (
            get_platform_group_news_reports(
                db,
                current_user.id,
                report_status,
                group_id,
                limit,
                offset,
            )
        )

        return GroupNewsReportListResponse(
            items=items,
            total=total,
            limit=safe_limit,
            offset=safe_offset,
        )

    except PermissionError as exception:
        raise HTTPException(
            status_code=(
                status.HTTP_403_FORBIDDEN
            ),
            detail=str(
                exception,
            ),
        )

    except ValueError as exception:
        raise HTTPException(
            status_code=(
                status.HTTP_400_BAD_REQUEST
            ),
            detail=str(
                exception,
            ),
        )

    except Exception:
        raise HTTPException(
            status_code=(
                status.HTTP_500_INTERNAL_SERVER_ERROR
            ),
            detail=(
                "Impossibile recuperare le segnalazioni della piattaforma."
            ),
        )


@router.get(
    "/{report_id}",
    response_model=(
        GroupNewsReportDetailResponse
    ),
)
def api_get_group_news_report(
    report_id: int,
    db: Session = Depends(
        get_db,
    ),
    current_user: User = Depends(
        get_current_user,
    ),
):
    if report_id <= 0:
        raise HTTPException(
            status_code=(
                status.HTTP_400_BAD_REQUEST
            ),
            detail=(
                "Segnalazione non valida."
            ),
        )

    report = (
        get_group_news_report_by_id(
            db,
            report_id,
        )
    )

    if report is None:
        raise HTTPException(
            status_code=(
                status.HTTP_404_NOT_FOUND
            ),
            detail=(
                "Segnalazione non trovata."
            ),
        )

    if not _can_view_report(
        db,
        report,
        current_user,
    ):
        raise HTTPException(
            status_code=(
                status.HTTP_403_FORBIDDEN
            ),
            detail=(
                "Non puoi visualizzare questa segnalazione."
            ),
        )

    return report


@router.post(
    "/{report_id}/under-review",
    response_model=(
        GroupNewsReportDetailResponse
    ),
)
def api_mark_group_news_report_under_review(
    report_id: int,
    db: Session = Depends(
        get_db,
    ),
    current_user: User = Depends(
        get_current_user,
    ),
):
    if report_id <= 0:
        raise HTTPException(
            status_code=(
                status.HTTP_400_BAD_REQUEST
            ),
            detail=(
                "Segnalazione non valida."
            ),
        )

    report = (
        get_group_news_report_by_id(
            db,
            report_id,
        )
    )

    if report is None:
        raise HTTPException(
            status_code=(
                status.HTTP_404_NOT_FOUND
            ),
            detail=(
                "Segnalazione non trovata."
            ),
        )

    try:
        return (
            mark_group_news_report_under_review(
                db,
                report,
                current_user.id,
            )
        )

    except PermissionError as exception:
        raise HTTPException(
            status_code=(
                status.HTTP_403_FORBIDDEN
            ),
            detail=str(
                exception,
            ),
        )

    except ValueError as exception:
        raise HTTPException(
            status_code=(
                status.HTTP_400_BAD_REQUEST
            ),
            detail=str(
                exception,
            ),
        )

    except Exception:
        db.rollback()

        raise HTTPException(
            status_code=(
                status.HTTP_500_INTERNAL_SERVER_ERROR
            ),
            detail=(
                "Impossibile aggiornare la segnalazione."
            ),
        )


@router.patch(
    "/{report_id}/moderate",
    response_model=(
        GroupNewsReportDetailResponse
    ),
)
def api_moderate_group_news_report(
    report_id: int,
    request: (
        GroupNewsReportModerationRequest
    ),
    db: Session = Depends(
        get_db,
    ),
    current_user: User = Depends(
        get_current_user,
    ),
):
    if report_id <= 0:
        raise HTTPException(
            status_code=(
                status.HTTP_400_BAD_REQUEST
            ),
            detail=(
                "Segnalazione non valida."
            ),
        )

    report = (
        get_group_news_report_by_id(
            db,
            report_id,
        )
    )

    if report is None:
        raise HTTPException(
            status_code=(
                status.HTTP_404_NOT_FOUND
            ),
            detail=(
                "Segnalazione non trovata."
            ),
        )

    try:
        return moderate_group_news_report(
            db,
            report,
            current_user.id,
            request,
        )

    except PermissionError as exception:
        raise HTTPException(
            status_code=(
                status.HTTP_403_FORBIDDEN
            ),
            detail=str(
                exception,
            ),
        )

    except ValueError as exception:
        raise HTTPException(
            status_code=(
                status.HTTP_400_BAD_REQUEST
            ),
            detail=str(
                exception,
            ),
        )

    except Exception:
        db.rollback()

        raise HTTPException(
            status_code=(
                status.HTTP_500_INTERNAL_SERVER_ERROR
            ),
            detail=(
                "Impossibile gestire la segnalazione."
            ),
        )


@router.patch(
    "/{report_id}/platform-moderate",
    response_model=(
        GroupNewsReportDetailResponse
    ),
)
def api_platform_moderate_group_news_report(
    report_id: int,
    request: (
        GroupNewsPlatformModerationRequest
    ),
    db: Session = Depends(
        get_db,
    ),
    current_user: User = Depends(
        get_current_user,
    ),
):
    if report_id <= 0:
        raise HTTPException(
            status_code=(
                status.HTTP_400_BAD_REQUEST
            ),
            detail=(
                "Segnalazione non valida."
            ),
        )

    report = (
        get_group_news_report_by_id(
            db,
            report_id,
        )
    )

    if report is None:
        raise HTTPException(
            status_code=(
                status.HTTP_404_NOT_FOUND
            ),
            detail=(
                "Segnalazione non trovata."
            ),
        )

    try:
        return (
            platform_moderate_group_news_report(
                db,
                report,
                current_user.id,
                request,
            )
        )

    except PermissionError as exception:
        raise HTTPException(
            status_code=(
                status.HTTP_403_FORBIDDEN
            ),
            detail=str(
                exception,
            ),
        )

    except ValueError as exception:
        raise HTTPException(
            status_code=(
                status.HTTP_400_BAD_REQUEST
            ),
            detail=str(
                exception,
            ),
        )

    except Exception:
        db.rollback()

        raise HTTPException(
            status_code=(
                status.HTTP_500_INTERNAL_SERVER_ERROR
            ),
            detail=(
                "Impossibile completare la moderazione della piattaforma."
            ),
        )