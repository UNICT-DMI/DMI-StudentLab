#!/usr/bin/env python3
"""Importa nel database i dizionari generati (data/**/dictionary/*.json).

Per ogni file cerca la materia (codice corso/dipartimento e nome). Se non la
riconosce con sicurezza la salta e mostra i candidati: in quel caso importalo
dall'app (Dizionario > Importa JSON) scegliendo la materia, oppure rilancia
con --materia FILE=ID.

Uso, dalla cartella BE/ (con le variabili del database impostate):
    python3 scripts/importa_dizionari.py --admin-email tu@esempio.it --prova
    python3 scripts/importa_dizionari.py --admin-email tu@esempio.it
    python3 scripts/importa_dizionari.py --admin-email tu@esempio.it --materia reti_di_calcolatori_e_internet.json=42
"""
import argparse
import importlib
import pkgutil
import importlib
import pkgutil
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import models  # noqa: E402
import models  # noqa: E402
from core.database import SessionLocal  # noqa: E402
from models.subject import Subject  # noqa: E402
from models.user import User  # noqa: E402
import models.dictionary  # noqa: E402,F401
from services.dictionary import import_dictionary, is_admin, match_subject  # noqa: E402


def import_all_models():
    for info in pkgutil.walk_packages(models.__path__, prefix=f"{models.__name__}."):
        importlib.import_module(info.name)

def import_all_models():
    for info in pkgutil.walk_packages(models.__path__, prefix=f"{models.__name__}."):
        importlib.import_module(info.name)

def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--data', default='data')
    parser.add_argument('--admin-email', required=True, help='account admin che risulterà autore dell’import')
    parser.add_argument('--materia', action='append', default=[], help='FILE=ID_MATERIA per forzare la materia')
    parser.add_argument('--prova', action='store_true', help='mostra solo gli abbinamenti, non scrive')
    args = parser.parse_args()
    forced = dict(item.split('=', 1) for item in args.materia if '=' in item)
    import_all_models()
    import_all_models()
    db = SessionLocal()
    try:
        admin = db.query(User).filter(User.email == args.admin_email).first()
        if admin is None or not is_admin(admin):
            sys.exit('✗ Account admin non trovato.')
        files = sorted(p for p in Path(args.data).rglob('*.json') if p.parent.name == 'dictionary')
        if not files:
            sys.exit('✗ Nessun dizionario: esegui prima scripts/genera_dizionario_da_domande.py')
        for path in files:
            data = json.loads(path.read_text(encoding='utf-8'))
            if path.name in forced:
                subject = db.query(Subject).filter(Subject.id == int(forced[path.name])).first()
                candidates = []
            else:
                subject, candidates = match_subject(db, data.get('metadata') or {})
            if subject is None:
                options = ', '.join(f'{c.id}={c.name}' for c in candidates) or 'nessuno'
                print(f'• {path}: materia non riconosciuta (candidati: {options})')
                continue
            if args.prova:
                print(f'✓ {path} → {subject.id} {subject.name} ({len(data.get("entries") or [])} termini)')
                continue
            report = import_dictionary(db, data, admin, subject, None)
            print(f'✓ {path} → {subject.name}: {report["created"]} nuovi, {report["updated"]} aggiornati, '
                  f'{report["skipped"]} saltati (A.A. {report["academic_year"]})')
    finally:
        db.close()


if __name__ == '__main__':
    main()
