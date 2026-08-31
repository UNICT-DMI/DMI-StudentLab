from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_admin_user, get_current_user
from models.user import User
from schemas.public_news_report import (
    PublicNewsReportCreate,
    PublicNewsReportModerationRequest,
    PublicNewsReportResponse,
    PublicNewsReportsResponse,
)
from services.public_news_report import (
    create_public_news_report,
    get_public_news_reports,
    moderate_public_news_report,
)


router = APIRouter(
    prefix="/public-news-reports",
    tags=["Public News Reports"],
)


@router.post(
    "/{news_id}",
    response_model=PublicNewsReportResponse,
    status_code=status.HTTP_201_CREATED,
)
def api_create_public_news_report(
    news_id: int,
    request: PublicNewsReportCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        return create_public_news_report(
            db,
            news_id=news_id,
            reporter=current_user,
            data=request,
        )
    except PermissionError as exception:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=str(exception),
        )
    except ValueError as exception:
        message = str(exception)
        code = status.HTTP_400_BAD_REQUEST

        if "non trovata" in message.lower():
            code = status.HTTP_404_NOT_FOUND
        elif "già segnalato" in message.lower():
            code = status.HTTP_409_CONFLICT

        raise HTTPException(
            status_code=code,
            detail=message,
        )


@router.get(
    "/admin",
    response_model=PublicNewsReportsResponse,
)
def api_admin_public_news_reports(
    report_status: str | None = Query(default=None, alias="status"),
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_admin_user),
):
    items, total, safe_limit, safe_offset = get_public_news_reports(
        db,
        status=report_status,
        limit=limit,
        offset=offset,
    )

    return PublicNewsReportsResponse(
        items=items,
        total=total,
        limit=safe_limit,
        offset=safe_offset,
    )


@router.patch(
    "/admin/{report_id}",
    response_model=PublicNewsReportResponse,
)
def api_admin_moderate_public_news_report(
    report_id: int,
    request: PublicNewsReportModerationRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_admin_user),
):
    try:
        return moderate_public_news_report(
            db,
            report_id=report_id,
            reviewer=current_user,
            data=request,
        )
    except PermissionError as exception:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=str(exception),
        )
    except ValueError as exception:
        raise HTTPException(
            status_code=(
                status.HTTP_404_NOT_FOUND
                if "non trovata" in str(exception).lower()
                else status.HTTP_400_BAD_REQUEST
            ),
            detail=str(exception),
        )
