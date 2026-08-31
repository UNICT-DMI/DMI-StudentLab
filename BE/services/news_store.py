import copy
import json
import os
import secrets
import threading
import uuid
from datetime import datetime, timezone
from pathlib import Path

from services import news_crypto


class NewsStoreError(Exception):
    pass


class NewsNotFound(NewsStoreError):
    pass


class NewsPermissionDenied(NewsStoreError):
    pass


def _news_root() -> Path:
    override = os.getenv("StudentLab_NEWS_DIR") or os.getenv("NEWS_DIR")

    if override:
        return Path(override)

    return Path(__file__).resolve().parent.parent / "news"


_LOCK = threading.Lock()

_CATEGORIES = (
    "avvisi",
    "gruppi",
    "private",
)


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _new_id() -> str:
    return uuid.uuid4().hex


def _new_token() -> str:
    return secrets.token_urlsafe(24)


def conversation_id(user_a: int, user_b: int) -> str:
    low, high = sorted((int(user_a), int(user_b)))
    return f"{low}_{high}"


def _category_dir(category: str) -> Path:
    if category not in _CATEGORIES:
        raise NewsStoreError(f"Categoria news non valida: {category}")

    return _news_root() / category


def _ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def _write_atomic(path: Path, payload: dict) -> None:
    _ensure_dir(path.parent)

    tmp = path.with_suffix(f".{uuid.uuid4().hex}.tmp")

    with tmp.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2)

    os.replace(tmp, path)


# Campi di testo cifrati a riposo (avvisi/gruppi). Le private non passano
# di qui: contengono gia' ciphertext E2E generato dal client.
_ENC_FIELDS = {
    "avviso": ("title", "content"),
    "group": ("content",),
}


def _encode_for_disk(record: dict) -> dict:
    disk = copy.deepcopy(record)

    for field in _ENC_FIELDS.get(disk.get("type"), ()):
        if isinstance(disk.get(field), str):
            disk[field] = news_crypto.encrypt_at_rest(disk[field])

    for reply in disk.get("replies", []):
        if isinstance(reply.get("content"), str):
            reply["content"] = news_crypto.encrypt_at_rest(reply["content"])

    return disk


def _decode_from_disk(record: dict) -> dict:
    for field in _ENC_FIELDS.get(record.get("type"), ()):
        if isinstance(record.get(field), str):
            record[field] = news_crypto.decrypt_at_rest(record[field])

    for reply in record.get("replies", []):
        if isinstance(reply.get("content"), str):
            reply["content"] = news_crypto.decrypt_at_rest(reply["content"])

    return record


def _write_record(path: Path, record: dict) -> None:
    _write_atomic(path, _encode_for_disk(record))


def _read_json(path: Path) -> dict:
    if not path.exists():
        raise NewsNotFound("News non trovata.")

    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def _read(path: Path) -> dict:
    return _decode_from_disk(_read_json(path))


def _list_dir(path: Path) -> list[dict]:
    if not path.exists():
        return []

    items = []

    for entry in sorted(path.glob("*.json")):
        try:
            items.append(_read(entry))
        except (json.JSONDecodeError, OSError):
            continue

    return items


ACTIVE_STATUS = "active"

MODERATION_STATUSES = (
    ACTIVE_STATUS,
    "hidden",
    "removed",
)


DELIVERED = "delivered"

PENDING_DELIVERY = "pending"


def status_of(record: dict) -> str:
    return record.get("status") or ACTIVE_STATUS


def _wrapped_keys(record: dict) -> dict:
    metadata = record.get("metadata")

    if not isinstance(metadata, dict):
        return {}

    wrapped = metadata.get("wrapped_keys")

    return wrapped if isinstance(wrapped, dict) else {}


def has_wrap_for_user(record: dict, user_id: int) -> bool:
    prefix = f"{int(user_id)}:"

    return any(
        str(target).startswith(prefix)
        for target in _wrapped_keys(record)
    )


def delivery_of(record: dict) -> str:
    return record.get("delivery") or DELIVERED


def is_pending_for(record: dict, viewer_id: int) -> bool:
    return (
        delivery_of(record) == PENDING_DELIVERY
        and int(record.get("recipient_id", 0) or 0) == int(viewer_id)
    )


def _is_visible(record: dict) -> bool:
    return status_of(record) == ACTIVE_STATUS


def _visible_only(records: list[dict], include_moderated: bool) -> list[dict]:
    if include_moderated:
        return records

    return [record for record in records if _is_visible(record)]


def _record_path(
    category: str,
    news_id: str,
    group_id: int | None = None,
    conversation_id: str | None = None,
) -> Path:
    if category == "avvisi":
        return _category_dir("avvisi") / f"{news_id}.json"

    if category == "gruppi":
        if group_id is None:
            raise NewsStoreError("Gruppo non specificato.")

        return _category_dir("gruppi") / str(int(group_id)) / f"{news_id}.json"

    if category == "private":
        if not conversation_id:
            raise NewsStoreError("Conversazione non specificata.")

        return _category_dir("private") / str(conversation_id) / f"{news_id}.json"

    raise NewsStoreError(f"Categoria news non valida: {category}")


def get_record(
    *,
    category: str,
    news_id: str,
    group_id: int | None = None,
    conversation_id: str | None = None,
) -> dict:
    return _read(
        _record_path(
            category,
            news_id,
            group_id,
            conversation_id,
        ),
    )


def set_status(
    *,
    category: str,
    news_id: str,
    status: str,
    moderated_by: int,
    reason: str,
    group_id: int | None = None,
    conversation_id: str | None = None,
) -> dict:
    if status not in MODERATION_STATUSES:
        raise NewsStoreError(f"Stato di moderazione non valido: {status}")

    path = _record_path(
        category,
        news_id,
        group_id,
        conversation_id,
    )

    with _LOCK:
        record = _read(path)

        record["status"] = status
        record["moderated_by"] = int(moderated_by)
        record["moderation_reason"] = reason
        record["moderated_at"] = _now()
        record["updated_at"] = _now()

        _write_record(path, record)

    return record


def _assert_owner(record: dict, user_id: int, write_token: str | None) -> None:
    if int(record.get("author_id", -1)) != int(user_id):
        raise NewsPermissionDenied(
            "Non puoi modificare una news di un altro utente."
        )

    stored_token = record.get("write_token")

    if stored_token and write_token != stored_token:
        raise NewsPermissionDenied("Token di modifica non valido.")


# --- Avvisi (sezione principale) -------------------------------------------


def create_avviso(
    *,
    author_id: int,
    author_name: str,
    author_role: str,
    title: str,
    content: str,
) -> dict:
    news_id = _new_id()

    record = {
        "id": news_id,
        "type": "avviso",
        "author_id": int(author_id),
        "author_name": author_name,
        "author_role": author_role,
        "title": title,
        "content": content,
        "status": ACTIVE_STATUS,
        "created_at": _now(),
        "updated_at": _now(),
        "write_token": _new_token(),
        "replies": [],
    }

    with _LOCK:
        _write_record(_category_dir("avvisi") / f"{news_id}.json", record)

    return record


def list_avvisi(include_moderated: bool = False) -> list[dict]:
    return _visible_only(
        _list_dir(_category_dir("avvisi")),
        include_moderated,
    )


def get_avviso(news_id: str, include_moderated: bool = False) -> dict:
    record = _read(_category_dir("avvisi") / f"{news_id}.json")

    if not include_moderated and not _is_visible(record):
        raise NewsNotFound("News non trovata.")

    return record


# --- News di gruppo ---------------------------------------------------------


def create_group_news(
    *,
    group_id: int,
    group_name: str,
    author_id: int,
    author_name: str,
    author_role: str,
    content: str,
) -> dict:
    news_id = _new_id()

    record = {
        "id": news_id,
        "type": "group",
        "group_id": int(group_id),
        "group_name": group_name,
        "author_id": int(author_id),
        "author_name": author_name,
        "author_role": author_role,
        "content": content,
        "status": ACTIVE_STATUS,
        "created_at": _now(),
        "updated_at": _now(),
        "write_token": _new_token(),
        "replies": [],
    }

    with _LOCK:
        _write_record(
            _category_dir("gruppi") / str(int(group_id)) / f"{news_id}.json",
            record,
        )

    return record


def list_group_news(
    group_id: int,
    include_moderated: bool = False,
) -> list[dict]:
    return _visible_only(
        _list_dir(_category_dir("gruppi") / str(int(group_id))),
        include_moderated,
    )


def add_reply(
    *,
    category: str,
    group_id: int | None,
    news_id: str,
    author_id: int,
    author_name: str,
    content: str,
) -> dict:
    if category == "gruppi":
        path = _category_dir("gruppi") / str(int(group_id)) / f"{news_id}.json"
    else:
        path = _category_dir("avvisi") / f"{news_id}.json"

    with _LOCK:
        record = _read(path)

        reply = {
            "id": _new_id(),
            "author_id": int(author_id),
            "author_name": author_name,
            "content": content,
            "created_at": _now(),
            "write_token": _new_token(),
        }

        record.setdefault("replies", []).append(reply)
        record["updated_at"] = _now()

        _write_record(path, record)

    return reply


# --- News private (E2E: solo ciphertext) -----------------------------------


def create_private_news(
    *,
    sender_id: int,
    recipient_id: int,
    ciphertext: str,
    algo: str,
    metadata: dict | None = None,
) -> dict:
    news_id = _new_id()

    record = {
        "id": news_id,
        "type": "private",
        "conversation_id": conversation_id(sender_id, recipient_id),
        "author_id": int(sender_id),
        "sender_id": int(sender_id),
        "recipient_id": int(recipient_id),
        "status": ACTIVE_STATUS,
        "created_at": _now(),
        "write_token": _new_token(),
        "algo": algo,
        "ciphertext": ciphertext,
        "metadata": metadata or {},
    }

    record["delivery"] = (
        DELIVERED
        if has_wrap_for_user(record, recipient_id)
        else PENDING_DELIVERY
    )

    with _LOCK:
        _write_record(
            _category_dir("private")
            / record["conversation_id"]
            / f"{news_id}.json",
            record,
        )

    return record


def add_wrapped_keys(
    *,
    conversation_id: str,
    news_id: str,
    sender_id: int,
    wrapped_keys: dict,
) -> dict:
    if not wrapped_keys:
        raise NewsStoreError("Nessuna chiave da aggiungere.")

    path = _record_path(
        "private",
        news_id,
        conversation_id=conversation_id,
    )

    with _LOCK:
        record = _read(path)

        if int(record.get("sender_id", -1)) != int(sender_id):
            raise NewsPermissionDenied(
                "Solo il mittente può completare la consegna di questo "
                "messaggio."
            )

        metadata = record.get("metadata")

        if not isinstance(metadata, dict):
            metadata = {}

        existing = metadata.get("wrapped_keys")

        if not isinstance(existing, dict):
            existing = {}

        for target, wrap in wrapped_keys.items():
            if target in existing:
                raise NewsStoreError(
                    f"La chiave per {target} è già presente: non può essere "
                    "sostituita."
                )

            existing[target] = wrap

        metadata["wrapped_keys"] = existing
        record["metadata"] = metadata

        record["delivery"] = (
            DELIVERED
            if has_wrap_for_user(
                record,
                record.get("recipient_id", 0),
            )
            else PENDING_DELIVERY
        )

        record["updated_at"] = _now()

        _write_record(path, record)

    return record


def list_pending_for_sender(sender_id: int) -> list[dict]:
    root = _category_dir("private")

    if not root.exists():
        return []

    items = []

    for conversation_dir in root.iterdir():
        if not conversation_dir.is_dir():
            continue

        parts = conversation_dir.name.split("_")

        if len(parts) != 2:
            continue

        if str(int(sender_id)) not in parts:
            continue

        for record in _list_dir(conversation_dir):
            if int(record.get("sender_id", 0) or 0) != int(sender_id):
                continue

            if delivery_of(record) != PENDING_DELIVERY:
                continue

            items.append(record)

    return _visible_only(
        items,
        False,
    )


def list_private_conversation(
    user_a: int,
    user_b: int,
    include_moderated: bool = False,
) -> list[dict]:
    conversation = conversation_id(user_a, user_b)

    return _visible_only(
        _list_dir(_category_dir("private") / conversation),
        include_moderated,
    )


def list_private_for_user(
    user_id: int,
    include_moderated: bool = False,
) -> list[dict]:
    root = _category_dir("private")

    if not root.exists():
        return []

    items = []

    for conversation_dir in root.iterdir():
        if not conversation_dir.is_dir():
            continue

        parts = conversation_dir.name.split("_")

        if len(parts) != 2:
            continue

        if str(int(user_id)) not in parts:
            continue

        items.extend(_list_dir(conversation_dir))

    return _visible_only(
        items,
        include_moderated,
    )


# --- Eliminazione con ownership + token ------------------------------------


def delete_news(
    *,
    category: str,
    news_id: str,
    user_id: int,
    write_token: str | None,
    group_id: int | None = None,
    conversation_id: str | None = None,
) -> None:
    if category == "avvisi":
        path = _category_dir("avvisi") / f"{news_id}.json"
    elif category == "gruppi":
        path = _category_dir("gruppi") / str(int(group_id)) / f"{news_id}.json"
    elif category == "private":
        path = _category_dir("private") / str(conversation_id) / f"{news_id}.json"
    else:
        raise NewsStoreError(f"Categoria news non valida: {category}")

    with _LOCK:
        record = _read(path)

        _assert_owner(record, user_id, write_token)

        path.unlink(missing_ok=True)
