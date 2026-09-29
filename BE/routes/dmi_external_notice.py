import hashlib
import hmac
import os
import re
from datetime import datetime
from urllib.parse import urlsplit

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from sqlalchemy.orm import Session

from core.database import get_db
from models.dmi_external_notice import DmiExternalNotice, utc_now
from schemas.dmi_external_notice import DmiNoticeResponse, DmiNoticeSyncRequest
from services.news_filter_scope import COURSES, code as academic_code, teacher_name_key, unambiguous_course_mention


router = APIRouter(prefix="/institutional-notices", tags=["Institutional notices"])

SOURCES = {
    ("www.unict.it", "/it/news/"): ("ateneo", None, None),
    ("web.dmi.unict.it", "/corsi/l-31/avvisi/"): ("corso", "DMI", "L-31"),
    ("web.dmi.unict.it", "/corsi/l-31/avvisi-docente/"): ("docente", "DMI", "L-31"),
    ("web.dmi.unict.it", "/corsi/l-35/avvisi/"): ("corso", "DMI", "L-35"),
    ("web.dmi.unict.it", "/corsi/l-35/avvisi-docente/"): ("docente", "DMI", "L-35"),
    ("web.dmi.unict.it", "/corsi/lm-40/avvisi/"): ("corso", "DMI", "LM-40"),
    ("web.dmi.unict.it", "/corsi/lm-40/avvisi-docente/"): ("docente", "DMI", "LM-40"),
    ("web.dmi.unict.it", "/corsi/lm-18/avvisi/"): ("corso", "DMI", "LM-18"),
    ("web.dmi.unict.it", "/corsi/lm-18/avvisi-docente/"): ("docente", "DMI", "LM-18"),
    ("www.dsbga.unict.it", "/corsi/l-13/avvisi/"): ("corso", "DSBGA", "L-13"),
    ("www.dsbga.unict.it", "/corsi/l-13/avvisi-docente/"): ("docente", "DSBGA", "L-13"),
}


def _scope(value: str, dimension: str = "course") -> str:
    import re
    known = academic_code(value, dimension)
    if known is not None:
        return known.casefold()
    text = value.casefold()
    if dimension == "department":
        if "dsbga" in text or "scienze biologiche" in text or "dipbiogeo" in text:
            return "dsbga"
        if "dmi" in text or "matematica" in text:
            return "dmi"
        return text.strip()
    if dimension == "university":
        return "unict" if "catania" in text or "unict" in text else text.strip()
    if re.search(r"\blm[\s-]*40\b", text) or ("matematica" in text and "magistrale" in text):
        return "lm-40"
    if re.search(r"\blm[\s-]*18\b", text) or ("informatica" in text and "magistrale" in text):
        return "lm-18"
    match = re.search(r"\bl[\s-]*(31|35|13)\b", text)
    if match:
        return f"l-{match.group(1)}"
    if "informatica" in text:
        return "l-31"
    if "matematica" in text and "informatica" not in text:
        return "l-35"
    if "scienze biologiche" in text:
        return "l-13"
    if "dsbga" in text or "scienze biologiche" in text or "dipbiogeo" in text:
        return "dsbga"
    if "dmi" in text or "matematica" in text:
        return "dmi"
    if "catania" in text or "unict" in text:
        return "unict"
    return text.strip()


def _effective_source(row):
    """The listing URL is authoritative; the detail URL supports legacy rows."""
    source_url = getattr(row, 'source_url', None)
    if source_url:
        parts = urlsplit(source_url)
        path = parts.path.lower().replace('/it/corsi/', '/corsi/', 1).rstrip('/')
        for (host, prefix), (_, department, course) in SOURCES.items():
            if parts.hostname == host and path == prefix.rstrip('/'):
                if course:
                    return department, course
                hint = unambiguous_course_mention(row.title or '', row.content or '')
                return (COURSES[hint][0], hint) if hint else (None, None)
        return None, None
    parts = urlsplit(row.original_url or "")
    path = parts.path.lower().replace('/it/corsi/', '/corsi/', 1)
    for (host, prefix), (kind, department, course) in SOURCES.items():
        if course is None:
            continue  # Classify official university news by its actual contents.
        if parts.hostname == host and (path.startswith(prefix) or path == prefix.rstrip('/')):
            return department, course
    # UniCt also publishes news beneath /it/<section>/news/<article>.
    if parts.hostname == 'www.unict.it' and re.match(r'^/it/(?:[^/]+/)?news/[^/]+', path):
        course = unambiguous_course_mention(row.title or '', row.content or '')
        if course:
            return COURSES[course][0], course
        return None, None
    # Unknown source: never infer broad visibility from missing database fields.
    return None, None


def _visible_for_scope(row, department=None, course=None):
    source_department, source_course = _effective_source(row)
    if course:
        return source_course is not None and _scope(course) == _scope(source_course) and (
            not department or _scope(department, 'department') == _scope(source_department, 'department'))
    if department:
        return source_department is not None and source_course is None and (
            _scope(department, 'department') == _scope(source_department, 'department'))
    # No course/department: show only the university's own news feed.
    return source_department is None and source_course is None and _is_university_news(row)


def _is_university_news(row):
    parts = urlsplit(getattr(row, 'source_url', None) or row.original_url or '')
    return parts.hostname == 'www.unict.it' and bool(
        parts.path.lower().rstrip('/') == '/it/news' or
        re.match(r'^/it/(?:[^/]+/)?news/[^/]+', parts.path.lower()))


def _response(row):
    department, course = _effective_source(row)
    return DmiNoticeResponse.model_validate(row).model_copy(
        update={'department': department, 'course': course})


@router.get("", response_model=list[DmiNoticeResponse])
def list_notices(limit: int = Query(default=200, ge=1, le=500),
                 university: str | None = None, department: str | None = None,
                 course: str | None = None, teacher: str | None = None,
                 db: Session = Depends(get_db)):
    if university and _scope(university, "university") != "unict":
        return []
    if teacher and not course:
        return []
    rows = (db.query(DmiExternalNotice)
            .order_by(DmiExternalNotice.published_on.desc(), DmiExternalNotice.id.desc()).all())
    if not department and not course:
        return [_response(row) for row in rows if _is_university_news(row)
                and _effective_source(row)[1] is None][:limit]
    return [_response(row) for row in rows if _visible_for_scope(row, department, course)
            and (not teacher or (teacher_name_key(row.teacher) and teacher_name_key(row.teacher) == teacher_name_key(teacher)))][:limit]


@router.get("/sources")
def notice_sources():
    return [{"university": "Università di Catania", "department": department, "course": course}
            for _, department, course in dict.fromkeys(SOURCES.values())]


@router.post("/sync")
def sync_notices(request: DmiNoticeSyncRequest,
                 token: str | None = Header(default=None, alias="X-StudentLab-Sync-Token"),
                 db: Session = Depends(get_db)):
    expected = os.getenv("STUDENTLAB_NOTICE_SYNC_TOKEN", "")
    if not expected or not token or not hmac.compare_digest(token, expected):
        raise HTTPException(403, "Sincronizzazione non autorizzata.")

    prepared = {}
    for item in request.notices:
        url = item.url.strip()
        parts = urlsplit(url)
        if parts.scheme != "https" or parts.username or parts.password or parts.port not in (None, 443):
            raise HTTPException(422, "Fonte dell'avviso non valida.")
        if parts.hostname not in {host for host, _ in SOURCES}:
            raise HTTPException(422, "Dominio dell'avviso non valido.")
        path = parts.path.lower().removeprefix("/it/corsi/")
        if path != parts.path.lower():
            path = "/corsi/" + path
        listing_url = None
        if item.source_url:
            source_parts = urlsplit(item.source_url.strip())
            if (source_parts.scheme != 'https' or source_parts.username or source_parts.password
                    or source_parts.port not in (None, 443) or source_parts.query or source_parts.fragment):
                raise HTTPException(422, "Elenco di provenienza non valido.")
            source_path = source_parts.path.lower().replace('/it/corsi/', '/corsi/', 1).rstrip('/')
            match = next(((kind, dep, crs) for (host, prefix), (kind, dep, crs) in SOURCES.items()
                          if source_parts.hostname == host and source_path == prefix.rstrip('/')), None)
            if match is not None:
                listing_url = f"https://{source_parts.hostname}{source_parts.path.rstrip('/')}"
        else:
            # Compatibility with synchronizers installed before source_url.
            match = next(((kind, dep, crs) for (host, prefix), (kind, dep, crs) in SOURCES.items()
                          if parts.hostname == host and path.startswith(prefix)), None)
            if match is None and parts.hostname == 'www.unict.it' and re.match(
                    r'^/it/(?:[^/]+/)?news/[^/]+', parts.path.lower()):
                match = ('ateneo', None, None)
        if match is None or item.fonte != match[0] or not parts.path.strip("/").split("/")[-1]:
            raise HTTPException(422, "Percorso dell'avviso non valido.")
        try:
            published = datetime.strptime(item.data, "%d/%m/%Y").date()
        except ValueError as exc:
            raise HTTPException(422, "Data dell'avviso non valida.") from exc
        canonical_url = f"https://{parts.hostname}{parts.path}"
        original_url = canonical_url + (f"?{parts.query}" if parts.query else "")
        external_id = hashlib.sha256((canonical_url + (f'|{listing_url}' if listing_url else '')).encode()).hexdigest()
        title = " ".join(item.titolo.split())[:160]
        content = " ".join(item.testo.split())[:30000]
        content_hash = hashlib.sha256(f"{title}|{content}".encode()).hexdigest()
        prepared[external_id] = dict(external_id=external_id, source_kind=item.fonte,
                                     university="Università di Catania", department=match[1], course=match[2],
                                     title=title, content=content,
                                     teacher=item.docente.strip() if item.docente else None,
                                     category=item.tipo, published_on=published,
                                     original_url=original_url, source_url=listing_url,
                                     content_hash=content_hash)

    inserted = updated = 0
    seen_at = utc_now()
    try:
        legacy_ids = {hashlib.sha256(values['original_url'].split('?')[0].encode()).hexdigest()
                      for values in prepared.values() if values['source_url']}
        existing = {row.external_id: row for row in db.query(DmiExternalNotice)
                    .filter(DmiExternalNotice.external_id.in_(set(prepared) | legacy_ids)).all()} if prepared else {}
        migrated_legacy = set()
        for external_id, values in prepared.items():
            row = existing.get(external_id)
            if row is None and values['source_url']:
                legacy_id = hashlib.sha256(values['original_url'].split('?')[0].encode()).hexdigest()
                legacy = existing.get(legacy_id)
                if legacy is not None and legacy.id not in migrated_legacy and not legacy.source_url:
                    row = legacy
                    migrated_legacy.add(row.id)
            if row is None:
                db.add(DmiExternalNotice(**values, created_at=seen_at, updated_at=seen_at, last_seen_at=seen_at))
                inserted += 1
                continue
            if any(getattr(row, field) != value for field, value in values.items() if field != "external_id"):
                for field, value in values.items():
                    setattr(row, field, value)
                row.updated_at = seen_at
                updated += 1
            row.last_seen_at = seen_at
        db.commit()
    except Exception:
        db.rollback()
        raise
    return {"received": len(prepared), "inserted": inserted, "updated": updated}
