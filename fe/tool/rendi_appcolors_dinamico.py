#!/usr/bin/env python3
"""Adatta il codice Flutter ad AppColors dinamico.

Con i temi, `AppColors.x` non è più una costante di compilazione: è un getter
che legge la palette attiva. Le espressioni `const ...(color: AppColors.x)`
quindi non compilano più. Questo script:

  1. esegue `dart analyze --format=machine lib`;
  2. per ogni errore "valore non costante in un contesto const" toglie
     soltanto la parola `const` che racchiude quel punto;
  3. ripete finché non restano errori di questo tipo.

Prima di tutto sostituisce i colori fissi di Material usati nel codice
(`Colors.white70`, `Colors.redAccent`…) con gli equivalenti `AppColors.white70`,
`AppColors.redAccent`…: con Notte hanno esattamente lo stesso valore, negli altri
temi seguono la palette. `Colors.transparent`, `Colors.black…` e le sfumature
(`Colors.red.shade200`, `Colors.amber[400]`) restano come sono.

Poi aggiunge `assets/mascot/themes/` a pubspec.yaml (mascotte e logo per tema).

Non rinomina variabili e non cambia testi o layout. I casi che non può
sistemare da solo li elenca alla fine.

Uso, dalla cartella fe/:
    python3 tool/rendi_appcolors_dinamico.py            # applica
    python3 tool/rendi_appcolors_dinamico.py --prova    # mostra solo cosa farebbe
"""
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

REMOVE_ENCLOSING_CONST = {
    'CONST_WITH_NON_CONSTANT_ARGUMENT',
    'INVALID_CONSTANT',
    'NON_CONSTANT_LIST_ELEMENT',
    'NON_CONSTANT_SET_ELEMENT',
    'NON_CONSTANT_MAP_ELEMENT',
    'NON_CONSTANT_MAP_KEY',
    'NON_CONSTANT_MAP_VALUE',
    'CONST_WITH_NON_CONST',
    'CONST_EVAL_METHOD_INVOCATION',
    'CONST_EVAL_PROPERTY_ACCESS',
    'CONST_EVAL_TYPE_BOOL_NUM_STRING',
    'CONST_EVAL_EXTENSION_METHOD',
}
DECLARATION_TO_FINAL = {'CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE'}
MANUAL = {
    'NON_CONSTANT_DEFAULT_VALUE': 'colore come valore predefinito di un parametro',
    'NON_CONSTANT_CASE_EXPRESSION': 'colore usato in un case',
    'CONST_CONSTRUCTOR_WITH_NON_CONST_SUPER': 'costruttore const con super non costante',
}


def analyze(fe_dir: Path):
    result = subprocess.run(
        ['dart', 'analyze', '--format=machine', 'lib'],
        cwd=fe_dir, capture_output=True, text=True)
    errors = []
    for line in (result.stdout + result.stderr).splitlines():
        parts = line.split('|')
        if len(parts) < 8 or parts[0] != 'ERROR':
            continue
        errors.append({
            'code': parts[2], 'file': parts[3], 'line': int(parts[4]),
            'col': int(parts[5]), 'message': '|'.join(parts[7:]),
        })
    return errors


def code_mask(text: str):
    """True per i caratteri di codice, False dentro stringhe e commenti."""
    mask = [True] * len(text)
    i, n = 0, len(text)
    while i < n:
        ch = text[i]
        if text.startswith('//', i):
            j = text.find('\n', i)
            j = n if j < 0 else j
            for k in range(i, j):
                mask[k] = False
            i = j
            continue
        if text.startswith('/*', i):
            j = text.find('*/', i + 2)
            j = n if j < 0 else j + 2
            for k in range(i, j):
                mask[k] = False
            i = j
            continue
        if ch in ('"', "'"):
            raw = i > 0 and text[i - 1] == 'r'
            quote = text[i:i + 3] if text[i:i + 3] in ('"""', "'''") else ch
            j = i + len(quote)
            while j < n and not text.startswith(quote, j):
                j += 2 if (text[j] == '\\' and not raw) else 1
            j = min(n, j + len(quote))
            for k in range(i, j):
                mask[k] = False
            i = j
            continue
        i += 1
    return mask


def offset_of(text: str, line: int, col: int) -> int:
    lines = text.split('\n')
    return sum(len(item) + 1 for item in lines[:line - 1]) + col - 1


def enclosing_const(text: str, mask, offset: int):
    """Posizione della parola `const` più vicina che racchiude `offset`."""
    for match in reversed([m for m in re.finditer(r'\bconst\b', text[:offset])]):
        start = match.start()
        if not mask[start]:
            continue
        depth = 0
        opened = False
        closed = False
        for k in range(match.end(), offset):
            if not mask[k]:
                continue
            c = text[k]
            if c in '([{':
                depth += 1
                opened = True
            elif c in ')]}':
                depth -= 1
                if depth <= 0:
                    # L'espressione di questo const si chiude prima del punto
                    # con l'errore: non lo racchiude.
                    closed = True
                    break
        if opened and not closed and depth > 0:
            return start
    return None


def declaration_const(text: str, mask, offset: int):
    """`const` della dichiarazione (variabile o campo) che contiene `offset`."""
    line_start = text.rfind(';', 0, offset) + 1
    brace = text.rfind('{', 0, offset) + 1
    line_start = max(line_start, brace)
    for match in re.finditer(r'\bconst\b', text[line_start:offset]):
        start = line_start + match.start()
        if mask[start]:
            return start
    return None


THEMED_COLORS = [
    'white70', 'white60', 'white54', 'white38', 'white30', 'white24', 'white12', 'white10', 'white',
    'redAccent', 'red', 'greenAccent', 'green', 'amberAccent', 'amber', 'orangeAccent', 'orange',
    'lightBlueAccent', 'blueAccent', 'cyanAccent', 'purpleAccent',
]
COLORS_RE = re.compile(r'\bColors\.(' + '|'.join(THEMED_COLORS) + r')\b(?!\s*(?:\.shade|\[))')


def replace_material_colors(lib_dir: Path, dry_run: bool):
    """Colors.x -> AppColors.x per i colori che devono seguire il tema."""
    changed, total = [], 0
    for path in lib_dir.rglob('*.dart'):
        if 'theme' in path.parts:
            continue
        text = path.read_text(encoding='utf-8')
        if 'Colors.' not in text:
            continue
        mask = code_mask(text)
        pieces, last, count = [], 0, 0
        for match in COLORS_RE.finditer(text):
            if not mask[match.start()]:
                continue
            pieces.append(text[last:match.start()])
            pieces.append('AppColors.' + match.group(1))
            last = match.end()
            count += 1
        if count == 0:
            continue
        pieces.append(text[last:])
        new_text = ''.join(pieces)
        if 'nightTheme.dart' not in new_text:
            # Import del file dei colori, dopo il primo import esistente.
            first = re.search(r"^import [^\n]*;\n", new_text, re.M)
            line = "import 'package:fe/theme/nightTheme.dart';\n"
            new_text = new_text[:first.end()] + line + new_text[first.end():] if first else line + new_text
        total += count
        changed.append(str(path))
        if not dry_run:
            path.write_text(new_text, encoding='utf-8')
    return changed, total


def add_theme_assets(fe_dir: Path, dry_run: bool) -> bool:
    """Aggiunge la cartella delle immagini per tema a pubspec.yaml."""
    pubspec = fe_dir / 'pubspec.yaml'
    text = pubspec.read_text(encoding='utf-8')
    if 'assets/mascot/themes/' in text:
        return False
    match = re.search(r'^(\s*)- assets/mascot/\s*$', text, re.M)
    if match is None:
        raise SystemExit('✗ In pubspec.yaml non trovo "- assets/mascot/": aggiungi a mano "- assets/mascot/themes/".')
    line = f"\n{match.group(1)}- assets/mascot/themes/"
    if not dry_run:
        pubspec.write_text(text[:match.end()] + line + text[match.end():], encoding='utf-8')
    return True


def fix_color_defaults(lib_dir: Path, dry_run: bool):
    """Parametri con un colore di AppColors come valore predefinito.

    `this.color = AppColors.x` non è più valido (il valore predefinito deve
    essere costante). Diventa `Color? color` con `color ?? AppColors.x`
    nell'initializer: il campo, il suo nome e il colore predefinito restano uguali.
    """
    pattern = re.compile(r'this\.(\w+) = (AppColors\.\w+),')
    fixed, manual = [], []
    for path in lib_dir.rglob('*.dart'):
        if path.name in ('nightTheme.dart', 'app_palette.dart'):
            continue
        text = path.read_text(encoding='utf-8')
        original = text
        while True:
            match = pattern.search(text)
            if match is None:
                break
            name, default = match.group(1), match.group(2)
            ctors = [c for c in re.finditer(r'\b(const )?(\w+)\(\{', text[:match.start()])]
            if not ctors or not re.search(rf'final Color {name};', text):
                manual.append(f'{path}: {name} = {default}')
                break
            ctor = ctors[-1]
            open_paren = ctor.end() - 2
            depth, close_paren = 0, -1
            for k in range(open_paren, len(text)):
                if text[k] in '([{':
                    depth += 1
                elif text[k] in ')]}':
                    depth -= 1
                    if depth == 0:
                        close_paren = k
                        break
            after = text[close_paren + 1:close_paren + 40] if close_paren > 0 else ''
            if close_paren < match.end() or not (after.lstrip().startswith(';') or after.lstrip().startswith(':')):
                manual.append(f'{path}: {name} = {default}')
                break
            initializer = f'{name} = {name} ?? {default}'
            rest = text[close_paren + 1:]
            stripped = rest.lstrip()
            gap = rest[:len(rest) - len(stripped)]
            if stripped.startswith(';'):
                rest = f' : {initializer}' + rest
            else:  # c'è già un initializer: aggiungo in testa
                rest = gap + ': ' + initializer + ',' + stripped[1:]
            text = text[:close_paren + 1] + rest
            text = text[:match.start()] + f'Color? {name},' + text[match.end():]
            if ctor.group(1):
                text = text[:ctor.start()] + text[ctor.start() + len('const '):]
            fixed.append(f'{path}: {name}')
        if text != original and not dry_run:
            path.write_text(text, encoding='utf-8')
    return fixed, manual

def main():
    dry_run = '--prova' in sys.argv
    fe_dir = Path.cwd()
    if not (fe_dir / 'pubspec.yaml').exists():
        print('✗ Esegui lo script dalla cartella fe/ (quella con pubspec.yaml).')
        sys.exit(1)

    if add_theme_assets(fe_dir, dry_run):
        print('[pubspec] aggiunta la cartella assets/mascot/themes/')
    colored, replaced = replace_material_colors(fe_dir / 'lib', dry_run)
    print(f'[colori] {replaced} colori di Material resi tematici in {len(colored)} file')

    fixed, manual_defaults = fix_color_defaults(fe_dir / 'lib', dry_run)
    print('[prima] colori come valore predefinito di un parametro')
    for item in fixed:
        print(f'  ✓ {item}')
    for item in manual_defaults:
        print(f'  ! da sistemare a mano: {item}')

    changed_files = set()
    finals = []
    total_removed = 0
    for round_number in range(1, 41):
        print(f'\n[giro {round_number}] dart analyze…')
        errors = analyze(fe_dir)
        fixable = [e for e in errors if e['code'] in REMOVE_ENCLOSING_CONST | DECLARATION_TO_FINAL]
        print(f'  errori sistemabili in questo giro: {len(fixable)}')
        if not fixable:
            break
        by_file = defaultdict(list)
        for error in fixable:
            by_file[error['file']].append(error)
        removed_this_round = 0
        for file, file_errors in by_file.items():
            path = Path(file)
            text = path.read_text(encoding='utf-8')
            mask = code_mask(text)
            edits = {}
            for error in file_errors:
                offset = offset_of(text, error['line'], error['col'])
                if error['code'] in DECLARATION_TO_FINAL:
                    start = declaration_const(text, mask, offset)
                    if start is not None:
                        edits[start] = 'final'
                        finals.append(f"{path}:{error['line']}")
                else:
                    start = enclosing_const(text, mask, offset)
                    if start is not None:
                        edits.setdefault(start, '')
            if not edits:
                continue
            for start in sorted(edits, reverse=True):
                replacement = edits[start]
                end = start + len('const')
                if replacement == '' and end < len(text) and text[end] == ' ':
                    end += 1
                text = text[:start] + replacement + text[end:]
            removed_this_round += len(edits)
            changed_files.add(str(path))
            if not dry_run:
                path.write_text(text, encoding='utf-8')
        total_removed += removed_this_round
        print(f'  const modificati: {removed_this_round}')
        if dry_run or removed_this_round == 0:
            break

    default_files = {item.split(':')[0] for item in fixed}
    all_changed = sorted(changed_files | default_files | set(colored))
    if all_changed and not dry_run:
        listing = fe_dir / 'tool' / 'appcolors_file_modificati.txt'
        listing.write_text('\n'.join(str(Path(f).resolve().relative_to(fe_dir.resolve().parent)) for f in all_changed) + '\n',
                           encoding='utf-8')
        print(f'Elenco dei file modificati: {listing}')
        print('Per annullare solo questi: git restore --source=HEAD -- $(cat fe/tool/appcolors_file_modificati.txt)')

    errors = analyze(fe_dir)
    manual = [e for e in errors if e['code'] in MANUAL]
    other = [e for e in errors if e['code'] not in MANUAL]
    print('\n=== Riepilogo ===')
    print(f"{'(prova) ' if dry_run else ''}const rimossi o cambiati: {total_removed} in {len(changed_files)} file")
    if finals:
        print('\nDichiarazioni diventate final (controlla che non siano campi static usati come colore fisso):')
        for item in finals:
            print(f'  • {item}')
    if manual:
        print('\nDa sistemare a mano:')
        for e in manual:
            print(f"  • {e['file']}:{e['line']} — {MANUAL[e['code']]}")
    if other:
        print(f'\nAltri errori ({len(other)}), primi 20:')
        for e in other[:20]:
            print(f"  • {e['code']} {e['file']}:{e['line']} {e['message']}")
    if not manual and not other:
        print('\n✓ Nessun errore di analisi rimasto.')


if __name__ == '__main__':
    main()
