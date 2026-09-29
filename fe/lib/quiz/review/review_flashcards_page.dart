import 'package:flutter/material.dart';

import '../../theme/nightTheme.dart';

/// Schede ricavate dalle domande sbagliate nello storico, indipendenti dalla
/// banca degli esercizi flashcard e dalla sua programmazione temporale.
class ReviewFlashcardsPage extends StatefulWidget {
  final String subject;
  final List<Map<String, dynamic>> items;

  const ReviewFlashcardsPage({super.key, required this.subject, required this.items});

  @override
  State<ReviewFlashcardsPage> createState() => _ReviewFlashcardsPageState();
}

class _ReviewFlashcardsPageState extends State<ReviewFlashcardsPage> {
  int _index = 0;
  bool _revealed = false;

  String _field(Map<String, dynamic> item, String key) => item[key]?.toString().trim() ?? '';

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> item = widget.items[_index];
    final String answer = _field(item, 'correct_option_text');
    final String explanation = [_field(item, 'formal_explanation'), _field(item, 'informal_explanation')]
        .where((value) => value.isNotEmpty).join('\n\n');
    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(backgroundColor: AppColors.brandNightBlue, foregroundColor: AppColors.pureWhite,
        title: Text('Flashcard · ${widget.subject}')),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text('${_index + 1} / ${widget.items.length}', style: TextStyle(color: AppColors.white70)),
          const SizedBox(height: 20),
          Card(color: AppColors.eleganceMidnight, child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_field(item, 'question_text'), style: TextStyle(color: AppColors.pureWhite, fontSize: 20)),
              if (_revealed) ...[
                const SizedBox(height: 24),
                Divider(color: AppColors.white38),
                Text(answer.isEmpty ? 'Risposta non disponibile nello storico' : answer,
                    style: TextStyle(color: AppColors.materialSky, fontSize: 18)),
                if (explanation.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(explanation, style: TextStyle(color: AppColors.white70)),
                ],
              ],
            ]),
          )),
          const SizedBox(height: 20),
          FilledButton(onPressed: () {
            if (!_revealed) {
              setState(() => _revealed = true);
            } else if (_index < widget.items.length - 1) {
              setState(() { _index++; _revealed = false; });
            } else {
              Navigator.pop(context);
            }
          }, child: Text(!_revealed ? 'Mostra risposta' : _index == widget.items.length - 1 ? 'Fine' : 'Prossima scheda')),
        ]),
      ))),
    );
  }
}
