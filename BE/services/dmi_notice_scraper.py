import hashlib
import json
import re
import time
from pathlib import Path
from urllib.parse import parse_qs, urljoin, urlparse

import requests
from bs4 import BeautifulSoup, Tag

BASE_URL = "https://web.dmi.unict.it"

URLS = {
    "ateneo": "https://www.unict.it/it/news",
    "l31_corso": "https://web.dmi.unict.it/corsi/l-31/avvisi",
    "l31_docente": "https://web.dmi.unict.it/corsi/l-31/avvisi-docente",
    "l35_corso": "https://web.dmi.unict.it/corsi/l-35/avvisi",
    "l35_docente": "https://web.dmi.unict.it/corsi/l-35/avvisi-docente",
    "lm40_corso": "https://web.dmi.unict.it/corsi/lm-40/avvisi",
    "lm40_docente": "https://web.dmi.unict.it/corsi/lm-40/avvisi-docente",
    "lm18_corso": "https://web.dmi.unict.it/corsi/lm-18/avvisi",
    "lm18_docente": "https://web.dmi.unict.it/corsi/lm-18/avvisi-docente",
    "l13_corso": "https://www.dsbga.unict.it/corsi/l-13/avvisi",
    "l13_docente": "https://www.dsbga.unict.it/corsi/l-13/avvisi-docente",
}

OUTPUT_FILE = Path("avvisi_dmi.json")

HEADERS = {
    "User-Agent": (
        "StudentLab/1.0 "
        "(institutional notice synchronizer; https://studentlab.net)"
    )
}

DATE_RE = re.compile(r"\b\d{2}/\d{2}/\d{4}\b")
TEACHER_RE = re.compile(
    r"\b(?:Prof\.ssa|Prof\.|Proff\.)\s+[A-Za-zÀ-ÿ'’.\-\s]+",
    re.IGNORECASE,
)

session = requests.Session()
session.headers.update(HEADERS)


def clean(value: str | None) -> str:
    if not value:
        return ""

    return re.sub(r"\s+", " ", value).strip()


def normalize_url(url: str, base: str = BASE_URL) -> str:
    if not url:
        return ""

    return urljoin(base, url)


def external_id(url: str) -> str:
    return hashlib.sha256(url.encode("utf-8")).hexdigest()


def content_hash(title: str, content: str) -> str:
    raw = f"{title}|{content}".encode("utf-8")
    return hashlib.sha256(raw).hexdigest()


def classify(title: str, content: str) -> str:
    text = f"{title} {content}".lower()

    categories = [
        (
            "risultati",
            [
                "esiti",
                "risultati",
                "ammessi",
                "voti",
                "voto",
            ],
        ),
        (
            "esame",
            [
                "esame",
                "appello",
                "prova scritta",
                "prova pratica",
                "orale",
                "orali",
            ],
        ),
        (
            "ricevimento",
            [
                "ricevimento",
                "riceve studenti",
            ],
        ),
        (
            "lezione",
            [
                "lezione",
                "lezioni",
                "inizio corso",
                "inizio delle lezioni",
            ],
        ),
        (
            "tirocinio",
            [
                "tirocinio",
                "stage",
                "coursera",
            ],
        ),
        (
            "ofa",
            [
                "ofa",
                "test di ingresso",
                "corso zero",
            ],
        ),
    ]

    for category, keywords in categories:
        if any(keyword in text for keyword in keywords):
            return category

    return "altro"


def get_soup(url: str) -> BeautifulSoup:
    response = session.get(url, timeout=20)
    response.raise_for_status()

    return BeautifulSoup(response.text, "html.parser")


def is_notice_url(url: str, source: str) -> bool:
    parts = urlparse(url)
    path = parts.path.lower()
    host = parts.hostname
    if source == "ateneo":
        return host == "www.unict.it" and bool(re.match(r"^/it/[^/]+/news/[^/]+", path))
    course, kind = source.split("_", 1)
    expected_host = "www.dsbga.unict.it" if course == "l13" else "web.dmi.unict.it"
    path = path.removeprefix("/it")
    if host != expected_host:
        return False
    # Gli avvisi dei docenti hanno URL globali /avvisi-docente/<slug>?cdl=l-31.
    # Il parametro del CdL deve essere quello dell'elenco da cui li leggiamo.
    if kind == 'docente' and re.fullmatch(r'/avvisi-docente/[^/]+/?', path):
        values = parse_qs(parts.query).get('cdl', [])
        course_code = ('lm-' if course.startswith('lm') else 'l-') + (
            course[2:] if course.startswith('lm') else course[1:])
        return len(values) == 1 and values[0].strip().lower() == course_code
    allowed_courses = r'l-13' if course == 'l13' else r'(?:l-31|l-35|lm-18|lm-40)'
    # The listing page is authoritative: an article can be cross-posted
    # under another course URL, while remaining part of this listing.
    return bool(re.match(
        rf'^/corsi/{allowed_courses}/avvisi(?:-docente)?/[^/]+', path))


def find_date_before(element: Tag) -> str | None:
    """
    Cerca la data associata all'avviso andando all'indietro
    nell'HTML, fermandosi alla prima DD/MM/YYYY valida.
    """

    for previous in element.find_all_previous(string=True):
        text = clean(str(previous))

        if DATE_RE.fullmatch(text):
            return text

    return None


def find_teacher_near_link(link: Tag) -> str | None:
    """
    Cerca il docente nell'area immediatamente successiva al titolo
    senza attraversare l'avviso successivo.
    """

    for element in link.find_all_next():
        if element is link:
            continue

        if not isinstance(element, Tag):
            continue

        text = clean(element.get_text(" ", strip=True))

        if not text:
            continue

        # Siamo arrivati all'avviso successivo.
        if DATE_RE.fullmatch(text):
            break

        href = element.get("href")

        if (
            element.name == "a"
            and href
            and "/docenti/" in href
        ):
            teacher = clean(element.get_text(" ", strip=True))

            if teacher:
                return teacher

        match = TEACHER_RE.search(text)

        if match:
            return clean(match.group(0))

    return None


def extract_listing(source: str, url: str) -> list[dict]:
    """
    Dalla pagina elenco prendiamo solamente:
    - data
    - titolo
    - URL originale
    - eventuale docente

    Il corpo completo NON viene estratto dalla pagina elenco.
    """

    soup = get_soup(url)

    results = []
    seen_urls = set()

    for link in soup.find_all("a", href=True):
        href = normalize_url(link.get("href"), url)
        title = clean(link.get_text(" ", strip=True))

        if not title or not href:
            continue

        if not is_notice_url(href, source):
            continue

        if href in seen_urls:
            continue

        date = find_date_before(link) if source != "ateneo" else None

        if not date and source != "ateneo":
            continue

        teacher = None

        if source.endswith("docente"):
            teacher = find_teacher_near_link(link)

        results.append(
            {
                "fonte": source,
                "data": date,
                "titolo": title,
                "docente": teacher,
                "url": href,
            }
        )

        seen_urls.add(href)

    return results


def remove_unwanted_elements(container: Tag) -> None:
    unwanted_selectors = [
        "script",
        "style",
        "nav",
        "footer",
        "header",
        "form",
        ".breadcrumb",
        ".pager",
        ".pagination",
        ".region-sidebar",
        ".block-system-breadcrumb-block",
    ]

    for selector in unwanted_selectors:
        for element in container.select(selector):
            element.decompose()


def find_content_container(soup: BeautifulSoup) -> Tag:
    """
    Prova diversi container comuni di Drupal.
    """

    selectors = [
        ".field--name-body",
        ".field-name-body",
        ".node__content",
        "article .content",
        "article",
        "main article",
        "main",
    ]

    for selector in selectors:
        element = soup.select_one(selector)

        if element:
            return element

    return soup.body or soup


def extract_detail(
    url: str,
    expected_title: str,
    source: str,
) -> dict:
    """
    Apre il singolo avviso e ne estrae il contenuto.
    """

    soup = get_soup(url)

    page_title = None

    h1 = soup.find("h1")

    if h1:
        page_title = clean(h1.get_text(" ", strip=True))

    title = page_title or expected_title

    container = find_content_container(soup)

    # Copia la porzione HTML per non modificare soup.
    detail_soup = BeautifulSoup(str(container), "html.parser")
    detail_container = detail_soup

    remove_unwanted_elements(detail_container)

    # Rimuove il titolo dal contenuto se compare nuovamente.
    for heading in detail_container.find_all(
        ["h1", "h2", "h3"]
    ):
        heading_text = clean(
            heading.get_text(" ", strip=True)
        )

        if (
            heading_text == title
            or heading_text == expected_title
        ):
            heading.decompose()

    teacher = None

    if source.endswith("docente"):
        # Prima cerchiamo link a pagine docente.
        for link in detail_container.find_all(
            "a",
            href=True,
        ):
            href = link.get("href", "")

            if "/docenti/" in href:
                candidate = clean(
                    link.get_text(" ", strip=True)
                )

                if candidate:
                    teacher = candidate
                    link.decompose()
                    break

    text = clean(
        detail_container.get_text(
            " ",
            strip=True,
        )
    )

    # Fallback docente tramite regex.
    if source.endswith("docente") and not teacher:
        matches = list(TEACHER_RE.finditer(text))

        if matches:
            teacher = clean(matches[-1].group(0))

    # Rimuove il docente dal corpo se appare in coda.
    if teacher and text.endswith(teacher):
        text = clean(
            text[: -len(teacher)]
        )

    # Evita che il titolo venga duplicato all'inizio.
    if text.startswith(title):
        text = clean(
            text[len(title):]
        )

    return {
        "titolo": title,
        "testo": text,
        "docente": teacher,
        "data": (DATE_RE.search(soup.get_text(" ", strip=True).split("Ultima modifica:")[-1]).group(0)
                 if source == "ateneo" and "Ultima modifica:" in soup.get_text(" ", strip=True)
                 and DATE_RE.search(soup.get_text(" ", strip=True).split("Ultima modifica:")[-1]) else None),
    }


def scrape_source(
    source: str,
    list_url: str,
) -> list[dict]:
    print(f"\n[{source.upper()}]")
    print(f"Elenco: {list_url}")

    listing = extract_listing(
        source,
        list_url,
    )

    print(
        f"Trovati {len(listing)} avvisi nell'elenco."
    )

    results = []

    for index, item in enumerate(
        listing,
        start=1,
    ):
        print(
            f"  [{index}/{len(listing)}] "
            f"{item['titolo']}"
        )

        try:
            detail = extract_detail(
                item["url"],
                item["titolo"],
                source,
            )

            teacher = (
                detail["docente"]
                or item["docente"]
            )

            title = detail["titolo"]
            content = detail["testo"]

            course = source.split("_", 1)[0]
            record = {
                "external_id": external_id(f"{item['url']}|{list_url}"),
                "fonte": source.split("_", 1)[-1] if source != "ateneo" else "ateneo",
                "external_source": "dmi_unict",
                "istituzione": (
                    "Università degli Studi di Catania"
                ),
                "dipartimento": ("DSBGA" if course == "l13" else "DMI") if source != "ateneo" else None,
                "corso": (f"LM-{course[2:]}" if course.startswith("lm")
                          else course.upper().replace("L", "L-", 1))
                         if source != "ateneo" else None,
                "data": item["data"] or detail.get("data"),
                "titolo": title,
                "testo": content,
                "docente": teacher,
                "tipo": classify(
                    title,
                    content,
                ),
                "url": item["url"],
                "source_url": list_url,
                "content_hash": content_hash(
                    title,
                    content,
                ),
            }

            if record["data"]:
                results.append(record)

        except requests.RequestException as exc:
            print(
                f"    Errore HTTP: {exc}"
            )

        except Exception as exc:
            print(
                f"    Errore parsing: {exc}"
            )

        # Piccolo intervallo tra le pagine dettaglio.
        time.sleep(0.25)

    return results


def remove_duplicates(
    notices: list[dict],
) -> list[dict]:
    unique = {}

    for notice in notices:
        unique[notice["external_id"]] = notice

    return list(unique.values())


def save_json(
    notices: list[dict],
) -> None:
    OUTPUT_FILE.write_text(
        json.dumps(
            notices,
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )


def main():
    all_notices = []

    for source, url in URLS.items():
        try:
            notices = scrape_source(
                source,
                url,
            )

            all_notices.extend(notices)

        except requests.RequestException as exc:
            print(
                f"Errore caricando {source}: {exc}"
            )

    all_notices = remove_duplicates(
        all_notices
    )

    save_json(all_notices)

    print()
    print("--------------------------------")
    print(
        f"Creato {OUTPUT_FILE}"
    )
    print(
        f"Totale avvisi: {len(all_notices)}"
    )
    print("--------------------------------")


if __name__ == "__main__":
    main()
