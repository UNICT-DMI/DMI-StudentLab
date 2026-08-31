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

from models.group_news import (
    GroupNews,
)

from models.user import (
    User,
)

from schemas.group_news import (
    GroupNewsCreate,
    GroupNewsDeleteResponse,
    GroupNewsFeedItemResponse,
    GroupNewsFeedResponse,
    GroupNewsModerationRequest,
    GroupNewsPrivateInboxItemResponse,
    GroupNewsPrivateInboxResponse,
    GroupNewsResponse,
)

from services.group_news import (
    can_delete_group_news,
    can_moderate_group_news,
    can_view_group_news,
    create_group_news,
    delete_group_news,
    get_group_news_by_id,
    get_group_news_feed,
    get_private_group_news_inbox,
    moderate_group_news,
    platform_moderate_group_news,
)

from services.user_block import (
    can_send_private_content,
    is_user_blocked,
)


router = APIRouter(
    prefix="/group-news",
    tags=[
        "Group News",
    ],
)


def _subject_name(
    news: GroupNews,
) -> str:
    group = news.group

    if group is None:
        return ""

    subject = getattr(
        group,
        "subject",
        None,
    )

    if subject is not None:
        name = getattr(
            subject,
            "name",
            None,
        )

        if name:
            return str(
                name,
            ).strip()

    value = getattr(
        group,
        "subject_name",
        None,
    )

    if value:
        return str(
            value,
        ).strip()

    return ""


def _build_feed_item(
    db: Session,
    news: GroupNews,
    current_user: User,
):
    is_author = (
        news.author_user_id
        ==
        current_user.id
    )

    can_delete = (
        can_delete_group_news(
            db,
            news,
            current_user.id,
        )
    )

    can_moderate = (
        can_moderate_group_news(
            db,
            news,
            current_user.id,
        )
    )

    can_report = (
        not is_author
    )

    can_block_author = (
        not is_author
        and not is_user_blocked(
            db,
            current_user.id,
            news.author_user_id,
        )
    )

    if (
        news.visibility
        ==
        "private"
    ):
        is_private_participant = (
            current_user.id
            in {
                news.author_user_id,
                news.recipient_user_id,
            }
        )

        if not is_private_participant:
            can_delete = False
            can_moderate = False
            can_report = False
            can_block_author = False

        other_user_id = (
            news.recipient_user_id
            if current_user.id
            ==
            news.author_user_id
            else news.author_user_id
        )

        can_reply = (
            is_private_participant
            and other_user_id
            is not None
            and can_send_private_content(
                db,
                current_user.id,
                other_user_id,
            )
        )

    else:
        can_reply = True

    return GroupNewsFeedItemResponse(
        id=news.id,
        group_id=news.group_id,
        author_user_id=(
            news.author_user_id
        ),
        recipient_user_id=(
            news.recipient_user_id
        ),
        parent_news_id=(
            news.parent_news_id
        ),
        visibility=(
            news.visibility
        ),
        is_private=(
            news.visibility
            ==
            "private"
        ),
        content=(
            news.content
        ),
        created_at=(
            news.created_at
        ),
        expires_at=(
            news.expires_at
        ),
        author=(
            news.author
        ),
        recipient=(
            news.recipient
        ),
        can_reply=(
            can_reply
        ),
        can_delete=(
            can_delete
        ),
        can_moderate=(
            can_moderate
        ),
        can_report=(
            can_report
        ),
        can_block_author=(
            can_block_author
        ),
    )


def _build_private_inbox_item(
    db: Session,
    news: GroupNews,
    current_user: User,
):
    item = _build_feed_item(
        db,
        news,
        current_user,
    )

    group = news.group

    return GroupNewsPrivateInboxItemResponse(
        **item.model_dump(),
        group_name=(
            getattr(
                group,
                "name",
                "",
            )
            or ""
        ),
        subject_id=(
            getattr(
                group,
                "subject_id",
                None,
            )
        ),
        subject_name=(
            _subject_name(
                news,
            )
        ),
    )


@router.post(
    "/groups/{group_id}",
    response_model=GroupNewsResponse,
    status_code=status.HTTP_201_CREATED,
)
def api_create_group_news(
    group_id: int,
    request: GroupNewsCreate,
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

    try:
        return create_group_news(
            db,
            group_id,
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
            "Gruppo non trovato."
        ):
            raise HTTPException(
                status_code=(
                    status.HTTP_404_NOT_FOUND
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
                "Impossibile pubblicare la news."
            ),
        )


@router.get(
    "/private",
    response_model=GroupNewsPrivateInboxResponse,
)
def api_get_private_group_news_inbox(
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
    try:
        (
            items,
            total,
            safe_limit,
            safe_offset,
        ) = get_private_group_news_inbox(
            db,
            current_user.id,
            limit,
            offset,
        )

        return GroupNewsPrivateInboxResponse(
            items=[
                _build_private_inbox_item(
                    db,
                    news,
                    current_user,
                )
                for news in items
            ],
            total=(
                total
            ),
            limit=(
                safe_limit
            ),
            offset=(
                safe_offset
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
                "Impossibile recuperare le comunicazioni private."
            ),
        )


@router.get(
    "/groups/{group_id}",
    response_model=GroupNewsFeedResponse,
)
def api_get_group_news_feed(
    group_id: int,
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

    try:
        (
            items,
            total,
            safe_limit,
            safe_offset,
        ) = get_group_news_feed(
            db,
            group_id,
            current_user.id,
            limit,
            offset,
        )

        response_items = [
            _build_feed_item(
                db,
                news,
                current_user,
            )
            for news in items
        ]

        return GroupNewsFeedResponse(
            group_id=(
                group_id
            ),
            items=(
                response_items
            ),
            total=(
                total
            ),
            limit=(
                safe_limit
            ),
            offset=(
                safe_offset
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
        message = str(
            exception,
        )

        if (
            message
            ==
            "Gruppo non trovato."
        ):
            raise HTTPException(
                status_code=(
                    status.HTTP_404_NOT_FOUND
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
        raise HTTPException(
            status_code=(
                status.HTTP_500_INTERNAL_SERVER_ERROR
            ),
            detail=(
                "Impossibile recuperare le news del gruppo."
            ),
        )


@router.get(
    "/{news_id}",
    response_model=GroupNewsResponse,
)
def api_get_group_news(
    news_id: int,
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

    news = get_group_news_by_id(
        db,
        news_id,
    )

    if news is None:
        raise HTTPException(
            status_code=(
                status.HTTP_404_NOT_FOUND
            ),
            detail=(
                "News non trovata."
            ),
        )

    if not can_view_group_news(
        db,
        news,
        current_user.id,
    ):
        raise HTTPException(
            status_code=(
                status.HTTP_403_FORBIDDEN
            ),
            detail=(
                "Non puoi visualizzare questa news."
            ),
        )

    return news


@router.delete(
    "/{news_id}",
    response_model=GroupNewsDeleteResponse,
)
def api_delete_group_news(
    news_id: int,
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

    news = get_group_news_by_id(
        db,
        news_id,
    )

    if news is None:
        raise HTTPException(
            status_code=(
                status.HTTP_404_NOT_FOUND
            ),
            detail=(
                "News non trovata."
            ),
        )

    try:
        updated_news = (
            delete_group_news(
                db,
                news,
                current_user.id,
            )
        )

        return GroupNewsDeleteResponse(
            success=True,
            message=(
                "News eliminata."
            ),
            news_id=(
                updated_news.id
            ),
            status=(
                updated_news.status
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

    except Exception:
        db.rollback()

        raise HTTPException(
            status_code=(
                status.HTTP_500_INTERNAL_SERVER_ERROR
            ),
            detail=(
                "Impossibile eliminare la news."
            ),
        )


@router.post(
    "/{news_id}/moderate",
    response_model=GroupNewsResponse,
)
def api_moderate_group_news(
    news_id: int,
    request: GroupNewsModerationRequest,
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

    news = get_group_news_by_id(
        db,
        news_id,
    )

    if news is None:
        raise HTTPException(
            status_code=(
                status.HTTP_404_NOT_FOUND
            ),
            detail=(
                "News non trovata."
            ),
        )

    try:
        return moderate_group_news(
            db,
            news,
            current_user.id,
            request.reason,
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
                "Impossibile moderare la news."
            ),
        )


@router.post(
    "/{news_id}/platform-moderate",
    response_model=GroupNewsResponse,
)
def api_platform_moderate_group_news(
    news_id: int,
    request: GroupNewsModerationRequest,
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

    news = get_group_news_by_id(
        db,
        news_id,
    )

    if news is None:
        raise HTTPException(
            status_code=(
                status.HTTP_404_NOT_FOUND
            ),
            detail=(
                "News non trovata."
            ),
        )

    try:
        return platform_moderate_group_news(
            db,
            news,
            current_user.id,
            request.reason,
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
                "Impossibile completare la moderazione della news."
            ),
        )