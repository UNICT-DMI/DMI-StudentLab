import 'package:flutter/material.dart';

import 'package:fe/theme/app_palette.dart';
import 'package:fe/widgets/studentlab_ui/studentlab_ui.dart';
import 'package:fe/quiz/exercises/exercise_models.dart';

/// Editor dei dati specifici di ogni tipo. Ogni editor riceve i dati salvati
/// (anche nella forma già validata dal server) e restituisce la forma di
/// scrittura che il server valida di nuovo (services/exercise_types.py).
typedef DataChanged = void Function(Map<String, dynamic> data);

Widget typeEditor({
  required String type,
  required Map<String, dynamic> initial,
  required List<Map<String, dynamic>> attachments,
  required DataChanged onChanged,
}) {
  final Key key = ValueKey<String>('editor-$type');
  return switch (type) {
    'scelta' => SceltaEditor(key: key, initial: initial, attachments: attachments, onChanged: onChanged),
    'ordina' => OrdinaEditor(key: key, initial: initial, onChanged: onChanged),
    'abbina' => AbbinaEditor(key: key, initial: initial, onChanged: onChanged),
    'completa' => CompletaEditor(key: key, initial: initial, onChanged: onChanged),
    'errore' => ErroreEditor(key: key, initial: initial, onChanged: onChanged),
    'diagramma' => DiagrammaEditor(key: key, initial: initial, attachments: attachments, onChanged: onChanged),
    'grafo' => GrafoEditor(key: key, initial: initial, onChanged: onChanged),
    'flashcard' => FlashcardEditor(key: key, initial: initial, onChanged: onChanged),
    'traccia' => TracciaEditor(key: key, initial: initial, onChanged: onChanged),
    'numerica' => NumericaEditor(key: key, initial: initial, onChanged: onChanged),
    'codice' => CodiceEditor(key: key, initial: initial, onChanged: onChanged),
    // tipi generici (v24)
    'caso' => CasoEditor(key: key, initial: initial, onChanged: onChanged),
    'vero_falso' => VeroFalsoEditor(key: key, initial: initial, onChanged: onChanged),
    'categorizza' => CategorizzaEditor(key: key, initial: initial, onChanged: onChanged),
    'linea_tempo' => LineaTempoEditor(key: key, initial: initial, onChanged: onChanged),
    'risposta_breve' => RispostaBreveEditor(key: key, initial: initial, onChanged: onChanged),
    _ => const SizedBox.shrink(),
  };
}

InputDecoration _dec(String label, {String? hint, bool dense = true}) =>
    InputDecoration(labelText: label, hintText: hint, isDense: dense, border: const OutlineInputBorder());

List<String> _splitList(String text) =>
    text.split(RegExp(r'[,;\n]')).map((String s) => s.trim()).where((String s) => s.isNotEmpty).toList();

/// Una riga di testo con controller proprio (liste modificabili).
class _Row {
  final String key;
  final TextEditingController a;
  final TextEditingController b;
  bool flag;
  _Row(this.key, {String a = '', String b = '', this.flag = false})
      : a = TextEditingController(text: a),
        b = TextEditingController(text: b);
  void dispose() {
    a.dispose();
    b.dispose();
  }
}

int _seq = 0;
String _newKey() => 'k${DateTime.now().microsecondsSinceEpoch}${_seq++}';

Widget _section(BuildContext context, String title, List<Widget> children, {String? help}) {
  final p = context.palette;
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: p.eleganceMidnight,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: p.pureWhite.withValues(alpha: 0.07)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      SlOverline(title),
      if (help != null) ...<Widget>[
        const SizedBox(height: 4),
        Text(help, style: SlText.muted(p).copyWith(fontSize: 12)),
      ],
      const SizedBox(height: 10),
      ...children,
    ]),
  );
}

// ------------------------------------------------------------------- scelta
class SceltaEditor extends StatefulWidget {
  final Map<String, dynamic> initial;
  final List<Map<String, dynamic>> attachments;
  final DataChanged onChanged;
  const SceltaEditor({super.key, required this.initial, required this.attachments, required this.onChanged});
  @override
  State<SceltaEditor> createState() => _SceltaEditorState();
}

class _SceltaEditorState extends State<SceltaEditor> {
  final List<_Row> _options = <_Row>[];
  final Map<String, String?> _images = <String, String?>{};

  @override
  void initState() {
    super.initState();
    final Set<String> correct = asStringList(widget.initial['correct']).toSet();
    for (final Map<String, dynamic> o in asMapList(widget.initial['options'])) {
      final _Row row = _Row(o['id']?.toString() ?? _newKey(), a: o['text']?.toString() ?? '', flag: correct.contains(o['id']?.toString()));
      _images[row.key] = o['attachment_id']?.toString();
      _options.add(row);
    }
    while (_options.length < 4) {
      _options.add(_Row(String.fromCharCode(65 + _options.length)));
    }
    for (final _Row r in _options) {
      r.a.addListener(_emit);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    for (final _Row r in _options) {
      r.dispose();
    }
    super.dispose();
  }

  void _emit() {
    final List<_Row> used = _options.where((_Row r) => r.a.text.trim().isNotEmpty || _images[r.key] != null).toList();
    widget.onChanged(<String, dynamic>{
      'options': <Map<String, dynamic>>[
        for (final _Row r in used)
          <String, dynamic>{'id': r.key, 'text': r.a.text.trim(), if (_images[r.key] != null) 'attachment_id': _images[r.key]},
      ],
      'correct': used.where((_Row r) => r.flag).map((_Row r) => r.key).toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> images = widget.attachments
        .where((Map<String, dynamic> a) => (a['mime_type']?.toString() ?? '').startsWith('image/'))
        .toList();
    return _section(context, 'RISPOSTE', help: 'Segna una o più risposte giuste. Una risposta può avere un’immagine (caricala negli allegati).', <Widget>[
      for (final _Row r in _options)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: <Widget>[
            Checkbox(value: r.flag, onChanged: (bool? v) {
              setState(() => r.flag = v == true);
              _emit();
            }),
            Expanded(child: TextField(controller: r.a, decoration: _dec('Risposta ${r.key}'))),
            if (images.isNotEmpty) ...<Widget>[
              const SizedBox(width: 6),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String?>(
                  value: images.any((Map<String, dynamic> a) => a['id'] == _images[r.key]) ? _images[r.key] : null,
                  isExpanded: true,
                  decoration: _dec('Immagine'),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(value: null, child: Text('Nessuna')),
                    for (final Map<String, dynamic> a in images)
                      DropdownMenuItem<String?>(value: a['id'].toString(), child: Text('${a['original_name']}', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (String? v) {
                    setState(() => _images[r.key] = v);
                    _emit();
                  },
                ),
              ),
            ],
            IconButton(
              tooltip: 'Togli',
              onPressed: _options.length <= 2
                  ? null
                  : () {
                      setState(() {
                        _options.remove(r);
                        r.dispose();
                      });
                      _emit();
                    },
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),
          ]),
        ),
      if (_options.length < 12)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              String id = String.fromCharCode(65 + _options.length);
              while (_options.any((_Row r) => r.key == id)) {
                id = _newKey();
              }
              final _Row row = _Row(id)..a.addListener(_emit);
              setState(() => _options.add(row));
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Aggiungi risposta'),
          ),
        ),
    ]);
  }
}

// ------------------------------------------------------------------- ordina
class OrdinaEditor extends StatefulWidget {
  final Map<String, dynamic> initial;
  final DataChanged onChanged;
  const OrdinaEditor({super.key, required this.initial, required this.onChanged});
  @override
  State<OrdinaEditor> createState() => _OrdinaEditorState();
}

class _OrdinaEditorState extends State<OrdinaEditor> {
  final List<_Row> _steps = <_Row>[];

  @override
  void initState() {
    super.initState();
    final List<Map<String, dynamic>> items = asMapList(widget.initial['items']);
    final Map<String, String> texts = {for (final i in items) i['id'].toString(): i['text']?.toString() ?? ''};
    final List<String> order = asStringList(widget.initial['order']);
    for (final String id in order.isNotEmpty ? order : texts.keys.toList()) {
      _steps.add(_Row(_newKey(), a: texts[id] ?? ''));
    }
    while (_steps.length < 3) {
      _steps.add(_Row(_newKey()));
    }
    for (final _Row r in _steps) {
      r.a.addListener(_emit);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    for (final _Row r in _steps) {
      r.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged(<String, dynamic>{
        'items': _steps.map((_Row r) => r.a.text.trim()).where((String t) => t.isNotEmpty).toList(),
      });

  @override
  Widget build(BuildContext context) {
    return _section(context, 'PASSAGGI NELL’ORDINE GIUSTO', help: 'Lo studente li vedrà mescolati.', <Widget>[
      for (int i = 0; i < _steps.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: <Widget>[
            SizedBox(width: 26, child: Text('${i + 1}.')),
            Expanded(child: TextField(controller: _steps[i].a, decoration: _dec('Passaggio ${i + 1}'))),
            IconButton(
              tooltip: 'Su',
              onPressed: i == 0 ? null : () => setState(() {
                final _Row r = _steps.removeAt(i);
                _steps.insert(i - 1, r);
                _emit();
              }),
              icon: const Icon(Icons.arrow_upward_rounded, size: 18),
            ),
            IconButton(
              tooltip: 'Togli',
              onPressed: _steps.length <= 2 ? null : () => setState(() {
                _steps.removeAt(i).dispose();
                _emit();
              }),
              icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
            ),
          ]),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _steps.length >= 15 ? null : () => setState(() => _steps.add(_Row(_newKey())..a.addListener(_emit))),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Aggiungi passaggio'),
        ),
      ),
    ]);
  }
}

// ------------------------------------------------------------------- abbina
class AbbinaEditor extends StatefulWidget {
  final Map<String, dynamic> initial;
  final DataChanged onChanged;
  const AbbinaEditor({super.key, required this.initial, required this.onChanged});
  @override
  State<AbbinaEditor> createState() => _AbbinaEditorState();
}

class _AbbinaEditorState extends State<AbbinaEditor> {
  final List<_Row> _pairs = <_Row>[];
  late final TextEditingController _distractors;

  @override
  void initState() {
    super.initState();
    final dynamic rawPairs = widget.initial['pairs'];
    final List<String> extra = <String>[];
    if (rawPairs is Map) {
      final Map<String, String> right = {
        for (final r in asMapList(widget.initial['right'])) r['id'].toString(): r['text']?.toString() ?? ''
      };
      for (final Map<String, dynamic> l in asMapList(widget.initial['left'])) {
        _pairs.add(_Row(_newKey(), a: l['text']?.toString() ?? '', b: right[rawPairs[l['id'].toString()]?.toString()] ?? ''));
      }
      final Set<String> used = rawPairs.values.map((dynamic v) => v.toString()).toSet();
      extra.addAll(right.entries.where((MapEntry<String, String> e) => !used.contains(e.key)).map((e) => e.value));
    } else {
      for (final Map<String, dynamic> p in asMapList(rawPairs)) {
        _pairs.add(_Row(_newKey(), a: p['left']?.toString() ?? '', b: p['right']?.toString() ?? ''));
      }
      extra.addAll(asStringList(widget.initial['distractors']));
    }
    while (_pairs.length < 3) {
      _pairs.add(_Row(_newKey()));
    }
    _distractors = TextEditingController(text: extra.join('\n'))..addListener(_emit);
    for (final _Row r in _pairs) {
      r.a.addListener(_emit);
      r.b.addListener(_emit);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    for (final _Row r in _pairs) {
      r.dispose();
    }
    _distractors.dispose();
    super.dispose();
  }

  void _emit() => widget.onChanged(<String, dynamic>{
        'pairs': <Map<String, String>>[
          for (final _Row r in _pairs)
            if (r.a.text.trim().isNotEmpty || r.b.text.trim().isNotEmpty) <String, String>{'left': r.a.text.trim(), 'right': r.b.text.trim()},
        ],
        'distractors': _distractors.text.split('\n').map((String s) => s.trim()).where((String s) => s.isNotEmpty).toList(),
      });

  @override
  Widget build(BuildContext context) {
    return _section(context, 'COPPIE', help: 'A sinistra il termine, a destra ciò che gli corrisponde.', <Widget>[
      for (int i = 0; i < _pairs.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: <Widget>[
            Expanded(flex: 2, child: TextField(controller: _pairs[i].a, decoration: _dec('Sinistra ${i + 1}'))),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_forward_rounded, size: 18)),
            Expanded(flex: 3, child: TextField(controller: _pairs[i].b, decoration: _dec('Destra ${i + 1}'))),
            IconButton(
              tooltip: 'Togli',
              onPressed: _pairs.length <= 2 ? null : () => setState(() {
                _pairs.removeAt(i).dispose();
                _emit();
              }),
              icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
            ),
          ]),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _pairs.length >= 12
              ? null
              : () => setState(() => _pairs.add(_Row(_newKey())
                ..a.addListener(_emit)
                ..b.addListener(_emit))),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Aggiungi coppia'),
        ),
      ),
      const SizedBox(height: 6),
      TextField(controller: _distractors, minLines: 1, maxLines: 4,
          decoration: _dec('Elementi di disturbo a destra (uno per riga, facoltativi)')),
    ]);
  }
}

// ------------------------------------------------------------------- completa
class CompletaEditor extends StatefulWidget {
  final Map<String, dynamic> initial;
  final DataChanged onChanged;
  const CompletaEditor({super.key, required this.initial, required this.onChanged});
  @override
  State<CompletaEditor> createState() => _CompletaEditorState();
}

class _CompletaEditorState extends State<CompletaEditor> {
  static final RegExp _blank = RegExp(r'\[\[([A-Za-z0-9_-]{1,20})\]\]');
  late final TextEditingController _text = TextEditingController(text: widget.initial['text']?.toString() ?? '');
  late final TextEditingController _bank = TextEditingController(text: asStringList(widget.initial['bank']).join(', '));
  final Map<String, _Row> _blanks = <String, _Row>{};
  final Map<String, TextEditingController> _tolerance = <String, TextEditingController>{};
  bool _caseSensitive = false;

  @override
  void initState() {
    super.initState();
    _caseSensitive = widget.initial['case_sensitive'] == true;
    for (final Map<String, dynamic> b in asMapList(widget.initial['blanks'])) {
      final String id = b['id'].toString();
      _blanks[id] = _Row(id, a: asStringList(b['accepted']).join(', '), flag: b['numeric'] == true);
      _tolerance[id] = TextEditingController(text: '${b['tolerance'] ?? ''}' == '0.0' ? '' : '${b['tolerance'] ?? ''}');
    }
    _text.addListener(_sync);
    _bank.addListener(_emit);
    _sync();
  }

  @override
  void dispose() {
    _text.dispose();
    _bank.dispose();
    for (final _Row r in _blanks.values) {
      r.dispose();
    }
    for (final TextEditingController c in _tolerance.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _sync() {
    final List<String> ids = _blank.allMatches(_text.text).map((RegExpMatch m) => m.group(1)!).toList();
    bool changed = false;
    for (final String id in ids) {
      if (!_blanks.containsKey(id)) {
        _blanks[id] = _Row(id)..a.addListener(_emit);
        _tolerance[id] = TextEditingController()..addListener(_emit);
        changed = true;
      } else {
        _blanks[id]!.a.removeListener(_emit);
        _blanks[id]!.a.addListener(_emit);
        _tolerance[id]!.removeListener(_emit);
        _tolerance[id]!.addListener(_emit);
      }
    }
    if (changed && mounted) setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
      _emit();
    });
  }

  void _insertBlank() {
    int n = 1;
    while (_text.text.contains('[[$n]]')) {
      n++;
    }
    final TextSelection selection = _text.selection;
    final String marker = '[[$n]]';
    final int at = selection.isValid ? selection.start : _text.text.length;
    _text.value = TextEditingValue(
      text: _text.text.replaceRange(at, selection.isValid ? selection.end : at, marker),
      selection: TextSelection.collapsed(offset: at + marker.length),
    );
  }

  void _emit() {
    final List<String> ids = _blank.allMatches(_text.text).map((RegExpMatch m) => m.group(1)!).toList();
    widget.onChanged(<String, dynamic>{
      'text': _text.text,
      'blanks': <Map<String, dynamic>>[
        for (final String id in ids)
          if (_blanks[id] != null)
            <String, dynamic>{
              'id': id,
              'accepted': _splitList(_blanks[id]!.a.text),
              'numeric': _blanks[id]!.flag,
              'tolerance': double.tryParse(_tolerance[id]!.text.replaceAll(',', '.')) ?? 0,
            },
      ],
      'bank': _splitList(_bank.text),
      'case_sensitive': _caseSensitive,
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<String> ids = _blank.allMatches(_text.text).map((RegExpMatch m) => m.group(1)!).toList();
    return _section(context, 'TESTO CON GLI SPAZI', help: 'Scrivi il testo e metti [[1]], [[2]]… dove lo studente deve completare.', <Widget>[
      TextField(controller: _text, minLines: 3, maxLines: 8, decoration: _dec('Testo', hint: 'Un /26 lascia [[1]] bit per gli host')),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(onPressed: _insertBlank, icon: const Icon(Icons.add_box_outlined), label: const Text('Inserisci uno spazio')),
      ),
      for (final String id in ids)
        if (_blanks[id] != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: <Widget>[
              SizedBox(width: 52, child: Text('[[$id]]', style: const TextStyle(fontFamily: 'monospace'))),
              Expanded(child: TextField(controller: _blanks[id]!.a, decoration: _dec('Risposte ammesse (separate da virgola)'))),
              const SizedBox(width: 6),
              FilterChip(
                label: const Text('Numero'),
                selected: _blanks[id]!.flag,
                onSelected: (bool v) {
                  setState(() => _blanks[id]!.flag = v);
                  _emit();
                },
              ),
              if (_blanks[id]!.flag) ...<Widget>[
                const SizedBox(width: 6),
                SizedBox(width: 90, child: TextField(controller: _tolerance[id], decoration: _dec('± tolleranza'))),
              ],
            ]),
          ),
      const SizedBox(height: 6),
      TextField(controller: _bank, decoration: _dec('Parole da trascinare (facoltative, separate da virgola)')),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _caseSensitive,
        title: const Text('Distingui maiuscole e minuscole'),
        onChanged: (bool v) {
          setState(() => _caseSensitive = v);
          _emit();
        },
      ),
    ]);
  }
}

// ------------------------------------------------------------------- errore
class ErroreEditor extends StatefulWidget {
  final Map<String, dynamic> initial;
  final DataChanged onChanged;
  const ErroreEditor({super.key, required this.initial, required this.onChanged});
  @override
  State<ErroreEditor> createState() => _ErroreEditorState();
}

class _ErroreEditorState extends State<ErroreEditor> {
  late final TextEditingController _lines = TextEditingController(text: asStringList(widget.initial['lines']).join('\n'));
  late final TextEditingController _errors = TextEditingController(text: asStringList(widget.initial['error_lines']).join(', '));
  late final TextEditingController _language = TextEditingController(text: widget.initial['language']?.toString() ?? '');
  late final TextEditingController _fix = TextEditingController(text: widget.initial['fix']?.toString() ?? '');
  final List<_Row> _reasons = <_Row>[];

  @override
  void initState() {
    super.initState();
    final String? correct = widget.initial['correct_reason']?.toString();
    for (final Map<String, dynamic> r in asMapList(widget.initial['reasons'])) {
      _reasons.add(_Row(r['id'].toString(), a: r['text']?.toString() ?? '', flag: r['id'].toString() == correct));
    }
    for (final TextEditingController c in <TextEditingController>[_lines, _errors, _language, _fix]) {
      c.addListener(_emit);
    }
    for (final _Row r in _reasons) {
      r.a.addListener(_emit);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[_lines, _errors, _language, _fix]) {
      c.dispose();
    }
    for (final _Row r in _reasons) {
      r.dispose();
    }
    super.dispose();
  }

  void _emit() {
    final List<_Row> reasons = _reasons.where((_Row r) => r.a.text.trim().isNotEmpty).toList();
    widget.onChanged(<String, dynamic>{
      'lines': _lines.text.split('\n'),
      'language': _language.text.trim(),
      'error_lines': _splitList(_errors.text).map(int.tryParse).whereType<int>().toList(),
      'reasons': <Map<String, String>>[for (final _Row r in reasons) <String, String>{'id': r.key, 'text': r.a.text.trim()}],
      if (reasons.any((_Row r) => r.flag)) 'correct_reason': reasons.firstWhere((_Row r) => r.flag).key,
      'fix': _fix.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return _section(context, 'RIGHE E ERRORE', help: 'Una riga per riga di codice o di calcolo. Le righe si contano da 1.', <Widget>[
      TextField(controller: _language, decoration: _dec('Linguaggio (facoltativo: c, python, pseudocodice…)')),
      const SizedBox(height: 8),
      TextField(
        controller: _lines,
        minLines: 5,
        maxLines: 16,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        decoration: _dec('Righe', dense: false),
      ),
      const SizedBox(height: 8),
      TextField(controller: _errors, decoration: _dec('Numero delle righe con l’errore (es. 3 oppure 3, 5)')),
      const SizedBox(height: 12),
      Text('Motivi (facoltativi): lo studente sceglie perché è sbagliata', style: SlText.muted(context.palette).copyWith(fontSize: 12)),
      const SizedBox(height: 6),
      for (final _Row r in _reasons)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: <Widget>[
            Radio<String>(
              value: r.key,
              groupValue: _reasons.where((_Row x) => x.flag).map((_Row x) => x.key).firstOrNull,
              onChanged: (String? v) {
                setState(() {
                  for (final _Row x in _reasons) {
                    x.flag = x.key == v;
                  }
                });
                _emit();
              },
            ),
            Expanded(child: TextField(controller: r.a, decoration: _dec('Motivo'))),
            IconButton(
              tooltip: 'Togli',
              onPressed: () => setState(() {
                _reasons.remove(r);
                r.dispose();
                _emit();
              }),
              icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
            ),
          ]),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _reasons.length >= 6
              ? null
              : () => setState(() => _reasons.add(_Row(String.fromCharCode(97 + _reasons.length))..a.addListener(_emit))),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Aggiungi motivo'),
        ),
      ),
      TextField(controller: _fix, decoration: _dec('Riga corretta (mostrata dopo la risposta)')),
    ]);
  }
}

// ------------------------------------------------------------------- flashcard
class FlashcardEditor extends StatefulWidget {
  final Map<String, dynamic> initial;
  final DataChanged onChanged;
  const FlashcardEditor({super.key, required this.initial, required this.onChanged});
  @override
  State<FlashcardEditor> createState() => _FlashcardEditorState();
}

class _FlashcardEditorState extends State<FlashcardEditor> {
  late final TextEditingController _front = TextEditingController(text: widget.initial['front']?.toString() ?? '')..addListener(_emit);
  late final TextEditingController _back = TextEditingController(text: widget.initial['back']?.toString() ?? '')..addListener(_emit);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    super.dispose();
  }

  void _emit() => widget.onChanged(<String, dynamic>{'front': _front.text.trim(), 'back': _back.text.trim()});

  @override
  Widget build(BuildContext context) {
    return _section(context, 'SCHEDA',
        help: 'Le flashcard si creano da sole dai termini approvati del Dizionario: qui puoi aggiungerne di tue.', <Widget>[
      TextField(controller: _front, decoration: _dec('Fronte')),
      const SizedBox(height: 8),
      TextField(controller: _back, minLines: 3, maxLines: 8, decoration: _dec('Retro', dense: false)),
    ]);
  }
}

// ------------------------------------------------------------------- numerica
class NumericaEditor extends StatefulWidget {
  final Map<String, dynamic> initial;
  final DataChanged onChanged;
  const NumericaEditor({super.key, required this.initial, required this.onChanged});
  @override
  State<NumericaEditor> createState() => _NumericaEditorState();
}

class _NumericaEditorState extends State<NumericaEditor> {
  final List<List<TextEditingController>> _steps = <List<TextEditingController>>[];
  static const List<String> _fields = <String>['label', 'answer', 'tolerance', 'unit', 'hint', 'check'];

  @override
  void initState() {
    super.initState();
    for (final Map<String, dynamic> s in asMapList(widget.initial['steps'])) {
      _add(s);
    }
    if (_steps.isEmpty) _add(const <String, dynamic>{});
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  void _add(Map<String, dynamic> s) {
    _steps.add(<TextEditingController>[
      for (final String f in _fields)
        TextEditingController(text: s[f] == null || '${s[f]}' == '0.0' && f == 'tolerance' ? '' : _fmt(s[f]))..addListener(_emit),
    ]);
  }

  String _fmt(dynamic v) {
    if (v is double && v == v.roundToDouble()) return v.toInt().toString();
    return '$v';
  }

  @override
  void dispose() {
    for (final List<TextEditingController> s in _steps) {
      for (final TextEditingController c in s) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _emit() => widget.onChanged(<String, dynamic>{
        'steps': <Map<String, dynamic>>[
          for (int i = 0; i < _steps.length; i++)
            <String, dynamic>{
              'id': 's${i + 1}',
              'label': _steps[i][0].text.trim(),
              'answer': _steps[i][1].text.trim(),
              'tolerance': double.tryParse(_steps[i][2].text.replaceAll(',', '.')) ?? 0,
              'unit': _steps[i][3].text.trim(),
              'hint': _steps[i][4].text.trim(),
              'check': _steps[i][5].text.trim(),
            },
        ],
      });

  @override
  Widget build(BuildContext context) {
    return _section(context, 'PASSAGGI', help: 'Uno o più valori da calcolare. La tolleranza è assoluta (es. 0,01).', <Widget>[
      for (int i = 0; i < _steps.length; i++)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: context.palette.pureWhite.withValues(alpha: 0.08)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: <Widget>[
            Row(children: <Widget>[
              Expanded(child: TextField(controller: _steps[i][0], decoration: _dec('Passaggio ${i + 1}: cosa calcolare'))),
              IconButton(
                tooltip: 'Togli',
                onPressed: _steps.length <= 1 ? null : () => setState(() {
                  for (final TextEditingController c in _steps.removeAt(i)) {
                    c.dispose();
                  }
                  _emit();
                }),
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: <Widget>[
              Expanded(child: TextField(controller: _steps[i][1], decoration: _dec('Risultato'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _steps[i][2], decoration: _dec('± tolleranza'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _steps[i][3], decoration: _dec('Unità'))),
            ]),
            const SizedBox(height: 8),
            TextField(controller: _steps[i][4], decoration: _dec('Suggerimento (facoltativo)')),
            const SizedBox(height: 8),
            TextField(controller: _steps[i][5], decoration: _dec('Verifica mostrata se giusto (es. 2³ = 8 ≥ 6)')),
          ]),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _steps.length >= 8 ? null : () => setState(() => _add(const <String, dynamic>{})),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Aggiungi passaggio'),
        ),
      ),
    ]);
  }
}

// ------------------------------------------------------------------- codice
class CodiceEditor extends StatefulWidget {
  final Map<String, dynamic> initial;
  final DataChanged onChanged;
  const CodiceEditor({super.key, required this.initial, required this.onChanged});
  @override
  State<CodiceEditor> createState() => _CodiceEditorState();
}

class _CodiceEditorState extends State<CodiceEditor> {
  late final TextEditingController _function = TextEditingController(text: widget.initial['function']?.toString() ?? '');
  late final TextEditingController _starter = TextEditingController(text: widget.initial['starter']?.toString() ?? '');
  late final TextEditingController _forbidden =
      TextEditingController(text: asStringList(widget.initial['forbidden']).join(', '));
  final List<_Row> _tests = <_Row>[];

  @override
  void initState() {
    super.initState();
    for (final Map<String, dynamic> t in asMapList(widget.initial['tests'])) {
      _tests.add(_Row(_newKey(), a: t['call']?.toString() ?? '', b: t['expected']?.toString() ?? '', flag: t['hidden'] == true));
    }
    while (_tests.length < 2) {
      _tests.add(_Row(_newKey(), flag: _tests.isNotEmpty));
    }
    for (final TextEditingController c in <TextEditingController>[_function, _starter, _forbidden]) {
      c.addListener(_emit);
    }
    for (final _Row r in _tests) {
      r.a.addListener(_emit);
      r.b.addListener(_emit);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[_function, _starter, _forbidden]) {
      c.dispose();
    }
    for (final _Row r in _tests) {
      r.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged(<String, dynamic>{
        'language': 'python',
        'function': _function.text.trim(),
        'starter': _starter.text,
        'forbidden': _splitList(_forbidden.text),
        'tests': <Map<String, dynamic>>[
          for (final _Row r in _tests)
            if (r.a.text.trim().isNotEmpty) <String, dynamic>{'call': r.a.text.trim(), 'expected': r.b.text.trim(), 'hidden': r.flag},
        ],
      });

  @override
  Widget build(BuildContext context) {
    return _section(context, 'CODICE E TEST (PYTHON)',
        help: 'Il codice dello studente gira solo nel servizio isolato. Almeno un test visibile; i test nascosti evitano soluzioni “su misura”.',
        <Widget>[
          TextField(controller: _function, decoration: _dec('Nome della funzione (es. massimo)')),
          const SizedBox(height: 8),
          TextField(
            controller: _starter,
            minLines: 4,
            maxLines: 12,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: _dec('Codice di partenza', dense: false),
          ),
          const SizedBox(height: 8),
          TextField(controller: _forbidden, decoration: _dec('Da non usare (es. max(, sorted()')),
          const SizedBox(height: 12),
          for (final _Row r in _tests)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: <Widget>[
                Expanded(flex: 3, child: TextField(controller: r.a, style: const TextStyle(fontFamily: 'monospace'),
                    decoration: _dec('Chiamata (es. massimo([3, 9, 2]))'))),
                const SizedBox(width: 6),
                Expanded(flex: 2, child: TextField(controller: r.b, style: const TextStyle(fontFamily: 'monospace'),
                    decoration: _dec('Risultato atteso'))),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('Nascosto'),
                  selected: r.flag,
                  onSelected: (bool v) {
                    setState(() => r.flag = v);
                    _emit();
                  },
                ),
                IconButton(
                  tooltip: 'Togli',
                  onPressed: _tests.length <= 1 ? null : () => setState(() {
                    _tests.remove(r);
                    r.dispose();
                    _emit();
                  }),
                  icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                ),
              ]),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _tests.length >= 20
                  ? null
                  : () => setState(() => _tests.add(_Row(_newKey())
                    ..a.addListener(_emit)
                    ..b.addListener(_emit))),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Aggiungi test'),
            ),
          ),
        ]);
  }
}

// ------------------------------------------------------------------- grafo
class GrafoEditor extends StatefulWidget {
  final Map<String, dynamic> initial;
  final DataChanged onChanged;
  const GrafoEditor({super.key, required this.initial, required this.onChanged});
  @override
  State<GrafoEditor> createState() => _GrafoEditorState();
}

class _GrafoEditorState extends State<GrafoEditor> {
  String _task = 'dijkstra';
  late final TextEditingController _nodes;
  late final TextEditingController _edges;
  late final TextEditingController _source;

  @override
  void initState() {
    super.initState();
    _task = widget.initial['task']?.toString() ?? 'dijkstra';
    _nodes = TextEditingController(
        text: asMapList(widget.initial['nodes']).map((Map<String, dynamic> n) => '${n['id']} ${n['x']} ${n['y']}').join('\n'))
      ..addListener(_emit);
    _edges = TextEditingController(
        text: asMapList(widget.initial['edges']).map((Map<String, dynamic> e) => '${e['from']} ${e['to']} ${e['w'] ?? 1}').join('\n'))
      ..addListener(_emit);
    _source = TextEditingController(text: widget.initial['source']?.toString() ?? '')..addListener(_emit);
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    _nodes.dispose();
    _edges.dispose();
    _source.dispose();
    super.dispose();
  }

  void _emit() {
    final List<Map<String, dynamic>> nodes = <Map<String, dynamic>>[];
    for (final String line in _nodes.text.split('\n')) {
      final List<String> parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length >= 3) {
        nodes.add(<String, dynamic>{
          'id': parts[0],
          'label': parts[0],
          'x': double.tryParse(parts[1].replaceAll(',', '.')) ?? 0.5,
          'y': double.tryParse(parts[2].replaceAll(',', '.')) ?? 0.5,
        });
      }
    }
    final List<Map<String, dynamic>> edges = <Map<String, dynamic>>[];
    for (final String line in _edges.text.split('\n')) {
      final List<String> parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        edges.add(<String, dynamic>{'from': parts[0], 'to': parts[1], 'w': parts.length > 2 ? int.tryParse(parts[2]) ?? 1 : 1});
      }
    }
    widget.onChanged(<String, dynamic>{
      'task': _task,
      'directed': false,
      'nodes': nodes,
      'edges': edges,
      'source': _source.text.trim().isEmpty && nodes.isNotEmpty ? nodes.first['id'] : _source.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return _section(context, 'GRAFO', help: 'Più semplice con “Genera varianti”: ogni studente riceve un grafo diverso. Qui puoi disegnarne uno fisso.', <Widget>[
      SegmentedButton<String>(
        segments: const <ButtonSegment<String>>[
          ButtonSegment<String>(value: 'dijkstra', label: Text('Dijkstra')),
          ButtonSegment<String>(value: 'bfs', label: Text('BFS')),
          ButtonSegment<String>(value: 'dfs', label: Text('DFS')),
        ],
        selected: <String>{_task},
        onSelectionChanged: (Set<String> v) {
          setState(() => _task = v.first);
          _emit();
        },
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _nodes,
        minLines: 3,
        maxLines: 10,
        style: const TextStyle(fontFamily: 'monospace'),
        decoration: _dec('Nodi: nome x y (x e y tra 0 e 1), uno per riga', hint: 'u 0.1 0.5\nv 0.4 0.2', dense: false),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _edges,
        minLines: 3,
        maxLines: 12,
        style: const TextStyle(fontFamily: 'monospace'),
        decoration: _dec('Archi: da a peso, uno per riga', hint: 'u v 2\nv w 1', dense: false),
      ),
      const SizedBox(height: 8),
      TextField(controller: _source, decoration: _dec('Nodo di partenza (vuoto = il primo)')),
    ]);
  }
}

// ------------------------------------------------------------------- traccia
class TracciaEditor extends StatefulWidget {
  final Map<String, dynamic> initial;
  final DataChanged onChanged;
  const TracciaEditor({super.key, required this.initial, required this.onChanged});
  @override
  State<TracciaEditor> createState() => _TracciaEditorState();
}

/// Tabella: una cella che inizia con "?" è da completare.
///   ?SYN_SENT                         risposta libera
///   ?SYN_SENT | LISTEN, ESTABLISHED   a scelta (la prima è quella giusta)
class _TracciaEditorState extends State<TracciaEditor> {
  late final TextEditingController _columns;
  late final TextEditingController _rows;
  bool _rowByRow = true;

  @override
  void initState() {
    super.initState();
    _rowByRow = widget.initial['row_by_row'] != false;
    _columns = TextEditingController(text: asStringList(widget.initial['columns']).join(' ; '))..addListener(_emit);
    final List<String> lines = <String>[];
    for (final dynamic row in (widget.initial['rows'] as List?) ?? const <dynamic>[]) {
      if (row is! List) continue;
      lines.add(row.map((dynamic cell) {
        if (cell is Map) {
          final List<String> accepted = asStringList(cell['accepted']);
          final List<String> others = asStringList(cell['options']).where((String o) => !accepted.contains(o)).toList();
          return '?${accepted.join(' / ')}${others.isEmpty ? '' : ' | ${others.join(', ')}'}';
        }
        return '$cell';
      }).join(' ; '));
    }
    _rows = TextEditingController(text: lines.join('\n'))..addListener(_emit);
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    _columns.dispose();
    _rows.dispose();
    super.dispose();
  }

  void _emit() {
    final List<String> columns = _columns.text.split(';').map((String s) => s.trim()).where((String s) => s.isNotEmpty).toList();
    final List<List<dynamic>> rows = <List<dynamic>>[];
    for (final String line in _rows.text.split('\n')) {
      if (line.trim().isEmpty) continue;
      rows.add(line.split(';').map((String raw) {
        final String cell = raw.trim();
        if (!cell.startsWith('?')) return cell;
        final List<String> parts = cell.substring(1).split('|');
        final List<String> accepted = parts.first.split('/').map((String s) => s.trim()).where((String s) => s.isNotEmpty).toList();
        final List<String> others = parts.length > 1 ? _splitList(parts[1]) : <String>[];
        return <String, dynamic>{
          'blank': true,
          'accepted': accepted,
          'options': others.isEmpty ? <String>[] : <String>[...accepted.take(1), ...others],
        };
      }).toList());
    }
    widget.onChanged(<String, dynamic>{'columns': columns, 'rows': rows, 'row_by_row': _rowByRow});
  }

  @override
  Widget build(BuildContext context) {
    return _section(context, 'TABELLA', help: 'Separa le celle con “;”. Una cella che inizia con “?” è da completare: '
        '“?SYN_SENT” (risposta libera) oppure “?SYN_SENT | LISTEN, ESTABLISHED” (a scelta).', <Widget>[
      TextField(controller: _columns, decoration: _dec('Colonne', hint: 'T ; Ricevuto ; Inviato ; Stato')),
      const SizedBox(height: 8),
      TextField(
        controller: _rows,
        minLines: 4,
        maxLines: 16,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        decoration: _dec('Righe (una per riga)', hint: '0 ; – ; SYN ; ?SYN_SENT | LISTEN, ESTABLISHED', dense: false),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _rowByRow,
        title: const Text('Una riga alla volta (ogni riga giusta sblocca la successiva)'),
        onChanged: (bool v) {
          setState(() => _rowByRow = v);
          _emit();
        },
      ),
    ]);
  }
}

// ------------------------------------------------------------------- diagramma
class DiagrammaEditor extends StatefulWidget {
  final Map<String, dynamic> initial;
  final List<Map<String, dynamic>> attachments;
  final DataChanged onChanged;
  const DiagrammaEditor({super.key, required this.initial, required this.attachments, required this.onChanged});
  @override
  State<DiagrammaEditor> createState() => _DiagrammaEditorState();
}

/// Due modi: un diagramma disegnato dall'app (nodi e collegamenti) oppure
/// un'immagine caricata con le zone da toccare (coordinate tra 0 e 1).
class _DiagrammaEditorState extends State<DiagrammaEditor> {
  bool _image = false;
  String? _imageId;
  late final TextEditingController _nodes;
  late final TextEditingController _edges;
  late final TextEditingController _regions;
  late final TextEditingController _correct;
  late final TextEditingController _ratio;

  static const String _shapesHelp = 'Forme: rect, circle, cloud, device. Icone: computer, switch, router, cloud, server, phone, database, firewall, cpu.';

  @override
  void initState() {
    super.initState();
    final Map<String, dynamic> scene = asMap(widget.initial['scene']);
    _imageId = widget.initial['image_attachment_id']?.toString();
    _image = scene.isEmpty && _imageId != null;
    _nodes = TextEditingController(
        text: asMapList(scene['nodes'])
            .map((Map<String, dynamic> n) => '${n['id']} ; ${n['label']} ; ${n['x']} ; ${n['y']} ; ${n['shape'] ?? 'rect'} ; ${n['icon'] ?? ''}')
            .join('\n'))
      ..addListener(_emit);
    _edges = TextEditingController(
        text: asMapList(scene['edges']).map((Map<String, dynamic> e) => '${e['from']} ${e['to']}').join('\n'))
      ..addListener(_emit);
    _regions = TextEditingController(
        text: _image
            ? asMapList(widget.initial['regions'])
                .map((Map<String, dynamic> r) => '${r['id']} ; ${r['x']} ; ${r['y']} ; ${r['w']} ; ${r['h']} ; ${r['label'] ?? ''}')
                .join('\n')
            : '')
      ..addListener(_emit);
    _correct = TextEditingController(text: asStringList(widget.initial['correct']).join(', '))..addListener(_emit);
    _ratio = TextEditingController(text: '${scene['ratio'] ?? 1.6}')..addListener(_emit);
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    for (final TextEditingController c in <TextEditingController>[_nodes, _edges, _regions, _correct, _ratio]) {
      c.dispose();
    }
    super.dispose();
  }

  double _d(String v) => double.tryParse(v.trim().replaceAll(',', '.')) ?? 0;

  void _emit() {
    final Map<String, dynamic> data = <String, dynamic>{'correct': _splitList(_correct.text)};
    if (_image) {
      data['image_attachment_id'] = _imageId;
      data['regions'] = <Map<String, dynamic>>[
        for (final String line in _regions.text.split('\n'))
          if (line.split(';').length >= 5)
            () {
              final List<String> p = line.split(';');
              return <String, dynamic>{
                'id': p[0].trim(), 'x': _d(p[1]), 'y': _d(p[2]), 'w': _d(p[3]), 'h': _d(p[4]),
                if (p.length > 5) 'label': p[5].trim(),
              };
            }(),
      ];
    } else {
      data['scene'] = <String, dynamic>{
        'ratio': _d(_ratio.text) <= 0 ? 1.6 : _d(_ratio.text),
        'nodes': <Map<String, dynamic>>[
          for (final String line in _nodes.text.split('\n'))
            if (line.split(';').length >= 4)
              () {
                final List<String> p = line.split(';');
                return <String, dynamic>{
                  'id': p[0].trim(), 'label': p[1].trim(), 'x': _d(p[2]), 'y': _d(p[3]),
                  'shape': p.length > 4 && p[4].trim().isNotEmpty ? p[4].trim() : 'rect',
                  'icon': p.length > 5 ? p[5].trim() : '',
                };
              }(),
        ],
        'edges': <Map<String, dynamic>>[
          for (final String line in _edges.text.split('\n'))
            if (line.trim().split(RegExp(r'\s+')).length >= 2)
              <String, dynamic>{'from': line.trim().split(RegExp(r'\s+'))[0], 'to': line.trim().split(RegExp(r'\s+'))[1]},
        ],
      };
    }
    widget.onChanged(data);
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> images = widget.attachments
        .where((Map<String, dynamic> a) => (a['mime_type']?.toString() ?? '').startsWith('image/'))
        .toList();
    return _section(context, 'DIAGRAMMA', <Widget>[
      SegmentedButton<bool>(
        segments: const <ButtonSegment<bool>>[
          ButtonSegment<bool>(value: false, label: Text('Disegnato'), icon: Icon(Icons.account_tree_outlined)),
          ButtonSegment<bool>(value: true, label: Text('Immagine'), icon: Icon(Icons.image_outlined)),
        ],
        selected: <bool>{_image},
        onSelectionChanged: (Set<bool> v) {
          setState(() => _image = v.first);
          _emit();
        },
      ),
      const SizedBox(height: 10),
      if (_image) ...<Widget>[
        if (images.isEmpty)
          Text('Carica prima un’immagine negli allegati (ruolo “diagramma”).', style: SlText.muted(context.palette))
        else
          DropdownButtonFormField<String?>(
            value: images.any((Map<String, dynamic> a) => a['id'] == _imageId) ? _imageId : null,
            isExpanded: true,
            decoration: _dec('Immagine'),
            items: <DropdownMenuItem<String?>>[
              for (final Map<String, dynamic> a in images)
                DropdownMenuItem<String?>(value: a['id'].toString(), child: Text('${a['original_name']}', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (String? v) {
              setState(() => _imageId = v);
              _emit();
            },
          ),
        const SizedBox(height: 8),
        TextField(
          controller: _regions,
          minLines: 3,
          maxLines: 10,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: _dec('Zone: id ; x ; y ; larghezza ; altezza ; nome (valori tra 0 e 1)',
              hint: 'router ; 0.55 ; 0.40 ; 0.15 ; 0.20 ; Router', dense: false),
        ),
      ] else ...<Widget>[
        TextField(
          controller: _nodes,
          minLines: 3,
          maxLines: 12,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: _dec('Elementi: id ; nome ; x ; y ; forma ; icona', hint: 'rt ; Router ; 0.6 ; 0.5 ; circle ; router', dense: false),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text(_shapesHelp, style: SlText.muted(context.palette).copyWith(fontSize: 11)),
        ),
        TextField(
          controller: _edges,
          minLines: 2,
          maxLines: 10,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: _dec('Collegamenti: id id, uno per riga', hint: 'sw rt', dense: false),
        ),
        const SizedBox(height: 8),
        TextField(controller: _ratio, decoration: _dec('Proporzione larghezza/altezza (es. 1.6)')),
      ],
      const SizedBox(height: 8),
      TextField(controller: _correct, decoration: _dec('Elementi o zone giusti (id separati da virgola)')),
    ]);
  }
}


// =================================================================== tipi generici (v24)
String _num(dynamic v) {
  if (v == null) return '';
  if (v is double && v == v.roundToDouble()) return v.toInt().toString();
  return '$v';
}

Widget _removeButton({required bool enabled, required VoidCallback onPressed, String tooltip = 'Togli'}) => IconButton(
      tooltip: tooltip,
      onPressed: enabled ? onPressed : null,
      icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
    );

// ------------------------------------------------------------------- caso pratico a passi
class _CasoStep {
  String kind;
  int weight;
  final TextEditingController prompt;
  final TextEditingController note;
  final TextEditingController answer;
  final TextEditingController tolerance;
  final TextEditingController unit;
  final List<_Row> options;
  bool multiple;
  double tolerancePct;

  _CasoStep({this.tolerancePct = 0, this.kind = 'scelta', this.weight = 1, String prompt = '', String note = '', String answer = '',
      String tolerance = '', String unit = '', List<_Row>? options, this.multiple = false})
      : prompt = TextEditingController(text: prompt),
        note = TextEditingController(text: note),
        answer = TextEditingController(text: answer),
        tolerance = TextEditingController(text: tolerance),
        unit = TextEditingController(text: unit),
        options = options ?? <_Row>[];

  void listen(VoidCallback f) {
    for (final TextEditingController c in <TextEditingController>[prompt, note, answer, tolerance, unit]) {
      c.addListener(f);
    }
    for (final _Row r in options) {
      r.a.addListener(f);
    }
  }

  void dispose() {
    for (final TextEditingController c in <TextEditingController>[prompt, note, answer, tolerance, unit]) {
      c.dispose();
    }
    for (final _Row r in options) {
      r.dispose();
    }
  }
}

/// Caso pratico: il testo del caso e da 1 a 8 passi (domanda a scelta o numerica).
/// Modelli pronti: caso clinico, caso giuridico, caso aziendale, caso didattico.
class CasoEditor extends StatefulWidget {
  final Map<String, dynamic> initial;
  final DataChanged onChanged;
  const CasoEditor({super.key, required this.initial, required this.onChanged});
  @override
  State<CasoEditor> createState() => _CasoEditorState();
}

class _CasoEditorState extends State<CasoEditor> {
  late final TextEditingController _scenario =
      TextEditingController(text: widget.initial['scenario']?.toString() ?? '')..addListener(_emit);
  final List<_CasoStep> _steps = <_CasoStep>[];

  static const Map<String, List<String>> _templates = <String, List<String>>{
    'Caso clinico': <String>['Valutazione iniziale: cosa rilevi per primo?', 'Qual è la priorità assistenziale?',
        'Calcolo (dosaggio, velocità d’infusione…)', 'Come rivaluti il paziente?'],
    'Caso giuridico': <String>['Qual è la questione giuridica?', 'Quale norma o istituto si applica?',
        'Come si risolve il caso?'],
    'Caso aziendale': <String>['Qual è il problema dell’impresa?', 'Calcola l’indice richiesto',
        'Quale decisione consigli?'],
    'Caso didattico': <String>['Che cosa sta succedendo in classe?', 'Quale strategia adotti?',
        'Come verifichi che abbia funzionato?'],
  };

  @override
  void initState() {
    super.initState();
    for (final Map<String, dynamic> raw in asMapList(widget.initial['steps'])) {
      final Set<String> correct = asStringList(raw['correct']).toSet();
      final _CasoStep step = _CasoStep(
        kind: raw['kind']?.toString() == 'numerica' ? 'numerica' : 'scelta',
        weight: (int.tryParse('${raw['weight']}') ?? 1).clamp(1, 5),
        prompt: raw['prompt']?.toString() ?? '',
        note: raw['note']?.toString() ?? '',
        answer: _num(raw['answer']),
        tolerance: raw['tolerance'] == null || '${raw['tolerance']}' == '0.0' || '${raw['tolerance']}' == '0' ? '' : _num(raw['tolerance']),
        unit: raw['unit']?.toString() ?? '',
        multiple: raw['multiple'] == true,
        tolerancePct: double.tryParse('${raw['tolerance_pct'] ?? 0}') ?? 0,
        options: <_Row>[
          for (final Map<String, dynamic> o in asMapList(raw['options']))
            _Row(o['id']?.toString() ?? _newKey(), a: o['text']?.toString() ?? '', flag: correct.contains(o['id']?.toString())),
        ],
      );
      _steps.add(step);
    }
    if (_steps.isEmpty) _steps.add(_blankStep());
    for (final _CasoStep step in _steps) {
      _fillOptions(step);
      step.listen(_emit);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  _CasoStep _blankStep([String prompt = '']) => _fillOptions(_CasoStep(prompt: prompt));

  _CasoStep _fillOptions(_CasoStep step) {
    while (step.options.length < 3) {
      step.options.add(_Row(_newKey()));
    }
    return step;
  }

  @override
  void dispose() {
    _scenario.dispose();
    for (final _CasoStep s in _steps) {
      s.dispose();
    }
    super.dispose();
  }

  void _emit() {
    widget.onChanged(<String, dynamic>{
      'scenario': _scenario.text.trim(),
      'steps': <Map<String, dynamic>>[
        for (int i = 0; i < _steps.length; i++)
          _casoStepData(_steps[i], i),
      ],
    });
  }

  void _addStep([String prompt = '']) {
    final _CasoStep step = _blankStep(prompt)..listen(_emit);
    setState(() => _steps.add(step));
    _emit();
  }

  void _applyTemplate(String name) {
    final List<String> prompts = _templates[name] ?? const <String>[];
    setState(() {
      for (final _CasoStep s in _steps) {
        s.dispose();
      }
      _steps
        ..clear()
        ..addAll(prompts.map((String p) => _blankStep(p)..listen(_emit)));
      final int calc = prompts.indexWhere((String p) => p.startsWith('Calcol'));
      if (calc >= 0) _steps[calc].kind = 'numerica';
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      _section(context, 'IL CASO', help: 'Descrivi la situazione come la vedrebbe lo studente: dati, parametri, contesto. '
          'Puoi aggiungere documenti o immagini negli allegati.', <Widget>[
        TextField(controller: _scenario, minLines: 3, maxLines: 10, maxLength: 3000,
            decoration: _dec('Testo del caso', hint: 'Sig.ra R., 78 anni, diabetica, confusa da un’ora…', dense: false)),
        Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
          for (final String name in _templates.keys)
            ActionChip(
              avatar: const Icon(Icons.auto_awesome_outlined, size: 16),
              label: Text(name),
              onPressed: () async {
                final bool empty = _steps.every((_CasoStep s) => s.prompt.text.trim().isEmpty);
                final bool ok = empty ||
                    await showDialog<bool>(
                          context: context,
                          builder: (BuildContext c) => AlertDialog(
                            title: Text('Usare il modello “$name”?'),
                            content: const Text('I passi scritti finora verranno sostituiti.'),
                            actions: <Widget>[
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annulla')),
                              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sostituisci')),
                            ],
                          ),
                        ) ==
                        true;
                if (ok && mounted) _applyTemplate(name);
              },
            ),
        ]),
      ]),
      for (int i = 0; i < _steps.length; i++)
        _section(context, 'PASSO ${i + 1}', <Widget>[
          Row(children: <Widget>[
            Expanded(
              child: SegmentedButton<String>(
                segments: const <ButtonSegment<String>>[
                  ButtonSegment<String>(value: 'scelta', label: Text('A scelta'), icon: Icon(Icons.checklist_rounded)),
                  ButtonSegment<String>(value: 'numerica', label: Text('Numerica'), icon: Icon(Icons.calculate_outlined)),
                ],
                selected: <String>{_steps[i].kind},
                onSelectionChanged: (Set<String> v) {
                  setState(() => _steps[i].kind = v.first);
                  _emit();
                },
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: _steps[i].weight,
              items: <DropdownMenuItem<int>>[
                for (int w = 1; w <= 5; w++) DropdownMenuItem<int>(value: w, child: Text('peso $w')),
              ],
              onChanged: (int? w) {
                setState(() => _steps[i].weight = w ?? 1);
                _emit();
              },
            ),
            IconButton(
              tooltip: 'Sposta su',
              onPressed: i == 0
                  ? null
                  : () {
                      setState(() => _steps.insert(i - 1, _steps.removeAt(i)));
                      _emit();
                    },
              icon: const Icon(Icons.arrow_upward_rounded, size: 18),
            ),
            _removeButton(
              enabled: _steps.length > 1,
              tooltip: 'Togli il passo',
              onPressed: () {
                setState(() => _steps.removeAt(i).dispose());
                _emit();
              },
            ),
          ]),
          const SizedBox(height: 10),
          TextField(controller: _steps[i].prompt, decoration: _dec('Domanda del passo')),
          const SizedBox(height: 10),
          if (_steps[i].kind == 'numerica')
            Row(children: <Widget>[
              Expanded(child: TextField(controller: _steps[i].answer, decoration: _dec('Risultato'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _steps[i].tolerance, decoration: _dec('± tolleranza'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _steps[i].unit, decoration: _dec('Unità (ml, €, N…)'))),
            ])
          else ...<Widget>[
            for (final _Row r in _steps[i].options)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: <Widget>[
                  Checkbox(
                    value: r.flag,
                    onChanged: (bool? v) {
                      setState(() => r.flag = v == true);
                      _emit();
                    },
                  ),
                  Expanded(child: TextField(controller: r.a, decoration: _dec(r.flag ? 'Risposta giusta' : 'Risposta'))),
                  _removeButton(
                    enabled: _steps[i].options.length > 2,
                    onPressed: () {
                      setState(() {
                        _steps[i].options.remove(r);
                        r.dispose();
                      });
                      _emit();
                    },
                  ),
                ]),
              ),
            if (_steps[i].options.length < 8)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _steps[i].options.add(_Row(_newKey())..a.addListener(_emit))),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Aggiungi risposta'),
                ),
              ),
          ],
          const SizedBox(height: 4),
          TextField(
            controller: _steps[i].note,
            minLines: 1,
            maxLines: 4,
            decoration: _dec('Spiegazione mostrata dopo la verifica (facoltativa)'),
          ),
        ]),
      if (_steps.length < 8)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _addStep(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Aggiungi passo'),
          ),
        ),
      Text('In esercitazione ogni passo si verifica e sblocca il successivo; nei quiz e nei compiti si corregge tutto alla consegna. '
          'Il punteggio è la media pesata dei passi.', style: SlText.muted(p).copyWith(fontSize: 11.5)),
    ]);
  }
}

/// Forma di scrittura di un passo (vedi _clean_caso_step nel backend).
Map<String, dynamic> _casoStepData(_CasoStep s, int i) {
  final Map<String, dynamic> base = <String, dynamic>{
    'id': 's${i + 1}',
    'kind': s.kind,
    'prompt': s.prompt.text.trim(),
    'weight': s.weight,
    'note': s.note.text.trim(),
  };
  if (s.kind == 'numerica') {
    return <String, dynamic>{
      ...base,
      'answer': s.answer.text.trim(),
      'tolerance': double.tryParse(s.tolerance.text.replaceAll(',', '.')) ?? 0,
      'tolerance_pct': s.tolerancePct,
      'unit': s.unit.text.trim(),
    };
  }
  final List<_Row> used = s.options.where((_Row r) => r.a.text.trim().isNotEmpty).toList();
  return <String, dynamic>{
    ...base,
    'options': <Map<String, dynamic>>[
      for (final _Row r in used) <String, dynamic>{'id': r.key, 'text': r.a.text.trim()},
    ],
    'correct': used.where((_Row r) => r.flag).map((_Row r) => r.key).toList(),
  };
}

// ------------------------------------------------------------------- vero o falso motivato
class _Claim {
  final TextEditingController text;
  final TextEditingController explanation;
  final List<TextEditingController> reasons;
  bool value;
  int correct;

  _Claim({String text = '', String explanation = '', List<String>? reasons, this.value = true, this.correct = 0})
      : text = TextEditingController(text: text),
        explanation = TextEditingController(text: explanation),
        reasons = <TextEditingController>[for (final String r in reasons ?? const <String>[]) TextEditingController(text: r)];

  void listen(VoidCallback f) {
    text.addListener(f);
    explanation.addListener(f);
    for (final TextEditingController r in reasons) {
      r.addListener(f);
    }
  }

  void dispose() {
    text.dispose();
    explanation.dispose();
    for (final TextEditingController r in reasons) {
      r.dispose();
    }
  }
}

class VeroFalsoEditor extends StatefulWidget {
  final Map<String, dynamic> initial;
  final DataChanged onChanged;
  const VeroFalsoEditor({super.key, required this.initial, required this.onChanged});
  @override
  State<VeroFalsoEditor> createState() => _VeroFalsoEditorState();
}

class _VeroFalsoEditorState extends State<VeroFalsoEditor> {
  final List<_Claim> _claims = <_Claim>[];

  @override
  void initState() {
    super.initState();
    for (final Map<String, dynamic> c in asMapList(widget.initial['claims'])) {
      final List<Map<String, dynamic>> reasons = asMapList(c['reasons']);
      final List<String> texts = reasons.isNotEmpty
          ? reasons.map((Map<String, dynamic> r) => r['text']?.toString() ?? '').toList()
          : asStringList(c['reasons']);
      int correct = reasons.indexWhere((Map<String, dynamic> r) => r['id']?.toString() == c['correct_reason']?.toString());
      if (correct < 0) correct = int.tryParse('${c['correct_reason']}') ?? 0;
      final dynamic value = c['value'];
      _claims.add(_Claim(
        text: c['text']?.toString() ?? '',
        explanation: c['explanation']?.toString() ?? '',
        reasons: texts,
        value: value is bool ? value : !'$value'.toLowerCase().startsWith('f'),
        correct: correct,
      ));
    }
    if (_claims.isEmpty) _claims.add(_Claim(reasons: <String>['', '', '']));
    for (final _Claim c in _claims) {
      c.listen(_emit);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    for (final _Claim c in _claims) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() {
    widget.onChanged(<String, dynamic>{
      'claims': <Map<String, dynamic>>[
        for (final _Claim c in _claims)
          () {
            final List<int> filled = <int>[
              for (int i = 0; i < c.reasons.length; i++)
                if (c.reasons[i].text.trim().isNotEmpty) i,
            ];
            return <String, dynamic>{
              'text': c.text.text.trim(),
              'value': c.value,
              'explanation': c.explanation.text.trim(),
              'reasons': <String>[for (final int i in filled) c.reasons[i].text.trim()],
              // motivo giusto lasciato vuoto: niente correct_reason, così il server lo segnala
              if (filled.isNotEmpty && filled.contains(c.correct)) 'correct_reason': filled.indexOf(c.correct),
            };
          }(),
      ],
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      for (int i = 0; i < _claims.length; i++)
        _section(context, 'AFFERMAZIONE ${i + 1}',
            help: i == 0
                ? 'Scrivi 3–4 motivi, alcuni a favore di VERO e alcuni di FALSO: così il motivo non suggerisce il verdetto. '
                    'Senza motivi vale solo vero/falso.'
                : null,
            <Widget>[
              Row(children: <Widget>[
                Expanded(child: TextField(controller: _claims[i].text, minLines: 1, maxLines: 4, decoration: _dec('Affermazione'))),
                _removeButton(
                  enabled: _claims.length > 1,
                  onPressed: () {
                    setState(() => _claims.removeAt(i).dispose());
                    _emit();
                  },
                ),
              ]),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const <ButtonSegment<bool>>[
                  ButtonSegment<bool>(value: true, label: Text('È vera'), icon: Icon(Icons.check_rounded)),
                  ButtonSegment<bool>(value: false, label: Text('È falsa'), icon: Icon(Icons.close_rounded)),
                ],
                selected: <bool>{_claims[i].value},
                onSelectionChanged: (Set<bool> v) {
                  setState(() => _claims[i].value = v.first);
                  _emit();
                },
              ),
              const SizedBox(height: 10),
              Text('Motivi (tocca il pallino di quello giusto)', style: SlText.muted(p).copyWith(fontSize: 12)),
              const SizedBox(height: 6),
              for (int r = 0; r < _claims[i].reasons.length; r++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: <Widget>[
                    IconButton(
                      tooltip: 'Motivo giusto',
                      onPressed: () {
                        setState(() => _claims[i].correct = r);
                        _emit();
                      },
                      icon: Icon(_claims[i].correct == r ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                          color: _claims[i].correct == r ? p.adminGreen : null),
                    ),
                    Expanded(child: TextField(controller: _claims[i].reasons[r], decoration: _dec('Motivo ${r + 1}'))),
                    _removeButton(
                      enabled: true,
                      onPressed: () {
                        setState(() {
                          _claims[i].reasons.removeAt(r).dispose();
                          // il motivo giusto resta lo stesso anche se se ne toglie uno prima
                          if (r < _claims[i].correct) {
                            _claims[i].correct--;
                          } else if (r == _claims[i].correct) {
                            _claims[i].correct = 0;
                          }
                        });
                        _emit();
                      },
                    ),
                  ]),
                ),
              if (_claims[i].reasons.length < 5)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _claims[i].reasons.add(TextEditingController()..addListener(_emit))),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Aggiungi motivo'),
                  ),
                ),
              TextField(controller: _claims[i].explanation, maxLines: 3, minLines: 1,
                  decoration: _dec('Spiegazione dopo la verifica (es. art. 1478 c.c.)')),
            ]),
      if (_claims.length < 10)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              final _Claim c = _Claim(reasons: <String>['', '', ''])..listen(_emit);
              setState(() => _claims.add(c));
              _emit();
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Aggiungi affermazione'),
          ),
        ),
    ]);
  }
}

// ------------------------------------------------------------------- categorizza
class CategorizzaEditor extends StatefulWidget {
  final Map<String, dynamic> initial;
  final DataChanged onChanged;
  const CategorizzaEditor({super.key, required this.initial, required this.onChanged});
  @override
  State<CategorizzaEditor> createState() => _CategorizzaEditorState();
}

class _CategorizzaEditorState extends State<CategorizzaEditor> {
  final List<TextEditingController> _categories = <TextEditingController>[];
  final List<_Row> _items = <_Row>[];
  final Map<String, int> _itemCategory = <String, int>{};

  @override
  void initState() {
    super.initState();
    final List<Map<String, dynamic>> cats = asMapList(widget.initial['categories']);
    final List<String> catTexts = cats.isNotEmpty
        ? cats.map((Map<String, dynamic> c) => c['text']?.toString() ?? '').toList()
        : asStringList(widget.initial['categories']);
    final Map<String, int> catIndex = <String, int>{
      for (int i = 0; i < cats.length; i++) cats[i]['id'].toString(): i,
    };
    final Map<String, dynamic> placement = asMap(widget.initial['placement']);
    for (final String t in catTexts) {
      _categories.add(TextEditingController(text: t));
    }
    while (_categories.length < 2) {
      _categories.add(TextEditingController());
    }
    for (final Map<String, dynamic> item in asMapList(widget.initial['items'])) {
      final _Row row = _Row(_newKey(), a: item['text']?.toString() ?? '');
      int index = 0;
      if (placement.isNotEmpty) {
        index = catIndex[placement[item['id']?.toString()]?.toString()] ?? 0;
      } else {
        final dynamic c = item['category'];
        index = c is int ? c : (int.tryParse('$c') ?? catTexts.indexWhere((String t) => t.toLowerCase() == '$c'.toLowerCase()));
      }
      _itemCategory[row.key] = index < 0 ? 0 : index;
      _items.add(row);
    }
    while (_items.length < 4) {
      final _Row row = _Row(_newKey());
      _itemCategory[row.key] = _items.length % 2;
      _items.add(row);
    }
    for (final TextEditingController c in _categories) {
      c.addListener(_emit);
    }
    for (final _Row r in _items) {
      r.a.addListener(_emit);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    for (final TextEditingController c in _categories) {
      c.dispose();
    }
    for (final _Row r in _items) {
      r.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged(<String, dynamic>{
        'categories': _categories.map((TextEditingController c) => c.text.trim()).toList(),
        'items': <Map<String, dynamic>>[
          for (final _Row r in _items)
            if (r.a.text.trim().isNotEmpty)
              <String, dynamic>{'text': r.a.text.trim(), 'category': (_itemCategory[r.key] ?? 0).clamp(0, _categories.length - 1)},
        ],
      });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      _section(context, 'CATEGORIE', help: 'Da 2 a 6 (es. Procarioti / Eucarioti / Entrambi).', <Widget>[
        for (int i = 0; i < _categories.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: <Widget>[
              Expanded(child: TextField(controller: _categories[i], decoration: _dec('Categoria ${i + 1}'))),
              _removeButton(
                enabled: _categories.length > 2,
                onPressed: () {
                  setState(() {
                    _categories.removeAt(i).dispose();
                    // gli elementi della categoria tolta passano alla prima; gli altri scalano
                    _itemCategory.updateAll((String k, int v) => v == i ? 0 : (v > i ? v - 1 : v));
                  });
                  _emit();
                },
              ),
            ]),
          ),
        if (_categories.length < 6)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _categories.add(TextEditingController()..addListener(_emit))),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Aggiungi categoria'),
            ),
          ),
      ]),
      _section(context, 'ELEMENTI DA SISTEMARE', help: 'Da 2 a 24. Lo studente li vedrà mescolati.', <Widget>[
        for (final _Row r in _items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: <Widget>[
              Expanded(flex: 3, child: TextField(controller: r.a, decoration: _dec('Elemento'))),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int>(
                  value: (_itemCategory[r.key] ?? 0).clamp(0, _categories.length - 1),
                  isExpanded: true,
                  decoration: _dec('Va in'),
                  items: <DropdownMenuItem<int>>[
                    for (int i = 0; i < _categories.length; i++)
                      DropdownMenuItem<int>(
                        value: i,
                        child: Text(_categories[i].text.trim().isEmpty ? 'Categoria ${i + 1}' : _categories[i].text.trim(),
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (int? v) {
                    setState(() => _itemCategory[r.key] = v ?? 0);
                    _emit();
                  },
                ),
              ),
              _removeButton(
                enabled: _items.length > 2,
                onPressed: () {
                  setState(() {
                    _items.remove(r);
                    _itemCategory.remove(r.key);
                    r.dispose();
                  });
                  _emit();
                },
              ),
            ]),
          ),
        if (_items.length < 24)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                final _Row row = _Row(_newKey())..a.addListener(_emit);
                setState(() {
                  _itemCategory[row.key] = 0;
                  _items.add(row);
                });
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Aggiungi elemento'),
            ),
          ),
      ]),
    ]);
  }
}

// ------------------------------------------------------------------- linea del tempo
class LineaTempoEditor extends StatefulWidget {
  final Map<String, dynamic> initial;
  final DataChanged onChanged;
  const LineaTempoEditor({super.key, required this.initial, required this.onChanged});
  @override
  State<LineaTempoEditor> createState() => _LineaTempoEditorState();
}

class _LineaTempoEditorState extends State<LineaTempoEditor> {
  final List<_Row> _events = <_Row>[];

  @override
  void initState() {
    super.initState();
    for (final dynamic raw in (widget.initial['events'] is List ? widget.initial['events'] as List : const <dynamic>[])) {
      if (raw is Map) {
        _events.add(_Row(_newKey(), a: raw['text']?.toString() ?? '', b: raw['date']?.toString() ?? ''));
      } else if (raw != null) {
        _events.add(_Row(_newKey(), a: raw.toString()));
      }
    }
    while (_events.length < 3) {
      _events.add(_Row(_newKey()));
    }
    for (final _Row r in _events) {
      r.a.addListener(_emit);
      r.b.addListener(_emit);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    for (final _Row r in _events) {
      r.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged(<String, dynamic>{
        'events': <Map<String, dynamic>>[
          for (final _Row r in _events)
            if (r.a.text.trim().isNotEmpty) <String, dynamic>{'text': r.a.text.trim(), 'date': r.b.text.trim()},
        ],
      });

  @override
  Widget build(BuildContext context) {
    return _section(context, 'EVENTI DAL PIÙ ANTICO AL PIÙ RECENTE',
        help: 'Almeno 3 eventi. La data (o la fase) si mostra solo dopo la verifica: non suggerisce l’ordine.', <Widget>[
      for (int i = 0; i < _events.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: <Widget>[
            SizedBox(width: 26, child: Text('${i + 1}.')),
            SizedBox(width: 110, child: TextField(controller: _events[i].b, decoration: _dec('Data', hint: '1948'))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _events[i].a, decoration: _dec('Evento'))),
            IconButton(
              tooltip: 'Su',
              onPressed: i == 0
                  ? null
                  : () {
                      setState(() => _events.insert(i - 1, _events.removeAt(i)));
                      _emit();
                    },
              icon: const Icon(Icons.arrow_upward_rounded, size: 18),
            ),
            _removeButton(
              enabled: _events.length > 3,
              onPressed: () {
                setState(() => _events.removeAt(i).dispose());
                _emit();
              },
            ),
          ]),
        ),
      if (_events.length < 12)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _events.add(_Row(_newKey())
              ..a.addListener(_emit)
              ..b.addListener(_emit))),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Aggiungi evento'),
          ),
        ),
    ]);
  }
}

// ------------------------------------------------------------------- risposta breve con griglia
class RispostaBreveEditor extends StatefulWidget {
  final Map<String, dynamic> initial;
  final DataChanged onChanged;
  const RispostaBreveEditor({super.key, required this.initial, required this.onChanged});
  @override
  State<RispostaBreveEditor> createState() => _RispostaBreveEditorState();
}

class _RispostaBreveEditorState extends State<RispostaBreveEditor> {
  late final TextEditingController _model =
      TextEditingController(text: widget.initial['model_answer']?.toString() ?? '')..addListener(_emit);
  late final TextEditingController _min =
      TextEditingController(text: '${widget.initial['min_chars'] ?? 40}')..addListener(_emit);
  late final TextEditingController _max =
      TextEditingController(text: '${widget.initial['max_chars'] ?? 600}')..addListener(_emit);
  final List<_Row> _criteria = <_Row>[];
  final Map<String, int> _points = <String, int>{};
  final Map<String, int> _minMatches = <String, int>{};

  @override
  void initState() {
    super.initState();
    for (final Map<String, dynamic> c in asMapList(widget.initial['criteria'])) {
      final dynamic k = c['keywords'];
      final _Row row = _Row(_newKey(), a: c['text']?.toString() ?? '', b: k is List ? k.join(', ') : (k?.toString() ?? ''));
      _points[row.key] = (int.tryParse('${c['points']}') ?? 1).clamp(1, 5);
      _minMatches[row.key] = int.tryParse('${c['min_matches'] ?? 1}') ?? 1;
      _criteria.add(row);
    }
    while (_criteria.length < 2) {
      final _Row row = _Row(_newKey());
      _points[row.key] = 1;
      _criteria.add(row);
    }
    for (final _Row r in _criteria) {
      r.a.addListener(_emit);
      r.b.addListener(_emit);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    _model.dispose();
    _min.dispose();
    _max.dispose();
    for (final _Row r in _criteria) {
      r.dispose();
    }
    super.dispose();
  }

  void _emit() => widget.onChanged(<String, dynamic>{
        'model_answer': _model.text.trim(),
        'min_chars': int.tryParse(_min.text.trim()) ?? 40,
        'max_chars': int.tryParse(_max.text.trim()) ?? 600,
        'criteria': <Map<String, dynamic>>[
          for (final _Row r in _criteria)
            if (r.a.text.trim().isNotEmpty)
              <String, dynamic>{
                'text': r.a.text.trim(),
                'points': _points[r.key] ?? 1,
                'keywords': r.b.text.trim(),
                'min_matches': _minMatches[r.key] ?? 1,
              },
        ],
      });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      _section(context, 'RISPOSTA MODELLO', help: 'Lo studente la vede dopo la verifica, accanto alla sua.', <Widget>[
        TextField(controller: _model, minLines: 3, maxLines: 8, decoration: _dec('Risposta modello', dense: false)),
        const SizedBox(height: 8),
        Row(children: <Widget>[
          Expanded(child: TextField(controller: _min, keyboardType: TextInputType.number, decoration: _dec('Minimo caratteri'))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: _max, keyboardType: TextInputType.number, decoration: _dec('Massimo caratteri'))),
        ]),
      ]),
      _section(context, 'GRIGLIA', help: 'Da 1 a 6 punti. Le parole chiave servono al controllo automatico indicativo: '
          'scrivi l’inizio delle parole (“filtr” trova filtrazione e filtrare), separate da virgole.', <Widget>[
        for (final _Row r in _criteria)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: p.pureWhite.withValues(alpha: 0.08)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: <Widget>[
              Row(children: <Widget>[
                Expanded(child: TextField(controller: r.a, decoration: _dec('Cosa deve dire'))),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _points[r.key] ?? 1,
                  items: <DropdownMenuItem<int>>[
                    for (int v = 1; v <= 5; v++) DropdownMenuItem<int>(value: v, child: Text('$v pt')),
                  ],
                  onChanged: (int? v) {
                    setState(() => _points[r.key] = v ?? 1);
                    _emit();
                  },
                ),
                _removeButton(
                  enabled: _criteria.length > 1,
                  onPressed: () {
                    setState(() {
                      _criteria.remove(r);
                      _points.remove(r.key);
                      r.dispose();
                    });
                    _emit();
                  },
                ),
              ]),
              const SizedBox(height: 8),
              TextField(controller: r.b, decoration: _dec('Parole chiave', hint: 'filtr, ritenzione, trattien')),
            ]),
          ),
        if (_criteria.length < 6)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                final _Row row = _Row(_newKey())
                  ..a.addListener(_emit)
                  ..b.addListener(_emit);
                setState(() {
                  _points[row.key] = 1;
                  _criteria.add(row);
                });
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Aggiungi punto'),
            ),
          ),
      ]),
    ]);
  }
}
