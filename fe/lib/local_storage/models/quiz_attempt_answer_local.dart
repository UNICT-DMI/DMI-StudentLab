class QuizAttemptAnswerLocal {
  final int? id;
  final int attemptId;
  final String questionId;
  final String? argument;
  final String questionText;
  final String? selectedOptionId;
  final String? selectedOptionText;
  final String? correctOptionId;
  final String? correctOptionText;
  final String? formalExplanation;
  final String? informalExplanation;
  final String? questionResponseExplanation;
  final String? selectedAnswerExplanation;
  final String? correctAnswerExplanation;
  final bool? isCorrect;
  final int? responseTimeSeconds;
  final DateTime answeredAt;

  const QuizAttemptAnswerLocal({
    this.id,
    required this.attemptId,
    required this.questionId,
    required this.argument,
    required this.questionText,
    required this.selectedOptionId,
    required this.selectedOptionText,
    required this.correctOptionId,
    required this.correctOptionText,
    required this.formalExplanation,
    required this.informalExplanation,
    required this.questionResponseExplanation,
    required this.selectedAnswerExplanation,
    required this.correctAnswerExplanation,
    required this.isCorrect,
    required this.responseTimeSeconds,
    required this.answeredAt,
  });

  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'attempt_id': attemptId,
      'question_id': questionId,
      'argument': argument,
      'question_text': questionText,
      'selected_option_id': selectedOptionId,
      'selected_option_text': selectedOptionText,
      'correct_option_id': correctOptionId,
      'correct_option_text': correctOptionText,
      'formal_explanation': formalExplanation,
      'informal_explanation': informalExplanation,
      'question_response_explanation':
          questionResponseExplanation,
      'selected_answer_explanation':
          selectedAnswerExplanation,
      'correct_answer_explanation':
          correctAnswerExplanation,
      'is_correct': isCorrect == null
          ? null
          : isCorrect!
              ? 1
              : 0,
      'response_time_seconds': responseTimeSeconds,
      'answered_at':
          answeredAt.toUtc().toIso8601String(),
    };
  }

  factory QuizAttemptAnswerLocal.fromMap(
    Map<String, dynamic> map,
  ) {
    return QuizAttemptAnswerLocal(
      id: _int(map['id']),
      attemptId:
          _int(map['attempt_id']) ?? 0,
      questionId:
          map['question_id']?.toString() ?? '',
      argument: _nullable(map['argument']),
      questionText:
          map['question_text']?.toString() ?? '',
      selectedOptionId:
          _nullable(map['selected_option_id']),
      selectedOptionText:
          _nullable(map['selected_option_text']),
      correctOptionId:
          _nullable(map['correct_option_id']),
      correctOptionText:
          _nullable(map['correct_option_text']),
      formalExplanation:
          _nullable(map['formal_explanation']),
      informalExplanation:
          _nullable(map['informal_explanation']),
      questionResponseExplanation:
          _nullable(
            map['question_response_explanation'],
          ),
      selectedAnswerExplanation:
          _nullable(
            map['selected_answer_explanation'],
          ),
      correctAnswerExplanation:
          _nullable(
            map['correct_answer_explanation'],
          ),
      isCorrect: map['is_correct'] == null
          ? null
          : _int(map['is_correct']) == 1,
      responseTimeSeconds:
          _int(map['response_time_seconds']),
      answeredAt:
          _date(map['answered_at']) ?? DateTime.now(),
    );
  }
}

int? _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String? _nullable(dynamic value) {
  final String text = value?.toString() ?? '';
  return text.trim().isEmpty ? null : text;
}

DateTime? _date(dynamic value) {
  final String raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}
