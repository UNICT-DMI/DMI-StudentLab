"""Tipi di esercizio: validazione, versione pubblica e correzione.

Ogni tipo ha tre funzioni pure (niente database, niente rete):
  clean(data)            -> dati validati per il salvataggio (ValueError se non validi)
  public(data, rng)      -> quello che vede lo studente, SENZA soluzione
  grade(data, answer, scope) -> esito: is_correct, score 0..1, feedback, soluzione

La correzione avviene solo sul server. `scope` permette di controllare una
parte (es. una riga di "traccia") senza rivelare il resto.
"""
from __future__ import annotations

import hashlib
import math
import random
import re
import unicodedata
from typing import Any, Callable

MAX_TEXT = 4000
MAX_ITEMS = 40

TYPES: dict[str, dict[str, str]] = {
    'scelta': {'label': 'Scelta con allegati', 'category': 'pratica'},
    'ordina': {'label': 'Ordina i passaggi', 'category': 'logico'},
    'abbina': {'label': 'Abbina', 'category': 'logico'},
    'completa': {'label': 'Completa gli spazi', 'category': 'pratica'},
    'errore': {'label': 'Trova l’errore', 'category': 'logico'},
    'diagramma': {'label': 'Tocca sul diagramma', 'category': 'visivo'},
    'grafo': {'label': 'Grafo interattivo', 'category': 'strategia'},
    'flashcard': {'label': 'Flashcard', 'category': 'memoria'},
    'traccia': {'label': 'Traccia l’algoritmo', 'category': 'strategia'},
    'numerica': {'label': 'Risposta numerica', 'category': 'pratica'},
    'codice': {'label': 'Scrivi il codice', 'category': 'pratica'},
    # tipi generici (v24): adatti a qualunque corso, il contenuto lo scrive il docente
    'caso': {'label': 'Caso pratico a passi', 'category': 'ragionamento'},
    'vero_falso': {'label': 'Vero o falso motivato', 'category': 'logico'},
    'categorizza': {'label': 'Categorizza', 'category': 'logico'},
    'linea_tempo': {'label': 'Linea del tempo', 'category': 'logico'},
    'risposta_breve': {'label': 'Risposta breve con griglia', 'category': 'ragionamento'},
}
# multiple_choice = le domande attuali dei quiz (non passano da qui).
EXERCISE_TYPES = tuple(TYPES)


# --------------------------------------------------------------------- utilità
def _text(value: Any, limit: int = MAX_TEXT, required: bool = True, name: str = 'testo') -> str:
    result = str(value if value is not None else '').strip()[:limit]
    if required and not result:
        raise ValueError(f'Manca {name}.')
    return result


def _id(value: Any, name: str = 'id') -> str:
    result = str(value if value is not None else '').strip()[:60]
    if not result or not re.fullmatch(r'[A-Za-z0-9_.:-]+', result):
        raise ValueError(f'{name} non valido: usa lettere, numeri, _ . : -')
    return result


def _list(value: Any, name: str, minimum: int = 1, maximum: int = MAX_ITEMS) -> list:
    if not isinstance(value, list):
        raise ValueError(f'{name}: serve un elenco.')
    if not (minimum <= len(value) <= maximum):
        raise ValueError(f'{name}: servono da {minimum} a {maximum} elementi.')
    return value


def _opaque(prefix: str, *parts: Any) -> str:
    """Id derivato SOLO dal contenuto visibile: non rivela l'ordine giusto né le coppie."""
    digest = hashlib.sha256('\x1f'.join(str(p) for p in parts).encode('utf-8')).hexdigest()[:10]
    return f'{prefix}{digest}'


def _as_list(value: Any) -> list:
    return value if isinstance(value, list) else []


def _as_dict(value: Any) -> dict:
    return value if isinstance(value, dict) else {}


def _unique(ids: list[str], name: str) -> None:
    if len(ids) != len(set(ids)):
        raise ValueError(f'{name}: identificativi ripetuti.')


def normalize_answer(value: Any, case_sensitive: bool = False) -> str:
    text = unicodedata.normalize('NFKC', str(value if value is not None else '')).strip()
    text = re.sub(r'\s+', ' ', text)
    return text if case_sensitive else text.casefold()


def parse_number(value: Any) -> float | None:
    """Accetta 1.5, 1,5, 1 500, 2^3, 3/4 (frazione semplice)."""
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        try:
            number = float(value)
        except (OverflowError, ValueError):
            return None
        return number if math.isfinite(number) else None
    text = str(value if value is not None else '').strip().replace(' ', '').replace(' ', '')
    if not text or len(text) > 40:
        return None
    match = re.fullmatch(r'(-?\d+)\^(\d{1,3})', text)
    if match:
        try:
            result = float(int(match.group(1)) ** int(match.group(2)))
        except OverflowError:
            return None
        return result if math.isfinite(result) else None
    match = re.fullmatch(r'(-?\d+(?:[.,]\d+)?)/(\d+(?:[.,]\d+)?)', text)
    if match:
        try:
            denominator = float(match.group(2).replace(',', '.'))
            result = float(match.group(1).replace(',', '.')) / denominator if denominator else None
        except (OverflowError, ValueError):
            return None
        return result if result is not None and math.isfinite(result) else None
    if text.count(',') == 1 and '.' not in text:
        text = text.replace(',', '.')
    try:
        result = float(text)
    except (ValueError, OverflowError):
        return None
    return result if math.isfinite(result) else None


def _within(value: float, expected: float, tolerance: float = 0.0, tolerance_pct: float = 0.0) -> bool:
    allowed = max(abs(tolerance), abs(expected) * abs(tolerance_pct) / 100.0, 1e-9)
    return abs(value - expected) <= allowed


def _result(is_correct: bool, score: float, feedback: dict | None = None, solution: Any = None) -> dict:
    score = max(0.0, min(1.0, float(score)))
    return {'is_correct': bool(is_correct), 'score': round(score, 4), 'feedback': feedback or {},
            'correct_payload': solution}


def _shuffled(items: list, rng: random.Random) -> list:
    copy = list(items)
    rng.shuffle(copy)
    return copy


# --------------------------------------------------------------------- scelta
def _clean_scelta(data: dict) -> dict:
    options = []
    for raw in _list(data.get('options'), 'Risposte', 2, 12):
        if not isinstance(raw, dict):
            raise ValueError('Risposte: ogni risposta deve avere id e testo.')
        option = {'id': _id(raw.get('id'), 'id della risposta'), 'text': _text(raw.get('text'), 1000, False)}
        if raw.get('attachment_id'):
            option['attachment_id'] = _id(raw['attachment_id'], 'allegato della risposta')
        if not option['text'] and 'attachment_id' not in option:
            raise ValueError('Ogni risposta deve avere un testo o un’immagine.')
        options.append(option)
    ids = [o['id'] for o in options]
    _unique(ids, 'Risposte')
    correct = [str(c) for c in _list(data.get('correct'), 'Risposte corrette', 1, len(ids))]
    if not set(correct) <= set(ids):
        raise ValueError('Le risposte corrette devono essere tra le risposte.')
    explanations = _as_dict(data.get('explanations'))
    # Gli id scritti dal docente (a, b, c…) direbbero quale risposta era la prima: si sostituiscono.
    remap = {o['id']: _opaque('o', o['text'], o.get('attachment_id', '')) for o in options}
    if len(set(remap.values())) != len(remap):
        raise ValueError('Risposte: due risposte sono identiche.')
    for option in options:
        option['id'] = remap[option['id']]
    return {'options': options, 'correct': sorted({remap[c] for c in correct}),
            'multiple': bool(data.get('multiple')) or len(set(correct)) > 1,
            'explanations': {remap[k]: _text(v, 1500, False) for k, v in explanations.items() if k in remap}}


def _public_scelta(data: dict, rng: random.Random) -> dict:
    return {'options': _shuffled(data['options'], rng), 'multiple': data['multiple']}


def _grade_scelta(data: dict, answer: dict, scope: Any = None) -> dict:
    chosen = {str(x) for x in _as_list(answer.get('selected')) if isinstance(x, (str, int))}
    valid = {o['id'] for o in data['options']}
    chosen &= valid
    correct = set(data['correct'])
    if not data['multiple']:
        chosen = set(list(chosen)[:1])
    hits = len(chosen & correct)
    wrong = len(chosen - correct)
    exact = chosen == correct
    score = 1.0 if exact else max(0.0, (hits - wrong) / len(correct))
    return _result(exact, score, {'selected': sorted(chosen), 'wrong': sorted(chosen - correct),
                                  'missed': sorted(correct - chosen),
                                  'explanations': {k: v for k, v in data.get('explanations', {}).items() if k in chosen | correct}},
                   {'correct': sorted(correct)})


# --------------------------------------------------------------------- ordina
def _clean_ordina(data: dict) -> dict:
    items = []
    for raw in _list(data.get('items'), 'Passaggi', 2, 15):
        if isinstance(raw, str):
            raw = {'id': f's{len(items) + 1}', 'text': raw}
        if not isinstance(raw, dict):
            raise ValueError('Passaggi: ogni passaggio è un testo o {"id", "text"}.')
        items.append({'id': _id(raw.get('id'), 'id del passaggio'), 'text': _text(raw.get('text'), 600)})
    ids = [i['id'] for i in items]
    _unique(ids, 'Passaggi')
    order = [str(x) for x in (_as_list(data.get('order')) or ids)]
    if sorted(order) != sorted(ids):
        raise ValueError('L’ordine corretto deve contenere tutti i passaggi una volta.')
    accepted = []
    for alternative in _as_list(data.get('accepted_orders')):
        alternative = [str(x) for x in _as_list(alternative)]
        if sorted(alternative) != sorted(ids):
            raise ValueError('Ogni ordine alternativo deve contenere tutti i passaggi.')
        accepted.append(alternative)
    # id opachi: con s1, s2… basterebbe ordinare per id per avere la soluzione
    remap = {i['id']: _opaque('p', i['text']) for i in items}
    if len(set(remap.values())) != len(remap):
        raise ValueError('Passaggi: due passaggi hanno lo stesso testo.')
    for item in items:
        item['id'] = remap[item['id']]
    return {'items': items, 'order': [remap[x] for x in order],
            'accepted_orders': [[remap[x] for x in alt] for alt in accepted[:5]]}


def _public_ordina(data: dict, rng: random.Random) -> dict:
    items = _shuffled(data['items'], rng)
    if [i['id'] for i in items] == data['order'] and len(items) > 1:
        items = items[1:] + items[:1]
    return {'items': items}


def _lcs(a: list, b: list) -> int:
    table = [[0] * (len(b) + 1) for _ in range(len(a) + 1)]
    for i, x in enumerate(a):
        for j, y in enumerate(b):
            table[i + 1][j + 1] = table[i][j] + 1 if x == y else max(table[i][j + 1], table[i + 1][j])
    return table[-1][-1]


def _grade_ordina(data: dict, answer: dict, scope: Any = None) -> dict:
    given = [str(x) for x in _as_list(answer.get('order'))][:MAX_ITEMS]
    ids = [i['id'] for i in data['items']]
    if sorted(given) != sorted(ids):
        return _result(False, 0, {'error': 'incomplete'}, {'order': data['order']})
    candidates = [data['order'], *data.get('accepted_orders', [])]
    best = max(candidates, key=lambda c: _lcs(given, c))
    exact = given in candidates
    positions = [given[i] == best[i] for i in range(len(given))]
    score = 1.0 if exact else _lcs(given, best) / len(best)
    return _result(exact, score, {'positions': positions}, {'order': best})


# --------------------------------------------------------------------- abbina
def _clean_abbina(data: dict) -> dict:
    if isinstance(data.get('pairs'), dict) and isinstance(data.get('left'), list):
        # forma già salvata (left/right/pairs per id): la riporto alla forma di scrittura
        right_text = {str(r.get('id')): r.get('text') for r in data.get('right') or [] if isinstance(r, dict)}
        used = set(data['pairs'].values())
        data = {'pairs': [{'left': l.get('text'), 'right': right_text.get(data['pairs'].get(str(l.get('id'))))}
                          for l in data['left'] if isinstance(l, dict)],
                'distractors': [t for rid, t in right_text.items() if rid not in used]}
    left, right, pairs = [], [], {}
    for raw in _list(data.get('pairs'), 'Coppie', 2, 12):
        if not isinstance(raw, dict):
            raise ValueError('Coppie: ogni coppia ha "left" e "right".')
        left_text = _text(raw.get('left'), 300, name='elemento a sinistra')
        right_text = _text(raw.get('right'), 600, name='elemento a destra')
        # id dal solo testo di ciascun lato: dagli id non si ricava la coppia
        lid, rid = _opaque('l', left_text), _opaque('r', right_text)
        left.append({'id': lid, 'text': left_text})
        right.append({'id': rid, 'text': right_text})
        pairs[lid] = rid
    for extra in _as_list(data.get('distractors'))[:4]:
        text = _text(extra, 600)
        right.append({'id': _opaque('r', text), 'text': text})
    _unique([i['id'] for i in left], 'Elementi a sinistra (testi ripetuti)')
    _unique([i['id'] for i in right], 'Elementi a destra (testi ripetuti)')
    return {'left': left, 'right': right, 'pairs': pairs}


def _public_abbina(data: dict, rng: random.Random) -> dict:
    return {'left': _shuffled(data['left'], rng), 'right': _shuffled(data['right'], rng)}


def _grade_abbina(data: dict, answer: dict, scope: Any = None) -> dict:
    given = answer.get('pairs') if isinstance(answer.get('pairs'), dict) else {}
    result = {lid: str(given.get(lid)) == rid for lid, rid in data['pairs'].items()}
    # la stessa voce a destra usata per più elementi conta una volta sola
    used = [str(v) for v in given.values()]
    for lid in result:
        if result[lid] and used.count(str(given.get(lid))) > 1:
            result[lid] = False
    good = sum(result.values())
    exact = good == len(result)
    return _result(exact, good / len(result), {'pairs': result}, {'pairs': data['pairs']})


# --------------------------------------------------------------------- completa
_BLANK = re.compile(r'\[\[([A-Za-z0-9_-]{1,20})\]\]')


def _clean_completa(data: dict) -> dict:
    text = _text(data.get('text'), MAX_TEXT, name='testo con gli spazi')
    found = _BLANK.findall(text)
    if not found:
        raise ValueError('Segna gli spazi nel testo con [[1]], [[2]]…')
    _unique(found, 'Spazi')
    blanks = {}
    for raw in _list(data.get('blanks'), 'Spazi', 1, 20):
        if not isinstance(raw, dict):
            raise ValueError('Spazi: ogni spazio ha "id" e "accepted".')
        bid = _id(raw.get('id'), 'id dello spazio')
        accepted = [_text(a, 200) for a in _list(raw.get('accepted'), f'Risposte ammesse per [[{bid}]]', 1, 10)]
        blank = {'id': bid, 'accepted': accepted, 'numeric': bool(raw.get('numeric')),
                 'tolerance': abs(float(raw.get('tolerance') or 0))}
        if blank['numeric'] and any(parse_number(a) is None for a in accepted):
            raise ValueError(f'Lo spazio [[{bid}]] è numerico: le risposte ammesse devono essere numeri.')
        blanks[bid] = blank
    if set(found) != set(blanks):
        raise ValueError('Ogni [[spazio]] del testo deve avere le sue risposte, e viceversa.')
    bank = [_text(w, 100) for w in _as_list(data.get('bank'))][:16]
    return {'text': text, 'blanks': [blanks[b] for b in found], 'bank': bank,
            'case_sensitive': bool(data.get('case_sensitive'))}


def _public_completa(data: dict, rng: random.Random) -> dict:
    return {'text': data['text'], 'blanks': [{'id': b['id'], 'numeric': b['numeric']} for b in data['blanks']],
            'bank': _shuffled(data['bank'], rng)}


def _blank_ok(blank: dict, value: Any, case_sensitive: bool) -> bool:
    if blank['numeric']:
        number = parse_number(value)
        return number is not None and any(_within(number, parse_number(a), blank['tolerance']) for a in blank['accepted'])
    given = normalize_answer(value, case_sensitive)
    return bool(given) and given in {normalize_answer(a, case_sensitive) for a in blank['accepted']}


def _grade_completa(data: dict, answer: dict, scope: Any = None) -> dict:
    values = answer.get('values') if isinstance(answer.get('values'), dict) else {}
    result = {b['id']: _blank_ok(b, values.get(b['id']), data['case_sensitive']) for b in data['blanks']}
    good = sum(result.values())
    return _result(good == len(result), good / len(result), {'blanks': result},
                   {'values': {b['id']: b['accepted'][0] for b in data['blanks']}})


# --------------------------------------------------------------------- errore
def _clean_errore(data: dict) -> dict:
    lines = [str(line)[:300] for line in _list(data.get('lines'), 'Righe', 2, 60)]
    try:
        errors = sorted({int(x) for x in _list(data.get('error_lines'), 'Righe con l’errore', 1, 5)})
    except (TypeError, ValueError, OverflowError):
        raise ValueError('Righe con l’errore: servono numeri di riga.')
    if any(not 1 <= e <= len(lines) for e in errors):
        raise ValueError('Le righe con l’errore devono esistere (numerate da 1).')
    reasons = []
    for raw in _as_list(data.get('reasons'))[:6]:
        if not isinstance(raw, dict):
            raise ValueError('Motivi: ogni motivo ha "id" e "text".')
        reasons.append({'id': _id(raw.get('id'), 'id del motivo'), 'text': _text(raw.get('text'), 400)})
    _unique([r['id'] for r in reasons], 'Motivi')
    correct_reason = str(data.get('correct_reason') or '')
    if reasons and correct_reason not in {r['id'] for r in reasons}:
        raise ValueError('Indica quale motivo è quello giusto.')
    remap = {r['id']: _opaque('m', r['text']) for r in reasons}
    if len(set(remap.values())) != len(remap):
        raise ValueError('Motivi: due motivi hanno lo stesso testo.')
    for reason in reasons:
        reason['id'] = remap[reason['id']]
    correct_reason = remap.get(correct_reason, '')
    return {'lines': lines, 'language': _text(data.get('language'), 20, False), 'error_lines': errors,
            'reasons': reasons, 'correct_reason': correct_reason or None,
            'fix': _text(data.get('fix'), 600, False)}


def _public_errore(data: dict, rng: random.Random) -> dict:
    return {'lines': data['lines'], 'language': data['language'], 'reasons': _shuffled(data['reasons'], rng),
            'count': len(data['error_lines'])}


def _grade_errore(data: dict, answer: dict, scope: Any = None) -> dict:
    lines = set()
    for x in _as_list(answer.get('lines'))[:60]:
        try:
            lines.add(int(x))
        except (TypeError, ValueError, OverflowError):
            continue
    expected = set(data['error_lines'])
    line_ok = lines == expected
    reason_ok = data['correct_reason'] is None or str(answer.get('reason') or '') == data['correct_reason']
    # ogni riga segnata in più toglie quanto una giusta: selezionare tutto non paga
    line_score = max(0.0, (len(lines & expected) - len(lines - expected)) / len(expected))
    if data['correct_reason']:
        score = 0.5 * line_score + (0.5 if line_ok and reason_ok else 0.0)
    else:
        score = line_score
    return _result(line_ok and reason_ok, score, {'line_ok': line_ok, 'reason_ok': reason_ok},
                   {'lines': sorted(expected), 'reason': data['correct_reason'], 'fix': data['fix']})


# --------------------------------------------------------------------- diagramma
def _num01(value: Any, name: str) -> float:
    try:
        number = float(value)
    except (TypeError, ValueError):
        raise ValueError(f'{name}: serve un numero tra 0 e 1.')
    if not 0 <= number <= 1:
        raise ValueError(f'{name}: serve un numero tra 0 e 1.')
    return number


def _clean_diagramma(data: dict) -> dict:
    regions = []
    scene = data.get('scene')
    if isinstance(scene, dict):
        nodes = []
        for raw in _list(scene.get('nodes'), 'Elementi del diagramma', 2, 30):
            if not isinstance(raw, dict):
                raise ValueError('Elementi del diagramma non validi.')
            node = {'id': _id(raw.get('id'), 'id dell’elemento'), 'label': _text(raw.get('label'), 60),
                    'x': _num01(raw.get('x'), 'x'), 'y': _num01(raw.get('y'), 'y'),
                    'shape': raw.get('shape') if raw.get('shape') in ('rect', 'circle', 'cloud', 'device') else 'rect',
                    'icon': _text(raw.get('icon'), 30, False)}
            nodes.append(node)
            regions.append({'id': node['id'], 'x': max(0, node['x'] - 0.08), 'y': max(0, node['y'] - 0.08),
                            'w': 0.16, 'h': 0.16})
        _unique([n['id'] for n in nodes], 'Elementi')
        ids = {n['id'] for n in nodes}
        edges = []
        for raw in _as_list(scene.get('edges'))[:60]:
            if isinstance(raw, dict) and raw.get('from') in ids and raw.get('to') in ids:
                edges.append({'from': raw['from'], 'to': raw['to'], 'label': _text(raw.get('label'), 40, False)})
        try:
            ratio = float(scene.get('ratio') or 1.6)
        except (TypeError, ValueError):
            ratio = 1.6
        scene = {'nodes': nodes, 'edges': edges, 'ratio': ratio if 0.3 <= ratio <= 4 else 1.6}
    else:
        scene = None
        for raw in _list(data.get('regions'), 'Zone', 1, 30):
            if not isinstance(raw, dict):
                raise ValueError('Zone non valide.')
            regions.append({'id': _id(raw.get('id'), 'id della zona'), 'x': _num01(raw.get('x'), 'x'),
                            'y': _num01(raw.get('y'), 'y'), 'w': _num01(raw.get('w'), 'larghezza'),
                            'h': _num01(raw.get('h'), 'altezza'), 'label': _text(raw.get('label'), 60, False)})
        if not data.get('image_attachment_id'):
            raise ValueError('Serve un’immagine (allegato) oppure un diagramma disegnato ("scene").')
    _unique([r['id'] for r in regions], 'Zone')
    correct = [str(c) for c in _list(data.get('correct'), 'Zone corrette', 1, len(regions))]
    if not set(correct) <= {r['id'] for r in regions}:
        raise ValueError('Le zone corrette devono esistere.')
    return {'scene': scene, 'image_attachment_id': str(data.get('image_attachment_id') or '') or None,
            'regions': regions, 'correct': sorted(set(correct)), 'multiple': len(set(correct)) > 1 or bool(data.get('multiple')),
            'feedback': {str(k): _text(v, 400, False) for k, v in _as_dict(data.get('feedback')).items()}}


def _public_diagramma(data: dict, rng: random.Random) -> dict:
    # Con un'immagine non si mandano le zone: lo studente tocca un punto e il server decide.
    return {'scene': data['scene'], 'image_attachment_id': data['image_attachment_id'], 'multiple': data['multiple']}


def _hit(regions: list[dict], x: float, y: float) -> str | None:
    for region in regions:
        if region['x'] <= x <= region['x'] + region['w'] and region['y'] <= y <= region['y'] + region['h']:
            return region['id']
    return None


def _grade_diagramma(data: dict, answer: dict, scope: Any = None) -> dict:
    chosen = set()
    valid = {r['id'] for r in data['regions']}
    for rid in _as_list(answer.get('ids'))[:30]:
        if isinstance(rid, (str, int)) and str(rid) in valid:
            chosen.add(str(rid))
    for point in _as_list(answer.get('points'))[:10]:
        try:
            hit = _hit(data['regions'], float(point.get('x')), float(point.get('y')))
        except (TypeError, ValueError, AttributeError, OverflowError):
            hit = None
        if hit:
            chosen.add(hit)
    correct = set(data['correct'])
    exact = chosen == correct
    score = 1.0 if exact else max(0.0, (len(chosen & correct) - len(chosen - correct)) / len(correct))
    notes = {rid: data['feedback'][rid] for rid in chosen | correct if rid in data['feedback']}
    return _result(exact, score, {'chosen': sorted(chosen), 'notes': notes},
                   {'correct': sorted(correct),
                    'regions': [r for r in data['regions'] if r['id'] in correct]})


# --------------------------------------------------------------------- grafo
def _clean_grafo(data: dict) -> dict:
    task = data.get('task') if data.get('task') in ('dijkstra', 'bfs', 'dfs') else None
    if task is None:
        raise ValueError('Compito del grafo: dijkstra, bfs o dfs.')
    nodes = []
    for raw in _list(data.get('nodes'), 'Nodi', 3, 12):
        if not isinstance(raw, dict):
            raise ValueError('Nodi non validi.')
        nodes.append({'id': _id(raw.get('id'), 'id del nodo'), 'label': _text(raw.get('label') or raw.get('id'), 12),
                      'x': _num01(raw.get('x'), 'x'), 'y': _num01(raw.get('y'), 'y')})
    ids = [n['id'] for n in nodes]
    _unique(ids, 'Nodi')
    edges = []
    for raw in _list(data.get('edges'), 'Archi', 2, 40):
        if not isinstance(raw, dict):
            raise ValueError('Archi non validi.')
        a, b = str(raw.get('from')), str(raw.get('to'))
        if a not in ids or b not in ids or a == b:
            raise ValueError('Ogni arco collega due nodi diversi esistenti.')
        weight = raw.get('w', 1)
        try:
            weight = int(weight)
        except (TypeError, ValueError, OverflowError):
            raise ValueError('I pesi degli archi sono interi.')
        if weight < 0 or weight > 999:
            raise ValueError('Pesi tra 0 e 999 (Dijkstra non ammette pesi negativi).')
        edges.append({'from': a, 'to': b, 'w': weight})
    source = str(data.get('source') or ids[0])
    if source not in ids:
        raise ValueError('Il nodo di partenza deve esistere.')
    return {'task': task, 'directed': bool(data.get('directed')), 'nodes': nodes, 'edges': edges, 'source': source,
            'order_neighbors': 'label'}


def _neighbors(data: dict) -> dict[str, list[tuple[str, int]]]:
    result: dict[str, list[tuple[str, int]]] = {n['id']: [] for n in data['nodes']}
    for edge in data['edges']:
        result[edge['from']].append((edge['to'], edge['w']))
        if not data['directed']:
            result[edge['to']].append((edge['from'], edge['w']))
    labels = {n['id']: n['label'] for n in data['nodes']}
    for node in result:
        result[node].sort(key=lambda item: labels[item[0]])
    return result


def _dijkstra_check(data: dict, order: list[str]) -> tuple[int, dict, list[str]]:
    """Quanti passi validi (i pari merito sono tutti validi), distanze, un ordine di riferimento."""
    adjacency = _neighbors(data)
    dist = {n: math.inf for n in adjacency}
    dist[data['source']] = 0
    visited: set[str] = set()
    valid = 0
    for step in order:
        frontier = {n: d for n, d in dist.items() if n not in visited and d < math.inf}
        if not frontier:
            break
        best = min(frontier.values())
        if step not in frontier or frontier[step] != best:
            break
        valid += 1
        visited.add(step)
        for other, weight in adjacency[step]:
            if other not in visited and dist[step] + weight < dist[other]:
                dist[other] = dist[step] + weight
    # riferimento completo
    ref_dist = {n: math.inf for n in adjacency}
    ref_dist[data['source']] = 0
    done: set[str] = set()
    reference = []
    labels = {n['id']: n['label'] for n in data['nodes']}
    while True:
        frontier = {n: d for n, d in ref_dist.items() if n not in done and d < math.inf}
        if not frontier:
            break
        node = min(frontier, key=lambda n: (frontier[n], labels[n]))
        done.add(node)
        reference.append(node)
        for other, weight in adjacency[node]:
            if other not in done and ref_dist[node] + weight < ref_dist[other]:
                ref_dist[other] = ref_dist[node] + weight
    return valid, {k: (None if v == math.inf else v) for k, v in ref_dist.items()}, reference


def _traversal_check(data: dict, order: list[str]) -> tuple[int, list[str]]:
    """BFS/DFS: vale qualsiasi ordine compatibile con la visita (vicini in qualsiasi ordine)."""
    adjacency = _neighbors(data)
    source = data['source']
    if data['task'] == 'bfs':
        valid = 0
        visited = []
        # un ordine BFS è valido se ogni nodo è vicino del primo nodo già visitato che ha vicini non ancora visti
        if order[:1] == [source]:
            valid = 1
            visited = [source]
            seen = {source}
            queue_index = 0
            for step in order[1:]:
                while queue_index < len(visited) and all(o in seen for o, _ in adjacency[visited[queue_index]]):
                    queue_index += 1
                if queue_index >= len(visited):
                    break
                candidates = {o for o, _ in adjacency[visited[queue_index]] if o not in seen}
                if step not in candidates:
                    break
                visited.append(step)
                seen.add(step)
                valid += 1
    else:
        valid = 0
        if order[:1] == [source]:
            valid = 1
            stack = [source]
            seen = {source}
            for step in order[1:]:
                while stack and all(o in seen for o, _ in adjacency[stack[-1]]):
                    stack.pop()
                if not stack:
                    break
                candidates = {o for o, _ in adjacency[stack[-1]] if o not in seen}
                if step not in candidates:
                    break
                stack.append(step)
                seen.add(step)
                valid += 1
    # riferimento (vicini in ordine di etichetta)
    reference, seen = [], {source}
    if data['task'] == 'bfs':
        queue = [source]
        while queue:
            node = queue.pop(0)
            reference.append(node)
            for other, _ in adjacency[node]:
                if other not in seen:
                    seen.add(other)
                    queue.append(other)
    else:
        def visit(node: str):
            reference.append(node)
            for other, _ in adjacency[node]:
                if other not in seen:
                    seen.add(other)
                    visit(other)
        visit(source)
    return valid, reference


def _reachable(data: dict) -> int:
    adjacency = _neighbors(data)
    seen, todo = {data['source']}, [data['source']]
    while todo:
        for other, _ in adjacency[todo.pop()]:
            if other not in seen:
                seen.add(other)
                todo.append(other)
    return len(seen)


def _public_grafo(data: dict, rng: random.Random) -> dict:
    return {'task': data['task'], 'directed': data['directed'], 'nodes': data['nodes'], 'edges': data['edges'],
            'source': data['source']}


def _grade_grafo(data: dict, answer: dict, scope: Any = None) -> dict:
    order = [str(x) for x in _as_list(answer.get('order'))[:40] if isinstance(x, (str, int))]
    total = _reachable(data)
    if data['task'] == 'dijkstra':
        valid, dist, reference = _dijkstra_check(data, order)
        solution = {'order': reference, 'distances': dist}
    else:
        valid, reference = _traversal_check(data, order)
        solution = {'order': reference}
    exact = valid == total and len(order) == total
    return _result(exact, valid / total, {'valid_steps': valid, 'total': total}, solution)


# --------------------------------------------------------------------- flashcard
def _clean_flashcard(data: dict) -> dict:
    return {'front': _text(data.get('front'), 600, name='fronte'), 'back': _text(data.get('back'), 2000, name='retro')}


def _public_flashcard(data: dict, rng: random.Random) -> dict:
    # Il retro è parte della scheda: l'autovalutazione non ha una soluzione da nascondere.
    return {'front': data['front'], 'back': data['back']}


def _grade_flashcard(data: dict, answer: dict, scope: Any = None) -> dict:
    # Autovalutazione: serve solo alla ripetizione dilazionata, non dà punti.
    try:
        grade = max(0, min(3, int(answer.get('grade'))))
    except (TypeError, ValueError, OverflowError):
        grade = 0
    return _result(False, 0, {'grade': grade, 'self_assessed': True}, {'back': data['back']})


# --------------------------------------------------------------------- traccia
def _clean_traccia(data: dict) -> dict:
    columns = [_text(c, 60) for c in _list(data.get('columns'), 'Colonne', 1, 8)]
    rows = []
    blanks = 0
    for raw_row in _list(data.get('rows'), 'Righe', 1, 30):
        if not isinstance(raw_row, list) or len(raw_row) != len(columns):
            raise ValueError('Ogni riga deve avere una cella per colonna.')
        row = []
        for cell in raw_row:
            if isinstance(cell, dict) and cell.get('blank'):
                accepted = [_text(a, 120) for a in _list(cell.get('accepted'), 'Valori ammessi', 1, 8)]
                options = [_text(o, 120) for o in _as_list(cell.get('options'))][:8]
                row.append({'blank': True, 'accepted': accepted, 'options': options})
                blanks += 1
            else:
                row.append(_text(cell, 120, False))
        rows.append(row)
    if not blanks:
        raise ValueError('Lascia almeno una cella da completare ({"blank": true, "accepted": [...]}).')
    return {'columns': columns, 'rows': rows, 'row_by_row': bool(data.get('row_by_row', True))}


def _public_traccia(data: dict, rng: random.Random) -> dict:
    rows = []
    for row in data['rows']:
        rows.append([{'blank': True, 'options': _shuffled(c['options'], rng)} if isinstance(c, dict) else c for c in row])
    return {'columns': data['columns'], 'rows': rows, 'row_by_row': data['row_by_row']}


def _grade_traccia(data: dict, answer: dict, scope: Any = None) -> dict:
    cells = answer.get('cells') if isinstance(answer.get('cells'), dict) else {}
    only_row = None
    if isinstance(scope, dict) and 'row' in scope:
        try:
            only_row = int(scope['row'])
        except (TypeError, ValueError, OverflowError):
            only_row = None
    result, good, total, solution = {}, 0, 0, {}
    for r, row in enumerate(data['rows']):
        if only_row is not None and r != only_row:
            continue
        for c, cell in enumerate(row):
            if not isinstance(cell, dict):
                continue
            key = f'{r},{c}'
            value = cells.get(key)
            ok = isinstance(value, (str, int, float)) and normalize_answer(value) in {normalize_answer(a) for a in cell['accepted']}
            result[key] = ok
            solution[key] = cell['accepted'][0]
            good += ok
            total += 1
    if not total:
        return _result(False, 0, {'cells': {}}, None)
    # Controllo di una riga: la soluzione si rivela solo per le celle già giuste.
    if only_row is not None:
        solution = {k: v for k, v in solution.items() if result[k]}
    return _result(good == total, good / total, {'cells': result}, {'cells': solution})


# --------------------------------------------------------------------- numerica
def _clean_numerica(data: dict) -> dict:
    steps = []
    raw_steps = data.get('steps') or [{'id': 'r', 'label': data.get('label') or 'Risultato', 'answer': data.get('answer'),
                                       'tolerance': data.get('tolerance'), 'tolerance_pct': data.get('tolerance_pct'),
                                       'unit': data.get('unit')}]
    for raw in _list(raw_steps, 'Passaggi', 1, 8):
        if not isinstance(raw, dict):
            raise ValueError('Passaggi non validi.')
        answer = parse_number(raw.get('answer'))
        if answer is None:
            raise ValueError('Ogni passaggio ha una risposta numerica.')
        steps.append({'id': _id(raw.get('id'), 'id del passaggio'), 'label': _text(raw.get('label'), 200),
                      'answer': answer, 'tolerance': abs(float(raw.get('tolerance') or 0)),
                      'tolerance_pct': abs(float(raw.get('tolerance_pct') or 0)), 'unit': _text(raw.get('unit'), 20, False),
                      'hint': _text(raw.get('hint'), 300, False), 'check': _text(raw.get('check'), 300, False)})
    _unique([s['id'] for s in steps], 'Passaggi')
    return {'steps': steps}


def _public_numerica(data: dict, rng: random.Random) -> dict:
    return {'steps': [{'id': s['id'], 'label': s['label'], 'unit': s['unit']} for s in data['steps']]}


def _fmt(number: float) -> str:
    return str(int(number)) if float(number).is_integer() else f'{number:.6g}'


def _grade_numerica(data: dict, answer: dict, scope: Any = None) -> dict:
    values = answer.get('values') if isinstance(answer.get('values'), dict) else {}
    result, checks = {}, {}
    for step in data['steps']:
        number = parse_number(values.get(step['id']))
        ok = number is not None and _within(number, step['answer'], step['tolerance'], step['tolerance_pct'])
        result[step['id']] = ok
        if ok and step['check']:
            checks[step['id']] = step['check']
    good = sum(result.values())
    return _result(good == len(result), good / len(result), {'steps': result, 'checks': checks},
                   {'values': {s['id']: _fmt(s['answer']) for s in data['steps']}})


# --------------------------------------------------------------------- codice
_CALL = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*\(.*\)$', re.S)


def _clean_codice(data: dict) -> dict:
    language = data.get('language') if data.get('language') in ('python',) else None
    if language is None:
        raise ValueError('Linguaggio supportato: python.')
    function = _id(data.get('function'), 'nome della funzione')
    tests = []
    for raw in _list(data.get('tests'), 'Test', 1, 20):
        if not isinstance(raw, dict):
            raise ValueError('Test non validi.')
        call = _text(raw.get('call'), 400, name='chiamata del test')
        if not _CALL.match(call) or not call.startswith(function + '('):
            raise ValueError(f'Ogni test chiama {function}(...).')
        tests.append({'call': call, 'expected': _text(raw.get('expected'), 400, name='risultato atteso'),
                      'hidden': bool(raw.get('hidden'))})
    if all(t['hidden'] for t in tests):
        raise ValueError('Lascia almeno un test visibile allo studente.')
    return {'language': language, 'function': function, 'starter': _text(data.get('starter'), 4000, False),
            'tests': tests, 'time_limit_ms': max(500, min(5000, _int(data.get('time_limit_ms'), 3000))),
            'forbidden': [_text(f, 40) for f in _as_list(data.get('forbidden'))][:10]}


def _int(value: Any, default: int) -> int:
    try:
        return int(value)
    except (TypeError, ValueError, OverflowError):
        return default


def _public_codice(data: dict, rng: random.Random) -> dict:
    return {'language': data['language'], 'function': data['function'], 'starter': data['starter'],
            'tests': [{'call': t['call'], 'expected': t['expected']} for t in data['tests'] if not t['hidden']],
            'hidden_tests': sum(1 for t in data['tests'] if t['hidden']), 'forbidden': data['forbidden']}


def _grade_codice(data: dict, answer: dict, scope: Any = None) -> dict:
    """Il codice non si esegue qui: arriva già l'esito dal servizio isolato
    (services/code_runner.py), che lo mette in answer['_run']."""
    run = answer.get('_run') if isinstance(answer.get('_run'), dict) else None
    if run is None:
        return _result(False, 0, {'error': 'not_run'}, None)
    results = [r for r in _as_list(run.get('results')) if isinstance(r, dict)]
    good = sum(1 for r in results if r.get('ok'))
    total = len(data['tests'])
    visible = [r for r in results if not r.get('hidden')]
    feedback = {'tests': visible, 'hidden_passed': sum(1 for r in results if r.get('hidden') and r.get('ok')),
                'hidden_total': sum(1 for t in data['tests'] if t['hidden']), 'error': run.get('error')}
    return _result(good == total, good / total if total else 0, feedback, None)



# ===================================================================== tipi generici (v24)
def _bool(value: Any, name: str) -> bool:
    if isinstance(value, bool):
        return value
    text = normalize_answer(value)
    if text in ('true', 'vero', 'v', '1', 'si', 'sì', 'yes'):
        return True
    if text in ('false', 'falso', 'f', '0', 'no'):
        return False
    raise ValueError(f'{name}: scrivi vero o falso.')


def _weight(value: Any) -> int:
    try:
        number = int(value if value not in (None, '') else 1)
    except (TypeError, ValueError):
        raise ValueError('Peso del passo: usa un numero da 1 a 5.') from None
    return max(1, min(5, number))


def _pick(value: Any, options: list[tuple[str, str]], name: str) -> str:
    """Ritrova un elemento scritto dal docente come id, posizione (0, 1, …) o testo."""
    if isinstance(value, bool):
        raise ValueError(f'{name} non valido.')
    if isinstance(value, int) and 0 <= value < len(options):
        return options[value][0]
    text = str(value if value is not None else '').strip()
    # prima il testo della voce (una categoria può chiamarsi "1"), poi l'id, poi la posizione
    for key, label in options:
        if text and normalize_answer(text) == normalize_answer(label):
            return key
    for key, label in options:
        if text == key:
            return key
    if text.isdigit() and int(text) < len(options):
        return options[int(text)][0]
    raise ValueError(f'{name}: non corrisponde a nessuna delle voci.')


# --------------------------------------------------------------------- caso pratico a passi
def _clean_caso_step(raw: dict, index: int) -> dict:
    if not isinstance(raw, dict):
        raise ValueError('Passi: ogni passo è un oggetto.')
    kind = raw.get('kind') or ('numerica' if raw.get('answer') not in (None, '') and not raw.get('options') else 'scelta')
    if kind not in ('scelta', 'numerica'):
        raise ValueError('Passi: il tipo del passo è "scelta" o "numerica".')
    step = {'id': _id(raw.get('id') or f's{index + 1}', 'id del passo'), 'kind': kind,
            'prompt': _text(raw.get('prompt'), 1000, name='domanda del passo'),
            'weight': _weight(raw.get('weight')), 'note': _text(raw.get('note'), 1500, False)}
    if kind == 'scelta':
        raw = dict(raw)
        options = _as_list(raw.get('options'))
        if options and all(isinstance(o, str) for o in options):
            # forma breve: risposte come testi e risposte giuste come posizioni (0, 1, …) o testi
            raw['options'] = [{'id': f'o{i}', 'text': o} for i, o in enumerate(options)]
            pairs = [(f'o{i}', o) for i, o in enumerate(options)]
            correct = raw.get('correct')
            correct = correct if isinstance(correct, list) else [correct]
            raw['correct'] = [_pick(c, pairs, 'Risposta giusta del passo') for c in correct if c is not None]
        step.update(_clean_scelta(raw))
    else:
        answer = parse_number(raw.get('answer'))
        if answer is None:
            raise ValueError(f'Passo {index + 1}: serve la risposta numerica.')
        step.update({'answer': answer, 'tolerance': abs(float(raw.get('tolerance') or 0)),
                     'tolerance_pct': abs(float(raw.get('tolerance_pct') or 0)),
                     'unit': _text(raw.get('unit'), 20, False)})
    return step


def _clean_caso(data: dict) -> dict:
    steps = [_clean_caso_step(raw, i) for i, raw in enumerate(_list(data.get('steps'), 'Passi', 1, 8))]
    _unique([s['id'] for s in steps], 'Passi')
    return {'scenario': _text(data.get('scenario'), 3000, name='il caso'), 'steps': steps}


def _public_caso(data: dict, rng: random.Random) -> dict:
    steps = []
    for step in data['steps']:
        public = {'id': step['id'], 'kind': step['kind'], 'prompt': step['prompt'], 'weight': step['weight']}
        if step['kind'] == 'scelta':
            public.update(_public_scelta(step, rng))
        else:
            public['unit'] = step['unit']
        steps.append(public)
    return {'scenario': data['scenario'], 'steps': steps}


def _grade_caso_step(step: dict, answer: Any) -> tuple[bool, float]:
    answer = _as_dict(answer)
    if step['kind'] == 'scelta':
        result = _grade_scelta(step, answer)
        return result['is_correct'], result['score']
    number = parse_number(answer.get('value'))
    ok = number is not None and _within(number, step['answer'], step['tolerance'], step['tolerance_pct'])
    return ok, 1.0 if ok else 0.0


def _caso_solution(step: dict) -> dict:
    if step['kind'] == 'scelta':
        return {'correct': list(step['correct'])}
    return {'value': _fmt(step['answer']), 'unit': step['unit']}


def _grade_caso(data: dict, answer: dict, scope: Any = None) -> dict:
    given = _as_dict(answer.get('steps'))
    target = str(_as_dict(scope).get('step') or '') if scope else ''
    if target:
        # controllo di un solo passo (esercitazione): dice se è giusto, non qual è la risposta
        step = next((s for s in data['steps'] if s['id'] == target), None)
        if step is None:
            return _result(False, 0, {'error': 'unknown_step'}, None)
        ok, score = _grade_caso_step(step, given.get(step['id']))
        return _result(ok, score, {'steps': {step['id']: ok}}, None)
    oks, scores, notes = {}, {}, {}
    total = weighted = 0.0
    for step in data['steps']:
        ok, score = _grade_caso_step(step, given.get(step['id']))
        oks[step['id']], scores[step['id']] = ok, round(score, 4)
        if step['note']:
            notes[step['id']] = step['note']
        total += step['weight']
        weighted += step['weight'] * score
    return _result(all(oks.values()), weighted / total if total else 0,
                   {'steps': oks, 'scores': scores, 'notes': notes},
                   {'steps': {s['id']: _caso_solution(s) for s in data['steps']}})


# --------------------------------------------------------------------- vero o falso motivato
def _clean_vero_falso(data: dict) -> dict:
    claims = []
    for raw in _list(data.get('claims'), 'Affermazioni', 1, 10):
        if not isinstance(raw, dict):
            raise ValueError('Affermazioni: ogni affermazione ha "text" e "value".')
        text = _text(raw.get('text'), 800, name='affermazione')
        reasons_in = []
        for i, reason in enumerate(_as_list(raw.get('reasons'))[:5]):
            if isinstance(reason, dict):
                reasons_in.append((str(reason.get('id') or i), _text(reason.get('text'), 400, name='motivo')))
            else:
                reasons_in.append((str(i), _text(reason, 400, name='motivo')))
        if len(reasons_in) == 1:
            raise ValueError('Motivi: scrivine almeno 2 (o nessuno).')
        claim = {'id': _opaque('c', text), 'text': text, 'value': _bool(raw.get('value'), 'Vero o falso'),
                 'explanation': _text(raw.get('explanation'), 1500, False), 'reasons': [], 'correct_reason': None}
        if reasons_in:
            correct = _pick(raw.get('correct_reason'), reasons_in, 'Motivo corretto')
            remap = {key: _opaque('m', text, label) for key, label in reasons_in}
            if len(set(remap.values())) != len(remap):
                raise ValueError('Motivi: due motivi sono identici.')
            claim['reasons'] = [{'id': remap[key], 'text': label} for key, label in reasons_in]
            claim['correct_reason'] = remap[correct]
        claims.append(claim)
    _unique([c['id'] for c in claims], 'Affermazioni (testi ripetuti)')
    return {'claims': claims}


def _public_vero_falso(data: dict, rng: random.Random) -> dict:
    return {'claims': [{'id': c['id'], 'text': c['text'], 'reasons': _shuffled(c['reasons'], rng)}
                       for c in data['claims']]}


def _grade_vero_falso(data: dict, answer: dict, scope: Any = None) -> dict:
    given = _as_dict(answer.get('answers'))
    marks, explanations, total = {}, {}, 0.0
    for claim in data['claims']:
        mine = _as_dict(given.get(claim['id']))
        value = mine.get('value')
        value_ok = isinstance(value, bool) and value == claim['value']
        reason_ok = None
        if claim['reasons']:
            reason_ok = value_ok and str(mine.get('reason') or '') == claim['correct_reason']
            total += (0.5 if value_ok else 0) + (0.5 if reason_ok else 0)
        else:
            total += 1.0 if value_ok else 0
        marks[claim['id']] = {'value': value_ok, 'reason': reason_ok}
        if claim['explanation']:
            explanations[claim['id']] = claim['explanation']
    exact = all(m['value'] and m['reason'] is not False for m in marks.values())
    return _result(exact, total / len(data['claims']), {'claims': marks, 'explanations': explanations},
                   {'claims': {c['id']: {'value': c['value'], 'reason': c['correct_reason']} for c in data['claims']}})


# --------------------------------------------------------------------- categorizza
def _clean_categorizza(data: dict) -> dict:
    if isinstance(data.get('placement'), dict) and isinstance(data.get('items'), list):
        # forma già salvata: la riporto alla forma di scrittura
        data = {'categories': [c for c in _as_list(data.get('categories')) if isinstance(c, dict)],
                'items': [{'text': i.get('text'), 'category': str(data['placement'].get(str(i.get('id'))) or '')}
                          for i in data['items'] if isinstance(i, dict)]}
    categories_in = []
    for i, raw in enumerate(_list(data.get('categories'), 'Categorie', 2, 6)):
        label = raw.get('text') if isinstance(raw, dict) else raw
        key = str(raw.get('id') or i) if isinstance(raw, dict) else str(i)
        categories_in.append((key, _text(label, 120, name='categoria')))
    categories = [{'id': _opaque('k', label), 'text': label} for _, label in categories_in]
    _unique([c['id'] for c in categories], 'Categorie (nomi ripetuti)')
    by_key = {key: _opaque('k', label) for key, label in categories_in}
    items, placement = [], {}
    for raw in _list(data.get('items'), 'Elementi', 2, 24):
        if not isinstance(raw, dict):
            raise ValueError('Elementi: ogni elemento ha "text" e "category".')
        text = _text(raw.get('text'), 300, name='elemento')
        item_id = _opaque('i', text)
        items.append({'id': item_id, 'text': text})
        placement[item_id] = by_key[_pick(raw.get('category'), categories_in, f'Categoria di “{text[:40]}”')]
    _unique([i['id'] for i in items], 'Elementi (testi ripetuti)')
    return {'categories': categories, 'items': items, 'placement': placement}


def _public_categorizza(data: dict, rng: random.Random) -> dict:
    return {'categories': data['categories'], 'items': _shuffled(data['items'], rng)}


def _grade_categorizza(data: dict, answer: dict, scope: Any = None) -> dict:
    given = _as_dict(answer.get('placement'))
    marks = {item_id: str(given.get(item_id) or '') == cat for item_id, cat in data['placement'].items()}
    good = sum(marks.values())
    return _result(good == len(marks), good / len(marks), {'items': marks}, {'placement': dict(data['placement'])})


# --------------------------------------------------------------------- linea del tempo
def _clean_linea_tempo(data: dict) -> dict:
    events = []
    for raw in _list(data.get('events'), 'Eventi', 3, 12):   # con 2 eventi il mescolamento direbbe l'ordine
        if isinstance(raw, str):
            raw = {'text': raw}
        if not isinstance(raw, dict):
            raise ValueError('Eventi: ogni evento ha "text" e, se vuoi, "date".')
        text = _text(raw.get('text'), 400, name='evento')
        events.append({'id': _opaque('e', text), 'text': text, 'date': _text(raw.get('date'), 60, False)})
    _unique([e['id'] for e in events], 'Eventi (testi ripetuti)')
    # l'ordine giusto è quello in cui il docente li scrive (dal primo all'ultimo)
    return {'events': events, 'order': [e['id'] for e in events]}


def _public_linea_tempo(data: dict, rng: random.Random) -> dict:
    events = [{'id': e['id'], 'text': e['text']} for e in _shuffled(data['events'], rng)]
    if [e['id'] for e in events] == data['order']:
        events = events[1:] + events[:1]
    return {'events': events}


def _grade_linea_tempo(data: dict, answer: dict, scope: Any = None) -> dict:
    given = [str(x) for x in _as_list(answer.get('order'))][:MAX_ITEMS]
    ids = data['order']
    dates = {e['id']: e['date'] for e in data['events'] if e['date']}
    if sorted(given) != sorted(ids):
        return _result(False, 0, {'error': 'incomplete'}, {'order': ids, 'dates': dates})
    positions = [given[i] == ids[i] for i in range(len(ids))]
    exact = given == ids
    return _result(exact, 1.0 if exact else _lcs(given, ids) / len(ids), {'positions': positions},
                   {'order': ids, 'dates': dates})


# --------------------------------------------------------------------- risposta breve con griglia
def _fold(value: Any) -> str:
    text = unicodedata.normalize('NFKD', normalize_answer(value))
    return ''.join(ch for ch in text if not unicodedata.combining(ch))


def _keywords(value: Any) -> list[str]:
    raw = value if isinstance(value, list) else re.split(r'[,;\n]', str(value or ''))
    result = []
    for word in raw:
        word = _text(word, 80, False)
        if word and word not in result:
            result.append(word)
    return result[:10]


def _clean_risposta_breve(data: dict) -> dict:
    criteria = []
    for raw in _list(data.get('criteria'), 'Griglia', 1, 6):
        if not isinstance(raw, dict):
            raise ValueError('Griglia: ogni punto ha "text", "points" e "keywords".')
        text = _text(raw.get('text'), 300, name='punto della griglia')
        keywords = _keywords(raw.get('keywords'))
        if not keywords:
            raise ValueError(f'Griglia: “{text[:40]}” ha bisogno di almeno una parola chiave.')
        criteria.append({'id': _opaque('g', text), 'text': text, 'points': _weight(raw.get('points')),
                         'keywords': keywords, 'min_matches': max(1, min(len(keywords), int(raw.get('min_matches') or 1)))})
    _unique([c['id'] for c in criteria], 'Griglia (punti ripetuti)')
    max_chars = max(80, min(2000, int(data.get('max_chars') or 600)))
    min_chars = max(0, min(max_chars, int(data.get('min_chars') or 40)))
    return {'model_answer': _text(data.get('model_answer'), 2000, name='la risposta modello'),
            'criteria': criteria, 'min_chars': min_chars, 'max_chars': max_chars}


def _public_risposta_breve(data: dict, rng: random.Random) -> dict:
    return {'criteria': [{'id': c['id'], 'text': c['text'], 'points': c['points']} for c in data['criteria']],
            'min_chars': data['min_chars'], 'max_chars': data['max_chars']}


def _keyword_found(text: str, keyword: str) -> bool:
    # "filtr" trova anche "filtrazione": la parola chiave vale come inizio di parola
    return re.search(r'(?<![\w])' + re.escape(_fold(keyword)), text) is not None


def _grade_risposta_breve(data: dict, answer: dict, scope: Any = None) -> dict:
    raw = str(answer.get('text') or '')[:data['max_chars'] + 200]
    text = _fold(raw)
    solution = {'model_answer': data['model_answer'],
                'criteria': {c['id']: c['keywords'] for c in data['criteria']}}
    if len(text.strip()) < data['min_chars']:
        return _result(False, 0, {'error': 'too_short', 'length': len(raw.strip())}, solution)
    marks, points, total = {}, 0, 0
    for criterion in data['criteria']:
        found = sum(1 for k in criterion['keywords'] if _keyword_found(text, k))
        marks[criterion['id']] = found >= criterion['min_matches']
        total += criterion['points']
        points += criterion['points'] if marks[criterion['id']] else 0
    # correzione automatica indicativa (parole chiave); l'autovalutazione resta nell'app
    return _result(all(marks.values()), points / total if total else 0,
                   {'criteria': marks, 'length': len(raw.strip()), 'automatic': True}, solution)


# --------------------------------------------------------------------- registro
Handlers = tuple[Callable[[dict], dict], Callable[[dict, random.Random], dict], Callable[..., dict]]
HANDLERS: dict[str, Handlers] = {
    'scelta': (_clean_scelta, _public_scelta, _grade_scelta),
    'ordina': (_clean_ordina, _public_ordina, _grade_ordina),
    'abbina': (_clean_abbina, _public_abbina, _grade_abbina),
    'completa': (_clean_completa, _public_completa, _grade_completa),
    'errore': (_clean_errore, _public_errore, _grade_errore),
    'diagramma': (_clean_diagramma, _public_diagramma, _grade_diagramma),
    'grafo': (_clean_grafo, _public_grafo, _grade_grafo),
    'flashcard': (_clean_flashcard, _public_flashcard, _grade_flashcard),
    'traccia': (_clean_traccia, _public_traccia, _grade_traccia),
    'numerica': (_clean_numerica, _public_numerica, _grade_numerica),
    'codice': (_clean_codice, _public_codice, _grade_codice),
    'caso': (_clean_caso, _public_caso, _grade_caso),
    'vero_falso': (_clean_vero_falso, _public_vero_falso, _grade_vero_falso),
    'categorizza': (_clean_categorizza, _public_categorizza, _grade_categorizza),
    'linea_tempo': (_clean_linea_tempo, _public_linea_tempo, _grade_linea_tempo),
    'risposta_breve': (_clean_risposta_breve, _public_risposta_breve, _grade_risposta_breve),
}


def clean_data(kind: str, data: Any) -> dict:
    if kind not in HANDLERS:
        raise ValueError('Tipo di esercizio non valido.')
    if not isinstance(data, dict):
        raise ValueError('Dati dell’esercizio non validi.')
    try:
        return HANDLERS[kind][0](data)
    except ValueError:
        raise
    except (TypeError, AttributeError, KeyError, OverflowError) as exc:
        raise ValueError('Dati dell’esercizio non validi: controlla il formato.') from exc


def public_data(kind: str, data: dict, rng: random.Random | None = None) -> dict:
    return HANDLERS[kind][1](data, rng or random.Random())


def grade(kind: str, data: dict, answer: Any, scope: Any = None) -> dict:
    if not isinstance(answer, dict):
        answer = {}
    try:
        return HANDLERS[kind][2](data, answer, scope)
    except (TypeError, ValueError, AttributeError, KeyError, OverflowError, RecursionError):
        # Una risposta malformata vale 0: non deve bloccare la consegna del tentativo.
        return _result(False, 0, {'error': 'invalid_answer'}, None)


def solution_summary(kind: str, data: dict) -> str:
    """Soluzione in testo semplice, per il Ripasso e per chi non ha l'app aggiornata."""
    if kind == 'scelta':
        texts = {o['id']: o['text'] or '(immagine)' for o in data['options']}
        return ' · '.join(texts[c] for c in data['correct'])
    if kind == 'ordina':
        texts = {i['id']: i['text'] for i in data['items']}
        return '\n'.join(f'{n}. {texts[i]}' for n, i in enumerate(data['order'], 1))
    if kind == 'abbina':
        left = {i['id']: i['text'] for i in data['left']}
        right = {i['id']: i['text'] for i in data['right']}
        return '\n'.join(f'{left[l]} → {right[r]}' for l, r in data['pairs'].items())
    if kind == 'completa':
        values = {b['id']: b['accepted'][0] for b in data['blanks']}
        return _BLANK.sub(lambda m: values.get(m.group(1), '…'), data['text'])
    if kind == 'errore':
        lines = ', '.join(str(x) for x in data['error_lines'])
        reason = next((r['text'] for r in data['reasons'] if r['id'] == data['correct_reason']), '')
        return f'Riga {lines}' + (f': {reason}' if reason else '') + (f'\nCorrezione: {data["fix"]}' if data['fix'] else '')
    if kind == 'diagramma':
        labels = {n['id']: n['label'] for n in (data['scene'] or {}).get('nodes', [])}
        labels.update({r['id']: r.get('label') or r['id'] for r in data['regions'] if r.get('label')})
        return ', '.join(labels.get(c, c) for c in data['correct'])
    if kind == 'grafo':
        solution = grade('grafo', data, {'order': []})['correct_payload']
        labels = {n['id']: n['label'] for n in data['nodes']}
        return 'Un ordine corretto: ' + ' → '.join(labels[n] for n in solution['order'])
    if kind == 'flashcard':
        return data['back']
    if kind == 'traccia':
        parts = []
        for r, row in enumerate(data['rows']):
            for c, cell in enumerate(row):
                if isinstance(cell, dict):
                    parts.append(f'riga {r + 1}, {data["columns"][c]}: {cell["accepted"][0]}')
        return '\n'.join(parts)
    if kind == 'numerica':
        return '\n'.join(f'{s["label"]}: {_fmt(s["answer"])}{(" " + s["unit"]) if s["unit"] else ""}' for s in data['steps'])
    if kind == 'codice':
        return 'Esercizio di programmazione: soluzione verificata dai test.'
    if kind == 'caso':
        parts = []
        for n, step in enumerate(data['steps'], 1):
            if step['kind'] == 'scelta':
                texts = {o['id']: o['text'] or '(immagine)' for o in step['options']}
                value = ' · '.join(texts[c] for c in step['correct'])
            else:
                value = _fmt(step['answer']) + (f' {step["unit"]}' if step['unit'] else '')
            parts.append(f'{n}. {step["prompt"]} → {value}')
        return '\n'.join(parts)
    if kind == 'vero_falso':
        parts = []
        for claim in data['claims']:
            reason = next((r['text'] for r in claim['reasons'] if r['id'] == claim['correct_reason']), '')
            parts.append(f'{"VERO" if claim["value"] else "FALSO"} · {claim["text"]}' + (f' — {reason}' if reason else ''))
        return '\n'.join(parts)
    if kind == 'categorizza':
        names = {c['id']: c['text'] for c in data['categories']}
        groups: dict[str, list[str]] = {}
        for item in data['items']:
            groups.setdefault(data['placement'][item['id']], []).append(item['text'])
        return '\n'.join(f'{names[k]}: {", ".join(v)}' for k, v in groups.items())
    if kind == 'linea_tempo':
        return '\n'.join(f'{n}. ' + (f'{e["date"]} · ' if e['date'] else '') + e['text']
                         for n, e in enumerate(data['events'], 1))
    if kind == 'risposta_breve':
        return data['model_answer']
    return ''
