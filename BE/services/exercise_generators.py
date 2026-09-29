"""Esercizi generati: un modello nella banca (es. "grafo · dijkstra") e un seme.

Lo stesso seme produce sempre lo stesso esercizio, quindi il server può
ricostruirlo per correggerlo senza salvarlo: l'id dell'esercizio è
"ex:<id del modello>:<seme>".
"""
from __future__ import annotations

import math
import random

GENERATORS = {
    'dijkstra': ('grafo', 'Esegui Dijkstra da {source}: tocca i nodi nell’ordine in cui vengono chiusi.'),
    'bfs': ('grafo', 'Visita in ampiezza (BFS) da {source}: tocca i nodi nell’ordine di visita.'),
    'dfs': ('grafo', 'Visita in profondità (DFS) da {source}: tocca i nodi nell’ordine di visita.'),
    'subnet': ('numerica', 'Dividi la rete {network}/24 in {parts} sottoreti della stessa dimensione.'),
    'bubble': ('traccia', 'Esegui il bubble sort crescente su [{array}]: scrivi l’array dopo ogni passata.'),
    'base_conversion': ('numerica', 'Converti il numero {value} dalla base {base_from} alla base 10.'),
}
MAX_SEED = 2 ** 31 - 1
LABELS = ['u', 'v', 'w', 'x', 'y', 'z', 't']
# Posizioni fisse su una griglia leggibile (0..1): il disegno resta pulito.
LAYOUT = [(0.10, 0.50), (0.35, 0.18), (0.35, 0.82), (0.62, 0.18), (0.62, 0.82), (0.90, 0.50), (0.50, 0.50)]


def _graph(rng: random.Random, size: int, weighted: bool) -> tuple[list[dict], list[dict]]:
    nodes = [{'id': LABELS[i], 'label': LABELS[i], 'x': LAYOUT[i][0], 'y': LAYOUT[i][1]} for i in range(size)]
    # Coppie "vicine" nel disegno: evita archi che attraversano tutto il grafo.
    near = [(a, b) for a in range(size) for b in range(a + 1, size)
            if math.dist(LAYOUT[a], LAYOUT[b]) < 0.48]
    rng.shuffle(near)
    parent = list(range(size))

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x
    chosen = []
    for a, b in near:                      # albero ricoprente: il grafo è connesso
        if find(a) != find(b):
            parent[find(a)] = find(b)
            chosen.append((a, b))
    for a, b in near:                      # qualche arco in più
        if (a, b) not in chosen and len(chosen) < size + 2 and rng.random() < 0.5:
            chosen.append((a, b))
    edges = [{'from': LABELS[a], 'to': LABELS[b], 'w': rng.randint(1, 9) if weighted else 1} for a, b in chosen]
    return nodes, edges


def generate(template: dict, seed: int) -> dict:
    """Restituisce un esercizio completo (tipo, testo, data) a partire dal modello."""
    spec = template.get('generator') or {}
    name = spec.get('name')
    if name not in GENERATORS:
        raise ValueError('Generatore non valido.')
    seed = int(seed) % MAX_SEED
    rng = random.Random(f'{template.get("id_exercise")}:{name}:{seed}')
    difficulty = max(1, min(3, int(spec.get('difficulty') or 2)))
    kind, prompt = GENERATORS[name]

    if name in ('dijkstra', 'bfs', 'dfs'):
        size = 4 + difficulty
        nodes, edges = _graph(rng, size, weighted=(name == 'dijkstra'))
        source = 'u'
        data = {'task': name, 'directed': False, 'nodes': nodes, 'edges': edges, 'source': source}
        text = prompt.format(source=source)
        if name != 'dijkstra':
            text += ' A parità di scelta vale qualsiasi vicino.'
        else:
            text += ' In caso di pari merito va bene uno qualsiasi.'
    elif name == 'subnet':
        third = rng.randint(1, 254)
        parts = rng.choice([3, 4, 5, 6, 7, 8, 10, 12, 16] if difficulty > 1 else [2, 3, 4, 6, 8])
        bits = math.ceil(math.log2(parts))
        mask = 24 + bits
        hosts = 2 ** (32 - mask) - 2
        network = f'192.168.{third}.0'
        data = {'steps': [
            {'id': 'bits', 'label': 'Bit presi in prestito', 'answer': bits,
             'check': f'2^{bits} = {2 ** bits} ≥ {parts}', 'hint': 'Il più piccolo n con 2^n ≥ numero di sottoreti.'},
            {'id': 'mask', 'label': 'Nuova maschera: scrivi il numero dopo la barra (es. 27 per /27)', 'answer': mask},
            {'id': 'hosts', 'label': 'Host utilizzabili per sottorete', 'answer': hosts,
             'check': 'Tolti indirizzo di rete e broadcast', 'hint': '2^(bit per gli host) − 2'},
        ]}
        text = prompt.format(network=network, parts=parts)
    elif name == 'bubble':
        length = 4 + difficulty
        array = rng.sample(range(1, 20), length)
        rows, current, number = [], list(array), 0
        while True:
            number += 1
            swaps = 0
            for i in range(len(current) - number):
                if current[i] > current[i + 1]:
                    current[i], current[i + 1] = current[i + 1], current[i]
                    swaps += 1
            state = ' '.join(map(str, current))
            rows.append([str(number),
                         {'blank': True, 'accepted': [state, state.replace(' ', ','), state.replace(' ', ', ')]},
                         {'blank': True, 'accepted': [str(swaps)]}])
            if swaps == 0 or number >= length - 1:
                break
        data = {'columns': ['Passata', 'Array dopo la passata', 'Scambi'], 'rows': rows, 'row_by_row': True}
        text = prompt.format(array=', '.join(map(str, array)))
    else:  # base_conversion
        base_from = rng.choice([2, 8, 16] if difficulty > 1 else [2])
        value = rng.randint(9, 255 if difficulty > 1 else 63)
        digits = '0123456789ABCDEF'
        shown, n = '', value
        while n:
            shown = digits[n % base_from] + shown
            n //= base_from
        data = {'steps': [{'id': 'r', 'label': 'Valore in base 10', 'answer': value}]}
        text = prompt.format(value=shown, base_from=base_from)
    return {'type': kind, 'text': text, 'data': data}


def available() -> list[dict]:
    return [{'name': name, 'type': kind, 'description': prompt} for name, (kind, prompt) in GENERATORS.items()]
