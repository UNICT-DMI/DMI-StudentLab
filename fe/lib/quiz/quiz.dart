import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/quiz_model.dart';
import 'package:fe/theme/nightTheme.dart';
import 'package:fe/quiz/quizResultLayer.dart';
import 'services/free_quiz_api_service.dart';
import 'services/quiz_attempt_api_service.dart';
import 'teacher/widgets/quiz_execution_guard.dart';
class QuizPage extends StatefulWidget {
  final String department;
  final String course;
  final String sub;
  final List<String> arguments;
  final int numberOfQuestions;
  final int? attemptId;
  final List<Map<String, dynamic>>?
      assignedQuestions;
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
  })  : attemptId = null,
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
  })  : arguments = const [],
        numberOfQuestions = 0;
  bool get isAssigned =>
      attemptId != null &&
      assignedQuestions != null;
  @override
  State<QuizPage> createState() =>
      _QuizPageState();
}
class _QuizPageState
    extends State<QuizPage> {
final FreeQuizApiService
      _freeQuizApiService =
      FreeQuizApiService();
  final QuizAttemptApiService
      _attemptApiService =
      QuizAttemptApiService();
  List<QuizModel> question = [];
  List<QuizQuestionResult> results = [];
  final List<Map<String, dynamic>>
      _assignedAnswers = [];
  bool load = true;
  bool isLocked = false;
  bool modalIsOpen = false;
  bool _completing = false;
  int idx = 0;
  late DateTime _quizStartedAt;
  late DateTime _questionStartedAt;
  Timer? _timer;
  int? _remainingSeconds;
  int get _questionLength =>
      widget.isAssigned
          ? widget.assignedQuestions!.length
          : question.length;
  @override
  void initState() {
super.initState();
    _quizStartedAt =
        widget.assignedStartedAt ??
        DateTime.now();
    _questionStartedAt =
        DateTime.now();
    takeData();
    if (widget.isAssigned &&
        widget.timeLimitSeconds != null) {
      _startTimer();
    }
  }
  @override
  void dispose() {
    _timer?.cancel();
super.dispose();
  }
  void _startTimer() {
    final int limit =
        widget.timeLimitSeconds!;
    final int alreadyElapsed =
        DateTime.now()
            .difference(
              _quizStartedAt,
            )
            .inSeconds;
    _remainingSeconds =
        (limit - alreadyElapsed)
            .clamp(
              0,
              limit,
            );
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        final current =
            _remainingSeconds ?? 0;
        if (current <= 1) {
          timer.cancel();
          setState(() {
            _remainingSeconds = 0;
          });
          _completeAssignedQuiz(
            reason: 'time_expired',
          );
          return;
        }
        setState(() {
          _remainingSeconds =
              current - 1;
        });
      },
    );
  }
  void _showQuizResult() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            QuizResultLayer(
          results: results,
        ),
      ),
    );
  }
  void takeData() async {
    if (widget.isAssigned) {
      if (!mounted) return;
      setState(() {
        load = false;
      });
      return;
    }
    try {
      final result =
          await _freeQuizApiService.loadQuiz(
        department: widget.department,
        course: widget.course,
        subject: widget.sub,
        arguments: widget.arguments,
        numberOfQuestions:
            widget.numberOfQuestions,
      );
      if (!mounted) return;
      setState(() {
        question = result;
        load = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        load = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Errore nel caricamento delle domande.',
          ),
        ),
      );
    }
  }
  Future<void> answerValidate(
    String idChoice,
  ) async {
    if (isLocked || _completing) {
      return;
    }
    if (widget.isAssigned) {
      await _answerAssigned(
        idChoice,
      );
      return;
    }
    await _answerFreeQuiz(
      idChoice,
    );
  }
  Future<void> _answerFreeQuiz(
    String idChoice,
  ) async {
    setState(() {
      isLocked = true;
    });
    final currentQuestion =
        question[idx];
    final idQuestion =
        currentQuestion.idQuestion;
    try {
      final FreeQuizAnswerValidation
          validation =
          await _freeQuizApiService
              .validateAnswer(
        questionId: idQuestion,
        optionId: idChoice,
        department: widget.department,
        course: widget.course,
        subject: widget.sub,
      );
      final bool isCorrect =
          validation.isCorrect;
      if (!mounted) return;
      final selectedOption =
          currentQuestion.option.firstWhere(
        (option) =>
            option.id == idChoice,
      );
      final correctOption =
          currentQuestion.option.firstWhere(
        (option) =>
            option.id ==
            currentQuestion.idCorrect,
      );
      results.add(
        QuizQuestionResult(
          question:
              currentQuestion.text,
          givenAnswer:
              selectedOption.text,
          correctAnswer:
              correctOption.text,
          formalExplanation:
              currentQuestion
                  .formalExplanation,
          informalExplanation:
              currentQuestion
                  .informalExplanation,
          questionResponseExplanation:
              currentQuestion
                  .questionResponseExplanation,
          answerExplanations: const {},
          isCorrect: isCorrect,
        ),
      );
      _advanceOrFinishFree();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLocked = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Impossibile verificare la risposta.',
          ),
        ),
      );
    }
  }
  void _advanceOrFinishFree() {
    if (idx < question.length - 1) {
      setState(() {
        idx++;
        isLocked = false;
      });
    } else {
      _showQuizResult();
    }
  }
  Future<void> _answerAssigned(
    String idChoice,
  ) async {
    final current =
        widget.assignedQuestions![idx];
    final String questionId =
        current['id_question']
                ?.toString()
                .trim() ??
            '';
    if (questionId.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Domanda non valida.',
          ),
        ),
      );
      return;
    }
    setState(() {
      isLocked = true;
    });
    final int responseSeconds =
        DateTime.now()
            .difference(
              _questionStartedAt,
            )
            .inSeconds;
    _assignedAnswers.removeWhere(
      (answer) =>
          answer['question_id']
              ?.toString() ==
          questionId,
    );
    _assignedAnswers.add({
      'question_id': questionId,
      'selected_option_id':
          idChoice,
      'response_time_seconds':
          responseSeconds,
    });
    if (idx <
        widget.assignedQuestions!.length -
            1) {
      setState(() {
        idx++;
        isLocked = false;
        _questionStartedAt =
            DateTime.now();
      });
      return;
    }
    await _completeAssignedQuiz(
      reason: 'completed',
    );
  }
  Future<void> _completeAssignedQuiz({
    required String reason,
  }) async {
    if (!widget.isAssigned ||
        _completing) {
      return;
    }
    _timer?.cancel();
    setState(() {
      _completing = true;
      isLocked = true;
    });
    try {
      final int elapsed =
          DateTime.now()
              .difference(
                _quizStartedAt,
              )
              .inSeconds;
      final completed =
          await _attemptApiService
              .completeAttempt(
        attemptId: widget.attemptId!,
        answers: _assignedAnswers,
        elapsedSeconds: elapsed,
        completionReason: reason,
        interruptionCount: 0,
      );
      if (!mounted) return;
      results = _resultsFromCompletedAttempt(
        completed,
      );
      _showQuizResult();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _completing = false;
        isLocked = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Impossibile completare il quiz.',
          ),
        ),
      );
    }
  }
  List<QuizQuestionResult>
      _resultsFromCompletedAttempt(
    Map<String, dynamic> attempt,
  ) {
    final dynamic rawAnswers =
        attempt['answers'];
    if (rawAnswers is! List) {
      return [];
    }
    final result =
        <QuizQuestionResult>[];
    for (final raw in rawAnswers) {
      if (raw is! Map) continue;
      final answer =
          Map<String, dynamic>.from(
        raw,
      );
      final String selectedExplanation =
          answer[
                  'selected_answer_explanation']
              ?.toString()
              .trim() ??
          '';
      final String correctExplanation =
          answer[
                  'correct_answer_explanation']
              ?.toString()
              .trim() ??
          '';
      final List<String> responseParts =
          [];
      if (selectedExplanation
          .isNotEmpty) {
        responseParts.add(
          selectedExplanation,
        );
      }
      if (correctExplanation.isNotEmpty &&
          correctExplanation !=
              selectedExplanation) {
        responseParts.add(
          correctExplanation,
        );
      }
      final Map<String, String>
          answerExplanations = {};
      if (selectedExplanation
          .isNotEmpty) {
        answerExplanations[
                'Risposta scelta'] =
            selectedExplanation;
      }
      if (correctExplanation
          .isNotEmpty) {
        answerExplanations[
                'Risposta corretta'] =
            correctExplanation;
      }
      result.add(
        QuizQuestionResult(
          question:
              answer['question_text']
                      ?.toString() ??
                  '',
          givenAnswer:
              answer['selected_option_text']
                      ?.toString() ??
                  'Nessuna risposta',
          correctAnswer:
              answer['correct_option_text']
                      ?.toString() ??
                  '',
          formalExplanation:
              answer['formal_explanation']
                      ?.toString() ??
                  '',
          informalExplanation:
              answer['informal_explanation']
                      ?.toString() ??
                  '',
          questionResponseExplanation:
              responseParts.join(
            '\n\n',
          ),
          answerExplanations:
              answerExplanations,
          isCorrect:
              answer['is_correct'] ==
                  true,
        ),
      );
    }
    return result;
  }
  List<_QuizOptionView>
      _currentOptions() {
    if (!widget.isAssigned) {
      return question[idx]
          .option
          .map(
            (option) =>
                _QuizOptionView(
              id: option.id,
              text: option.text,
            ),
          )
          .toList();
    }
    final dynamic raw =
        widget.assignedQuestions![idx]
            ['option'];
    if (raw is! List) {
      return [];
    }
    return raw
        .whereType<Map>()
        .map(
          (option) =>
              _QuizOptionView(
            id: option['id']
                    ?.toString() ??
                '',
            text: option['text']
                    ?.toString() ??
                '',
          ),
        )
        .where(
          (option) =>
              option.id.isNotEmpty,
        )
        .toList();
  }
  String get _currentText {
    if (!widget.isAssigned) {
      return question[idx].text;
    }
    return widget.assignedQuestions![idx]
                ['text']
            ?.toString() ??
        '';
  }
  Map<String, dynamic>
      get _currentMetadata {
    if (!widget.isAssigned) {
      return Map<String, dynamic>.from(
        question[idx].metadata,
      );
    }
    final raw =
        widget.assignedQuestions![idx]
            ['metadata'];
    if (raw is Map) {
      return Map<String, dynamic>.from(
        raw,
      );
    }
    return {};
  }
  Future<void> _showExplanation(
    BuildContext context,
    QuizModel currentQuestion,
  ) async {
    if (modalIsOpen) return;
    setState(() {
      modalIsOpen = true;
    });
    await showModalBottomSheet(
      context: context,
      backgroundColor:
          AppColors.secondaryNightBlue,
      isScrollControlled: true,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (modalContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.only(
                top: 10,
                left: 20,
                right: 20,
                bottom: 20 +
                    MediaQuery.of(
                      modalContext,
                    ).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Row(
                    children: [
                      const SizedBox(
                        height: 24,
                      ),
                      const Icon(
                        Icons.menu_book_rounded,
                        color:
                            AppColors.skyBlue,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      const Expanded(
                        child: Text(
                          'Spiegazione',
                          style: TextStyle(
                            color: AppColors
                                .pureWhite,
                            fontSize: 18,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(
                            modalContext,
                          );
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors
                              .pureWhite,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 18,
                  ),
                  const Text(
                    'Definizione formale',
                    style: TextStyle(
                      color:
                          AppColors.skyBlue,
                      fontSize: 13,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 6,
                  ),
                  Text(
                    currentQuestion
                            .formalExplanation
                            .isNotEmpty
                        ? currentQuestion
                            .formalExplanation
                        : 'Nessuna definizione formale disponibile.',
                    style: TextStyle(
                      color: AppColors
                          .pureWhite
                          .withOpacity(
                            0.85,
                          ),
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  const Text(
                    'Spiegazione informale',
                    style: TextStyle(
                      color:
                          AppColors.skyBlue,
                      fontSize: 13,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  const SizedBox(
                    height: 6,
                  ),
                  Text(
                    currentQuestion
                            .informalExplanation
                            .isNotEmpty
                        ? currentQuestion
                            .informalExplanation
                        : 'Nessuna spiegazione informale disponibile.',
                    style: TextStyle(
                      color: AppColors
                          .pureWhite
                          .withOpacity(
                            0.70,
                          ),
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  SizedBox(
                    width:
                        double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(
                          modalContext,
                        );
                      },
                      child: const Text(
                        'Ho capito',
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
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
  String _formatRemaining(
    int seconds,
  ) {
    final int minutes =
        seconds ~/ 60;
    final int remaining =
        seconds % 60;
    return '$minutes:${remaining.toString().padLeft(2, '0')}';
  }
  @override
  Widget build(BuildContext context) {
    if (load) {
      return Scaffold(
        backgroundColor:
            const Color(0xFF0D1B2A),
        appBar: AppBar(
          backgroundColor:
              const Color(0xFF1B263B),
          foregroundColor:
              Colors.white,
          title: const Text(
            'Che ansia..',
            style: TextStyle(
              fontSize: 16,
            ),
          ),
        ),
        body: const Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }
    if (_questionLength == 0) {
      return Scaffold(
        backgroundColor:
            const Color(0xFF0D1B2A),
        appBar: AppBar(
          backgroundColor:
              const Color(0xFF1B263B),
          foregroundColor:
              Colors.white,
          title: const Text(
            'Quiz',
          ),
        ),
        body: const Center(
          child: Text(
            'Non sono state trovate domande.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ),
      );
    }
    final options =
        _currentOptions();
    final metadata =
        _currentMetadata;
    final Widget quizScaffold = Scaffold(
      backgroundColor:
          const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor:
            const Color(0xFF1B263B),
        foregroundColor:
            Colors.white,
        elevation: 0,
        title: Text(
          '${metadata['sub'] ?? widget.sub}'
          ' - '
          '${metadata['argoment'] ?? ''}',
          style: const TextStyle(
            fontSize: 16,
          ),
        ),
        actions: [
          if (widget.isAssigned &&
              _remainingSeconds != null)
            Center(
              child: Padding(
                padding:
                    const EdgeInsets.only(
                  right: 12,
                ),
                child: Text(
                  _formatRemaining(
                    _remainingSeconds!,
                  ),
                  style: TextStyle(
                    color:
                        _remainingSeconds! <=
                                60
                            ? Colors.redAccent
                            : Colors.white,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (!widget.isAssigned)
            IconButton(
              icon: const Icon(
                Icons.book,
              ),
              tooltip: 'Spiegazione',
              onPressed: () {
                _showExplanation(
                  context,
                  question[idx],
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: LayoutBuilder(
            builder:
                (context, constraints) {
              final isLargeScreen =
                  constraints.maxWidth >
                      700;
              final contentWidth =
                  isLargeScreen
                      ? 600.0
                      : constraints.maxWidth;
              return SizedBox(
                width: contentWidth,
                child: ListView(
                  padding:
                      const EdgeInsets.all(
                    20,
                  ),
                  children: [
                    LinearProgressIndicator(
                      value:
                          (idx + 1) /
                              _questionLength,
                      backgroundColor:
                          Colors.white
                              .withOpacity(
                                0.1,
                              ),
                      valueColor:
                          const AlwaysStoppedAnimation<
                              Color>(
                        Color(
                          0xFF5C6BC0,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 25,
                    ),
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Expanded(
                          child: Text(
                            _currentText,
                            style:
                                const TextStyle(
                              color:
                                  Colors.white,
                              fontSize: 14,
                              fontWeight:
                                  FontWeight
                                      .w500,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 15,
                        ),
                        Container(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                const Color(
                              0xFF1B263B,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              8,
                            ),
                          ),
                          child: Text(
                            '${idx + 1}/$_questionLength',
                            style:
                                const TextStyle(
                              color:
                                  Colors.white,
                              fontSize: 10,
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 35,
                    ),
                    ...options.map(
                      (option) {
                        return Padding(
                          padding:
                              const EdgeInsets
                                  .only(
                            bottom: 12,
                          ),
                          child:
                              ElevatedButton(
                            style:
                                ElevatedButton
                                    .styleFrom(
                              backgroundColor:
                                  const Color(
                                0xFF1B263B,
                              ),
                              foregroundColor:
                                  Colors.white,
                              disabledBackgroundColor:
                                  const Color(
                                0xFF1B263B,
                              ),
                              disabledForegroundColor:
                                  Colors.white
                                      .withOpacity(
                                        0.50,
                                      ),
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                vertical: 18,
                                horizontal: 16,
                              ),
                              alignment:
                                  Alignment
                                      .centerLeft,
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  12,
                                ),
                              ),
                              elevation: 3,
                            ),
                            onPressed:
                                isLocked ||
                                        _completing
                                    ? null
                                    : () =>
                                        answerValidate(
                                          option.id,
                                        ),
                            child: Text(
                              option.text,
                              style:
                                  const TextStyle(
                                fontSize: 16,
                                fontWeight:
                                    FontWeight
                                        .w400,
                                height: 1.2,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    if (_completing) ...[
                      const SizedBox(
                        height: 16,
                      ),
                      const Center(
                        child:
                            CircularProgressIndicator(),
                      ),
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
      onForcedSubmit: (reason) async {
        await _completeAssignedQuiz(
          reason: reason,
        );
      },
      child: quizScaffold,
    );
  }
}
class _QuizOptionView {
  final String id;
  final String text;
  const _QuizOptionView({
    required this.id,
    required this.text,
  });
}