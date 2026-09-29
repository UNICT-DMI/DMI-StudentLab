import 'package:sqflite_common/sqlite_api.dart';

import 'database_tables.dart';

class DatabaseMigrations {
  DatabaseMigrations._();

  static Future<void> onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _migrationToVersion2(db);
    }

    if (oldVersion < 3) {
      await _migrationToVersion3(db);
    }

    if (oldVersion < 4) {
      await _migrationToVersion4(db);
    }

    if (oldVersion < 5) {
      await _migrationToVersion5(db);
    }

    if (oldVersion < 6) {
      await _migrationToVersion6(db);
    }

    if (oldVersion < 7) {
      await _migrationToVersion7(db);
    }

    if (oldVersion < 8) {
      await _migrationToVersion8(db);
    }

    if (oldVersion < 9) {
      await _migrationToVersion9(db);
    }

    if (oldVersion < 10) {
      await _migrationToVersion10(db);
    }

    if (oldVersion < 11) {
      await _migrationToVersion11(db);
    }

    if (oldVersion < 12) {
      await _migrationToVersion12(db);
    }
    if (oldVersion < 13) {
      await _migrationToVersion13(db);
    }

    if (oldVersion < 14) {
      await ensureExerciseSchema(db);
    }
    if (oldVersion < 15) {
      await ensureReviewOptions(db);
    }
  }

  static Future<void> ensureReviewOptions(Database db) async {
    if (await _tableExists(db, DatabaseTables.studyPlanItems) &&
        !await _columnExists(db, DatabaseTables.studyPlanItems, 'options_snapshot')) {
      await db.execute('ALTER TABLE ${DatabaseTables.studyPlanItems} ADD COLUMN options_snapshot TEXT');
    }
  }

  /// v14 · nuovi tipi di esercizio e flashcard. Solo aggiunte: i tentativi,
  /// il ripasso e i materiali già salvati restano come sono.
  static Future<void> ensureExerciseSchema(Database db) async {
    if (await _tableExists(db, DatabaseTables.quizAttemptAnswers)) {
      const Map<String, String> answerColumns = <String, String>{
        'question_type': "TEXT NOT NULL DEFAULT 'multiple_choice'",
        'answer_payload': 'TEXT',
        'correct_payload': 'TEXT',
        'score': 'REAL',
      };
      for (final MapEntry<String, String> column in answerColumns.entries) {
        if (!await _columnExists(db, DatabaseTables.quizAttemptAnswers, column.key)) {
          await db.execute('ALTER TABLE ${DatabaseTables.quizAttemptAnswers} ADD COLUMN ${column.key} ${column.value}');
        }
      }
    }
    if (await _tableExists(db, DatabaseTables.studyPlanItems) &&
        !await _columnExists(db, DatabaseTables.studyPlanItems, 'question_type')) {
      await db.execute(
        "ALTER TABLE ${DatabaseTables.studyPlanItems} ADD COLUMN question_type TEXT NOT NULL DEFAULT 'multiple_choice'",
      );
    }
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseTables.flashcardReviewsLocal} (
        card_key TEXT PRIMARY KEY,
        department TEXT NOT NULL,
        course TEXT NOT NULL,
        subject TEXT NOT NULL,
        card_id TEXT NOT NULL,
        argument TEXT,
        ease REAL NOT NULL DEFAULT 2.5,
        interval_days INTEGER NOT NULL DEFAULT 0,
        due_at TEXT,
        reviews INTEGER NOT NULL DEFAULT 0,
        lapses INTEGER NOT NULL DEFAULT 0,
        last_grade INTEGER,
        updated_at TEXT NOT NULL
      )
      ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_flashcard_local_subject ON ${DatabaseTables.flashcardReviewsLocal}(department, course, subject, due_at)',
    );
  }

  static Future<void> _migrationToVersion2(Database db) async {
    final bool exists = await _columnExists(
      db,
      DatabaseTables.pendingUploads,
      'retry_count',
    );

    if (!exists) {
      await db.execute('''
        ALTER TABLE ${DatabaseTables.pendingUploads}
        ADD COLUMN retry_count INTEGER NOT NULL DEFAULT 0
        ''');
    }
  }

  static Future<void> _migrationToVersion3(Database db) async {
    final bool exists = await _columnExists(
      db,
      DatabaseTables.pendingUploads,
      'last_attempt_at',
    );

    if (!exists) {
      await db.execute('''
        ALTER TABLE ${DatabaseTables.pendingUploads}
        ADD COLUMN last_attempt_at TEXT
        ''');
    }
  }

  static Future<void> _migrationToVersion4(Database db) async {
    if (!await _tableExists(db, DatabaseTables.downloadedMaterials)) {
      return;
    }

    final bool hasSubjectId = await _columnExists(
      db,
      DatabaseTables.downloadedMaterials,
      'subject_id',
    );

    if (!hasSubjectId) {
      await db.execute('''
        ALTER TABLE ${DatabaseTables.downloadedMaterials}
        ADD COLUMN subject_id INTEGER
        ''');
    }

    final bool hasSubjectName = await _columnExists(
      db,
      DatabaseTables.downloadedMaterials,
      'subject_name',
    );

    if (!hasSubjectName) {
      await db.execute('''
        ALTER TABLE ${DatabaseTables.downloadedMaterials}
        ADD COLUMN subject_name TEXT
        ''');
    }

    final bool hasCourse = await _columnExists(
      db,
      DatabaseTables.downloadedMaterials,
      'course',
    );

    if (!hasCourse) {
      await db.execute('''
        ALTER TABLE ${DatabaseTables.downloadedMaterials}
        ADD COLUMN course TEXT
        ''');
    }

    final bool hasDepartment = await _columnExists(
      db,
      DatabaseTables.downloadedMaterials,
      'department',
    );

    if (!hasDepartment) {
      await db.execute('''
        ALTER TABLE ${DatabaseTables.downloadedMaterials}
        ADD COLUMN department TEXT
        ''');
    }

    await db.execute('''
      CREATE INDEX IF NOT EXISTS
      idx_downloaded_materials_user_subject
      ON ${DatabaseTables.downloadedMaterials}
      (
        user_id,
        subject_id
      )
      ''');
  }

  static Future<void> _migrationToVersion5(Database db) async {
    if (!await _tableExists(db, DatabaseTables.downloadedMaterials)) {
      return;
    }

    final bool hasUniversity = await _columnExists(
      db,
      DatabaseTables.downloadedMaterials,
      'university',
    );

    if (!hasUniversity) {
      await db.execute('''
        ALTER TABLE ${DatabaseTables.downloadedMaterials}
        ADD COLUMN university TEXT
        ''');
    }

    await db.execute('''
      CREATE INDEX IF NOT EXISTS
      idx_downloaded_materials_user_university
      ON ${DatabaseTables.downloadedMaterials}
      (
        user_id,
        university
      )
      ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS
      idx_downloaded_materials_hierarchy
      ON ${DatabaseTables.downloadedMaterials}
      (
        user_id,
        university,
        department,
        course,
        subject_id
      )
      ''');
  }

  static Future<void> _migrationToVersion6(Database db) async {
    await _createVersion6Tables(db);

    await _createVersion6Indexes(db);

    await _migrateDownloadedMaterialsToVersion6(db);

    await _migrateMaterialCacheToVersion6(db);

    await _dropLegacyMaterialTables(db);
  }

  static Future<void> _createVersion6Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseTables.materialFiles} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        local_path TEXT NOT NULL,

        file_hash TEXT,

        size INTEGER,

        mime_type TEXT,

        exists_locally INTEGER NOT NULL DEFAULT 1,

        created_at TEXT NOT NULL,

        updated_at TEXT NOT NULL,

        UNIQUE(local_path)
      )
      ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseTables.materials} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        user_id INTEGER NOT NULL,

        source TEXT NOT NULL,

        remote_key TEXT,

        remote_id INTEGER,

        subject_id INTEGER,

        group_id INTEGER,

        university TEXT,

        department TEXT,

        course TEXT,

        subject_name TEXT,

        original_name TEXT NOT NULL,

        file_id INTEGER,

        remote_version INTEGER,

        remote_status TEXT,

        is_available_remote INTEGER NOT NULL DEFAULT 0,

        is_personal INTEGER NOT NULL DEFAULT 0,

        created_at TEXT NOT NULL,

        updated_at TEXT NOT NULL,

        last_synced_at TEXT,

        FOREIGN KEY(file_id)
          REFERENCES ${DatabaseTables.materialFiles}(id)
          ON DELETE SET NULL,

        CHECK(
          source IN (
            'local',
            'public',
            'teacher',
            'group'
          )
        ),

        CHECK(
          is_available_remote IN (
            0,
            1
          )
        ),

        CHECK(
          is_personal IN (
            0,
            1
          )
        ),

        UNIQUE(
          user_id,
          remote_key
        )
      )
      ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseTables.materialDownloads} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        user_id INTEGER NOT NULL,

        material_id INTEGER NOT NULL,

        status TEXT NOT NULL DEFAULT 'pending',

        temp_path TEXT,

        expected_hash TEXT,

        expected_size INTEGER,

        downloaded_bytes INTEGER NOT NULL DEFAULT 0,

        started_at TEXT,

        completed_at TEXT,

        error_message TEXT,

        FOREIGN KEY(material_id)
          REFERENCES ${DatabaseTables.materials}(id)
          ON DELETE CASCADE,

        CHECK(
          status IN (
            'pending',
            'downloading',
            'verifying',
            'completed',
            'failed'
          )
        )
      )
      ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseTables.materialSyncState} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,

        user_id INTEGER NOT NULL UNIQUE,

        last_manifest_at TEXT,

        last_successful_sync_at TEXT,

        updated_at TEXT NOT NULL
      )
      ''');
  }

  static Future<void> _createVersion6Indexes(Database db) async {
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS
      idx_material_files_hash
      ON ${DatabaseTables.materialFiles}(
        file_hash
      )
      WHERE file_hash IS NOT NULL
      ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS
      idx_materials_user
      ON ${DatabaseTables.materials}(
        user_id
      )
      ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS
      idx_materials_user_source
      ON ${DatabaseTables.materials}(
        user_id,
        source
      )
      ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS
      idx_materials_user_subject
      ON ${DatabaseTables.materials}(
        user_id,
        subject_id
      )
      ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS
      idx_materials_user_group
      ON ${DatabaseTables.materials}(
        user_id,
        group_id
      )
      ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS
      idx_materials_remote_id
      ON ${DatabaseTables.materials}(
        source,
        remote_id
      )
      ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS
      idx_materials_file_id
      ON ${DatabaseTables.materials}(
        file_id
      )
      ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS
      idx_materials_available_remote
      ON ${DatabaseTables.materials}(
        user_id,
        is_available_remote
      )
      ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS
      idx_material_downloads_user_status
      ON ${DatabaseTables.materialDownloads}(
        user_id,
        status
      )
      ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS
      idx_material_downloads_material
      ON ${DatabaseTables.materialDownloads}(
        material_id
      )
      ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS
      idx_material_sync_state_user
      ON ${DatabaseTables.materialSyncState}(
        user_id
      )
      ''');
  }

  static Future<void> _migrateDownloadedMaterialsToVersion6(Database db) async {
    final bool downloadedMaterialsExists = await _tableExists(
      db,
      DatabaseTables.downloadedMaterials,
    );

    if (!downloadedMaterialsExists) {
      return;
    }

    final List<Map<String, dynamic>> rows = await db.query(
      DatabaseTables.downloadedMaterials,
    );

    for (final Map<String, dynamic> row in rows) {
      final int? userId = _asInt(row['user_id']);

      final int? materialId = _asInt(row['material_id']);

      final int? groupId = _asInt(row['group_id']);

      final String? originalName = row['original_name']?.toString();

      final String? localPath = row['local_path']?.toString();

      if (userId == null ||
          materialId == null ||
          originalName == null ||
          originalName.isEmpty ||
          localPath == null ||
          localPath.isEmpty) {
        continue;
      }

      final int fileId = await _getOrCreateLegacyMaterialFile(
        db,
        localPath: localPath,
        mimeType: row['mime_type']?.toString(),
        size: _asInt(row['size']),
        createdAt: row['downloaded_at']?.toString(),
      );

      final String remoteKey = 'group:$materialId';

      final String now = DateTime.now().toUtc().toIso8601String();

      await db.insert(DatabaseTables.materials, <String, Object?>{
        'user_id': userId,
        'source': 'group',
        'remote_key': remoteKey,
        'remote_id': materialId,
        'subject_id': _asInt(row['subject_id']),
        'group_id': groupId,
        'university': row['university']?.toString(),
        'department': row['department']?.toString(),
        'course': row['course']?.toString(),
        'subject_name': row['subject_name']?.toString(),
        'original_name': originalName,
        'file_id': fileId,
        'remote_version': 1,
        'remote_status': 'active',
        'is_available_remote': 1,
        'is_personal': 0,
        'created_at': row['downloaded_at']?.toString() ?? now,
        'updated_at': now,
        'last_synced_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  static Future<void> _migrateMaterialCacheToVersion6(Database db) async {
    if (!await _tableExists(db, DatabaseTables.materialCache)) {
      return;
    }

    final List<Map<String, dynamic>> rows = await db.query(
      DatabaseTables.materialCache,
    );

    final String now = DateTime.now().toUtc().toIso8601String();

    for (final Map<String, dynamic> row in rows) {
      final int? userId = _asInt(row['user_id']);

      final int? materialId = _asInt(row['material_id']);

      final int? groupId = _asInt(row['group_id']);

      if (userId == null || materialId == null || groupId == null) {
        continue;
      }

      final String originalName = row['original_name']?.toString().trim() ?? '';

      final String remoteKey = 'group:$materialId';

      await db.insert(DatabaseTables.materials, <String, Object?>{
        'user_id': userId,
        'source': 'group',
        'remote_key': remoteKey,
        'remote_id': materialId,
        'group_id': groupId,
        'original_name': originalName.isEmpty
            ? 'material_$materialId'
            : originalName,
        'remote_version': 1,
        'remote_status': 'active',
        'is_available_remote': 1,
        'is_personal': 0,
        'created_at': row['created_at']?.toString() ?? now,
        'updated_at': row['synced_at']?.toString() ?? now,
        'last_synced_at': row['synced_at']?.toString() ?? now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  static Future<void> _dropLegacyMaterialTables(Database db) async {
    if (await _tableExists(db, DatabaseTables.materialCache)) {
      await db.execute('DROP TABLE ${DatabaseTables.materialCache}');
    }

    if (await _tableExists(db, DatabaseTables.downloadedMaterials)) {
      await db.execute('DROP TABLE ${DatabaseTables.downloadedMaterials}');
    }
  }

  static Future<int> _getOrCreateLegacyMaterialFile(
    Database db, {
    required String localPath,
    String? mimeType,
    int? size,
    String? createdAt,
  }) async {
    final List<Map<String, dynamic>> existing = await db.query(
      DatabaseTables.materialFiles,
      columns: <String>['id'],
      where: 'local_path = ?',
      whereArgs: <Object?>[localPath],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      return _asInt(existing.first['id']) ?? 0;
    }

    final String now = DateTime.now().toUtc().toIso8601String();

    return db.insert(DatabaseTables.materialFiles, <String, Object?>{
      'local_path': localPath,
      'file_hash': null,
      'size': size,
      'mime_type': mimeType,
      'exists_locally': 1,
      'created_at': createdAt ?? now,
      'updated_at': now,
    });
  }

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  static Future<bool> _columnExists(
    Database db,
    String table,
    String column,
  ) async {
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      PRAGMA table_info($table)
      ''');

    for (final Map<String, dynamic> row in result) {
      final String? name = row['name']?.toString();

      if (name == column) {
        return true;
      }
    }

    return false;
  }

  static Future<bool> _tableExists(Database db, String table) async {
    final List<Map<String, dynamic>> result = await db.rawQuery(
      '''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table'
        AND name = ?
      LIMIT 1
      ''',
      <Object?>[table],
    );

    return result.isNotEmpty;
  }

  static Future<void> _migrationToVersion7(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseTables.localFileBlobs} (
        path TEXT PRIMARY KEY,
        file_name TEXT NOT NULL,
        mime_type TEXT,
        data BLOB NOT NULL,
        size INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS
      idx_local_file_blobs_updated
      ON ${DatabaseTables.localFileBlobs}(updated_at)
      ''');
  }

  static Future<void> _migrationToVersion8(Database db) async {
    await createQuizSchema(db);
  }

  static Future<void> createQuizSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseTables.quizAttempts} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL DEFAULT 0,
        mode TEXT NOT NULL DEFAULT 'free',
        department TEXT NOT NULL,
        course TEXT NOT NULL,
        subject TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'in_progress',
        total_questions INTEGER NOT NULL DEFAULT 0,
        correct_count INTEGER NOT NULL DEFAULT 0,
        wrong_count INTEGER NOT NULL DEFAULT 0,
        unanswered_count INTEGER NOT NULL DEFAULT 0,
        is_hidden_from_history INTEGER NOT NULL DEFAULT 0,
        study_source_key TEXT,
        started_at TEXT NOT NULL,
        completed_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        CHECK(status IN ('in_progress','completed','abandoned')),
        CHECK(is_hidden_from_history IN (0,1))
      )
      ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseTables.quizAttemptAnswers} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        attempt_id INTEGER NOT NULL,
        question_id TEXT NOT NULL,
        argument TEXT,
        question_text TEXT NOT NULL,
        selected_option_id TEXT,
        selected_option_text TEXT,
        correct_option_id TEXT,
        correct_option_text TEXT,
        formal_explanation TEXT,
        informal_explanation TEXT,
        question_response_explanation TEXT,
        selected_answer_explanation TEXT,
        correct_answer_explanation TEXT,
        is_correct INTEGER,
        response_time_seconds INTEGER,
        answered_at TEXT NOT NULL,
        FOREIGN KEY(attempt_id) REFERENCES ${DatabaseTables.quizAttempts}(id) ON DELETE CASCADE,
        CHECK(is_correct IS NULL OR is_correct IN (0,1)),
        UNIQUE(attempt_id, question_id)
      )
      ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_quiz_attempts_user_status ON ${DatabaseTables.quizAttempts}(user_id, status)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_quiz_attempts_user_history ON ${DatabaseTables.quizAttempts}(user_id, is_hidden_from_history, completed_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_quiz_attempts_subject ON ${DatabaseTables.quizAttempts}(user_id, department, course, subject)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_quiz_answers_attempt ON ${DatabaseTables.quizAttemptAnswers}(attempt_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_quiz_answers_question ON ${DatabaseTables.quizAttemptAnswers}(question_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_quiz_answers_argument ON ${DatabaseTables.quizAttemptAnswers}(argument)',
    );
  }

  static Future<void> _migrationToVersion9(Database db) async {
    if (await _tableExists(db, DatabaseTables.quizAttempts) &&
        !await _columnExists(
          db,
          DatabaseTables.quizAttempts,
          'study_source_key',
        )) {
      await db.execute('''
        ALTER TABLE ${DatabaseTables.quizAttempts}
        ADD COLUMN study_source_key TEXT
        ''');
    }
    await createStudyPlanSchema(db);
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_quiz_attempts_study_source ON ${DatabaseTables.quizAttempts}(study_source_key)',
    );
  }

  static Future<void> createStudyPlanSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseTables.studyPlanSources} (
        source_key TEXT PRIMARY KEY,
        session_uuid TEXT NOT NULL UNIQUE,
        device_id TEXT NOT NULL,
        remote_user_id INTEGER,
        source_type TEXT NOT NULL,
        display_label TEXT,
        contribution_enabled INTEGER NOT NULL DEFAULT 1,
        claimed_by_user_id INTEGER,
        is_current_device INTEGER NOT NULL DEFAULT 1,
        sync_state TEXT NOT NULL DEFAULT 'local',
        created_at TEXT NOT NULL,
        last_activity_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        CHECK(source_type IN ('guest','authenticated')),
        CHECK(contribution_enabled IN (0,1)),
        CHECK(is_current_device IN (0,1)),
        CHECK(sync_state IN ('local','pending','synced','error'))
      )
      ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseTables.studyPlanItems} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_key TEXT NOT NULL UNIQUE,
        department TEXT NOT NULL,
        course TEXT NOT NULL,
        subject TEXT NOT NULL,
        argument TEXT,
        question_id TEXT NOT NULL,
        question_text TEXT NOT NULL DEFAULT '',
        correct_option_id TEXT,
        correct_option_text TEXT,
        formal_explanation TEXT,
        informal_explanation TEXT,
        correct_answer_explanation TEXT,
        first_seen_at TEXT NOT NULL,
        last_seen_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseTables.studyPlanContributions} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contribution_uuid TEXT NOT NULL UNIQUE,
        item_id INTEGER NOT NULL,
        source_key TEXT NOT NULL,
        correct_count INTEGER NOT NULL DEFAULT 0,
        wrong_count INTEGER NOT NULL DEFAULT 0,
        unanswered_count INTEGER NOT NULL DEFAULT 0,
        review_count INTEGER NOT NULL DEFAULT 0,
        last_is_correct INTEGER,
        last_selected_option_id TEXT,
        last_selected_option_text TEXT,
        last_selected_answer_explanation TEXT,
        first_seen_at TEXT NOT NULL,
        last_answered_at TEXT,
        client_revision INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(item_id) REFERENCES ${DatabaseTables.studyPlanItems}(id) ON DELETE CASCADE,
        FOREIGN KEY(source_key) REFERENCES ${DatabaseTables.studyPlanSources}(source_key) ON DELETE CASCADE,
        CHECK(last_is_correct IS NULL OR last_is_correct IN (0,1)),
        UNIQUE(item_id, source_key)
      )
      ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseTables.studyPlanProgress} (
        item_id INTEGER PRIMARY KEY,
        total_answers INTEGER NOT NULL DEFAULT 0,
        correct_count INTEGER NOT NULL DEFAULT 0,
        wrong_count INTEGER NOT NULL DEFAULT 0,
        unanswered_count INTEGER NOT NULL DEFAULT 0,
        review_count INTEGER NOT NULL DEFAULT 0,
        source_count INTEGER NOT NULL DEFAULT 0,
        mastery_percentage REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'review',
        last_reviewed_at TEXT,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(item_id) REFERENCES ${DatabaseTables.studyPlanItems}(id) ON DELETE CASCADE,
        CHECK(status IN ('review','improving','consolidated'))
      )
      ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_study_sources_user ON ${DatabaseTables.studyPlanSources}(remote_user_id, contribution_enabled)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_study_sources_device ON ${DatabaseTables.studyPlanSources}(device_id, last_activity_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_study_items_subject ON ${DatabaseTables.studyPlanItems}(department, course, subject)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_study_items_argument ON ${DatabaseTables.studyPlanItems}(argument)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_study_contributions_item ON ${DatabaseTables.studyPlanContributions}(item_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_study_contributions_source ON ${DatabaseTables.studyPlanContributions}(source_key)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_study_progress_status ON ${DatabaseTables.studyPlanProgress}(status, mastery_percentage)',
    );
  }

  static Future<void> _migrationToVersion10(Database db) async {
    if (!await _columnExists(db, DatabaseTables.materials, 'cloud_policy')) {
      await db.execute(
        'ALTER TABLE ${DatabaseTables.materials} ADD COLUMN cloud_policy TEXT',
      );
    }
    if (!await _columnExists(
      db,
      DatabaseTables.materials,
      'cloud_expires_at',
    )) {
      await db.execute(
        'ALTER TABLE ${DatabaseTables.materials} ADD COLUMN cloud_expires_at TEXT',
      );
    }
    if (!await _columnExists(
      db,
      DatabaseTables.materials,
      'retention_status',
    )) {
      await db.execute(
        'ALTER TABLE ${DatabaseTables.materials} ADD COLUMN retention_status TEXT',
      );
    }
    if (!await _columnExists(
      db,
      DatabaseTables.materials,
      'shared_by_user_id',
    )) {
      await db.execute(
        'ALTER TABLE ${DatabaseTables.materials} ADD COLUMN shared_by_user_id INTEGER',
      );
    }
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_materials_cloud_expiry ON ${DatabaseTables.materials}(cloud_expires_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_materials_retention_status ON ${DatabaseTables.materials}(retention_status)',
    );
  }

  static Future<void> _migrationToVersion11(Database db) async {
    await _ensureLocalFileBlobSchema(db);
  }

  static Future<void> _migrationToVersion12(Database db) async {
    // Version 12 is a non-destructive consolidation migration.
    // Development databases may already report version 11 even if the
    // corresponding migration was not executed. These idempotent checks
    // repair that state without deleting local user data.
    await _ensureLocalFileBlobSchema(db);

    if (await _tableExists(db, DatabaseTables.materials)) {
      if (!await _columnExists(db, DatabaseTables.materials, 'cloud_policy')) {
        await db.execute(
          'ALTER TABLE ${DatabaseTables.materials} ADD COLUMN cloud_policy TEXT',
        );
      }

      if (!await _columnExists(
        db,
        DatabaseTables.materials,
        'cloud_expires_at',
      )) {
        await db.execute(
          'ALTER TABLE ${DatabaseTables.materials} ADD COLUMN cloud_expires_at TEXT',
        );
      }

      if (!await _columnExists(
        db,
        DatabaseTables.materials,
        'retention_status',
      )) {
        await db.execute(
          'ALTER TABLE ${DatabaseTables.materials} ADD COLUMN retention_status TEXT',
        );
      }

      if (!await _columnExists(
        db,
        DatabaseTables.materials,
        'shared_by_user_id',
      )) {
        await db.execute(
          'ALTER TABLE ${DatabaseTables.materials} ADD COLUMN shared_by_user_id INTEGER',
        );
      }

      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_materials_cloud_expiry ON ${DatabaseTables.materials}(cloud_expires_at)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_materials_retention_status ON ${DatabaseTables.materials}(retention_status)',
      );
    }

    await createQuizSchema(db);
    await createStudyPlanSchema(db);
  }

  // Additive: legacy materials stay in the degree course with no folders.
  // Never rebuild or clear materials/material_files during this migration.
  static Future<void> _migrationToVersion13(Database db) async {
    if (!await _columnExists(db, DatabaseTables.materials, 'course_scope')) {
      await db.execute("ALTER TABLE ${DatabaseTables.materials} ADD COLUMN course_scope TEXT NOT NULL DEFAULT 'degree'");
    }
    if (!await _columnExists(db, DatabaseTables.materials, 'path_segments_json')) {
      await db.execute('ALTER TABLE ${DatabaseTables.materials} ADD COLUMN path_segments_json TEXT');
    }
    if (!await _columnExists(db, DatabaseTables.materials, 'remote_file_hash')) {
      await db.execute('ALTER TABLE ${DatabaseTables.materials} ADD COLUMN remote_file_hash TEXT');
    }
    await db.execute('''
      CREATE TABLE IF NOT EXISTS material_duplicate_preferences (
        user_id INTEGER NOT NULL,
        file_hash TEXT NOT NULL,
        material_id INTEGER NOT NULL REFERENCES materials(id) ON DELETE CASCADE,
        updated_at TEXT NOT NULL,
        PRIMARY KEY(user_id, file_hash)
      )
    ''');

  }

  static Future<void> _ensureLocalFileBlobSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseTables.localFileBlobs} (
        path TEXT PRIMARY KEY,
        file_name TEXT NOT NULL,
        mime_type TEXT,
        data BLOB NOT NULL,
        size INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS
      idx_local_file_blobs_updated
      ON ${DatabaseTables.localFileBlobs}(updated_at)
      ''');
  }
}
