import 'dart:js_interop';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common/sqlite_api.dart';
import 'package:web/web.dart' as web;

import '../database/app_database.dart';
import '../database/database_tables.dart';

class LocalFileService {
  final AppDatabase _database;

  LocalFileService({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  String _userRoot(int userId) => 'studentlab/users/$userId';

  String _normalizeSource(String source) {
    final String value = source.trim().toLowerCase();
    if (!{'local', 'public', 'teacher', 'group'}.contains(value)) {
      throw ArgumentError('Sorgente materiale non valida.');
    }
    return value;
  }

  String _sanitizeFileName(String fileName) {
    String value = fileName.trim();
    if (value.isEmpty) value = 'file';
    value = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    value = value.replaceAll(RegExp(r'\s+'), ' ');
    value = value.replaceAll(RegExp(r'^\.+'), '');
    return value.isEmpty ? 'file' : value;
  }

  String _uniqueName(String fileName) {
    final String extension = p.extension(fileName);
    final String base = p.basenameWithoutExtension(fileName);
    final int stamp = DateTime.now().microsecondsSinceEpoch;
    return extension.isEmpty ? '${base}_$stamp' : '${base}_$stamp$extension';
  }

  Future<void> _write({
    required String path,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    if (bytes.isEmpty) throw ArgumentError('Il file è vuoto.');
    final Database db = await _database.database;
    final String now = DateTime.now().toUtc().toIso8601String();
    await db.insert(
      DatabaseTables.localFileBlobs,
      <String, Object?>{
        'path': path,
        'file_name': fileName,
        'mime_type': mimeType,
        'data': bytes,
        'size': bytes.length,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, Object?>?> _row(String path) async {
    if (path.trim().isEmpty) return null;
    final Database db = await _database.database;
    final List<Map<String, Object?>> rows = await db.query(
      DatabaseTables.localFileBlobs,
      where: 'path = ?',
      whereArgs: <Object?>[path],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<String> saveDownloadedMaterial({
    required int userId,
    required String source,
    required int remoteId,
    int? groupId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final String normalizedSource = _normalizeSource(source);
    final List<String> parts = <String>[
      _userRoot(userId),
      'downloads',
      normalizedSource,
      if (normalizedSource == 'group' && groupId != null) '$groupId',
      '$remoteId',
      _sanitizeFileName(fileName),
    ];
    final String path = p.posix.joinAll(parts);
    await _write(path: path, fileName: fileName, bytes: bytes);
    return path;
  }

  Future<String> saveTemporaryDownload({
    required int userId,
    required String source,
    required int remoteId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final String path = p.posix.join(
      _userRoot(userId),
      'temp',
      'downloads',
      _normalizeSource(source),
      '$remoteId',
      '${_uniqueName(_sanitizeFileName(fileName))}.part',
    );
    await _write(path: path, fileName: fileName, bytes: bytes);
    return path;
  }

  Future<String> moveTemporaryDownload({
    required String temporaryPath,
    required int userId,
    required String source,
    required int remoteId,
    int? groupId,
    required String fileName,
  }) async {
    final Uint8List? bytes = await readBytes(temporaryPath);
    if (bytes == null) throw StateError('Il file temporaneo non esiste.');
    final String path = await saveDownloadedMaterial(
      userId: userId,
      source: source,
      remoteId: remoteId,
      groupId: groupId,
      fileName: fileName,
      bytes: bytes,
    );
    await delete(temporaryPath);
    return path;
  }

  Future<String> copyToPendingUpload({
    required int userId,
    required int groupId,
    required String sourcePath,
    String? preferredFileName,
  }) async {
    final Uint8List? bytes = await readBytes(sourcePath);
    if (bytes == null) throw StateError('Il file selezionato non esiste.');
    return savePendingUploadBytes(
      userId: userId,
      groupId: groupId,
      fileName: preferredFileName?.trim().isNotEmpty == true
          ? preferredFileName!.trim()
          : getFileName(sourcePath),
      bytes: bytes,
    );
  }

  Future<String> savePendingUploadBytes({
    required int userId,
    required int groupId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final String path = p.posix.join(
      _userRoot(userId),
      'uploads',
      'pending',
      'groups',
      '$groupId',
      _uniqueName(_sanitizeFileName(fileName)),
    );
    await _write(path: path, fileName: fileName, bytes: bytes);
    return path;
  }

  Future<String> saveImportedMaterialBytes({
    required int userId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final String path = p.posix.join(
      _userRoot(userId),
      'library',
      'imported',
      _uniqueName(_sanitizeFileName(fileName)),
    );
    await _write(path: path, fileName: fileName, bytes: bytes);
    return path;
  }

  Future<String> saveTransientFile({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    final String path = p.posix.join(
      'studentlab',
      'transient',
      _uniqueName(_sanitizeFileName(fileName)),
    );
    await _write(
      path: path,
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
    );
    return path;
  }

  Future<Uint8List?> readBytes(String path) async {
    final Map<String, Object?>? row = await _row(path);
    final Object? data = row?['data'];
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);
    return null;
  }

  Future<bool> exists(String path) async => await _row(path) != null;

  Future<int?> getFileSize(String path) async {
    final Map<String, Object?>? row = await _row(path);
    final Object? value = row?['size'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  Future<String?> calculateSha256(String path) async {
    final Uint8List? bytes = await readBytes(path);
    return bytes == null ? null : sha256.convert(bytes).toString().toLowerCase();
  }

  Future<bool> matchesSha256({
    required String path,
    required String expectedHash,
  }) async {
    final String expected = expectedHash.trim().toLowerCase();
    if (expected.isEmpty) return false;
    return await calculateSha256(path) == expected;
  }

  String getFileName(String path) => p.posix.basename(path);
  String getExtension(String path) => p.posix.extension(path);

  Future<void> delete(String path) async {
    if (path.trim().isEmpty) return;
    final Database db = await _database.database;
    await db.delete(
      DatabaseTables.localFileBlobs,
      where: 'path = ?',
      whereArgs: <Object?>[path],
    );
  }

  Future<void> deleteDirectory(String path) async {
    if (path.trim().isEmpty) return;
    final Database db = await _database.database;
    await db.delete(
      DatabaseTables.localFileBlobs,
      where: 'path = ? OR path LIKE ?',
      whereArgs: <Object?>[path, '${path.replaceAll('%', r'\%')}/%'],
    );
  }

  Future<void> deleteUserFiles(int userId) => deleteDirectory(_userRoot(userId));

  Future<String> getUserStoragePath(int userId) async => _userRoot(userId);

  Future<String> getPendingUploadDirectoryPath({
    required int userId,
    required int groupId,
  }) async => p.posix.join(
        _userRoot(userId),
        'uploads',
        'pending',
        'groups',
        '$groupId',
      );

  Future<String> getDownloadDirectoryPath({
    required int userId,
    required String source,
    int? remoteId,
    int? groupId,
  }) async => p.posix.joinAll(<String>[
        _userRoot(userId),
        'downloads',
        _normalizeSource(source),
        if (source.trim().toLowerCase() == 'group' && groupId != null) '$groupId',
        if (remoteId != null && remoteId > 0) '$remoteId',
      ]);

  Future<String> getGroupDownloadDirectoryPath({
    required int userId,
    required int groupId,
  }) => getDownloadDirectoryPath(
        userId: userId,
        source: 'group',
        groupId: groupId,
      );

  Future<void> openStoredFile(
    String path, {
    String? fileName,
    String? mimeType,
  }) async {
    final Uint8List? bytes = await readBytes(path);
    if (bytes == null) throw StateError('File non disponibile.');
    final String name = fileName?.trim().isNotEmpty == true
        ? fileName!.trim()
        : getFileName(path);
    final String type = mimeType?.trim().isNotEmpty == true
        ? mimeType!.trim()
        : 'application/octet-stream';
    final web.Blob blob = web.Blob(
      <JSAny>[bytes.toJS].toJS,
      web.BlobPropertyBag(type: type),
    );
    final String url = web.URL.createObjectURL(blob);
    final web.HTMLAnchorElement anchor = web.HTMLAnchorElement()
      ..href = url
      ..target = '_blank'
      ..download = name;
    web.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    Future<void>.delayed(const Duration(seconds: 2), () {
      web.URL.revokeObjectURL(url);
    });
  }
}
