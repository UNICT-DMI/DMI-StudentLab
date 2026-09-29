import 'package:flutter/material.dart';

import 'package:fe/theme/app_palette.dart';
import 'package:fe/widgets/studentlab_ui/studentlab_ui.dart';
import 'package:fe/quiz/exercises/exercise_api_service.dart';
import 'package:fe/quiz/exercises/exercise_models.dart';
import 'package:fe/quiz/exercises/widgets/views_logic.dart';

/// Tipi generici (v24): vanno bene per ogni corso, dall'Infermieristica alla Giurisprudenza.
/// Come gli altri tipi: la vista raccoglie la risposta, la correzione è del server.

typedef PartCheck = Future<ExerciseResult> Function(Map<String, dynamic> answer, Map<String, dynamic> scope);

Widget _card(BuildContext context, {required Widget child, bool? ok, bool selected = false, EdgeInsets? padding}) =>
    Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: padding ?? const EdgeInsets.all(14),
      decoration: outcomeBox(context, ok: ok, selected: selected),
      child: child,
    );

Widget _note(BuildContext context, String text, {IconData icon = Icons.lightbulb_outline_rounded, Color? color}) {
  final p = context.palette;
  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Icon(icon, size: 16, color: color ?? p.adminAmber),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: SlText.muted(p).copyWith(fontSize: 12.5, height: 1.4))),
    ]),
  );
}

Widget _solutionLine(BuildContext context, String text) {
  final p = context.palette;
  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Icon(Icons.check_circle_outline_rounded, size: 16, color: p.adminGreen),
      const SizedBox(width: 6),
      Expanded(child: Text(text, style: TextStyle(color: p.adminGreen, fontSize: 13, height: 1.35))),
    ]),
  );
}

/// Riga di una risposta a scelta (usata dal Caso pratico e dal Vero o falso).
class _ChoiceRow extends StatelessWidget {
  final String text;
  final bool chosen;
  final bool multiple;
  final bool? ok;
  final VoidCallback? onTap;

  const _ChoiceRow({required this.text, required this.chosen, required this.multiple, this.ok, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        selected: chosen,
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: outcomeBox(context, ok: ok, selected: chosen, radius: 12),
            child: Row(children: <Widget>[
              Icon(
                multiple
                    ? (chosen ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded)
                    : (chosen ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded),
                size: 20,
                color: chosen ? p.skyBlue : p.pureWhite.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: TextStyle(color: p.pureWhite, fontSize: 14, height: 1.35))),
              outcomeIcon(context, ok),
            ]),
          ),
        ),
      ),
    );
  }
}

// ======================================================================= caso pratico a passi
/// Un caso (clinico, giuridico, aziendale, didattico…) e da 1 a 8 passi: domande a scelta o numeriche.
/// In esercitazione ogni passo si controlla sul server e sblocca il successivo; nei quiz e nei compiti
/// i passi compaiono uno dopo l'altro man mano che si risponde e si correggono tutti alla consegna.
class CasoView extends StatefulWidget {
  final ExerciseItem item;
  final ExerciseResult? result;
  final bool locked;
  final Map<String, dynamic>? initial;
  final AnswerChanged onChanged;
  final PartCheck? checkPart;

  const CasoView({super.key, required this.item, required this.onChanged, this.result, this.locked = false,
      this.initial, this.checkPart});

  @override
  State<CasoView> createState() => _CasoViewState();
}

class _CasoViewState extends State<CasoView> {
  final Map<String, Map<String, dynamic>> _answers = <String, Map<String, dynamic>>{};
  final Map<String, TextEditingController> _values = <String, TextEditingController>{};
  final Set<String> _confirmed = <String>{};
  final Map<String, bool> _stepOk = <String, bool>{};
  bool _checking = false;
  bool _stepChecksOff = false;
  String? _message;

  List<Map<String, dynamic>> get _steps => asMapList(widget.item.data['steps']);

  bool get _stepMode => widget.checkPart != null && !widget.locked && widget.result == null && !_stepChecksOff;

  @override
  void initState() {
    super.initState();
    final Map<String, dynamic> saved = asMap(widget.initial?['steps']);
    for (final Map<String, dynamic> step in _steps) {
      final String id = step['id'].toString();
      final Map<String, dynamic> answer = asMap(saved[id]);
      _answers[id] = answer;
      if (step['kind'] == 'numerica') {
        _values[id] = TextEditingController(text: answer['value']?.toString() ?? '')
          ..addListener(() {
            if (!mounted) return;
            setState(() {
              _answers[id] = <String, dynamic>{'value': _values[id]!.text.trim()};
              _stepOk.remove(id);
            });
            _emit();
          });
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emit();
    });
  }

  @override
  void dispose() {
    for (final TextEditingController c in _values.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _answered(Map<String, dynamic> step) {
    final Map<String, dynamic> answer = _answers[step['id'].toString()] ?? const <String, dynamic>{};
    return step['kind'] == 'numerica'
        ? (answer['value']?.toString().trim() ?? '').isNotEmpty
        : asStringList(answer['selected']).isNotEmpty;
  }

  void _emit() {
    widget.onChanged(<String, dynamic>{'steps': Map<String, dynamic>.from(_answers)}, _steps.every(_answered));
  }

  /// Quanti passi si vedono: con il controllo per passo fino al primo non ancora confermato,
  /// altrimenti fino al primo senza risposta. Con l'esito si vedono tutti.
  int get _visible {
    if (widget.result != null || widget.locked) return _steps.length;
    int n = 0;
    for (final Map<String, dynamic> step in _steps) {
      n++;
      final bool done = _stepMode ? _confirmed.contains(step['id'].toString()) : _answered(step);
      if (!done) break;
    }
    return n;
  }

  void _select(Map<String, dynamic> step, String optionId) {
    final String id = step['id'].toString();
    if (widget.locked || _confirmed.contains(id)) return;
    final Set<String> selected = asStringList(_answers[id]?['selected']).toSet();
    setState(() {
      if (step['multiple'] == true) {
        selected.contains(optionId) ? selected.remove(optionId) : selected.add(optionId);
      } else {
        selected
          ..clear()
          ..add(optionId);
      }
      _answers[id] = <String, dynamic>{'selected': selected.toList()};
      _stepOk.remove(id);
      _message = null;
    });
    _emit();
  }

  Future<void> _check(Map<String, dynamic> step) async {
    final String id = step['id'].toString();
    setState(() {
      _checking = true;
      _message = null;
    });
    try {
      final ExerciseResult result = await widget.checkPart!(
          <String, dynamic>{'steps': <String, dynamic>{id: _answers[id]}}, <String, dynamic>{'step': id});
      if (!mounted) return;
      setState(() {
        _stepOk[id] = result.isCorrect;
        if (result.isCorrect) {
          _confirmed.add(id);
        } else {
          _message = 'Non è la risposta giusta: riprova questo passo.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      // controllo per passo non disponibile (es. compito assegnato): si prosegue senza
      setState(() {
        _stepChecksOff = true;
        _message = '${cleanError(error)} Rispondi a tutti i passi: la correzione arriva alla verifica.';
      });
    }
    if (mounted) setState(() => _checking = false);
  }

  String _solutionText(Map<String, dynamic> step, Map<String, dynamic> solution) {
    if (step['kind'] == 'numerica') {
      final String unit = solution['unit']?.toString() ?? '';
      return 'Risposta: ${solution['value'] ?? ''}${unit.isEmpty ? '' : ' $unit'}';
    }
    final Map<String, String> texts = {
      for (final Map<String, dynamic> o in asMapList(step['options'])) o['id'].toString(): o['text']?.toString() ?? ''
    };
    return 'Risposta: ${asStringList(solution['correct']).map((String c) => texts[c] ?? '').join(' · ')}';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Color accent = categoryColor(context, 'ragionamento');
    final Map<String, dynamic> outcomes = asMap(widget.result?.feedback['steps']);
    final Map<String, dynamic> notes = asMap(widget.result?.feedback['notes']);
    final Map<String, dynamic> solutions = asMap(widget.result?.solution?['steps']);
    final List<Map<String, dynamic>> steps = _steps;
    final int visible = _visible;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
          Text('IL CASO', style: SlText.mono(p, size: 10.5, color: accent, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(widget.item.data['scenario']?.toString() ?? '',
              style: TextStyle(color: p.pureWhite, fontSize: 14.5, height: 1.5)),
        ]),
      ),
      for (int i = 0; i < steps.length && i < visible; i++)
        Builder(builder: (BuildContext context) {
          final Map<String, dynamic> step = steps[i];
          final String id = step['id'].toString();
          final bool confirmed = _confirmed.contains(id);
          final bool? ok = widget.result != null
              ? (outcomes.containsKey(id) ? outcomes[id] == true : null)
              : (confirmed ? true : _stepOk[id]);
          final bool editable = !widget.locked && widget.result == null && !confirmed;
          final bool current = i == visible - 1 && editable;
          return _card(
            context,
            ok: ok,
            selected: current && ok == null,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (ok == true ? p.adminGreen : (ok == false ? p.adminCoral : accent)).withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Text('${i + 1}',
                      style: TextStyle(color: ok == true ? p.adminGreen : (ok == false ? p.adminCoral : accent),
                          fontSize: 12, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(step['prompt']?.toString() ?? '',
                      style: TextStyle(color: p.pureWhite, fontSize: 15, fontWeight: FontWeight.w600, height: 1.35)),
                ),
                if ((int.tryParse('${step['weight']}') ?? 1) > 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text('×${step['weight']}', style: SlText.mono(p, size: 11, color: p.adminAmber)),
                  ),
              ]),
              const SizedBox(height: 10),
              if (step['kind'] == 'numerica')
                Row(children: <Widget>[
                  SizedBox(
                    width: 170,
                    child: TextField(
                      controller: _values[id],
                      enabled: editable,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      style: TextStyle(color: p.pureWhite, fontSize: 17, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                      decoration: InputDecoration(isDense: true, hintText: 'valore', border: const OutlineInputBorder(),
                          filled: true, fillColor: p.darkElegance),
                    ),
                  ),
                  if ((step['unit']?.toString() ?? '').isNotEmpty) ...<Widget>[
                    const SizedBox(width: 10),
                    Text(step['unit'].toString(), style: SlText.body(p)),
                  ],
                ])
              else
                for (final Map<String, dynamic> option in asMapList(step['options']))
                  Builder(builder: (BuildContext context) {
                    final String optionId = option['id'].toString();
                    final bool chosen = asStringList(_answers[id]?['selected']).contains(optionId);
                    final Set<String> correct = asStringList(asMap(solutions[id])['correct']).toSet();
                    final bool? optionOk = widget.result == null || correct.isEmpty
                        ? null
                        : (correct.contains(optionId) ? true : (chosen ? false : null));
                    return _ChoiceRow(
                      text: option['text']?.toString() ?? '',
                      chosen: chosen,
                      multiple: step['multiple'] == true,
                      ok: optionOk,
                      onTap: editable ? () => _select(step, optionId) : null,
                    );
                  }),
              if (widget.result != null && ok == false && solutions[id] != null)
                _solutionLine(context, _solutionText(step, asMap(solutions[id]))),
              if (widget.result != null && notes[id] != null) _note(context, notes[id].toString()),
              if (current && _stepMode) ...<Widget>[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _checking || !_answered(step) ? null : () => _check(step),
                    icon: const Icon(Icons.task_alt_rounded, size: 18),
                    label: Text(_checking ? 'Controllo…' : (i == steps.length - 1 ? 'Verifica il passo' : 'Verifica e prosegui')),
                  ),
                ),
              ],
            ]),
          );
        }),
      if (visible < steps.length)
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 8),
          child: Row(children: <Widget>[
            Icon(Icons.lock_outline_rounded, size: 16, color: p.pureWhite.withValues(alpha: 0.45)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                  'Ancora ${steps.length - visible} ${steps.length - visible == 1 ? 'passo' : 'passi'}: '
                  'si sblocca${steps.length - visible == 1 ? '' : 'no'} rispondendo a quello attuale.',
                  style: SlText.muted(p).copyWith(fontSize: 12)),
            ),
          ]),
        ),
      if (_message != null) _note(context, _message!, icon: Icons.info_outline_rounded, color: p.adminCoral),
    ]);
  }
}

// ======================================================================= vero o falso motivato
class VeroFalsoView extends StatefulWidget {
  final ExerciseItem item;
  final ExerciseResult? result;
  final bool locked;
  final Map<String, dynamic>? initial;
  final AnswerChanged onChanged;

  const VeroFalsoView({super.key, required this.item, required this.onChanged, this.result, this.locked = false,
      this.initial});

  @override
  State<VeroFalsoView> createState() => _VeroFalsoViewState();
}

class _VeroFalsoViewState extends State<VeroFalsoView> {
  final Map<String, bool> _values = <String, bool>{};
  final Map<String, String> _reasons = <String, String>{};

  List<Map<String, dynamic>> get _claims => asMapList(widget.item.data['claims']);

  @override
  void initState() {
    super.initState();
    asMap(widget.initial?['answers']).forEach((String id, dynamic raw) {
      final Map<String, dynamic> answer = asMap(raw);
      if (answer['value'] is bool) _values[id] = answer['value'] as bool;
      if (answer['reason'] != null) _reasons[id] = answer['reason'].toString();
    });
  }

  void _emit() {
    final bool complete = _claims.every((Map<String, dynamic> c) {
      final String id = c['id'].toString();
      return _values.containsKey(id) && (asMapList(c['reasons']).isEmpty || _reasons.containsKey(id));
    });
    widget.onChanged(<String, dynamic>{
      'answers': <String, dynamic>{
        for (final String id in _values.keys)
          id: <String, dynamic>{'value': _values[id], if (_reasons[id] != null) 'reason': _reasons[id]},
      },
    }, complete);
  }

  Widget _verdict(BuildContext context, String id, bool value, {bool? ok}) {
    final p = context.palette;
    final bool chosen = _values[id] == value;
    final Color tone = value ? p.adminGreen : p.adminCoral;
    return Expanded(
      child: Semantics(
        button: true,
        selected: chosen,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: widget.locked
              ? null
              : () {
                  setState(() => _values[id] = value);
                  _emit();
                },
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: chosen ? tone.withValues(alpha: 0.18) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: chosen ? tone.withValues(alpha: 0.75) : p.pureWhite.withValues(alpha: 0.18),
                  width: ok == null ? 1 : 2),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              Icon(value ? Icons.check_rounded : Icons.close_rounded, size: 18, color: chosen ? tone : p.pureWhite.withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Text(value ? 'Vero' : 'Falso',
                  style: TextStyle(color: p.pureWhite, fontWeight: chosen ? FontWeight.w700 : FontWeight.w500)),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Map<String, dynamic> marks = asMap(widget.result?.feedback['claims']);
    final Map<String, dynamic> explanations = asMap(widget.result?.feedback['explanations']);
    final Map<String, dynamic> solution = asMap(widget.result?.solution?['claims']);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      if (!widget.locked && _claims.any((Map<String, dynamic> c) => asMapList(c['reasons']).isNotEmpty))
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Metà punteggio per vero/falso, metà per il motivo giusto.', style: SlText.muted(p).copyWith(fontSize: 12)),
        ),
      for (int i = 0; i < _claims.length; i++)
        Builder(builder: (BuildContext context) {
          final Map<String, dynamic> claim = _claims[i];
          final String id = claim['id'].toString();
          final Map<String, dynamic> mark = asMap(marks[id]);
          final Map<String, dynamic> right = asMap(solution[id]);
          final List<Map<String, dynamic>> reasons = asMapList(claim['reasons']);
          final bool? valueOk = mark.isEmpty ? null : mark['value'] == true;
          final bool? allOk = mark.isEmpty ? null : (mark['value'] == true && mark['reason'] != false);
          return _card(
            context,
            ok: allOk,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                if (_claims.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 1),
                    child: Text('${i + 1}.', style: SlText.mono(p, size: 13, color: p.pureWhite.withValues(alpha: 0.6))),
                  ),
                Expanded(
                  child: Text(claim['text']?.toString() ?? '',
                      style: TextStyle(color: p.pureWhite, fontSize: 15, height: 1.4)),
                ),
                outcomeIcon(context, allOk),
              ]),
              const SizedBox(height: 10),
              Row(children: <Widget>[
                _verdict(context, id, true, ok: valueOk),
                const SizedBox(width: 8),
                _verdict(context, id, false, ok: valueOk),
              ]),
              if (reasons.isNotEmpty && (_values.containsKey(id) || widget.result != null)) ...<Widget>[
                const SizedBox(height: 10),
                Text('Perché?', style: SlText.muted(p).copyWith(fontSize: 12)),
                const SizedBox(height: 6),
                for (final Map<String, dynamic> reason in reasons)
                  Builder(builder: (BuildContext context) {
                    final String rid = reason['id'].toString();
                    final bool chosen = _reasons[id] == rid;
                    final bool? ok = widget.result == null || right.isEmpty
                        ? null
                        : (right['reason']?.toString() == rid ? true : (chosen ? false : null));
                    return _ChoiceRow(
                      text: reason['text']?.toString() ?? '',
                      chosen: chosen,
                      multiple: false,
                      ok: ok,
                      onTap: widget.locked
                          ? null
                          : () {
                              setState(() => _reasons[id] = rid);
                              _emit();
                            },
                    );
                  }),
              ],
              if (widget.result != null && valueOk == false && right['value'] is bool)
                _solutionLine(context, 'L’affermazione è ${right['value'] == true ? 'VERA' : 'FALSA'}.'),
              if (widget.result != null && explanations[id] != null) _note(context, explanations[id].toString()),
            ]),
          );
        }),
    ]);
  }
}

// ======================================================================= categorizza
/// Si tocca un elemento e poi la categoria (oppure si trascina). Tocca un elemento già sistemato
/// per rimetterlo tra quelli da sistemare.
class CategorizzaView extends StatefulWidget {
  final ExerciseItem item;
  final ExerciseResult? result;
  final bool locked;
  final Map<String, dynamic>? initial;
  final AnswerChanged onChanged;

  const CategorizzaView({super.key, required this.item, required this.onChanged, this.result, this.locked = false,
      this.initial});

  @override
  State<CategorizzaView> createState() => _CategorizzaViewState();
}

class _CategorizzaViewState extends State<CategorizzaView> {
  late final Map<String, String> _placement = asMap(widget.initial?['placement'])
      .map((String k, dynamic v) => MapEntry<String, String>(k, v.toString()));
  String? _active;

  static const List<Color> _tones = <Color>[
    Color(0xFF54D99B), Color(0xFFA9A8FF), Color(0xFF35D0E6), Color(0xFFF4B860), Color(0xFFF08CFF), Color(0xFF64B5F6),
  ];

  List<Map<String, dynamic>> get _categories => asMapList(widget.item.data['categories']);
  List<Map<String, dynamic>> get _items => asMapList(widget.item.data['items']);

  void _emit() =>
      widget.onChanged(<String, dynamic>{'placement': Map<String, String>.from(_placement)}, _placement.length == _items.length);

  void _place(String itemId, String? categoryId) {
    if (widget.locked) return;
    setState(() {
      if (categoryId == null) {
        _placement.remove(itemId);
      } else {
        _placement[itemId] = categoryId;
      }
      _active = null;
    });
    _emit();
  }

  Widget _chip(BuildContext context, Map<String, dynamic> item, {Color? tone, bool? ok, String? hint}) {
    final p = context.palette;
    final String id = item['id'].toString();
    final bool active = _active == id;
    final Color border = ok == null
        ? (active ? p.skyBlue : (tone ?? p.pureWhite).withValues(alpha: tone == null ? 0.22 : 0.65))
        : (ok ? p.adminGreen : p.adminCoral);
    final Widget body = Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: active ? p.skyBlue.withValues(alpha: 0.18) : (tone ?? p.eleganceMidnight).withValues(alpha: tone == null ? 1 : 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: active || ok != null ? 1.6 : 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
        if (!widget.locked && tone == null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(Icons.drag_indicator_rounded, size: 16, color: p.pureWhite.withValues(alpha: 0.45)),
          ),
        Flexible(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: <Widget>[
            Text(item['text']?.toString() ?? '', style: TextStyle(color: p.pureWhite, fontSize: 13.5)),
            if (hint != null) Text(hint, style: TextStyle(color: p.adminGreen, fontSize: 11)),
          ]),
        ),
        if (ok != null) ...<Widget>[const SizedBox(width: 4), outcomeIcon(context, ok)],
      ]),
    );
    if (widget.locked) return body;
    return Semantics(
      button: true,
      selected: active,
      label: tone == null ? 'Da sistemare' : 'Sistemato: tocca per togliere',
      child: Draggable<String>(
        data: id,
        feedback: Material(color: Colors.transparent, child: Opacity(opacity: 0.9, child: body)),
        childWhenDragging: Opacity(opacity: 0.35, child: body),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            if (tone != null) {
              _place(id, null);
            } else {
              setState(() => _active = active ? null : id);
            }
          },
          child: body,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Map<String, dynamic> marks = asMap(widget.result?.feedback['items']);
    final Map<String, dynamic> solution = asMap(widget.result?.solution?['placement']);
    final List<Map<String, dynamic>> categories = _categories;
    final Map<String, String> names = {for (final c in categories) c['id'].toString(): c['text']?.toString() ?? ''};
    final List<Map<String, dynamic>> pool =
        _items.where((Map<String, dynamic> i) => !_placement.containsKey(i['id'].toString())).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      if (!widget.locked)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
              _active == null
                  ? 'Tocca un elemento e poi la categoria (o trascinalo).'
                  : 'Ora tocca la categoria giusta.',
              style: SlText.muted(p).copyWith(fontSize: 12)),
        ),
      for (int c = 0; c < categories.length; c++)
        Builder(builder: (BuildContext context) {
          final String cid = categories[c]['id'].toString();
          final Color tone = _tones[c % _tones.length];
          final List<Map<String, dynamic>> placed =
              _items.where((Map<String, dynamic> i) => _placement[i['id'].toString()] == cid).toList();
          return DragTarget<String>(
            onWillAcceptWithDetails: (DragTargetDetails<String> d) => !widget.locked,
            onAcceptWithDetails: (DragTargetDetails<String> d) => _place(d.data, cid),
            builder: (BuildContext context, List<String?> hovering, List<dynamic> rejected) => InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: widget.locked || _active == null ? null : () => _place(_active!, cid),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(minHeight: 72),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: hovering.isNotEmpty || _active != null ? 0.10 : 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: tone.withValues(alpha: hovering.isNotEmpty ? 0.95 : 0.55), width: 1.4),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                  Row(children: <Widget>[
                    Expanded(
                      child: Text(names[cid] ?? '', style: TextStyle(color: tone, fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                    Text('${placed.length}', style: SlText.mono(p, size: 11, color: tone)),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: <Widget>[
                    for (final Map<String, dynamic> item in placed)
                      Builder(builder: (BuildContext context) {
                        final String iid = item['id'].toString();
                        final bool? ok = marks.isEmpty ? null : marks[iid] == true;
                        return _chip(context, item,
                            tone: tone,
                            ok: ok,
                            hint: ok == false && solution[iid] != null ? '→ ${names[solution[iid].toString()] ?? ''}' : null);
                      }),
                  ]),
                ]),
              ),
            ),
          );
        }),
      if (pool.isNotEmpty) ...<Widget>[
        const SizedBox(height: 4),
        SlOverline('DA SISTEMARE · ${pool.length}'),
        const SizedBox(height: 8),
        DragTarget<String>(
          onAcceptWithDetails: (DragTargetDetails<String> d) => _place(d.data, null),
          builder: (BuildContext context, List<String?> hovering, List<dynamic> rejected) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final Map<String, dynamic> item in pool)
                _chip(context, item,
                    ok: widget.result == null ? null : false,
                    hint: widget.result != null && solution[item['id'].toString()] != null
                        ? '→ ${names[solution[item['id'].toString()].toString()] ?? ''}'
                        : null),
            ],
          ),
        ),
      ],
    ]);
  }
}

// ======================================================================= linea del tempo
class LineaTempoView extends StatefulWidget {
  final ExerciseItem item;
  final ExerciseResult? result;
  final bool locked;
  final Map<String, dynamic>? initial;
  final AnswerChanged onChanged;

  const LineaTempoView({super.key, required this.item, required this.onChanged, this.result, this.locked = false,
      this.initial});

  @override
  State<LineaTempoView> createState() => _LineaTempoViewState();
}

class _LineaTempoViewState extends State<LineaTempoView> {
  late List<Map<String, dynamic>> _events;

  @override
  void initState() {
    super.initState();
    final List<Map<String, dynamic>> events = asMapList(widget.item.data['events']);
    final List<String> saved = asStringList(widget.initial?['order']);
    final Map<String, Map<String, dynamic>> byId = {for (final e in events) e['id'].toString(): e};
    final List<Map<String, dynamic>> restored = saved.map((String id) => byId[id]).whereType<Map<String, dynamic>>().toList();
    _events = restored.length == events.length ? restored : events;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emit();
    });
  }

  void _emit() => widget.onChanged(
      <String, dynamic>{'order': _events.map((Map<String, dynamic> e) => e['id'].toString()).toList()}, true);

  void _move(int from, int to) {
    if (widget.locked || to < 0 || to >= _events.length) return;
    setState(() => _events.insert(to, _events.removeAt(from)));
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Color accent = categoryColor(context, 'logico');
    final List<dynamic> positions = (widget.result?.feedback['positions'] as List?) ?? const <dynamic>[];
    final List<String> solution = asStringList(widget.result?.solution?['order']);
    final Map<String, dynamic> dates = asMap(widget.result?.solution?['dates']);
    final Map<String, String> texts = {for (final e in _events) e['id'].toString(): e['text']?.toString() ?? ''};
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      if (!widget.locked)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Dal più antico (in alto) al più recente. Trascina o usa le frecce.',
              style: SlText.muted(p).copyWith(fontSize: 12)),
        ),
      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: _events.length,
        onReorder: (int from, int to) => _move(from, to > from ? to - 1 : to),
        itemBuilder: (BuildContext context, int index) {
          final Map<String, dynamic> event = _events[index];
          final String id = event['id'].toString();
          final bool? ok = widget.result == null || index >= positions.length ? null : positions[index] == true;
          final bool last = index == _events.length - 1;
          return IntrinsicHeight(
            key: ValueKey<String>(id),
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
              SizedBox(
                width: 28,
                child: Column(children: <Widget>[
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(top: 18),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ok == null ? accent : (ok ? p.adminGreen : p.adminCoral),
                    ),
                  ),
                  if (!last)
                    Expanded(child: Container(width: 2, color: accent.withValues(alpha: 0.35))),
                ]),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(4, 6, 6, 6),
                  decoration: outcomeBox(context, ok: ok),
                  child: Row(children: <Widget>[
                    if (!widget.locked)
                      ReorderableDragStartListener(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(Icons.drag_indicator_rounded, color: p.pureWhite.withValues(alpha: 0.5)),
                        ),
                      )
                    else
                      const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                        if (dates[id] != null)
                          Text(dates[id].toString(), style: SlText.mono(p, size: 11, color: accent, weight: FontWeight.w700)),
                        Text(event['text']?.toString() ?? '', style: TextStyle(color: p.pureWhite, height: 1.35)),
                      ]),
                    ),
                    outcomeIcon(context, ok),
                    if (!widget.locked) ...<Widget>[
                      IconButton(
                        tooltip: 'Prima',
                        visualDensity: VisualDensity.compact,
                        onPressed: index == 0 ? null : () => _move(index, index - 1),
                        icon: const Icon(Icons.keyboard_arrow_up_rounded),
                      ),
                      IconButton(
                        tooltip: 'Dopo',
                        visualDensity: VisualDensity.compact,
                        onPressed: last ? null : () => _move(index, index + 1),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                    ],
                  ]),
                ),
              ),
            ]),
          );
        },
      ),
      if (widget.result != null && !widget.result!.isCorrect && solution.isNotEmpty) ...<Widget>[
        const SizedBox(height: 6),
        SlOverline('ORDINE CORRETTO'),
        const SizedBox(height: 6),
        for (int i = 0; i < solution.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
                '${i + 1}. ${dates[solution[i]] != null ? '${dates[solution[i]]} · ' : ''}${texts[solution[i]] ?? ''}',
                style: SlText.body(p).copyWith(fontSize: 13)),
          ),
      ],
    ]);
  }
}

// ======================================================================= risposta breve con griglia
/// Il server dà un punteggio indicativo cercando le parole chiave della griglia; dopo la verifica
/// lo studente confronta la sua risposta con quella modello e si autovaluta punto per punto.
class RispostaBreveView extends StatefulWidget {
  final ExerciseItem item;
  final ExerciseResult? result;
  final bool locked;
  final Map<String, dynamic>? initial;
  final AnswerChanged onChanged;

  const RispostaBreveView({super.key, required this.item, required this.onChanged, this.result, this.locked = false,
      this.initial});

  @override
  State<RispostaBreveView> createState() => _RispostaBreveViewState();
}

class _RispostaBreveViewState extends State<RispostaBreveView> {
  late final TextEditingController _text = TextEditingController(text: widget.initial?['text']?.toString() ?? '')
    ..addListener(_emit);
  final Map<String, bool> _self = <String, bool>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emit();
    });
  }

  int get _min => int.tryParse('${widget.item.data['min_chars']}') ?? 0;
  int get _max => int.tryParse('${widget.item.data['max_chars']}') ?? 600;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _emit() {
    if (mounted) setState(() {});
    widget.onChanged(<String, dynamic>{'text': _text.text}, _text.text.trim().length >= _min);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final List<Map<String, dynamic>> criteria = asMapList(widget.item.data['criteria']);
    final Map<String, dynamic> auto = asMap(widget.result?.feedback['criteria']);
    final String model = widget.result?.solution?['model_answer']?.toString() ?? '';
    final int length = _text.text.trim().length;
    final int total = criteria.fold<int>(0, (int s, Map<String, dynamic> c) => s + (int.tryParse('${c['points']}') ?? 1));
    final int self = criteria.fold<int>(0, (int s, Map<String, dynamic> c) {
      final String id = c['id'].toString();
      return s + ((_self[id] ?? auto[id] == true) ? (int.tryParse('${c['points']}') ?? 1) : 0);
    });
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      TextField(
        controller: _text,
        enabled: !widget.locked,
        minLines: 5,
        maxLines: 10,
        maxLength: _max,
        style: TextStyle(color: p.pureWhite, fontSize: 14.5, height: 1.5),
        decoration: InputDecoration(
          hintText: 'Scrivi la tua risposta in poche righe…',
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: p.darkElegance,
          helperText: length < _min ? 'Almeno $_min caratteri (ora $length).' : null,
        ),
      ),
      if (widget.result == null && criteria.isNotEmpty)
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Cosa deve contenere (${criteria.length} punti)', style: SlText.body(p).copyWith(fontSize: 13.5)),
            children: <Widget>[
              for (final Map<String, dynamic> c in criteria)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• ${c['text']}  (${c['points']} pt)', style: SlText.muted(p).copyWith(fontSize: 12.5)),
                  ),
                ),
            ],
          ),
        ),
      if (widget.result != null) ...<Widget>[
        if (widget.result!.feedback['error'] == 'too_short')
          _note(context, 'Risposta troppo corta: servono almeno $_min caratteri.', icon: Icons.info_outline_rounded,
              color: p.adminCoral),
        if (model.isNotEmpty)
          _card(
            context,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
              SlOverline('RISPOSTA MODELLO'),
              const SizedBox(height: 6),
              Text(model, style: TextStyle(color: p.pureWhite, fontSize: 14, height: 1.5)),
            ]),
          ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.adminGreen.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.adminGreen.withValues(alpha: 0.35)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
            Text('Confronta e spunta i punti che hai toccato',
                style: TextStyle(color: p.pureWhite, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Le spunte iniziali sono del controllo automatico (parole chiave): correggile tu.',
                style: SlText.muted(p).copyWith(fontSize: 12)),
            const SizedBox(height: 6),
            for (final Map<String, dynamic> c in criteria)
              Builder(builder: (BuildContext context) {
                final String id = c['id'].toString();
                final bool value = _self[id] ?? auto[id] == true;
                return CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: value,
                  onChanged: (bool? v) => setState(() => _self[id] = v == true),
                  title: Text('${c['text']}', style: TextStyle(color: p.pureWhite, fontSize: 13.5)),
                  secondary: Text('${c['points']} pt', style: SlText.mono(p, size: 11)),
                );
              }),
            const Divider(),
            Text('Autovalutazione: $self su $total punti', style: TextStyle(color: p.adminGreen, fontWeight: FontWeight.w700)),
          ]),
        ),
      ],
    ]);
  }
}
