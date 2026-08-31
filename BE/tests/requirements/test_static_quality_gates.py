
import re
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[3]
FE_LIB = PROJECT_ROOT / "fe" / "lib"
BE_MAIN = PROJECT_ROOT / "BE" / "main.py"


def dart_files():
    if not FE_LIB.exists():
        return []
    return list(FE_LIB.rglob("*.dart"))


def test_no_known_hardcoded_current_user_id():
    offenders = []
    patterns = [
        re.compile(r"_currentUserId\s*=\s*1\b"),
        re.compile(r"currentUserId\s*:\s*1\b"),
    ]

    for path in dart_files():
        text = path.read_text(encoding="utf-8", errors="ignore")
        if any(pattern.search(text) for pattern in patterns):
            offenders.append(str(path.relative_to(PROJECT_ROOT)))

    assert not offenders, (
        "Sono ancora presenti ID utente hardcoded: "
        + ", ".join(offenders)
    )


def test_common_user_facing_widgets_do_not_render_error_tostring_directly():
    offenders = []
    patterns = [
        re.compile(r"Text\s*\(\s*error\.toString\s*\(\s*\)\s*\)"),
        re.compile(r"Text\s*\(\s*exception\.toString\s*\(\s*\)\s*\)"),
        re.compile(r"_error\s*=\s*error\.toString\s*\(\s*\)"),
        re.compile(r"_error\s*=\s*exception\.toString\s*\(\s*\)"),
    ]

    for path in dart_files():
        text = path.read_text(encoding="utf-8", errors="ignore")
        if any(pattern.search(text) for pattern in patterns):
            offenders.append(str(path.relative_to(PROJECT_ROOT)))

    assert not offenders, (
        "Possibile esposizione di errori tecnici nella UI: "
        + ", ".join(offenders)
    )


def test_cors_does_not_use_wildcard_origin_with_credentials():
    text = BE_MAIN.read_text(encoding="utf-8", errors="ignore")
    wildcard = re.search(
        r"allow_origins\s*=\s*\[\s*[\"']\*[\"']\s*\]",
        text,
        flags=re.S,
    )
    credentials = re.search(
        r"allow_credentials\s*=\s*True",
        text,
    )
    assert not (wildcard and credentials), (
        "CORS non sicuro: allow_origins=['*'] con allow_credentials=True"
    )
