class QuizAttemptLocal {
  final int? id;
  final int userId;
  final String mode;
  final String department;
  final String course;
  final String subject;
  final String status;
  final int totalQuestions;
  final int correctCount;
  final int wrongCount;
  final int unansweredCount;
  final bool isHiddenFromHistory;
  final String? studySourceKey;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const QuizAttemptLocal({
    this.id,
    required this.userId,
    required this.mode,
    required this.department,
    required this.course,
    required this.subject,
    required this.status,
    required this.totalQuestions,
    required this.correctCount,
    required this.wrongCount,
    required this.unansweredCount,
    required this.isHiddenFromHistory,
    this.studySourceKey,
    required this.startedAt,
    required this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'user_id': userId,
      'mode': mode,
      'department': department,
      'course': course,
      'subject': subject,
      'status': status,
      'total_questions': totalQuestions,
      'correct_count': correctCount,
      'wrong_count': wrongCount,
      'unanswered_count': unansweredCount,
      'is_hidden_from_history':
          isHiddenFromHistory ? 1 : 0,
      'study_source_key': studySourceKey,
      'started_at': startedAt.toUtc().toIso8601String(),
      'completed_at':
          completedAt?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  factory QuizAttemptLocal.fromMap(
    Map<String, dynamic> map,
  ) {
    return QuizAttemptLocal(
      id: _int(map['id']),
      userId: _int(map['user_id']) ?? 0,
      mode: map['mode']?.toString() ?? 'free',
      department:
          map['department']?.toString() ?? '',
      course: map['course']?.toString() ?? '',
      subject: map['subject']?.toString() ?? '',
      status:
          map['status']?.toString() ?? 'in_progress',
      totalQuestions:
          _int(map['total_questions']) ?? 0,
      correctCount:
          _int(map['correct_count']) ?? 0,
      wrongCount:
          _int(map['wrong_count']) ?? 0,
      unansweredCount:
          _int(map['unanswered_count']) ?? 0,
      isHiddenFromHistory:
          _int(map['is_hidden_from_history']) == 1,
      studySourceKey: _nullable(map['study_source_key']),
      startedAt:
          _date(map['started_at']) ?? DateTime.now(),
      completedAt:
          _date(map['completed_at']),
      createdAt:
          _date(map['created_at']) ?? DateTime.now(),
      updatedAt:
          _date(map['updated_at']) ?? DateTime.now(),
    );
  }
}

int? _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String? _nullable(dynamic value) {
  final String text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

DateTime? _date(dynamic value) {
  final String raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}
