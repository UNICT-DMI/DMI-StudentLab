"""Test dei nuovi tipi di esercizio (logica pura: nessun database).

    cd BE && python -m pytest tests/test_exercises.py -q
"""
import random

import pytest

from services import exercise_types as T
from services.exercise_generators import generate


def _solve(kind, data):
    solution = T.grade(kind, data, {})['correct_payload']
    return {'grafo': lambda: {'order': solution['order']}, 'numerica': lambda: {'values': solution['values']},
            'traccia': lambda: {'cells': solution['cells']}}[kind]()


@pytest.mark.parametrize('name', ['dijkstra', 'bfs', 'dfs', 'subnet', 'bubble', 'base_conversion'])
def test_generated_exercises_are_solvable_and_reproducible(name):
    for seed in range(60):
        template = {'id_exercise': '7', 'generator': {'name': name, 'difficulty': 1 + seed % 3}}
        first, second = generate(template, seed), generate(template, seed)
        assert first == second                                   # stesso seme, stesso esercizio
        data = T.clean_data(first['type'], first['data'])
        result = T.grade(first['type'], data, _solve(first['type'], data))
        assert result['is_correct'] and result['score'] == 1


def test_dijkstra_accepts_ties_and_rejects_wrong_order():
    data = T.clean_data('grafo', {'task': 'dijkstra', 'source': 'u',
                                  'nodes': [{'id': n, 'x': 0.2 * i, 'y': 0.5} for i, n in enumerate('uvwx', 1)],
                                  'edges': [{'from': 'u', 'to': 'v', 'w': 2}, {'from': 'u', 'to': 'w', 'w': 2},
                                            {'from': 'v', 'to': 'x', 'w': 1}, {'from': 'w', 'to': 'x', 'w': 5}]})
    assert T.grade('grafo', data, {'order': ['u', 'v', 'w', 'x']})['is_correct']
    assert T.grade('grafo', data, {'order': ['u', 'w', 'v', 'x']})['is_correct']
    wrong = T.grade('grafo', data, {'order': ['u', 'x', 'v', 'w']})
    assert not wrong['is_correct'] and wrong['score'] == 0.25


def test_public_data_never_contains_the_solution():
    ordina = T.clean_data('ordina', {'items': ['a', 'b', 'c']})
    assert 'order' not in T.public_data('ordina', ordina, random.Random(1))
    abbina = T.clean_data('abbina', {'pairs': [{'left': 'TCP', 'right': 'x'}, {'left': 'UDP', 'right': 'y'}]})
    assert 'pairs' not in T.public_data('abbina', abbina)
    completa = T.clean_data('completa', {'text': 'a [[1]]', 'blanks': [{'id': '1', 'accepted': ['b']}]})
    assert 'accepted' not in str(T.public_data('completa', completa))
    diagram = T.clean_data('diagramma', {'regions': [{'id': 'r', 'x': 0, 'y': 0, 'w': .5, 'h': .5}],
                                         'correct': ['r'], 'image_attachment_id': 'img001'})
    assert 'regions' not in T.public_data('diagramma', diagram)
    code = T.clean_data('codice', {'language': 'python', 'function': 'f',
                                   'tests': [{'call': 'f(1)', 'expected': '1'},
                                             {'call': 'f(2)', 'expected': '2', 'hidden': True}]})
    public = T.public_data('codice', code)
    assert len(public['tests']) == 1 and public['hidden_tests'] == 1


def test_partial_scores_and_normalization():
    completa = T.clean_data('completa', {'text': '[[1]] e [[2]]', 'blanks': [
        {'id': '1', 'accepted': ['6'], 'numeric': True}, {'id': '2', 'accepted': ['Attesa circolare']}]})
    result = T.grade('completa', completa, {'values': {'1': '6,0', '2': '  attesa   CIRCOLARE '}})
    assert result['is_correct']
    scelta = T.clean_data('scelta', {'options': [{'id': 'A', 'text': 'x'}, {'id': 'B', 'text': 'y'},
                                                 {'id': 'C', 'text': 'z'}], 'correct': ['A', 'C']})
    ids = {o['text']: o['id'] for o in scelta['options']}          # id opachi
    assert T.grade('scelta', scelta, {'selected': [ids['x']]})['score'] == 0.5
    assert T.grade('scelta', scelta, {'selected': [ids['x'], ids['y']]})['score'] == 0.0


def test_public_ids_do_not_reveal_the_solution():
    import random
    abbina = T.clean_data('abbina', {'pairs': [{'left': f'L{i}', 'right': f'R{i}'} for i in range(4)]})
    public = T.public_data('abbina', abbina, random.Random(1))
    lefts = sorted(i['id'] for i in public['left'])
    rights = sorted(i['id'] for i in public['right'])
    guess = dict(zip(lefts, rights))                                 # "l1 con r1" non funziona più
    assert T.grade('abbina', abbina, {'pairs': guess})['score'] < 1
    ordina = T.clean_data('ordina', {'items': ['primo', 'secondo', 'terzo', 'quarto']})
    ids = sorted(i['id'] for i in T.public_data('ordina', ordina, random.Random(1))['items'])
    assert ids != ordina['order']
    scelta = T.clean_data('scelta', {'options': [{'id': 'a', 'text': 'giusta'}, {'id': 'b', 'text': 'no'}],
                                     'correct': ['a']})
    assert scelta['correct'] != ['a']
    # ripulire di nuovo dati già salvati non cambia gli id (le risposte salvate restano valide)
    assert T.clean_data('abbina', abbina) == abbina
    assert T.clean_data('ordina', ordina) == ordina
    assert T.clean_data('scelta', scelta) == scelta


def test_selecting_every_line_is_not_rewarded():
    errore = T.clean_data('errore', {'lines': ['a', 'b', 'c', 'd'], 'error_lines': [2]})
    assert T.grade('errore', errore, {'lines': [1, 2, 3, 4]})['score'] == 0


def test_flashcards_give_no_points():
    card = T.clean_data('flashcard', {'front': 'f', 'back': 'b'})
    assert T.grade('flashcard', card, {'grade': 3})['score'] == 0


def test_malformed_answers_never_crash():
    samples = [T.clean_data('grafo', {'task': 'bfs', 'source': 'a', 'nodes': [
        {'id': n, 'x': 0.1 * i, 'y': 0.5} for i, n in enumerate('abc')], 'edges': [
        {'from': 'a', 'to': 'b'}, {'from': 'b', 'to': 'c'}]}),
    ]
    junk = [{'order': 5}, {'order': [float('inf')]}, {'lines': [float('inf')]}, {'values': {'r': 10 ** 400}},
            {'points': {'x': 1}}, {'selected': 3}, {'grade': float('inf')}, {'cells': [1]}]
    for answer in junk:
        for kind, data in [('grafo', samples[0]),
                           ('numerica', T.clean_data('numerica', {'answer': 2})),
                           ('errore', T.clean_data('errore', {'lines': ['a', 'b'], 'error_lines': [1]}))]:
            assert 0 <= T.grade(kind, data, answer)['score'] <= 1


def test_traccia_row_check_does_not_reveal_other_rows():
    data = T.clean_data('traccia', {'columns': ['a', 'b'], 'rows': [
        ['1', {'blank': True, 'accepted': ['x']}], ['2', {'blank': True, 'accepted': ['y']}]]})
    result = T.grade('traccia', data, {'cells': {'0,1': 'sbagliato'}}, scope={'row': 0})
    assert result['correct_payload'] == {'cells': {}}
    assert '1,1' not in result['feedback']['cells']


def test_client_cannot_forge_code_results():
    from services.exercise_items import grade_item
    item = {'id': 'ex:1', 'type': 'codice', 'data': T.clean_data('codice', {
        'language': 'python', 'function': 'f', 'tests': [{'call': 'f(1)', 'expected': '1'}]})}
    forged = {'code': 'x', '_run': {'results': [{'ok': True}]}}
    assert not grade_item(item, forged)['is_correct']


def test_invalid_exercises_are_rejected():
    with pytest.raises(ValueError):
        T.clean_data('ordina', {'items': ['solo uno']})
    with pytest.raises(ValueError):
        T.clean_data('completa', {'text': 'senza spazi', 'blanks': []})
    with pytest.raises(ValueError):
        T.clean_data('grafo', {'task': 'dijkstra', 'nodes': [{'id': 'a', 'x': 0, 'y': 0}, {'id': 'b', 'x': 1, 'y': 1},
                                                             {'id': 'c', 'x': .5, 'y': .5}],
                               'edges': [{'from': 'a', 'to': 'b', 'w': -1}, {'from': 'b', 'to': 'c', 'w': 1}]})
    with pytest.raises(ValueError):
        T.clean_data('codice', {'language': 'python', 'function': 'f',
                                'tests': [{'call': '__import__("os").system("x")', 'expected': '0'}]})


def test_saved_data_can_be_cleaned_again():
    """L'editor rimanda i dati già salvati: la validazione deve dare lo stesso risultato."""
    samples = {
        'abbina': {'pairs': [{'left': 'TCP', 'right': 'affidabile'}, {'left': 'UDP', 'right': 'veloce'}],
                   'distractors': ['altro']},
        'ordina': {'items': ['a', 'b', 'c']},
        'completa': {'text': 'x [[1]]', 'blanks': [{'id': '1', 'accepted': ['6'], 'numeric': True}], 'bank': ['6']},
        'numerica': {'steps': [{'id': 'r', 'label': 'r', 'answer': '1,5', 'tolerance': 0.1}]},
        'traccia': {'columns': ['a'], 'rows': [[{'blank': True, 'accepted': ['x'], 'options': ['x', 'y']}]]},
    }
    for kind, raw in samples.items():
        once = T.clean_data(kind, raw)
        assert T.clean_data(kind, once) == once, kind


# ------------------------------------------------------------------ scelta degli esercizi (v21)
import contextlib


@contextlib.contextmanager
def _fake_bank(items, questions):
    """Banca e domande finte, senza file: si rimettono a posto alla fine del test."""
    from services import exercise_items as ei
    saved = ei.read_exercises, ei.get_available_questions
    ei.read_exercises = lambda d, c, s: items
    ei.get_available_questions = lambda **kw: questions
    try:
        yield ei
    finally:
        ei.read_exercises, ei.get_available_questions = saved


BANK = [
    {'id_exercise': '1', 'type': 'ordina', 'metadata': {'argoment': 'Trasporto', 'difficulty': 1}, 'estimed_time': 60,
     'text': 'Ordina.', 'data': {'items': ['SYN', 'SYN-ACK', 'ACK']}},
    {'id_exercise': '2', 'type': 'ordina', 'metadata': {'argoment': 'Rete', 'difficulty': 3}, 'estimed_time': 300,
     'text': 'Ordina.', 'data': {'items': ['a', 'b', 'c']}},
    {'id_exercise': '3', 'type': 'grafo', 'metadata': {'argoment': 'Rete', 'difficulty': 2}, 'text': 'BFS',
     'generator': {'name': 'bfs', 'difficulty': 2}},
]
QUESTIONS = [{'id_question': '7', 'text': 'Q?', 'estimed_time': '20', 'metadata': {'argoment': 'Trasporto'},
              'option': [{'id': 'a', 'text': 'x'}, {'id': 'b', 'text': 'y'}], 'id_correct': 'a'}]


def test_history_marks_latest_answer():
    from services.exercise_items import history_from_rows
    h = history_from_rows([('ex:1:55', 'ordina', 0.4, False, '1'), ('ex:1:99', 'ordina', 1.0, True, '2'),
                           ('7', None, None, False, '3')])
    assert h['seen'] == {'ex:1', '7'} and h['wrong'] == {'7'}          # l'ultima risposta a ex:1 è giusta
    assert h['stats']['ordina']['done'] == 1 and h['stats']['multiple_choice']['to_review'] == 1


def test_overview_counts_per_type_with_filters():
    with _fake_bank(BANK, QUESTIONS) as ei:
        _check_overview(ei)


def _check_overview(ei):
    data = ei.overview(None, 'd', 'c', 's', filters=ei.Filters(arguments=['Trasporto']), code_runner=False)
    cards = {c['type']: c for c in data['types']}
    assert cards['ordina']['count'] == 1 and cards['multiple_choice']['count'] == 1
    assert cards['grafo']['count'] == 0 and not cards['grafo']['available']
    # il conteggio degli argomenti ignora il filtro sugli argomenti: "Rete" mostra quanti se ne aggiungerebbero
    assert {a['name']: a['count'] for a in data['filters']['arguments']}['Rete'] == 2
    short = ei.overview(None, 'd', 'c', 's', filters=ei.Filters(max_seconds=120), code_runner=False)
    cards = {c['type']: c for c in short['types']}
    assert cards['ordina']['count'] == 1 and cards['grafo']['variants']
    assert 'difficulties' not in short['filters'] and 'difficulty' not in cards['ordina']
    # ogni filtro si conta ignorando se stesso: con "fino a 1 min" si vede quanti se ne aggiungono allungando
    brief = ei.overview(None, 'd', 'c', 's', filters=ei.Filters(max_seconds=60), code_runner=False)
    assert brief['filters']['durations']['long'] == 1 and brief['filters']['durations']['short'] >= 2
    rete = ei.overview(None, 'd', 'c', 's', filters=ei.Filters(arguments=['Rete'], max_seconds=60), code_runner=False)
    assert {c['type']: c for c in rete['types']}['flashcard']['count'] == 0   # qf segue l'argomento (Trasporto)
    trasporto = ei.overview(None, 'd', 'c', 's', filters=ei.Filters(arguments=['Trasporto'], max_seconds=10), code_runner=False)
    assert {c['type']: c for c in trasporto['types']}['flashcard']['count'] == 1   # la durata non vale per le flashcard


def test_overview_only_mistakes_and_pick_mixes_questions():
    with _fake_bank(BANK, QUESTIONS) as ei:
        _check_mistakes(ei)


def _check_mistakes(ei):
    import random
    history = ei.history_from_rows([('ex:2', 'ordina', 0.0, False, '1'), ('ex:1', 'ordina', 1.0, True, '2')])
    data = ei.overview(None, 'd', 'c', 's', filters=ei.Filters(), code_runner=False, history=history, only_mistakes=True)
    assert data['total'] == 1
    items = ei.pick(None, 'd', 'c', 's', types=['ordina', 'multiple_choice'], arguments=None, count=5,
                    rng=random.Random(0), filters=ei.Filters(exclude=history['seen']))
    assert {i['id'] for i in items} == {'7'}                             # solo nuovi: resta la domanda
    public = ei.public_multiple_choice(QUESTIONS[0])
    assert 'id_correct' not in public and public['type'] == 'multiple_choice'
