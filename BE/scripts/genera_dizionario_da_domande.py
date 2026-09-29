#!/usr/bin/env python3
"""Genera una prima versione del Dizionario dai JSON delle domande.

Cerca tutti i file `data/**/question/*.json` (qualsiasi ateneo, dipartimento
e corso: la struttura delle cartelle non è fissa) e per ogni materia scrive
`data/<stessa cartella>/dictionary/<nome file>.json` nel formato
`studentlab.dictionary/1`.

Da ogni domanda prende, se riesce a riconoscerlo, il TERMINE:
  1. campo esplicito `term` (o `metadata.term`), se presente: è il modo
     consigliato per le domande nuove;
  2. un termine breve tra virgolette nel testo ("Formula soddisfacibile");
  3. frasi tipiche ("… definisce correttamente Router?", "che cosa indica …?").
Poi raccoglie definizione formale e informale, argomento, docenti, anno e gli
id delle domande (per "Mettiti alla prova"). Le domande senza termine
riconoscibile restano fuori dal dizionario (sono comunque nel quiz).

Uso, dalla cartella BE/:
    python3 scripts/genera_dizionario_da_domande.py            # solo il riepilogo
    python3 scripts/genera_dizionario_da_domande.py --scrivi   # crea soltanto file nuovi
    python3 scripts/genera_dizionario_da_domande.py --data altra/cartella
"""
import argparse
import json
import re
import sys
import unicodedata
from collections import OrderedDict
from pathlib import Path

SCHEMA = 'studentlab.dictionary/1'

PATTERNS = [
    r"definisce correttamente (?P<t>.+?)\s*\?$",
    r"che cosa indica (?P<t>.+?)\s*\?$",
    r"descrive correttamente (?P<t>.+?)\s*\?$",
    r"a quale definizione corrisponde (?P<t>.+?)\s*\?$",
    r"^che cos['’]è (?P<t>.+?)\s*\?$",
    r"^cos['’]è (?P<t>.+?)\s*\?$",
    r"^cosa si intende per (?P<t>.+?)\s*\?$",
    r"^qual è la definizione (?:o l['’]enunciato formale )?(?:corrett[oa] )?di (?P<t>.+?)\s*\?$",
]
QUOTED = re.compile(r'[“"«]([^”"»\n]{2,60})[”"»]')
ARTICLES = re.compile(r"^(?:(?:un|una|uno|il|lo|la|i|gli|le)\s+|l['’]\s*|un['’]\s*)", re.I)


def slug(text: str) -> str:
    value = unicodedata.normalize('NFKD', text).encode('ascii', 'ignore').decode().lower()
    return re.sub(r'[^a-z0-9]+', '-', value).strip('-')[:80] or 'termine'


def clean_term(raw: str) -> str | None:
    term = ARTICLES.sub('', raw.strip().strip('.:;')).strip()
    if not term or len(term) > 60 or len(term.split()) > 8 or '?' in term:
        return None
    if term.lower().startswith(('seguente', 'quale ', 'cosa ', 'come ')):
        return None
    return term[0].upper() + term[1:]


def find_term(question: dict) -> str | None:
    explicit = question.get('term') or (question.get('metadata') or {}).get('term')
    if isinstance(explicit, str) and explicit.strip():
        return explicit.strip()
    text = ' '.join(str(question.get('text') or '').split())
    for match in QUOTED.finditer(text):
        term = clean_term(match.group(1))
        if term:
            return term
    for pattern in PATTERNS:
        match = re.search(pattern, text, re.I)
        if match:
            term = clean_term(match.group('t'))
            if term:
                return term
    return None


def load_questions(path: Path) -> list[dict]:
    data = json.loads(path.read_text(encoding='utf-8'))
    if isinstance(data, dict):
        data = data.get('questions') or data.get('items') or []
    return [q for q in data if isinstance(q, dict)]


def build(path: Path, data_root: Path) -> tuple[dict, dict]:
    questions = load_questions(path)
    relative = path.relative_to(data_root).parts   # es. ('dmi', 'l-31', 'question', 'reti.json')
    folders = list(relative[:-2])
    meta0 = (questions[0].get('metadata') if questions else {}) or {}
    teachers, years = [], []
    topics: OrderedDict[str, dict] = OrderedDict()
    entries: OrderedDict[str, dict] = OrderedDict()
    skipped = 0
    for q in questions:
        meta = q.get('metadata') or {}
        names = meta.get('teacher') or meta.get('teachers') or []
        if isinstance(names, str):
            names = [n.strip() for n in re.split(r'[;,]', names) if n.strip()]
        for t in names:
            if t and t not in teachers:
                teachers.append(t)
        year = meta.get('year_of_validity') or meta.get('academic_year')
        if year and year not in years:
            years.append(year)
        topic_title = (meta.get('argoment') or meta.get('topic') or 'Generale').strip()
        topic_id = slug(topic_title)
        topics.setdefault(topic_id, {'id': topic_id, 'title': topic_title, 'order': len(topics) + 1})
        term = find_term(q)
        if term is None:
            skipped += 1
            continue
        key = slug(term)
        entry = entries.get(key)
        if entry is None:
            entry = entries[key] = {
                'id': key, 'term': term, 'aliases': [], 'topic': topic_id,
                'formal_definition': '', 'informal_definition': '',
                'examples': [], 'exercises': [], 'exam_questions': [],
                'related': [], 'resources': [], 'quiz_question_ids': [],
            }
        if not entry['formal_definition'] and (q.get('formal_explanation') or '').strip():
            entry['formal_definition'] = q['formal_explanation'].strip()
        if not entry['informal_definition'] and (q.get('informal_explanation') or '').strip():
            entry['informal_definition'] = q['informal_explanation'].strip()
        qid = q.get('id_question') or q.get('id')
        if qid is not None and qid not in entry['quiz_question_ids']:
            entry['quiz_question_ids'].append(qid)
    result = {
        'schema': SCHEMA,
        'metadata': {
            'university': meta0.get('city') or meta0.get('university'),
            'department': meta0.get('department'),
            'department_code': folders[0].upper() if len(folders) >= 1 else None,
            'course': meta0.get('course'),
            'course_code': folders[1].upper() if len(folders) >= 2 else None,
            'subject': meta0.get('sub') or meta0.get('subject') or path.stem.replace('_', ' ').title(),
            'academic_year': years[-1] if years else None,
            'teachers': teachers,
            'source': str(path.relative_to(data_root)),
        },
        'topics': [t for t in topics.values() if any(e['topic'] == t['id'] for e in entries.values())],
        'entries': [e for e in entries.values() if e['formal_definition'] or e['informal_definition']],
    }
    report = {'file': str(path.relative_to(data_root)), 'questions': len(questions),
              'terms': len(result['entries']), 'skipped': skipped}
    return result, report


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--data', default='data', help='cartella radice dei dati (default: data)')
    parser.add_argument('--prova', action='store_true', help='solo il riepilogo (comportamento predefinito)')
    parser.add_argument('--scrivi', action='store_true', help='crea soltanto JSON nuovi; non sovrascrive file esistenti')
    args = parser.parse_args()
    if args.prova and args.scrivi:
        parser.error('--prova e --scrivi non possono essere usati insieme')
    root = Path(args.data)
    files = sorted(p for p in root.rglob('*.json') if p.parent.name == 'question')
    if not files:
        sys.exit(f'✗ Nessun file in {root}/**/question/*.json')
    print(f'{"File":58} {"domande":>8} {"termini":>8} {"senza":>7}')
    for path in files:
        try:
            result, report = build(path, root)
        except (json.JSONDecodeError, OSError) as exc:
            print(f'✗ {path}: {exc}')
            continue
        print(f'{report["file"]:58} {report["questions"]:8} {report["terms"]:8} {report["skipped"]:7}')
        if args.scrivi and result['entries']:
            out = path.parent.parent / 'dictionary' / path.name
            if out.exists():
                print(f'  • già presente, non sovrascritto: {out}')
                continue
            out.parent.mkdir(parents=True, exist_ok=True)
            with out.open('x', encoding='utf-8') as file:
                file.write(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
            print(f'  ✓ creato: {out}')
    print('\n"senza": domande in cui non si riconosce un termine. Per le domande nuove aggiungi il campo '
          '"term" (es. "term": "Router") e verranno incluse.')


if __name__ == '__main__':
    main()
