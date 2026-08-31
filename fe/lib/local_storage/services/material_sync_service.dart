import 'package:sqflite_common/sqlite_api.dart';

import '../../services/api_service.dart';

import '../database/app_database.dart';

import '../database/database_tables.dart';

import '../models/material_local.dart';

import '../models/pending_upload_local.dart';

import 'local_file_service.dart';

import 'pending_upload_service.dart';

enum MaterialSyncSource { backend, local }

class MaterialSyncService {

  final ApiService _apiService;

  final AppDatabase _database;

  final PendingUploadService _pendingUploadService;

  final LocalFileService _fileService;

  MaterialSyncService({

    ApiService? apiService,

    AppDatabase? database,

    PendingUploadService? pendingUploadService,

    LocalFileService? fileService,

  }) : _apiService = apiService ?? ApiService(),

       _database = database ?? AppDatabase.instance,

       _pendingUploadService = pendingUploadService ?? PendingUploadService(),

       _fileService = fileService ?? LocalFileService();

  Future<MaterialManifestSyncResult> syncMaterials({

    required int userId,

    bool forceFull = false,

  }) async {

    final DateTime? since = forceFull ? null : await _getLastManifestAt(userId);

    final Map<String, dynamic> manifest = await _apiService

        .getMaterialSyncManifest(since: since);

    final DateTime generatedAt =

        _parseDateTime(manifest['generated_at']) ?? DateTime.now().toUtc();

    final List<String> visibleKeys = _parseVisibleKeys(

      manifest['visible_keys'],

    );

    final List<Map<String, dynamic>> items = _parseItems(manifest['items']);

    final bool incremental = manifest['incremental'] == true;

    final _ManifestApplyResult applyResult = await _applyManifest(

      userId: userId,

      generatedAt: generatedAt,

      visibleKeys: visibleKeys.toSet(),

      items: items,

      fullSync: !incremental,

    );

    for (final int fileId in applyResult.detachedFileIds) {

      await _deletePhysicalFileIfUnused(fileId);

    }

    await _purgeUnavailableRemoteFiles(userId);

    await _purgeUnavailableRemoteRecords(userId);

    return MaterialManifestSyncResult(

      userId: userId,

      generatedAt: generatedAt,

      since: since,

      incremental: incremental,

      visibleKeys: visibleKeys,

      changedCount: applyResult.changedCount,

    );

  }

  Future<GroupMaterialSyncResult> syncGroup({

    required int userId,

    required int groupId,

  }) async {

    final List<PendingUploadLocal> uploadResults = <PendingUploadLocal>[];

    String? uploadError;

    try {

      await _pendingUploadService.resetInterruptedUploads(userId);

    } catch (error) {

      uploadError = error.toString();

    }

    try {

      final List<PendingUploadLocal> waiting = await _pendingUploadService

          .getByGroup(userId: userId, groupId: groupId);

      for (final PendingUploadLocal upload in waiting) {

        if (!upload.isPending && !upload.isFailed) {

          continue;

        }

        try {

          final PendingUploadLocal result = await _pendingUploadService.upload(

            upload,

          );

          uploadResults.add(result);

        } catch (error) {

          uploadError = error.toString();

        }

      }

    } catch (error) {

      uploadError = error.toString();

    }

    try {

      final MaterialManifestSyncResult syncResult = await syncMaterials(

        userId: userId,

      );

      final List<MaterialLocal> materials = await _getGroupMaterials(

        userId: userId,

        groupId: groupId,

      );

      return GroupMaterialSyncResult(

        userId: userId,

        groupId: groupId,

        materials: materials,

        uploads: uploadResults,

        source: MaterialSyncSource.backend,

        isOffline: false,

        syncedAt: syncResult.generatedAt,

        uploadError: uploadError,

      );

    } catch (error) {

      final List<MaterialLocal> materials = await _getGroupMaterials(

        userId: userId,

        groupId: groupId,

      );

      return GroupMaterialSyncResult(

        userId: userId,

        groupId: groupId,

        materials: materials,

        uploads: uploadResults,

        source: MaterialSyncSource.local,

        isOffline: true,

        syncedAt: await _getLastSuccessfulSyncAt(userId),

        syncError: error.toString(),

        uploadError: uploadError,

      );

    }

  }

  Future<UserUploadSyncResult> syncUploads(int userId) async {

    await _pendingUploadService.resetInterruptedUploads(userId);

    final List<PendingUploadLocal> results = await _pendingUploadService

        .syncWaiting(userId);

    int uploaded = 0;

    int failed = 0;

    for (final PendingUploadLocal upload in results) {

      if (upload.isUploaded) {

        uploaded++;

      }

      if (upload.isFailed) {

        failed++;

      }

    }

    return UserUploadSyncResult(

      userId: userId,

      uploads: results,

      uploadedCount: uploaded,

      failedCount: failed,

    );

  }

  Future<List<MaterialLocal>> forceRefreshGroup({

    required int userId,

    required int groupId,

  }) async {

    await syncMaterials(userId: userId, forceFull: true);

    return _getGroupMaterials(userId: userId, groupId: groupId);

  }

  Future<GroupLocalMaterialState> getLocalGroupState({

    required int userId,

    required int groupId,

  }) async {

    final List<MaterialLocal> materials = await _getGroupMaterials(

      userId: userId,

      groupId: groupId,

    );

    final List<PendingUploadLocal> uploads = await _pendingUploadService

        .getByGroup(userId: userId, groupId: groupId);

    return GroupLocalMaterialState(

      userId: userId,

      groupId: groupId,

      materials: materials,

      uploads: uploads,

      lastSync: await _getLastSuccessfulSyncAt(userId),

    );

  }

  Future<int> countWaitingUploads(int userId) {

    return _pendingUploadService.countWaiting(userId);

  }

  Future<PendingUploadLocal?> retryUpload(int uploadId) {

    return _pendingUploadService.retry(uploadId);

  }

  Future<void> removeUpload(int uploadId) {

    return _pendingUploadService.remove(uploadId);

  }

  Future<int> clearUploadedHistory(int userId) {

    return _pendingUploadService.clearUploaded(userId);

  }

  Future<void> clearGroupCache({

    required int userId,

    required int groupId,

  }) async {

    final Database db = await _database.database;

    final List<Map<String, Object?>> rows = await db.query(

      DatabaseTables.materials,

      columns: <String>['id', 'file_id'],

      where:

          'user_id = ? AND group_id = ? AND source = ? AND file_id IS NOT NULL',

      whereArgs: <Object?>[userId, groupId, MaterialSourceLocal.group.name],

    );

    final List<int> fileIds = <int>[];

    await db.transaction((Transaction transaction) async {

      for (final Map<String, Object?> row in rows) {

        final int? materialId = _asInt(row['id']);

        final int? fileId = _asInt(row['file_id']);

        if (materialId == null || fileId == null) {

          continue;

        }

        fileIds.add(fileId);

        await transaction.update(

          DatabaseTables.materials,

          <String, Object?>{'file_id': null},

          where: 'id = ?',

          whereArgs: <Object?>[materialId],

        );

        await transaction.delete(

          DatabaseTables.materialDownloads,

          where: 'material_id = ?',

          whereArgs: <Object?>[materialId],

        );

      }

    });

    for (final int fileId in fileIds.toSet()) {

      await _deletePhysicalFileIfUnused(fileId);

    }

  }

  Future<void> clearUserCache(int userId) async {

    final Database db = await _database.database;

    final List<Map<String, Object?>> rows = await db.query(

      DatabaseTables.materials,

      columns: <String>['id', 'file_id'],

      where: 'user_id = ? AND source <> ? AND file_id IS NOT NULL',

      whereArgs: <Object?>[userId, MaterialSourceLocal.local.name],

    );

    final List<int> fileIds = <int>[];

    await db.transaction((Transaction transaction) async {

      for (final Map<String, Object?> row in rows) {

        final int? materialId = _asInt(row['id']);

        final int? fileId = _asInt(row['file_id']);

        if (materialId == null || fileId == null) {

          continue;

        }

        fileIds.add(fileId);

        await transaction.update(

          DatabaseTables.materials,

          <String, Object?>{'file_id': null},

          where: 'id = ?',

          whereArgs: <Object?>[materialId],

        );

        await transaction.delete(

          DatabaseTables.materialDownloads,

          where: 'material_id = ?',

          whereArgs: <Object?>[materialId],

        );

      }

      await transaction.delete(

        DatabaseTables.materialSyncState,

        where: 'user_id = ?',

        whereArgs: <Object?>[userId],

      );

    });

    for (final int fileId in fileIds.toSet()) {

      await _deletePhysicalFileIfUnused(fileId);

    }

  }

  Future<_ManifestApplyResult> _applyManifest({

    required int userId,

    required DateTime generatedAt,

    required Set<String> visibleKeys,

    required List<Map<String, dynamic>> items,

    required bool fullSync,

  }) async {

    final Database db = await _database.database;

    int changedCount = 0;

    final Set<int> detachedFileIds = <int>{};

    await db.transaction((Transaction transaction) async {

      for (final Map<String, dynamic> item in items) {

        final String key = item['key']?.toString().trim() ?? '';

        final MaterialSourceLocal? source = _parseSource(item['source']);

        final int? remoteId = _asInt(item['material_id']);

        if (key.isEmpty ||

            source == null ||

            source == MaterialSourceLocal.local ||

            remoteId == null ||

            remoteId <= 0) {

          continue;

        }

        final int version = _asInt(item['version']) ?? 1;

        final int normalizedVersion = version < 1 ? 1 : version;

        final String status =

            item['status']?.toString().trim().toLowerCase() ?? 'active';

        final bool isActive = _asBool(item['is_active']) ?? false;

        final bool isVisible = _asBool(item['is_visible']) ?? false;

        final bool isTombstone =

            (_asBool(item['is_tombstone']) ?? false) || status == 'removed';

        final bool available =

            !isTombstone && isActive && isVisible && visibleKeys.contains(key);

        final DateTime updatedAt =

            _parseDateTime(item['updated_at']) ?? generatedAt;

        final DateTime? removedAt = _parseDateTime(item['removed_at']);

        final List<Map<String, Object?>> existing = await transaction.query(

          DatabaseTables.materials,

          columns: <String>['id', 'file_id', 'remote_version'],

          where: 'user_id = ? AND remote_key = ?',

          whereArgs: <Object?>[userId, key],

          limit: 1,

        );

        final Map<String, Object?> values = <String, Object?>{

          'user_id': userId,

          'source': source.name,

          'remote_key': key,

          'remote_id': remoteId,

          'subject_id': _asInt(item['subject_id']),

          'group_id': _asInt(item['group_id']),

          'original_name': _nullableString(item['original_name']) ?? key,

          'remote_version': normalizedVersion,

          'remote_status': status,

          'is_available_remote': available ? 1 : 0,

          'is_personal': 0,

          'updated_at':

              (removedAt != null && !available ? removedAt : updatedAt)

                  .toUtc()

                  .toIso8601String(),

          'last_synced_at': generatedAt.toUtc().toIso8601String(),

        };

        _putOptionalString(values, 'university', item, 'university');

        _putOptionalString(values, 'department', item, 'department');

        _putOptionalString(values, 'course', item, 'course');

        _putOptionalString(values, 'subject_name', item, 'subject_name');

        if (existing.isEmpty) {

          values['created_at'] = updatedAt.toUtc().toIso8601String();

          await transaction.insert(DatabaseTables.materials, values);

          changedCount++;

          continue;

        }

        final Map<String, Object?> current = existing.first;

        final int? materialId = _asInt(current['id']);

        if (materialId == null) {

          continue;

        }

        final int currentVersion = _asInt(current['remote_version']) ?? 1;

        final int? currentFileId = _asInt(current['file_id']);

        if (currentFileId != null && currentVersion != normalizedVersion) {

          values['file_id'] = null;

          detachedFileIds.add(currentFileId);

          await transaction.delete(

            DatabaseTables.materialDownloads,

            where: 'material_id = ?',

            whereArgs: <Object?>[materialId],

          );

        }

        await transaction.update(

          DatabaseTables.materials,

          values,

          where: 'id = ?',

          whereArgs: <Object?>[materialId],

        );

        changedCount++;

      }

      if (fullSync) {

        final List<Map<String, Object?>> remoteRows = await transaction.query(

          DatabaseTables.materials,

          columns: <String>['id', 'remote_key'],

          where: 'user_id = ? AND source <> ? AND is_available_remote = 1',

          whereArgs: <Object?>[userId, MaterialSourceLocal.local.name],

        );

        for (final Map<String, Object?> row in remoteRows) {

          final int? materialId = _asInt(row['id']);

          final String key = row['remote_key']?.toString().trim() ?? '';

          if (materialId == null || key.isEmpty || visibleKeys.contains(key)) {

            continue;

          }

          await transaction.update(

            DatabaseTables.materials,

            <String, Object?>{

              'is_available_remote': 0,

              'updated_at': generatedAt.toUtc().toIso8601String(),

              'last_synced_at': generatedAt.toUtc().toIso8601String(),

            },

            where: 'id = ?',

            whereArgs: <Object?>[materialId],

          );

          changedCount++;

        }

      }

      final String now = DateTime.now().toUtc().toIso8601String();

      await transaction.insert(

        DatabaseTables.materialSyncState,

        <String, Object?>{

          'user_id': userId,

          'last_manifest_at': generatedAt.toUtc().toIso8601String(),

          'last_successful_sync_at': now,

          'updated_at': now,

        },

        conflictAlgorithm: ConflictAlgorithm.replace,

      );

    });

    return _ManifestApplyResult(

      changedCount: changedCount,

      detachedFileIds: detachedFileIds,

    );

  }

  Future<void> _purgeUnavailableRemoteFiles(int userId) async {

    final Database db = await _database.database;

    final List<Map<String, Object?>> rows = await db.query(

      DatabaseTables.materials,

      columns: <String>['id', 'file_id'],

      where:

          'user_id = ? AND source <> ? AND is_available_remote = 0 AND file_id IS NOT NULL',

      whereArgs: <Object?>[userId, MaterialSourceLocal.local.name],

    );

    for (final Map<String, Object?> row in rows) {

      final int? materialId = _asInt(row['id']);

      final int? fileId = _asInt(row['file_id']);

      if (materialId == null || fileId == null) {

        continue;

      }

      await db.transaction((Transaction transaction) async {

        await transaction.update(

          DatabaseTables.materials,

          <String, Object?>{'file_id': null},

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

    }

  }

  Future<void> _purgeUnavailableRemoteRecords(int userId) async {

    final Database db = await _database.database;

    await db.delete(

      DatabaseTables.materials,

      where:

          'user_id = ? AND source <> ? AND is_available_remote = 0 AND file_id IS NULL',

      whereArgs: <Object?>[userId, MaterialSourceLocal.local.name],

    );

  }

  Future<void> _deletePhysicalFileIfUnused(int fileId) async {

    final Database db = await _database.database;

    String? localPath;

    await db.transaction((Transaction transaction) async {

      final List<Map<String, Object?>> references = await transaction.rawQuery(

        '''

        SELECT COUNT(*) AS total

        FROM ${DatabaseTables.materials}

        WHERE file_id = ?

        ''',

        <Object?>[fileId],

      );

      final int count =

          _asInt(references.isEmpty ? null : references.first['total']) ?? 0;

      if (count > 0) {

        return;

      }

      final List<Map<String, Object?>> files = await transaction.query(

        DatabaseTables.materialFiles,

        columns: <String>['local_path'],

        where: 'id = ?',

        whereArgs: <Object?>[fileId],

        limit: 1,

      );

      if (files.isNotEmpty) {

        localPath = files.first['local_path']?.toString();

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

  Future<List<MaterialLocal>> _getGroupMaterials({

    required int userId,

    required int groupId,

  }) async {

    final Database db = await _database.database;

    final List<Map<String, Object?>> rows = await db.query(

      DatabaseTables.materials,

      where:

          'user_id = ? AND group_id = ? AND source = ? AND is_available_remote = 1',

      whereArgs: <Object?>[userId, groupId, MaterialSourceLocal.group.name],

      orderBy: 'updated_at DESC, id DESC',

    );

    return rows.map(MaterialLocal.fromMap).toList();

  }

  Future<DateTime?> _getLastManifestAt(int userId) async {

    final Database db = await _database.database;

    final List<Map<String, Object?>> rows = await db.query(

      DatabaseTables.materialSyncState,

      columns: <String>['last_manifest_at'],

      where: 'user_id = ?',

      whereArgs: <Object?>[userId],

      limit: 1,

    );

    if (rows.isEmpty) {

      return null;

    }

    return _parseDateTime(rows.first['last_manifest_at']);

  }

  Future<DateTime?> _getLastSuccessfulSyncAt(int userId) async {

    final Database db = await _database.database;

    final List<Map<String, Object?>> rows = await db.query(

      DatabaseTables.materialSyncState,

      columns: <String>['last_successful_sync_at'],

      where: 'user_id = ?',

      whereArgs: <Object?>[userId],

      limit: 1,

    );

    if (rows.isEmpty) {

      return null;

    }

    return _parseDateTime(rows.first['last_successful_sync_at']);

  }

  List<String> _parseVisibleKeys(dynamic value) {

    if (value is! List) {

      return <String>[];

    }

    return value

        .map((dynamic item) => item?.toString().trim() ?? '')

        .where((String item) => item.isNotEmpty)

        .toSet()

        .toList();

  }

  List<Map<String, dynamic>> _parseItems(dynamic value) {

    if (value is! List) {

      return <Map<String, dynamic>>[];

    }

    return value

        .whereType<Map>()

        .map((Map<dynamic, dynamic> item) => Map<String, dynamic>.from(item))

        .toList();

  }

  MaterialSourceLocal? _parseSource(dynamic value) {

    switch (value?.toString().trim().toLowerCase()) {

      case 'public':

        return MaterialSourceLocal.public;

      case 'teacher':

        return MaterialSourceLocal.teacher;

      case 'group':

        return MaterialSourceLocal.group;

      default:

        return null;

    }

  }

  void _putOptionalString(

    Map<String, Object?> target,

    String column,

    Map<String, dynamic> source,

    String key,

  ) {

    if (!source.containsKey(key)) {

      return;

    }

    target[column] = _nullableString(source[key]);

  }

  String? _nullableString(dynamic value) {

    if (value == null) {

      return null;

    }

    final String result = value.toString().trim();

    return result.isEmpty ? null : result;

  }

  DateTime? _parseDateTime(dynamic value) {

    if (value == null) {

      return null;

    }

    if (value is DateTime) {

      return value.toUtc();

    }

    return DateTime.tryParse(value.toString())?.toUtc();

  }

  int? _asInt(dynamic value) {

    if (value is int) {

      return value;

    }

    if (value is num) {

      return value.toInt();

    }

    return int.tryParse(value?.toString() ?? '');

  }

  bool? _asBool(dynamic value) {

    if (value is bool) {

      return value;

    }

    if (value is num) {

      return value != 0;

    }

    final String normalized = value?.toString().trim().toLowerCase() ?? '';

    if (normalized == 'true' || normalized == '1') {

      return true;

    }

    if (normalized == 'false' || normalized == '0') {

      return false;

    }

    return null;

  }

}

class MaterialManifestSyncResult {

  final int userId;

  final DateTime generatedAt;

  final DateTime? since;

  final bool incremental;

  final List<String> visibleKeys;

  final int changedCount;

  const MaterialManifestSyncResult({

    required this.userId,

    required this.generatedAt,

this.since,

    required this.incremental,

    required this.visibleKeys,

    required this.changedCount,

  });

  bool get hasChanges => changedCount > 0;

}

class GroupMaterialSyncResult {

  final int userId;

  final int groupId;

  final List<MaterialLocal> materials;

  final List<PendingUploadLocal> uploads;

  final MaterialSyncSource source;

  final bool isOffline;

  final DateTime? syncedAt;

  final String? syncError;

  final String? uploadError;

  const GroupMaterialSyncResult({

    required this.userId,

    required this.groupId,

    required this.materials,

    required this.uploads,

    required this.source,

    required this.isOffline,

this.syncedAt,

this.syncError,

this.uploadError,

  });

  bool get fromBackend => source == MaterialSyncSource.backend;

  bool get fromLocal => source == MaterialSyncSource.local;

  bool get hasMaterials => materials.isNotEmpty;

  bool get hasUploads => uploads.isNotEmpty;

  bool get hasSyncError => syncError != null && syncError!.isNotEmpty;

  bool get hasUploadError => uploadError != null && uploadError!.isNotEmpty;

  bool get hasErrors => hasSyncError || hasUploadError;

  int get uploadedCount =>

      uploads.where((PendingUploadLocal upload) => upload.isUploaded).length;

  int get failedUploadCount =>

      uploads.where((PendingUploadLocal upload) => upload.isFailed).length;

}

class UserUploadSyncResult {

  final int userId;

  final List<PendingUploadLocal> uploads;

  final int uploadedCount;

  final int failedCount;

  const UserUploadSyncResult({

    required this.userId,

    required this.uploads,

    required this.uploadedCount,

    required this.failedCount,

  });

  bool get hasUploads => uploads.isNotEmpty;

  bool get allSucceeded => uploads.isNotEmpty && failedCount == 0;

  bool get hasFailures => failedCount > 0;

}

class GroupLocalMaterialState {

  final int userId;

  final int groupId;

  final List<MaterialLocal> materials;

  final List<PendingUploadLocal> uploads;

  final DateTime? lastSync;

  const GroupLocalMaterialState({

    required this.userId,

    required this.groupId,

    required this.materials,

    required this.uploads,

this.lastSync,

  });

  bool get hasMaterials => materials.isNotEmpty;

  bool get hasUploads => uploads.isNotEmpty;

  bool get hasPendingUploads => uploads.any(

    (PendingUploadLocal upload) => upload.isPending || upload.isUploading,

  );

  bool get hasFailedUploads =>

      uploads.any((PendingUploadLocal upload) => upload.isFailed);

  int get pendingUploadCount => uploads

      .where(

        (PendingUploadLocal upload) => upload.isPending || upload.isUploading,

      )

      .length;

  int get failedUploadCount =>

      uploads.where((PendingUploadLocal upload) => upload.isFailed).length;

}

class _ManifestApplyResult {

  final int changedCount;

  final Set<int> detachedFileIds;

  const _ManifestApplyResult({

    required this.changedCount,

    required this.detachedFileIds,

  });

}