import 'dart:typed_data';

import 'package:sqflite_common/sqlite_api.dart';

import '../database/app_database.dart';
import '../database/database_tables.dart';
import '../models/material_file_local.dart';
import '../models/material_local.dart';
import '../repositories/material_repository.dart';
import 'local_file_service.dart';
import 'local_storage_identity.dart';

class LocalMaterialImportService {
  final MaterialRepository _materialRepository;
  final LocalFileService _fileService;
  final AppDatabase _database;

  LocalMaterialImportService({
    MaterialRepository? materialRepository,
    LocalFileService? fileService,
    AppDatabase? database,
  }) : _materialRepository = materialRepository ?? MaterialRepository(),
       _fileService = fileService ?? LocalFileService(),
       _database = database ?? AppDatabase.instance;

  Future<MaterialLocal> importMaterial({
    int? userId,
    required String sourcePath,
    String? university,
    String? department,
    String? course,
    String? subjectName,
    String? originalName,
    int? subjectId,
  }) async {
    final int resolvedUserId = LocalStorageIdentity.resolve(userId: userId);

    final Uint8List? sourceBytes = await _fileService.readBytes(sourcePath);

    if (sourceBytes == null) {
      throw StateError('File non disponibile.');
    }

    final int size = sourceBytes.length;

    if (size <= 0) {
      throw StateError('File vuoto.');
    }

    final String resolvedName =
        originalName != null && originalName.trim().isNotEmpty
        ? originalName.trim()
        : _fileService.getFileName(sourcePath);

    final List<MaterialLocal> existing = await _materialRepository.getByUser(
      resolvedUserId,
    );

    final String rawUniversity = _requiredValue(university, 'Ateneo');
    final String rawDepartment = _requiredValue(department, 'Dipartimento');
    final String rawCourse = _requiredValue(course, 'Corso');
    final String rawSubjectName = _requiredValue(subjectName, 'Materia');

    final String? canonicalUniversity = _canonicalOptionalValue(
      rawUniversity,
      existing
          .map((MaterialLocal material) => material.university)
          .whereType<String>(),
    );

    final String? canonicalDepartment = _canonicalOptionalValue(
      rawDepartment,
      existing
          .where(
            (MaterialLocal material) =>
                _sameText(material.university, canonicalUniversity),
          )
          .map((MaterialLocal material) => material.department)
          .whereType<String>(),
    );

    final String? canonicalCourse = _canonicalOptionalValue(
      rawCourse,
      existing
          .where(
            (MaterialLocal material) =>
                _sameText(material.university, canonicalUniversity) &&
                _sameText(material.department, canonicalDepartment),
          )
          .map((MaterialLocal material) => material.course)
          .whereType<String>(),
    );

    final String? canonicalSubject = _canonicalOptionalValue(
      rawSubjectName,
      existing
          .where(
            (MaterialLocal material) =>
                _sameText(material.university, canonicalUniversity) &&
                _sameText(material.department, canonicalDepartment) &&
                _sameText(material.course, canonicalCourse),
          )
          .map((MaterialLocal material) => material.subjectName)
          .whereType<String>(),
    );

    final bool completeCatalogHierarchy =
        canonicalUniversity != null &&
        canonicalDepartment != null &&
        canonicalCourse != null &&
        canonicalSubject != null;

    if (!completeCatalogHierarchy) {
      throw ArgumentError('Gerarchia accademica non valida.');
    }

    final int? resolvedSubjectId = subjectId;

    final String mimeType = _mimeType(resolvedName);

    final String? fileHash = await _fileService.calculateSha256(sourcePath);

    final MaterialFileLocal? existingPhysicalFile = fileHash == null
        ? null
        : await _getMaterialFileByHash(fileHash);

    final int fileId;

    if (existingPhysicalFile != null &&
        await _fileService.exists(existingPhysicalFile.localPath)) {
      fileId = existingPhysicalFile.id!;
    } else {
      final String copiedPath = await _copyIntoLibrary(
        userId: resolvedUserId,
        sourcePath: sourcePath,
        fileName: resolvedName,
      );

      final DateTime now = DateTime.now().toUtc();

      if (existingPhysicalFile != null) {
        final MaterialFileLocal updatedFile = existingPhysicalFile.copyWith(
          localPath: copiedPath,
          fileHash: fileHash,
          size: size,
          mimeType: mimeType,
          existsLocally: true,
          updatedAt: now,
        );

        await _updateMaterialFile(updatedFile);

        fileId = existingPhysicalFile.id!;
      } else {
        fileId = await _insertMaterialFile(
          MaterialFileLocal(
            localPath: copiedPath,
            fileHash: fileHash,
            size: size,
            mimeType: mimeType,
            existsLocally: true,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    }

    final DateTime now = DateTime.now().toUtc();

    final MaterialLocal material = MaterialLocal(
      userId: resolvedUserId,
      source: MaterialSourceLocal.local,
      remoteKey: null,
      remoteId: null,
      subjectId: resolvedSubjectId,
      groupId: null,
      university: canonicalUniversity,
      department: canonicalDepartment,
      course: canonicalCourse,
      subjectName: canonicalSubject,
      originalName: resolvedName,
      fileId: fileId,
      remoteVersion: null,
      remoteStatus: null,
      isAvailableRemote: false,
      isPersonal: true,
      createdAt: now,
      updatedAt: now,
      lastSyncedAt: null,
    );

    final int id = await _materialRepository.insert(material);

    return material.copyWith(id: id);
  }

  Future<String> _copyIntoLibrary({
    required int userId,
    required String sourcePath,
    required String fileName,
  }) async {
    final Uint8List? bytes = await _fileService.readBytes(sourcePath);

    if (bytes == null || bytes.isEmpty) {
      throw StateError('File non disponibile.');
    }

    return _fileService.saveImportedMaterialBytes(
      userId: userId,
      fileName: fileName,
      bytes: bytes,
    );
  }

  Future<MaterialLocal> importMaterialBytes({
    int? userId,
    required Uint8List bytes,
    required String fileName,
    String? university,
    String? department,
    String? course,
    String? subjectName,
    int? subjectId,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError('File vuoto.');
    }

    final String transientPath = await _fileService.saveTransientFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: _mimeType(fileName),
    );

    try {
      return await importMaterial(
        userId: userId,
        sourcePath: transientPath,
        university: university,
        department: department,
        course: course,
        subjectName: subjectName,
        originalName: fileName,
        subjectId: subjectId,
      );
    } finally {
      await _fileService.delete(transientPath);
    }
  }

  Future<MaterialFileLocal?> _getMaterialFileByHash(String fileHash) async {
    final Database db = await _database.database;

    final List<Map<String, Object?>> rows = await db.query(
      DatabaseTables.materialFiles,
      where: 'file_hash = ?',
      whereArgs: <Object?>[fileHash.trim().toLowerCase()],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return MaterialFileLocal.fromMap(rows.first);
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

  String _requiredValue(String? value, String fieldName) {
    final String normalized = value == null ? '' : _cleanText(value);

    if (normalized.isEmpty) {
      throw ArgumentError('$fieldName obbligatorio.');
    }

    return normalized;
  }

  String? _canonicalOptionalValue(String? value, Iterable<String> existing) {
    if (value == null) {
      return null;
    }

    final String trimmed = _cleanText(value);

    if (trimmed.isEmpty) {
      return null;
    }

    for (final String candidate in existing) {
      if (_sameText(candidate, trimmed)) {
        return _cleanText(candidate);
      }
    }

    return trimmed;
  }

  bool _sameText(String? a, String? b) {
    if (a == null || b == null) {
      return false;
    }

    return _normalizeText(a) == _normalizeText(b);
  }

  String _normalizeText(String value) {
    return _cleanText(value).toLowerCase();
  }

  String _cleanText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _sanitizeFileName(String fileName) {
    String value = fileName.trim();

    if (value.isEmpty) {
      value = 'materiale';
    }

    value = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    value = value.replaceAll(RegExp(r'^\.+'), '');

    if (value.isEmpty) {
      return 'materiale';
    }

    return value;
  }

  String _mimeType(String fileName) {
    final String lower = fileName.toLowerCase();

    if (lower.endsWith('.pdf')) {
      return 'application/pdf';
    }

    if (lower.endsWith('.txt')) {
      return 'text/plain';
    }

    if (lower.endsWith('.zip')) {
      return 'application/zip';
    }

    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }

    if (lower.endsWith('.pptx')) {
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    }

    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }

    if (lower.endsWith('.csv')) {
      return 'text/csv';
    }

    if (lower.endsWith('.png')) {
      return 'image/png';
    }

    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }

    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }

    return 'application/octet-stream';
  }
}
