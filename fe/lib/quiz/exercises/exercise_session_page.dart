import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fe/quiz/exercises/exercise_local_repository.dart';
import 'package:fe/local_storage/services/study_plan_sync_service.dart';
import 'package:fe/theme/app_palette.dart';
import 'package:fe/widgets/studentlab_ui/studentlab_ui.dart';
import 'package:fe/quiz/teacher/widgets/quiz_execution_guard.dart';
import 'package:fe/quiz/exercises/exercise_api_service.dart';
import 'package:fe/quiz/exercises/exercise_models.dart';
import 'package:fe/quiz/exercises/widgets/exercise_attachments.dart';
import 'package:fe/quiz/exercises/widgets/exercise_view.dart';

/// Svolgimento di una serie di esercizi (tavole Es* del canvas).
///
/// - Esercitazione libera: correzione dopo ogni esercizio (sul server), con
///   un secondo tentativo. Con l'account la sessione finisce nello storico e
///   nel Ripasso; da ospite resta sul telefono (SQLite).
/// - Assegnazione del docente o di StudentLab: stesso aspetto; in modalità
///   controllata niente correzione fino alla consegna, tempo e protezione
///   dell'app come nei quiz controllati.
class ExerciseSessionPage extends StatefulWidget {
  final String department;
  final String course;
  final String subject;
  final String title;
  final List<String> types;
  final List<String> arguments;
  final int count;
  final List<String> itemIds;
  /// Filtri scelti nella pagina degli esercizi (argomenti, difficoltà, durata, nuovi/da rivedere).
  final ExerciseChoice? choice;

  /// "Crea un quiz": correzione solo alla consegna, un tentativo per esercizio,
  /// niente suggerimenti; con [timeLimitSeconds] c'è anche il tempo.
  final bool quizMode;
  final int? timeLimitSeconds;
  final Map<String, dynamic>? attempt;
  final String executionMode;
  final String externalActivityPolicy;
  final int? attemptsPerItem;

  const ExerciseSessionPage.practice({
    super.key,
    required this.department,
    required this.course,
    required this.subject,
    this.title = 'Esercizi',
    this.types = const <String>[],
    this.arguments = const <String>[],
    this.count = 10,
    this.itemIds = const <String>[],
    this.choice,
    this.quizMode = false,
    this.timeLimitSeconds,
  })  : attempt = null,
        executionMode = 'practice',
        externalActivityPolicy = 'disabled',
        attemptsPerItem = null;

  /// Tentativo già creato dal server (assegnazione o esercitazione salvata).
  ExerciseSessionPage.attempt({
    super.key,
    required Map<String, dynamic> this.attempt,
    this.title = 'Esercizi assegnati',
    this.attemptsPerItem,
  })  : department = attempt['department']?.toString() ?? '',
        course = attempt['course']?.toString() ?? '',
        subject = attempt['subject']?.toString() ?? '',
        types = const <String>[],
        arguments = const <String>[],
        count = 0,
        itemIds = const <String>[],
        choice = null,
        quizMode = false,
        timeLimitSeconds = null,
        executionMode = attempt['execution_mode']?.toString() ?? 'practice',
        externalActivityPolicy = attempt['external_activity_policy']?.toString() ?? 'disabled';

  bool get isSimulation => executionMode == 'simulation';

  @override
  State<ExerciseSessionPage> createState() => _ExerciseSessionPageState();
}

class _ExerciseSessionPageState extends State<ExerciseSessionPage> {
  final ExerciseApiService _api = ExerciseApiService();
  final ExerciseLocalRepository _local = ExerciseLocalRepository();
  final Stopwatch _clock = Stopwatch();

  bool _loading = true;
  String? _error;
  List<ExerciseItem> _items = <ExerciseItem>[];
  int _index = 0;
  int? _attemptId;
  bool _guest = false;
  final Map<String, Map<String, dynamic>> _answers = <String, Map<String, dynamic>>{};
  final Map<String, bool> _complete = <String, bool>{};
  final Map<String, ExerciseResult> _results = <String, ExerciseResult>{};
  final Map<String, int> _tries = <String, int>{};
  final Map<String, int> _serverMax = <String, int>{};
  final Set<String> _final = <String>{};
  bool _assigned = false;
  final Set<String> _showHint = <String>{};
  bool _checking = false;
  bool _finishing = false;
  bool _finished = false;
  Map<String, dynamic>? _serverSummary;
  Timer? _timer;
  int? _remaining;

  /// Correzione rimandata alla consegna: simulazione assegnata o quiz creato dallo studente.
  bool get _deferred => widget.isSimulation || widget.quizMode;
  int get _maxTries => _deferred ? 1 : (widget.attemptsPerItem ?? 2);
  int _maxFor(String id) => _serverMax[id] ?? _maxTries;
  ExerciseItem? get _current => _index >= 0 && _index < _items.length ? _items[_index] : null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      Map<String, dynamic>? attempt = widget.attempt;
      if (attempt == null && widget.itemIds.isEmpty && _api.isLoggedIn) {
        // Con l'account l'esercitazione è salvata nello storico e nel Ripasso.
        try {
          attempt = await _api.start(
            department: widget.department,
            course: widget.course,
            subject: widget.subject,
            types: widget.types,
            arguments: widget.arguments,
            count: widget.count,
            choice: widget.choice,
            timeLimitSeconds: widget.timeLimitSeconds,
            quiz: widget.quizMode,
          );
        } catch (_) {
          attempt = null;
        }
      }
      if (!mounted) return;
      if (attempt != null) {
        _attemptId = int.tryParse('${attempt['attempt_id'] ?? ''}');
        _assigned = attempt['assignment_id'] != null;
        _items = asMapList(attempt['questions']).map(ExerciseItem.fromJson).toList();
        _restoreChecks();
        final int? limit = int.tryParse('${attempt['time_limit_seconds'] ?? ''}');
        if (limit != null && limit > 0) {
          final DateTime? started = DateTime.tryParse('${attempt['started_at'] ?? ''}')?.toLocal();
          final int elapsed = started == null ? 0 : DateTime.now().difference(started).inSeconds;
          _remaining = (limit - elapsed).clamp(0, limit);
          _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
        }
      } else {
        _guest = !_api.isLoggedIn;
        // Da ospite "solo nuovi" e "solo da rivedere" si basano sullo storico del telefono.
        final ExerciseChoice? choice = widget.choice;
        final List<Map<String, dynamic>> history =
            _guest && choice != null && (choice.onlyNew || choice.onlyMistakes)
                ? await _local
                    .guestHistory(widget.department, widget.course, widget.subject)
                    .catchError((Object _) => <Map<String, dynamic>>[])
                : const <Map<String, dynamic>>[];
        _items = await _api.practice(
          department: widget.department,
          course: widget.course,
          subject: widget.subject,
          types: widget.types,
          arguments: widget.arguments,
          count: widget.count,
          itemIds: widget.itemIds,
          choice: choice,
          history: history,
        );
        // Quiz senza tentativo sul server (ospite): il tempo lo tiene il telefono.
        final int? limit = widget.timeLimitSeconds;
        if (mounted && limit != null && limit > 0 && _items.isNotEmpty) {
          _remaining = limit;
          _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
        }
      }
      if (_items.isEmpty) _error = 'Nessun esercizio disponibile con questi filtri.';
      _clock.start();
    } catch (error) {
      _error = cleanError(error, 'Esercizi non disponibili.');
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Ripresa di un tentativo: esercizi già controllati (e chiusi) restano com'erano.
  void _restoreChecks() {
    for (final ExerciseItem item in _items) {
      final int tries = int.tryParse('${item.check['tries'] ?? 0}') ?? 0;
      if (tries > 0) _tries[item.id] = tries;
      if (item.check['final'] == true) {
        _final.add(item.id);
        _answers[item.id] = asMap(item.check['answer']);
        _complete[item.id] = true;
        _results[item.id] = ExerciseResult.fromJson(asMap(item.check['result']));
      }
    }
  }

  Future<ExerciseResult> _attemptCheck(String itemId, Map<String, dynamic> answer,
      {Map<String, dynamic>? scope}) async {
    final Map<String, dynamic> data =
        await _api.attemptCheck(attemptId: _attemptId!, itemId: itemId, answer: answer, scope: scope);
    if (scope == null) {
      final int? tries = int.tryParse('${data['tries'] ?? ''}');
      final int? max = int.tryParse('${data['max_tries'] ?? ''}');
      if (tries != null) _tries[itemId] = tries;
      if (max != null) _serverMax[itemId] = max;
      if (data['final'] == true) _final.add(itemId);
    }
    return ExerciseResult.fromJson(data);
  }

  void _tick() {
    if (!mounted) {
      _timer?.cancel();
      return;
    }
    final int? value = _remaining;
    if (value == null || _finished) return;
    if (value <= 1) {
      _timer?.cancel();
      setState(() => _remaining = 0);
      _finish(reason: 'time_expired');
      return;
    }
    setState(() => _remaining = value - 1);
  }

  ExerciseScope get _scope => ExerciseScope(
        department: widget.department,
        course: widget.course,
        subject: widget.subject,
        // Nei compiti assegnati la tabella di "Traccia" si controlla tutta insieme.
        checkPart: _deferred || _assigned
            ? null
            : _attemptId != null
                ? (Map<String, dynamic> answer, Map<String, dynamic> scope) =>
                    _attemptCheck(_current!.id, answer, scope: scope)
                : (Map<String, dynamic> answer, Map<String, dynamic> scope) => _api.check(
                  department: widget.department,
                  course: widget.course,
                  subject: widget.subject,
                  itemId: _current!.id,
                  answer: answer,
                  scope: scope,
                ),
        runCode: _api.isLoggedIn && !_deferred
            ? (String code) => _api.runCode(
                  department: widget.department,
                  course: widget.course,
                  subject: widget.subject,
                  itemId: _current!.id,
                  code: code,
                )
            : null,
      );

  Future<void> _check() async {
    final ExerciseItem? item = _current;
    if (item == null) return;
    if (_deferred) {
      _next();
      return;
    }
    setState(() => _checking = true);
    try {
      final Map<String, dynamic> answer = _answers[item.id] ?? const <String, dynamic>{};
      final ExerciseResult result = item.isMultipleChoice
          ? await _api.checkMultipleChoice(
              department: widget.department,
              course: widget.course,
              subject: widget.subject,
              questionId: item.id,
              optionId: asStringList(answer['selected']).firstOrNull ?? '',
            )
          : _attemptId != null
              ? await _attemptCheck(item.id, answer)
              : await _api.check(
                  department: widget.department,
                  course: widget.course,
                  subject: widget.subject,
                  itemId: item.id,
                  answer: answer,
                );
      setState(() {
        _results[item.id] = result;
        // nei tentativi salvati il conteggio arriva dal server
        if (_attemptId == null || item.isMultipleChoice) _tries[item.id] = (_tries[item.id] ?? 0) + 1;
      });
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cleanError(error))));
    }
    if (mounted) setState(() => _checking = false);
  }

  void _retry() {
    final ExerciseItem? item = _current;
    if (item == null || _final.contains(item.id)) return;
    setState(() => _results.remove(item.id));
  }

  void _gradeFlashcard(int grade) {
    final ExerciseItem? item = _current;
    if (item == null) return;
    _answers[item.id] = <String, dynamic>{'grade': grade};
    _complete[item.id] = true;
    setState(() {
      _results[item.id] = ExerciseResult(
        isCorrect: grade >= 2,
        score: grade / 3,
        feedback: <String, dynamic>{'grade': grade},
        solution: null,
        explanation: '',
        solutionText: item.data['back']?.toString() ?? '',
      );
      _tries[item.id] = 1;
    });
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (mounted && _current?.id == item.id) _next();
    });
  }

  void _next() {
    if (_index < _items.length - 1) {
      setState(() => _index++);
    } else {
      _finish();
    }
  }

  /// Quiz senza tentativo sul server: alla consegna si correggono una per una
  /// le risposte date (le stesse chiamate di "Verifica"). Le risposte vuote restano non svolte.
  Future<void> _gradeAll() async {
    for (final ExerciseItem item in _items) {
      if (_results.containsKey(item.id) || item.type == 'flashcard') continue;
      final Map<String, dynamic>? answer = _answers[item.id];
      // come sul server: si corregge qualunque risposta data, anche incompleta
      if (answer == null || answer.isEmpty) continue;
      try {
        _results[item.id] = item.isMultipleChoice
            ? await _api.checkMultipleChoice(
                department: widget.department,
                course: widget.course,
                subject: widget.subject,
                questionId: item.id,
                optionId: asStringList(answer['selected']).firstOrNull ?? '',
              )
            : await _api.check(
                department: widget.department,
                course: widget.course,
                subject: widget.subject,
                itemId: item.id,
                answer: answer,
              );
        _tries[item.id] = 1;
      } catch (_) {
        // Un esercizio non corretto (rete) resta "non svolto": gli altri si correggono lo stesso.
      }
    }
  }

  Future<void> _finish({String reason = 'completed'}) async {
    if (_finishing || _finished) return;
    setState(() => _finishing = true);
    _timer?.cancel();
    _clock.stop();
    try {
      if (_attemptId != null) {
        final List<Map<String, dynamic>> answers = <Map<String, dynamic>>[];
        for (final ExerciseItem item in _items) {
          final Map<String, dynamic>? answer = _answers[item.id];
          if (answer == null) continue;
          if (item.isMultipleChoice) {
            final String? selected = asStringList(answer['selected']).firstOrNull;
            if (selected != null) answers.add(<String, dynamic>{'question_id': item.id, 'selected_option_id': selected});
          } else {
            answers.add(<String, dynamic>{'question_id': item.id, 'answer_payload': answer});
          }
        }
        _serverSummary = await _api.complete(
          attemptId: _attemptId!,
          answers: answers,
          elapsedSeconds: _clock.elapsed.inSeconds,
          completionReason: reason,
        );
        for (final Map<String, dynamic> saved in asMapList(_serverSummary?['answers'])) {
          final String id = saved['question_id']?.toString() ?? '';
          if (id.isEmpty) continue;
          final bool mc = (saved['question_type']?.toString() ?? kMultipleChoice) == kMultipleChoice;
          _results[id] = ExerciseResult(
            isCorrect: saved['is_correct'] == true,
            score: (saved['score'] as num?)?.toDouble() ?? (saved['is_correct'] == true ? 1 : 0),
            feedback: asMap(asMap(saved['answer_payload'])['feedback']),
            solution: mc
                ? <String, dynamic>{'correct': <String>[saved['correct_option_id']?.toString() ?? '']}
                : (saved['correct_payload'] is Map ? asMap(saved['correct_payload']) : null),
            explanation: <String>[saved['formal_explanation']?.toString() ?? '', saved['informal_explanation']?.toString() ?? '']
                .where((String t) => t.trim().isNotEmpty)
                .join('\n\n'),
            solutionText: mc ? '' : saved['correct_option_text']?.toString() ?? '',
          );
        }
        try {
          await StudyPlanSyncService().refreshAfterQuizCompletion();
        } catch (_) {}
      } else {
        if (_deferred) await _gradeAll();
      }
      if (_attemptId == null && _guest) {
        try {
          await _local.saveGuestSession(
            department: widget.department,
            course: widget.course,
            subject: widget.subject,
            items: _items,
            answers: _answers,
            results: _results,
          );
          await StudyPlanSyncService().refreshGuestPlan();
        } catch (_) {
          // Il salvataggio locale non deve impedire di vedere il risultato.
        }
      }
      if (mounted) {
        setState(() {
          _finished = true;
          _index = -1; // riepilogo
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(cleanError(error, 'Consegna non riuscita.'))));
      }
    }
    if (mounted) setState(() => _finishing = false);
  }

  Future<bool> _confirmExit() async {
    if (_finished || _items.isEmpty) return true;
    final p = context.palette;
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: p.eleganceDeepNavy,
        title: Text(_attemptId != null ? 'Consegnare e uscire?' : 'Uscire dagli esercizi?'),
        content: Text(_attemptId != null
            ? 'Gli esercizi senza risposta conteranno come non svolti.'
            : 'Le risposte date finora non verranno salvate.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Continua')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(_attemptId != null ? 'Consegna ed esci' : 'Esci'),
          ),
        ],
      ),
    );
    if (leave == true && _attemptId != null) {
      await _finish(reason: 'user_confirmed_exit');
      return false;
    }
    return leave == true;
  }

  // ---------------------------------------------------------------- interfaccia
  String _timeLabel(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

  Widget _header(BuildContext context, ExerciseItem item) {
    final p = context.palette;
    final Color color = categoryColor(context, item.info.category);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: (_index + (_results.containsKey(item.id) ? 1 : 0)) / _items.length,
          minHeight: 5,
          backgroundColor: p.pureWhite.withValues(alpha: 0.08),
          color: p.skyBlue,
        ),
      ),
      const SizedBox(height: 12),
      Row(children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
            Icon(item.info.icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text('${categoryLabel(item.info.category)} · ${item.info.label.toUpperCase()}',
                style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
          ]),
        ),
        const Spacer(),
        if (_remaining != null)
          Row(children: <Widget>[
            Icon(Icons.timer_outlined, size: 16, color: (_remaining ?? 0) < 60 ? p.adminCoral : p.pureWhite.withValues(alpha: 0.7)),
            const SizedBox(width: 4),
            Text(_timeLabel(_remaining ?? 0),
                style: TextStyle(color: (_remaining ?? 0) < 60 ? p.adminCoral : p.pureWhite, fontFamily: 'monospace')),
          ]),
      ]),
      if (item.argument != null && item.argument!.isNotEmpty) ...<Widget>[
        const SizedBox(height: 6),
        Text(item.argument!, style: SlText.muted(p).copyWith(fontSize: 12)),
      ],
    ]);
  }

  Widget _resultPanel(BuildContext context, ExerciseItem item, ExerciseResult result) {
    final p = context.palette;
    if (item.type == 'flashcard') return const SizedBox.shrink();
    final Color color = result.isCorrect ? p.adminGreen : (result.isPartial ? p.adminAmber : p.adminCoral);
    final String title = result.isCorrect ? 'Giusto!' : (result.isPartial ? 'Quasi' : 'Non ancora');
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        Row(children: <Widget>[
          Icon(result.isCorrect ? Icons.check_circle_rounded : (result.isPartial ? Icons.adjust_rounded : Icons.cancel_rounded),
              color: color),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 16)),
          const Spacer(),
          if (!result.isCorrect)
            Text('${(result.score * 100).round()}%', style: TextStyle(color: color, fontFamily: 'monospace')),
        ]),
        if (result.explanation.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(result.explanation, style: SlText.body(p).copyWith(fontSize: 13.5, height: 1.45)),
        ],
        if (!result.isCorrect &&
            result.solutionText.trim().isNotEmpty &&
            ((_tries[item.id] ?? 0) >= _maxFor(item.id) || _final.contains(item.id) || _finished)) ...<Widget>[
            const SizedBox(height: 8),
            SlOverline('SOLUZIONE'),
            const SizedBox(height: 4),
            SelectableText(result.solutionText, style: SlText.body(p).copyWith(fontSize: 13)),
          ],
      ]),
    );
  }

  Widget _footer(BuildContext context, ExerciseItem item) {
    final p = context.palette;
    final ExerciseResult? result = _results[item.id];
    final bool last = _index == _items.length - 1;
    if (_finished) {
      return Row(children: <Widget>[
        OutlinedButton(onPressed: _index == 0 ? null : () => setState(() => _index--), child: const Text('Indietro')),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            onPressed: () => last ? setState(() => _index = -1) : setState(() => _index++),
            child: Text(last ? 'Torna al riepilogo' : 'Avanti'),
          ),
        ),
      ]);
    }
    if (item.type == 'flashcard') {
      return Text('Gira la scheda e scegli quanto te la ricordavi.', textAlign: TextAlign.center, style: SlText.muted(p));
    }
    if (result == null) {
      final bool ready = _complete[item.id] == true;
      return Row(children: <Widget>[
        if (!_deferred && item.hint.isNotEmpty)
          IconButton(
            tooltip: 'Suggerimento',
            onPressed: () => setState(() => _showHint.contains(item.id) ? _showHint.remove(item.id) : _showHint.add(item.id)),
            icon: Icon(Icons.lightbulb_outline_rounded, color: p.adminAmber),
          ),
        if (_deferred && _index > 0)
          OutlinedButton(onPressed: () => setState(() => _index--), child: const Text('Indietro')),
        const SizedBox(width: 8),
        Expanded(
          child: FilledButton(
            onPressed: _checking || _finishing
                ? null
                : _deferred
                    ? (last ? () => _finish() : _next)
                    : (ready ? _check : null),
            child: Text(_checking
                ? 'Controllo…'
                : _deferred
                    ? (last ? 'Consegna' : 'Avanti')
                    : 'Verifica'),
          ),
        ),
      ]);
    }
    final bool canRetry =
        !result.isCorrect && !_final.contains(item.id) && (_tries[item.id] ?? 0) < _maxFor(item.id);
    return Row(children: <Widget>[
      if (canRetry) ...<Widget>[
        Expanded(child: OutlinedButton(onPressed: _retry, child: const Text('Riprova'))),
        const SizedBox(width: 8),
      ],
      Expanded(
        flex: 2,
        child: FilledButton(
          onPressed: _finishing ? null : _next,
          child: Text(_finishing ? 'Salvataggio…' : (last ? 'Vedi il risultato' : 'Continua')),
        ),
      ),
    ]);
  }

  Widget _exercise(BuildContext context, ExerciseItem item) {
    final p = context.palette;
    final ExerciseResult? result = _results[item.id];
    final bool locked = _finished || result != null || _finishing;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: <Widget>[
      _header(context, item),
      const SizedBox(height: 14),
      if (item.text.trim().isNotEmpty)
        Text(item.text, style: TextStyle(color: p.pureWhite, fontSize: 18, fontWeight: FontWeight.w700, height: 1.35)),
      const SizedBox(height: 12),
      item.isMultipleChoice
          ? ExerciseAttachments.question(
              attachments: item.attachments,
              department: widget.department,
              course: widget.course,
              subject: widget.subject,
              questionId: item.id,
            )
          : ExerciseAttachments.exercise(
              attachments: item.attachments,
              department: widget.department,
              course: widget.course,
              subject: widget.subject,
              itemId: item.id,
              exclude: <String>{if (item.data['image_attachment_id'] != null) item.data['image_attachment_id'].toString()},
            ),
      const SizedBox(height: 12),
      ExerciseView(
        item: item,
        scope: _scope,
        result: result,
        locked: locked,
        initialAnswer: _answers[item.id],
        onGrade: locked ? null : _gradeFlashcard,
        onChanged: (Map<String, dynamic> answer, bool complete) {
          _answers[item.id] = answer;
          if (_complete[item.id] != complete) setState(() => _complete[item.id] = complete);
        },
      ),
      if (_showHint.contains(item.id) && item.hint.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: p.adminAmber.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.adminAmber.withValues(alpha: 0.35)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Icon(Icons.lightbulb_outline_rounded, color: p.adminAmber, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(item.hint, style: SlText.body(p).copyWith(fontSize: 13))),
          ]),
        ),
      if (result != null) _resultPanel(context, item, result),
    ]);
  }

  Widget _summary(BuildContext context) {
    final p = context.palette;
    final double total = _items.fold<double>(0, (double sum, ExerciseItem i) => sum + (_results[i.id]?.score ?? 0));
    final int percentage = _items.isEmpty ? 0 : (total / _items.length * 100).round();
    final int correct = _items.where((ExerciseItem i) => _results[i.id]?.isCorrect == true).length;
    final List<ExerciseItem> toReview = _items
        .where((ExerciseItem i) => _results[i.id]?.isCorrect != true && !i.isMultipleChoice && !i.id.startsWith('qf:'))
        .toList();
    return ListView(padding: const EdgeInsets.all(16), children: <Widget>[
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: p.eleganceMidnight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: p.skyBlue.withValues(alpha: 0.2)),
        ),
        child: Column(children: <Widget>[
          Text('$percentage%',
              style: TextStyle(
                  color: percentage >= 75 ? p.adminGreen : (percentage >= 40 ? p.adminAmber : p.adminCoral),
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace')),
          const SizedBox(height: 4),
          Text('$correct esercizi giusti su ${_items.length}', style: SlText.body(p)),
          const SizedBox(height: 6),
          Text(
            _attemptId != null
                ? 'Salvato nello storico: gli errori finiscono nel tuo Ripasso.'
                : (_guest ? 'Salvato su questo telefono: lo trovi nel Ripasso.' : ''),
            textAlign: TextAlign.center,
            style: SlText.muted(p).copyWith(fontSize: 12),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      SlOverline('ESERCIZI'),
      const SizedBox(height: 8),
      for (int i = 0; i < _items.length; i++)
        Builder(builder: (BuildContext context) {
          final ExerciseItem item = _items[i];
          final ExerciseResult? result = _results[item.id];
          final bool? ok = result == null ? null : result.isCorrect;
          return Card(
            color: p.eleganceMidnight,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(item.info.icon, color: categoryColor(context, item.info.category)),
              title: Text(item.text.isEmpty ? item.info.label : item.text,
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.pureWhite, fontSize: 14)),
              subtitle: Text(
                  result == null ? 'Non svolto' : '${item.info.label} · ${(result.score * 100).round()}%',
                  style: SlText.muted(p).copyWith(fontSize: 12)),
              trailing: Icon(
                ok == null ? Icons.remove_circle_outline_rounded : (ok ? Icons.check_circle_rounded : Icons.cancel_rounded),
                color: ok == null ? p.pureWhite.withValues(alpha: 0.4) : (ok ? p.adminGreen : p.adminCoral),
              ),
              onTap: () => setState(() => _index = i),
            ),
          );
        }),
      const SizedBox(height: 12),
      if (toReview.isNotEmpty && !widget.isSimulation)
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
            builder: (_) => ExerciseSessionPage.practice(
              department: widget.department,
              course: widget.course,
              subject: widget.subject,
              title: 'Rifai gli errori',
              itemIds: toReview.map((ExerciseItem i) => i.id).toList(),
            ),
          )),
          icon: const Icon(Icons.replay_rounded),
          label: Text('Rifai i ${toReview.length} da rivedere'),
        ),
      const SizedBox(height: 8),
      FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Fine')),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ExerciseItem? item = _finished && _index < 0 ? null : _current;
    final Widget body;
    if (_loading) {
      body = Center(child: CircularProgressIndicator(color: p.skyBlue));
    } else if (_error != null) {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: SlErrorCard(title: 'Esercizi non disponibili', message: _error!, onRetry: _load),
      );
    } else if (_finished && (item == null || _index < 0)) {
      body = _summary(context);
    } else if (item == null) {
      body = _summary(context);
    } else {
      body = _exercise(context, item);
    }
    final Widget scaffold = PopScope(
      canPop: _finished || _items.isEmpty || _error != null,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final NavigatorState navigator = Navigator.of(context);
        if (await _confirmExit() && mounted) navigator.pop();
      },
      child: Scaffold(
        backgroundColor: p.darkElegance,
        appBar: AppBar(
          backgroundColor: p.eleganceMidnight,
          foregroundColor: p.pureWhite,
          title: Text(_finished ? 'Risultato' : widget.title),
          actions: <Widget>[
            if (!_loading && _items.isNotEmpty && !(_finished && _index < 0))
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Text('${(_index < 0 ? 0 : _index) + 1} / ${_items.length}',
                      style: TextStyle(color: p.pureWhite.withValues(alpha: 0.75), fontFamily: 'monospace')),
                ),
              ),
          ],
        ),
        body: SafeArea(child: body),
        bottomNavigationBar: item == null || _loading || _error != null || (_finished && _index < 0)
            ? null
            : SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  decoration: BoxDecoration(
                    color: p.eleganceMidnight,
                    border: Border(top: BorderSide(color: p.pureWhite.withValues(alpha: 0.06))),
                  ),
                  child: _footer(context, item),
                ),
              ),
      ),
    );
    if (widget.attempt == null) return scaffold;
    return QuizExecutionGuard(
      mode: widget.isSimulation ? QuizExecutionMode.simulation : QuizExecutionMode.practice,
      externalActivityPolicy: widget.externalActivityPolicy == 'structured_devices'
          ? ExternalActivityPolicy.structuredDevices
          : ExternalActivityPolicy.disabled,
      onForcedSubmit: (String reason) => _finish(reason: reason),
      child: scaffold,
    );
  }
}
