import 'package:flutter/material.dart';

import 'package:fe/theme/app_palette.dart';
import 'package:fe/widgets/studentlab_ui/studentlab_ui.dart';
import 'package:fe/quiz/exercises/exercise_api_service.dart';
import 'package:fe/quiz/exercises/exercise_models.dart';

/// Sezione "Tipi di esercizio" del modulo di assegnazione (docente e admin).
/// Senza scelte diverse dalla risposta multipla l'assegnazione resta identica a prima.
class ExerciseTypesSection extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final int? attemptsPerItem;
  final ValueChanged<int?> onAttemptsChanged;
  final bool practice;

  const ExerciseTypesSection({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.attemptsPerItem,
    required this.onAttemptsChanged,
    required this.practice,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final List<String> all = <String>[
      kMultipleChoice,
      ...kExerciseTypes.where((String type) => type != 'flashcard'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Text('Scegli cosa assegnare. Il server sceglie gli esercizi tra quelli della materia; '
          '“Grafo”, “Traccia” e “Risposta numerica” generati sono diversi per ogni studente.',
          style: SlText.muted(p).copyWith(fontSize: 12)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
        for (final String type in all)
          FilterChip(
            avatar: Icon(exerciseInfo(type).icon, size: 16),
            label: Text(exerciseInfo(type).label),
            selected: selected.contains(type),
            onSelected: (bool value) {
              final Set<String> next = Set<String>.from(selected);
              value ? next.add(type) : next.remove(type);
              if (next.isEmpty) next.add(kMultipleChoice);
              onChanged(next);
            },
          ),
      ]),
      if (practice && selected.any((String t) => t != kMultipleChoice)) ...<Widget>[
        const SizedBox(height: 12),
        DropdownButtonFormField<int?>(
          value: attemptsPerItem,
          decoration: const InputDecoration(labelText: 'Tentativi per esercizio (esercitazione)', isDense: true),
          items: const <DropdownMenuItem<int?>>[
            DropdownMenuItem<int?>(value: null, child: Text('2 (predefinito)')),
            DropdownMenuItem<int?>(value: 1, child: Text('1')),
            DropdownMenuItem<int?>(value: 3, child: Text('3')),
            DropdownMenuItem<int?>(value: 5, child: Text('5')),
          ],
          onChanged: onAttemptsChanged,
        ),
      ],
      if (selected.any((String t) => t != kMultipleChoice)) ...<Widget>[
        const SizedBox(height: 8),
        Text('Gli studenti con una versione vecchia dell’app vedranno “aggiorna StudentLab” per questa assegnazione.',
            style: SlText.muted(p).copyWith(fontSize: 11)),
      ],
    ]);
  }
}

/// Scelta a mano degli esercizi della banca (modalità "domande specifiche").
class ExerciseItemPicker extends StatefulWidget {
  final String department;
  final String course;
  final String subject;
  final Set<String> types;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  const ExerciseItemPicker({
    super.key,
    required this.department,
    required this.course,
    required this.subject,
    required this.types,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<ExerciseItemPicker> createState() => _ExerciseItemPickerState();
}

class _ExerciseItemPickerState extends State<ExerciseItemPicker> {
  final ExerciseApiService _api = ExerciseApiService();
  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final Map<String, dynamic> data = await _api.manageList(widget.department, widget.course, widget.subject);
      _items = asMapList(data['items'])
          .where((Map<String, dynamic> r) => r['is_hidden'] != true && r['is_active'] != false)
          .toList();
    } catch (error) {
      _error = cleanError(error, 'Banca esercizi non disponibile.');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (_loading) return Padding(padding: const EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(color: p.skyBlue)));
    if (_error != null) return Text(_error!, style: TextStyle(color: p.adminCoral));
    final List<Map<String, dynamic>> shown =
        _items.where((Map<String, dynamic> r) => widget.types.contains(r['type'])).toList();
    if (shown.isEmpty) {
      return Text('Nessun esercizio dei tipi scelti nella banca della materia.', style: SlText.muted(p));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Text('Esercizi della banca (${widget.selected.length} scelti)', style: SlText.muted(p).copyWith(fontSize: 12)),
      const SizedBox(height: 6),
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: ListView(shrinkWrap: true, children: <Widget>[
          for (final Map<String, dynamic> r in shown)
            Builder(builder: (BuildContext context) {
              final String id = 'ex:${r['id_exercise']}';
              final ExerciseTypeInfo info = exerciseInfo(r['type']?.toString() ?? '');
              return CheckboxListTile(
                dense: true,
                value: widget.selected.contains(id),
                secondary: Icon(info.icon, color: categoryColor(context, info.category)),
                title: Text((r['text']?.toString() ?? '').isEmpty ? info.label : r['text'].toString(),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text('${info.label}${r['generator'] != null ? ' · variante per ogni studente' : ''}'),
                onChanged: (bool? v) {
                  final Set<String> next = Set<String>.from(widget.selected);
                  v == true ? next.add(id) : next.remove(id);
                  widget.onChanged(next);
                },
              );
            }),
        ]),
      ),
    ]);
  }
}
