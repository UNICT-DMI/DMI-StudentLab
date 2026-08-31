import json
from pathlib import Path


def test_blob_upload_route_exists_in_vercel_config():
    vercel_config_path = Path("vercel.json")

    assert vercel_config_path.exists()

    config = json.loads(
        vercel_config_path.read_text(
            encoding="utf-8",
        )
    )

    builds = config.get(
        "builds",
        [],
    )

    routes = config.get(
        "routes",
        [],
    )

    blob_build = next(
        (
            build
            for build in builds
            if build.get("src")
            == "api/blob-upload.ts"
        ),
        None,
    )

    assert blob_build is not None
    assert (
        blob_build.get("use")
        == "@vercel/node"
    )

    blob_route = next(
        (
            route
            for route in routes
            if route.get("src")
            == "/api/blob-upload"
        ),
        None,
    )

    assert blob_route is not None
    assert (
        blob_route.get("dest")
        == "/api/blob-upload.ts"
    )


def test_blob_upload_route_precedes_fastapi_catch_all():
    config = json.loads(
        Path("vercel.json").read_text(
            encoding="utf-8",
        )
    )

    routes = config.get(
        "routes",
        [],
    )

    blob_index = next(
        index
        for index, route in enumerate(
            routes
        )
        if route.get("src")
        == "/api/blob-upload"
    )

    catch_all_index = next(
        index
        for index, route in enumerate(
            routes
        )
        if route.get("src")
        == "/(.*)"
    )

    assert blob_index < catch_all_index


def test_blob_upload_handler_uses_vercel_node_request_response():
    source = Path(
        "api/blob-upload.ts"
    ).read_text(
        encoding="utf-8",
    )

    assert (
        "VercelRequest"
        in source
    )

    assert (
        "VercelResponse"
        in source
    )

    assert (
        "request.body"
        in source
    )

    assert (
        "request.json()"
        not in source
    )


def test_blob_upload_handler_restricts_signed_token():
    source = Path(
        "api/blob-upload.ts"
    ).read_text(
        encoding="utf-8",
    )

    assert "pathname," in source

    assert (
        "operations: ["
        in source
    )

    assert (
        "'put'"
        in source
    )

    assert (
        "maximumSizeInBytes"
        in source
    )

    assert (
        "allowedContentTypes"
        in source
    )

    assert (
        "validUntil"
        in source
    )


def test_blob_upload_handler_requires_blob_token():
    source = Path(
        "api/blob-upload.ts"
    ).read_text(
        encoding="utf-8",
    )

    assert (
        "StudentLab_READ_WRITE_TOKEN"
        in source
    )

    assert (
        "BLOB_READ_WRITE_TOKEN"
        in source
    )

    assert (
        "Token Vercel Blob non configurato."
        in source
    )


def test_blob_upload_handler_validates_file_constraints():
    source = Path(
        "api/blob-upload.ts"
    ).read_text(
        encoding="utf-8",
    )

    assert (
        "250 * 1024 * 1024"
        in source
    )

    assert (
        "ALLOWED_CONTENT_TYPES"
        in source
    )

    assert (
        "/^[a-fA-F0-9]{64}$/"
        in source
    )

    assert (
        "ID gruppo non valido."
        in source
    )

    assert (
        "ID utente non valido."
        in source
    )

    assert (
        "Tipo di file non supportato."
        in source
    )

    assert (
        "Hash del file non valido."
        in source
    )