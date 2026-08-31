import base64

from types import (
    SimpleNamespace,
)

import pytest

from fastapi.testclient import (
    TestClient,
)

from pydantic import (
    ValidationError,
)

from main import (
    app,
)

from schemas.news_report import (
    NewsReportCreate,
    NewsReportModerationRequest,
)

from services import (
    news_crypto,
    news_report,
    news_store,
)

from tests.requirements.test_private_news_disclosure import (
    DART_FIXTURE,
)


client = TestClient(
    app,
)


class FakeSession:
    def __init__(self):
        self.added = []
        self.commits = 0
        self.rollbacks = 0

    def add(
        self,
        instance,
    ):
        self.added.append(
            instance,
        )

    def commit(self):
        self.commits += 1

    def refresh(
        self,
        instance,
    ):
        return instance

    def rollback(self):
        self.rollbacks += 1


@pytest.fixture()
def news_dir(
    tmp_path,
    monkeypatch,
):
    monkeypatch.setenv(
        "StudentLab_NEWS_DIR",
        str(
            tmp_path,
        ),
    )

    app.dependency_overrides.clear()

    yield tmp_path

    app.dependency_overrides.clear()


def user(
    user_id: int,
):
    return SimpleNamespace(
        id=user_id,
        first_name="Anna",
        last_name="Rossi",
        role="student",
        is_active=True,
    )


def admin():
    return SimpleNamespace(
        id=200,
        first_name="Marco",
        last_name="Bianchi",
        role="admin",
        is_active=True,
    )


def stored_private_message():
    return news_store.create_private_news(
        sender_id=7,
        recipient_id=3,
        ciphertext=DART_FIXTURE["ciphertext"],
        algo=DART_FIXTURE["algo"],
        metadata=DART_FIXTURE["metadata"],
    )


def test_private_report_requires_consent_and_key():
    with pytest.raises(
        ValidationError,
    ):
        NewsReportCreate(
            category="private",
            news_id="abc",
            reason="harassment",
            other_user_id=7,
            disclosed_content_key=DART_FIXTURE["content_key"],
        )

    with pytest.raises(
        ValidationError,
    ):
        NewsReportCreate(
            category="private",
            news_id="abc",
            reason="harassment",
            other_user_id=7,
            disclosure_consent=True,
        )


def test_disclosure_key_is_refused_for_public_categories():
    with pytest.raises(
        ValidationError,
    ):
        NewsReportCreate(
            category="avvisi",
            news_id="abc",
            reason="spam",
            disclosed_content_key=DART_FIXTURE["content_key"],
        )


def test_group_report_requires_group():
    with pytest.raises(
        ValidationError,
    ):
        NewsReportCreate(
            category="gruppi",
            news_id="abc",
            reason="spam",
        )


def test_private_report_stores_key_encrypted_at_rest(
    news_dir,
):
    message = stored_private_message()

    db = FakeSession()

    report = news_report.create_news_report(
        db,
        user(
            3,
        ),
        NewsReportCreate(
            category="private",
            news_id=message["id"],
            reason="harassment",
            other_user_id=7,
            description="Messaggio offensivo",
            disclosed_content_key=DART_FIXTURE["content_key"],
            disclosure_consent=True,
        ),
    )

    assert db.added == [
        report,
    ]

    assert report.reporter_user_id == 3
    assert report.reported_user_id == 7
    assert report.conversation_id == "3_7"
    assert report.disclosure_consent_at is not None

    assert report.disclosed_content_key.startswith(
        "enc:v1:",
    )

    assert (
        news_crypto.decrypt_at_rest(
            report.disclosed_content_key,
        )
        == DART_FIXTURE["content_key"]
    )


def test_private_report_rejects_unverifiable_key(
    news_dir,
):
    message = stored_private_message()

    raw = bytearray(
        base64.b64decode(
            DART_FIXTURE["content_key"],
        ),
    )

    raw[0] ^= 0xFF

    wrong_key = base64.b64encode(
        bytes(
            raw,
        ),
    ).decode("ascii")

    with pytest.raises(
        ValueError,
    ):
        news_report.create_news_report(
            FakeSession(),
            user(
                3,
            ),
            NewsReportCreate(
                category="private",
                news_id=message["id"],
                reason="harassment",
                other_user_id=7,
                disclosed_content_key=wrong_key,
                disclosure_consent=True,
            ),
        )


def test_private_report_requires_participation(
    news_dir,
):
    message = stored_private_message()

    with pytest.raises(
        news_store.NewsNotFound,
    ):
        news_report.create_news_report(
            FakeSession(),
            user(
                99,
            ),
            NewsReportCreate(
                category="private",
                news_id=message["id"],
                reason="harassment",
                other_user_id=7,
                disclosed_content_key=DART_FIXTURE["content_key"],
                disclosure_consent=True,
            ),
        )


def test_disclosure_returns_verified_plaintext(
    news_dir,
):
    message = stored_private_message()

    db = FakeSession()

    report = news_report.create_news_report(
        db,
        user(
            3,
        ),
        NewsReportCreate(
            category="private",
            news_id=message["id"],
            reason="illegal_content",
            other_user_id=7,
            disclosed_content_key=DART_FIXTURE["content_key"],
            disclosure_consent=True,
        ),
    )

    disclosure = news_report.open_report_disclosure(
        db,
        report,
        admin(),
    )

    assert disclosure["content"] == DART_FIXTURE["plaintext"]
    assert disclosure["verified"] is True
    assert disclosure["wrap_targets"] == [
        "3:device-recipient",
    ]

    assert report.disclosure_opened_at is not None
    assert report.disclosure_opened_by_user_id == 200


def test_avviso_report_cannot_be_created_by_its_author(
    news_dir,
):
    avviso = news_store.create_avviso(
        author_id=5,
        author_name="Admin",
        author_role="admin",
        title="T",
        content="C",
    )

    with pytest.raises(
        ValueError,
    ):
        news_report.create_news_report(
            FakeSession(),
            user(
                5,
            ),
            NewsReportCreate(
                category="avvisi",
                news_id=avviso["id"],
                reason="spam",
            ),
        )


def test_moderation_hides_the_reported_avviso(
    news_dir,
):
    avviso = news_store.create_avviso(
        author_id=5,
        author_name="Admin",
        author_role="admin",
        title="Titolo",
        content="Contenuto",
    )

    db = FakeSession()

    report = news_report.create_news_report(
        db,
        user(
            3,
        ),
        NewsReportCreate(
            category="avvisi",
            news_id=avviso["id"],
            reason="spam",
        ),
    )

    news_report.moderate_news_report(
        db,
        report,
        admin(),
        NewsReportModerationRequest(
            status="resolved",
            action="hide_news",
            note="Contenuto pubblicitario",
        ),
    )

    assert report.status == "resolved"
    assert report.moderation_action == "hide_news"
    assert report.reviewed_by_user_id == 200

    assert news_store.list_avvisi() == []

    hidden = news_store.list_avvisi(
        include_moderated=True,
    )

    assert len(hidden) == 1
    assert news_store.status_of(hidden[0]) == "hidden"
    assert hidden[0]["moderation_reason"] == "Contenuto pubblicitario"

    with pytest.raises(
        news_store.NewsNotFound,
    ):
        news_store.get_avviso(
            avviso["id"],
        )

    assert news_store.get_avviso(
        avviso["id"],
        include_moderated=True,
    )["title"] == "Titolo"


def test_moderation_requires_a_note_to_hide(
    news_dir,
):
    avviso = news_store.create_avviso(
        author_id=5,
        author_name="Admin",
        author_role="admin",
        title="Titolo",
        content="Contenuto",
    )

    db = FakeSession()

    report = news_report.create_news_report(
        db,
        user(
            3,
        ),
        NewsReportCreate(
            category="avvisi",
            news_id=avviso["id"],
            reason="spam",
        ),
    )

    with pytest.raises(
        ValueError,
    ):
        news_report.moderate_news_report(
            db,
            report,
            admin(),
            NewsReportModerationRequest(
                status="resolved",
                action="hide_news",
            ),
        )

    assert len(
        news_store.list_avvisi(),
    ) == 1


@pytest.mark.parametrize(
    "method,path",
    [
        (
            "post",
            "/news-reports",
        ),
        (
            "get",
            "/me/news-reports",
        ),
        (
            "get",
            "/admin/news-reports",
        ),
        (
            "patch",
            "/admin/news-reports/1",
        ),
        (
            "get",
            "/admin/news-reports/1/disclosure",
        ),
    ],
)
def test_report_endpoints_reject_anonymous_user(
    method,
    path,
):
    if method == "post":
        response = client.post(
            path,
            json={},
        )
    elif method == "patch":
        response = client.patch(
            path,
            json={
                "status": "resolved",
            },
        )
    else:
        response = client.get(
            path,
        )

    assert response.status_code in {
        401,
        403,
    }, (
        f"{method.upper()} {path} accessibile senza "
        f"autenticazione: {response.status_code}"
    )


@pytest.mark.parametrize(
    "path,method",
    [
        (
            "/admin/news-reports",
            "GET",
        ),
        (
            "/admin/news-reports/{report_id}",
            "PATCH",
        ),
        (
            "/admin/news-reports/{report_id}/disclosure",
            "GET",
        ),
    ],
)
def test_admin_report_routes_depend_on_admin_user(
    path,
    method,
):
    import routes.news_report as report_routes

    names = set()

    for route in report_routes.router.routes:
        if getattr(
            route,
            "path",
            None,
        ) != path or method not in (
            getattr(
                route,
                "methods",
                None,
            )
            or set()
        ):
            continue

        for dependency in route.dependant.dependencies:
            names.add(
                getattr(
                    dependency.call,
                    "__name__",
                    "",
                ),
            )

    assert "get_admin_user" in names, (
        f"{method} {path} deve dipendere da get_admin_user; "
        f"trovate: {names}"
    )
