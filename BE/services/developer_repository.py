from __future__ import annotations

from dataclasses import (
    dataclass,
)

from hashlib import (
    sha256,
)

from pathlib import (
    Path,
)

from typing import (
    Any,
)

from urllib.error import (
    HTTPError,
    URLError,
)

from urllib.parse import (
    quote,
)

from urllib.request import (
    Request,
    urlopen,
)

import io
import json
import os
import shutil
import subprocess
import tempfile
import zipfile


DEFAULT_IGNORED_DIRECTORIES = {
    ".dart_tool",
    ".git",
    ".idea",
    ".pytest_cache",
    ".venv",
    ".vscode",
    "__pycache__",
    "build",
    "coverage",
    "dist",
    "node_modules",
    "storage",
}

DEFAULT_IGNORED_FILES = {
    ".env",
    ".env.local",
    ".env.production",
    ".env.development",
    ".studentlab-developer-source",
}

DEFAULT_IGNORED_SUFFIXES = {
    ".db",
    ".sqlite",
    ".sqlite3",
    ".key",
    ".pem",
    ".p12",
    ".pfx",
    ".jks",
    ".keystore",
    ".png",
    ".jpg",
    ".jpeg",
    ".gif",
    ".webp",
    ".ico",
    ".pdf",
    ".zip",
    ".jar",
    ".class",
    ".so",
    ".dll",
    ".dylib",
    ".mp4",
    ".mov",
    ".avi",
}

DEFAULT_SOURCE_SUFFIXES = {
    ".py",
    ".dart",
    ".md",
    ".txt",
    ".json",
    ".yaml",
    ".yml",
    ".toml",
    ".xml",
    ".gradle",
    ".kts",
    ".sql",
    ".html",
    ".css",
    ".js",
    ".ts",
    ".tsx",
    ".jsx",
    ".sh",
}

MAX_INDEXED_FILE_SIZE = (
    2 * 1024 * 1024
)

GITHUB_API_BASE = (
    "https://api.github.com"
)

DEFAULT_GITHUB_OWNER = (
    "FranzAmoroso"
)

DEFAULT_GITHUB_REPOSITORY = (
    "DMI-StudentLab"
)

DEFAULT_GITHUB_BRANCH = (
    "main"
)

SOURCE_MARKER_NAME = (
    ".studentlab-developer-source"
)


@dataclass(
    frozen=True,
)
class RepositoryFile:
    path: str
    absolute_path: Path
    size_bytes: int
    modified_at: float
    content_hash: str


@dataclass(
    frozen=True,
)
class RepositorySourceInfo:
    source_type: str
    repository_name: str
    repository_label: str
    branch: str | None
    head_commit: str | None
    git_available: bool
    remote_url: str | None = None


def developer_source_mode() -> str:
    value = (
        os.getenv(
            "STUDENTLAB_DEVELOPER_SOURCE",
            "github",
        )
        .strip()
        .lower()
    )

    if value not in {
        "github",
        "local",
        "deployed",
    }:
        raise RuntimeError(
            "STUDENTLAB_DEVELOPER_SOURCE "
            "non valido. Usa github, local "
            "oppure deployed.",
        )

    return value


def github_owner() -> str:
    return (
        os.getenv(
            "STUDENTLAB_GITHUB_OWNER",
            DEFAULT_GITHUB_OWNER,
        )
        .strip()
        or DEFAULT_GITHUB_OWNER
    )


def github_repository() -> str:
    value = (
        os.getenv(
            "STUDENTLAB_GITHUB_REPO",
            DEFAULT_GITHUB_REPOSITORY,
        )
        .strip()
    )

    if value.endswith(
        ".git",
    ):
        value = value[:-4]

    return (
        value
        or DEFAULT_GITHUB_REPOSITORY
    )


def github_branch() -> str:
    return (
        os.getenv(
            "STUDENTLAB_GITHUB_BRANCH",
            DEFAULT_GITHUB_BRANCH,
        )
        .strip()
        or DEFAULT_GITHUB_BRANCH
    )


def github_repository_url() -> str:
    return (
        "https://github.com/"
        f"{github_owner()}/"
        f"{github_repository()}"
    )


def _github_headers() -> dict[str, str]:
    headers = {
        "Accept":
            "application/vnd.github+json",
        "X-GitHub-Api-Version":
            "2026-03-10",
        "User-Agent":
            "StudentLab-Developer-System",
    }

    token = (
        os.getenv(
            "STUDENTLAB_GITHUB_TOKEN",
        )
        or os.getenv(
            "GITHUB_TOKEN",
        )
    )

    if (
        token is not None
        and token.strip()
    ):
        headers[
            "Authorization"
        ] = (
            "Bearer "
            + token.strip()
        )

    return headers


def _github_request(
    url: str,
    *,
    accept: str | None = None,
) -> bytes:
    headers = _github_headers()

    if accept is not None:
        headers[
            "Accept"
        ] = accept

    request = Request(
        url,
        headers=headers,
        method="GET",
    )

    try:
        with urlopen(
            request,
            timeout=30,
        ) as response:
            return response.read()

    except HTTPError as exception:
        if exception.code == 401:
            message = (
                "GitHub ha rifiutato "
                "l'autenticazione."
            )
        elif exception.code == 403:
            message = (
                "Accesso GitHub negato o "
                "rate limit raggiunto."
            )
        elif exception.code == 404:
            message = (
                "Repository o branch GitHub "
                "non trovato."
            )
        else:
            message = (
                "GitHub non è disponibile "
                f"(HTTP {exception.code})."
            )

        raise RuntimeError(
            message,
        ) from exception

    except URLError as exception:
        raise RuntimeError(
            "Impossibile raggiungere GitHub.",
        ) from exception


def _github_json(
    url: str,
) -> dict[str, Any]:
    raw = _github_request(
        url,
    )

    try:
        decoded = json.loads(
            raw.decode(
                "utf-8",
            ),
        )
    except (
        UnicodeDecodeError,
        json.JSONDecodeError,
    ) as exception:
        raise RuntimeError(
            "Risposta GitHub non valida.",
        ) from exception

    if not isinstance(
        decoded,
        dict,
    ):
        raise RuntimeError(
            "Risposta GitHub inattesa.",
        )

    return decoded


def github_head_commit() -> str:
    owner = quote(
        github_owner(),
        safe="",
    )

    repository = quote(
        github_repository(),
        safe="",
    )

    branch = quote(
        github_branch(),
        safe="",
    )

    data = _github_json(
        f"{GITHUB_API_BASE}/repos/"
        f"{owner}/{repository}/commits/"
        f"{branch}",
    )

    sha = data.get(
        "sha",
    )

    if (
        not isinstance(
            sha,
            str,
        )
        or not sha.strip()
    ):
        raise RuntimeError(
            "SHA GitHub non disponibile.",
        )

    return sha.strip()


def _github_cache_root() -> Path:
    configured = os.getenv(
        "STUDENTLAB_DEVELOPER_CACHE_ROOT",
    )

    if configured:
        root = Path(
            configured,
        ).expanduser()
    else:
        root = (
            Path(
                tempfile.gettempdir(),
            )
            / "studentlab-developer"
        )

    root.mkdir(
        parents=True,
        exist_ok=True,
    )

    return root.resolve()


def _safe_extract_zip(
    payload: bytes,
    destination: Path,
) -> Path:
    destination.mkdir(
        parents=True,
        exist_ok=True,
    )

    with zipfile.ZipFile(
        io.BytesIO(
            payload,
        ),
    ) as archive:
        members = (
            archive.infolist()
        )

        if not members:
            raise RuntimeError(
                "Archivio GitHub vuoto.",
            )

        top_levels = {
            Path(
                member.filename,
            ).parts[0]
            for member in members
            if Path(
                member.filename,
            ).parts
        }

        if len(
            top_levels,
        ) != 1:
            raise RuntimeError(
                "Archivio GitHub non valido.",
            )

        top_level = next(
            iter(
                top_levels,
            ),
        )

        destination_resolved = (
            destination.resolve()
        )

        for member in members:
            member_path = (
                destination
                / member.filename
            ).resolve()

            try:
                member_path.relative_to(
                    destination_resolved,
                )
            except ValueError as exception:
                raise RuntimeError(
                    "Archivio GitHub contiene "
                    "un percorso non sicuro.",
                ) from exception

        archive.extractall(
            destination,
        )

    extracted_root = (
        destination
        / top_level
    ).resolve()

    if (
        not extracted_root.exists()
        or not extracted_root.is_dir()
    ):
        raise RuntimeError(
            "Repository GitHub non estratta.",
        )

    return extracted_root


def _write_source_marker(
    repository_root: Path,
    *,
    head_commit: str,
) -> None:
    marker = (
        repository_root
        / SOURCE_MARKER_NAME
    )

    marker.write_text(
        json.dumps(
            {
                "source_type":
                    "remote",
                "repository_name":
                    github_repository(),
                "repository_label":
                    (
                        f"{github_owner()}/"
                        f"{github_repository()}"
                    ),
                "branch":
                    github_branch(),
                "head_commit":
                    head_commit,
                "git_available":
                    True,
                "remote_url":
                    github_repository_url(),
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )


def _read_source_marker(
    repository_root: Path,
) -> RepositorySourceInfo | None:
    marker = (
        repository_root
        / SOURCE_MARKER_NAME
    )

    if not marker.exists():
        return None

    try:
        data = json.loads(
            marker.read_text(
                encoding="utf-8",
            ),
        )
    except (
        OSError,
        json.JSONDecodeError,
    ):
        return None

    if not isinstance(
        data,
        dict,
    ):
        return None

    return RepositorySourceInfo(
        source_type=str(
            data.get(
                "source_type",
                "remote",
            ),
        ),
        repository_name=str(
            data.get(
                "repository_name",
                repository_root.name,
            ),
        ),
        repository_label=str(
            data.get(
                "repository_label",
                repository_root.name,
            ),
        ),
        branch=(
            str(
                data[
                    "branch"
                ],
            )
            if data.get(
                "branch",
            )
            else None
        ),
        head_commit=(
            str(
                data[
                    "head_commit"
                ],
            )
            if data.get(
                "head_commit",
            )
            else None
        ),
        git_available=bool(
            data.get(
                "git_available",
                True,
            ),
        ),
        remote_url=(
            str(
                data[
                    "remote_url"
                ],
            )
            if data.get(
                "remote_url",
            )
            else None
        ),
    )


def materialize_github_repository() -> Path:
    head_commit = (
        github_head_commit()
    )

    cache_root = (
        _github_cache_root()
    )

    cache_key = (
        f"{github_owner()}__"
        f"{github_repository()}__"
        f"{head_commit}"
    )

    final_root = (
        cache_root
        / cache_key
    )

    marker = (
        final_root
        / SOURCE_MARKER_NAME
    )

    if (
        final_root.exists()
        and final_root.is_dir()
        and marker.exists()
    ):
        return final_root.resolve()

    working = (
        cache_root
        / (
            cache_key
            + ".building"
        )
    )

    if working.exists():
        shutil.rmtree(
            working,
            ignore_errors=True,
        )

    working.mkdir(
        parents=True,
        exist_ok=True,
    )

    owner = quote(
        github_owner(),
        safe="",
    )

    repository = quote(
        github_repository(),
        safe="",
    )

    ref = quote(
        head_commit,
        safe="",
    )

    try:
        payload = _github_request(
            f"{GITHUB_API_BASE}/repos/"
            f"{owner}/{repository}/zipball/"
            f"{ref}",
            accept=(
                "application/vnd.github+json"
            ),
        )

        extracted = (
            _safe_extract_zip(
                payload,
                working,
            )
        )

        temporary_root = (
            cache_root
            / (
                cache_key
                + ".ready"
            )
        )

        if temporary_root.exists():
            shutil.rmtree(
                temporary_root,
                ignore_errors=True,
            )

        shutil.move(
            str(
                extracted,
            ),
            str(
                temporary_root,
            ),
        )

        _write_source_marker(
            temporary_root,
            head_commit=head_commit,
        )

        if final_root.exists():
            shutil.rmtree(
                final_root,
                ignore_errors=True,
            )

        temporary_root.rename(
            final_root,
        )

    finally:
        if working.exists():
            shutil.rmtree(
                working,
                ignore_errors=True,
            )

    return final_root.resolve()


def resolve_repository_root() -> Path:
    mode = developer_source_mode()

    if mode == "github":
        return (
            materialize_github_repository()
        )

    configured = os.getenv(
        "STUDENTLAB_REPOSITORY_ROOT",
    )

    if configured:
        root = Path(
            configured,
        ).expanduser()
    else:
        current_file = Path(
            __file__,
        ).resolve()

        if mode == "deployed":
            candidates = [
                current_file.parents[2],
                current_file.parents[1],
                Path.cwd(),
            ]
        else:
            candidates = [
                Path.cwd(),
                current_file.parents[2],
                current_file.parents[1],
            ]

        root = next(
            (
                candidate
                for candidate in candidates
                if candidate.exists()
                and candidate.is_dir()
            ),
            current_file.parents[1],
        )

    root = root.resolve()

    if not root.exists():
        raise RuntimeError(
            "Repository StudentLab non trovato.",
        )

    if not root.is_dir():
        raise RuntimeError(
            "Il percorso repository non è "
            "una cartella.",
        )

    return root


def ensure_path_inside_repository(
    repository_root: Path,
    relative_path: str,
) -> Path:
    candidate = (
        repository_root
        / relative_path
    ).resolve()

    try:
        candidate.relative_to(
            repository_root,
        )
    except ValueError as exception:
        raise ValueError(
            "Percorso repository non valido.",
        ) from exception

    return candidate


def should_index_file(
    path: Path,
) -> bool:
    if path.name in DEFAULT_IGNORED_FILES:
        return False

    if path.suffix.lower() in (
        DEFAULT_IGNORED_SUFFIXES
    ):
        return False

    if (
        path.suffix.lower()
        not in DEFAULT_SOURCE_SUFFIXES
        and path.name not in {
            "Dockerfile",
            "Procfile",
        }
    ):
        return False

    try:
        if (
            path.stat().st_size
            > MAX_INDEXED_FILE_SIZE
        ):
            return False
    except OSError:
        return False

    return True


def iter_repository_files(
    repository_root: Path,
) -> list[RepositoryFile]:
    result: list[
        RepositoryFile
    ] = []

    for current_root, directories, names in os.walk(
        repository_root,
    ):
        directories[:] = [
            name
            for name in directories
            if name
            not in DEFAULT_IGNORED_DIRECTORIES
        ]

        current = Path(
            current_root,
        )

        for name in names:
            absolute = current / name

            if not should_index_file(
                absolute,
            ):
                continue

            try:
                raw = absolute.read_bytes()
                stat = absolute.stat()
            except OSError:
                continue

            relative = (
                absolute
                .relative_to(
                    repository_root,
                )
                .as_posix()
            )

            result.append(
                RepositoryFile(
                    path=relative,
                    absolute_path=absolute,
                    size_bytes=stat.st_size,
                    modified_at=stat.st_mtime,
                    content_hash=(
                        sha256(
                            raw,
                        ).hexdigest()
                    ),
                ),
            )

    result.sort(
        key=lambda item: item.path,
    )

    return result


def _run_git(
    repository_root: Path,
    *args: str,
) -> str | None:
    try:
        process = subprocess.run(
            [
                "git",
                "-C",
                str(repository_root),
                *args,
            ],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
    except (
        OSError,
        subprocess.SubprocessError,
    ):
        return None

    if process.returncode != 0:
        return None

    return process.stdout.strip()


def repository_source_info(
    repository_root: Path,
) -> RepositorySourceInfo:
    marker = _read_source_marker(
        repository_root,
    )

    if marker is not None:
        return marker

    branch = _run_git(
        repository_root,
        "branch",
        "--show-current",
    )

    head = _run_git(
        repository_root,
        "rev-parse",
        "HEAD",
    )

    git_is_available = (
        _run_git(
            repository_root,
            "rev-parse",
            "--is-inside-work-tree",
        )
        == "true"
    )

    source_type = (
        "local"
        if developer_source_mode()
        == "local"
        else "remote"
        if developer_source_mode()
        == "github"
        else "local"
    )

    return RepositorySourceInfo(
        source_type=source_type,
        repository_name=(
            repository_root.name
        ),
        repository_label=(
            os.getenv(
                "STUDENTLAB_REPOSITORY_LABEL",
                repository_root.name,
            )
        ),
        branch=(
            branch
            or None
        ),
        head_commit=(
            head
            or None
        ),
        git_available=(
            git_is_available
        ),
        remote_url=None,
    )


def git_branch(
    repository_root: Path,
) -> str | None:
    return repository_source_info(
        repository_root,
    ).branch


def git_head_commit(
    repository_root: Path,
) -> str | None:
    return repository_source_info(
        repository_root,
    ).head_commit


def git_changed_paths(
    repository_root: Path,
) -> set[str]:
    info = repository_source_info(
        repository_root,
    )

    if info.source_type == "remote":
        return set()

    value = _run_git(
        repository_root,
        "status",
        "--porcelain=v1",
        "-z",
        "--untracked-files=all",
    )

    if not value:
        return set()

    chunks = value.split(
        "\x00",
    )

    changed: set[str] = set()

    for chunk in chunks:
        if not chunk:
            continue

        if len(chunk) < 4:
            continue

        path = chunk[3:]

        if " -> " in path:
            path = path.split(
                " -> ",
                1,
            )[1]

        changed.add(
            path.replace(
                "\\",
                "/",
            ),
        )

    return changed


def git_available(
    repository_root: Path,
) -> bool:
    return repository_source_info(
        repository_root,
    ).git_available