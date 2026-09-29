import 'package:flutter/material.dart';

import 'package:fe/quiz/exercises/exercise_local_repository.dart';
import 'package:fe/theme/app_palette.dart';
import 'package:fe/widgets/studentlab_ui/studentlab_ui.dart';
import 'package:fe/quiz/exercises/exercise_api_service.dart';
import 'package:fe/quiz/exercises/exercise_models.dart';
import 'package:fe/quiz/exercises/widgets/exercise_view.dart';

/// Ripasso con le flashcard (canvas: Esercizio · Flashcard).
/// Con l'account la programmazione è sul server (vale su tutti i dispositivi);
/// da ospite resta su questo telefono.
class FlashcardSessionPage extends StatefulWidget {
  final String department;
  final String course;
  final String subject;
  final String? subjectLabel;
  final List<String> arguments;

  const FlashcardSessionPage({
    super.key,
    required this.department,
    required this.course,
    required this.subject,
    this.subjectLabel,
    this.arguments = const <String>[],
  });

  @override
  State<FlashcardSessionPage> createState() => _FlashcardSessionPageState();
}

class _FlashcardSessionPageState extends State<FlashcardSessionPage> {
  final ExerciseApiService _api = ExerciseApiService();
  final ExerciseLocalRepository _local = ExerciseLocalRepository();
  bool _loading = true;
  String? _error;
  List<ExerciseItem> _cards = <ExerciseItem>[];
  final Map<String, Map<String, dynamic>> _states = <String, Map<String, dynamic>>{};
  final Map<int, int> _grades = <int, int>{};
  int _index = 0;
  int _total = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final Map<String, dynamic> deck = await _api.flashcardDeck(
        department: widget.department,
        course: widget.course,
        subject: widget.subject,
        arguments: widget.arguments,
        limit: _api.isLoggedIn ? 20 : 100,
      );
      final List<Map<String, dynamic>> raw = asMapList(deck['cards']);
      _total = int.tryParse('${deck['total'] ?? raw.length}') ?? raw.length;
      final List<ExerciseItem> cards = raw.map(ExerciseItem.fromJson).toList();
      if (deck['synced'] == true) {
        for (final Map<String, dynamic> card in raw) {
          _states['${card['id']}'] = asMap(card['state']);
        }
        _cards = cards;
      } else {
        final Map<String, Map<String, dynamic>> local =
            await _local.flashcardStates(widget.department, widget.course, widget.subject);
        _states.addAll(local);
        _cards = _local.dueOrder(cards, local);
      }
      if (_cards.isEmpty) _error = null;
    } catch (error) {
      _error = cleanError(error, 'Schede non disponibili.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _grade(int grade) async {
    if (_saving || _index >= _cards.length) return;
    final ExerciseItem card = _cards[_index];
    setState(() => _saving = true);
    try {
      if (_api.isLoggedIn) {
        final Map<String, dynamic> response = await _api.flashcardReview(
          department: widget.department,
          course: widget.course,
          subject: widget.subject,
          cardId: card.id,
          grade: grade,
        );
        _states[card.id] = asMap(response['state']);
      } else {
        _states[card.id] = await _local.reviewFlashcard(
          department: widget.department,
          course: widget.course,
          subject: widget.subject,
          cardId: card.id,
          grade: grade,
          argument: card.argument,
        );
      }
      _grades[grade] = (_grades[grade] ?? 0) + 1;
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) setState(() => _index++);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cleanError(error))));
    }
    if (mounted) setState(() => _saving = false);
  }

  Widget _done(BuildContext context) {
    final p = context.palette;
    const List<String> labels = <String>['Per niente', 'A fatica', 'Bene', 'Facile'];
    return ListView(padding: const EdgeInsets.all(20), children: <Widget>[
      const SizedBox(height: 20),
      Icon(Icons.celebration_outlined, size: 56, color: p.adminGreen),
      const SizedBox(height: 12),
      Text(_cards.isEmpty ? 'Niente da ripassare adesso' : 'Ripasso di oggi completato',
          textAlign: TextAlign.center, style: TextStyle(color: p.pureWhite, fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text(
        _cards.isEmpty
            ? 'Le schede torneranno quando sarà il momento di rivederle.'
            : '${_cards.length} schede ripassate. Quelle che ricordavi meno torneranno prima.',
        textAlign: TextAlign.center,
        style: SlText.muted(p),
      ),
      const SizedBox(height: 20),
      if (_grades.isNotEmpty)
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: <Widget>[
          for (int g = 0; g < 4; g++)
            if ((_grades[g] ?? 0) > 0)
              SlStatusBadge(
                label: '${labels[g]}: ${_grades[g]}',
                tone: g == 0 ? SlTone.danger : (g == 1 ? SlTone.warning : SlTone.success),
              ),
        ]),
      const SizedBox(height: 24),
      FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fine')),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget body;
    if (_loading) {
      body = Center(child: CircularProgressIndicator(color: p.skyBlue));
    } else if (_error != null) {
      body = Padding(padding: const EdgeInsets.all(16), child: SlErrorCard(title: 'Attenzione', message: _error!, onRetry: _load));
    } else if (_index >= _cards.length) {
      body = _done(context);
    } else {
      final ExerciseItem card = _cards[_index];
      body = ListView(padding: const EdgeInsets.all(16), children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _index / _cards.length,
            minHeight: 5,
            backgroundColor: p.pureWhite.withValues(alpha: 0.08),
            color: const Color(0xFFF08CFF),
          ),
        ),
        const SizedBox(height: 10),
        Text('Ripasso di oggi: ${_cards.length} schede${_total > _cards.length ? ' su $_total' : ''}',
            style: SlText.muted(p).copyWith(fontSize: 12)),
        const SizedBox(height: 14),
        ExerciseView(
          key: ValueKey<String>('card-${card.id}-$_index'),
          item: card,
          scope: ExerciseScope(department: widget.department, course: widget.course, subject: widget.subject),
          locked: _saving,
          flashcardState: _states[card.id],
          onGrade: _grade,
          onChanged: (Map<String, dynamic> _, bool __) {},
        ),
      ]);
    }
    return Scaffold(
      backgroundColor: p.darkElegance,
      appBar: AppBar(
        backgroundColor: p.eleganceMidnight,
        foregroundColor: p.pureWhite,
        title: Text(widget.subjectLabel == null ? 'Flashcard' : 'Flashcard · ${widget.subjectLabel}'),
        actions: <Widget>[
          if (!_loading && _cards.isNotEmpty && _index < _cards.length)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text('${_index + 1} / ${_cards.length}',
                    style: TextStyle(color: p.pureWhite.withValues(alpha: 0.75), fontFamily: 'monospace')),
              ),
            ),
        ],
      ),
      body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680), child: body))),
    );
  }
}
