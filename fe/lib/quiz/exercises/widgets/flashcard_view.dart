import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:fe/theme/app_palette.dart';
import 'package:fe/widgets/studentlab_ui/studentlab_ui.dart';
import 'package:fe/quiz/exercises/exercise_models.dart';
import 'package:fe/quiz/exercises/flashcard_scheduler.dart';

/// Scheda: fronte → gira → "Quanto te lo ricordavi?" con 4 voti.
/// Le etichette dei pulsanti dicono quando tornerà la scheda.
class FlashcardView extends StatefulWidget {
  final ExerciseItem item;
  final bool locked;
  final void Function(int grade)? onGrade;
  final Map<String, dynamic>? state;
  final AnswerChanged onChanged;

  const FlashcardView({super.key, required this.item, required this.onChanged, this.locked = false, this.onGrade, this.state});

  @override
  State<FlashcardView> createState() => _FlashcardViewState();
}

class _FlashcardViewState extends State<FlashcardView> with SingleTickerProviderStateMixin {
  late final AnimationController _flip =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  bool _showBack = false;
  int? _grade;

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  void _turn() {
    setState(() => _showBack = !_showBack);
    _showBack ? _flip.forward() : _flip.reverse();
  }

  void _choose(int grade) {
    if (widget.locked) return;
    setState(() => _grade = grade);
    widget.onChanged(<String, dynamic>{'grade': grade}, true);
    widget.onGrade?.call(grade);
  }

  Widget _face(BuildContext context, {required bool back}) {
    final p = context.palette;
    final String text = back ? widget.item.data['back']?.toString() ?? '' : widget.item.data['front']?.toString() ?? '';
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 240),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: back ? p.eleganceDeepNavy : p.eleganceMidnight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (back ? p.adminGreen : const Color(0xFFF08CFF)).withValues(alpha: 0.4)),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        SlOverline(back ? 'RETRO${widget.item.argument != null ? ' · ${widget.item.argument!.toUpperCase()}' : ''}' : 'FRONTE'),
        const SizedBox(height: 12),
        Text(text,
            style: TextStyle(
                color: p.pureWhite,
                fontSize: back ? 16 : (text.length > 80 ? 18 : 26),
                fontWeight: back ? FontWeight.w400 : FontWeight.w700,
                height: 1.4)),
        if (!back) ...<Widget>[
          const SizedBox(height: 18),
          Text('Tocca per girare', style: SlText.muted(p).copyWith(fontSize: 12)),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Map<String, dynamic> state = widget.state ?? const <String, dynamic>{};
    final Map<String, String> labels = FlashcardScheduler.buttonLabels(
      ease: (state['ease'] as num?)?.toDouble() ?? 2.5,
      intervalDays: int.tryParse('${state['interval_days'] ?? 0}') ?? 0,
      reviews: int.tryParse('${state['reviews'] ?? 0}') ?? 0,
    );
    const List<(int, String)> grades = <(int, String)>[(0, 'Per niente'), (1, 'A fatica'), (2, 'Bene'), (3, 'Facile')];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      Semantics(
        button: true,
        label: _showBack ? 'Retro della scheda. Tocca per tornare al fronte' : 'Fronte della scheda. Tocca per girare',
        child: GestureDetector(
          onTap: _turn,
          child: AnimatedBuilder(
            animation: _flip,
            builder: (BuildContext context, Widget? child) {
              final double angle = _flip.value * math.pi;
              final bool back = angle > math.pi / 2;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0012)
                  ..rotateY(angle),
                child: back
                    ? Transform(alignment: Alignment.center, transform: Matrix4.rotationY(math.pi), child: _face(context, back: true))
                    : _face(context, back: false),
              );
            },
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (_showBack) ...<Widget>[
        Text('Quanto te lo ricordavi?', style: TextStyle(color: p.pureWhite, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(children: <Widget>[
          for (final (int grade, String label) in grades)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    backgroundColor: _grade == grade ? p.skyBlue.withValues(alpha: 0.18) : null,
                    side: BorderSide(
                        color: grade == 0 ? p.adminCoral.withValues(alpha: 0.6) : (grade == 3 ? p.adminGreen.withValues(alpha: 0.6)
                            : p.pureWhite.withValues(alpha: 0.2))),
                  ),
                  onPressed: widget.locked ? null : () => _choose(grade),
                  child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5)),
                    const SizedBox(height: 2),
                    Text(labels['$grade'] ?? '', style: SlText.muted(p).copyWith(fontSize: 11)),
                  ]),
                ),
              ),
            ),
        ]),
      ] else
        Center(
          child: TextButton.icon(onPressed: _turn, icon: const Icon(Icons.flip_rounded), label: const Text('Mostra il retro')),
        ),
    ]);
  }
}
