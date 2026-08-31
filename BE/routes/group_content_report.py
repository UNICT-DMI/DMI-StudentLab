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

from schemas.group_content_report import (
    GroupContentReportCreate,
    GroupContentReportDetailResponse,
    GroupContentReportModerationUpdate,
    GroupContentReportResponse,
)

from services.group_content_report import (
    create_group_content_report,
    get_all_group_content_reports,
    get_group_content_report_by_id,
    get_my_group_content_reports,
    get_pending_group_content_reports,
    moderate_group_content_report,
)


router = APIRouter(
    tags=[
        "Group Content Reports",
    ],
)


@router.post(
    "/group-content-reports",
    response_model=GroupContentReportResponse,
    status_code=status.HTTP_201_CREATED,
)
def api_create_group_content_report(
    request: GroupContentReportCreate,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return create_group_content_report(
        db,
        current_user=current_user,
        payload=request,
    )


@router.get(
    "/me/group-content-reports",
    response_model=list[
        GroupContentReportDetailResponse
    ],
)
def api_my_group_content_reports(
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return get_my_group_content_reports(
        db,
        current_user=current_user,
    )


@router.get(
    "/group-content-reports/{report_id}",
    response_model=GroupContentReportDetailResponse,
)
def api_group_content_report(
    report_id: int,
    current_user: User = Depends(
        get_current_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return get_group_content_report_by_id(
        db,
        report_id=report_id,
        current_user=current_user,
    )


@router.get(
    "/admin/group-content-reports",
    response_model=list[
        GroupContentReportDetailResponse
    ],
)
def api_admin_group_content_reports(
    report_status: str | None = None,
    content_type: str | None = None,
    reason: str | None = None,
    group_id: int | None = None,
    current_user: User = Depends(
        get_admin_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return get_all_group_content_reports(
        db,
        report_status=report_status,
        content_type=content_type,
        reason=reason,
        group_id=group_id,
    )


@router.get(
    "/admin/group-content-reports/pending",
    response_model=list[
        GroupContentReportDetailResponse
    ],
)
def api_admin_pending_group_content_reports(
    current_user: User = Depends(
        get_admin_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return get_pending_group_content_reports(
        db,
    )


@router.patch(
    "/admin/group-content-reports/{report_id}/moderation",
    response_model=GroupContentReportDetailResponse,
)
def api_admin_moderate_group_content_report(
    report_id: int,
    request: GroupContentReportModerationUpdate,
    current_user: User = Depends(
        get_admin_user,
    ),
    db: Session = Depends(
        get_db,
    ),
):
    return moderate_group_content_report(
        db,
        report_id=report_id,
        moderator_user=current_user,
        payload=request,
    )