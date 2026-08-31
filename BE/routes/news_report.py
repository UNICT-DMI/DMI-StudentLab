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
    get_admin_user,
    get_current_user,
)

from models.user import (
    User,
)

from schemas.news_report import (
    NewsReportCreate,
    NewsReportDisclosureResponse,
    NewsReportListResponse,
    NewsReportModerationRequest,
    NewsReportResponse,
)

from services import (
    news_store,
)

from services.news_report import (
    create_news_report,
    get_news_report,
    list_news_reports,
    moderate_news_report,
    open_report_disclosure,
)


router = APIRouter(
    tags=["Segnalazioni news"],
)


def _require_report(
    db: Session,
    report_id: int,
):
    report = get_news_report(
        db,
        report_id,
    )

    if report is None:
        raise HTTPException(
            status_code=(
                status.HTTP_404_NOT_FOUND
            ),
            detail="Segnalazione non trovata.",
        )

    return report


@router.post(
    "/news-reports",
    response_model=NewsReportResponse,
    status_code=status.HTTP_201_CREATED,
)
def api_create_news_report(
    request: NewsReportCreate,
    db: Session = Depends(
        get_db,
    ),
    current_user: User = Depends(
        get_current_user,
    ),
):
    try:
        return create_news_report(
            db,
            current_user,
            request,
        )
    except news_store.NewsNotFound as exception:
        raise HTTPException(
            status_code=(
                status.HTTP_404_NOT_FOUND
            ),
            detail=str(
                exception,
            ),
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


@router.get(
    "/me/news-reports",
    response_model=NewsReportListResponse,
)
def api_list_own_news_reports(
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
    items, total = list_news_reports(
        db,
        reporter_user_id=current_user.id,
        limit=limit,
        offset=offset,
    )

    return NewsReportListResponse(
        items=[
            NewsReportResponse.model_validate(
                item,
            )
            for item in items
        ],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.get(
    "/admin/news-reports",
    response_model=NewsReportListResponse,
)
def api_list_news_reports(
    report_status: str | None = Query(
        default=None,
        alias="status",
        max_length=30,
    ),
    category: str | None = Query(
        default=None,
        max_length=20,
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
        get_admin_user,
    ),
):
    items, total = list_news_reports(
        db,
        status=report_status,
        category=category,
        limit=limit,
        offset=offset,
    )

    return NewsReportListResponse(
        items=[
            NewsReportResponse.model_validate(
                item,
            )
            for item in items
        ],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.patch(
    "/admin/news-reports/{report_id}",
    response_model=NewsReportResponse,
)
def api_moderate_news_report(
    report_id: int,
    request: NewsReportModerationRequest,
    db: Session = Depends(
        get_db,
    ),
    current_user: User = Depends(
        get_admin_user,
    ),
):
    report = _require_report(
        db,
        report_id,
    )

    try:
        return moderate_news_report(
            db,
            report,
            current_user,
            request,
        )
    except news_store.NewsNotFound as exception:
        raise HTTPException(
            status_code=(
                status.HTTP_404_NOT_FOUND
            ),
            detail=str(
                exception,
            ),
        )
    except (
        news_store.NewsStoreError,
        ValueError,
    ) as exception:
        db.rollback()

        raise HTTPException(
            status_code=(
                status.HTTP_400_BAD_REQUEST
            ),
            detail=str(
                exception,
            ),
        )


@router.get(
    "/admin/news-reports/{report_id}/disclosure",
    response_model=NewsReportDisclosureResponse,
)
def api_open_news_report_disclosure(
    report_id: int,
    db: Session = Depends(
        get_db,
    ),
    current_user: User = Depends(
        get_admin_user,
    ),
):
    report = _require_report(
        db,
        report_id,
    )

    try:
        return NewsReportDisclosureResponse(
            **open_report_disclosure(
                db,
                report,
                current_user,
            ),
        )
    except news_store.NewsNotFound as exception:
        raise HTTPException(
            status_code=(
                status.HTTP_404_NOT_FOUND
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
