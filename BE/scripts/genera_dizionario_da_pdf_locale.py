#!/usr/bin/env python3
"""Estrae bozze di voci del dizionario da PDF con testo selezionabile.

Richiede pdftotext (poppler-utils). Non modifica il PDF, il DB o i JSON
esistenti. Per i PDF scansiti occorre prima un OCR (es. ocrmypdf).
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import sqlite3
import subprocess
import sys
import unicodedata
from datetime import datetime, timezone
from pathlib import Path


def slug(value: str) -> str:
    value = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+", "-", value).strip("-")[:80] or "termine"


def pages_from_pdf(path: Path) -> list[str]:
    try:
        result = subprocess.run(
            ["pdftotext", "-enc", "UTF-8", "-layout", str(path), "-"],
            capture_output=True, text=True, check=True,
        )
    except FileNotFoundError as exc:
        raise RuntimeError("Manca pdftotext: installa poppler-utils.") from exc
    except subprocess.CalledProcessError as exc:
        raise RuntimeError(f"PDF non leggibile: {exc.stderr.strip()}") from exc
    return result.stdout.split("\f")


DEFINITION = re.compile(
    r"^(?P<term>[\wÀ-ÿ][\wÀ-ÿ '\u2019\-/()]{2,75}?)\s*"
    r"(?::|\s+[–—-]\s+|\s+(?:è|sono|indica|consiste in|si definisce)\s+)"
    r"\s*(?P<description>\S.{24,})$", re.I,
)
NOISE = re.compile(r"^(?:slide|pagina|lezione|esercizio|esempio|nota|figure?|tabella|capitolo)\b", re.I)


def candidates(pages: list[str], source: Path) -> tuple[list[dict], int]:
    entries: dict[str, dict] = {}
    rejected = 0
    for page_number, page in enumerate(pages, start=1):
        lines = [re.sub(r"\s+", " ", row).strip() for row in page.splitlines()]
        for line in lines:
            match = DEFINITION.fullmatch(line)
            if not match:
                continue
            term = match["term"].strip(" :.-")
            definition = match["description"].strip()
            if (NOISE.match(term) or len(term.split()) > 7 or len(definition) > 800
                    or sum(c.isalpha() for c in definition) < 25):
                rejected += 1
                continue
            key = slug(term)
            if key in entries:
                entries[key]["resources"].append(
                    {"title": f"{source.name}, pagina {page_number}", "url": ""}
                )
                continue
            entries[key] = {
                "id": key, "term": term[0].upper() + term[1:], "aliases": [],
                "topic": "da-classificare", "formal_definition": definition,
                "informal_definition": "", "examples": [], "exercises": [],
                "exam_questions": [], "related": [],
                "resources": [{"title": f"{source.name}, pagina {page_number}", "url": ""}],
                "quiz_question_ids": [],
                "_review": {"source_file": source.name, "page": page_number,
                            "extraction": "definition_pattern", "needs_review": True},
            }
    return list(entries.values()), rejected


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pdf", nargs="?", type=Path, help="un PDF, opzionale se usi --input-dir o --path-list")
    parser.add_argument("--input-dir", action="append", type=Path,
                        help="cartella di PDF; ripetibile, include sottocartelle")
    parser.add_argument("--path-list", type=Path,
                        help="TXT: un PDF o una cartella per riga; righe # ignorate; percorsi relativi al TXT")
    parser.add_argument("--department-code", required=True)
    parser.add_argument("--course-code", required=True)
    parser.add_argument("--subject", required=True)
    parser.add_argument("--academic-year", required=True)
    parser.add_argument("--output", type=Path,
                        help="Scrive un JSON nuovo in una cartella di bozze; senza questa opzione mostra soltanto un'anteprima")
    parser.add_argument("--output-dir", type=Path, help="cartella di bozze per elaborare più PDF")
    parser.add_argument("--state-csv", type=Path, help="registro CSV: richiede --output-dir")
    parser.add_argument("--state-db", type=Path, help="registro SQLite locale: richiede --output-dir")
    args = parser.parse_args()
    if args.output and args.output_dir:
        parser.error("Scegli --output oppure --output-dir.")
    if args.state_csv and not args.output_dir:
        parser.error("--state-csv richiede --output-dir.")
    if args.state_db and not args.output_dir:
        parser.error("--state-db richiede --output-dir.")
    if args.state_db and args.state_csv:
        parser.error("Scegli un solo registro: --state-db oppure --state-csv.")
    sources = []
    if args.pdf:
        sources.append(args.pdf)
    sources.extend(args.input_dir or [])
    if args.path_list:
        if not args.path_list.is_file():
            parser.error("Il TXT dei percorsi non esiste.")
        for row in args.path_list.read_text(encoding="utf-8-sig").splitlines():
            row = row.strip()
            if not row or row.startswith("#"):
                continue
            path = Path(row).expanduser()
            sources.append(path if path.is_absolute() else args.path_list.parent / path)
    if not sources:
        parser.error("Indica un PDF, --input-dir o --path-list.")
    files: dict[str, Path] = {}
    for source in sources:
        source = source.expanduser().resolve()
        if source.is_dir():
            for pdf in source.rglob("*"):
                if pdf.is_file() and pdf.suffix.lower() == ".pdf":
                    files[str(pdf.resolve())] = pdf.resolve()
        elif source.is_file() and source.suffix.lower() == ".pdf":
            files[str(source)] = source
        else:
            parser.error(f"Percorso non valido o non PDF: {source}")
    if not files:
        parser.error("Nessun PDF trovato.")
    if len(files) > 1 and args.output:
        parser.error("Per più PDF usa --output-dir.")
    csv_fields = ["pdf", "sha256", "subject", "academic_year", "status", "entries", "draft", "processed_at", "error"]
    previous: dict[tuple[str, str, str], dict] = {}
    if args.state_db:
        args.state_db.parent.mkdir(parents=True, exist_ok=True)
        with sqlite3.connect(args.state_db) as db:
            db.execute('''CREATE TABLE IF NOT EXISTS processed_pdfs (
                pdf TEXT NOT NULL, subject TEXT NOT NULL, academic_year TEXT NOT NULL,
                sha256 TEXT NOT NULL, status TEXT NOT NULL, entries INTEGER NOT NULL,
                draft TEXT NOT NULL, processed_at TEXT NOT NULL, error TEXT NOT NULL,
                PRIMARY KEY (pdf, subject, academic_year))''')
            for row in db.execute('SELECT pdf, sha256, subject, academic_year, status, entries, draft, processed_at, error FROM processed_pdfs'):
                record = dict(zip(csv_fields, row))
                previous[(record['pdf'], record['subject'], record['academic_year'])] = record
    if args.state_csv and args.state_csv.exists():
        with args.state_csv.open(newline="", encoding="utf-8") as stream:
            for row in csv.DictReader(stream):
                previous[(row.get("pdf", ""), row.get("subject", ""), row.get("academic_year", ""))] = row
    changed = False
    failed = False
    for path in sorted(files.values()):
        digest = hashlib.sha256()
        with path.open("rb") as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(block)
        checksum = digest.hexdigest()
        key = (str(path), args.subject.strip(), args.academic_year.strip())
        old = previous.get(key)
        if (old and old.get("sha256") == checksum
                and (old.get("status") == "no_candidates"
                     or (old.get("status") == "generated" and Path(old.get("draft", "")).is_file()))):
            print(f"Già elaborato, salto: {path}")
            continue
        print(f"\nPDF: {path}")
        try:
            pages = pages_from_pdf(path)
            if len("".join(pages).strip()) < 80:
                raise RuntimeError("Testo non estraibile; serve OCR.")
            entries, rejected = candidates(pages, path)
            print(f"Pagine: {len(pages)} | Candidati: {len(entries)} | Righe scartate: {rejected}")
            for entry in entries[:15]:
                print(f"  p.{entry['_review']['page']}: {entry['term']}: {entry['formal_definition'][:95]}")
            if len(entries) > 15:
                print(f"  ... e altri {len(entries) - 15}")
            target = args.output
            if args.output_dir:
                target = args.output_dir / (slug(path.stem) + "-" + hashlib.sha256(str(path).encode()).hexdigest()[:10] + ".json")
            status = "no_candidates"
            if target and entries:
                if target.parent.name == "dictionary":
                    raise RuntimeError("Usa una cartella di bozze, non dictionary/.")
                data = {
                    "schema": "studentlab.dictionary/1",
                    "metadata": {
                        "department_code": args.department_code.strip(),
                        "course_code": args.course_code.strip(),
                        "subject": args.subject.strip(),
                        "academic_year": args.academic_year.strip(),
                        "teachers": [], "source": path.name,
                    },
                    "topics": [{"id": "da-classificare", "title": "Da classificare", "order": 1}],
                    "entries": entries,
                }
                target.parent.mkdir(parents=True, exist_ok=True)
                if target.exists():
                    print(f"Bozza già presente, non sovrascritta: {target}")
                    status = "draft_exists"
                else:
                    with target.open("x", encoding="utf-8") as stream:
                        json.dump(data, stream, ensure_ascii=False, indent=2)
                        stream.write("\n")
                    print(f"Bozza da revisionare: {target}")
                    status = "generated"
            elif not target:
                print("Solo anteprima: nessun file o database modificato.")
            if args.state_csv or args.state_db:
                previous[key] = dict(pdf=str(path), sha256=checksum, subject=args.subject.strip(),
                                     academic_year=args.academic_year.strip(),
                                     status=status, entries=str(len(entries)),
                                     draft=str(target.resolve()) if target and status == "generated" else "",
                                     processed_at=datetime.now(timezone.utc).isoformat(), error="")
                changed = True
        except (OSError, RuntimeError) as exc:
            failed = True
            print(f"Errore: {exc}", file=sys.stderr)
            if args.state_csv or args.state_db:
                previous[key] = dict(pdf=str(path), sha256=checksum, subject=args.subject.strip(),
                                     academic_year=args.academic_year.strip(),
                                     status="error", entries="0", draft="",
                                     processed_at=datetime.now(timezone.utc).isoformat(), error=str(exc))
                changed = True
    if args.state_csv and changed:
        args.state_csv.parent.mkdir(parents=True, exist_ok=True)
        temporary = args.state_csv.with_name(args.state_csv.name + ".tmp")
        with temporary.open("w", newline="", encoding="utf-8") as stream:
            writer = csv.DictWriter(stream, fieldnames=csv_fields)
            writer.writeheader()
            writer.writerows(previous.values())
        temporary.replace(args.state_csv)
        print(f"Registro aggiornato: {args.state_csv}")
    if args.state_db and changed:
        with sqlite3.connect(args.state_db) as db:
            db.executemany('''INSERT INTO processed_pdfs
                (pdf, sha256, subject, academic_year, status, entries, draft, processed_at, error)
                VALUES (:pdf, :sha256, :subject, :academic_year, :status, :entries, :draft, :processed_at, :error)
                ON CONFLICT(pdf, subject, academic_year) DO UPDATE SET
                sha256=excluded.sha256, status=excluded.status, entries=excluded.entries,
                draft=excluded.draft, processed_at=excluded.processed_at, error=excluded.error''', previous.values())
        print(f"Registro SQLite aggiornato: {args.state_db}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
