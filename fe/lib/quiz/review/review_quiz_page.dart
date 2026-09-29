import 'package:flutter/material.dart';

import '../../theme/nightTheme.dart';

/// Quiz sullo snapshot dello storico: funziona anche se la banca domande cambia.
/// Le risposte al quiz di ripasso non modificano lo storico delle lacune.
class ReviewQuizPage extends StatefulWidget {
  final String subject;
  final List<Map<String, dynamic>> items;

  const ReviewQuizPage({super.key, required this.subject, required this.items});

  @override
  State<ReviewQuizPage> createState() => _ReviewQuizPageState();
}

class _ReviewQuizPageState extends State<ReviewQuizPage> {
  int _index = 0;
  int _correct = 0;
  String? _selected;
  bool _revealed = false;

  String _field(Map<String, dynamic> row, String key) => row[key]?.toString().trim() ?? '';

  List<String> _answers(Map<String, dynamic> row) {
    final options = <String>[];
    final raw = row['options'];
    if (raw is List) {
      for (final entry in raw) {
        final String text = entry is Map
            ? (entry['text'] ?? entry['answer'] ?? entry['value'] ?? '').toString().trim()
            : entry.toString().trim();
        if (text.isNotEmpty && !options.contains(text)) options.add(text);
      }
    }
    // Nelle vecchie sessioni offline erano salvate solo le due risposte.
    for (final key in ['last_selected_option_text', 'correct_option_text']) {
      final value = _field(row, key);
      if (value.isNotEmpty && !options.contains(value)) options.add(value);
    }
    return options;
  }

  void _next() {
    if (_index + 1 == widget.items.length) {
      showDialog<void>(context: context, builder: (context) => AlertDialog(
        title: const Text('Ripasso completato'),
        content: Text('Risposte corrette: $_correct / ${widget.items.length}'),
        actions: [TextButton(onPressed: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        }, child: const Text('Chiudi'))],
      ));
    } else {
      setState(() { _index++; _selected = null; _revealed = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.items[_index];
    final answer = _field(row, 'correct_option_text');
    final options = _answers(row);
    final hasChoice = options.length >= 2;
    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(title: Text('Quiz di ripasso · ${widget.subject}')),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text('${_index + 1} / ${widget.items.length}', style: TextStyle(color: AppColors.white70)),
          const SizedBox(height: 20),
          Text(_field(row, 'question_text'), style: TextStyle(color: AppColors.pureWhite,
            fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 22),
          if (hasChoice)
            for (final option in options)
              Card(color: AppColors.eleganceMidnight, child: RadioListTile<String>(
                title: Text(option, style: TextStyle(color: AppColors.pureWhite)),
                value: option, groupValue: _selected,
                onChanged: _revealed ? null : (value) => setState(() => _selected = value),
              )),
          if (!hasChoice)
            Text('Questa domanda precedente non conserva tutte le alternative. '
              'Prova a rispondere prima di mostrare la soluzione.',
              style: TextStyle(color: AppColors.white70)),
          if (_revealed) ...[
            const SizedBox(height: 16),
            Text('Risposta: $answer', style: TextStyle(color: AppColors.materialSky, fontSize: 17)),
            if (_field(row, 'formal_explanation').isNotEmpty)
              Text(_field(row, 'formal_explanation'), style: TextStyle(color: AppColors.white70)),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: _revealed ? _next : (!hasChoice || _selected != null ? () {
            if (_selected == answer) _correct++;
            setState(() => _revealed = true);
          } : null), child: Text(_revealed ? 'Prossima domanda' : 'Verifica risposta')),
        ]),
      ))),
    );
  }
}
