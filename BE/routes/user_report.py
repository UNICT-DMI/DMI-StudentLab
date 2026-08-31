from fastapi import (
    APIRouter,
    Depends,
    status,
)

from sqlalchemy.orm import Session

from core.database import get_db
from core.security import (
    get_admin_user,
    get_current_user,
)

from models.user import User

from schemas.user_report import (
    UserReportCreate,
    UserReportDetailResponse,
    UserReportModerationUpdate,
    UserReportResponse,
)

from services.user_report import (
    create_user_report,
    deactivate_user_report,
    get_all_user_reports,
    get_my_user_reports,
    get_pending_user_reports,
    get_user_report_by_id,
    moderate_user_report,
)


router = APIRouter(
    tags=[
        "User Reports",
    ],
)


@router.post(
    "/user-reports",
    response_model=UserReportResponse,
    status_code=status.HTTP_201_CREATED,
)
def api_create_user_report(
    request: UserReportCreate,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return create_user_report(
        db,
        reporter_user=current_user,
        payload=request,
    )


@router.get(
    "/me/user-reports",
    response_model=list[
        UserReportDetailResponse
    ],
)
def api_my_user_reports(
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return get_my_user_reports(
        db,
        current_user=current_user,
    )


@router.get(
    "/user-reports/{report_id}",
    response_model=UserReportDetailResponse,
)
def api_user_report(
    report_id: int,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return get_user_report_by_id(
        db,
        report_id=report_id,
        current_user=current_user,
    )


@router.delete(
    "/user-reports/{report_id}",
    response_model=UserReportResponse,
)
def api_deactivate_user_report(
    report_id: int,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return deactivate_user_report(
        db,
        report_id=report_id,
        current_user=current_user,
    )


@router.get(
    "/admin/user-reports",
    response_model=list[
        UserReportDetailResponse
    ],
)
def api_admin_user_reports(
    report_status: str | None = None,
    current_user: User = Depends(
        get_admin_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return get_all_user_reports(
        db,
        report_status=report_status,
    )


@router.get(
    "/admin/user-reports/pending",
    response_model=list[
        UserReportDetailResponse
    ],
)
def api_admin_pending_user_reports(
    current_user: User = Depends(
        get_admin_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return get_pending_user_reports(
        db,
    )


@router.patch(
    "/admin/user-reports/{report_id}/moderation",
    response_model=UserReportDetailResponse,
)
def api_admin_moderate_user_report(
    report_id: int,
    request: UserReportModerationUpdate,
    current_user: User = Depends(
        get_admin_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return moderate_user_report(
        db,
        report_id=report_id,
        moderator_user=current_user,
        payload=request,
    )