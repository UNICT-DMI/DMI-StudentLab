from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from urllib.parse import urlparse

from bs4 import BeautifulSoup
from playwright.sync_api import (
    Error as PlaywrightError,
    TimeoutError as PlaywrightTimeoutError,
    sync_playwright,
)


SCRIPT_DIR = Path(__file__).resolve().parent

DEFAULT_OUTPUT_PATH = "output"
DEFAULT_EXTENSION = ".txt"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="scraper.py",
        description=(
            "Estrae il testo leggibile da una pagina web e lo salva "
            "in un file di testo."
        ),
        epilog=(
            "Esempi:\n"
            '  python scraper.py\n'
            '  python scraper.py -u "https://example.com"\n'
            '  python scraper.py -u "https://example.com" -n appunti\n'
            '  python scraper.py -u "https://example.com" '
            "-n reti_cap3 -p appunti/reti\n"
            '  python scraper.py --url "https://example.com" '
            "--name reti --path output\n"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    parser.add_argument(
        "-u",
        "--url",
        type=str,
        help="URL della pagina da estrarre.",
    )

    parser.add_argument(
        "-n",
        "--name",
        type=str,
        help=(
            "Nome del file di output. "
            "L'estensione .txt viene aggiunta automaticamente se assente."
        ),
    )

    parser.add_argument(
        "-p",
        "--path",
        type=str,
        help=(
            "Percorso relativo alla cartella dello script "
            f"in cui salvare il file. Default: {DEFAULT_OUTPUT_PATH}"
        ),
    )

    parser.add_argument(
        "--show-browser",
        action="store_true",
        help=(
            "Mostra il browser durante lo scraping. "
            "Utile per login manuali o debug."
        ),
    )

    parser.add_argument(
        "--timeout",
        type=int,
        default=120,
        help="Timeout massimo di caricamento in secondi. Default: 120.",
    )

    parser.add_argument(
        "--keep-links",
        action="store_true",
        help="Mantiene gli URL dei link accanto al relativo testo.",
    )

    parser.add_argument(
        "--html",
        action="store_true",
        help="Salva anche una copia del codice HTML della pagina.",
    )

    return parser.parse_args()


def clean_input(value: str | None) -> str:
    return value.strip() if value else ""


def ask_if_missing(
    current_value: str | None,
    message: str,
    default: str | None = None,
) -> str:
    value = clean_input(current_value)

    if value:
        return value

    if default:
        entered = input(f"{message} [{default}]: ").strip()
        return entered or default

    while True:
        entered = input(f"{message}: ").strip()

        if entered:
            return entered

        print("Il valore non può essere vuoto.")


def validate_url(url: str) -> str:
    url = url.strip()

    if not url.startswith(("http://", "https://")):
        url = f"https://{url}"

    parsed = urlparse(url)

    if not parsed.netloc:
        raise ValueError("URL non valido.")

    return url


def sanitize_filename(name: str) -> str:
    name = name.strip()

    if not name:
        name = "pagina_estratta"

    name = re.sub(r'[<>:"/\\|?*]', "_", name)
    name = re.sub(r"\s+", "_", name)
    name = re.sub(r"_+", "_", name)
    name = name.strip("._ ")

    if not name:
        name = "pagina_estratta"

    if not name.lower().endswith(DEFAULT_EXTENSION):
        name += DEFAULT_EXTENSION

    return name


def sanitize_relative_path(path_value: str) -> Path:
    path_value = path_value.strip()

    if not path_value:
        return Path(DEFAULT_OUTPUT_PATH)

    requested = Path(path_value)

    if requested.is_absolute():
        raise ValueError(
            "Il parametro --path deve essere relativo alla cartella dello script."
        )

    if ".." in requested.parts:
        raise ValueError(
            "Il percorso non può contenere '..'. "
            "Il salvataggio deve restare dentro la cartella dello script."
        )

    return requested


def clean_text(text: str) -> str:
    text = text.replace("\xa0", " ")
    text = text.replace("\r\n", "\n")
    text = text.replace("\r", "\n")

    lines = []

    for line in text.splitlines():
        line = re.sub(r"[ \t]+", " ", line).strip()

        if line:
            lines.append(line)
        elif lines and lines[-1] != "":
            lines.append("")

    text = "\n".join(lines)

    text = re.sub(r"\n{3,}", "\n\n", text)

    return text.strip()


def remove_unwanted_elements(soup: BeautifulSoup) -> None:
    unwanted_tags = [
        "script",
        "style",
        "noscript",
        "svg",
        "iframe",
        "canvas",
    ]

    for tag in soup(unwanted_tags):
        tag.decompose()


def add_links_to_text(soup: BeautifulSoup) -> None:
    for anchor in soup.find_all("a", href=True):
        visible_text = anchor.get_text(" ", strip=True)
        href = anchor.get("href", "").strip()

        if not href:
            continue

        if visible_text:
            anchor.replace_with(f"{visible_text} [{href}]")
        else:
            anchor.replace_with(f"[{href}]")


def extract_readable_text(
    html: str,
    keep_links: bool = False,
) -> str:
    soup = BeautifulSoup(html, "html.parser")

    remove_unwanted_elements(soup)

    if keep_links:
        add_links_to_text(soup)

    main_content = (
        soup.find("main")
        or soup.find("article")
        or soup.find(attrs={"role": "main"})
        or soup.body
        or soup
    )

    text = main_content.get_text(
        separator="\n",
        strip=False,
    )

    return clean_text(text)


def scrape_page(
    url: str,
    show_browser: bool,
    timeout_seconds: int,
) -> tuple[str, str]:
    timeout_ms = timeout_seconds * 1000

    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            headless=not show_browser,
        )

        context = browser.new_context(
            viewport={
                "width": 1440,
                "height": 1200,
            },
            locale="it-IT",
        )

        page = context.new_page()

        try:
            print()
            print(f"Apertura pagina: {url}")

            page.goto(
                url,
                wait_until="domcontentloaded",
                timeout=timeout_ms,
            )

            try:
                page.wait_for_load_state(
                    "networkidle",
                    timeout=min(timeout_ms, 30000),
                )
            except PlaywrightTimeoutError:
                print(
                    "La pagina continua ad avere attività di rete. "
                    "Procedo comunque con il contenuto già caricato."
                )

            page.wait_for_timeout(1500)

            title = page.title().strip()
            html = page.content()

            return title, html

        finally:
            context.close()
            browser.close()


def print_configuration(
    url: str,
    output_file: Path,
    show_browser: bool,
) -> None:
    print()
    print("Configurazione")
    print("-" * 60)
    print(f"URL:        {url}")
    print(f"Output:     {output_file}")
    print(
        f"Browser:    {'visibile' if show_browser else 'headless'}"
    )
    print("-" * 60)
    print()


def main() -> int:
    args = parse_args()

    try:
        url = ask_if_missing(
            args.url,
            "URL della pagina",
        )

        file_name = ask_if_missing(
            args.name,
            "Nome del file",
            "pagina_estratta",
        )

        relative_path_value = ask_if_missing(
            args.path,
            "Percorso relativo",
            DEFAULT_OUTPUT_PATH,
        )

        url = validate_url(url)

        file_name = sanitize_filename(file_name)

        relative_path = sanitize_relative_path(
            relative_path_value
        )

        output_directory = (
            SCRIPT_DIR / relative_path
        ).resolve()

        script_directory_resolved = SCRIPT_DIR.resolve()

        try:
            output_directory.relative_to(
                script_directory_resolved
            )
        except ValueError:
            raise ValueError(
                "Il percorso di output deve trovarsi "
                "all'interno della directory dello script."
            )

        output_directory.mkdir(
            parents=True,
            exist_ok=True,
        )

        output_file = output_directory / file_name

        print_configuration(
            url,
            output_file,
            args.show_browser,
        )

        title, html = scrape_page(
            url=url,
            show_browser=args.show_browser,
            timeout_seconds=args.timeout,
        )

        text = extract_readable_text(
            html,
            keep_links=args.keep_links,
        )

        if not text:
            print(
                "Errore: non è stato possibile estrarre testo "
                "dalla pagina.",
                file=sys.stderr,
            )
            return 1

        header = []

        if title:
            header.append(f"TITOLO: {title}")

        header.append(f"URL: {url}")
        header.append("")

        final_text = "\n".join(header) + text

        output_file.write_text(
            final_text,
            encoding="utf-8",
        )

        if args.html:
            html_file = output_file.with_suffix(".html")

            html_file.write_text(
                html,
                encoding="utf-8",
            )

            print(
                f"HTML salvato: {html_file}"
            )

        print()
        print("Estrazione completata.")
        print(f"Titolo:     {title or 'non disponibile'}")
        print(f"Caratteri:  {len(text):,}")
        print(f"File:       {output_file}")

        return 0

    except KeyboardInterrupt:
        print("\nOperazione annullata.")
        return 130

    except PlaywrightTimeoutError:
        print(
            "Errore: timeout durante il caricamento della pagina.",
            file=sys.stderr,
        )
        return 1

    except PlaywrightError as exc:
        print(
            f"Errore Playwright: {exc}",
            file=sys.stderr,
        )
        return 1

    except ValueError as exc:
        print(
            f"Errore: {exc}",
            file=sys.stderr,
        )
        return 1

    except Exception as exc:
        print(
            f"Errore inatteso: {exc}",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())