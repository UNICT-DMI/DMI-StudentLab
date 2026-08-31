import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';


class LocalFileService {
  Future<Directory> _getRootDirectory() async {
    final Directory root =
        await getApplicationDocumentsDirectory();

    final Directory directory =
        Directory(
      p.join(
        root.path,
        'studentlab',
      ),
    );

    if (!await directory.exists()) {
      await directory.create(
        recursive:
            true,
      );
    }

    return directory;
  }


  Future<Directory> _getUserDirectory(
    int userId,
  ) async {
    final Directory root =
        await _getRootDirectory();

    final Directory directory =
        Directory(
      p.join(
        root.path,
        'users',
        userId.toString(),
      ),
    );

    if (!await directory.exists()) {
      await directory.create(
        recursive:
            true,
      );
    }

    return directory;
  }


  Future<Directory> _getDownloadsRootDirectory(
    int userId,
  ) async {
    final Directory userDirectory =
        await _getUserDirectory(
      userId,
    );

    final Directory directory =
        Directory(
      p.join(
        userDirectory.path,
        'downloads',
      ),
    );

    if (!await directory.exists()) {
      await directory.create(
        recursive:
            true,
      );
    }

    return directory;
  }


  Future<Directory> _getSourceDownloadDirectory({
    required int userId,
    required String source,
    int? remoteId,
    int? groupId,
  }) async {
    final String normalizedSource =
        _normalizeSource(
      source,
    );

    final Directory downloadsRoot =
        await _getDownloadsRootDirectory(
      userId,
    );

    final List<String> segments =
        <String>[
      downloadsRoot.path,
      normalizedSource,
    ];

    if (
      normalizedSource ==
          'group' &&
      groupId != null
    ) {
      segments.add(
        groupId.toString(),
      );
    }

    if (
      remoteId != null &&
      remoteId > 0
    ) {
      segments.add(
        remoteId.toString(),
      );
    }

    final Directory directory =
        Directory(
      p.joinAll(
        segments,
      ),
    );

    if (!await directory.exists()) {
      await directory.create(
        recursive:
            true,
      );
    }

    return directory;
  }


  Future<Directory> _getPendingUploadsDirectory({
    required int userId,
    required int groupId,
  }) async {
    final Directory userDirectory =
        await _getUserDirectory(
      userId,
    );

    final Directory directory =
        Directory(
      p.join(
        userDirectory.path,
        'uploads',
        'pending',
        'groups',
        groupId.toString(),
      ),
    );

    if (!await directory.exists()) {
      await directory.create(
        recursive:
            true,
      );
    }

    return directory;
  }


  Future<Directory> _getTemporaryDownloadDirectory({
    required int userId,
    required String source,
    required int remoteId,
  }) async {
    final String normalizedSource =
        _normalizeSource(
      source,
    );

    final Directory userDirectory =
        await _getUserDirectory(
      userId,
    );

    final Directory directory =
        Directory(
      p.join(
        userDirectory.path,
        'temp',
        'downloads',
        normalizedSource,
        remoteId.toString(),
      ),
    );

    if (!await directory.exists()) {
      await directory.create(
        recursive:
            true,
      );
    }

    return directory;
  }


  Future<String> saveDownloadedMaterial({
    required int userId,
    required String source,
    required int remoteId,
    int? groupId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final Directory directory =
        await _getSourceDownloadDirectory(
      userId:
          userId,
      source:
          source,
      remoteId:
          remoteId,
      groupId:
          groupId,
    );

    final String safeName =
        _sanitizeFileName(
      fileName,
    );

    final String filePath =
        p.join(
      directory.path,
      safeName,
    );

    final String temporaryPath =
        '$filePath.download';

    final File temporaryFile =
        File(
      temporaryPath,
    );

    await temporaryFile.writeAsBytes(
      bytes,
      flush:
          true,
    );

    final File destination =
        File(
      filePath,
    );

    if (await destination.exists()) {
      await destination.delete();
    }

    final File moved =
        await temporaryFile.rename(
      filePath,
    );

    return moved.path;
  }


  Future<String> saveTemporaryDownload({
    required int userId,
    required String source,
    required int remoteId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final Directory directory =
        await _getTemporaryDownloadDirectory(
      userId:
          userId,
      source:
          source,
      remoteId:
          remoteId,
    );

    final String safeName =
        _sanitizeFileName(
      fileName,
    );

    final String destinationPath =
        p.join(
      directory.path,
      '${_generateUniqueFileName(safeName)}.part',
    );

    final File file =
        File(
      destinationPath,
    );

    await file.writeAsBytes(
      bytes,
      flush:
          true,
    );

    return file.path;
  }


  Future<String> moveTemporaryDownload({
    required String temporaryPath,
    required int userId,
    required String source,
    required int remoteId,
    int? groupId,
    required String fileName,
  }) async {
    final File temporaryFile =
        File(
      temporaryPath,
    );

    if (!await temporaryFile.exists()) {
      throw FileSystemException(
        'Il file temporaneo non esiste.',
        temporaryPath,
      );
    }

    final Directory directory =
        await _getSourceDownloadDirectory(
      userId:
          userId,
      source:
          source,
      remoteId:
          remoteId,
      groupId:
          groupId,
    );

    final String safeName =
        _sanitizeFileName(
      fileName,
    );

    final String destinationPath =
        p.join(
      directory.path,
      safeName,
    );

    final File destinationFile =
        File(
      destinationPath,
    );

    if (await destinationFile.exists()) {
      await destinationFile.delete();
    }

    try {
      final File moved =
          await temporaryFile.rename(
        destinationPath,
      );

      return moved.path;
    } on FileSystemException {
      final File copied =
          await temporaryFile.copy(
        destinationPath,
      );

      await temporaryFile.delete();

      return copied.path;
    }
  }


  Future<String> copyToPendingUpload({
    required int userId,
    required int groupId,
    required String sourcePath,
    String? preferredFileName,
  }) async {
    final File sourceFile =
        File(
      sourcePath,
    );

    if (!await sourceFile.exists()) {
      throw FileSystemException(
        'Il file selezionato non esiste.',
        sourcePath,
      );
    }

    final Directory directory =
        await _getPendingUploadsDirectory(
      userId:
          userId,
      groupId:
          groupId,
    );

    final String originalName =
        preferredFileName != null &&
                preferredFileName.trim().isNotEmpty
            ? preferredFileName.trim()
            : p.basename(
                sourcePath,
              );

    final String safeName =
        _sanitizeFileName(
      originalName,
    );

    final String uniqueName =
        _generateUniqueFileName(
      safeName,
    );

    final String destinationPath =
        p.join(
      directory.path,
      uniqueName,
    );

    final File copiedFile =
        await sourceFile.copy(
      destinationPath,
    );

    return copiedFile.path;
  }


  Future<String> savePendingUploadBytes({
    required int userId,
    required int groupId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final Directory directory =
        await _getPendingUploadsDirectory(
      userId:
          userId,
      groupId:
          groupId,
    );

    final String safeName =
        _sanitizeFileName(
      fileName,
    );

    final String uniqueName =
        _generateUniqueFileName(
      safeName,
    );

    final String destinationPath =
        p.join(
      directory.path,
      uniqueName,
    );

    final File file =
        File(
      destinationPath,
    );

    await file.writeAsBytes(
      bytes,
      flush:
          true,
    );

    return file.path;
  }


  Future<bool> exists(
    String path,
  ) async {
    if (path.trim().isEmpty) {
      return false;
    }

    return File(
      path,
    ).exists();
  }


  Future<int?> getFileSize(
    String path,
  ) async {
    final File file =
        File(
      path,
    );

    if (!await file.exists()) {
      return null;
    }

    return file.length();
  }


  Future<String?> calculateSha256(
    String path,
  ) async {
    final File file =
        File(
      path,
    );

    if (!await file.exists()) {
      return null;
    }

    final Digest digest =
        await sha256
            .bind(
              file.openRead(),
            )
            .first;

    return digest
        .toString()
        .toLowerCase();
  }


  Future<bool> matchesSha256({
    required String path,
    required String expectedHash,
  }) async {
    final String normalizedExpected =
        expectedHash
            .trim()
            .toLowerCase();

    if (normalizedExpected.isEmpty) {
      return false;
    }

    final String? actual =
        await calculateSha256(
      path,
    );

    if (actual == null) {
      return false;
    }

    return actual ==
        normalizedExpected;
  }


  String getFileName(
    String path,
  ) {
    return p.basename(
      path,
    );
  }


  String getExtension(
    String path,
  ) {
    return p.extension(
      path,
    );
  }


  Future<void> delete(
    String path,
  ) async {
    if (path.trim().isEmpty) {
      return;
    }

    final File file =
        File(
      path,
    );

    if (await file.exists()) {
      await file.delete();
    }
  }


  Future<void> deleteDirectory(
    String path,
  ) async {
    if (path.trim().isEmpty) {
      return;
    }

    final Directory directory =
        Directory(
      path,
    );

    if (await directory.exists()) {
      await directory.delete(
        recursive:
            true,
      );
    }
  }


  Future<void> deleteUserFiles(
    int userId,
  ) async {
    final Directory root =
        await _getRootDirectory();

    final Directory userDirectory =
        Directory(
      p.join(
        root.path,
        'users',
        userId.toString(),
      ),
    );

    if (await userDirectory.exists()) {
      await userDirectory.delete(
        recursive:
            true,
      );
    }
  }


  Future<String> getUserStoragePath(
    int userId,
  ) async {
    final Directory directory =
        await _getUserDirectory(
      userId,
    );

    return directory.path;
  }


  Future<String> getPendingUploadDirectoryPath({
    required int userId,
    required int groupId,
  }) async {
    final Directory directory =
        await _getPendingUploadsDirectory(
      userId:
          userId,
      groupId:
          groupId,
    );

    return directory.path;
  }


  Future<String> getDownloadDirectoryPath({
    required int userId,
    required String source,
    int? remoteId,
    int? groupId,
  }) async {
    final Directory directory =
        await _getSourceDownloadDirectory(
      userId:
          userId,
      source:
          source,
      remoteId:
          remoteId,
      groupId:
          groupId,
    );

    return directory.path;
  }


  Future<String> getGroupDownloadDirectoryPath({
    required int userId,
    required int groupId,
  }) async {
    final Directory directory =
        await _getSourceDownloadDirectory(
      userId:
          userId,
      source:
          'group',
      groupId:
          groupId,
    );

    return directory.path;
  }


  String _normalizeSource(
    String source,
  ) {
    final String normalized =
        source
            .trim()
            .toLowerCase();

    if (
      normalized != 'local' &&
      normalized != 'public' &&
      normalized != 'teacher' &&
      normalized != 'group'
    ) {
      throw ArgumentError(
        'Sorgente materiale non valida.',
      );
    }

    return normalized;
  }


  String _sanitizeFileName(
    String fileName,
  ) {
    String result =
        fileName.trim();

    if (result.isEmpty) {
      result =
          'file';
    }

    result =
        result.replaceAll(
      RegExp(
        r'[\\/:*?"<>|]',
      ),
      '_',
    );

    result =
        result.replaceAll(
      RegExp(
        r'\s+',
      ),
      ' ',
    );

    result =
        result.replaceAll(
      RegExp(
        r'^\.+',
      ),
      '',
    );

    if (result.isEmpty) {
      return 'file';
    }

    return result;
  }


  String _generateUniqueFileName(
    String fileName,
  ) {
    final String extension =
        p.extension(
      fileName,
    );

    final String nameWithoutExtension =
        p.basenameWithoutExtension(
      fileName,
    );

    final int timestamp =
        DateTime.now()
            .microsecondsSinceEpoch;

    if (extension.isEmpty) {
      return '${nameWithoutExtension}_$timestamp';
    }

    return '${nameWithoutExtension}_$timestamp$extension';
  }

  Future<Uint8List?> readBytes(String path) async {
    if (path.trim().isEmpty) return null;
    final File file = File(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  Future<String> saveImportedMaterialBytes({
    required int userId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) {
      throw const FileSystemException('File vuoto.');
    }
    final Directory userDirectory = await _getUserDirectory(userId);
    final Directory directory = Directory(
      p.join(userDirectory.path, 'library', 'imported'),
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final String safeName = _sanitizeFileName(fileName);
    final String destinationPath = p.join(
      directory.path,
      _generateUniqueFileName(safeName),
    );
    final File file = File(destinationPath);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<String> saveTransientFile({
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    if (bytes.isEmpty) {
      throw const FileSystemException('File vuoto.');
    }
    final Directory root = await _getRootDirectory();
    final Directory directory = Directory(p.join(root.path, 'transient'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final String path = p.join(
      directory.path,
      _generateUniqueFileName(_sanitizeFileName(fileName)),
    );
    final File file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> openStoredFile(
    String path, {
    String? fileName,
    String? mimeType,
  }) async {
    if (!await exists(path)) {
      throw const FileSystemException('File non disponibile.');
    }
    final OpenResult result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      throw Exception('Non è stato possibile aprire il file.');
    }
  }

}