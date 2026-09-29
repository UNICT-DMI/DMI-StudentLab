#!/usr/bin/env python3
"""Anteprima o inserimento dei periodi ufficiali L-31 2026/27.

Eseguire dalla cartella BE con .venv/bin/python. Nessuna lezione individuale,
chiusura degli edifici o appello viene dedotto dalle sole finestre didattiche.
"""
import argparse
import importlib
import pkgutil
import sys
from datetime import datetime, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

SOURCE = 'https://web.dmi.unict.it/it/corsi/l-31/calendario-didattico'
# Periodi con estremi inclusi; la data di fine nel DB è esclusiva.
PERIODS = (
    ('lessons', 'Primo periodo di lezioni', '2026-10-01', '2027-01-15'),
    ('extraordinary', 'Pausa esami: appelli straordinari e prove in itinere', '2026-12-17', '2026-12-23'),
    ('event', 'Sospensione delle lezioni per pausa invernale', '2026-12-24', '2027-01-06'),
    ('session', 'Prima sessione di esami', '2027-01-18', '2027-02-26'),
    ('lessons', 'Secondo periodo di lezioni', '2027-03-01', '2027-06-11'),
    ('event', 'Sospensione delle lezioni per pausa primaverile', '2027-03-26', '2027-03-30'),
    ('extraordinary', 'Pausa esami: appelli straordinari e prove in itinere', '2027-04-19', '2027-04-23'),
    ('session', 'Seconda sessione di esami', '2027-06-14', '2027-07-30'),
    ('session', 'Terza sessione di esami', '2027-08-30', '2027-09-30'),
)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true', help='Inserisce soltanto i periodi mancanti nel database')
    args = parser.parse_args()
    if not args.apply:
        for kind, title, start, end in PERIODS:
            print(f'{start} – {end}: {title} [{kind}]')
        print('Solo anteprima; nessun database modificato.')
        return
    import models
    for info in pkgutil.walk_packages(models.__path__, prefix='models.'):
        importlib.import_module(info.name)
    from core.database import SessionLocal
    from models.academic_calendar import CalendarEvent
    db = SessionLocal()
    try:
        added = 0
        for kind, title, start, end in PERIODS:
            key = f'unict-l31-2026-27:{start}:{end}:{kind}'
            if db.query(CalendarEvent.id).filter(CalendarEvent.source_ref == key).first():
                continue
            starts_at = datetime.fromisoformat(start)
            ends_at = datetime.fromisoformat(end) + timedelta(days=1)
            db.add(CalendarEvent(university='Università degli Studi di Catania',
                department='Dipartimento di Matematica e Informatica',
                course='Scienze e tecnologie informatiche', kind=kind, title=title,
                starts_at=starts_at, ends_at=ends_at, all_day=True,
                status='confirmed', source='import', source_ref=key,
                notes=f'Periodo didattico L-31, estremi inclusi. Fonte: {SOURCE}. '
                      'La sospensione delle lezioni non certifica la chiusura degli edifici.'))
            added += 1
        db.commit()
        print(f'Inseriti {added} periodi; già presenti {len(PERIODS)-added}.')
    except Exception:
        db.rollback()
        raise
    finally:
        db.close()

if __name__ == '__main__':
    main()
