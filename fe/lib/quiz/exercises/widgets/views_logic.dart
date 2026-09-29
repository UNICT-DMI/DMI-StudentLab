import 'package:flutter/material.dart';

import 'package:fe/theme/app_palette.dart';
import 'package:fe/widgets/studentlab_ui/studentlab_ui.dart';
import 'package:fe/quiz/exercises/exercise_api_service.dart';
import 'package:fe/quiz/exercises/exercise_models.dart';
import 'package:fe/quiz/exercises/widgets/exercise_attachments.dart';
import 'package:fe/quiz/exercises/widgets/exercise_view.dart';

/// Bordo e sfondo di una riga secondo l'esito (null = nessun esito).
BoxDecoration outcomeBox(BuildContext context, {bool? ok, bool selected = false, double radius = 13}) {
  final p = context.palette;
  final Color border = ok == null
      ? (selected ? p.skyBlue.withValues(alpha: 0.6) : p.pureWhite.withValues(alpha: 0.10))
      : (ok ? p.adminGreen.withValues(alpha: 0.7) : p.adminCoral.withValues(alpha: 0.7));
  final Color fill = ok == null
      ? (selected ? p.skyBlue.withValues(alpha: 0.12) : p.eleganceMidnight)
      : (ok ? p.adminGreen.withValues(alpha: 0.10) : p.adminCoral.withValues(alpha: 0.10));
  return BoxDecoration(color: fill, borderRadius: BorderRadius.circular(radius), border: Border.all(color: border));
}

Widget outcomeIcon(BuildContext context, bool? ok) {
  final p = context.palette;
  if (ok == null) return const SizedBox.shrink();
  return Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
      size: 20, color: ok ? p.adminGreen : p.adminCoral, semanticLabel: ok ? 'giusto' : 'sbagliato');
}

// ======================================================================= scelta
/// Risposta multipla (le domande di sempre) e "Scelta con allegati":
/// testo, eventuali immagini nelle risposte, una o più risposte giuste.
class SceltaView extends StatefulWidget {
  final ExerciseItem item;
  final ExerciseScope scope;
  final ExerciseResult? result;
  final bool locked;
  final Map<String, dynamic>? initial;
  final AnswerChanged onChanged;

  const SceltaView({super.key, required this.item, required this.scope, required this.onChanged, this.result,
      this.locked = false, this.initial});

  @override
  State<SceltaView> createState() => _SceltaViewState();
}

class _SceltaViewState extends State<SceltaView> {
  late final Set<String> _selected = asStringList(widget.initial?['selected']).toSet();

  bool get _multiple => widget.item.data['multiple'] == true;

  void _toggle(String id) {
    if (widget.locked) return;
    setState(() {
      if (_multiple) {
        _selected.contains(id) ? _selected.remove(id) : _selected.add(id);
      } else {
        _selected
          ..clear()
          ..add(id);
      }
    });
    widget.onChanged(<String, dynamic>{'selected': _selected.toList()}, _selected.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final List<Map<String, dynamic>> options = asMapList(widget.item.data['options']);
    final Set<String> correct = asStringList(widget.result?.solution?['correct']).toSet();
    final Map<String, dynamic> explanations = asMap(widget.result?.feedback['explanations']);
    final Map<String, Map<String, dynamic>> optionImages = <String, Map<String, dynamic>>{
      for (final Map<String, dynamic> a in widget.item.attachments) a['id'].toString(): a,
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      if (_multiple)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Puoi scegliere più risposte.', style: SlText.muted(p).copyWith(fontSize: 12)),
        ),
      for (final Map<String, dynamic> option in options)
        Builder(builder: (BuildContext context) {
          final String id = option['id']?.toString() ?? '';
          final bool chosen = _selected.contains(id);
          final bool? ok = widget.result == null || correct.isEmpty
              ? null
              : (correct.contains(id) ? true : (chosen ? false : null));
          final String? imageId = option['attachment_id']?.toString();
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Semantics(
              selected: chosen,
              button: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: widget.locked ? null : () => _toggle(id),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: outcomeBox(context, ok: ok, selected: chosen),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                    Row(children: <Widget>[
                      Icon(
                        _multiple
                            ? (chosen ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded)
                            : (chosen ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded),
                        color: chosen ? p.skyBlue : p.pureWhite.withValues(alpha: 0.5),
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(option['text']?.toString() ?? '',
                            style: TextStyle(color: p.pureWhite, fontSize: 15, height: 1.35)),
                      ),
                      outcomeIcon(context, ok),
                    ]),
                    if (imageId != null && optionImages.containsKey(imageId)) ...<Widget>[
                      const SizedBox(height: 10),
                      AttachmentImage(
                        maxHeight: 220,
                        uri: ExerciseApiService().exerciseAttachmentUri(widget.scope.department,
                            widget.scope.course, widget.scope.subject, widget.item.id, imageId),
                      ),
                    ],
                    if (widget.result != null && explanations[id] != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text('${explanations[id]}', style: SlText.muted(p).copyWith(fontSize: 12)),
                    ],
                  ]),
                ),
              ),
            ),
          );
        }),
    ]);
  }
}

// ======================================================================= ordina
class OrdinaView extends StatefulWidget {
  final ExerciseItem item;
  final ExerciseResult? result;
  final bool locked;
  final Map<String, dynamic>? initial;
  final AnswerChanged onChanged;

  const OrdinaView({super.key, required this.item, required this.onChanged, this.result, this.locked = false, this.initial});

  @override
  State<OrdinaView> createState() => _OrdinaViewState();
}

class _OrdinaViewState extends State<OrdinaView> {
  late List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    final List<Map<String, dynamic>> items = asMapList(widget.item.data['items']);
    final List<String> saved = asStringList(widget.initial?['order']);
    if (saved.length == items.length) {
      final Map<String, Map<String, dynamic>> byId = {for (final i in items) i['id'].toString(): i};
      _items = saved.map((String id) => byId[id]).whereType<Map<String, dynamic>>().toList();
      if (_items.length != items.length) _items = items;
    } else {
      _items = items;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  void _emit() => widget.onChanged(
      <String, dynamic>{'order': _items.map((Map<String, dynamic> i) => i['id'].toString()).toList()}, true);

  void _move(int from, int to) {
    setState(() {
      final Map<String, dynamic> item = _items.removeAt(from);
      _items.insert(to, item);
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final List<dynamic> positions = (widget.result?.feedback['positions'] as List?) ?? const <dynamic>[];
    final List<String> solution = asStringList(widget.result?.solution?['order']);
    final Map<String, String> texts = {for (final i in _items) i['id'].toString(): i['text']?.toString() ?? ''};
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Text(widget.locked ? '' : 'Trascina le righe (o usa le frecce) per metterle in ordine.',
          style: SlText.muted(p).copyWith(fontSize: 12)),
      const SizedBox(height: 8),
      ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        itemCount: _items.length,
        onReorder: (int from, int to) {
          if (widget.locked) return;
          _move(from, to > from ? to - 1 : to);
        },
        itemBuilder: (BuildContext context, int index) {
          final Map<String, dynamic> item = _items[index];
          final bool? ok = index < positions.length ? positions[index] == true : null;
          return Padding(
            key: ValueKey<String>(item['id'].toString()),
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              decoration: outcomeBox(context, ok: widget.result == null ? null : ok),
              padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
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
                  const SizedBox(width: 12),
                SizedBox(
                  width: 24,
                  child: Text('${index + 1}',
                      style: TextStyle(color: p.pureWhite.withValues(alpha: 0.55), fontFamily: 'monospace')),
                ),
                Expanded(child: Text(item['text']?.toString() ?? '', style: TextStyle(color: p.pureWhite, height: 1.35))),
                if (widget.result != null) outcomeIcon(context, ok),
                if (!widget.locked) ...<Widget>[
                  IconButton(
                    tooltip: 'Sposta su',
                    visualDensity: VisualDensity.compact,
                    onPressed: index == 0 ? null : () => _move(index, index - 1),
                    icon: const Icon(Icons.keyboard_arrow_up_rounded),
                  ),
                  IconButton(
                    tooltip: 'Sposta giù',
                    visualDensity: VisualDensity.compact,
                    onPressed: index == _items.length - 1 ? null : () => _move(index, index + 1),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ],
              ]),
            ),
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
            child: Text('${i + 1}. ${texts[solution[i]] ?? ''}', style: SlText.body(p).copyWith(fontSize: 13)),
          ),
      ],
    ]);
  }
}

// ======================================================================= abbina
class AbbinaView extends StatefulWidget {
  final ExerciseItem item;
  final ExerciseResult? result;
  final bool locked;
  final Map<String, dynamic>? initial;
  final AnswerChanged onChanged;

  const AbbinaView({super.key, required this.item, required this.onChanged, this.result, this.locked = false, this.initial});

  @override
  State<AbbinaView> createState() => _AbbinaViewState();
}

class _AbbinaViewState extends State<AbbinaView> {
  late final Map<String, String> _pairs = asMap(widget.initial?['pairs'])
      .map((String k, dynamic v) => MapEntry<String, String>(k, v.toString()));
  String? _activeLeft;

  static const List<Color> _pairColors = <Color>[
    Color(0xFF64B5F6), Color(0xFFF4B860), Color(0xFFA9A8FF), Color(0xFF54D99B), Color(0xFFF08CFF), Color(0xFF35D0E6),
    Color(0xFFFFB199), Color(0xFFB0BEC5),
  ];

  List<Map<String, dynamic>> get _left => asMapList(widget.item.data['left']);
  List<Map<String, dynamic>> get _right => asMapList(widget.item.data['right']);

  void _emit() => widget.onChanged(<String, dynamic>{'pairs': Map<String, String>.from(_pairs)},
      _pairs.length == _left.length);

  void _tapLeft(String id) {
    if (widget.locked) return;
    setState(() => _activeLeft = _activeLeft == id ? null : id);
  }

  void _tapRight(String id) {
    if (widget.locked) return;
    final String? left = _activeLeft;
    setState(() {
      if (left == null) {
        // tocco su una destra già abbinata: la libera
        _pairs.removeWhere((String k, String v) => v == id);
      } else {
        _pairs.removeWhere((String k, String v) => v == id);
        _pairs[left] = id;
        _activeLeft = null;
      }
    });
    _emit();
  }

  Color? _colorFor(String leftId) {
    final int index = _left.indexWhere((Map<String, dynamic> l) => l['id'].toString() == leftId);
    return index < 0 ? null : _pairColors[index % _pairColors.length];
  }

  Widget _cell(BuildContext context, String text, {required VoidCallback onTap, Color? color, bool active = false,
      bool? ok}) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color != null ? color.withValues(alpha: 0.14) : p.eleganceMidnight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                width: active ? 2 : 1,
                color: ok == false
                    ? p.adminCoral
                    : (color ?? (active ? p.skyBlue : p.pureWhite.withValues(alpha: 0.12))),
              ),
            ),
            child: Row(children: <Widget>[
              if (color != null)
                Container(width: 10, height: 10, margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              Expanded(child: Text(text, style: TextStyle(color: p.pureWhite, fontSize: 14, height: 1.3))),
              if (ok != null) outcomeIcon(context, ok),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Map<String, dynamic> results = asMap(widget.result?.feedback['pairs']);
    final Map<String, dynamic> solution = asMap(widget.result?.solution?['pairs']);
    final Map<String, String> rightTexts = {for (final r in _right) r['id'].toString(): r['text']?.toString() ?? ''};
    final Map<String, String> byRight = {for (final e in _pairs.entries) e.value: e.key};
    final Widget leftColumn = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      for (final Map<String, dynamic> l in _left)
        _cell(context, l['text']?.toString() ?? '',
            onTap: () => _tapLeft(l['id'].toString()),
            active: _activeLeft == l['id'].toString(),
            color: _pairs.containsKey(l['id'].toString()) ? _colorFor(l['id'].toString()) : null,
            ok: results.isEmpty ? null : results[l['id'].toString()] == true),
    ]);
    final Widget rightColumn = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      for (final Map<String, dynamic> r in _right)
        _cell(context, r['text']?.toString() ?? '',
            onTap: () => _tapRight(r['id'].toString()),
            color: byRight.containsKey(r['id'].toString()) ? _colorFor(byRight[r['id'].toString()]!) : null),
    ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Text(widget.locked ? '' : 'Tocca un elemento a sinistra, poi quello giusto a destra. ${_pairs.length} su ${_left.length} abbinati.',
          style: SlText.muted(p).copyWith(fontSize: 12)),
      const SizedBox(height: 8),
      LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 360) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[leftColumn, const SizedBox(height: 12), rightColumn]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Expanded(flex: 4, child: leftColumn),
          const SizedBox(width: 10),
          Expanded(flex: 6, child: rightColumn),
        ]);
      }),
      if (solution.isNotEmpty && widget.result?.isCorrect == false) ...<Widget>[
        const SizedBox(height: 6),
        SlOverline('ABBINAMENTI CORRETTI'),
        const SizedBox(height: 6),
        for (final Map<String, dynamic> l in _left)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('${l['text']} → ${rightTexts[solution[l['id'].toString()]] ?? ''}',
                style: SlText.body(p).copyWith(fontSize: 13)),
          ),
      ],
    ]);
  }
}

// ======================================================================= errore
class ErroreView extends StatefulWidget {
  final ExerciseItem item;
  final ExerciseResult? result;
  final bool locked;
  final Map<String, dynamic>? initial;
  final AnswerChanged onChanged;

  const ErroreView({super.key, required this.item, required this.onChanged, this.result, this.locked = false, this.initial});

  @override
  State<ErroreView> createState() => _ErroreViewState();
}

class _ErroreViewState extends State<ErroreView> {
  late final Set<int> _lines = asStringList(widget.initial?['lines']).map(int.tryParse).whereType<int>().toSet();
  late String? _reason = widget.initial?['reason']?.toString();

  int get _count => int.tryParse('${widget.item.data['count'] ?? 1}') ?? 1;
  List<Map<String, dynamic>> get _reasons => asMapList(widget.item.data['reasons']);

  void _emit() => widget.onChanged(
        <String, dynamic>{'lines': _lines.toList()..sort(), if (_reason != null) 'reason': _reason},
        _lines.length == _count && (_reasons.isEmpty || _reason != null),
      );

  void _tapLine(int number) {
    if (widget.locked) return;
    setState(() {
      if (_lines.contains(number)) {
        _lines.remove(number);
      } else {
        if (_count == 1) _lines.clear();
        if (_lines.length < _count) _lines.add(number);
      }
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final List<String> lines = asStringList(widget.item.data['lines']);
    final Set<int> correctLines = asStringList(widget.result?.solution?['lines']).map(int.tryParse).whereType<int>().toSet();
    final String? correctReason = widget.result?.solution?['reason']?.toString();
    final String fix = widget.result?.solution?['fix']?.toString() ?? '';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Text(widget.locked ? '' : (_count == 1 ? 'Tocca la riga che contiene l’errore.' : 'Tocca le $_count righe con un errore.'),
          style: SlText.muted(p).copyWith(fontSize: 12)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: p.darkElegance,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.pureWhite.withValues(alpha: 0.10)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
          for (int i = 0; i < lines.length; i++)
            Builder(builder: (BuildContext context) {
              final int number = i + 1;
              final bool chosen = _lines.contains(number);
              final bool? ok = widget.result == null
                  ? null
                  : (correctLines.contains(number) ? true : (chosen ? false : null));
              return InkWell(
                onTap: widget.locked ? null : () => _tapLine(number),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 40),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  color: ok == true
                      ? p.adminGreen.withValues(alpha: 0.14)
                      : ok == false
                          ? p.adminCoral.withValues(alpha: 0.14)
                          : chosen
                              ? p.skyBlue.withValues(alpha: 0.16)
                              : Colors.transparent,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    SizedBox(
                      width: 30,
                      child: Text('$number',
                          textAlign: TextAlign.right,
                          style: TextStyle(color: p.pureWhite.withValues(alpha: 0.45), fontFamily: 'monospace', fontSize: 13)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(lines[i],
                          style: TextStyle(color: p.pureWhite, fontFamily: 'monospace', fontSize: 13.5, height: 1.4)),
                    ),
                    if (ok != null) outcomeIcon(context, ok),
                  ]),
                ),
              );
            }),
        ]),
      ),
      if (_reasons.isNotEmpty && _lines.isNotEmpty) ...<Widget>[
        const SizedBox(height: 14),
        SlOverline(_lines.length == 1 ? 'RIGA ${_lines.first} · PERCHÉ È SBAGLIATA?' : 'PERCHÉ SONO SBAGLIATE?'),
        const SizedBox(height: 8),
        for (final Map<String, dynamic> reason in _reasons)
          Builder(builder: (BuildContext context) {
            final String id = reason['id'].toString();
            final bool chosen = _reason == id;
            final bool? ok = widget.result == null || correctReason == null
                ? null
                : (id == correctReason ? true : (chosen ? false : null));
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: widget.locked
                    ? null
                    : () {
                        setState(() => _reason = id);
                        _emit();
                      },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: outcomeBox(context, ok: ok, selected: chosen, radius: 12),
                  child: Row(children: <Widget>[
                    Icon(chosen ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        size: 20, color: chosen ? p.skyBlue : p.pureWhite.withValues(alpha: 0.5)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(reason['text']?.toString() ?? '', style: TextStyle(color: p.pureWhite))),
                    outcomeIcon(context, ok),
                  ]),
                ),
              ),
            );
          }),
      ],
      if (fix.isNotEmpty && widget.result != null) ...<Widget>[
        const SizedBox(height: 8),
        SlOverline('CORREZIONE'),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: p.darkElegance, borderRadius: BorderRadius.circular(10)),
          child: SelectableText(fix, style: TextStyle(color: p.adminGreen, fontFamily: 'monospace', fontSize: 13)),
        ),
      ],
    ]);
  }
}
