import 'dart:typed_data';

import 'package:sqflite_common/sqlite_api.dart';

import '../../services/api_service.dart';
import '../database/app_database.dart';
import '../database/database_tables.dart';
import '../models/material_download_local.dart';
import '../models/material_file_local.dart';
import '../models/material_local.dart';
import '../models/material_offline_entry.dart';
import '../repositories/material_repository.dart';
import 'local_file_service.dart';
import 'local_storage_identity.dart';

class MaterialDownloadService {
  final ApiService _apiService;
  final MaterialRepository _materialRepository;
  final LocalFileService _fileService;
  final AppDatabase _database;

  MaterialDownloadService({
    ApiService? apiService,
    MaterialRepository? materialRepository,
    LocalFileService? fileService,
    AppDatabase? database,
  }) : _apiService = apiService ?? ApiService(),
       _materialRepository = materialRepository ?? MaterialRepository(),
       _fileService = fileService ?? LocalFileService(),
       _database = database ?? AppDatabase.instance;

  int get currentLocalUserId => LocalStorageIdentity.currentLocalUserId;

  Future<MaterialLocal> downloadMaterial({
    int? userId,
    required MaterialSourceLocal source,
    required int materialId,
    int? groupId,
    String? university,
    String? department,
    String? course,
    int? subjectId,
    String? subjectName,
    required String originalName,
    String? mimeType,
    int? size,
    String? expectedHash,
    int? remoteVersion,
    String remoteStatus = 'active',
  }) async {
    if (source == MaterialSourceLocal.local) {
      throw ArgumentError(
        'Un materiale locale non può essere scaricato dal server.',
      );
    }

    final int resolvedUserId = LocalStorageIdentity.resolve(userId: userId);
    final String remoteKey = '${source.name}:$materialId';
    final DateTime now = DateTime.now().toUtc();

    MaterialLocal? material = await _materialRepository.getByRemoteKey(
      userId: resolvedUserId,
      remoteKey: remoteKey,
    );

    if (material == null) {
      material = MaterialLocal(
        userId: resolvedUserId,
        source: source,
        remoteKey: remoteKey,
        remoteId: materialId,
        subjectId: subjectId,
        groupId: groupId,
        university: university,
        department: department,
        course: course,
        subjectName: subjectName,
        originalName: originalName,
        remoteVersion: remoteVersion ?? 1,
        remoteStatus: remoteStatus,
        isAvailableRemote: true,
        isPersonal: false,
        createdAt: now,
        updatedAt: now,
        lastSyncedAt: now,
      );

      final int id = await _materialRepository.save(material);
      material = material.copyWith(id: id);
    } else {
      final bool versionChanged =
          remoteVersion != null && material.remoteVersion != remoteVersion;
      final int? previousFileId = material.fileId;

      if (versionChanged && material.id != null && previousFileId != null) {
        await _materialRepository.detachFile(material.id!);
        await _deleteDownloadState(material.id!);
        await _deleteMaterialFileIfUnused(previousFileId);
      }

      material = material.copyWith(
        subjectId: subjectId,
        groupId: groupId,
        university: university,
        department: department,
        course: course,
        subjectName: subjectName,
        originalName: originalName,
        remoteVersion: remoteVersion,
        remoteStatus: remoteStatus,
        isAvailableRemote: true,
        updatedAt: now,
        lastSyncedAt: now,
        clearFileId: versionChanged,
      );

      await _materialRepository.save(material);
    }

    final MaterialFileLocal? currentFile = await _getMaterialFile(
      material.fileId,
    );

    if (currentFile != null) {
      final bool exists = await _fileService.exists(currentFile.localPath);

      if (exists) {
        final String? normalizedExpectedHash = _normalizeHash(expectedHash);

        if (normalizedExpectedHash == null) {
          return material;
        }

        final String? currentHash = _normalizeHash(currentFile.fileHash);

        if (currentHash == normalizedExpectedHash) {
          return material;
        }

        final bool matches = await _fileService.matchesSha256(
          path: currentFile.localPath,
          expectedHash: normalizedExpectedHash,
        );

        if (matches) {
          await _updateMaterialFileHash(
            fileId: currentFile.id!,
            fileHash: normalizedExpectedHash,
          );
          return material;
        }
      }
    }

    final int localMaterialId = material.id!;

    await _setDownloadState(
      userId: resolvedUserId,
      materialId: localMaterialId,
      status: MaterialDownloadStatusLocal.downloading,
      expectedHash: _normalizeHash(expectedHash),
      expectedSize: size,
      startedAt: now,
      clearCompletedAt: true,
      clearError: true,
    );

    String? temporaryPath;

    try {
      final Uint8List bytes = await _downloadBytes(
        source: source,
        materialId: materialId,
      );

      if (size != null && size >= 0 && bytes.length != size) {
        throw Exception(
          'La dimensione del file scaricato non corrisponde a quella prevista.',
        );
      }

      temporaryPath = await _fileService.saveTemporaryDownload(
        userId: resolvedUserId,
        source: source.name,
        remoteId: materialId,
        fileName: originalName,
        bytes: bytes,
      );

      await _setDownloadState(
        userId: resolvedUserId,
        materialId: localMaterialId,
        status: MaterialDownloadStatusLocal.verifying,
        tempPath: temporaryPath,
        expectedHash: _normalizeHash(expectedHash),
        expectedSize: size ?? bytes.length,
        downloadedBytes: bytes.length,
      );

      final String? normalizedExpectedHash = _normalizeHash(expectedHash);
      final String? actualHash = await _fileService.calculateSha256(
        temporaryPath,
      );

      if (actualHash == null) {
        throw Exception('Impossibile verificare il file scaricato.');
      }

      if (normalizedExpectedHash != null &&
          actualHash != normalizedExpectedHash) {
        throw Exception(
          'Il file scaricato non supera il controllo di integrità.',
        );
      }

      final MaterialFileLocal? duplicate = await _getMaterialFileByHash(
        actualHash,
      );

      int fileId;

      if (duplicate != null) {
        final bool duplicateExists = await _fileService.exists(
          duplicate.localPath,
        );

        if (duplicateExists) {
          await _fileService.delete(temporaryPath);
          temporaryPath = null;
          fileId = duplicate.id!;
        } else {
          final String localPath = await _fileService.moveTemporaryDownload(
            temporaryPath: temporaryPath,
            userId: resolvedUserId,
            source: source.name,
            remoteId: materialId,
            groupId: groupId,
            fileName: originalName,
          );

          temporaryPath = null;

          await _updateMaterialFile(
            duplicate.copyWith(
              localPath: localPath,
              fileHash: actualHash,
              size: bytes.length,
              mimeType: mimeType,
              existsLocally: true,
              updatedAt: DateTime.now().toUtc(),
            ),
          );

          fileId = duplicate.id!;
        }
      } else {
        final String localPath = await _fileService.moveTemporaryDownload(
          temporaryPath: temporaryPath,
          userId: resolvedUserId,
          source: source.name,
          remoteId: materialId,
          groupId: groupId,
          fileName: originalName,
        );

        temporaryPath = null;

        fileId = await _insertMaterialFile(
          MaterialFileLocal(
            localPath: localPath,
            fileHash: actualHash,
            size: bytes.length,
            mimeType: mimeType,
            existsLocally: true,
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
      }

      final int? previousFileId = material.fileId;

      await _materialRepository.attachFile(
        materialId: localMaterialId,
        fileId: fileId,
      );

      if (previousFileId != null && previousFileId != fileId) {
        await _deleteMaterialFileIfUnused(previousFileId);
      }

      await _setDownloadState(
        userId: resolvedUserId,
        materialId: localMaterialId,
        status: MaterialDownloadStatusLocal.completed,
        expectedHash: actualHash,
        expectedSize: bytes.length,
        downloadedBytes: bytes.length,
        completedAt: DateTime.now().toUtc(),
        clearTempPath: true,
        clearError: true,
      );

      final MaterialLocal? updated = await _materialRepository.getById(
        localMaterialId,
      );

      if (updated == null) {
        throw StateError('Materiale locale non disponibile dopo il download.');
      }

      return updated;
    } catch (error) {
      if (temporaryPath != null) {
        await _fileService.delete(temporaryPath);
      }

      await _setDownloadState(
        userId: resolvedUserId,
        materialId: localMaterialId,
        status: MaterialDownloadStatusLocal.failed,
        errorMessage: error.toString(),
        clearTempPath: true,
      );

      rethrow;
    }
  }

  Future<MaterialLocal> getOrDownloadMaterial({
    int? userId,
    required MaterialSourceLocal source,
    required int materialId,
    int? groupId,
    String? university,
    String? department,
    String? course,
    int? subjectId,
    String? subjectName,
    required String originalName,
    String? mimeType,
    int? size,
    String? expectedHash,
    int? remoteVersion,
    String remoteStatus = 'active',
  }) async {
    final MaterialLocal? existing = await getLocalMaterialV6(
      userId: userId,
      source: source,
      materialId: materialId,
      expectedHash: expectedHash,
    );

    final bool versionChanged =
        existing != null &&
        remoteVersion != null &&
        existing.remoteVersion != remoteVersion;

    if (existing != null && !versionChanged) {
      final MaterialLocal updated = existing.copyWith(
        groupId: groupId,
        university: university,
        department: department,
        course: course,
        subjectId: subjectId,
        subjectName: subjectName,
        originalName: originalName,
        remoteVersion: remoteVersion,
        remoteStatus: remoteStatus,
        isAvailableRemote: true,
        updatedAt: DateTime.now().toUtc(),
      );

      await _materialRepository.save(updated);
      return updated;
    }

    return downloadMaterial(
      userId: userId,
      source: source,
      materialId: materialId,
      groupId: groupId,
      university: university,
      department: department,
      course: course,
      subjectId: subjectId,
      subjectName: subjectName,
      originalName: originalName,
      mimeType: mimeType,
      size: size,
      expectedHash: expectedHash,
      remoteVersion: remoteVersion,
      remoteStatus: remoteStatus,
    );
  }

  Future<bool> isMaterialDownloaded({
    int? userId,
    required MaterialSourceLocal source,
    required int materialId,
    String? expectedHash,
  }) async {
    return await getLocalMaterialV6(
          userId: userId,
          source: source,
          materialId: materialId,
          expectedHash: expectedHash,
        ) !=
        null;
  }

  Future<MaterialLocal?> getLocalMaterialV6({
    int? userId,
    required MaterialSourceLocal source,
    required int materialId,
    String? expectedHash,
  }) async {
    final int resolvedUserId = LocalStorageIdentity.resolve(userId: userId);

    final MaterialLocal? material = await _materialRepository.getByRemoteKey(
      userId: resolvedUserId,
      remoteKey: '${source.name}:$materialId',
    );

    if (material == null || material.fileId == null) {
      return null;
    }

    final MaterialFileLocal? file = await _getMaterialFile(material.fileId);

    if (file == null) {
      await _materialRepository.detachFile(material.id!);
      return null;
    }

    final bool exists = await _fileService.exists(file.localPath);

    if (!exists) {
      await _markFileMissing(file);
      await _materialRepository.detachFile(material.id!);
      await _deleteMaterialFileIfUnused(file.id!);
      return null;
    }

    final String? normalizedExpectedHash = _normalizeHash(expectedHash);

    if (normalizedExpectedHash != null) {
      final String? storedHash = _normalizeHash(file.fileHash);

      if (storedHash != normalizedExpectedHash) {
        final bool matches = await _fileService.matchesSha256(
          path: file.localPath,
          expectedHash: normalizedExpectedHash,
        );

        if (!matches) {
          return null;
        }

        await _updateMaterialFileHash(
          fileId: file.id!,
          fileHash: normalizedExpectedHash,
        );
      }
    }

    return material;
  }

  Future<String?> getMaterialFile({
    int? userId,
    required MaterialSourceLocal source,
    required int materialId,
    String? expectedHash,
  }) async {
    final MaterialLocal? material = await getLocalMaterialV6(
      userId: userId,
      source: source,
      materialId: materialId,
      expectedHash: expectedHash,
    );

    if (material == null || material.fileId == null) {
      return null;
    }

    final MaterialFileLocal? file = await _getMaterialFile(material.fileId);

    if (file == null || !await _fileService.exists(file.localPath)) {
      return null;
    }

    return file.localPath;
  }

  Future<void> openMaterial({
    int? userId,
    required MaterialSourceLocal source,
    required int materialId,
    String? expectedHash,
  }) async {
    final MaterialLocal? material = await getLocalMaterialV6(
      userId: userId,
      source: source,
      materialId: materialId,
      expectedHash: expectedHash,
    );

    if (material == null || material.fileId == null) {
      throw StateError('Il materiale non è disponibile offline.');
    }

    final MaterialFileLocal? file = await _getMaterialFile(material.fileId);

    if (file == null || !await _fileService.exists(file.localPath)) {
      throw StateError('Il file locale non è disponibile.');
    }

    await _fileService.openStoredFile(
      file.localPath,
      fileName: material.originalName,
      mimeType: file.mimeType,
    );
  }


  Future<void> removeMaterialDownload({
    int? userId,
    required MaterialSourceLocal source,
    required int materialId,
  }) async {
    final int resolvedUserId = LocalStorageIdentity.resolve(userId: userId);

    final MaterialLocal? material = await _materialRepository.getByRemoteKey(
      userId: resolvedUserId,
      remoteKey: '${source.name}:$materialId',
    );

    if (material == null || material.fileId == null) {
      return;
    }

    final int fileId = material.fileId!;

    await _materialRepository.detachFile(material.id!);
    await _deleteDownloadState(material.id!);
    await _deleteMaterialFileIfUnused(fileId);
  }

  Future<List<MaterialLocal>> getDownloadedMaterialsV6({int? userId}) async {
    final int resolvedUserId = LocalStorageIdentity.resolve(userId: userId);
    return _getValidDownloadedMaterials(resolvedUserId);
  }

  Future<List<MaterialOfflineEntry>> getDownloadedMaterialEntries({
    int? userId,
  }) async {
    final List<MaterialLocal> materials = await getDownloadedMaterialsV6(
      userId: userId,
    );
    final List<MaterialOfflineEntry> entries = <MaterialOfflineEntry>[];

    for (final MaterialLocal material in materials) {
      if (material.fileId == null) {
        continue;
      }

      final MaterialFileLocal? file = await _getMaterialFile(material.fileId);

      if (file == null || !file.existsLocally) {
        continue;
      }

      final bool exists = await _fileService.exists(file.localPath);

      if (!exists) {
        await _markFileMissing(file);

        if (material.id != null) {
          await _materialRepository.detachFile(material.id!);
        }

        if (file.id != null) {
          await _deleteMaterialFileIfUnused(file.id!);
        }

        continue;
      }

      entries.add(MaterialOfflineEntry(material: material, file: file));
    }

    return entries;
  }

  Future<String?> getFileForMaterial(MaterialLocal material) async {
    if (material.fileId == null) {
      return null;
    }

    final MaterialFileLocal? file = await _getMaterialFile(material.fileId);

    if (file == null) {
      if (material.id != null) {
        await _materialRepository.detachFile(material.id!);
      }
      return null;
    }

    final bool exists = await _fileService.exists(file.localPath);

    if (!exists) {
      await _markFileMissing(file);
      if (material.id != null) {
        await _materialRepository.detachFile(material.id!);
      }
      if (file.id != null) {
        await _deleteMaterialFileIfUnused(file.id!);
      }
      return null;
    }

    return file.localPath;
  }

  Future<void> openLocalMaterial(MaterialLocal material) async {
    final String? path = await getFileForMaterial(material);
    if (path == null) {
      throw StateError('Il file locale non è disponibile.');
    }
    final MaterialFileLocal? file = await _getMaterialFile(material.fileId);
    await _fileService.openStoredFile(
      path,
      fileName: material.originalName,
      mimeType: file?.mimeType,
    );
  }


  Future<void> removeMaterialDownloadV6(MaterialLocal material) async {
    if (material.id == null || material.fileId == null) {
      return;
    }

    final int fileId = material.fileId!;

    await _materialRepository.detachFile(material.id!);
    await _deleteDownloadState(material.id!);
    await _deleteMaterialFileIfUnused(fileId);
  }

  Future<int> removeSubjectDownloads({
    int? userId,
    required int subjectId,
  }) async {
    final int resolvedUserId = LocalStorageIdentity.resolve(userId: userId);

    final List<MaterialLocal> materials = await _materialRepository
        .getBySubject(
          userId: resolvedUserId,
          subjectId: subjectId,
          onlyAvailable: false,
        );

    int removed = 0;

    for (final MaterialLocal material in materials) {
      if (material.fileId == null || material.id == null) {
        continue;
      }

      final int fileId = material.fileId!;

      await _materialRepository.detachFile(material.id!);
      await _deleteDownloadState(material.id!);
      await _deleteMaterialFileIfUnused(fileId);
      removed++;
    }

    return removed;
  }

  Future<Uint8List> _downloadBytes({
    required MaterialSourceLocal source,
    required int materialId,
  }) {
    if (source == MaterialSourceLocal.local) {
      throw ArgumentError('Sorgente download non valida.');
    }

    return _apiService.downloadMaterial(
      source: source.name,
      materialId: materialId,
    );
  }

  Future<List<MaterialLocal>> _getValidDownloadedMaterials(int userId) async {
    final List<MaterialLocal> materials = await _materialRepository
        .getDownloadedByUser(userId);
    final List<MaterialLocal> valid = <MaterialLocal>[];

    for (final MaterialLocal material in materials) {
      if (material.fileId == null || material.id == null) {
        continue;
      }

      final MaterialFileLocal? file = await _getMaterialFile(material.fileId);

      if (file == null) {
        await _materialRepository.detachFile(material.id!);
        continue;
      }

      final bool exists = await _fileService.exists(file.localPath);

      if (exists) {
        valid.add(material);
        continue;
      }

      await _markFileMissing(file);
      await _materialRepository.detachFile(material.id!);

      if (file.id != null) {
        await _deleteMaterialFileIfUnused(file.id!);
      }
    }

    return valid;
  }

  Future<MaterialFileLocal?> _getMaterialFile(int? fileId) async {
    if (fileId == null) {
      return null;
    }

    final Database db = await _database.database;
    final List<Map<String, Object?>> result = await db.query(
      DatabaseTables.materialFiles,
      where: 'id = ?',
      whereArgs: <Object?>[fileId],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return MaterialFileLocal.fromMap(result.first);
  }

  Future<MaterialFileLocal?> _getMaterialFileByHash(String fileHash) async {
    final Database db = await _database.database;
    final List<Map<String, Object?>> result = await db.query(
      DatabaseTables.materialFiles,
      where: 'file_hash = ?',
      whereArgs: <Object?>[fileHash.trim().toLowerCase()],
      limit: 1,
    );

    if (result.isEmpty) {
      return null;
    }

    return MaterialFileLocal.fromMap(result.first);
  }

  Future<int> _insertMaterialFile(MaterialFileLocal file) async {
    final Database db = await _database.database;
    return db.insert(DatabaseTables.materialFiles, file.toMap());
  }

  Future<void> _updateMaterialFile(MaterialFileLocal file) async {
    if (file.id == null) {
      throw ArgumentError('File locale senza id.');
    }

    final Database db = await _database.database;

    await db.update(
      DatabaseTables.materialFiles,
      file.toMap(),
      where: 'id = ?',
      whereArgs: <Object?>[file.id],
    );
  }

  Future<void> _updateMaterialFileHash({
    required int fileId,
    required String fileHash,
  }) async {
    final Database db = await _database.database;

    await db.update(
      DatabaseTables.materialFiles,
      <String, Object?>{
        'file_hash': fileHash.trim().toLowerCase(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[fileId],
    );
  }

  Future<void> _markFileMissing(MaterialFileLocal file) async {
    if (file.id == null) {
      return;
    }

    final Database db = await _database.database;

    await db.update(
      DatabaseTables.materialFiles,
      <String, Object?>{
        'exists_locally': 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: <Object?>[file.id],
    );
  }

  Future<void> _deleteMaterialFileIfUnused(int fileId) async {
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

  Future<void> _setDownloadState({
    required int userId,
    required int materialId,
    required MaterialDownloadStatusLocal status,
    String? tempPath,
    String? expectedHash,
    int? expectedSize,
    int? downloadedBytes,
    DateTime? startedAt,
    DateTime? completedAt,
    String? errorMessage,
    bool clearTempPath = false,
    bool clearCompletedAt = false,
    bool clearError = false,
  }) async {
    final Database db = await _database.database;

    final List<Map<String, Object?>> existing = await db.query(
      DatabaseTables.materialDownloads,
      columns: <String>['id'],
      where: 'material_id = ?',
      whereArgs: <Object?>[materialId],
      orderBy: 'id DESC',
      limit: 1,
    );

    final Map<String, Object?> values = <String, Object?>{
      'user_id': userId,
      'material_id': materialId,
      'status': status.name,
    };

    if (clearTempPath) {
      values['temp_path'] = null;
    } else if (tempPath != null) {
      values['temp_path'] = tempPath;
    }

    if (expectedHash != null) {
      values['expected_hash'] = expectedHash;
    }

    if (expectedSize != null) {
      values['expected_size'] = expectedSize;
    }

    if (downloadedBytes != null) {
      values['downloaded_bytes'] = downloadedBytes;
    }

    if (startedAt != null) {
      values['started_at'] = startedAt.toUtc().toIso8601String();
    }

    if (clearCompletedAt) {
      values['completed_at'] = null;
    } else if (completedAt != null) {
      values['completed_at'] = completedAt.toUtc().toIso8601String();
    }

    if (clearError) {
      values['error_message'] = null;
    } else if (errorMessage != null) {
      values['error_message'] = errorMessage;
    }

    if (existing.isEmpty) {
      values.putIfAbsent('downloaded_bytes', () => 0);

      await db.insert(DatabaseTables.materialDownloads, values);
      return;
    }

    final int? id = _asInt(existing.first['id']);

    if (id == null) {
      return;
    }

    await db.update(
      DatabaseTables.materialDownloads,
      values,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> _deleteDownloadState(int materialId) async {
    final Database db = await _database.database;

    await db.delete(
      DatabaseTables.materialDownloads,
      where: 'material_id = ?',
      whereArgs: <Object?>[materialId],
    );
  }

  String? _normalizeHash(String? value) {
    if (value == null) {
      return null;
    }

    final String normalized = value.trim().toLowerCase();
    return normalized.isEmpty ? null : normalized;
  }

  int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }
}
