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

from schemas.group_report import (
    GroupReportCreate,
    GroupReportDetailResponse,
    GroupReportModerationUpdate,
    GroupReportResponse,
)

from services.group_report import (
    create_group_report,
    get_all_group_reports,
    get_group_report_by_id,
    get_my_group_reports,
    get_pending_group_reports,
    moderate_group_report,
)


router = APIRouter(
    tags=[
        "Group Reports",
    ],
)


@router.post(
    "/group-reports",
    response_model=GroupReportResponse,
    status_code=status.HTTP_201_CREATED,
)
def api_create_group_report(
    request: GroupReportCreate,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return create_group_report(
        db,
        current_user=current_user,
        payload=request,
    )


@router.get(
    "/me/group-reports",
    response_model=list[
        GroupReportDetailResponse
    ],
)
def api_my_group_reports(
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return get_my_group_reports(
        db,
        current_user=current_user,
    )


@router.get(
    "/group-reports/{report_id}",
    response_model=GroupReportDetailResponse,
)
def api_group_report(
    report_id: int,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return get_group_report_by_id(
        db,
        report_id=report_id,
        current_user=current_user,
    )


@router.get(
    "/admin/group-reports",
    response_model=list[
        GroupReportDetailResponse
    ],
)
def api_admin_group_reports(
    report_status: str | None = None,
    reason: str | None = None,
    current_user: User = Depends(
        get_admin_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return get_all_group_reports(
        db,
        report_status=report_status,
        reason=reason,
    )


@router.get(
    "/admin/group-reports/pending",
    response_model=list[
        GroupReportDetailResponse
    ],
)
def api_admin_pending_group_reports(
    current_user: User = Depends(
        get_admin_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return get_pending_group_reports(
        db,
    )


@router.patch(
    "/admin/group-reports/{report_id}/moderation",
    response_model=GroupReportDetailResponse,
)
def api_admin_moderate_group_report(
    report_id: int,
    request: GroupReportModerationUpdate,
    current_user: User = Depends(
        get_admin_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return moderate_group_report(
        db,
        report_id=report_id,
        moderator_user=current_user,
        payload=request,
    )