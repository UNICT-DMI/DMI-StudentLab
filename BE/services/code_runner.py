"""Esecuzione del codice degli studenti in un servizio ISOLATO (mai nel backend).

Si usa Piston (https://github.com/engineer-man/piston), da installare su una
macchina separata, senza accesso alla rete interna:
    CODE_RUNNER_URL=https://runner.example.org      (senza /api/v2)
    CODE_RUNNER_TOKEN=...                            (facoltativo, header Authorization)
    CODE_RUNNER_MAX_RUN_MS=10000                     (= PISTON_RUN_TIMEOUT del tuo Piston)
    CODE_RUNNER_CONCURRENCY=4                        (esecuzioni contemporanee per processo)
Su Piston imposta anche PISTON_OUTPUT_MAX_SIZE=65536 (il default 1024 taglia i risultati).

Come si evita che lo studente "legga" i risultati attesi:
  - i test e il codice arrivano al programma di controllo via stdin, non su disco;
  - il codice dello studente gira in un processo figlio che riceve solo le
    chiamate da eseguire, mai i risultati attesi;
  - il programma di controllo firma la riga dei risultati con un nonce casuale
    che il figlio non conosce.
Il confronto avviene sul server (repr dei valori).
"""
from __future__ import annotations

import ast
import json
import os
import secrets
import threading
import time
import urllib.error
import urllib.request
from collections import deque

MAX_CODE = 10_000
RUNS_PER_WINDOW = 20
WINDOW_SECONDS = 600
_runs: dict[int, deque] = {}
_lock = threading.Lock()
_slots = threading.BoundedSemaphore(max(1, int(os.environ.get('CODE_RUNNER_CONCURRENCY') or 4)))


def _max_run_ms() -> int:
    try:
        return max(1500, int(os.environ.get('CODE_RUNNER_MAX_RUN_MS') or 3000))
    except ValueError:
        return 3000

CHILD = r'''
import sys, json
_d = json.loads(sys.stdin.read())
_ns = {"__name__": "__studente__"}
try:
    exec(compile(_d["code"], "soluzione.py", "exec"), _ns)
except BaseException as _e:
    print("\x1e" + json.dumps({"error": (type(_e).__name__ + ": " + str(_e))[:300]}))
    raise SystemExit(0)
_out = []
for _c in _d["calls"]:
    try:
        _out.append({"ok": True, "repr": repr(eval(_c, _ns))[:200]})
    except BaseException as _e:
        _out.append({"ok": False, "repr": (type(_e).__name__ + ": " + str(_e))[:200]})
print("\x1e" + json.dumps({"results": _out}))
'''

PARENT = r'''
import sys, json, subprocess
nonce = sys.stdin.readline().strip()
payload = json.loads(sys.stdin.readline())
try:
    proc = subprocess.run([sys.executable, "-I", "-c", payload["child"]],
                          input=json.dumps({"code": payload["code"], "calls": payload["calls"]}),
                          capture_output=True, text=True, timeout=payload["timeout"])
    lines = [l for l in proc.stdout.split("\n") if l.startswith("\x1e")]
    data = json.loads(lines[-1][1:]) if lines else {"error": (proc.stderr or "Nessun risultato")[-300:]}
except subprocess.TimeoutExpired:
    data = {"error": "Tempo scaduto: il codice ci mette troppo (ciclo infinito?)."}
except Exception as e:
    data = {"error": "Esecuzione non riuscita: " + str(e)[:200]}
print(nonce + json.dumps(data))
'''


def configured() -> bool:
    return bool(os.environ.get('CODE_RUNNER_URL', '').strip())


def rate_limited(user_id: int) -> bool:
    now = time.monotonic()
    with _lock:
        runs = _runs.setdefault(int(user_id), deque())
        while runs and now - runs[0] > WINDOW_SECONDS:
            runs.popleft()
        if len(runs) >= RUNS_PER_WINDOW:
            return True
        runs.append(now)
        return False


def _same(got_repr: str, expected: str) -> bool:
    if got_repr.strip() == expected.strip():
        return True
    try:
        return ast.literal_eval(got_repr) == ast.literal_eval(expected)
    except (ValueError, SyntaxError, TypeError, MemoryError, RecursionError):
        return False


def run_tests(data: dict, code: str, *, include_hidden: bool) -> dict:
    """Esegue i test; restituisce {'results': [...], 'error': str|None}.
    Con include_hidden=False esegue solo i test visibili (pulsante "Esegui")."""
    code = str(code or '')
    if not code.strip():
        return {'results': [], 'error': 'Scrivi il codice prima di eseguirlo.'}
    if len(code) > MAX_CODE:
        return {'results': [], 'error': 'Il codice è troppo lungo (massimo 10.000 caratteri).'}
    for word in data.get('forbidden') or []:
        if word and word in code:
            return {'results': [], 'error': f'Non puoi usare “{word}” in questo esercizio.'}
    if not configured():
        return {'results': [], 'error': 'Il servizio di esecuzione del codice non è configurato.'}
    tests = [t for t in data['tests'] if include_hidden or not t['hidden']]
    nonce = secrets.token_hex(16)
    max_run = _max_run_ms()
    # il figlio deve finire prima che Piston fermi il programma di controllo (~1 s di margine)
    timeout = max(0.5, min(data.get('time_limit_ms', 3000), max_run - 1000) / 1000)
    stdin = nonce + '\n' + json.dumps({'child': CHILD, 'code': code, 'calls': [t['call'] for t in tests],
                                       'timeout': timeout}) + '\n'
    body = json.dumps({'language': 'python', 'version': '*', 'files': [{'name': 'main.py', 'content': PARENT}],
                       'stdin': stdin, 'run_timeout': max_run, 'compile_timeout': 5000,
                       'run_memory_limit': 128 * 1024 * 1024}).encode()
    url = os.environ['CODE_RUNNER_URL'].rstrip('/') + '/api/v2/execute'
    headers = {'Content-Type': 'application/json'}
    if os.environ.get('CODE_RUNNER_TOKEN'):
        headers['Authorization'] = os.environ['CODE_RUNNER_TOKEN']
    if not _slots.acquire(timeout=15):
        return {'results': [], 'error': 'Il servizio di esecuzione è occupato. Riprova tra poco.'}
    try:
        request = urllib.request.Request(url, data=body, headers=headers, method='POST')
        with urllib.request.urlopen(request, timeout=max_run / 1000 + 10) as response:
            result = json.loads(response.read(2_000_000).decode('utf-8', 'replace'))
    except (urllib.error.URLError, TimeoutError, ValueError, OSError):
        return {'results': [], 'error': 'Il servizio di esecuzione non risponde. Riprova tra poco.'}
    finally:
        _slots.release()
    stdout = ((result.get('run') or {}).get('stdout') or '')
    line = next((l for l in reversed(stdout.split('\n')) if l.startswith(nonce)), None)
    if line is None:
        return {'results': [], 'error': 'Esecuzione non riuscita.'}
    try:
        data_out = json.loads(line[len(nonce):])
    except ValueError:
        return {'results': [], 'error': 'Esecuzione non riuscita.'}
    if data_out.get('error'):
        return {'results': [], 'error': str(data_out['error'])[:300]}
    raw = data_out.get('results') or []
    results = []
    for test, output in zip(tests, raw):
        ok = bool(output.get('ok')) and _same(str(output.get('repr')), test['expected'])
        entry = {'ok': ok, 'hidden': test['hidden']}
        if not test['hidden']:
            entry.update({'call': test['call'], 'expected': test['expected'], 'got': str(output.get('repr'))[:300]})
        results.append(entry)
    if len(results) < len(tests):
        return {'results': results, 'error': 'Alcuni test non sono stati eseguiti.'}
    return {'results': results, 'error': None}
