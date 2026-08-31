import json

import pytest

from services import news_crypto, news_store


@pytest.fixture()
def news_dir(tmp_path, monkeypatch):
    monkeypatch.setenv("StudentLab_NEWS_DIR", str(tmp_path))
    return tmp_path


def _raw(path):
    return path.read_text(encoding="utf-8")


def test_avvisi_create_list_reply(news_dir):
    avviso = news_store.create_avviso(
        author_id=1,
        author_name="Admin",
        author_role="admin",
        title="Manutenzione",
        content="Domani stop",
    )

    assert avviso["write_token"]
    assert news_store.get_avviso(avviso["id"])["title"] == "Manutenzione"
    assert len(news_store.list_avvisi()) == 1

    news_store.add_reply(
        category="avvisi",
        group_id=None,
        news_id=avviso["id"],
        author_id=2,
        author_name="Bob",
        content="ok",
    )

    replies = news_store.get_avviso(avviso["id"])["replies"]
    assert replies[0]["author_name"] == "Bob"


def test_group_news_scoped_by_group(news_dir):
    news_store.create_group_news(
        group_id=12,
        group_name="Reti",
        author_id=1,
        author_name="Admin",
        author_role="admin",
        content="ciao gruppo",
    )

    assert news_store.list_group_news(12)[0]["group_name"] == "Reti"
    assert news_store.list_group_news(99) == []


def test_private_stores_only_ciphertext(news_dir):
    private = news_store.create_private_news(
        sender_id=7,
        recipient_id=3,
        ciphertext="BASE64CIPHERTEXT",
        algo="x25519-aesgcm",
    )

    assert private["conversation_id"] == "3_7"

    raw = (
        news_dir / "private" / "3_7" / f"{private['id']}.json"
    ).read_text(encoding="utf-8")

    assert "BASE64CIPHERTEXT" in raw

    assert len(news_store.list_private_conversation(7, 3)) == 1
    assert len(news_store.list_private_for_user(7)) == 1
    assert news_store.list_private_for_user(999) == []


def test_delete_requires_owner_and_token(news_dir):
    avviso = news_store.create_avviso(
        author_id=1,
        author_name="Admin",
        author_role="admin",
        title="T",
        content="C",
    )

    with pytest.raises(news_store.NewsPermissionDenied):
        news_store.delete_news(
            category="avvisi",
            news_id=avviso["id"],
            user_id=999,
            write_token=avviso["write_token"],
        )

    with pytest.raises(news_store.NewsPermissionDenied):
        news_store.delete_news(
            category="avvisi",
            news_id=avviso["id"],
            user_id=1,
            write_token="wrong",
        )

    news_store.delete_news(
        category="avvisi",
        news_id=avviso["id"],
        user_id=1,
        write_token=avviso["write_token"],
    )

    assert news_store.list_avvisi() == []


def test_avviso_text_is_encrypted_at_rest(news_dir):
    avviso = news_store.create_avviso(
        author_id=1,
        author_name="Admin",
        author_role="admin",
        title="Manutenzione",
        content="Domani stop",
    )

    raw = _raw(news_dir / "avvisi" / f"{avviso['id']}.json")

    assert "Manutenzione" not in raw
    assert "Domani stop" not in raw
    assert raw.count("enc:v1:") == 2

    assert "Admin" in raw

    stored = news_store.get_avviso(avviso["id"])

    assert stored["title"] == "Manutenzione"
    assert stored["content"] == "Domani stop"
    assert news_store.list_avvisi()[0]["content"] == "Domani stop"


def test_reply_content_is_encrypted_at_rest(news_dir):
    avviso = news_store.create_avviso(
        author_id=1,
        author_name="Admin",
        author_role="admin",
        title="Titolo",
        content="Contenuto",
    )

    news_store.add_reply(
        category="avvisi",
        group_id=None,
        news_id=avviso["id"],
        author_id=2,
        author_name="Bob",
        content="risposta segreta",
    )

    path = news_dir / "avvisi" / f"{avviso['id']}.json"
    raw = _raw(path)

    assert "risposta segreta" not in raw
    assert "Bob" in raw

    stored = news_store.get_avviso(avviso["id"])

    assert stored["title"] == "Titolo"
    assert stored["content"] == "Contenuto"
    assert stored["replies"][0]["content"] == "risposta segreta"

    payload = json.loads(raw)

    assert payload["title"].count("enc:v1:") == 1
    assert payload["content"].count("enc:v1:") == 1


def test_group_news_content_is_encrypted_at_rest(news_dir):
    news = news_store.create_group_news(
        group_id=12,
        group_name="Reti",
        author_id=1,
        author_name="Admin",
        author_role="admin",
        content="ciao gruppo",
    )

    raw = _raw(news_dir / "gruppi" / "12" / f"{news['id']}.json")

    assert "ciao gruppo" not in raw
    assert "Reti" in raw

    assert news_store.list_group_news(12)[0]["content"] == "ciao gruppo"


def test_private_ciphertext_is_not_re_encrypted(news_dir):
    private = news_store.create_private_news(
        sender_id=7,
        recipient_id=3,
        ciphertext="BASE64CIPHERTEXT",
        algo="x25519-aesgcm",
    )

    raw = _raw(news_dir / "private" / "3_7" / f"{private['id']}.json")

    assert "enc:v1:" not in raw

    stored = news_store.list_private_conversation(7, 3)[0]

    assert stored["ciphertext"] == "BASE64CIPHERTEXT"


def test_legacy_plaintext_records_stay_readable(news_dir):
    legacy_dir = news_dir / "avvisi"
    legacy_dir.mkdir(parents=True)

    (legacy_dir / "legacy.json").write_text(
        json.dumps(
            {
                "id": "legacy",
                "type": "avviso",
                "author_id": 1,
                "author_name": "Admin",
                "author_role": "admin",
                "title": "Vecchio titolo",
                "content": "Vecchio contenuto",
                "created_at": "2026-01-01T00:00:00+00:00",
                "updated_at": "2026-01-01T00:00:00+00:00",
                "write_token": "legacy-token",
                "replies": [],
            }
        ),
        encoding="utf-8",
    )

    stored = news_store.get_avviso("legacy")

    assert stored["title"] == "Vecchio titolo"
    assert stored["content"] == "Vecchio contenuto"

    news_store.add_reply(
        category="avvisi",
        group_id=None,
        news_id="legacy",
        author_id=2,
        author_name="Bob",
        content="ok",
    )

    raw = _raw(legacy_dir / "legacy.json")

    assert "Vecchio titolo" not in raw

    migrated = news_store.get_avviso("legacy")

    assert migrated["title"] == "Vecchio titolo"
    assert migrated["replies"][0]["content"] == "ok"


def test_at_rest_crypto_roundtrip_uses_random_tokens():
    first = news_crypto.encrypt_at_rest("segreto")
    second = news_crypto.encrypt_at_rest("segreto")

    assert first != second
    assert first.startswith("enc:v1:")

    assert news_crypto.decrypt_at_rest(first) == "segreto"
    assert news_crypto.decrypt_at_rest(second) == "segreto"

    assert news_crypto.encrypt_at_rest(None) is None
    assert news_crypto.decrypt_at_rest(None) is None
    assert news_crypto.decrypt_at_rest("testo in chiaro") == "testo in chiaro"
