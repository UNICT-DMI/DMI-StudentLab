import os
import sys
import traceback


REQUIRED_ENV = (
    ("StudentLab_SECRET_KEY", "SECRET_KEY"),
    ("StudentLab_DATABASE_URL", "DATABASE_URL"),
)


def configured(names):
    for name in names:
        value = os.getenv(name)
        if value and value.strip() and value.strip().upper() not in {
            "[SENSITIVE]",
            "<SENSITIVE>",
            "SENSITIVE",
        }:
            return True
    return False


def main():
    print("StudentLab backend startup check")
    print(f"Python: {sys.version.split()[0]}")
    print(f"VERCEL: {os.getenv('VERCEL', '0')}")
    print(f"VERCEL_ENV: {os.getenv('VERCEL_ENV', '-')}")

    missing = [
        " / ".join(names)
        for names in REQUIRED_ENV
        if not configured(names)
    ]

    if missing:
        print("Environment mancanti:")
        for item in missing:
            print(f"- {item}")
        return 2

    try:
        from main import app
    except Exception:
        print("IMPORT main FALLITO")
        traceback.print_exc()
        return 1

    routes = []
    for route in app.routes:
        path = getattr(route, "path", "")
        methods = sorted(getattr(route, "methods", []) or [])
        routes.append((path, methods))

    print(f"IMPORT OK - routes: {len(routes)}")

    root = [item for item in routes if item[0] == "/"]
    developer = [item for item in routes if item[0].startswith("/developer")]

    print(f"Root route: {'OK' if root else 'MANCANTE'}")
    print(f"Developer routes: {len(developer)}")

    return 0 if root else 3


if __name__ == "__main__":
    raise SystemExit(main())
