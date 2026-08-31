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

from schemas.profile_error_report import (
    ProfileErrorReportCreate,
    ProfileErrorReportDetailResponse,
    ProfileErrorReportModerationUpdate,
    ProfileErrorReportResponse,
)

from services.profile_error_report import (
    create_profile_error_report,
    get_all_profile_error_reports,
    get_my_profile_error_reports,
    get_pending_profile_error_reports,
    get_profile_error_report_by_id,
    moderate_profile_error_report,
)


router = APIRouter(
    tags=[
        "Profile Error Reports",
    ],
)


@router.post(
    "/me/profile-error-reports",
    response_model=ProfileErrorReportResponse,
    status_code=status.HTTP_201_CREATED,
)
def api_create_profile_error_report(
    request: ProfileErrorReportCreate,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return create_profile_error_report(
        db,
        current_user=current_user,
        payload=request,
    )


@router.get(
    "/me/profile-error-reports",
    response_model=list[
        ProfileErrorReportDetailResponse
    ],
)
def api_my_profile_error_reports(
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return get_my_profile_error_reports(
        db,
        current_user=current_user,
    )


@router.get(
    "/profile-error-reports/{report_id}",
    response_model=ProfileErrorReportDetailResponse,
)
def api_profile_error_report(
    report_id: int,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return get_profile_error_report_by_id(
        db,
        report_id=report_id,
        current_user=current_user,
    )


@router.get(
    "/admin/profile-error-reports",
    response_model=list[
        ProfileErrorReportDetailResponse
    ],
)
def api_admin_profile_error_reports(
    report_status: str | None = None,
    category: str | None = None,
    current_user: User = Depends(
        get_admin_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return get_all_profile_error_reports(
        db,
        report_status=report_status,
        category=category,
    )


@router.get(
    "/admin/profile-error-reports/pending",
    response_model=list[
        ProfileErrorReportDetailResponse
    ],
)
def api_admin_pending_profile_error_reports(
    current_user: User = Depends(
        get_admin_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return get_pending_profile_error_reports(
        db,
    )


@router.patch(
    "/admin/profile-error-reports/{report_id}/moderation",
    response_model=ProfileErrorReportDetailResponse,
)
def api_admin_moderate_profile_error_report(
    report_id: int,
    request: ProfileErrorReportModerationUpdate,
    current_user: User = Depends(
        get_admin_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return moderate_profile_error_report(
        db,
        report_id=report_id,
        moderator_user=current_user,
        payload=request,
    )