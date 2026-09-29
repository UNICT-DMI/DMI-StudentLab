from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import ValidationError
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_current_user
from models.user import User
from schemas.question_moderation import (
    QuestionModerationResolution,
    QuestionModerationResponse,
    QuestionProposalBatchCreate,
    QuestionProposalCreate,
    QuestionProposalUpdate,
    QuestionReportCreate,
    QuestionTemporaryAttachmentCleanupRequest,
)
from services.question_moderation import (
    claim_moderation_item,
    cleanup_temporary_attachments,
    create_question_proposal,
    create_question_proposals,
    create_question_report,
    delete_my_pending_proposal,
    get_moderation_item,
    list_moderation_items,
    list_my_proposals,
    require_moderation_access,
    resolve_moderation_item,
    serialize_moderation_item,
    update_proposal_payload,
)


router = APIRouter(
    prefix="/question-moderation",
    tags=["question-moderation"],
)


@router.post(
    "/reports",
    response_model=QuestionModerationResponse,
    status_code=status.HTTP_201_CREATED,
)
def api_create_question_report(
    request: QuestionReportCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        item = create_question_report(db, current_user, request)
        return serialize_moderation_item(db, item)
    except FileExistsError as exception:
        raise HTTPException(status_code=409, detail=str(exception)) from exception
    except ValueError as exception:
        raise HTTPException(status_code=404, detail=str(exception)) from exception


@router.post(
    "/proposals",
    response_model=QuestionModerationResponse,
    status_code=status.HTTP_201_CREATED,
)
def api_create_question_proposal(
    request: QuestionProposalCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        item = create_question_proposal(db, current_user, request)
        return serialize_moderation_item(db, item)
    except PermissionError as exception:
        raise HTTPException(status_code=403, detail=str(exception)) from exception
    except ValueError as exception:
        raise HTTPException(status_code=400, detail=str(exception)) from exception


@router.post(
    "/proposals/batch",
    response_model=list[QuestionModerationResponse],
    status_code=status.HTTP_201_CREATED,
)
def api_create_question_proposals(
    request: QuestionProposalBatchCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        items = create_question_proposals(db, current_user, request.proposals)
        return [serialize_moderation_item(db, item) for item in items]
    except PermissionError as exception:
        raise HTTPException(status_code=403, detail=str(exception)) from exception
    except ValueError as exception:
        raise HTTPException(status_code=400, detail=str(exception)) from exception


@router.get(
    "/mine",
    response_model=list[QuestionModerationResponse],
)
def api_my_question_proposals(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return [
        serialize_moderation_item(db, item)
        for item in list_my_proposals(db, current_user)
    ]


@router.delete("/proposals/{item_id}")
def api_delete_my_question_proposal(
    item_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        delete_my_pending_proposal(db, current_user, item_id)
    except ValueError as exception:
        raise HTTPException(status_code=400, detail=str(exception)) from exception
    return {"success": True}


@router.post("/temporary-attachments/cleanup")
def api_cleanup_temporary_question_attachments(
    request: QuestionTemporaryAttachmentCleanupRequest,
    current_user: User = Depends(get_current_user),
):
    deleted = cleanup_temporary_attachments(
        current_user,
        request.attachments,
    )
    return {"success": True, "deleted": deleted}


@router.get(
    "",
    response_model=list[QuestionModerationResponse],
)
def api_question_moderation_items(
    moderation_status: str | None = Query(default=None, alias="status"),
    department: str | None = None,
    course: str | None = None,
    subject: str | None = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if moderation_status is not None and moderation_status not in {
        "pending",
        "under_review",
        "approved",
        "rejected",
    }:
        raise HTTPException(status_code=400, detail="Stato di moderazione non valido.")
    try:
        items = list_moderation_items(
            db,
            current_user,
            status=moderation_status,
            department=department.strip() if department else None,
            course=course.strip() if course else None,
            subject=subject.strip() if subject else None,
        )
        return [serialize_moderation_item(db, item) for item in items]
    except PermissionError as exception:
        raise HTTPException(status_code=403, detail=str(exception)) from exception


@router.get(
    "/{item_id}",
    response_model=QuestionModerationResponse,
)
def api_question_moderation_item(
    item_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    item = get_moderation_item(db, item_id)
    if item is None:
        raise HTTPException(status_code=404, detail="Elemento di moderazione non trovato.")
    try:
        require_moderation_access(db, current_user, item=item)
    except PermissionError as exception:
        raise HTTPException(status_code=403, detail=str(exception)) from exception
    return serialize_moderation_item(db, item)


@router.post(
    "/{item_id}/claim",
    response_model=QuestionModerationResponse,
)
def api_claim_question_moderation_item(
    item_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        item = claim_moderation_item(db, current_user, item_id)
        return serialize_moderation_item(db, item)
    except ValueError as exception:
        raise HTTPException(status_code=404, detail=str(exception)) from exception
    except PermissionError as exception:
        raise HTTPException(status_code=403, detail=str(exception)) from exception
    except RuntimeError as exception:
        raise HTTPException(status_code=409, detail=str(exception)) from exception


@router.patch(
    "/{item_id}/proposal",
    response_model=QuestionModerationResponse,
)
def api_update_question_proposal(
    item_id: int,
    request: QuestionProposalUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        item = update_proposal_payload(db, current_user, item_id, request)
        return serialize_moderation_item(db, item)
    except ValueError as exception:
        raise HTTPException(status_code=400, detail=str(exception)) from exception
    except PermissionError as exception:
        raise HTTPException(status_code=403, detail=str(exception)) from exception
    except RuntimeError as exception:
        raise HTTPException(status_code=409, detail=str(exception)) from exception


@router.patch(
    "/{item_id}/resolution",
    response_model=QuestionModerationResponse,
)
def api_resolve_question_moderation_item(
    item_id: int,
    request: QuestionModerationResolution,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    try:
        item = resolve_moderation_item(db, current_user, item_id, request)
        return serialize_moderation_item(db, item)
    except ValidationError as exception:
        raise HTTPException(status_code=400, detail=str(exception)) from exception
    except ValueError as exception:
        raise HTTPException(status_code=400, detail=str(exception)) from exception
    except PermissionError as exception:
        raise HTTPException(status_code=403, detail=str(exception)) from exception
    except RuntimeError as exception:
        raise HTTPException(status_code=409, detail=str(exception)) from exception
