import 'package:sqflite_common/sqlite_api.dart';

import '../database/app_database.dart';
import '../database/database_tables.dart';
import '../models/quiz_attempt_answer_local.dart';
import '../models/quiz_attempt_local.dart';
import '../services/local_storage_identity.dart';
import '../../services/device_key_service.dart';
import 'study_plan_local_repository.dart';

class QuizAttemptLocalRepository {
  final AppDatabase _database;
  final DeviceKeyService _deviceKeys;
  final StudyPlanLocalRepository _studyPlanRepository;

  QuizAttemptLocalRepository({
    AppDatabase? database,
    DeviceKeyService? deviceKeys,
    StudyPlanLocalRepository? studyPlanRepository,
  })  : _database = database ?? AppDatabase.instance,
        _deviceKeys = deviceKeys ?? DeviceKeyService(),
        _studyPlanRepository = studyPlanRepository ?? StudyPlanLocalRepository(database: database);

  int get guestUserId => LocalStorageIdentity.guestUserId;

  Future<int> startGuestAttempt({
    required String department,
    required String course,
    required String subject,
    required int totalQuestions,
  }) async {
    final Database db = await _database.database;

    final DateTime now = DateTime.now().toUtc();
    final String deviceId = await _deviceKeys.getDeviceId();
    final String studySourceKey =
        await _studyPlanRepository.ensureGuestSource(deviceId);

    final QuizAttemptLocal attempt = QuizAttemptLocal(
      userId: guestUserId,
      mode: 'free',
      department: department.trim(),
      course: course.trim(),
      subject: subject.trim(),
      status: 'in_progress',
      totalQuestions: totalQuestions,
      correctCount: 0,
      wrongCount: 0,
      unansweredCount: totalQuestions,
      isHiddenFromHistory: false,
      studySourceKey: studySourceKey,
      startedAt: now,
      completedAt: null,
      createdAt: now,
      updatedAt: now,
    );

    return db.insert(DatabaseTables.quizAttempts, attempt.toMap());
  }

  Future<void> saveAnswer(QuizAttemptAnswerLocal answer) async {
    final Database db = await _database.database;

    await db.insert(
      DatabaseTables.quizAttemptAnswers,
      answer.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> answerCount(int attemptId) async {
    final Database db = await _database.database;

    final List<Map<String, Object?>> rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count
      FROM ${DatabaseTables.quizAttemptAnswers}
      WHERE attempt_id = ?
      ''',
      <Object?>[attemptId],
    );

    if (rows.isEmpty) {
      return 0;
    }

    return _asInt(rows.first['count']) ?? 0;
  }

  Future<void> completeAttempt(int attemptId) async {
    final Database db = await _database.database;

    final List<Map<String, dynamic>> answers = await db.query(
      DatabaseTables.quizAttemptAnswers,
      where: 'attempt_id = ?',
      whereArgs: <Object?>[attemptId],
    );

    int correct = 0;
    int wrong = 0;
    int unanswered = 0;

    for (final Map<String, dynamic> row in answers) {
      final dynamic isCorrect = row['is_correct'];
      final String selected =
          row['selected_option_id']?.toString().trim() ?? '';

      if (selected.isEmpty || isCorrect == null) {
        unanswered++;
      } else if (_asInt(isCorrect) == 1) {
        correct++;
      } else {
        wrong++;
      }
    }

    final List<Map<String, dynamic>> attemptRows = await db.query(
      DatabaseTables.quizAttempts,
      columns: <String>['total_questions'],
      where: 'id = ?',
      whereArgs: <Object?>[attemptId],
      limit: 1,
    );

    final int expected = attemptRows.isEmpty
        ? answers.length
        : _asInt(attemptRows.first['total_questions']) ?? answers.length;

    if (answers.length < expected) {
      unanswered += expected - answers.length;
    }

    final String now = DateTime.now().toUtc().toIso8601String();

    await db.update(
      DatabaseTables.quizAttempts,
      <String, Object?>{
        'status': 'completed',
        'correct_count': correct,
        'wrong_count': wrong,
        'unanswered_count': unanswered,
        'completed_at': now,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: <Object?>[attemptId],
    );
  }

  Future<void> abandonAttempt(int attemptId) async {
    final Database db = await _database.database;

    await db.update(
      DatabaseTables.quizAttempts,
      <String, Object?>{
        'status': 'abandoned',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[attemptId],
    );
  }

  Future<void> hideAttempt(int attemptId) async {
    await _setHidden(attemptId, true);
  }

  Future<void> restoreAttempt(int attemptId) async {
    await _setHidden(attemptId, false);
  }

  Future<void> _setHidden(int attemptId, bool hidden) async {
    final Database db = await _database.database;

    await db.update(
      DatabaseTables.quizAttempts,
      <String, Object?>{
        'is_hidden_from_history': hidden ? 1 : 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: <Object?>[attemptId, guestUserId],
    );
  }

  Future<void> deleteAttempt(int attemptId) async {
    final Database db = await _database.database;

    await db.delete(
      DatabaseTables.quizAttempts,
      where: 'id = ? AND user_id = ?',
      whereArgs: <Object?>[attemptId, guestUserId],
    );
  }

  Future<Map<String, dynamic>> getGuestOverall() async {
    final List<Map<String, dynamic>> rows = await _visibleAnswerRows();

    final Set<int> attempts = <int>{};
    int correct = 0;
    int wrong = 0;
    int unanswered = 0;

    for (final Map<String, dynamic> row in rows) {
      final int? attemptId = _asInt(row['attempt_id']);

      if (attemptId != null) {
        attempts.add(attemptId);
      }

      final String selected =
          row['selected_option_id']?.toString().trim() ?? '';

      if (selected.isEmpty || row['is_correct'] == null) {
        unanswered++;
      } else if (_asInt(row['is_correct']) == 1) {
        correct++;
      } else {
        wrong++;
      }
    }

    final int total = correct + wrong + unanswered;

    return <String, dynamic>{
      'total_attempts': attempts.length,
      'total_questions': total,
      'correct_count': correct,
      'wrong_count': wrong,
      'unanswered_count': unanswered,
      'accuracy_percentage': _accuracy(correct, total),
    };
  }

  Future<List<Map<String, dynamic>>> getGuestSubjects() async {
    final List<Map<String, dynamic>> rows = await _visibleAnswerRows();

    final Map<String, _Aggregate> aggregates = <String, _Aggregate>{};

    for (final Map<String, dynamic> row in rows) {
      final String department = row['department']?.toString() ?? '';
      final String course = row['course']?.toString() ?? '';
      final String subject = row['subject']?.toString() ?? '';

      final String key = '$department\u0001$course\u0001$subject';

      final _Aggregate aggregate = aggregates.putIfAbsent(
        key,
        () => _Aggregate(
          department: department,
          course: course,
          subject: subject,
          argument: null,
        ),
      );

      aggregate.add(row);
    }

    final List<Map<String, dynamic>> result = aggregates.values
        .map((_Aggregate value) => value.toMap())
        .toList();

    result.sort(
      (Map<String, dynamic> first, Map<String, dynamic> second) =>
          (first['subject']?.toString() ?? '').toLowerCase().compareTo(
            (second['subject']?.toString() ?? '').toLowerCase(),
          ),
    );

    return result;
  }

  Future<List<Map<String, dynamic>>> getGuestArguments({
    String? department,
    String? course,
    String? subject,
  }) async {
    final List<Map<String, dynamic>> rows = await _visibleAnswerRows(
      department: department,
      course: course,
      subject: subject,
    );

    final Map<String, _Aggregate> aggregates = <String, _Aggregate>{};

    for (final Map<String, dynamic> row in rows) {
      final String value = row['argument']?.toString().trim() ?? '';

      final String argument = value.isEmpty ? 'Senza argomento' : value;

      final String departmentValue = row['department']?.toString() ?? '';
      final String courseValue = row['course']?.toString() ?? '';
      final String subjectValue = row['subject']?.toString() ?? '';

      final String key =
          '$departmentValue\u0001$courseValue\u0001$subjectValue\u0001$argument';

      final _Aggregate aggregate = aggregates.putIfAbsent(
        key,
        () => _Aggregate(
          department: departmentValue,
          course: courseValue,
          subject: subjectValue,
          argument: argument,
        ),
      );

      aggregate.add(row);
    }

    final List<Map<String, dynamic>> result = aggregates.values
        .map((_Aggregate value) => value.toMap())
        .toList();

    result.sort((Map<String, dynamic> first, Map<String, dynamic> second) {
      final double firstAccuracy = _asDouble(first['accuracy_percentage']) ?? 0;
      final double secondAccuracy =
          _asDouble(second['accuracy_percentage']) ?? 0;

      return firstAccuracy.compareTo(secondAccuracy);
    });

    return result;
  }

  Future<List<Map<String, dynamic>>> getGuestWeakArguments({
    String? department,
    String? course,
    String? subject,
    double maximumAccuracy = 70,
    int minimumAnswers = 1,
  }) async {
    final List<Map<String, dynamic>> arguments = await getGuestArguments(
      department: department,
      course: course,
      subject: subject,
    );

    return arguments.where((Map<String, dynamic> item) {
      final int total = _asInt(item['total_questions']) ?? 0;
      final double accuracy = _asDouble(item['accuracy_percentage']) ?? 0;

      return total >= minimumAnswers && accuracy <= maximumAccuracy;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getGuestReview({
    String? department,
    String? course,
    String? subject,
    String? argument,
    bool includeCorrect = false,
  }) async {
    final List<Map<String, dynamic>> rows = await _visibleAnswerRows(
      department: department,
      course: course,
      subject: subject,
      argument: argument,
    );

    final Map<String, _QuestionAggregate> aggregates =
        <String, _QuestionAggregate>{};

    for (final Map<String, dynamic> row in rows) {
      final String questionId = row['question_id']?.toString().trim() ?? '';

      if (questionId.isEmpty) {
        continue;
      }

      final String departmentValue = row['department']?.toString() ?? '';
      final String courseValue = row['course']?.toString() ?? '';
      final String subjectValue = row['subject']?.toString() ?? '';

      final String key =
          '$departmentValue\u0001$courseValue\u0001$subjectValue\u0001$questionId';

      final _QuestionAggregate aggregate = aggregates.putIfAbsent(
        key,
        () => _QuestionAggregate(questionId: questionId),
      );

      aggregate.add(row);
    }

    final List<Map<String, dynamic>> result = aggregates.values
        .where(
          (_QuestionAggregate item) =>
              includeCorrect || item.wrong > 0 || item.unanswered > 0,
        )
        .map((_QuestionAggregate item) => item.toMap())
        .toList();

    result.sort((Map<String, dynamic> first, Map<String, dynamic> second) {
      final int firstWrong = _asInt(first['wrong_count']) ?? 0;
      final int secondWrong = _asInt(second['wrong_count']) ?? 0;

      if (firstWrong != secondWrong) {
        return secondWrong.compareTo(firstWrong);
      }

      final double firstAccuracy = _asDouble(first['accuracy_percentage']) ?? 0;
      final double secondAccuracy =
          _asDouble(second['accuracy_percentage']) ?? 0;

      return firstAccuracy.compareTo(secondAccuracy);
    });

    return result;
  }

  Future<List<Map<String, dynamic>>> _visibleAnswerRows({
    String? department,
    String? course,
    String? subject,
    String? argument,
  }) async {
    final Database db = await _database.database;

    final List<String> where = <String>[
      'a.user_id = ?',
      "a.status = 'completed'",
      'a.is_hidden_from_history = 0',
    ];

    final List<Object?> args = <Object?>[guestUserId];

    void addFilter(String column, String? value) {
      final String normalized = value?.trim() ?? '';

      if (normalized.isEmpty) {
        return;
      }

      where.add('$column = ?');
      args.add(normalized);
    }

    addFilter('a.department', department);
    addFilter('a.course', course);
    addFilter('a.subject', subject);

    final String normalizedArgument = argument?.trim() ?? '';

    if (normalizedArgument.isNotEmpty) {
      if (normalizedArgument == 'Senza argomento') {
        where.add("(q.argument IS NULL OR TRIM(q.argument) = '')");
      } else {
        where.add('q.argument = ?');
        args.add(normalizedArgument);
      }
    }

    return db.rawQuery('''
      SELECT
        q.*,
        a.user_id,
        a.department,
        a.course,
        a.subject,
        a.started_at,
        a.completed_at
      FROM ${DatabaseTables.quizAttemptAnswers} q
      INNER JOIN ${DatabaseTables.quizAttempts} a
        ON a.id = q.attempt_id
      WHERE ${where.join(' AND ')}
      ORDER BY q.answered_at DESC
      ''', args);
  }

  static double _accuracy(int correct, int total) {
    if (total <= 0) {
      return 0;
    }

    return correct / total * 100;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '');
  }

  static double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }
}

class _Aggregate {
  final String department;
  final String course;
  final String subject;
  final String? argument;

  int total = 0;
  int correct = 0;
  int wrong = 0;
  int unanswered = 0;

  _Aggregate({
    required this.department,
    required this.course,
    required this.subject,
    required this.argument,
  });

  void add(Map<String, dynamic> row) {
    total++;

    final String selected = row['selected_option_id']?.toString().trim() ?? '';

    if (selected.isEmpty || row['is_correct'] == null) {
      unanswered++;
    } else if (QuizAttemptLocalRepository._asInt(row['is_correct']) == 1) {
      correct++;
    } else {
      wrong++;
    }
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'department': department,
      'course': course,
      'subject': subject,
      if (argument != null) 'argument': argument,
      'total_questions': total,
      'correct_count': correct,
      'wrong_count': wrong,
      'unanswered_count': unanswered,
      'accuracy_percentage': QuizAttemptLocalRepository._accuracy(
        correct,
        total,
      ),
    };
  }
}

class _QuestionAggregate {
  final String questionId;

  int total = 0;
  int correct = 0;
  int wrong = 0;
  int unanswered = 0;
  Map<String, dynamic>? latest;

  _QuestionAggregate({required this.questionId});

  void add(Map<String, dynamic> row) {
    total++;

    final String selected = row['selected_option_id']?.toString().trim() ?? '';

    if (selected.isEmpty || row['is_correct'] == null) {
      unanswered++;
    } else if (QuizAttemptLocalRepository._asInt(row['is_correct']) == 1) {
      correct++;
    } else {
      wrong++;
    }

    if (latest == null) {
      latest = Map<String, dynamic>.from(row);
    }
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> row = latest ?? <String, dynamic>{};

    return <String, dynamic>{
      'question_id': questionId,
      'department': row['department']?.toString() ?? '',
      'course': row['course']?.toString() ?? '',
      'subject': row['subject']?.toString() ?? '',
      'argument': row['argument']?.toString() ?? '',
      'question_text': row['question_text']?.toString() ?? '',
      'correct_option_text': row['correct_option_text']?.toString() ?? '',
      'last_selected_option_text':
          row['selected_option_text']?.toString() ?? '',
      'formal_explanation': row['formal_explanation']?.toString() ?? '',
      'informal_explanation': row['informal_explanation']?.toString() ?? '',
      'correct_answer_explanation':
          row['correct_answer_explanation']?.toString() ?? '',
      'last_selected_answer_explanation':
          row['selected_answer_explanation']?.toString() ?? '',
      'question_response_explanation':
          row['question_response_explanation']?.toString() ?? '',
      'total_answers': total,
      'correct_count': correct,
      'wrong_count': wrong,
      'unanswered_count': unanswered,
      'accuracy_percentage': QuizAttemptLocalRepository._accuracy(
        correct,
        total,
      ),
      'last_answered_at': row['answered_at']?.toString(),
    };
  }
}
