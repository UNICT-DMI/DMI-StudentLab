from fastapi import (
    APIRouter,
    Depends,
    Header,
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
    get_optional_current_user,
)

from models.user import (
    User,
)

from schemas.news import (
    AvvisoCreate,
    AvvisoListResponse,
    AvvisoResponse,
    GroupNewsFileCreate,
    GroupNewsFileListResponse,
    GroupNewsFileResponse,
    NewsDeleteResponse,
    NewsReplyCreate,
    NewsReplyResponse,
    PrivateNewsCreate,
    PrivateNewsListResponse,
    PrivateNewsResponse,
    PrivateNewsWrapRequest,
)

from services import (
    news_store,
)

from services.group_news import (
    require_active_group,
    require_group_news_member,
)

from services.user_block import (
    can_send_private_content,
)


router = APIRouter(
    prefix="/news",
    tags=["News"],
)


def _author_name(
    user: User,
) -> str:
    return (
        f"{user.first_name} "
        f"{user.last_name}"
    ).strip()


def _viewer_id(
    viewer: User | None,
) -> int | None:
    return (
        viewer.id
        if viewer is not None
        else None
    )


def _sorted_recent_first(
    records: list[dict],
) -> list[dict]:
    return sorted(
        records,
        key=lambda record: str(
            record.get(
                "created_at",
                "",
            )
        ),
        reverse=True,
    )


def _paginate(
    records: list[dict],
    limit: int,
    offset: int,
) -> list[dict]:
    return records[
        offset:offset + limit
    ]


def _reply_responses(
    record: dict,
) -> list[NewsReplyResponse]:
    return [
        NewsReplyResponse(
            id=reply.get("id"),
            author_id=reply.get(
                "author_id",
            ),
            author_name=reply.get(
                "author_name",
                "",
            ),
            content=reply.get(
                "content",
                "",
            ),
            created_at=reply.get(
                "created_at",
            ),
        )
        for reply in record.get(
            "replies",
            [],
        )
    ]


def _is_author(
    record: dict,
    viewer_id: int | None,
) -> bool:
    return (
        viewer_id is not None
        and int(
            record.get(
                "author_id",
                -1,
            )
        )
        == int(
            viewer_id,
        )
    )


def _avviso_response(
    record: dict,
    viewer_id: int | None,
    include_write_token: bool = False,
) -> AvvisoResponse:
    return AvvisoResponse(
        id=record.get("id"),
        author_id=record.get(
            "author_id",
        ),
        author_name=record.get(
            "author_name",
            "",
        ),
        author_role=record.get(
            "author_role",
            "",
        ),
        title=record.get(
            "title",
            "",
        ),
        content=record.get(
            "content",
            "",
        ),
        created_at=record.get(
            "created_at",
        ),
        updated_at=record.get(
            "updated_at",
        ),
        replies=_reply_responses(
            record,
        ),
        can_delete=_is_author(
            record,
            viewer_id,
        ),
        write_token=(
            record.get(
                "write_token",
            )
            if include_write_token
            else None
        ),
    )


def _group_news_response(
    record: dict,
    viewer_id: int | None,
    include_write_token: bool = False,
) -> GroupNewsFileResponse:
    return GroupNewsFileResponse(
        id=record.get("id"),
        group_id=record.get(
            "group_id",
        ),
        group_name=record.get(
            "group_name",
            "",
        ),
        author_id=record.get(
            "author_id",
        ),
        author_name=record.get(
            "author_name",
            "",
        ),
        author_role=record.get(
            "author_role",
            "",
        ),
        content=record.get(
            "content",
            "",
        ),
        created_at=record.get(
            "created_at",
        ),
        updated_at=record.get(
            "updated_at",
        ),
        replies=_reply_responses(
            record,
        ),
        can_delete=_is_author(
            record,
            viewer_id,
        ),
        write_token=(
            record.get(
                "write_token",
            )
            if include_write_token
            else None
        ),
    )


def _participant_names(
    db: Session,
    records: list[dict],
) -> dict[int, str]:
    identifiers = set()

    for record in records:
        for field in (
            "sender_id",
            "recipient_id",
        ):
            value = record.get(
                field,
            )

            if value is not None:
                identifiers.add(
                    int(
                        value,
                    ),
                )

    if not identifiers:
        return {}

    rows = (
        db.query(
            User.id,
            User.first_name,
            User.last_name,
        )
        .filter(
            User.id.in_(
                identifiers,
            ),
        )
        .all()
    )

    return {
        int(row[0]): (
            f"{row[1]} {row[2]}"
        ).strip()
        for row in rows
    }


def _private_news_response(
    record: dict,
    viewer_id: int | None,
    names: dict[int, str] | None = None,
    include_write_token: bool = False,
) -> PrivateNewsResponse:
    resolved = names or {}

    return PrivateNewsResponse(
        id=record.get("id"),
        conversation_id=record.get(
            "conversation_id",
            "",
        ),
        sender_id=record.get(
            "sender_id",
        ),
        recipient_id=record.get(
            "recipient_id",
        ),
        sender_name=resolved.get(
            int(
                record.get(
                    "sender_id",
                    0,
                )
                or 0,
            ),
            "",
        ),
        recipient_name=resolved.get(
            int(
                record.get(
                    "recipient_id",
                    0,
                )
                or 0,
            ),
            "",
        ),
        algo=record.get(
            "algo",
            "",
        ),
        ciphertext=record.get(
            "ciphertext",
            "",
        ),
        metadata=record.get(
            "metadata",
        )
        or {},
        created_at=record.get(
            "created_at",
        ),
        delivery=news_store.delivery_of(
            record,
        ),
        can_delete=_is_author(
            record,
            viewer_id,
        ),
        write_token=(
            record.get(
                "write_token",
            )
            if include_write_token
            else None
        ),
    )


def _without_undelivered(
    records: list[dict],
    viewer_id: int,
) -> list[dict]:
    return [
        record
        for record in records
        if not news_store.is_pending_for(
            record,
            viewer_id,
        )
    ]


def _store_error(
    exception: Exception,
) -> HTTPException:
    if isinstance(
        exception,
        news_store.NewsNotFound,
    ):
        return HTTPException(
            status_code=(
                status.HTTP_404_NOT_FOUND
            ),
            detail=str(
                exception,
            ),
        )

    if isinstance(
        exception,
        news_store.NewsPermissionDenied,
    ):
        return HTTPException(
            status_code=(
                status.HTTP_403_FORBIDDEN
            ),
            detail=str(
                exception,
            ),
        )

    return HTTPException(
        status_code=(
            status.HTTP_400_BAD_REQUEST
        ),
        detail=str(
            exception,
        ),
    )


def _require_group_access(
    db: Session,
    group_id: int,
    user: User,
):
    try:
        group = require_active_group(
            db,
            group_id,
        )

        require_group_news_member(
            db,
            group_id,
            user.id,
        )

        return group
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
                status.HTTP_404_NOT_FOUND
            ),
            detail=str(
                exception,
            ),
        )


def _require_active_recipient(
    db: Session,
    recipient_id: int,
) -> User:
    recipient = (
        db.query(
            User,
        )
        .filter(
            User.id
            ==
            recipient_id,
            User.is_active.is_(
                True,
            ),
        )
        .first()
    )

    if recipient is None:
        raise HTTPException(
            status_code=(
                status.HTTP_404_NOT_FOUND
            ),
            detail="Destinatario non trovato.",
        )

    return recipient


@router.get(
    "/avvisi",
    response_model=AvvisoListResponse,
)
def api_list_avvisi(
    limit: int = Query(
        default=50,
        ge=1,
        le=100,
    ),
    offset: int = Query(
        default=0,
        ge=0,
    ),
    current_user: User | None = Depends(
        get_optional_current_user,
    ),
):
    records = _sorted_recent_first(
        news_store.list_avvisi(),
    )

    return AvvisoListResponse(
        items=[
            _avviso_response(
                record,
                _viewer_id(
                    current_user,
                ),
            )
            for record in _paginate(
                records,
                limit,
                offset,
            )
        ],
        total=len(
            records,
        ),
    )


@router.get(
    "/avvisi/{news_id}",
    response_model=AvvisoResponse,
)
def api_get_avviso(
    news_id: str,
    current_user: User | None = Depends(
        get_optional_current_user,
    ),
):
    try:
        record = news_store.get_avviso(
            news_id,
        )
    except news_store.NewsStoreError as exception:
        raise _store_error(
            exception,
        )

    return _avviso_response(
        record,
        _viewer_id(
            current_user,
        ),
    )


@router.post(
    "/avvisi",
    response_model=AvvisoResponse,
    status_code=status.HTTP_201_CREATED,
)
def api_create_avviso(
    request: AvvisoCreate,
    current_user: User = Depends(
        get_admin_user,
    ),
):
    try:
        record = news_store.create_avviso(
            author_id=current_user.id,
            author_name=_author_name(
                current_user,
            ),
            author_role=current_user.role,
            title=request.title,
            content=request.content,
        )
    except news_store.NewsStoreError as exception:
        raise _store_error(
            exception,
        )
    except OSError:
        raise HTTPException(
            status_code=(
                status
                .HTTP_500_INTERNAL_SERVER_ERROR
            ),
            detail="Impossibile pubblicare l'avviso.",
        )

    return _avviso_response(
        record,
        current_user.id,
        include_write_token=True,
    )


@router.post(
    "/avvisi/{news_id}/replies",
    response_model=NewsReplyResponse,
    status_code=status.HTTP_201_CREATED,
)
def api_reply_to_avviso(
    news_id: str,
    request: NewsReplyCreate,
    current_user: User = Depends(
        get_current_user,
    ),
):
    try:
        reply = news_store.add_reply(
            category="avvisi",
            group_id=None,
            news_id=news_id,
            author_id=current_user.id,
            author_name=_author_name(
                current_user,
            ),
            content=request.content,
        )
    except news_store.NewsStoreError as exception:
        raise _store_error(
            exception,
        )

    return NewsReplyResponse(
        id=reply.get("id"),
        author_id=reply.get(
            "author_id",
        ),
        author_name=reply.get(
            "author_name",
            "",
        ),
        content=reply.get(
            "content",
            "",
        ),
        created_at=reply.get(
            "created_at",
        ),
        write_token=reply.get(
            "write_token",
        ),
    )


@router.delete(
    "/avvisi/{news_id}",
    response_model=NewsDeleteResponse,
)
def api_delete_avviso(
    news_id: str,
    write_token: str | None = Header(
        default=None,
        alias="X-News-Write-Token",
        max_length=200,
    ),
    current_user: User = Depends(
        get_current_user,
    ),
):
    try:
        news_store.delete_news(
            category="avvisi",
            news_id=news_id,
            user_id=current_user.id,
            write_token=write_token,
        )
    except news_store.NewsStoreError as exception:
        raise _store_error(
            exception,
        )

    return NewsDeleteResponse(
        success=True,
        message="Avviso eliminato.",
        news_id=news_id,
    )


@router.get(
    "/groups/{group_id}",
    response_model=GroupNewsFileListResponse,
)
def api_list_group_news(
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
    _require_group_access(
        db,
        group_id,
        current_user,
    )

    records = _sorted_recent_first(
        news_store.list_group_news(
            group_id,
        ),
    )

    return GroupNewsFileListResponse(
        items=[
            _group_news_response(
                record,
                current_user.id,
            )
            for record in _paginate(
                records,
                limit,
                offset,
            )
        ],
        total=len(
            records,
        ),
    )


@router.post(
    "/groups/{group_id}",
    response_model=GroupNewsFileResponse,
    status_code=status.HTTP_201_CREATED,
)
def api_create_group_news(
    group_id: int,
    request: GroupNewsFileCreate,
    db: Session = Depends(
        get_db,
    ),
    current_user: User = Depends(
        get_current_user,
    ),
):
    group = _require_group_access(
        db,
        group_id,
        current_user,
    )

    try:
        record = news_store.create_group_news(
            group_id=group_id,
            group_name=group.name,
            author_id=current_user.id,
            author_name=_author_name(
                current_user,
            ),
            author_role=current_user.role,
            content=request.content,
        )
    except news_store.NewsStoreError as exception:
        raise _store_error(
            exception,
        )
    except OSError:
        raise HTTPException(
            status_code=(
                status
                .HTTP_500_INTERNAL_SERVER_ERROR
            ),
            detail="Impossibile pubblicare la news.",
        )

    return _group_news_response(
        record,
        current_user.id,
        include_write_token=True,
    )


@router.post(
    "/groups/{group_id}/{news_id}/replies",
    response_model=NewsReplyResponse,
    status_code=status.HTTP_201_CREATED,
)
def api_reply_to_group_news(
    group_id: int,
    news_id: str,
    request: NewsReplyCreate,
    db: Session = Depends(
        get_db,
    ),
    current_user: User = Depends(
        get_current_user,
    ),
):
    _require_group_access(
        db,
        group_id,
        current_user,
    )

    try:
        reply = news_store.add_reply(
            category="gruppi",
            group_id=group_id,
            news_id=news_id,
            author_id=current_user.id,
            author_name=_author_name(
                current_user,
            ),
            content=request.content,
        )
    except news_store.NewsStoreError as exception:
        raise _store_error(
            exception,
        )

    return NewsReplyResponse(
        id=reply.get("id"),
        author_id=reply.get(
            "author_id",
        ),
        author_name=reply.get(
            "author_name",
            "",
        ),
        content=reply.get(
            "content",
            "",
        ),
        created_at=reply.get(
            "created_at",
        ),
        write_token=reply.get(
            "write_token",
        ),
    )


@router.delete(
    "/groups/{group_id}/{news_id}",
    response_model=NewsDeleteResponse,
)
def api_delete_group_news(
    group_id: int,
    news_id: str,
    write_token: str | None = Header(
        default=None,
        alias="X-News-Write-Token",
        max_length=200,
    ),
    db: Session = Depends(
        get_db,
    ),
    current_user: User = Depends(
        get_current_user,
    ),
):
    _require_group_access(
        db,
        group_id,
        current_user,
    )

    try:
        news_store.delete_news(
            category="gruppi",
            news_id=news_id,
            user_id=current_user.id,
            write_token=write_token,
            group_id=group_id,
        )
    except news_store.NewsStoreError as exception:
        raise _store_error(
            exception,
        )

    return NewsDeleteResponse(
        success=True,
        message="News eliminata.",
        news_id=news_id,
    )


@router.post(
    "/private",
    response_model=PrivateNewsResponse,
    status_code=status.HTTP_201_CREATED,
)
def api_create_private_news(
    request: PrivateNewsCreate,
    db: Session = Depends(
        get_db,
    ),
    current_user: User = Depends(
        get_current_user,
    ),
):
    if request.recipient_id == current_user.id:
        raise HTTPException(
            status_code=(
                status.HTTP_400_BAD_REQUEST
            ),
            detail="Non puoi inviare una news privata a te stesso.",
        )

    _require_active_recipient(
        db,
        request.recipient_id,
    )

    if not can_send_private_content(
        db,
        current_user.id,
        request.recipient_id,
    ):
        raise HTTPException(
            status_code=(
                status.HTTP_403_FORBIDDEN
            ),
            detail="Non puoi inviare news private a questo utente.",
        )

    try:
        record = news_store.create_private_news(
            sender_id=current_user.id,
            recipient_id=request.recipient_id,
            ciphertext=request.ciphertext,
            algo=request.algo,
            metadata=request.metadata,
        )
    except news_store.NewsStoreError as exception:
        raise _store_error(
            exception,
        )
    except OSError:
        raise HTTPException(
            status_code=(
                status
                .HTTP_500_INTERNAL_SERVER_ERROR
            ),
            detail="Impossibile inviare la news privata.",
        )

    return _private_news_response(
        record,
        current_user.id,
        _participant_names(
            db,
            [
                record,
            ],
        ),
        include_write_token=True,
    )


@router.get(
    "/private",
    response_model=PrivateNewsListResponse,
)
def api_list_private_news(
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
    records = _sorted_recent_first(
        _without_undelivered(
            news_store.list_private_for_user(
                current_user.id,
            ),
            current_user.id,
        ),
    )

    page = _paginate(
        records,
        limit,
        offset,
    )

    names = _participant_names(
        db,
        page,
    )

    return PrivateNewsListResponse(
        items=[
            _private_news_response(
                record,
                current_user.id,
                names,
            )
            for record in page
        ],
        total=len(
            records,
        ),
    )


@router.get(
    "/private/pending",
    response_model=PrivateNewsListResponse,
)
def api_list_pending_private_news(
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
    records = _sorted_recent_first(
        news_store.list_pending_for_sender(
            current_user.id,
        ),
    )

    page = _paginate(
        records,
        limit,
        offset,
    )

    names = _participant_names(
        db,
        page,
    )

    return PrivateNewsListResponse(
        items=[
            _private_news_response(
                record,
                current_user.id,
                names,
            )
            for record in page
        ],
        total=len(
            records,
        ),
    )


@router.post(
    "/private/{other_user_id}/{news_id}/wrap",
    response_model=PrivateNewsResponse,
)
def api_complete_private_delivery(
    other_user_id: int,
    news_id: str,
    request: PrivateNewsWrapRequest,
    db: Session = Depends(
        get_db,
    ),
    current_user: User = Depends(
        get_current_user,
    ),
):
    if other_user_id <= 0 or other_user_id == current_user.id:
        raise HTTPException(
            status_code=(
                status.HTTP_400_BAD_REQUEST
            ),
            detail="Utente non valido.",
        )

    if not can_send_private_content(
        db,
        current_user.id,
        other_user_id,
    ):
        raise HTTPException(
            status_code=(
                status.HTTP_403_FORBIDDEN
            ),
            detail="Non puoi inviare news private a questo utente.",
        )

    try:
        record = news_store.add_wrapped_keys(
            conversation_id=news_store.conversation_id(
                current_user.id,
                other_user_id,
            ),
            news_id=news_id,
            sender_id=current_user.id,
            wrapped_keys=request.wrapped_keys,
        )
    except news_store.NewsStoreError as exception:
        raise _store_error(
            exception,
        )
    except OSError:
        raise HTTPException(
            status_code=(
                status
                .HTTP_500_INTERNAL_SERVER_ERROR
            ),
            detail="Impossibile completare la consegna del messaggio.",
        )

    return _private_news_response(
        record,
        current_user.id,
        _participant_names(
            db,
            [
                record,
            ],
        ),
    )


@router.get(
    "/private/{other_user_id}",
    response_model=PrivateNewsListResponse,
)
def api_list_private_conversation(
    other_user_id: int,
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
    if other_user_id <= 0:
        raise HTTPException(
            status_code=(
                status.HTTP_400_BAD_REQUEST
            ),
            detail="Utente non valido.",
        )

    records = _sorted_recent_first(
        _without_undelivered(
            news_store.list_private_conversation(
                current_user.id,
                other_user_id,
            ),
            current_user.id,
        ),
    )

    page = _paginate(
        records,
        limit,
        offset,
    )

    names = _participant_names(
        db,
        page,
    )

    return PrivateNewsListResponse(
        items=[
            _private_news_response(
                record,
                current_user.id,
                names,
            )
            for record in page
        ],
        total=len(
            records,
        ),
    )


@router.delete(
    "/private/{other_user_id}/{news_id}",
    response_model=NewsDeleteResponse,
)
def api_delete_private_news(
    other_user_id: int,
    news_id: str,
    write_token: str | None = Header(
        default=None,
        alias="X-News-Write-Token",
        max_length=200,
    ),
    current_user: User = Depends(
        get_current_user,
    ),
):
    if other_user_id <= 0:
        raise HTTPException(
            status_code=(
                status.HTTP_400_BAD_REQUEST
            ),
            detail="Utente non valido.",
        )

    try:
        news_store.delete_news(
            category="private",
            news_id=news_id,
            user_id=current_user.id,
            write_token=write_token,
            conversation_id=(
                news_store.conversation_id(
                    current_user.id,
                    other_user_id,
                )
            ),
        )
    except news_store.NewsStoreError as exception:
        raise _store_error(
            exception,
        )

    return NewsDeleteResponse(
        success=True,
        message="News privata eliminata.",
        news_id=news_id,
    )
