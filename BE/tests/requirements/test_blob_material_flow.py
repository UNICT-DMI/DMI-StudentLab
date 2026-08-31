import json
from pathlib import Path


def test_blob_function_is_built():
    config = json.loads(
        Path("vercel.json").read_text(
            encoding="utf-8",
        )
    )

    builds = config["builds"]

    assert any(
        item.get("src")
        == "api/blob-upload.ts"
        and item.get("use")
        == "@vercel/node"
        for item in builds
    )


def test_blob_route_precedes_fastapi_catch_all():
    config = json.loads(
        Path("vercel.json").read_text(
            encoding="utf-8",
        )
    )

    routes = config["routes"]

    blob_index = next(
        i
        for i, route in enumerate(routes)
        if route.get("src")
        == "/api/blob-upload"
    )

    catch_all_index = next(
        i
        for i, route in enumerate(routes)
        if route.get("src")
        == "/(.*)"
    )

    assert blob_index < catch_all_index


def test_blob_handler_uses_vercel_runtime():
    source = Path(
        "api/blob-upload.ts"
    ).read_text(
        encoding="utf-8",
    )

    assert "VercelRequest" in source
    assert "VercelResponse" in source
    assert "request.body" in source
    assert "request.json()" not in source


def test_blob_handler_restricts_upload():
    source = Path(
        "api/blob-upload.ts"
    ).read_text(
        encoding="utf-8",
    )

    assert "'put'" in source
    assert "maximumSizeInBytes" in source
    assert "allowedContentTypes" in source
    assert "validUntil" in source


def test_blob_handler_validates_hash():
    source = Path(
        "api/blob-upload.ts"
    ).read_text(
        encoding="utf-8",
    )

    assert "/^[a-fA-F0-9]{64}$/" in source


def test_blob_handler_limits_size():
    source = Path(
        "api/blob-upload.ts"
    ).read_text(
        encoding="utf-8",
    )

    assert "250 * 1024 * 1024" in source


def test_blob_handler_requires_token():
    source = Path(
        "api/blob-upload.ts"
    ).read_text(
        encoding="utf-8",
    )

    assert "StudentLab_READ_WRITE_TOKEN" in source
    assert "BLOB_READ_WRITE_TOKEN" in source