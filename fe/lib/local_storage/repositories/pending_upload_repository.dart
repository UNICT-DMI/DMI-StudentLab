import 'package:sqflite_common/sqlite_api.dart';

import '../database/app_database.dart';
import '../database/database_tables.dart';

import '../models/pending_upload_local.dart';


class PendingUploadRepository {
  final AppDatabase _database =
      AppDatabase.instance;


  Future<int> insert(
    PendingUploadLocal upload,
  ) async {
    final Database db =
        await _database.database;

    return db.insert(
      DatabaseTables.pendingUploads,
      upload.toMap(),
    );
  }


  Future<void> update(
    PendingUploadLocal upload,
  ) async {
    if (upload.id == null) {
      throw ArgumentError(
        'Impossibile aggiornare un upload senza id.',
      );
    }

    final Database db =
        await _database.database;

    await db.update(
      DatabaseTables.pendingUploads,
      upload.toMap(),
      where:
          'id = ?',
      whereArgs: <Object?>[
        upload.id,
      ],
    );
  }


  Future<PendingUploadLocal?> getById(
    int id,
  ) async {
    final Database db =
        await _database.database;

    final List<Map<String, Object?>>
        result =
        await db.query(
      DatabaseTables.pendingUploads,
      where:
          'id = ?',
      whereArgs: <Object?>[
        id,
      ],
      limit:
          1,
    );

    if (result.isEmpty) {
      return null;
    }

    return PendingUploadLocal.fromMap(
      result.first,
    );
  }


  Future<List<PendingUploadLocal>>
      getByUser(
    int userId,
  ) async {
    final Database db =
        await _database.database;

    final List<Map<String, Object?>>
        result =
        await db.query(
      DatabaseTables.pendingUploads,
      where:
          'user_id = ?',
      whereArgs: <Object?>[
        userId,
      ],
      orderBy:
          'created_at DESC, id DESC',
    );

    return result
        .map(
          PendingUploadLocal.fromMap,
        )
        .toList();
  }


  Future<List<PendingUploadLocal>>
      getByGroup({
    required int userId,
    required int groupId,
  }) async {
    final Database db =
        await _database.database;

    final List<Map<String, Object?>>
        result =
        await db.query(
      DatabaseTables.pendingUploads,
      where:
          'user_id = ? AND group_id = ?',
      whereArgs: <Object?>[
        userId,
        groupId,
      ],
      orderBy:
          'created_at DESC, id DESC',
    );

    return result
        .map(
          PendingUploadLocal.fromMap,
        )
        .toList();
  }


  Future<List<PendingUploadLocal>>
      getByStatus({
    required int userId,
    required PendingUploadStatus status,
  }) async {
    final Database db =
        await _database.database;

    final List<Map<String, Object?>>
        result =
        await db.query(
      DatabaseTables.pendingUploads,
      where:
          'user_id = ? AND status = ?',
      whereArgs: <Object?>[
        userId,
        status.name,
      ],
      orderBy:
          'created_at ASC, id ASC',
    );

    return result
        .map(
          PendingUploadLocal.fromMap,
        )
        .toList();
  }


  Future<List<PendingUploadLocal>>
      getPending(
    int userId,
  ) {
    return getByStatus(
      userId:
          userId,
      status:
          PendingUploadStatus.pending,
    );
  }


  Future<List<PendingUploadLocal>>
      getFailed(
    int userId,
  ) {
    return getByStatus(
      userId:
          userId,
      status:
          PendingUploadStatus.failed,
    );
  }


  Future<List<PendingUploadLocal>>
      getWaitingForSync(
    int userId,
  ) async {
    final Database db =
        await _database.database;

    final List<Map<String, Object?>>
        result =
        await db.query(
      DatabaseTables.pendingUploads,
      where:
          '''
          user_id = ?
          AND status IN (?, ?)
          ''',
      whereArgs: <Object?>[
        userId,
        PendingUploadStatus.pending.name,
        PendingUploadStatus.failed.name,
      ],
      orderBy:
          'created_at ASC, id ASC',
    );

    return result
        .map(
          PendingUploadLocal.fromMap,
        )
        .toList();
  }


  Future<void> updateStatus({
    required int id,
    required PendingUploadStatus status,
    String? errorMessage,
  }) async {
    final Database db =
        await _database.database;

    final Map<String, Object?> values =
        <String, Object?>{
      'status':
          status.name,
    };

    if (errorMessage != null) {
      values['error_message'] =
          errorMessage;
    } else if (
      status !=
          PendingUploadStatus.failed
    ) {
      values['error_message'] =
          null;
    }

    await db.update(
      DatabaseTables.pendingUploads,
      values,
      where:
          'id = ?',
      whereArgs: <Object?>[
        id,
      ],
    );
  }


  Future<void> markUploading(
    int id,
  ) async {
    final Database db =
        await _database.database;

    final String now =
        DateTime.now()
            .toUtc()
            .toIso8601String();

    await db.rawUpdate(
      '''
      UPDATE ${DatabaseTables.pendingUploads}
      SET
        status = ?,
        retry_count = COALESCE(retry_count, 0) + 1,
        last_attempt_at = ?,
        error_message = NULL,
        uploaded_at = NULL,
        server_material_id = NULL
      WHERE id = ?
      ''',
      <Object?>[
        PendingUploadStatus.uploading.name,
        now,
        id,
      ],
    );
  }


  Future<void> markFailed({
    required int id,
    required String errorMessage,
  }) async {
    final Database db =
        await _database.database;

    await db.update(
      DatabaseTables.pendingUploads,
      <String, Object?>{
        'status':
            PendingUploadStatus.failed.name,
        'error_message':
            errorMessage,
        'uploaded_at':
            null,
        'server_material_id':
            null,
      },
      where:
          'id = ?',
      whereArgs: <Object?>[
        id,
      ],
    );
  }


  Future<void> markUploaded({
    required int id,
    required int serverMaterialId,
  }) async {
    final Database db =
        await _database.database;

    await db.update(
      DatabaseTables.pendingUploads,
      <String, Object?>{
        'status':
            PendingUploadStatus.uploaded.name,
        'uploaded_at':
            DateTime.now()
                .toUtc()
                .toIso8601String(),
        'server_material_id':
            serverMaterialId,
        'error_message':
            null,
      },
      where:
          'id = ?',
      whereArgs: <Object?>[
        id,
      ],
    );
  }


  Future<void> retry(
    int id,
  ) async {
    final Database db =
        await _database.database;

    await db.update(
      DatabaseTables.pendingUploads,
      <String, Object?>{
        'status':
            PendingUploadStatus.pending.name,
        'error_message':
            null,
        'uploaded_at':
            null,
        'server_material_id':
            null,
      },
      where:
          'id = ?',
      whereArgs: <Object?>[
        id,
      ],
    );
  }


  Future<void> delete(
    int id,
  ) async {
    final Database db =
        await _database.database;

    await db.delete(
      DatabaseTables.pendingUploads,
      where:
          'id = ?',
      whereArgs: <Object?>[
        id,
      ],
    );
  }


  Future<int> deleteUploaded(
    int userId,
  ) async {
    final Database db =
        await _database.database;

    return db.delete(
      DatabaseTables.pendingUploads,
      where:
          'user_id = ? AND status = ?',
      whereArgs: <Object?>[
        userId,
        PendingUploadStatus.uploaded.name,
      ],
    );
  }


  Future<int> countWaiting(
    int userId,
  ) async {
    final Database db =
        await _database.database;

    final List<Map<String, Object?>>
        result =
        await db.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM ${DatabaseTables.pendingUploads}
      WHERE user_id = ?
      AND status IN (?, ?)
      ''',
      <Object?>[
        userId,
        PendingUploadStatus.pending.name,
        PendingUploadStatus.failed.name,
      ],
    );

    if (result.isEmpty) {
      return 0;
    }

    return _asInt(
          result.first['total'],
        ) ??
        0;
  }


  Future<void> resetInterruptedUploads(
    int userId,
  ) async {
    final Database db =
        await _database.database;

    await db.update(
      DatabaseTables.pendingUploads,
      <String, Object?>{
        'status':
            PendingUploadStatus.pending.name,
        'error_message':
            null,
        'uploaded_at':
            null,
        'server_material_id':
            null,
      },
      where:
          'user_id = ? AND status = ?',
      whereArgs: <Object?>[
        userId,
        PendingUploadStatus.uploading.name,
      ],
    );
  }


  static int? _asInt(
    Object? value,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ??
          '',
    );
  }
}