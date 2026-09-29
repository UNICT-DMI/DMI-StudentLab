"""Da dove vengono gli esercizi e come si presentano allo studente.

Identificativi (stabili, ricostruibili dal server per la correzione):
  ex:<id>            esercizio scritto nella banca della materia
  ex:<id>:<seme>     variante di un modello generato (grafo, subnetting, bubble sort…)
  dz:<entry>         flashcard da un termine approvato del Dizionario
  dzab:<e1>.<e2>…    "Abbina" con 3-5 termini approvati dello stesso argomento
  qf:<domanda>       flashcard da una domanda del quiz (se il Dizionario è vuoto)
"""
from __future__ import annotations

import logging
import random
import re
from typing import Any

from sqlalchemy import func
from sqlalchemy.orm import Session

from services import exercise_types as types_
from services.exercise_bank import public_attachments, read_exercises
from services.exercise_generators import MAX_SEED, generate
from services.quiz_service import get_available_questions

logger = logging.getLogger(__name__)

ID_PATTERN = re.compile(r'^(ex:[A-Za-z0-9_-]{1,40}(:\d{1,10})?|dz:\d{1,10}|dzab:\d{1,10}(\.\d{1,10}){2,4}|qf:[A-Za-z0-9_-]{1,90})$')
DEFINITION_LIMIT = 220


def valid_item_id(item_id: str) -> bool:
    return bool(ID_PATTERN.match(str(item_id or '')))


def subject_record(db: Session, department: str, course: str, subject: str):
    from models.subject import Subject
    return (db.query(Subject)
            .filter(func.lower(Subject.department_code) == department.strip().lower(),
                    func.lower(Subject.course_code) == course.strip().lower(),
                    func.lower(Subject.name) == subject.strip().lower(),
                    Subject.is_active.is_(True))
            .first())


def _available(record: dict) -> bool:
    return record.get('is_active', True) is not False and not record.get('is_hidden')


def _argument(record: dict) -> str | None:
    return (record.get('metadata') or {}).get('argoment') or None


# ------------------------------------------------------------- dal Dizionario
def _dictionary_rows(db: Session, subject_id: int) -> list[dict]:
    """Ultima versione approvata di ogni termine della materia."""
    try:
        from models.dictionary import DictionaryEntry, DictionaryTopic, DictionaryVersion
        from services.dictionary import PUBLIC_REVIEW_STATES
    except Exception:  # Dizionario non installato
        return []
    rows = (db.query(DictionaryEntry, DictionaryVersion, DictionaryTopic)
            .join(DictionaryVersion, DictionaryVersion.entry_id == DictionaryEntry.id)
            .outerjoin(DictionaryTopic, DictionaryTopic.id == DictionaryEntry.topic_id)
            .filter(DictionaryEntry.subject_id == subject_id,
                    DictionaryVersion.review_state.in_(PUBLIC_REVIEW_STATES))
            .order_by(DictionaryEntry.id, DictionaryVersion.academic_year.desc())
            .all())
    result, seen = [], set()
    for entry, version, topic in rows:
        if entry.id in seen:
            continue
        seen.add(entry.id)
        definition = (version.informal_definition or version.formal_definition or '').strip()
        if not definition:
            continue
        result.append({'entry_id': entry.id, 'term': entry.term, 'topic': topic.title if topic else None,
                       'informal': (version.informal_definition or '').strip(),
                       'formal': (version.formal_definition or '').strip(), 'year': version.academic_year})
    return result


def _short(text: str, limit: int = DEFINITION_LIMIT) -> str:
    text = re.sub(r'\s+', ' ', text).strip()
    return text if len(text) <= limit else text[:limit - 1].rsplit(' ', 1)[0] + '…'


def _flashcard_from_entry(row: dict) -> dict:
    back = row['informal'] or row['formal']
    if row['informal'] and row['formal']:
        back = f"{row['informal']}\n\nIn modo formale: {row['formal']}"
    return {'id': f"dz:{row['entry_id']}", 'type': 'flashcard', 'text': 'Ricordi il significato?',
            'argument': row['topic'], 'data': {'front': row['term'], 'back': back[:2000]},
            'source': 'dictionary', 'attachments': [], 'explanation': '', 'hint': '', 'estimed_time': 20,
            'difficulty': 1}


def _abbina_from_entries(rows: list[dict]) -> dict:
    rows = sorted(rows, key=lambda r: r['entry_id'])        # id canonico: stesso gruppo, stesso id
    ids = '.'.join(str(r['entry_id']) for r in rows)
    data = types_.clean_data('abbina', {'pairs': [{'left': r['term'], 'right': _short(r['informal'] or r['formal'])}
                                                  for r in rows]})
    return {'id': f'dzab:{ids}', 'type': 'abbina', 'text': 'Abbina ogni termine alla sua definizione.',
            'argument': rows[0]['topic'], 'data': data, 'source': 'dictionary', 'attachments': [],
            'explanation': '', 'hint': 'Tocca un termine a sinistra, poi la definizione giusta a destra.',
            'estimed_time': 60, 'difficulty': 2}


def _abbina_groups(rows: list[dict], rng: random.Random, size: int = 4) -> list[list[dict]]:
    by_topic: dict[str, list[dict]] = {}
    for row in rows:
        by_topic.setdefault(row['topic'] or '', []).append(row)
    groups = []
    for topic_rows in by_topic.values():
        topic_rows = list(topic_rows)
        rng.shuffle(topic_rows)
        for start in range(0, len(topic_rows) - size + 1, size):
            groups.append(topic_rows[start:start + size])
    return groups


# ------------------------------------------------------------- dalle domande
def _flashcard_from_question(question: dict) -> dict | None:
    correct = str(question.get('id_correct') or '')
    option = next((o for o in question.get('option') or [] if isinstance(o, dict) and str(o.get('id')) == correct), None)
    if option is None or question.get('attachments'):
        return None     # con un'immagine la domanda non sta su una scheda
    back = str(option.get('text') or '').strip()
    extra = str(question.get('informal_explanation') or '').strip()
    if extra:
        back = f'{back}\n\n{extra}'
    return {'id': f"qf:{question.get('id_question')}", 'type': 'flashcard', 'text': 'Ricordi la risposta?',
            'argument': (question.get('metadata') or {}).get('argoment'),
            'data': {'front': str(question.get('text') or '')[:600], 'back': back[:2000]},
            'source': 'questions', 'attachments': [], 'explanation': '', 'hint': '', 'estimed_time': 25,
            'difficulty': 1}


# ------------------------------------------------------------- dalla banca
def item_from_record(record: dict, seed: int | None = None) -> dict:
    base = {'argument': _argument(record), 'attachments': record.get('attachments') or [],
            'explanation': record.get('explanation') or '', 'hint': record.get('hint') or '',
            'estimed_time': record.get('estimed_time') or 60, 'source': 'bank',
            'difficulty': (record.get('metadata') or {}).get('difficulty') or 2}
    if record.get('generator'):
        if seed is None:
            seed = random.SystemRandom().randint(1, MAX_SEED)
        generated = generate(record, seed)
        text = generated['text'] if not record.get('text') else f"{record['text']}\n{generated['text']}"
        return {**base, 'id': f"ex:{record['id_exercise']}:{seed}", 'type': generated['type'], 'text': text,
                'data': types_.clean_data(generated['type'], generated['data']), 'source': 'generated'}
    # I record salvati dalla banca sono già validi; si ripulisce comunque (idempotente) per i file
    # scritti a mano: un record non valido solleva ValueError e chi chiama lo salta.
    return {**base, 'id': f"ex:{record['id_exercise']}", 'type': record['type'], 'text': record.get('text') or '',
            'data': types_.clean_data(record.get('type'), record.get('data'))}


def _safe_item(record: dict, seed: int | None = None) -> dict | None:
    try:
        return item_from_record(record, seed)
    except (ValueError, TypeError, KeyError) as exc:
        logger.warning('Esercizio %s saltato: %s', record.get('id_exercise'), exc)
        return None


# ------------------------------------------------------------- risoluzione
def resolve(db: Session | None, department: str, course: str, subject: str, item_id: str,
            include_hidden: bool = False) -> dict | None:
    """Ricostruisce l'esercizio completo (con soluzione) dal suo id. Solo server."""
    item_id = str(item_id or '').strip()
    if not valid_item_id(item_id):
        return None
    prefix, _, rest = item_id.partition(':')
    if prefix == 'ex':
        exercise_id, _, seed = rest.partition(':')
        for record in read_exercises(department, course, subject):
            if str(record.get('id_exercise')) != exercise_id:
                continue
            if not include_hidden and not _available(record):
                return None
            if record.get('generator'):
                return _safe_item(record, int(seed)) if seed else None
            return None if seed else _safe_item(record)
        return None
    if prefix == 'qf':
        for question in get_available_questions(department=department, course=course, subject=subject,
                                                selected_arguments=None):
            if str(question.get('id_question')) == rest:
                return _flashcard_from_question(question)
        return None
    if db is None:
        return None
    subject_row = subject_record(db, department, course, subject)
    if subject_row is None:
        return None
    rows = {r['entry_id']: r for r in _dictionary_rows(db, subject_row.id)}
    if prefix == 'dz':
        row = rows.get(int(rest))
        return _flashcard_from_entry(row) if row else None
    if prefix == 'dzab':
        numbers = [int(x) for x in rest.split('.')]
        if numbers != sorted(set(numbers)):
            return None     # solo la forma canonica (id crescenti, senza ripetizioni)
        chosen = [rows.get(x) for x in numbers]
        if any(r is None for r in chosen) or len({r['entry_id'] for r in chosen}) != len(chosen):
            return None
        return _abbina_from_entries(chosen)
    return None


def public_item(item: dict, rng: random.Random | None = None) -> dict:
    """Quello che vede lo studente: niente soluzione, niente percorsi di storage."""
    rng = rng or random.Random()
    meta = types_.TYPES[item['type']]
    return {'id': item['id'], 'type': item['type'], 'category': meta['category'], 'type_label': meta['label'],
            'text': item['text'], 'hint': item.get('hint') or '', 'argument': item.get('argument'),
            'estimed_time': item.get('estimed_time') or 60, 'difficulty': item.get('difficulty') or 2,
            'source': item.get('source'), 'attachments': public_attachments(item),
            'data': types_.public_data(item['type'], item['data'], rng)}


def grade_item(item: dict, answer: Any, scope: Any = None, run: dict | None = None) -> dict:
    answer = dict(answer) if isinstance(answer, dict) else {}
    answer.pop('_run', None)          # l'esito del codice non può arrivare dal client
    if run is not None:
        answer['_run'] = run
    result = types_.grade(item['type'], item['data'], answer, scope)
    result.update({'item_id': item['id'], 'type': item['type'], 'explanation': item.get('explanation') or '',
                   'solution_text': types_.solution_summary(item['type'], item['data'])
                   if result.get('correct_payload') is not None else ''})
    return result


# ------------------------------------------------------------- catalogo e scelta
def catalog(db: Session | None, department: str, course: str, subject: str, *, code_runner: bool) -> dict:
    counts: dict[str, dict[str, Any]] = {k: {'type': k, **v, 'count': 0, 'arguments': set(), 'generated': False}
                                         for k, v in types_.TYPES.items()}
    arguments: set[str] = set()
    for record in read_exercises(department, course, subject):
        if not _available(record) or record.get('type') not in counts:
            continue
        kind = record['type']
        counts[kind]['count'] += 1
        if record.get('generator'):
            counts[kind]['generated'] = True
        if _argument(record):
            counts[kind]['arguments'].add(_argument(record))
            arguments.add(_argument(record))
    dictionary = []
    if db is not None:
        subject_row = subject_record(db, department, course, subject)
        if subject_row is not None:
            dictionary = _dictionary_rows(db, subject_row.id)
    counts['flashcard']['count'] += len(dictionary)
    counts['flashcard']['from_dictionary'] = len(dictionary)
    groups = _abbina_groups(dictionary, random.Random(0))
    counts['abbina']['count'] += len(groups)
    for row in dictionary:
        if row['topic']:
            counts['flashcard']['arguments'].add(row['topic'])
    if not dictionary:
        questions = [q for q in get_available_questions(department=department, course=course, subject=subject,
                                                        selected_arguments=None) if not q.get('attachments')]
        counts['flashcard']['count'] += len(questions)
        counts['flashcard']['from_questions'] = len(questions)
        for q in questions:
            argument = (q.get('metadata') or {}).get('argoment')
            if argument:
                counts['flashcard']['arguments'].add(argument)
    result = []
    for value in counts.values():
        value['arguments'] = sorted(value['arguments'])
        value['available'] = value['count'] > 0 and (value['type'] != 'codice' or code_runner)
        if value['type'] == 'codice' and not code_runner:
            value['unavailable_reason'] = 'Serve il servizio di esecuzione isolata (CODE_RUNNER_URL).'
        result.append(value)
    return {'types': result, 'arguments': sorted(arguments | set(counts['flashcard']['arguments'])),
            'code_runner': code_runner}


MULTIPLE_CHOICE = 'multiple_choice'
MC_INFO = {'label': 'Risposta multipla', 'category': 'pratica'}


def base_id(item_id: str) -> str:
    """ex:5:123 (variante generata) -> ex:5; gli altri id restano uguali."""
    value = str(item_id or '')
    return value.rsplit(':', 1)[0] if value.startswith('ex:') and value.count(':') == 2 else value


def _seconds(record: dict, default: int = 60) -> int:
    try:
        return max(5, int(float(record.get('estimed_time') or default)))
    except (TypeError, ValueError):
        return default


class Filters:
    """Filtri scelti dallo studente prima di vedere le schede dei tipi.
    Niente filtro per difficoltà: le domande non hanno una categoria facile/media/difficile."""

    def __init__(self, arguments=None, max_seconds=None, include=None, exclude=None):
        self.arguments = {a.casefold() for a in arguments or [] if a}
        self.max_seconds = int(max_seconds) if max_seconds else None
        self.include = set(include) if include is not None else None      # solo questi (es. da rivedere)
        self.exclude = set(exclude or ())                                 # mai questi (es. già fatti)

    def argument_ok(self, value: str | None) -> bool:
        return not self.arguments or (value or '').casefold() in self.arguments

    def ok(self, item_id: str, argument: str | None, seconds: int,
           check_argument: bool = True, check_seconds: bool = True) -> bool:
        key = base_id(item_id)
        if key in self.exclude or (self.include is not None and key not in self.include):
            return False
        if check_argument and not self.argument_ok(argument):
            return False
        return not (check_seconds and self.max_seconds and seconds > self.max_seconds)


def history_from_rows(rows) -> dict:
    """rows: (item_id, tipo, punteggio 0-1 o None, corretto, quando) in ordine di tempo.
    Restituisce id già fatti, id da rivedere (ultima risposta non piena) e statistiche per tipo."""
    last: dict[str, tuple] = {}
    stats: dict[str, dict] = {}
    for item_id, kind, score, correct, when in rows:
        key = base_id(item_id)
        kind = kind or MULTIPLE_CHOICE
        value = float(score) if score is not None else (1.0 if correct else 0.0)
        last[key] = (kind, value, when)
        entry = stats.setdefault(kind, {'answers': 0, 'score_sum': 0.0, 'last_at': None, 'items': set()})
        entry['answers'] += 1
        entry['score_sum'] += value
        entry['items'].add(key)
        if when is not None and (entry['last_at'] is None or str(when) > str(entry['last_at'])):
            entry['last_at'] = when
    wrong = {k for k, (_, value, _) in last.items() if value < 0.999}
    out_stats = {}
    for kind, entry in stats.items():
        out_stats[kind] = {'done': len(entry['items']), 'answers': entry['answers'],
                           'avg_score': round(entry['score_sum'] / entry['answers'], 3) if entry['answers'] else None,
                           'last_at': str(entry['last_at']) if entry['last_at'] is not None else None,
                           'to_review': sum(1 for k in entry['items'] if k in wrong)}
    return {'seen': set(last), 'wrong': wrong, 'stats': out_stats}


def user_history(db: Session, user_id: int, department: str, course: str, subject: str) -> dict:
    from models.quiz_attempt import QuizAttempt, QuizAttemptAnswer
    rows = (db.query(QuizAttemptAnswer.question_id, QuizAttemptAnswer.question_type, QuizAttemptAnswer.score,
                     QuizAttemptAnswer.is_correct, QuizAttempt.completed_at)
            .join(QuizAttempt, QuizAttempt.id == QuizAttemptAnswer.attempt_id)
            .filter(QuizAttempt.user_id == user_id, QuizAttempt.status == 'completed',
                    QuizAttempt.is_deleted.is_(False),
                    func.lower(QuizAttempt.department) == department.strip().lower(),
                    func.lower(QuizAttempt.course) == course.strip().lower(),
                    func.lower(QuizAttempt.subject) == subject.strip().lower())
            .order_by(QuizAttempt.completed_at.asc())
            .limit(20000).all())
    return history_from_rows(rows)


def _mc_meta(question: dict) -> tuple[str, str | None, int]:
    return str(question.get('id_question')), (question.get('metadata') or {}).get('argoment'), _seconds(question, 30)


def public_multiple_choice(question: dict) -> dict:
    """Domanda a risposta multipla dentro un'esercitazione: senza risposta giusta né percorsi."""
    return {'id': str(question.get('id_question')), 'id_question': str(question.get('id_question')),
            'type': MULTIPLE_CHOICE, 'category': MC_INFO['category'], 'type_label': MC_INFO['label'],
            'text': question.get('text') or '', 'metadata': question.get('metadata') or {},
            'argument': (question.get('metadata') or {}).get('argoment'),
            'estimed_time': question.get('estimed_time'),
            'attachments': public_attachments(question),
            'option': [{k: v for k, v in o.items() if k in ('id', 'text', 'attachment_id')}
                       for o in question.get('option') or [] if isinstance(o, dict)]}


def overview(db: Session | None, department: str, course: str, subject: str, *, filters: Filters,
             code_runner: bool, history: dict | None = None, only_new: bool = False,
             only_mistakes: bool = False) -> dict:
    """Schede dei tipi di esercizio per i filtri scelti: quanti ce ne sono, per quali argomenti,
    quanto durano e come sono andati i tentativi dello studente."""
    history = history or {'seen': set(), 'wrong': set(), 'stats': {}}
    if only_mistakes:
        filters.include = set(history['wrong']) if filters.include is None else filters.include & history['wrong']
    if only_new:
        filters.exclude = filters.exclude | set(history['seen'])
    cards: dict[str, dict] = {}
    for kind, info in [(MULTIPLE_CHOICE, MC_INFO)] + list(types_.TYPES.items()):
        cards[kind] = {'type': kind, **info, 'count': 0, 'templates': 0, 'by_argument': {},
                       'seconds_sum': 0, 'new': 0, 'to_review': 0, 'stats': history['stats'].get(kind)}
    arg_counts: dict[str, int] = {}
    durations = {'short': 0, 'medium': 0, 'long': 0}

    def count(kind, item_id, argument, seconds, template=False):
        card = cards[kind]
        tally = kind != 'flashcard'          # le flashcard si ripassano a parte: non contano nei filtri
        # Ogni filtro si conta ignorando se stesso: accanto a ogni voce si vede quanti esercizi
        # si otterrebbero sceglierla (si può aggiungere un argomento o allungare la durata).
        if tally and argument and filters.ok(item_id, argument, seconds, check_argument=False):
            arg_counts[argument] = arg_counts.get(argument, 0) + 1
        if tally and filters.ok(item_id, argument, seconds, check_seconds=False):
            durations['short' if seconds <= 60 else 'medium' if seconds <= 180 else 'long'] += 1
        # Le flashcard seguono solo gli argomenti (la pagina delle flashcard non ha altri filtri).
        if not filters.ok(item_id, argument, seconds, check_seconds=tally):
            return
        card['count'] += 1
        card['templates'] += 1 if template else 0
        if argument:
            card['by_argument'][argument] = card['by_argument'].get(argument, 0) + 1
        card['seconds_sum'] += seconds
        key = base_id(item_id)
        card['new'] += 0 if key in history['seen'] and not template else 1
        card['to_review'] += 1 if key in history['wrong'] else 0

    for record in read_exercises(department, course, subject):
        if not _available(record) or record.get('type') not in cards:
            continue
        count(record['type'], f"ex:{record['id_exercise']}", _argument(record),
              _seconds(record), template=bool(record.get('generator')))
    dictionary = []
    if db is not None:
        subject_row = subject_record(db, department, course, subject)
        dictionary = _dictionary_rows(db, subject_row.id) if subject_row is not None else []
    for row in dictionary:
        count('flashcard', f"dz:{row['entry_id']}", row['topic'], 20)
    for group in _abbina_groups(dictionary, random.Random(0)):
        item = _abbina_from_entries(group)
        count('abbina', item['id'], item['argument'], 60)
    for question in get_available_questions(department=department, course=course, subject=subject,
                                            selected_arguments=None):
        qid, argument, seconds = _mc_meta(question)
        count(MULTIPLE_CHOICE, qid, argument, seconds)
        if not dictionary and not question.get('attachments'):
            count('flashcard', f'qf:{qid}', argument, 25)
    result = []
    for card in cards.values():
        n = card.pop('seconds_sum')
        card['avg_seconds'] = round(n / card['count']) if card['count'] else None
        card['arguments'] = sorted(card['by_argument'])
        card['variants'] = card['templates'] > 0          # modelli generati: varianti sempre nuove
        card['available'] = card['count'] > 0 and (card['type'] != 'codice' or code_runner)
        if card['type'] == 'codice' and not code_runner:
            card['unavailable_reason'] = 'Il servizio che esegue il codice non è attivo.'
        elif card['count'] == 0:
            card['unavailable_reason'] = 'Nessun esercizio di questo tipo con i filtri scelti.'
        result.append(card)
    result.sort(key=lambda c: (not c['available'], -c['count']))
    return {
        'types': result,
        'total': sum(c['count'] for c in result if c['available'] and c['type'] != 'flashcard'),
        'filters': {
            'arguments': [{'name': a, 'count': n} for a, n in sorted(arg_counts.items(), key=lambda x: x[0].casefold())],
            'durations': durations,
            'seen': len(history['seen']), 'to_review': len(history['wrong']),
        },
        'code_runner': code_runner,
    }


def pick(db: Session | None, department: str, course: str, subject: str, *, types: list[str],
         arguments: list[str] | None, count: int, rng: random.Random | None = None,
         code_runner: bool = False, exclude: set[str] | None = None, graded: bool = False,
         filters: Filters | None = None) -> list[dict]:
    """Sceglie `count` esercizi alternando i tipi richiesti (varietà prima di tutto).
    graded=True (tentativi con voto): niente flashcard e niente esercizi dal Dizionario o dalle
    domande, che sono consultabili liberamente nell'app. filters: difficoltà, durata, solo da
    rivedere / solo nuovi (vedi Filters). "multiple_choice" tra i tipi aggiunge le domande del quiz."""
    rng = rng or random.Random()
    filters = filters or Filters(arguments=arguments)
    if arguments and not filters.arguments:
        filters.arguments = {a.casefold() for a in arguments if a}
    wanted = [t for t in types if (t in types_.TYPES or (t == MULTIPLE_CHOICE and not graded))
              and (t != 'codice' or code_runner) and not (graded and t == 'flashcard')]
    selected_args = filters.arguments
    exclude = set(exclude or set()) | filters.exclude

    def argument_ok(value: str | None) -> bool:
        return not selected_args or (value or '').casefold() in selected_args

    pools: dict[str, list] = {t: [] for t in wanted}
    if MULTIPLE_CHOICE in pools:
        for question in get_available_questions(department=department, course=course, subject=subject,
                                                selected_arguments=None):
            qid, argument, seconds = _mc_meta(question)
            if qid not in exclude and filters.ok(qid, argument, seconds):
                pools[MULTIPLE_CHOICE].append(('item', {'id': qid, 'type': MULTIPLE_CHOICE, 'question': question,
                                                        'argument': argument}))
    for record in read_exercises(department, course, subject):
        if _available(record) and record.get('type') in pools and argument_ok(_argument(record)):
            if f"ex:{record['id_exercise']}" in exclude:
                continue
            if not filters.ok(f"ex:{record['id_exercise']}", _argument(record), _seconds(record)):
                continue
            if record.get('generator'):
                pools[record['type']].extend([('gen', record)] * 3)     # fino a 3 varianti per modello
            else:
                pools[record['type']].append(('rec', record))
    if not graded and ('flashcard' in pools or 'abbina' in pools):
        dictionary = []
        if db is not None:
            subject_row = subject_record(db, department, course, subject)
            dictionary = _dictionary_rows(db, subject_row.id) if subject_row is not None else []
        dictionary = [r for r in dictionary if argument_ok(r['topic'])]
        if 'flashcard' in pools:
            pools['flashcard'].extend(('item', _flashcard_from_entry(r)) for r in dictionary
                                      if filters.ok(f"dz:{r['entry_id']}", r['topic'], 20))
            if not dictionary:
                for question in get_available_questions(department=department, course=course, subject=subject,
                                                        selected_arguments=list(arguments or []) or None):
                    card = _flashcard_from_question(question)
                    if card:
                        pools['flashcard'].append(('item', card))
        if 'abbina' in pools:
            for group in _abbina_groups(dictionary, rng):
                item = _abbina_from_entries(group)
                if filters.ok(item['id'], item['argument'], 60):
                    pools['abbina'].append(('item', item))
    for pool in pools.values():
        rng.shuffle(pool)
    result, used = [], set(exclude)
    active = [t for t in wanted if pools[t]]
    while len(result) < count and active:
        for kind in list(active):
            if len(result) >= count:
                break
            while pools[kind]:
                source, value = pools[kind].pop()
                item = _safe_item(value, rng.randint(1, MAX_SEED)) if source == 'gen' else (
                    _safe_item(value) if source == 'rec' else value)
                if item is not None and item['id'] not in used:
                    used.add(item['id'])
                    result.append(item)
                    break
            if not pools[kind]:
                active.remove(kind)
    rng.shuffle(result)
    return result


def dictionary_flashcards(db: Session, department: str, course: str, subject: str,
                          arguments: list[str] | None = None) -> list[dict]:
    subject_row = subject_record(db, department, course, subject)
    rows = _dictionary_rows(db, subject_row.id) if subject_row is not None else []
    wanted = {a.casefold() for a in arguments or []}
    cards = [_flashcard_from_entry(r) for r in rows if not wanted or (r['topic'] or '').casefold() in wanted]
    for record in read_exercises(department, course, subject):     # schede scritte nella banca
        if record.get('type') == 'flashcard' and _available(record) and not record.get('generator') and (
                not wanted or (_argument(record) or '').casefold() in wanted):
            card = _safe_item(record)
            if card is not None:
                cards.append(card)
    if cards:
        return cards
    result = []
    for question in get_available_questions(department=department, course=course, subject=subject,
                                            selected_arguments=list(arguments or []) or None):
        card = _flashcard_from_question(question)
        if card:
            result.append(card)
    return result


def snapshot(item: dict, rng: random.Random) -> dict:
    """Come l'esercizio entra in quiz_attempts.questions_snapshot (compatibile con le domande)."""
    return {'id_question': item['id'], 'type': item['type'], 'text': item['text'],
            'metadata': {'argoment': item.get('argument')}, 'attachments': item.get('attachments') or [],
            'estimed_time': item.get('estimed_time'), 'hint': item.get('hint') or '',
            'explanation': item.get('explanation') or '', 'source': item.get('source'),
            'difficulty': item.get('difficulty') or 2,
            'data': item['data'], 'public': types_.public_data(item['type'], item['data'], rng)}


def public_from_snapshot(snap: dict) -> dict:
    meta = types_.TYPES.get(snap.get('type'), {'category': 'pratica', 'label': snap.get('type')})
    return {'id_question': str(snap.get('id_question')), 'id': str(snap.get('id_question')), 'type': snap.get('type'),
            'category': meta['category'], 'type_label': meta['label'], 'text': snap.get('text') or '',
            'hint': snap.get('hint') or '', 'metadata': snap.get('metadata') or {},
            'argument': (snap.get('metadata') or {}).get('argoment'), 'estimed_time': snap.get('estimed_time'),
            'difficulty': snap.get('difficulty') or 2, 'attachments': public_attachments(snap),
            'data': snap.get('public') or {}, 'option': [], 'check': _check_state(snap)}


def _check_state(snap: dict) -> dict:
    """Per riprendere un tentativo: quante volte è stato controllato e, se chiuso, l'esito."""
    state = snap.get('_checks') if isinstance(snap.get('_checks'), dict) else {}
    final = state.get('final') if isinstance(state.get('final'), dict) else None
    result = {'tries': int(state.get('tries') or 0), 'final': final is not None}
    if final is not None:
        answer = {k: v for k, v in (final.get('answer') or {}).items() if k != '_run'}
        result.update({'answer': answer, 'result': final.get('result')})
    return result


def item_from_snapshot(snap: dict) -> dict:
    return {'id': str(snap.get('id_question')), 'type': snap.get('type'), 'text': snap.get('text') or '',
            'data': snap.get('data') or {}, 'explanation': snap.get('explanation') or '',
            'argument': (snap.get('metadata') or {}).get('argoment'), 'attachments': snap.get('attachments') or []}
