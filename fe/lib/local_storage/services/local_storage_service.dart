import 'package:sqflite_common/sqlite_api.dart';

import '../database/app_database.dart';

import '../database/database_tables.dart';

import '../models/material_local.dart';

import '../repositories/pending_upload_repository.dart';

import 'local_file_service.dart';

class LocalStorageService {
  final AppDatabase _database;

  final PendingUploadRepository _pendingUploadRepository;

  final LocalFileService _fileService;

  LocalStorageService({
    AppDatabase? database,

    PendingUploadRepository? pendingUploadRepository,

    LocalFileService? fileService,
  }) : _database = database ?? AppDatabase.instance,

       _pendingUploadRepository =
           pendingUploadRepository ?? PendingUploadRepository(),

       _fileService = fileService ?? LocalFileService();

  Future<void> initialize({int? userId}) async {
    await _database.database;

    if (userId != null) {
      await _pendingUploadRepository.resetInterruptedUploads(userId);
    }
  }

  Future<void> prepareUserSession(int userId) async {
    await initialize(userId: userId);

    await cleanupMissingDownloadedFiles(userId);

    await cleanupMissingPendingUploadFiles(userId);

    await cleanupOrphanMaterialFiles();
  }

  Future<int> cleanupMissingDownloadedFiles(int userId) async {
    final Database db = await _database.database;

    final List<Map<String, Object?>> rows = await db.rawQuery(
      '''

      SELECT

        m.id AS material_id,

        m.file_id AS file_id,

        f.local_path AS local_path

      FROM ${DatabaseTables.materials} AS m

      INNER JOIN ${DatabaseTables.materialFiles} AS f

        ON f.id = m.file_id

      WHERE m.user_id = ?

        AND m.file_id IS NOT NULL

      ''',

      <Object?>[userId],
    );

    int removed = 0;

    for (final Map<String, Object?> row in rows) {
      final int? materialId = _asInt(row['material_id']);

      final int? fileId = _asInt(row['file_id']);

      final String localPath = row['local_path']?.toString().trim() ?? '';

      if (materialId == null || fileId == null || localPath.isEmpty) {
        continue;
      }

      final bool exists = await _fileService.exists(localPath);

      if (exists) {
        continue;
      }

      await db.transaction((Transaction transaction) async {
        await transaction.update(
          DatabaseTables.materials,

          <String, Object?>{
            'file_id': null,

            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },

          where: 'id = ?',

          whereArgs: <Object?>[materialId],
        );

        await transaction.delete(
          DatabaseTables.materialDownloads,

          where: 'material_id = ?',

          whereArgs: <Object?>[materialId],
        );

        await transaction.update(
          DatabaseTables.materialFiles,

          <String, Object?>{
            'exists_locally': 0,

            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },

          where: 'id = ?',

          whereArgs: <Object?>[fileId],
        );
      });

      await _deletePhysicalFileIfUnused(fileId);

      removed++;
    }

    return removed;
  }

  Future<int> cleanupMissingPendingUploadFiles(int userId) async {
    final uploads = await _pendingUploadRepository.getByUser(userId);

    int removed = 0;

    for (final upload in uploads) {
      if (upload.isUploaded) {
        continue;
      }

      final bool exists = await _fileService.exists(upload.localPath);

      if (exists) {
        continue;
      }

      if (upload.id != null) {
        await _pendingUploadRepository.delete(upload.id!);

        removed++;
      }
    }

    return removed;
  }

  Future<int> cleanupOrphanMaterialFiles() async {
    final Database db = await _database.database;

    final List<Map<String, Object?>> rows = await db.rawQuery('''

      SELECT

        f.id,

        f.local_path

      FROM ${DatabaseTables.materialFiles} AS f

      LEFT JOIN ${DatabaseTables.materials} AS m

        ON m.file_id = f.id

      WHERE m.id IS NULL

      ''');

    int removed = 0;

    for (final Map<String, Object?> row in rows) {
      final int? fileId = _asInt(row['id']);

      if (fileId == null) {
        continue;
      }

      await _deletePhysicalFileIfUnused(fileId);

      removed++;
    }

    return removed;
  }

  Future<void> clearMaterialCache(int userId) async {
    final Database db = await _database.database;

    await db.transaction((Transaction transaction) async {
      await transaction.update(
        DatabaseTables.materials,

        <String, Object?>{
          'is_available_remote': 0,

          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },

        where:
            'user_id = ? '
            'AND source <> ?',

        whereArgs: <Object?>[userId, MaterialSourceLocal.local.name],
      );

      await transaction.delete(
        DatabaseTables.materialSyncState,

        where: 'user_id = ?',

        whereArgs: <Object?>[userId],
      );
    });
  }

  Future<void> clearGroupMaterialCache({
    required int userId,

    required int groupId,
  }) async {
    final Database db = await _database.database;

    await db.update(
      DatabaseTables.materials,

      <String, Object?>{
        'is_available_remote': 0,

        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },

      where:
          'user_id = ? '
          'AND group_id = ? '
          'AND source = ?',

      whereArgs: <Object?>[userId, groupId, MaterialSourceLocal.group.name],
    );
  }

  Future<int> removeDownloadedMaterials(int userId) async {
    final Database db = await _database.database;

    final List<Map<String, Object?>> rows = await db.query(
      DatabaseTables.materials,

      columns: <String>['id', 'file_id'],

      where:
          'user_id = ? '
          'AND file_id IS NOT NULL '
          'AND source <> ?',

      whereArgs: <Object?>[userId, MaterialSourceLocal.local.name],
    );

    int removed = 0;

    for (final Map<String, Object?> row in rows) {
      final int? materialId = _asInt(row['id']);

      final int? fileId = _asInt(row['file_id']);

      if (materialId == null || fileId == null) {
        continue;
      }

      await db.transaction((Transaction transaction) async {
        await transaction.update(
          DatabaseTables.materials,

          <String, Object?>{
            'file_id': null,

            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },

          where: 'id = ?',

          whereArgs: <Object?>[materialId],
        );

        await transaction.delete(
          DatabaseTables.materialDownloads,

          where: 'material_id = ?',

          whereArgs: <Object?>[materialId],
        );
      });

      await _deletePhysicalFileIfUnused(fileId);

      removed++;
    }

    return removed;
  }

  Future<int> removeDownloadedMaterialsByGroup({
    required int userId,

    required int groupId,
  }) async {
    final Database db = await _database.database;

    final List<Map<String, Object?>> rows = await db.query(
      DatabaseTables.materials,

      columns: <String>['id', 'file_id'],

      where:
          'user_id = ? '
          'AND group_id = ? '
          'AND source = ? '
          'AND file_id IS NOT NULL',

      whereArgs: <Object?>[userId, groupId, MaterialSourceLocal.group.name],
    );

    int removed = 0;

    for (final Map<String, Object?> row in rows) {
      final int? materialId = _asInt(row['id']);

      final int? fileId = _asInt(row['file_id']);

      if (materialId == null || fileId == null) {
        continue;
      }

      await db.transaction((Transaction transaction) async {
        await transaction.update(
          DatabaseTables.materials,

          <String, Object?>{
            'file_id': null,

            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },

          where: 'id = ?',

          whereArgs: <Object?>[materialId],
        );

        await transaction.delete(
          DatabaseTables.materialDownloads,

          where: 'material_id = ?',

          whereArgs: <Object?>[materialId],
        );
      });

      await _deletePhysicalFileIfUnused(fileId);

      removed++;
    }

    return removed;
  }

  Future<int> removePendingUploads(int userId) async {
    final uploads = await _pendingUploadRepository.getByUser(userId);

    int removed = 0;

    for (final upload in uploads) {
      if (upload.isUploaded) {
        continue;
      }

      try {
        await _fileService.delete(upload.localPath);
      } finally {
        if (upload.id != null) {
          await _pendingUploadRepository.delete(upload.id!);

          removed++;
        }
      }
    }

    return removed;
  }

  Future<int> clearUploadedHistory(int userId) async {
    return _pendingUploadRepository.deleteUploaded(userId);
  }

  Future<void> onLogout(int userId) async {
    await _pendingUploadRepository.resetInterruptedUploads(userId);
  }

  Future<void> clearUserLocalData(int userId) async {
    final Database db = await _database.database;

    final List<Map<String, Object?>> materialRows = await db.query(
      DatabaseTables.materials,

      columns: <String>['id', 'file_id'],

      where: 'user_id = ?',

      whereArgs: <Object?>[userId],
    );

    final Set<int> fileIds = <int>{};

    for (final Map<String, Object?> row in materialRows) {
      final int? fileId = _asInt(row['file_id']);

      if (fileId != null) {
        fileIds.add(fileId);
      }
    }

    final uploads = await _pendingUploadRepository.getByUser(userId);

    for (final upload in uploads) {
      await _fileService.delete(upload.localPath);
    }

    await db.transaction((Transaction transaction) async {
      final List<Map<String, Object?>> materialIds = await transaction.query(
        DatabaseTables.materials,

        columns: <String>['id'],

        where: 'user_id = ?',

        whereArgs: <Object?>[userId],
      );

      for (final Map<String, Object?> row in materialIds) {
        final int? materialId = _asInt(row['id']);

        if (materialId == null) {
          continue;
        }

        await transaction.delete(
          DatabaseTables.materialDownloads,

          where: 'material_id = ?',

          whereArgs: <Object?>[materialId],
        );
      }

      await transaction.delete(
        DatabaseTables.materials,

        where: 'user_id = ?',

        whereArgs: <Object?>[userId],
      );

      await transaction.delete(
        DatabaseTables.materialSyncState,

        where: 'user_id = ?',

        whereArgs: <Object?>[userId],
      );

      await transaction.delete(
        DatabaseTables.pendingUploads,

        where: 'user_id = ?',

        whereArgs: <Object?>[userId],
      );
    });

    for (final int fileId in fileIds) {
      await _deletePhysicalFileIfUnused(fileId);
    }

    await _fileService.deleteUserFiles(userId);
  }

  Future<LocalStorageStats> getStats(int userId) async {
    final Database db = await _database.database;

    final List<Map<String, Object?>> downloadRows = await db.rawQuery(
      '''
      SELECT
        COUNT(DISTINCT m.id) AS count,
        COALESCE(
          (
            SELECT SUM(files.size)
            FROM ${DatabaseTables.materialFiles} AS files
            WHERE files.id IN (
              SELECT DISTINCT downloaded.file_id
              FROM ${DatabaseTables.materials} AS downloaded
              WHERE downloaded.user_id = ?
                AND downloaded.source <> ?
                AND downloaded.file_id IS NOT NULL
            )
              AND files.exists_locally = 1
          ),
          0
        ) AS bytes
      FROM ${DatabaseTables.materials} AS m
      INNER JOIN ${DatabaseTables.materialFiles} AS f
        ON f.id = m.file_id
      WHERE m.user_id = ?
        AND m.source <> ?
        AND f.exists_locally = 1
      ''',
      <Object?>[
        userId,
        MaterialSourceLocal.local.name,
        userId,
        MaterialSourceLocal.local.name,
      ],
    );

    final int downloadedCount =
        _asInt(downloadRows.isEmpty ? null : downloadRows.first['count']) ?? 0;

    final int downloadedBytes =
        _asInt(downloadRows.isEmpty ? null : downloadRows.first['bytes']) ?? 0;

    final List<Map<String, Object?>> cacheRows = await db.rawQuery(
      '''

      SELECT COUNT(*) AS count

      FROM ${DatabaseTables.materials}

      WHERE user_id = ?

        AND source <> ?

        AND is_available_remote = 1

      ''',

      <Object?>[userId, MaterialSourceLocal.local.name],
    );

    final int cachedMaterialCount =
        _asInt(cacheRows.isEmpty ? null : cacheRows.first['count']) ?? 0;

    final uploads = await _pendingUploadRepository.getByUser(userId);

    int pendingBytes = 0;

    int pendingCount = 0;

    int failedCount = 0;

    for (final upload in uploads) {
      if (upload.isPending || upload.isUploading) {
        pendingCount++;

        pendingBytes += upload.size ?? 0;
      }

      if (upload.isFailed) {
        failedCount++;
      }
    }

    return LocalStorageStats(
      downloadedCount: downloadedCount,

      downloadedBytes: downloadedBytes,

      cachedMaterialCount: cachedMaterialCount,

      pendingUploadCount: pendingCount,

      pendingUploadBytes: pendingBytes,

      failedUploadCount: failedCount,
    );
  }

  Future<void> close() async {
    await _database.close();
  }

  Future<void> _deletePhysicalFileIfUnused(int fileId) async {
    final Database db = await _database.database;

    String? localPath;

    await db.transaction((Transaction transaction) async {
      final List<Map<String, Object?>> references = await transaction.rawQuery(
        '''

          SELECT COUNT(*) AS count

          FROM ${DatabaseTables.materials}

          WHERE file_id = ?

          ''',

        <Object?>[fileId],
      );

      final int referenceCount =
          _asInt(references.isEmpty ? null : references.first['count']) ?? 0;

      if (referenceCount > 0) {
        return;
      }

      final List<Map<String, Object?>> fileRows = await transaction.query(
        DatabaseTables.materialFiles,

        columns: <String>['local_path'],

        where: 'id = ?',

        whereArgs: <Object?>[fileId],

        limit: 1,
      );

      if (fileRows.isNotEmpty) {
        localPath = fileRows.first['local_path']?.toString();
      }

      await transaction.delete(
        DatabaseTables.materialFiles,

        where: 'id = ?',

        whereArgs: <Object?>[fileId],
      );
    });

    if (localPath != null && localPath!.trim().isNotEmpty) {
      await _fileService.delete(localPath!);
    }
  }

  static int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }
}

class LocalStorageStats {
  final int downloadedCount;

  final int downloadedBytes;

  final int cachedMaterialCount;

  final int pendingUploadCount;

  final int pendingUploadBytes;

  final int failedUploadCount;

  const LocalStorageStats({
    required this.downloadedCount,

    required this.downloadedBytes,

    required this.cachedMaterialCount,

    required this.pendingUploadCount,

    required this.pendingUploadBytes,

    required this.failedUploadCount,
  });

  bool get hasDownloads {
    return downloadedCount > 0;
  }

  bool get hasPendingUploads {
    return pendingUploadCount > 0;
  }

  bool get hasFailedUploads {
    return failedUploadCount > 0;
  }

  int get totalTrackedItems {
    return downloadedCount +
        cachedMaterialCount +
        pendingUploadCount +
        failedUploadCount;
  }

  double get downloadedMegabytes {
    return downloadedBytes / (1024 * 1024);
  }

  double get pendingMegabytes {
    return pendingUploadBytes / (1024 * 1024);
  }
}
