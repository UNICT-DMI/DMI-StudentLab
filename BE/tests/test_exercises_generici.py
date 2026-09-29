"""Test dei tipi generici (v24) e delle aree didattiche. Logica pura: niente database.

    cd BE && python -m pytest tests/test_exercises_generici.py -q
"""
import json
import random

import pytest

from services import exercise_areas as A
from services import exercise_types as T

CASO = {
    'scenario': 'Sig.ra R., 78 anni, diabetica, confusa da un’ora. Ha saltato il pranzo.',
    'steps': [
        {'prompt': 'Prima azione?', 'options': ['Glicemia capillare', 'Liquidi per os', 'Attendere'],
         'correct': 0, 'note': 'Sospetta ipoglicemia: si misura subito.'},
        {'kind': 'numerica', 'prompt': 'Glucosio al 33%: quanti ml per 10 g?', 'answer': '30,3',
         'tolerance': 0.5, 'unit': 'ml', 'weight': 2},
    ],
}
VF = {'claims': [
    {'text': 'La vendita di cosa altrui è nulla.', 'value': False,
     'reasons': ['È valida e obbliga a procurare l’acquisto', 'È nulla per mancanza di oggetto', 'È annullabile'],
     'correct_reason': 0, 'explanation': 'Art. 1478 c.c.'},
    {'text': 'Il preliminare di vendita immobiliare richiede la forma scritta.', 'value': 'vero'},
]}
CAT = {'categories': ['Procarioti', 'Eucarioti'],
       'items': [{'text': 'Nucleoide', 'category': 'Procarioti'}, {'text': 'Nucleo', 'category': 1},
                 {'text': 'Plasmidi', 'category': 0}, {'text': 'Apparato di Golgi', 'category': 'eucarioti'}]}
LT = {'events': [{'text': 'Statuto albertino', 'date': '1848'}, {'text': 'Costituzione repubblicana', 'date': '1948'},
                 'Riforma del Titolo V']}
RB = {'model_answer': 'Il rene filtra meno, trattiene sodio e acqua: il liquido passa nei tessuti (edemi).',
      'criteria': [{'text': 'Nomina il meccanismo', 'points': 2, 'keywords': 'filtr, ritenzione, trattien'},
                   {'text': 'Collega sodio e acqua', 'keywords': ['sodio', 'acqua'], 'min_matches': 2}],
      'min_chars': 20}
ALL = {'caso': CASO, 'vero_falso': VF, 'categorizza': CAT, 'linea_tempo': LT, 'risposta_breve': RB}


def _public_json(kind, data):
    return json.dumps(T.public_data(kind, data, random.Random(1)), ensure_ascii=False)


@pytest.mark.parametrize('kind', list(ALL))
def test_clean_is_idempotent_and_registered(kind):
    assert kind in T.TYPES and kind in T.HANDLERS
    data = T.clean_data(kind, ALL[kind])
    assert T.clean_data(kind, data) == data          # salvare di nuovo non cambia nulla
    assert T.solution_summary(kind, data)


def test_public_data_hides_solutions():
    caso = T.clean_data('caso', CASO)
    text = _public_json('caso', caso)
    assert '30.3' not in text and 'correct' not in text and 'Sospetta' not in text
    vf = T.clean_data('vero_falso', VF)
    text = _public_json('vero_falso', vf)
    assert '"value"' not in text and 'correct_reason' not in text and '1478' not in text
    cat = T.clean_data('categorizza', CAT)
    assert 'placement' not in _public_json('categorizza', cat)
    lt = T.clean_data('linea_tempo', LT)
    text = _public_json('linea_tempo', lt)
    assert '1848' not in text and 'order' not in text
    rb = T.clean_data('risposta_breve', RB)
    text = _public_json('risposta_breve', rb)
    assert 'keywords' not in text and 'filtra meno' not in text


def test_caso_weighted_score_and_single_step_check():
    data = T.clean_data('caso', CASO)
    first, second = data['steps']
    right = first['correct'][0]
    wrong = next(o['id'] for o in first['options'] if o['id'] != right)
    full = T.grade('caso', data, {'steps': {first['id']: {'selected': [right]}, second['id']: {'value': '30'}}})
    assert full['is_correct'] and full['score'] == 1
    assert full['feedback']['notes'][first['id']].startswith('Sospetta')
    half = T.grade('caso', data, {'steps': {first['id']: {'selected': [wrong]}, second['id']: {'value': '30,1'}}})
    assert not half['is_correct'] and half['score'] == pytest.approx(2 / 3, abs=1e-3)   # peso 1 + 2
    step = T.grade('caso', data, {'steps': {first['id']: {'selected': [right]}}}, {'step': first['id']})
    assert step['is_correct'] and step['correct_payload'] is None      # il passo non rivela la soluzione
    assert T.grade('caso', data, {}, {'step': 'nessuno'})['score'] == 0


def test_vero_falso_half_for_value_half_for_reason():
    data = T.clean_data('vero_falso', VF)
    a, b = data['claims']
    good_reason = a['correct_reason']
    bad_reason = next(r['id'] for r in a['reasons'] if r['id'] != good_reason)
    perfect = T.grade('vero_falso', data, {'answers': {a['id']: {'value': False, 'reason': good_reason},
                                                        b['id']: {'value': True}}})
    assert perfect['is_correct'] and perfect['score'] == 1
    partial = T.grade('vero_falso', data, {'answers': {a['id']: {'value': False, 'reason': bad_reason},
                                                        b['id']: {'value': True}}})
    assert not partial['is_correct'] and partial['score'] == 0.75
    lucky = T.grade('vero_falso', data, {'answers': {a['id']: {'value': True, 'reason': good_reason}}})
    assert lucky['score'] == 0                         # motivo giusto ma verdetto sbagliato: 0
    assert T.grade('vero_falso', data, {'answers': {a['id']: {'value': 'false'}}})['score'] == 0   # solo bool


def test_categorizza_and_linea_tempo():
    data = T.clean_data('categorizza', CAT)
    placement = data['placement']
    assert T.grade('categorizza', data, {'placement': placement})['is_correct']
    swapped = dict(placement)
    first = next(iter(swapped))
    swapped[first] = next(c['id'] for c in data['categories'] if c['id'] != placement[first])
    result = T.grade('categorizza', data, {'placement': swapped})
    assert not result['is_correct'] and result['score'] == 0.75
    with pytest.raises(ValueError):
        T.clean_data('categorizza', {'categories': ['A', 'B'], 'items': [{'text': 'x', 'category': 'C'},
                                                                         {'text': 'y', 'category': 'A'}]})
    lt = T.clean_data('linea_tempo', LT)
    order = lt['order']
    assert T.grade('linea_tempo', lt, {'order': order})['is_correct']
    swapped = [order[1], order[0], order[2]]
    result = T.grade('linea_tempo', lt, {'order': swapped})
    assert not result['is_correct'] and result['score'] == pytest.approx(2 / 3, abs=1e-3)
    assert result['correct_payload']['dates'][order[0]] == '1848'
    assert T.grade('linea_tempo', lt, {'order': order[:2]})['feedback'] == {'error': 'incomplete'}


def test_risposta_breve_keywords_and_length():
    data = T.clean_data('risposta_breve', RB)
    good = T.grade('risposta_breve', data, {'text': 'Il rene FILTRA meno e trattiene sodio e acqua nei tessuti.'})
    assert good['is_correct'] and good['score'] == 1
    part = T.grade('risposta_breve', data, {'text': 'Si ha una ritenzione di liquidi nelle gambe, gonfiore.'})
    assert not part['is_correct'] and part['score'] == pytest.approx(2 / 3, abs=1e-3)
    short = T.grade('risposta_breve', data, {'text': 'sodio acqua'})
    assert short['score'] == 0 and short['feedback']['error'] == 'too_short'
    assert T.grade('risposta_breve', data, {'text': 'Parole sparse: àcqua sòdio filtrazione'})['is_correct']


@pytest.mark.parametrize('kind', list(ALL))
def test_malformed_answers_score_zero(kind):
    data = T.clean_data(kind, ALL[kind])
    for answer in ({}, {'steps': 'x', 'answers': [1], 'placement': 5, 'order': 'abc', 'text': None}, None):
        result = T.grade(kind, data, answer)
        assert result['score'] == 0 and not result['is_correct']


def test_invalid_data_is_rejected():
    with pytest.raises(ValueError):
        T.clean_data('caso', {'scenario': 'x', 'steps': []})
    with pytest.raises(ValueError):
        T.clean_data('vero_falso', {'claims': [{'text': 'a', 'value': 'forse'}]})
    with pytest.raises(ValueError):
        T.clean_data('vero_falso', {'claims': [{'text': 'a', 'value': True, 'reasons': ['uno']}]})
    with pytest.raises(ValueError):
        T.clean_data('risposta_breve', {'model_answer': 'x', 'criteria': [{'text': 'a', 'keywords': []}]})
    with pytest.raises(ValueError):
        T.clean_data('linea_tempo', {'events': ['uno', 'uno', 'due']})
    with pytest.raises(ValueError):          # con 2 eventi il mescolamento rivelerebbe l'ordine
        T.clean_data('linea_tempo', {'events': ['uno', 'due']})


def test_categorizza_numeric_labels_stay_put():
    raw = {'categories': ['1', '2', '0'], 'items': [{'text': 'x', 'category': '1'}, {'text': 'y', 'category': '2'},
                                                    {'text': 'z', 'category': '0'}]}
    data = T.clean_data('categorizza', raw)
    names = {c['id']: c['text'] for c in data['categories']}
    texts = {i['id']: i['text'] for i in data['items']}
    assert {texts[i]: names[c] for i, c in data['placement'].items()} == {'x': '1', 'y': '2', 'z': '0'}
    assert T.clean_data('categorizza', data) == data


@pytest.mark.parametrize('department,course,department_name,course_name,area', [
    ('DMI', 'L-31', 'Matematica e Informatica', 'Informatica', 'informatica'),
    ('DMI', 'L-35', 'Matematica e Informatica', 'Matematica', 'matematica_fisica'),
    ('DIEEI', 'L-8', '', 'Ingegneria informatica', 'informatica'),
    ('DIEEI', 'L-8', '', 'Ingegneria elettronica', 'ingegneria'),
    ('MEDCLIN', 'L/SNT1', 'Medicina Clinica e Sperimentale', 'Infermieristica', 'salute'),
    ('DSG', 'LMG-01', 'Giurisprudenza', 'Giurisprudenza', 'giuridico_economico'),
    ('DEI', 'L-18', 'Economia e Impresa', '', 'giuridico_economico'),
    ('DISUM', 'L-10', 'Scienze Umanistiche', '', 'umanistica'),
    ('sds_ragusa', 'L-11', '', '', 'umanistica'),
    ('sds_siracusa', 'LM-4', '', '', 'ingegneria'),
    ('DSBGA', 'L-13', '', 'Scienze biologiche', 'scienze'),
    ('XYZ', 'L-1', 'Scienze dei materiali', '', 'generale'),   # "dei" non è il codice di Economia
])
def test_areas_resolve(department, course, department_name, course_name, area):
    result = A.resolve(department, course, department_name=department_name, course_name=course_name,
                       config=A.validate(A.DEFAULT_CONFIG))
    assert result['id'] == area
    assert result['types'][0] == A.MULTIPLE_CHOICE
    assert ('codice' in result['types']) == (area == 'informatica')


def test_areas_default_config_covers_all_departments_and_validates():
    config = A.validate(A.DEFAULT_CONFIG)
    assert len(config['departments']) == 19          # 17 dipartimenti + SDS Ragusa e Siracusa
    for area in config['areas'].values():
        assert set(A.GENERIC) <= set(area['types'])
    with pytest.raises(ValueError):
        A.validate({**A.DEFAULT_CONFIG, 'default_area': 'nessuna'})
    with pytest.raises(ValueError):
        A.validate({**A.DEFAULT_CONFIG, 'departments': [{'area': 'nessuna', 'match': ['x']}]})
    broken = json.loads(json.dumps(A.DEFAULT_CONFIG))
    broken['areas']['generale']['types'] = ['inesistente']
    with pytest.raises(ValueError):
        A.validate(broken)


def test_areas_save_and_reset(tmp_path, monkeypatch):
    monkeypatch.setattr(A, 'DATA_ROOT', tmp_path)
    A.reset()
    changed = json.loads(json.dumps(A.DEFAULT_CONFIG))
    changed['areas']['giuridico_economico']['types'].append('diagramma')
    A.save(changed)
    assert 'diagramma' in A.resolve('DSG', 'x')['types']
    (tmp_path / A.CONFIG_FILE).write_text('{rotto', encoding='utf-8')
    assert 'diagramma' not in A.resolve('DSG', 'x')['types']      # file rovinato: si torna al predefinito
    A.reset()
    assert not (tmp_path / A.CONFIG_FILE).exists()
