from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from core.database import get_db
from core.security import get_current_user, get_optional_current_user
from models.public_news import PublicNews
from models.user import User
from schemas.public_news import (
    PublicNewsCreate,
    PublicNewsDeleteResponse,
    PublicNewsFeedItemResponse,
    PublicNewsFeedResponse,
    PublicNewsModerationRequest,
    PublicNewsResponse,
)
from services.public_news import (
    can_delete_public_news,
    can_moderate_public_news,
    create_public_news,
    delete_public_news,
    get_public_news_by_id,
    get_public_news_feed,
    moderate_public_news,
)
from services.user_block import is_user_blocked


router = APIRouter(
    prefix="/public-news",
    tags=["Public News"],
)


def _build_feed_item(db: Session, news: PublicNews, viewer: User | None):
    is_author = viewer is not None and viewer.id == news.author_user_id

    return PublicNewsFeedItemResponse(
        id=news.id,
        author_user_id=news.author_user_id,
        subject_id=news.subject_id,
        target_type=news.target_type,
        title=news.title,
        content=news.content,
        city=news.city,
        university=news.university,
        university_code=news.university_code,
        department=news.department,
        department_code=news.department_code,
        course=news.course,
        course_code=news.course_code,
        subject_name=news.subject_name,
        status=news.status,
        created_at=news.created_at,
        updated_at=news.updated_at,
        author=news.author,
        can_delete=viewer is not None and can_delete_public_news(news, viewer),
        can_moderate=viewer is not None and can_moderate_public_news(news, viewer),
        can_report=viewer is not None and not is_author,
        can_block_author=(
            viewer is not None
            and not is_author
            and not is_user_blocked(db, viewer.id, news.author_user_id)
        ),
    )


@router.get(
    "",
    response_model=PublicNewsFeedResponse,
)
def api_public_news_feed(
    search: str | None = Query(default=None, max_length=200),
    city: str | None = Query(default=None, max_length=160),
    university: str | None = Query(default=None, max_length=255),
    department: str | None = Query(default=None, max_length=255),
    course: str | None = Query(default=None, max_length=255),
    subject_id: int | None = Query(default=None, gt=0),
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
    current_user: User | None = Depends(get_optional_current_user),
):
    try:
        items, total, safe_limit, safe_offset = get_public_news_feed(
            db,
            viewer_user_id=current_user.id if current_user is not None else None,
            search=search,
            city=city,
            university=university,
            department=department,
            course=course,
            subject_id=subject_id,
            limit=limit,
            offset=offset,
        )

        return PublicNewsFeedResponse(
            items=[
                _build_feed_item(db, news, current_user)
                for news in items
            ],
            total=total,
            limit=safe_limit,
            offset=safe_offset,
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Impossibile recuperare le news.",
        )


@router.get(
    "/{news_id}",
    response_model=PublicNewsFeedItemResponse,
)
def api_public_news_detail(
    news_id: int,
    db: Session = Depends(get_db),
    current_user: User | None = Depends(get_optional_current_user),
):
    news = get_public_news_by_id(db, news_id)

    if news is None or news.status != "active":
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="News non trovata.",
        )

    return _build_feed_item(db, news, current_user)


@router.post(
    "",
    response_model=PublicNewsResponse,
    status_code=status.HTTP_201_CREATED,
)
def api_create_public_news(
    request: PublicNewsCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    try:
        return create_public_news(db, current_user, request)
    except PermissionError as exception:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=str(exception),
        )
    except ValueError as exception:
        message = str(exception)
        raise HTTPException(
            status_code=(
                status.HTTP_404_NOT_FOUND
                if "non trovata" in message.lower()
                else status.HTTP_400_BAD_REQUEST
            ),
            detail=message,
        )
    except Exception:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Impossibile pubblicare la news.",
        )


@router.delete(
    "/{news_id}",
    response_model=PublicNewsDeleteResponse,
)
def api_delete_public_news(
    news_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    news = get_public_news_by_id(db, news_id)

    if news is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="News non trovata.",
        )

    try:
        updated = delete_public_news(db, news, current_user)
        return PublicNewsDeleteResponse(
            success=True,
            message="News eliminata.",
            news_id=updated.id,
            status=updated.status,
        )
    except PermissionError as exception:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=str(exception),
        )
    except ValueError as exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exception),
        )


@router.post(
    "/{news_id}/moderate",
    response_model=PublicNewsResponse,
)
def api_moderate_public_news(
    news_id: int,
    request: PublicNewsModerationRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    news = get_public_news_by_id(db, news_id)

    if news is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="News non trovata.",
        )

    try:
        return moderate_public_news(
            db,
            news,
            current_user,
            request.reason,
        )
    except PermissionError as exception:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=str(exception),
        )
    except ValueError as exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exception),
        )
