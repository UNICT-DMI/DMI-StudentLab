import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/quiz_model.dart';
import 'package:fe/theme/nightTheme.dart';
import 'package:fe/quiz/quizResultLayer.dart';
import 'package:fe/services/auth_session.dart';

import '../local_storage/services/study_plan_sync_service.dart';
import 'services/free_quiz_api_service.dart';
import 'services/quiz_attempt_api_service.dart';
import 'services/question_moderation_service.dart';
import 'teacher/widgets/quiz_execution_guard.dart';
import 'widgets/question_attachment_image.dart';
import 'package:fe/quiz/exercises/widgets/exercise_attachments.dart';

class QuizPage extends StatefulWidget {
  final String department;
  final String course;
  final String sub;
  final List<String> arguments;
  final int numberOfQuestions;
  final List<String> reviewQuestionIds;
  final int? attemptId;
  final List<Map<String, dynamic>>? assignedQuestions;
  final int? timeLimitSeconds;
  final DateTime? assignedStartedAt;
  final String executionMode;
  final String externalActivityPolicy;

  const QuizPage({
    super.key,
    required this.department,
    required this.course,
    required this.sub,
    required this.arguments,
    required this.numberOfQuestions,
    this.reviewQuestionIds = const <String>[],
  }) : attemptId = null,
       assignedQuestions = null,
       timeLimitSeconds = null,
       assignedStartedAt = null,
       executionMode = 'practice',
       externalActivityPolicy = 'disabled';

  const QuizPage.assigned({
    super.key,
    required this.attemptId,
    required this.department,
    required this.course,
    required this.sub,
    required this.assignedQuestions,
    this.timeLimitSeconds,
    this.assignedStartedAt,
    this.executionMode = 'practice',
    this.externalActivityPolicy = 'disabled',
  }) : arguments = const <String>[],
       numberOfQuestions = 0,
       reviewQuestionIds = const <String>[];

  bool get isAssigned => attemptId != null && assignedQuestions != null;

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final FreeQuizApiService _freeQuizApiService = FreeQuizApiService();
  final QuizAttemptApiService _attemptApiService = QuizAttemptApiService();
  final StudyPlanSyncService _studyPlanSync = StudyPlanSyncService();
  final QuestionModerationService _questionModerationService =
      QuestionModerationService();

  List<QuizModel> question = <QuizModel>[];
  List<QuizQuestionResult> results = <QuizQuestionResult>[];

  final List<Map<String, dynamic>> _assignedAnswers = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> _freeServerAnswers =
      <Map<String, dynamic>>[];

  int? _freeAttemptId;
  bool load = true;
  String? _loadError;
  bool isLocked = false;
  bool modalIsOpen = false;
  bool _completing = false;
  bool _reportingQuestion = false;
  int idx = 0;

  late DateTime _quizStartedAt;
  late DateTime _questionStartedAt;

  Timer? _timer;
  int? _remainingSeconds;

  int get _questionLength =>
      widget.isAssigned ? widget.assignedQuestions!.length : question.length;

  @override
  void initState() {
    super.initState();
    _quizStartedAt = widget.assignedStartedAt ?? DateTime.now();
    _questionStartedAt = DateTime.now();
    takeData();

    if (widget.isAssigned && widget.timeLimitSeconds != null) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    final int limit = widget.timeLimitSeconds!;
    final int alreadyElapsed = DateTime.now()
        .difference(_quizStartedAt)
        .inSeconds;

    _remainingSeconds = (limit - alreadyElapsed).clamp(0, limit);

    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final int current = _remainingSeconds ?? 0;

      if (current <= 1) {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
        });
        _completeAssignedQuiz(reason: 'time_expired');
        return;
      }

      setState(() {
        _remainingSeconds = current - 1;
      });
    });
  }

  Future<void> _refreshStudyPlanAfterQuiz() async {
    try {
      await _studyPlanSync.refreshAfterQuizCompletion();
    } catch (_) {}
  }

  void _showQuizResult() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (BuildContext context) => QuizResultLayer(results: results),
      ),
    );
  }

  Future<void> takeData() async {
    if (widget.isAssigned) {
      if (!mounted) return;
      setState(() {
        load = false;
      });
      return;
    }

    try {
      List<QuizModel> result;

      if (AuthSession.instance.isAuthenticated) {
        final Map<String, dynamic> attempt = await _attemptApiService
            .startFreeQuiz(
              department: widget.department,
              course: widget.course,
              subject: widget.sub,
              arguments: widget.arguments,
              numberOfQuestions: widget.numberOfQuestions,
              questionIds: widget.reviewQuestionIds,
            );

        final dynamic rawAttemptId = attempt['attempt_id'];
        _freeAttemptId = rawAttemptId is int
            ? rawAttemptId
            : int.tryParse(rawAttemptId?.toString() ?? '');

        final dynamic rawQuestions = attempt['questions'];

        if (_freeAttemptId == null || rawQuestions is! List) {
          throw StateError('Tentativo quiz non valido.');
        }

        result = rawQuestions
            .whereType<Map>()
            .map(
              (Map item) => QuizModel.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      } else {
        _freeAttemptId = null;

        result = await _freeQuizApiService.loadQuiz(
          department: widget.department,
          course: widget.course,
          subject: widget.sub,
          arguments: widget.arguments,
          numberOfQuestions: widget.numberOfQuestions,
          questionIds: widget.reviewQuestionIds,
        );
      }

      if (!mounted) return;

      setState(() {
        question = result;
        load = false;
        _questionStartedAt = DateTime.now();
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        load = false;
        _loadError = widget.reviewQuestionIds.isNotEmpty
            ? 'Le domande dello storico non sono più disponibili per questo percorso. Aggiorna il Ripasso o apri le Flashcard.'
            : 'Impossibile caricare le domande. Riprova.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Errore nel caricamento delle domande.')),
      );
    }
  }

  Future<void> answerValidate(String idChoice) async {
    if (isLocked || _completing) {
      return;
    }

    if (widget.isAssigned) {
      await _answerAssigned(idChoice);
      return;
    }

    await _answerFreeQuiz(idChoice);
  }

  Future<void> _answerFreeQuiz(String idChoice) async {
    setState(() {
      isLocked = true;
    });

    final QuizModel currentQuestion = question[idx];
    final String idQuestion = currentQuestion.idQuestion;
    final int responseSeconds = DateTime.now()
        .difference(_questionStartedAt)
        .inSeconds;

    try {
      final FreeQuizAnswerValidation validation = await _freeQuizApiService
          .validateAnswer(
            questionId: idQuestion,
            optionId: idChoice,
            department: widget.department,
            course: widget.course,
            subject: widget.sub,
          );

      if (!mounted) return;

      final Option selectedOption = currentQuestion.option.firstWhere(
        (Option option) => option.id == idChoice,
      );

      final String correctId = validation.correctOptionId.trim().isNotEmpty
          ? validation.correctOptionId.trim()
          : currentQuestion.idCorrect.trim();

      final Option correctOption = currentQuestion.option.firstWhere(
        (Option option) => option.id == correctId,
      );

      final int? serverAttemptId = _freeAttemptId;

      if (serverAttemptId != null) {
        _freeServerAnswers.removeWhere(
          (Map<String, dynamic> answer) =>
              answer['question_id']?.toString() == idQuestion,
        );

        _freeServerAnswers.add(<String, dynamic>{
          'question_id': idQuestion,
          'selected_option_id': idChoice,
          'response_time_seconds': responseSeconds,
        });
      }

      results.add(
        QuizQuestionResult(
          question: currentQuestion.text,
          givenAnswer: selectedOption.text,
          correctAnswer: correctOption.text,
          formalExplanation: validation.formalExplanation.trim().isNotEmpty
              ? validation.formalExplanation
              : currentQuestion.formalExplanation,
          informalExplanation: validation.informalExplanation.trim().isNotEmpty
              ? validation.informalExplanation
              : currentQuestion.informalExplanation,
          questionResponseExplanation:
              validation.selectedAnswerExplanation.trim().isNotEmpty ||
                  validation.correctAnswerExplanation.trim().isNotEmpty
              ? <String>[
                  if (validation.selectedAnswerExplanation.trim().isNotEmpty)
                    validation.selectedAnswerExplanation.trim(),
                  if (validation.correctAnswerExplanation.trim().isNotEmpty &&
                      validation.correctAnswerExplanation.trim() !=
                          validation.selectedAnswerExplanation.trim())
                    validation.correctAnswerExplanation.trim(),
                ].join('\n\n')
              : currentQuestion.questionResponseExplanation,
          answerExplanations: validation.answerExplanations,
          isCorrect: validation.isCorrect,
        ),
      );

      await _advanceOrFinishFree();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        isLocked = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile verificare la risposta.')),
      );
    }
  }

  Future<void> _advanceOrFinishFree() async {
    if (idx < question.length - 1) {
      setState(() {
        idx++;
        isLocked = false;
        _questionStartedAt = DateTime.now();
      });
      return;
    }

    final int? attemptId = _freeAttemptId;

    if (attemptId != null) {
      setState(() {
        _completing = true;
      });

      try {
        final Map<String, dynamic> completed = await _attemptApiService
            .completeAttempt(
              attemptId: attemptId,
              answers: _freeServerAnswers,
              elapsedSeconds: DateTime.now()
                  .difference(_quizStartedAt)
                  .inSeconds,
              completionReason: 'completed',
              interruptionCount: 0,
            );

        if (!mounted) return;

        final List<QuizQuestionResult> serverResults =
            _resultsFromCompletedAttempt(completed);

        if (serverResults.isNotEmpty) {
          results = serverResults;
        }
      } catch (_) {
        if (!mounted) return;

        setState(() {
          _completing = false;
          isLocked = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossibile salvare il tentativo. Riprova.'),
          ),
        );
        return;
      }
    }

    await _refreshStudyPlanAfterQuiz();

    if (!mounted) return;
    _showQuizResult();
  }

  Future<void> _answerAssigned(String idChoice) async {
    final Map<String, dynamic> current = widget.assignedQuestions![idx];
    final String questionId = current['id_question']?.toString().trim() ?? '';

    if (questionId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Domanda non valida.')));
      return;
    }

    setState(() {
      isLocked = true;
    });

    final int responseSeconds = DateTime.now()
        .difference(_questionStartedAt)
        .inSeconds;

    _assignedAnswers.removeWhere(
      (Map<String, dynamic> answer) =>
          answer['question_id']?.toString() == questionId,
    );

    _assignedAnswers.add(<String, dynamic>{
      'question_id': questionId,
      'selected_option_id': idChoice,
      'response_time_seconds': responseSeconds,
    });

    if (idx < widget.assignedQuestions!.length - 1) {
      setState(() {
        idx++;
        isLocked = false;
        _questionStartedAt = DateTime.now();
      });
      return;
    }

    await _completeAssignedQuiz(reason: 'completed');
  }

  Future<void> _completeAssignedQuiz({required String reason}) async {
    if (!widget.isAssigned || _completing) {
      return;
    }

    _timer?.cancel();

    setState(() {
      _completing = true;
      isLocked = true;
    });

    try {
      final int elapsed = DateTime.now().difference(_quizStartedAt).inSeconds;

      final Map<String, dynamic> completed = await _attemptApiService
          .completeAttempt(
            attemptId: widget.attemptId!,
            answers: _assignedAnswers,
            elapsedSeconds: elapsed,
            completionReason: reason,
            interruptionCount: 0,
          );

      if (!mounted) return;

      results = _resultsFromCompletedAttempt(completed);

      await _refreshStudyPlanAfterQuiz();

      if (!mounted) return;
      _showQuizResult();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _completing = false;
        isLocked = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile completare il quiz.')),
      );
    }
  }

  List<QuizQuestionResult> _resultsFromCompletedAttempt(
    Map<String, dynamic> attempt,
  ) {
    final dynamic rawAnswers = attempt['answers'];

    if (rawAnswers is! List) {
      return <QuizQuestionResult>[];
    }

    final List<QuizQuestionResult> result = <QuizQuestionResult>[];

    for (final dynamic raw in rawAnswers) {
      if (raw is! Map) continue;

      final Map<String, dynamic> answer = Map<String, dynamic>.from(raw);

      final String selectedExplanation =
          answer['selected_answer_explanation']?.toString().trim() ?? '';
      final String correctExplanation =
          answer['correct_answer_explanation']?.toString().trim() ?? '';

      final List<String> responseParts = <String>[];

      if (selectedExplanation.isNotEmpty) {
        responseParts.add(selectedExplanation);
      }

      if (correctExplanation.isNotEmpty &&
          correctExplanation != selectedExplanation) {
        responseParts.add(correctExplanation);
      }

      final Map<String, String> answerExplanations = <String, String>{};

      if (selectedExplanation.isNotEmpty) {
        answerExplanations['Risposta scelta'] = selectedExplanation;
      }

      if (correctExplanation.isNotEmpty) {
        answerExplanations['Risposta corretta'] = correctExplanation;
      }

      result.add(
        QuizQuestionResult(
          question: answer['question_text']?.toString() ?? '',
          givenAnswer:
              answer['selected_option_text']?.toString() ?? 'Nessuna risposta',
          correctAnswer: answer['correct_option_text']?.toString() ?? '',
          formalExplanation: answer['formal_explanation']?.toString() ?? '',
          informalExplanation: answer['informal_explanation']?.toString() ?? '',
          questionResponseExplanation: responseParts.join('\n\n'),
          answerExplanations: answerExplanations,
          isCorrect: answer['is_correct'] == true,
        ),
      );
    }

    return result;
  }

  List<_QuizOptionView> _currentOptions() {
    if (!widget.isAssigned) {
      return question[idx].option
          .map(
            (Option option) =>
                _QuizOptionView(id: option.id, text: option.text),
          )
          .toList();
    }

    final dynamic raw = widget.assignedQuestions![idx]['option'];

    if (raw is! List) {
      return <_QuizOptionView>[];
    }

    return raw
        .whereType<Map>()
        .map(
          (Map option) => _QuizOptionView(
            id: option['id']?.toString() ?? '',
            text: option['text']?.toString() ?? '',
          ),
        )
        .where((_QuizOptionView option) => option.id.isNotEmpty)
        .toList();
  }

  String get _currentText {
    if (!widget.isAssigned) {
      return question[idx].text;
    }

    return widget.assignedQuestions![idx]['text']?.toString() ?? '';
  }

  List<Map<String, dynamic>> get _currentAttachments {
    if (!widget.isAssigned) {
      return question[idx].attachments;
    }

    final dynamic raw = widget.assignedQuestions![idx]['attachments'];

    if (raw is! List) {
      return <Map<String, dynamic>>[];
    }

    return raw
        .whereType<Map>()
        .map((Map item) => Map<String, dynamic>.from(item))
        .toList();
  }

  String get _currentQuestionId {
    if (!widget.isAssigned) {
      return question[idx].idQuestion;
    }

    return widget.assignedQuestions![idx]['id_question']?.toString().trim() ??
        '';
  }

  Map<String, dynamic> get _currentMetadata {
    if (!widget.isAssigned) {
      return Map<String, dynamic>.from(question[idx].metadata);
    }

    final dynamic raw = widget.assignedQuestions![idx]['metadata'];

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    return <String, dynamic>{};
  }

  Future<void> _showExplanation(
    BuildContext context,
    QuizModel currentQuestion,
  ) async {
    if (modalIsOpen) return;

    setState(() {
      modalIsOpen = true;
    });

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.secondaryNightBlue,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext modalContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                top: 10,
                left: 20,
                right: 20,
                bottom: 20 + MediaQuery.of(modalContext).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const SizedBox(height: 24),
                      Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.skyBlue,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Spiegazione',
                          style: TextStyle(
                            color: AppColors.pureWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(modalContext);
                        },
                        icon: Icon(
                          Icons.close_rounded,
                          color: AppColors.pureWhite,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Definizione formale',
                    style: TextStyle(
                      color: AppColors.skyBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    currentQuestion.formalExplanation.isNotEmpty
                        ? currentQuestion.formalExplanation
                        : 'Nessuna definizione formale disponibile.',
                    style: TextStyle(
                      color: AppColors.pureWhite.withOpacity(0.85),
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Spiegazione informale',
                    style: TextStyle(
                      color: AppColors.skyBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    currentQuestion.informalExplanation.isNotEmpty
                        ? currentQuestion.informalExplanation
                        : 'Nessuna spiegazione informale disponibile.',
                    style: TextStyle(
                      color: AppColors.pureWhite.withOpacity(0.70),
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(modalContext);
                      },
                      child: const Text('Ho capito'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted) return;

    setState(() {
      modalIsOpen = false;
    });
  }

  Future<void> _reportCurrentQuestion() async {
    if (widget.isAssigned || _reportingQuestion) return;
    if (!AuthSession.instance.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accedi a StudentLab per segnalare una domanda.'),
        ),
      );
      return;
    }
    const List<MapEntry<String, String>> reasons = <MapEntry<String, String>>[
      MapEntry<String, String>(
        'wrong_correct_answer',
        'Risposta corretta errata',
      ),
      MapEntry<String, String>('unclear_question', 'Domanda poco chiara'),
      MapEntry<String, String>('wrong_explanation', 'Spiegazione errata'),
      MapEntry<String, String>('wrong_feedback', 'Feedback errato'),
      MapEntry<String, String>('duplicate_question', 'Domanda duplicata'),
      MapEntry<String, String>('text_error', 'Errore nel testo'),
      MapEntry<String, String>('not_relevant', 'Contenuto non pertinente'),
      MapEntry<String, String>('other', 'Altro'),
    ];
    String selected = reasons.first.key;
    final TextEditingController messageController = TextEditingController();
    final Map<String, String>? result =
        await showModalBottomSheet<Map<String, String>>(
          context: context,
          backgroundColor: AppColors.secondaryNightBlue,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (BuildContext modalContext) {
            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                return SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      14,
                      20,
                      20 + MediaQuery.of(modalContext).viewInsets.bottom,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.flag_outlined,
                                color: AppColors.redAccent,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Segnala domanda',
                                  style: TextStyle(
                                    color: AppColors.pureWhite,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(modalContext),
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: AppColors.pureWhite,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          for (final MapEntry<String, String> reason in reasons)
                            RadioListTile<String>(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              value: reason.key,
                              groupValue: selected,
                              activeColor: AppColors.skyBlue,
                              title: Text(
                                reason.value,
                                style: TextStyle(
                                  color: AppColors.pureWhite,
                                  fontSize: 13,
                                ),
                              ),
                              onChanged: (String? value) {
                                if (value != null)
                                  setModalState(() => selected = value);
                              },
                            ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: messageController,
                            minLines: 3,
                            maxLines: 6,
                            maxLength: 2000,
                            style: TextStyle(color: AppColors.pureWhite),
                            decoration: InputDecoration(
                              labelText: 'Dettagli facoltativi',
                              labelStyle: TextStyle(
                                color: AppColors.white70,
                              ),
                              filled: true,
                              fillColor: AppColors.brandNightBlue.withValues(
                                alpha: 0.45,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  Navigator.pop(modalContext, <String, String>{
                                    'reason': selected,
                                    'message': messageController.text.trim(),
                                  }),
                              icon: const Icon(Icons.flag_outlined),
                              label: const Text('Invia segnalazione'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
    messageController.dispose();
    if (result == null || !mounted) return;
    setState(() => _reportingQuestion = true);
    try {
      await _questionModerationService.reportQuestion(
        department: widget.department,
        course: widget.course,
        subject: widget.sub,
        questionId: _currentQuestionId,
        reason: result['reason'] ?? 'other',
        message: result['message'],
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Segnalazione inviata. Grazie.')),
      );
    } catch (error) {
      if (!mounted) return;
      String message = error.toString();
      if (message.startsWith('Exception: ')) message = message.substring(11);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.trim().isEmpty
                ? 'Non è stato possibile inviare la segnalazione.'
                : message.trim(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _reportingQuestion = false);
    }
  }

  String _formatRemaining(int seconds) {
    final int minutes = seconds ~/ 60;
    final int remaining = seconds % 60;
    return '$minutes:${remaining.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (load) {
      return Scaffold(
        backgroundColor: AppColors.darkElegance,
        appBar: AppBar(
          backgroundColor: AppColors.secondaryNightBlue,
          foregroundColor: AppColors.white,
          title: const Text('Che ansia..', style: TextStyle(fontSize: 16)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_questionLength == 0) {
      return Scaffold(
        backgroundColor: AppColors.darkElegance,
        appBar: AppBar(
          backgroundColor: AppColors.secondaryNightBlue,
          foregroundColor: AppColors.white,
          title: const Text('Quiz'),
        ),
        body: Center(
          child: Text(
            _loadError ?? 'Non sono state trovate domande.',
            style: TextStyle(color: AppColors.white, fontSize: 16),
          ),
        ),
      );
    }

    final List<_QuizOptionView> options = _currentOptions();
    final Map<String, dynamic> metadata = _currentMetadata;

    final Widget quizScaffold = Scaffold(
      backgroundColor: AppColors.darkElegance,
      appBar: AppBar(
        backgroundColor: AppColors.secondaryNightBlue,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          '${metadata['sub'] ?? widget.sub} - ${metadata['argoment'] ?? ''}',
          style: const TextStyle(fontSize: 16),
        ),
        actions: <Widget>[
          if (widget.isAssigned && _remainingSeconds != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  _formatRemaining(_remainingSeconds!),
                  style: TextStyle(
                    color: _remainingSeconds! <= 60
                        ? AppColors.redAccent
                        : AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (!widget.isAssigned)
            IconButton(
              icon: const Icon(Icons.book),
              tooltip: 'Spiegazione',
              onPressed: () {
                _showExplanation(context, question[idx]);
              },
            ),
          if (!widget.isAssigned)
            IconButton(
              icon: _reportingQuestion
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.flag_outlined),
              tooltip: 'Segnala domanda',
              onPressed: _reportingQuestion ? null : _reportCurrentQuestion,
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool isLargeScreen = constraints.maxWidth > 700;
              final double contentWidth = isLargeScreen
                  ? 600.0
                  : constraints.maxWidth;

              return SizedBox(
                width: contentWidth,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: <Widget>[
                    LinearProgressIndicator(
                      value: (idx + 1) / _questionLength,
                      backgroundColor: AppColors.white.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.skyBlue),
                    ),
                    const SizedBox(height: 25),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            _currentText,
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryNightBlue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${idx + 1}/$_questionLength',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_currentAttachments.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 18),
                      for (final Map<String, dynamic> attachment
                          in _currentAttachments)
                        if (attachment['type']
                                    ?.toString()
                                    .trim()
                                    .toLowerCase() ==
                                'image' &&
                            _currentQuestionId.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: QuestionAttachmentImage(
                              department: widget.department,
                              course: widget.course,
                              subject: widget.sub,
                              questionId: _currentQuestionId,
                              attachment: attachment,
                            ),
                          ),
                      // v18: PDF, TXT, DOCX e PPTX si aprono con un tocco.
                      if (_currentQuestionId.isNotEmpty)
                        ExerciseAttachments.question(
                          attachments: _currentAttachments
                              .where((Map<String, dynamic> a) =>
                                  a['type']?.toString().trim().toLowerCase() != 'image')
                              .toList(),
                          department: widget.department,
                          course: widget.course,
                          subject: widget.sub,
                          questionId: _currentQuestionId,
                        ),
                    ],
                    const SizedBox(height: 35),
                    ...options.map(
                      (_QuizOptionView option) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondaryNightBlue,
                            foregroundColor: AppColors.white,
                            disabledBackgroundColor: AppColors.secondaryNightBlue,
                            disabledForegroundColor: AppColors.white.withOpacity(
                              0.50,
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 18,
                              horizontal: 16,
                            ),
                            alignment: Alignment.centerLeft,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 3,
                          ),
                          onPressed: isLocked || _completing
                              ? null
                              : () => answerValidate(option.id),
                          child: Text(
                            option.text,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_completing) ...<Widget>[
                      const SizedBox(height: 16),
                      const Center(child: CircularProgressIndicator()),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    if (!widget.isAssigned) {
      return quizScaffold;
    }

    return QuizExecutionGuard(
      mode: widget.executionMode == 'simulation'
          ? QuizExecutionMode.simulation
          : QuizExecutionMode.practice,
      externalActivityPolicy:
          widget.externalActivityPolicy == 'structured_devices'
          ? ExternalActivityPolicy.structuredDevices
          : ExternalActivityPolicy.disabled,
      onForcedSubmit: (String reason) async {
        await _completeAssignedQuiz(reason: reason);
      },
      child: quizScaffold,
    );
  }
}

class _QuizOptionView {
  final String id;
  final String text;

  const _QuizOptionView({required this.id, required this.text});
}
