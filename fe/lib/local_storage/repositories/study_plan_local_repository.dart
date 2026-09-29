import 'dart:math';
import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';

import '../database/app_database.dart';
import '../database/database_tables.dart';

class StudyPlanLocalRepository {
  final AppDatabase _database;
  final Random _random = Random.secure();

  StudyPlanLocalRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  Future<String> ensureGuestSource(String deviceId) async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseTables.studyPlanSources,
      where: "source_type = 'guest' AND device_id = ? AND claimed_by_user_id IS NULL",
      whereArgs: <Object?>[deviceId],
      orderBy: 'last_activity_at DESC',
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['source_key']!.toString();

    final String sessionUuid = 'guest-${_randomHex(16)}';
    final String sourceKey = 'guest:$sessionUuid';
    final String now = DateTime.now().toUtc().toIso8601String();
    await db.insert(DatabaseTables.studyPlanSources, <String, Object?>{
      'source_key': sourceKey,
      'session_uuid': sessionUuid,
      'device_id': deviceId,
      'remote_user_id': null,
      'source_type': 'guest',
      'display_label': 'Guest',
      'contribution_enabled': 1,
      'claimed_by_user_id': null,
      'is_current_device': 1,
      'sync_state': 'local',
      'created_at': now,
      'last_activity_at': now,
      'updated_at': now,
    });
    return sourceKey;
  }

  Future<void> refreshGuestFromQuizAttempts(String deviceId) async {
    final Database db = await _database.database;
    final String sourceKey = await ensureGuestSource(deviceId);

    // I tentativi Guest creati prima della v9 non avevano una sorgente.
    // Li assegniamo una sola volta alla sessione Guest corrente; dopo il claim
    // resteranno legati a quella sessione e non potranno essere importati di nuovo.
    await db.update(
      DatabaseTables.quizAttempts,
      <String, Object?>{'study_source_key': sourceKey},
      where: 'user_id = 0 AND study_source_key IS NULL',
    );

    final List<Map<String, dynamic>> rows = await db.rawQuery('''
      SELECT q.*, a.department, a.course, a.subject
      FROM ${DatabaseTables.quizAttemptAnswers} q
      INNER JOIN ${DatabaseTables.quizAttempts} a ON a.id = q.attempt_id
      WHERE a.user_id = 0
        AND a.status = 'completed'
        AND a.is_hidden_from_history = 0
        AND a.study_source_key = ?
      ORDER BY q.answered_at ASC
    ''', <Object?>[sourceKey]);

    final Map<String, _Aggregate> values = <String, _Aggregate>{};
    for (final Map<String, dynamic> row in rows) {
      final String department = row['department']?.toString().trim() ?? '';
      final String course = row['course']?.toString().trim() ?? '';
      final String subject = row['subject']?.toString().trim() ?? '';
      final String questionId = row['question_id']?.toString().trim() ?? '';
      if (department.isEmpty || course.isEmpty || subject.isEmpty || questionId.isEmpty) continue;
      final String itemKey = _itemKey(department, course, subject, questionId);
      values.putIfAbsent(itemKey, () => _Aggregate(itemKey: itemKey)).add(row);
    }

    for (final _Aggregate aggregate in values.values) {
      final int itemId = await _upsertItem(db, aggregate.latest!);
      final String contributionUuid = 'guest:${_sessionUuidFromSource(sourceKey)}:${aggregate.itemKey}';
      await _upsertContribution(
        db,
        itemId: itemId,
        sourceKey: sourceKey,
        contributionUuid: contributionUuid,
        correct: aggregate.correct,
        wrong: aggregate.wrong,
        unanswered: aggregate.unanswered,
        reviewCount: aggregate.total,
        lastIsCorrect: aggregate.lastIsCorrect,
        lastSelectedOptionId: aggregate.latest!['selected_option_id']?.toString(),
        lastSelectedOptionText: aggregate.latest!['selected_option_text']?.toString(),
        lastSelectedAnswerExplanation: aggregate.latest!['selected_answer_explanation']?.toString(),
        firstSeenAt: aggregate.firstAnsweredAt,
        lastAnsweredAt: aggregate.lastAnsweredAt,
        clientRevision: aggregate.total,
      );
      await _recomputeItem(db, itemId);
    }
  }

  Future<List<Map<String, dynamic>>> pendingGuestSyncPayload(int userId) async {
    final Database db = await _database.database;
    final List<Map<String, dynamic>> sources = await db.query(
      DatabaseTables.studyPlanSources,
      where: "source_type = 'guest' AND claimed_by_user_id IS NULL",
    );
    final List<Map<String, dynamic>> result = <Map<String, dynamic>>[];
    for (final Map<String, dynamic> source in sources) {
      final String sourceKey = source['source_key'].toString();
      final List<Map<String, dynamic>> contributions = await _contributionsForSource(db, sourceKey);
      if (contributions.isEmpty) continue;
      result.add(<String, dynamic>{
        'source_key': sourceKey,
        'session_uuid': source['session_uuid'],
        'device_id': source['device_id'],
        'device_label': source['display_label'],
        'source_type': 'guest',
        'contributions': contributions,
      });
    }
    return result;
  }

  Future<void> markGuestClaimed(String sourceKey, int userId) async {
    final Database db = await _database.database;
    await db.update(
      DatabaseTables.studyPlanSources,
      <String, Object?>{
        'claimed_by_user_id': userId,
        'remote_user_id': userId,
        'sync_state': 'synced',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'source_key = ?',
      whereArgs: <Object?>[sourceKey],
    );
  }

  Future<void> mergeBootstrap(int userId, Map<String, dynamic> bootstrap) async {
    final Database db = await _database.database;
    final dynamic rawSessions = bootstrap['sessions'];
    if (rawSessions is List) {
      for (final dynamic raw in rawSessions) {
        if (raw is! Map) continue;
        final Map<String, dynamic> session = Map<String, dynamic>.from(raw);
        final String sessionUuid = session['session_uuid']?.toString() ?? '';
        if (sessionUuid.isEmpty) continue;
        final List<Map<String, Object?>> existing = await db.query(
          DatabaseTables.studyPlanSources,
          where: 'session_uuid = ?',
          whereArgs: <Object?>[sessionUuid],
          limit: 1,
        );
        final String sourceKey = existing.isNotEmpty
            ? existing.first['source_key']!.toString()
            : 'remote:$userId:$sessionUuid';
        final String now = DateTime.now().toUtc().toIso8601String();
        final Map<String, Object?> values = <String, Object?>{
          'source_key': sourceKey,
          'session_uuid': sessionUuid,
          'device_id': session['device_id']?.toString() ?? 'server',
          'remote_user_id': userId,
          'source_type': session['source_type']?.toString() ?? 'authenticated',
          'display_label': session['device_label']?.toString(),
          'contribution_enabled': session['contribution_enabled'] == false ? 0 : 1,
          'claimed_by_user_id': session['source_type'] == 'guest' ? userId : null,
          'is_current_device': 0,
          'sync_state': 'synced',
          'created_at': session['created_at']?.toString() ?? now,
          'last_activity_at': session['last_activity_at']?.toString() ?? now,
          'updated_at': now,
        };
        await db.insert(DatabaseTables.studyPlanSources, values, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }

    final dynamic rawItems = bootstrap['items'];
    if (rawItems is! List) return;
    for (final dynamic raw in rawItems) {
      if (raw is! Map) continue;
      final Map<String, dynamic> item = Map<String, dynamic>.from(raw);
      final int itemId = await _upsertRemoteItem(db, item);
      final dynamic rawContributions = item['contributions'];
      if (rawContributions is List) {
        for (final dynamic rawContribution in rawContributions) {
          if (rawContribution is! Map) continue;
          final Map<String, dynamic> contribution = Map<String, dynamic>.from(rawContribution);
          final String sessionUuid = contribution['session_uuid']?.toString() ?? '';
          final List<Map<String, Object?>> sourceRows = await db.query(
            DatabaseTables.studyPlanSources,
            where: 'session_uuid = ?',
            whereArgs: <Object?>[sessionUuid],
            limit: 1,
          );
          if (sourceRows.isEmpty) continue;
          await _upsertContribution(
            db,
            itemId: itemId,
            sourceKey: sourceRows.first['source_key']!.toString(),
            contributionUuid: contribution['contribution_uuid']?.toString() ?? 'remote:$userId:$sessionUuid:${item['question_id']}',
            correct: _int(contribution['correct_count']),
            wrong: _int(contribution['wrong_count']),
            unanswered: _int(contribution['unanswered_count']),
            reviewCount: _int(contribution['review_count']),
            lastIsCorrect: _boolOrNull(contribution['last_is_correct']),
            lastSelectedOptionId: contribution['last_selected_option_id']?.toString(),
            lastSelectedOptionText: contribution['last_selected_option_text']?.toString(),
            lastSelectedAnswerExplanation: contribution['last_selected_answer_explanation']?.toString(),
            firstSeenAt: contribution['first_seen_at']?.toString(),
            lastAnsweredAt: contribution['last_answered_at']?.toString(),
            clientRevision: _int(contribution['client_revision']),
          );
        }
      }
      await _recomputeItem(db, itemId);
    }
  }

  Future<Map<String, dynamic>> getOverall() async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.rawQuery('''
      SELECT COALESCE(SUM(p.total_answers),0) total_questions,
             COALESCE(SUM(p.correct_count),0) correct_count,
             COALESCE(SUM(p.wrong_count),0) wrong_count,
             COALESCE(SUM(p.unanswered_count),0) unanswered_count,
             COUNT(*) item_count
      FROM ${DatabaseTables.studyPlanProgress} p
    ''');
    final Map<String, Object?> row = rows.first;
    final int total = _int(row['total_questions']);
    final int correct = _int(row['correct_count']);
    return <String, dynamic>{
      'total_attempts': 0,
      'total_questions': total,
      'correct_count': correct,
      'wrong_count': _int(row['wrong_count']),
      'unanswered_count': _int(row['unanswered_count']),
      'accuracy_percentage': total == 0 ? 0.0 : correct / total * 100.0,
      'item_count': _int(row['item_count']),
    };
  }

  Future<List<Map<String, dynamic>>> getSubjects() async => _aggregate(groupByArgument: false);
  Future<List<Map<String, dynamic>>> getArguments({String? department, String? course, String? subject}) async =>
      _aggregate(groupByArgument: true, department: department, course: course, subject: subject);

  Future<List<Map<String, dynamic>>> getWeakArguments({String? department, String? course, String? subject, double maximumAccuracy = 70, int minimumAnswers = 1}) async {
    final List<Map<String, dynamic>> rows = await getArguments(department: department, course: course, subject: subject);
    return rows.where((Map<String, dynamic> row) => _int(row['total_questions']) >= minimumAnswers && _double(row['accuracy_percentage']) <= maximumAccuracy).toList();
  }

  Future<List<Map<String, dynamic>>> getReview({String? department, String? course, String? subject, String? argument, bool includeCorrect = false}) async {
    final Database db = await _database.database;
    final List<String> where = <String>['s.contribution_enabled = 1'];
    final List<Object?> args = <Object?>[];
    void filter(String column, String? value) {
      final String normalized = value?.trim() ?? '';
      if (normalized.isNotEmpty) { where.add('$column = ?'); args.add(normalized); }
    }
    filter('i.department', department); filter('i.course', course); filter('i.subject', subject);
    if ((argument ?? '').trim().isNotEmpty) {
      if (argument!.trim() == 'Senza argomento') where.add("(i.argument IS NULL OR TRIM(i.argument) = '')");
      else { where.add('i.argument = ?'); args.add(argument.trim()); }
    }
    final List<Map<String, dynamic>> rows = await db.rawQuery('''
      SELECT i.*, p.total_answers, p.correct_count, p.wrong_count, p.unanswered_count,
             p.mastery_percentage AS accuracy_percentage, p.review_count, p.source_count,
             c.last_selected_option_text, c.last_selected_answer_explanation, MAX(c.last_answered_at) AS last_answered_at,
             GROUP_CONCAT(DISTINCT s.source_type) AS source_types,
             GROUP_CONCAT(DISTINCT COALESCE(CAST(s.remote_user_id AS TEXT), 'guest')) AS source_users
      FROM ${DatabaseTables.studyPlanItems} i
      JOIN ${DatabaseTables.studyPlanProgress} p ON p.item_id = i.id
      LEFT JOIN ${DatabaseTables.studyPlanContributions} c ON c.item_id = i.id
      LEFT JOIN ${DatabaseTables.studyPlanSources} s ON s.source_key = c.source_key
      WHERE ${where.join(' AND ')}
      GROUP BY i.id
      ORDER BY p.wrong_count DESC, p.mastery_percentage ASC
    ''', args);
    return rows.where((Map<String, dynamic> row) => includeCorrect || _int(row['wrong_count']) > 0 || _int(row['unanswered_count']) > 0)
      .map((row) {
        final value = Map<String, dynamic>.from(row);
        try { value['options'] = jsonDecode(row['options_snapshot']?.toString() ?? '[]'); }
        catch (_) { value['options'] = <dynamic>[]; }
        return value;
      }).toList();
  }

  Future<List<Map<String, dynamic>>> getSources() async {
    final Database db = await _database.database;
    return db.query(DatabaseTables.studyPlanSources, orderBy: 'last_activity_at DESC');
  }

  Future<void> setSourceEnabled(String sourceKey, bool enabled) async {
    final Database db = await _database.database;
    await db.update(DatabaseTables.studyPlanSources, <String, Object?>{
      'contribution_enabled': enabled ? 1 : 0,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, where: 'source_key = ?', whereArgs: <Object?>[sourceKey]);
    final List<Map<String, Object?>> itemRows = await db.query(DatabaseTables.studyPlanContributions, columns: <String>['item_id'], where: 'source_key = ?', whereArgs: <Object?>[sourceKey]);
    for (final Map<String, Object?> row in itemRows) await _recomputeItem(db, _int(row['item_id']));
  }

  Future<void> removeSource(String sourceKey) async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> itemRows = await db.query(DatabaseTables.studyPlanContributions, columns: <String>['item_id'], where: 'source_key = ?', whereArgs: <Object?>[sourceKey]);
    await db.delete(DatabaseTables.studyPlanSources, where: 'source_key = ?', whereArgs: <Object?>[sourceKey]);
    for (final Map<String, Object?> row in itemRows) await _recomputeItem(db, _int(row['item_id']));
  }

  Future<List<Map<String, dynamic>>> _aggregate({required bool groupByArgument, String? department, String? course, String? subject}) async {
    final Database db = await _database.database;
    final List<String> where = <String>['s.contribution_enabled = 1'];
    final List<Object?> args = <Object?>[];
    void filter(String column, String? value) { final String v = value?.trim() ?? ''; if (v.isNotEmpty) { where.add('$column = ?'); args.add(v); } }
    filter('i.department', department); filter('i.course', course); filter('i.subject', subject);
    final String group = groupByArgument ? 'i.department, i.course, i.subject, COALESCE(NULLIF(TRIM(i.argument),\'\'),\'Senza argomento\')' : 'i.department, i.course, i.subject';
    final String argumentSelect = groupByArgument ? ", COALESCE(NULLIF(TRIM(i.argument),''),'Senza argomento') AS argument" : '';
    final List<Map<String, dynamic>> queryRows = await db.rawQuery('''
      SELECT i.department, i.course, i.subject $argumentSelect,
             COUNT(DISTINCT i.id) AS item_count,
             SUM(c.correct_count + c.wrong_count + c.unanswered_count) AS total_questions,
             SUM(c.correct_count) AS correct_count,
             SUM(c.wrong_count) AS wrong_count,
             SUM(c.unanswered_count) AS unanswered_count,
             SUM(c.review_count) AS review_count
      FROM ${DatabaseTables.studyPlanItems} i
      JOIN ${DatabaseTables.studyPlanContributions} c ON c.item_id = i.id
      JOIN ${DatabaseTables.studyPlanSources} s ON s.source_key = c.source_key
      WHERE ${where.join(' AND ')} GROUP BY $group
    ''', args);

    final List<Map<String, dynamic>> rows = queryRows
        .map((Map<String, dynamic> row) => Map<String, dynamic>.from(row))
        .toList();

    for (final Map<String, dynamic> row in rows) {
      final int total = _int(row['total_questions']);
      row['accuracy_percentage'] =
          total == 0 ? 0.0 : _int(row['correct_count']) / total * 100.0;
    }

    rows.sort(
      (Map<String, dynamic> a, Map<String, dynamic> b) =>
          _double(a['accuracy_percentage']).compareTo(
            _double(b['accuracy_percentage']),
          ),
    );
    return rows;
  }

  Future<List<Map<String, dynamic>>> _contributionsForSource(Database db, String sourceKey) async {
    final List<Map<String, dynamic>> rows = await db.rawQuery('''
      SELECT c.contribution_uuid, i.department, i.course, i.subject, i.argument, i.question_id,
             i.question_text, i.correct_option_id, i.correct_option_text, i.formal_explanation,
             i.informal_explanation, i.correct_answer_explanation, i.question_type,
             c.correct_count, c.wrong_count, c.unanswered_count, c.review_count,
             c.last_is_correct, c.last_selected_option_id, c.last_selected_option_text,
             c.last_selected_answer_explanation, c.first_seen_at, c.last_answered_at, c.client_revision
      FROM ${DatabaseTables.studyPlanContributions} c
      JOIN ${DatabaseTables.studyPlanItems} i ON i.id = c.item_id
      WHERE c.source_key = ?
    ''', <Object?>[sourceKey]);
    return rows.map((Map<String, dynamic> row) {
      final Map<String, dynamic> value = Map<String, dynamic>.from(row);
      final dynamic rawCorrect = value['last_is_correct'];
      value['last_is_correct'] = rawCorrect == null ? null : _int(rawCorrect) == 1;
      return value;
    }).toList();
  }

  Future<int> _upsertItem(Database db, Map<String, dynamic> row) async {
    return _upsertRemoteItem(db, <String, dynamic>{
      'department': row['department'], 'course': row['course'], 'subject': row['subject'], 'argument': row['argument'],
      'question_id': row['question_id'], 'question_text': row['question_text'], 'correct_option_id': row['correct_option_id'],
      'correct_option_text': row['correct_option_text'], 'formal_explanation': row['formal_explanation'],
      'informal_explanation': row['informal_explanation'], 'correct_answer_explanation': row['correct_answer_explanation'],
      'first_seen_at': row['answered_at'], 'last_seen_at': row['answered_at'],
      'question_type': row['question_type'],
    });
  }

  Future<int> _upsertRemoteItem(Database db, Map<String, dynamic> item) async {
    final String department = item['department']?.toString().trim() ?? '';
    final String course = item['course']?.toString().trim() ?? '';
    final String subject = item['subject']?.toString().trim() ?? '';
    final String questionId = item['question_id']?.toString().trim() ?? '';
    final String key = _itemKey(department, course, subject, questionId);
    final String now = DateTime.now().toUtc().toIso8601String();
    await db.insert(DatabaseTables.studyPlanItems, <String, Object?>{
      'item_key': key, 'department': department, 'course': course, 'subject': subject,
      'argument': item['argument']?.toString(), 'question_id': questionId, 'question_text': item['question_text']?.toString() ?? '',
      'correct_option_id': item['correct_option_id']?.toString(), 'correct_option_text': item['correct_option_text']?.toString(),
      'options_snapshot': jsonEncode(item['options'] is List ? item['options'] : []),
      'formal_explanation': item['formal_explanation']?.toString(), 'informal_explanation': item['informal_explanation']?.toString(),
      'correct_answer_explanation': item['correct_answer_explanation']?.toString(),
      'first_seen_at': item['first_seen_at']?.toString() ?? now, 'last_seen_at': item['last_seen_at']?.toString() ?? now, 'updated_at': now,
      'question_type': item['question_type']?.toString() ?? 'multiple_choice',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.update(DatabaseTables.studyPlanItems, <String, Object?>{
      'argument': item['argument']?.toString(), 'question_text': item['question_text']?.toString() ?? '',
      'correct_option_id': item['correct_option_id']?.toString(), 'correct_option_text': item['correct_option_text']?.toString(),
      if (item['options'] is List && (item['options'] as List).isNotEmpty)
        'options_snapshot': jsonEncode(item['options']),
      'formal_explanation': item['formal_explanation']?.toString(), 'informal_explanation': item['informal_explanation']?.toString(),
      'correct_answer_explanation': item['correct_answer_explanation']?.toString(), 'last_seen_at': item['last_seen_at']?.toString() ?? now, 'updated_at': now,
      if (item['question_type'] != null) 'question_type': item['question_type'].toString(),
    }, where: 'item_key = ?', whereArgs: <Object?>[key]);
    final List<Map<String, Object?>> rows = await db.query(DatabaseTables.studyPlanItems, columns: <String>['id'], where: 'item_key = ?', whereArgs: <Object?>[key], limit: 1);
    return _int(rows.first['id']);
  }

  Future<void> _upsertContribution(Database db, {required int itemId, required String sourceKey, required String contributionUuid, required int correct, required int wrong, required int unanswered, required int reviewCount, required bool? lastIsCorrect, String? lastSelectedOptionId, String? lastSelectedOptionText, String? lastSelectedAnswerExplanation, String? firstSeenAt, String? lastAnsweredAt, required int clientRevision}) async {
    final String now = DateTime.now().toUtc().toIso8601String();
    final Map<String, Object?> values = <String, Object?>{
      'contribution_uuid': contributionUuid, 'item_id': itemId, 'source_key': sourceKey,
      'correct_count': correct, 'wrong_count': wrong, 'unanswered_count': unanswered, 'review_count': reviewCount,
      'last_is_correct': lastIsCorrect == null ? null : (lastIsCorrect ? 1 : 0),
      'last_selected_option_id': lastSelectedOptionId, 'last_selected_option_text': lastSelectedOptionText,
      'last_selected_answer_explanation': lastSelectedAnswerExplanation, 'first_seen_at': firstSeenAt ?? now,
      'last_answered_at': lastAnsweredAt, 'client_revision': clientRevision, 'updated_at': now,
    };
    final List<Map<String, Object?>> rows = await db.query(DatabaseTables.studyPlanContributions, columns: <String>['id'], where: 'item_id = ? AND source_key = ?', whereArgs: <Object?>[itemId, sourceKey], limit: 1);
    if (rows.isEmpty) await db.insert(DatabaseTables.studyPlanContributions, values);
    else await db.update(DatabaseTables.studyPlanContributions, values, where: 'id = ?', whereArgs: <Object?>[_int(rows.first['id'])]);
  }

  Future<void> _recomputeItem(Database db, int itemId) async {
    final List<Map<String, Object?>> rows = await db.rawQuery('''
      SELECT COALESCE(SUM(c.correct_count),0) correct_count, COALESCE(SUM(c.wrong_count),0) wrong_count,
             COALESCE(SUM(c.unanswered_count),0) unanswered_count, COALESCE(SUM(c.review_count),0) review_count,
             COUNT(*) source_count, MAX(c.last_answered_at) last_reviewed_at
      FROM ${DatabaseTables.studyPlanContributions} c
      JOIN ${DatabaseTables.studyPlanSources} s ON s.source_key = c.source_key
      WHERE c.item_id = ? AND s.contribution_enabled = 1
    ''', <Object?>[itemId]);
    final Map<String, Object?> row = rows.first;
    final int correct = _int(row['correct_count']), wrong = _int(row['wrong_count']), unanswered = _int(row['unanswered_count']);
    final int total = correct + wrong + unanswered;
    final double mastery = total == 0 ? 0 : correct / total * 100.0;
    final String status = mastery >= 85 ? 'consolidated' : mastery >= 60 ? 'improving' : 'review';
    await db.insert(DatabaseTables.studyPlanProgress, <String, Object?>{
      'item_id': itemId, 'total_answers': total, 'correct_count': correct, 'wrong_count': wrong, 'unanswered_count': unanswered,
      'review_count': _int(row['review_count']), 'source_count': _int(row['source_count']), 'mastery_percentage': mastery,
      'status': status, 'last_reviewed_at': row['last_reviewed_at']?.toString(), 'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  String _randomHex(int bytes) => List<int>.generate(bytes, (_) => _random.nextInt(256)).map((int value) => value.toRadixString(16).padLeft(2, '0')).join();
  static String _itemKey(String d, String c, String s, String q) => '$d\u0001$c\u0001$s\u0001$q';
  static String _sessionUuidFromSource(String sourceKey) => sourceKey.startsWith('guest:') ? sourceKey.substring(6) : sourceKey;
  static int _int(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

  static double _double(dynamic value) =>
      value is num
          ? value.toDouble()
          : double.tryParse(value?.toString() ?? '') ?? 0.0;

  static bool? _boolOrNull(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value.toInt() != 0;

    final String normalized = value.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
    return null;
  }
}

class _Aggregate {
  final String itemKey;
  int total = 0, correct = 0, wrong = 0, unanswered = 0;
  bool? lastIsCorrect;
  String? firstAnsweredAt, lastAnsweredAt;
  Map<String, dynamic>? latest;
  _Aggregate({required this.itemKey});
  void add(Map<String, dynamic> row) {
    total++;
    final bool? isCorrect = row['is_correct'] == null ? null : StudyPlanLocalRepository._int(row['is_correct']) == 1;
    final String selected = row['selected_option_id']?.toString().trim() ?? '';
    if (selected.isEmpty || isCorrect == null) unanswered++; else if (isCorrect) correct++; else wrong++;
    final String? answeredAt = row['answered_at']?.toString();
    firstAnsweredAt ??= answeredAt;
    lastAnsweredAt = answeredAt;
    lastIsCorrect = isCorrect;
    latest = Map<String, dynamic>.from(row);
  }
}
