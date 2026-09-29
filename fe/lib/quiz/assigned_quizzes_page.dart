import 'package:flutter/material.dart';

import '../../theme/nightTheme.dart';
import 'quiz.dart';
import 'services/assigned_quiz_service.dart';
import 'package:fe/quiz/exercises/exercise_session_page.dart';

class AssignedQuizzesPage extends StatefulWidget {
  const AssignedQuizzesPage({super.key});

  @override
  State<AssignedQuizzesPage> createState() => _AssignedQuizzesPageState();
}

class _AssignedQuizzesPageState extends State<AssignedQuizzesPage> {
  final AssignedQuizService _service = AssignedQuizService();

  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  bool _loading = true;
  int? _startingAssignmentId;
  String? _error;

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
      final List<Map<String, dynamic>> items = await _service
          .getAssignedQuizzes();

      if (!mounted) return;

      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor: AppColors.brandNightBlue,
        foregroundColor: AppColors.pureWhite,
        title: const Text('Quiz assegnati'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Aggiorna',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _state(
        icon: Icons.error_outline_rounded,
        title: 'Impossibile caricare i quiz',
        message: _error!,
        showRetry: true,
      );
    }

    if (_items.isEmpty) {
      return _state(
        icon: Icons.assignment_outlined,
        title: 'Nessun quiz assegnato',
        message: 'Quando un docente ti assegnerà un quiz, comparirà qui.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, int index) {
          final Map<String, dynamic> item = _items[index];
          final int? id = _toInt(item['id']);

          return _AssignedQuizCard(
            data: item,
            busy: id != null && _startingAssignmentId == id,
            onPressed: id == null ? null : () => _handleQuiz(item, id),
          );
        },
      ),
    );
  }

  Widget _state({
    required IconData icon,
    required String title,
    required String message,
    bool showRetry = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              color: showRetry ? AppColors.redAccent : AppColors.skyBlue,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.pureWhite,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.white54),
            ),
            if (showRetry) ...<Widget>[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Riprova'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleQuiz(Map<String, dynamic> item, int assignmentId) async {
    final bool isExpired = item['is_expired'] == true;
    final bool isCompleted = item['is_completed'] == true;
    final bool isInProgress = item['is_in_progress'] == true;
    final bool canStart = item['can_start'] == true;
    final int? attemptId = _toInt(item['attempt_id']);

    if (isExpired && !isCompleted) {
      _showMessage('Questo quiz è scaduto.');
      return;
    }

    if (isCompleted && attemptId != null) {
      final Map<String, dynamic>? attempt = await _safeGetAttempt(attemptId);

      if (!mounted || attempt == null) return;

      await _showAttemptSummary(attempt, completed: true);
      return;
    }

    if (isInProgress && attemptId != null) {
      setState(() {
        _startingAssignmentId = assignmentId;
      });

      try {
        final Map<String, dynamic> attempt = await _service.resumeAttempt(
          attemptId,
        );

        if (!mounted) return;

        await _openAssignedAttempt(attempt);

        if (!mounted) return;
        await _load();
      } catch (error) {
        if (!mounted) return;
        _showMessage(_friendlyError(error));
      } finally {
        if (mounted) {
          setState(() {
            _startingAssignmentId = null;
          });
        }
      }
      return;
    }

    if (!canStart) {
      _showMessage('Questo quiz non può essere avviato.');
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Avviare il quiz?'),
        content: Text(_startWarning(item)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Avvia'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _startingAssignmentId = assignmentId;
    });

    try {
      final Map<String, dynamic> attempt = await _service.startAssignedQuiz(
        assignmentId,
      );

      if (!mounted) return;

      await _openAssignedAttempt(attempt);

      if (!mounted) return;
      await _load();
    } catch (error) {
      if (!mounted) return;
      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() {
          _startingAssignmentId = null;
        });
      }
    }
  }

  Future<void> _openAssignedAttempt(Map<String, dynamic> attempt) async {
    final int? attemptId = _toInt(attempt['attempt_id']);

    final String department = attempt['department']?.toString().trim() ?? '';
    final String course = attempt['course']?.toString().trim() ?? '';
    final String subject = attempt['subject']?.toString().trim() ?? '';
    final dynamic rawQuestions = attempt['questions'];

    if (attemptId == null ||
        department.isEmpty ||
        course.isEmpty ||
        subject.isEmpty ||
        rawQuestions is! List) {
      _showMessage('Il quiz ricevuto dal server non è valido.');
      return;
    }

    final List<Map<String, dynamic>> questions = rawQuestions
        .whereType<Map>()
        .map((Map item) => Map<String, dynamic>.from(item))
        .toList();

    if (questions.isEmpty) {
      _showMessage('Il quiz non contiene domande.');
      return;
    }

    // v18: con esercizi dei nuovi tipi si apre la sessione esercizi (anche per le domande miste).
    if (questions.any((Map<String, dynamic> q) =>
        (q['type']?.toString() ?? 'multiple_choice') != 'multiple_choice')) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ExerciseSessionPage.attempt(attempt: attempt),
        ),
      );
      return;
    }

    final int? timeLimitSeconds = _toInt(attempt['time_limit_seconds']);

    final DateTime? startedAt = DateTime.tryParse(
      attempt['started_at']?.toString() ?? '',
    );

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuizPage.assigned(
          attemptId: attemptId,
          department: department,
          course: course,
          sub: subject,
          assignedQuestions: questions,
          timeLimitSeconds: timeLimitSeconds,
          assignedStartedAt: startedAt?.toLocal(),
          executionMode: attempt['execution_mode']?.toString() ?? 'practice',
          externalActivityPolicy:
              attempt['external_activity_policy']?.toString() ?? 'disabled',
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _safeGetAttempt(int attemptId) async {
    try {
      return await _service.getAttempt(attemptId);
    } catch (error) {
      if (mounted) {
        _showMessage(_friendlyError(error));
      }
      return null;
    }
  }

  Future<void> _showAttemptSummary(
    Map<String, dynamic> attempt, {
    required bool completed,
  }) {
    final int questionCount = _toInt(attempt['question_count']) ?? 0;
    final int? timeLimit = _toInt(attempt['time_limit_seconds']);
    final double? percentage = _toDouble(attempt['percentage']);

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(completed ? 'Quiz completato' : 'Tentativo pronto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('${attempt['subject'] ?? 'Materia'}'),
            const SizedBox(height: 8),
            Text('$questionCount domande'),
            if (timeLimit != null)
              Text('${(timeLimit / 60).ceil()} minuti disponibili'),
            if (completed && percentage != null)
              Text('Risultato: ${percentage.toStringAsFixed(1)}%'),
          ],
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  String _startWarning(Map<String, dynamic> item) {
    final int count = _toInt(item['question_count']) ?? 0;
    final int? seconds = _toInt(item['time_limit_seconds']);
    final DateTime? dueAt = DateTime.tryParse(
      item['due_at']?.toString() ?? '',
    )?.toLocal();

    final List<String> parts = <String>['Il quiz contiene $count domande.'];

    if (seconds != null) {
      parts.add('Tempo limite: ${(seconds / 60).ceil()} minuti.');
    }

    if (dueAt != null) {
      parts.add('Scadenza: ${_formatDate(dueAt)}.');
    }

    parts.add(
      'Dopo l’avvio verrà creato il tuo unico tentativo per questa assegnazione.',
    );

    return parts.join('\n\n');
  }

  String _friendlyError(Object error) {
    final String raw = error.toString().trim();
    final String normalized = raw.toLowerCase();

    if (normalized.contains('401') ||
        normalized.contains('non autenticato') ||
        normalized.contains('sessione non è più valida')) {
      return 'La sessione non è più valida. Accedi nuovamente a StudentLab.';
    }

    if (normalized.contains('socket') ||
        normalized.contains('network') ||
        normalized.contains('connection') ||
        normalized.contains('timeout') ||
        normalized.contains('host lookup')) {
      return 'Non è stato possibile contattare StudentLab. Controlla la connessione e riprova.';
    }

    if (normalized.contains('500') ||
        normalized.contains('internal server') ||
        normalized.contains('errore tecnico')) {
      return 'StudentLab non riesce a caricare i quiz assegnati in questo momento. Riprova.';
    }

    String message = raw;

    if (message.startsWith('Exception: ')) {
      message = message.substring('Exception: '.length);
    }

    if (message.startsWith('Bad state: ')) {
      message = message.substring('Bad state: '.length);
    }

    return message.isEmpty
        ? 'Non è stato possibile completare l’operazione.'
        : message;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '');
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();

    return double.tryParse(value?.toString() ?? '');
  }

  String _formatDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');

    return '${two(value.day)}/${two(value.month)}/${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

class _AssignedQuizCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool busy;
  final VoidCallback? onPressed;

  const _AssignedQuizCard({
    required this.data,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final (String, _StatusTone) status = _status(data);
    final DateTime? dueAt = DateTime.tryParse(
      data['due_at']?.toString() ?? '',
    )?.toLocal();
    final int questionCount = _toInt(data['question_count']) ?? 0;
    final int? seconds = _toInt(data['time_limit_seconds']);
    final String description = data['description']?.toString().trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.eleganceDeepNavy,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  data['title']?.toString() ?? 'Quiz',
                  style: TextStyle(
                    color: AppColors.pureWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _StatusBadge(label: status.$1, tone: status.$2),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            data['subject']?.toString() ?? '',
            style: TextStyle(
              color: AppColors.skyBlue,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (description.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: AppColors.white54,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _InfoChip(
                icon: Icons.quiz_outlined,
                label: '$questionCount domande',
              ),
              if (seconds != null)
                _InfoChip(
                  icon: Icons.timer_outlined,
                  label: '${(seconds / 60).ceil()} min',
                ),
              if (dueAt != null)
                _InfoChip(
                  icon: Icons.event_outlined,
                  label: _formatDate(dueAt),
                ),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              onPressed: busy ? null : onPressed,
              icon: busy
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_buttonIcon(data)),
              label: Text(_buttonLabel(data)),
            ),
          ),
        ],
      ),
    );
  }

  static (String, _StatusTone) _status(Map<String, dynamic> data) {
    if (data['is_completed'] == true) {
      return ('Completato', _StatusTone.completed);
    }

    if (data['is_expired'] == true) {
      return ('Scaduto', _StatusTone.expired);
    }

    if (data['is_in_progress'] == true) {
      return ('In corso', _StatusTone.progress);
    }

    return ('Da svolgere', _StatusTone.pending);
  }

  static String _buttonLabel(Map<String, dynamic> data) {
    if (data['is_completed'] == true) return 'Vedi risultato';
    if (data['is_expired'] == true) return 'Quiz scaduto';
    if (data['is_in_progress'] == true) return 'Riprendi quiz';

    return 'Avvia quiz';
  }

  static IconData _buttonIcon(Map<String, dynamic> data) {
    if (data['is_completed'] == true) {
      return Icons.insights_outlined;
    }

    if (data['is_expired'] == true) {
      return Icons.lock_clock_outlined;
    }

    if (data['is_in_progress'] == true) {
      return Icons.play_circle_outline_rounded;
    }

    return Icons.play_arrow_rounded;
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '');
  }

  static String _formatDate(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');

    return '${two(value.day)}/${two(value.month)} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

enum _StatusTone { pending, progress, completed, expired }

class _StatusBadge extends StatelessWidget {
  final String label;
  final _StatusTone tone;

  const _StatusBadge({required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    final Color color = switch (tone) {
      _StatusTone.pending => AppColors.skyBlue,
      _StatusTone.progress => AppColors.amberAccent,
      _StatusTone.completed => AppColors.greenAccent,
      _StatusTone.expired => AppColors.redAccent,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.brandNightBlue.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: AppColors.skyBlue, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: AppColors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
