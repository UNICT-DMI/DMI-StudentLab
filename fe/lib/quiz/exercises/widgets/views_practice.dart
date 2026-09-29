import 'package:flutter/material.dart';

import 'package:fe/theme/app_palette.dart';
import 'package:fe/widgets/studentlab_ui/studentlab_ui.dart';
import 'package:fe/quiz/exercises/exercise_api_service.dart';
import 'package:fe/quiz/exercises/exercise_models.dart';
import 'package:fe/quiz/exercises/widgets/views_logic.dart';

InputDecoration _blankDecoration(BuildContext context, {bool? ok, String? hint}) {
  final p = context.palette;
  final Color border = ok == null ? p.skyBlue.withValues(alpha: 0.5) : (ok ? p.adminGreen : p.adminCoral);
  return InputDecoration(
    isDense: true,
    hintText: hint,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: p.skyBlue, width: 2)),
    disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)),
    filled: true,
    fillColor: ok == null ? p.darkElegance : (ok ? p.adminGreen : p.adminCoral).withValues(alpha: 0.12),
  );
}

// ======================================================================= completa
class CompletaView extends StatefulWidget {
  final ExerciseItem item;
  final ExerciseResult? result;
  final bool locked;
  final Map<String, dynamic>? initial;
  final AnswerChanged onChanged;

  const CompletaView({super.key, required this.item, required this.onChanged, this.result, this.locked = false, this.initial});

  @override
  State<CompletaView> createState() => _CompletaViewState();
}

class _CompletaViewState extends State<CompletaView> {
  static final RegExp _blank = RegExp(r'\[\[([A-Za-z0-9_-]{1,20})\]\]');
  final Map<String, TextEditingController> _controllers = <String, TextEditingController>{};
  final Map<String, FocusNode> _focus = <String, FocusNode>{};
  String? _lastFocused;

  List<Map<String, dynamic>> get _blanks => asMapList(widget.item.data['blanks']);

  @override
  void initState() {
    super.initState();
    final Map<String, dynamic> saved = asMap(widget.initial?['values']);
    for (final Map<String, dynamic> blank in _blanks) {
      final String id = blank['id'].toString();
      _controllers[id] = TextEditingController(text: saved[id]?.toString() ?? '')..addListener(_emit);
      _focus[id] = FocusNode()..addListener(() {
        if (_focus[id]!.hasFocus) _lastFocused = id;
      });
    }
  }

  @override
  void dispose() {
    for (final TextEditingController c in _controllers.values) {
      c.dispose();
    }
    for (final FocusNode f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  void _emit() {
    final Map<String, String> values = _controllers.map((String k, TextEditingController c) => MapEntry(k, c.text.trim()));
    widget.onChanged(<String, dynamic>{'values': values}, values.values.every((String v) => v.isNotEmpty));
  }

  void _useWord(String word) {
    if (widget.locked) return;
    final String? target = _lastFocused ??
        _controllers.entries.where((MapEntry<String, TextEditingController> e) => e.value.text.isEmpty).map((e) => e.key).firstOrNull;
    if (target == null) return;
    _controllers[target]!.text = word;
    final String? next =
        _controllers.entries.where((MapEntry<String, TextEditingController> e) => e.value.text.isEmpty).map((e) => e.key).firstOrNull;
    if (next != null) _focus[next]!.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final String text = widget.item.data['text']?.toString() ?? '';
    final Map<String, dynamic> results = asMap(widget.result?.feedback['blanks']);
    final Map<String, dynamic> solution = asMap(widget.result?.solution?['values']);
    final Map<String, bool> numeric = {for (final b in _blanks) b['id'].toString(): b['numeric'] == true};
    final List<Widget> pieces = <Widget>[];
    int cursor = 0;
    TextStyle style = TextStyle(color: p.pureWhite, fontSize: 17, height: 1.6);
    void addText(String value) {
      for (final String word in value.split(RegExp(r'(?<=\s)'))) {
        if (word.isNotEmpty) pieces.add(Text(word, style: style));
      }
    }

    for (final RegExpMatch match in _blank.allMatches(text)) {
      addText(text.substring(cursor, match.start));
      final String id = match.group(1)!;
      final bool? ok = results.isEmpty ? null : results[id] == true;
      pieces.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          SizedBox(
            width: 96,
            child: TextField(
              controller: _controllers[id],
              focusNode: _focus[id],
              enabled: !widget.locked,
              textAlign: TextAlign.center,
              keyboardType: numeric[id] == true ? const TextInputType.numberWithOptions(decimal: true, signed: true) : null,
              style: TextStyle(color: p.pureWhite, fontSize: 15, fontWeight: FontWeight.w600),
              decoration: _blankDecoration(context, ok: ok, hint: '?'),
            ),
          ),
          if (ok == false && solution[id] != null)
            Text('${solution[id]}', style: TextStyle(color: p.adminGreen, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ));
      cursor = match.end;
    }
    addText(text.substring(cursor));
    final List<String> bank = asStringList(widget.item.data['bank']);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 4, children: pieces),
      if (bank.isNotEmpty && !widget.locked) ...<Widget>[
        const SizedBox(height: 16),
        Text('Tocca una parola per metterla nello spazio, oppure scrivila.', style: SlText.muted(p).copyWith(fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
          for (final String word in bank) ActionChip(label: Text(word), onPressed: () => _useWord(word)),
        ]),
      ],
    ]);
  }
}

// ======================================================================= numerica
class NumericaView extends StatefulWidget {
  final ExerciseItem item;
  final ExerciseResult? result;
  final bool locked;
  final Map<String, dynamic>? initial;
  final AnswerChanged onChanged;

  const NumericaView({super.key, required this.item, required this.onChanged, this.result, this.locked = false, this.initial});

  @override
  State<NumericaView> createState() => _NumericaViewState();
}

class _NumericaViewState extends State<NumericaView> {
  final Map<String, TextEditingController> _controllers = <String, TextEditingController>{};

  List<Map<String, dynamic>> get _steps => asMapList(widget.item.data['steps']);

  @override
  void initState() {
    super.initState();
    final Map<String, dynamic> saved = asMap(widget.initial?['values']);
    for (final Map<String, dynamic> step in _steps) {
      final String id = step['id'].toString();
      _controllers[id] = TextEditingController(text: saved[id]?.toString() ?? '')..addListener(_emit);
    }
  }

  @override
  void dispose() {
    for (final TextEditingController c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _emit() {
    final Map<String, String> values = _controllers.map((String k, TextEditingController c) => MapEntry(k, c.text.trim()));
    widget.onChanged(<String, dynamic>{'values': values}, values.values.every((String v) => v.isNotEmpty));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Map<String, dynamic> results = asMap(widget.result?.feedback['steps']);
    final Map<String, dynamic> checks = asMap(widget.result?.feedback['checks']);
    final Map<String, dynamic> solution = asMap(widget.result?.solution?['values']);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      for (int i = 0; i < _steps.length; i++)
        Builder(builder: (BuildContext context) {
          final Map<String, dynamic> step = _steps[i];
          final String id = step['id'].toString();
          final bool? ok = results.isEmpty ? null : results[id] == true;
          final String unit = step['unit']?.toString() ?? '';
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: outcomeBox(context, ok: ok),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
              Row(children: <Widget>[
                if (_steps.length > 1)
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: p.skyBlue.withValues(alpha: 0.16), shape: BoxShape.circle),
                    child: Text('${i + 1}', style: TextStyle(color: p.skyBlue, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                Expanded(child: Text(step['label']?.toString() ?? '', style: TextStyle(color: p.pureWhite, fontSize: 14, height: 1.35))),
                outcomeIcon(context, ok),
              ]),
              const SizedBox(height: 10),
              Row(children: <Widget>[
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _controllers[id],
                    enabled: !widget.locked,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    style: TextStyle(color: p.pureWhite, fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                    decoration: _blankDecoration(context, ok: ok, hint: 'valore'),
                  ),
                ),
                if (unit.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 10),
                  Text(unit, style: SlText.body(p)),
                ],
              ]),
              if (ok == true && checks[id] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('✓ ${checks[id]}', style: TextStyle(color: p.adminGreen, fontSize: 12)),
                ),
              if (ok == false && solution[id] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Risposta: ${solution[id]}${unit.isEmpty ? '' : ' $unit'}',
                      style: TextStyle(color: p.adminGreen, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ]),
          );
        }),
      if (!widget.locked)
        Text('Puoi scrivere 1,5 oppure 1.5, 2^8 oppure 3/4.', style: SlText.muted(p).copyWith(fontSize: 11)),
    ]);
  }
}

// ======================================================================= traccia
class TracciaView extends StatefulWidget {
  final ExerciseItem item;
  final ExerciseResult? result;
  final bool locked;
  final Map<String, dynamic>? initial;
  final AnswerChanged onChanged;
  final Future<ExerciseResult> Function(Map<String, dynamic> answer, Map<String, dynamic> scope)? checkPart;

  const TracciaView({super.key, required this.item, required this.onChanged, this.result, this.locked = false,
      this.initial, this.checkPart});

  @override
  State<TracciaView> createState() => _TracciaViewState();
}

class _TracciaViewState extends State<TracciaView> {
  final Map<String, TextEditingController> _text = <String, TextEditingController>{};
  final Map<String, String> _values = <String, String>{};
  final Map<String, bool> _rowResults = <String, bool>{};
  int _unlocked = 0;
  bool _checking = false;
  String? _message;

  List<String> get _columns => asStringList(widget.item.data['columns']);
  List<List<dynamic>> get _rows =>
      ((widget.item.data['rows'] as List?) ?? const <dynamic>[]).whereType<List>().map((List r) => r.toList()).toList();
  bool get _rowByRow => widget.item.data['row_by_row'] == true && widget.checkPart != null && !widget.locked;

  @override
  void initState() {
    super.initState();
    final Map<String, dynamic> saved = asMap(widget.initial?['cells']);
    saved.forEach((String k, dynamic v) => _values[k] = v.toString());
    for (int r = 0; r < _rows.length; r++) {
      for (int c = 0; c < _rows[r].length; c++) {
        final dynamic cell = _rows[r][c];
        if (cell is Map && asStringList(cell['options']).isEmpty) {
          final String key = '$r,$c';
          _text[key] = TextEditingController(text: _values[key] ?? '')
            ..addListener(() {
              _values[key] = _text[key]!.text.trim();
              _emit();
            });
        }
      }
    }
  }

  @override
  void dispose() {
    for (final TextEditingController c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  int get _blankCount {
    int count = 0;
    for (final List<dynamic> row in _rows) {
      count += row.where((dynamic c) => c is Map).length;
    }
    return count;
  }

  void _emit() {
    final Map<String, String> cells = Map<String, String>.fromEntries(
        _values.entries.where((MapEntry<String, String> e) => e.value.isNotEmpty));
    widget.onChanged(<String, dynamic>{'cells': cells}, cells.length == _blankCount);
  }

  bool _rowFilled(int r) {
    for (int c = 0; c < _rows[r].length; c++) {
      if (_rows[r][c] is Map && (_values['$r,$c'] ?? '').isEmpty) return false;
    }
    return true;
  }

  Future<void> _checkRow(int r) async {
    if (widget.checkPart == null) return;
    setState(() {
      _checking = true;
      _message = null;
    });
    try {
      final ExerciseResult result = await widget.checkPart!(
          <String, dynamic>{'cells': Map<String, String>.from(_values)}, <String, dynamic>{'row': r});
      final Map<String, dynamic> cells = asMap(result.feedback['cells']);
      setState(() {
        cells.forEach((String k, dynamic v) => _rowResults[k] = v == true);
        if (result.isCorrect) {
          _unlocked = r + 1;
        } else {
          _message = 'Qualcosa non torna nella riga ${r + 1}: correggi le celle in rosso.';
        }
      });
    } catch (error) {
      setState(() => _message = cleanError(error));
    }
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Map<String, dynamic> finalResults = asMap(widget.result?.feedback['cells']);
    final Map<String, dynamic> solution = asMap(widget.result?.solution?['cells']);
    final int active = _rowByRow ? _unlocked : -1;
    Widget cellWidget(int r, int c, dynamic cell) {
      final String key = '$r,$c';
      if (cell is! Map) {
        return Text(cell?.toString() ?? '', style: TextStyle(color: p.pureWhite, fontSize: 13, fontFamily: 'monospace'));
      }
      final bool enabled = !widget.locked && (!_rowByRow || r == active);
      final bool? ok = finalResults.isNotEmpty ? finalResults[key] == true : _rowResults[key];
      final List<String> options = asStringList(cell['options']);
      final Widget input = options.isNotEmpty
          ? DropdownButtonFormField<String>(
              value: options.contains(_values[key]) ? _values[key] : null,
              isExpanded: true,
              isDense: true,
              decoration: _blankDecoration(context, ok: ok, hint: '?'),
              items: <DropdownMenuItem<String>>[
                for (final String o in options)
                  DropdownMenuItem<String>(value: o, child: Text(o, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontFamily: 'monospace'))),
              ],
              onChanged: enabled
                  ? (String? v) {
                      setState(() => _values[key] = v ?? '');
                      _emit();
                    }
                  : null,
            )
          : TextField(
              controller: _text[key],
              enabled: enabled,
              style: TextStyle(color: p.pureWhite, fontSize: 13, fontFamily: 'monospace'),
              decoration: _blankDecoration(context, ok: ok, hint: '?'),
            );
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        input,
        if (ok == false && solution[key] != null)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text('${solution[key]}', style: TextStyle(color: p.adminGreen, fontSize: 11, fontFamily: 'monospace')),
          ),
      ]);
    }

    final List<double> widths = <double>[
      for (int c = 0; c < _columns.length; c++)
        _rows.any((List<dynamic> row) => c < row.length && row[c] is Map) ? 190 : (c == 0 ? 56 : 120),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.pureWhite.withValues(alpha: 0.10)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Container(
              color: p.eleganceDeepNavy,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: <Widget>[
                for (int c = 0; c < _columns.length; c++)
                  SizedBox(
                    width: widths[c],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(_columns[c].toUpperCase(),
                          style: TextStyle(color: p.pureWhite.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w700,
                              fontFamily: 'monospace')),
                    ),
                  ),
              ]),
            ),
            for (int r = 0; r < _rows.length; r++)
              Container(
                color: r == active ? p.skyBlue.withValues(alpha: 0.08) : Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Opacity(
                  opacity: _rowByRow && r > active ? 0.45 : 1,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    for (int c = 0; c < _rows[r].length && c < widths.length; c++)
                      SizedBox(
                        width: widths[c],
                        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: cellWidget(r, c, _rows[r][c])),
                      ),
                  ]),
                ),
              ),
          ]),
        ),
      ),
      if (_rowByRow && active < _rows.length) ...<Widget>[
        const SizedBox(height: 10),
        Row(children: <Widget>[
          Expanded(
            child: Text(_message ?? 'Compila la riga evidenziata. Ogni riga giusta sblocca la successiva.',
                style: TextStyle(color: _message == null ? p.pureWhite.withValues(alpha: 0.64) : p.adminAmber, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _checking || !_rowFilled(active) ? null : () => _checkRow(active),
            child: Text(_checking ? 'Controllo…' : 'Verifica la riga'),
          ),
        ]),
      ],
    ]);
  }
}

// ======================================================================= codice
class CodiceView extends StatefulWidget {
  final ExerciseItem item;
  final ExerciseResult? result;
  final bool locked;
  final Map<String, dynamic>? initial;
  final AnswerChanged onChanged;
  final Future<Map<String, dynamic>> Function(String code)? runCode;

  const CodiceView({super.key, required this.item, required this.onChanged, this.result, this.locked = false,
      this.initial, this.runCode});

  @override
  State<CodiceView> createState() => _CodiceViewState();
}

class _CodiceViewState extends State<CodiceView> {
  late final TextEditingController _code =
      TextEditingController(text: widget.initial?['code']?.toString() ?? widget.item.data['starter']?.toString() ?? '');
  final ScrollController _lines = ScrollController();
  Map<String, dynamic>? _run;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _code.addListener(() {
      final String starter = widget.item.data['starter']?.toString() ?? '';
      widget.onChanged(<String, dynamic>{'code': _code.text}, _code.text.trim().isNotEmpty && _code.text != starter);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _code.dispose();
    _lines.dispose();
    super.dispose();
  }

  Future<void> _execute() async {
    if (widget.runCode == null) return;
    setState(() => _running = true);
    try {
      final Map<String, dynamic> result = await widget.runCode!(_code.text);
      setState(() => _run = result);
    } catch (error) {
      setState(() => _run = <String, dynamic>{'error': cleanError(error), 'results': const <dynamic>[]});
    }
    if (mounted) setState(() => _running = false);
  }

  Widget _testRow(BuildContext context, Map<String, dynamic> test) {
    final p = context.palette;
    final bool ok = test['ok'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: outcomeBox(context, ok: ok, radius: 10),
      child: Row(children: <Widget>[
        Expanded(
          child: Text('${test['call'] ?? 'test'}', style: TextStyle(color: p.pureWhite, fontFamily: 'monospace', fontSize: 12.5)),
        ),
        if (!ok && test['got'] != null)
          Flexible(
            child: Text('→ ${test['got']} (atteso ${test['expected']})',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.adminCoral, fontFamily: 'monospace', fontSize: 12)),
          )
        else
          Text('${test['expected'] ?? ''}', style: TextStyle(color: p.adminGreen, fontFamily: 'monospace', fontSize: 12.5)),
        const SizedBox(width: 6),
        outcomeIcon(context, ok),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final int lineCount = '\n'.allMatches(_code.text).length + 1;
    final List<Map<String, dynamic>> publicTests = asMapList(widget.item.data['tests']);
    final Map<String, dynamic> feedback = widget.result?.feedback ?? const <String, dynamic>{};
    final List<Map<String, dynamic>> shown =
        widget.result != null ? asMapList(feedback['tests']) : asMapList(_run?['results']);
    final String? error = (widget.result != null ? feedback['error'] : _run?['error'])?.toString();
    final int hidden = int.tryParse('${widget.item.data['hidden_tests'] ?? 0}') ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Row(children: <Widget>[
        SlStatusBadge(label: (widget.item.data['language']?.toString() ?? 'python').toUpperCase(), tone: SlTone.info),
        const SizedBox(width: 6),
        if (asStringList(widget.item.data['forbidden']).isNotEmpty)
          Flexible(
            child: Text('Non usare: ${asStringList(widget.item.data['forbidden']).join(', ')}',
                style: SlText.muted(p).copyWith(fontSize: 12)),
          ),
      ]),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: p.darkElegance,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.pureWhite.withValues(alpha: 0.12)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Container(
            width: 36,
            padding: const EdgeInsets.only(top: 12, right: 6),
            child: Text(List<String>.generate(lineCount, (int i) => '${i + 1}').join('\n'),
                textAlign: TextAlign.right,
                style: TextStyle(color: p.pureWhite.withValues(alpha: 0.35), fontFamily: 'monospace', fontSize: 13.5, height: 1.45)),
          ),
          Expanded(
            child: TextField(
              controller: _code,
              enabled: !widget.locked,
              maxLines: null,
              minLines: 10,
              keyboardType: TextInputType.multiline,
              autocorrect: false,
              enableSuggestions: false,
              style: TextStyle(color: p.pureWhite, fontFamily: 'monospace', fontSize: 13.5, height: 1.45),
              decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.fromLTRB(4, 12, 12, 12)),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      if (shown.isEmpty && publicTests.isNotEmpty) ...<Widget>[
        SlOverline('TEST VISIBILI'),
        const SizedBox(height: 6),
        for (final Map<String, dynamic> test in publicTests)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('${test['call']}  →  ${test['expected']}',
                style: TextStyle(color: p.pureWhite.withValues(alpha: 0.8), fontFamily: 'monospace', fontSize: 12.5)),
          ),
      ] else if (shown.isNotEmpty) ...<Widget>[
        SlOverline('RISULTATI'),
        const SizedBox(height: 6),
        for (final Map<String, dynamic> test in shown) _testRow(context, test),
      ],
      if (widget.result != null && feedback['hidden_total'] != null)
        Text('Test nascosti superati: ${feedback['hidden_passed'] ?? 0} su ${feedback['hidden_total']}',
            style: SlText.body(p).copyWith(fontSize: 13))
      else if (hidden > 0)
        Text('+ $hidden test nascosti alla consegna', style: SlText.muted(p).copyWith(fontSize: 12)),
      if (error != null && error.isNotEmpty) ...<Widget>[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: p.adminCoral.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
          child: Text(error, style: TextStyle(color: p.adminCoral, fontFamily: 'monospace', fontSize: 12)),
        ),
      ],
      if (!widget.locked && widget.runCode != null) ...<Widget>[
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _running ? null : _execute,
            icon: _running
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_arrow_rounded),
            label: Text(_running ? 'Esecuzione…' : 'Esegui i test visibili'),
          ),
        ),
      ] else if (!widget.locked)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('I test vengono eseguiti alla consegna.', style: SlText.muted(p).copyWith(fontSize: 12)),
        ),
    ]);
  }
}
