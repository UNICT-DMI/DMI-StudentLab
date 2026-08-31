import 'dart:typed_data';

import '../../services/api_service.dart';

import '../models/pending_upload_local.dart';
import '../repositories/pending_upload_repository.dart';

import 'local_file_service.dart';

class PendingUploadService {
  final ApiService _apiService;

  final PendingUploadRepository _repository;

  final LocalFileService _fileService;

  PendingUploadService({
    ApiService? apiService,
    PendingUploadRepository? repository,
    LocalFileService? fileService,
  })  : _apiService =
            apiService ??
                ApiService(),
        _repository =
            repository ??
                PendingUploadRepository(),
        _fileService =
            fileService ??
                LocalFileService();

  Future<PendingUploadLocal>
      createFromFile({
    required int userId,
    required int groupId,
    required String sourcePath,
    required String originalName,
    String? mimeType,
    int? size,
  }) async {
    final bool sourceExists =
        await _fileService.exists(sourcePath);

    if (!sourceExists) {
      throw StateError('Il file selezionato non esiste.');
    }

    final int? sourceSizeValue =
        await _fileService.getFileSize(sourcePath);

    final int sourceSize = sourceSizeValue ?? 0;

    if (sourceSize <= 0) {
      throw StateError('Il file selezionato è vuoto.');
    }

    final String normalizedName =
        _normalizeOriginalName(
      originalName,
      sourcePath:
          sourcePath,
    );

    final String localPath =
        await _fileService
            .copyToPendingUpload(
      userId:
          userId,
      groupId:
          groupId,
      sourcePath:
          sourcePath,
      preferredFileName:
          normalizedName,
    );

    final int? copiedSize =
        await _fileService
            .getFileSize(
      localPath,
    );

    if (
      copiedSize == null ||
      copiedSize <= 0
    ) {
      await _fileService.delete(
        localPath,
      );

      throw StateError('Non è stato possibile preparare il file per il caricamento.');
    }

    if (
      size != null &&
      size > 0 &&
      copiedSize != size
    ) {
      await _fileService.delete(
        localPath,
      );

      throw StateError('La dimensione del file preparato non corrisponde al file selezionato.');
    }

    final PendingUploadLocal upload =
        PendingUploadLocal(
      userId:
          userId,
      groupId:
          groupId,
      localPath:
          localPath,
      originalName:
          normalizedName,
      mimeType:
          mimeType,
      size:
          copiedSize,
      status:
          PendingUploadStatus.pending,
      createdAt:
          DateTime.now()
              .toUtc(),
      retryCount:
          0,
    );

    try {
      final int id =
          await _repository.insert(
        upload,
      );

      return upload.copyWith(
        id:
            id,
      );
    } catch (_) {
      await _fileService.delete(
        localPath,
      );

      rethrow;
    }
  }

  Future<PendingUploadLocal>
      createFromBytes({
    required int userId,
    required int groupId,
    required String originalName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError(
        'Il file da caricare è vuoto.',
      );
    }

    final String normalizedName =
        _normalizeOriginalName(
      originalName,
    );

    final String localPath =
        await _fileService
            .savePendingUploadBytes(
      userId:
          userId,
      groupId:
          groupId,
      fileName:
          normalizedName,
      bytes:
          bytes,
    );

    final int? savedSize =
        await _fileService
            .getFileSize(
      localPath,
    );

    if (
      savedSize == null ||
      savedSize != bytes.length
    ) {
      await _fileService.delete(
        localPath,
      );

      throw StateError('Non è stato possibile salvare correttamente il file da caricare.');
    }

    final PendingUploadLocal upload =
        PendingUploadLocal(
      userId:
          userId,
      groupId:
          groupId,
      localPath:
          localPath,
      originalName:
          normalizedName,
      mimeType:
          mimeType,
      size:
          savedSize,
      status:
          PendingUploadStatus.pending,
      createdAt:
          DateTime.now()
              .toUtc(),
      retryCount:
          0,
    );

    try {
      final int id =
          await _repository.insert(
        upload,
      );

      return upload.copyWith(
        id:
            id,
      );
    } catch (_) {
      await _fileService.delete(
        localPath,
      );

      rethrow;
    }
  }

  Future<PendingUploadLocal> upload(
    PendingUploadLocal upload,
  ) async {
    if (upload.id == null) {
      throw ArgumentError(
        'Upload locale senza id.',
      );
    }

    if (upload.isUploaded) {
      return upload;
    }

    final PendingUploadLocal? current =
        await _repository.getById(
      upload.id!,
    );

    if (current == null) {
      throw StateError(
        'Upload locale non più disponibile.',
      );
    }

    if (current.isUploaded) {
      return current;
    }

    final bool exists =
        await _fileService.exists(
      current.localPath,
    );

    if (!exists) {
      final PendingUploadLocal failed =
          current.copyWith(
        status:
            PendingUploadStatus.failed,
        errorMessage:
            'Il file locale non esiste più.',
        retryCount:
            current.retryCount + 1,
        lastAttemptAt:
            DateTime.now()
                .toUtc(),
        clearUploadedAt:
            true,
        clearServerMaterialId:
            true,
      );

      await _repository.update(
        failed,
      );

      return failed;
    }

    final int? actualSize =
        await _fileService
            .getFileSize(
      current.localPath,
    );

    if (
      actualSize == null ||
      actualSize <= 0
    ) {
      final PendingUploadLocal failed =
          current.copyWith(
        status:
            PendingUploadStatus.failed,
        errorMessage:
            'Il file locale è vuoto o non leggibile.',
        retryCount:
            current.retryCount + 1,
        lastAttemptAt:
            DateTime.now()
                .toUtc(),
        clearUploadedAt:
            true,
        clearServerMaterialId:
            true,
      );

      await _repository.update(
        failed,
      );

      return failed;
    }

    final DateTime attemptTime =
        DateTime.now()
            .toUtc();

    final PendingUploadLocal uploading =
        current.copyWith(
      status:
          PendingUploadStatus.uploading,
      size:
          actualSize,
      retryCount:
          current.retryCount + 1,
      lastAttemptAt:
          attemptTime,
      clearErrorMessage:
          true,
      clearUploadedAt:
          true,
      clearServerMaterialId:
          true,
    );

    await _repository.update(
      uploading,
    );

    try {
      final Uint8List? bytes =
          await _fileService.readBytes(uploading.localPath);

      if (bytes == null || bytes.isEmpty) {
        throw StateError('Il file locale non è disponibile.');
      }

      final Map<String, dynamic> result =
          await _apiService.addGroupMaterialBytes(
        groupId: uploading.groupId,
        bytes: bytes,
        originalName: uploading.originalName,
        mimeType: uploading.mimeType,
      );

      final int serverMaterialId =
          _extractServerMaterialId(
        result,
      );

      final PendingUploadLocal uploaded =
          uploading.copyWith(
        status:
            PendingUploadStatus.uploaded,
        uploadedAt:
            DateTime.now()
                .toUtc(),
        serverMaterialId:
            serverMaterialId,
        clearErrorMessage:
            true,
      );

      await _repository.update(
        uploaded,
      );

      return uploaded;
    } catch (error) {
      final PendingUploadLocal failed =
          uploading.copyWith(
        status:
            PendingUploadStatus.failed,
        errorMessage:
            _friendlyUploadError(
          error,
        ),
        clearUploadedAt:
            true,
        clearServerMaterialId:
            true,
      );

      await _repository.update(
        failed,
      );

      return failed;
    }
  }

  Future<PendingUploadLocal?> retry(
    int uploadId,
  ) async {
    final PendingUploadLocal? existing =
        await _repository.getById(
      uploadId,
    );

    if (existing == null) {
      return null;
    }

    if (existing.isUploaded) {
      return existing;
    }

    final bool exists =
        await _fileService.exists(
      existing.localPath,
    );

    if (!exists) {
      final PendingUploadLocal failed =
          existing.copyWith(
        status:
            PendingUploadStatus.failed,
        errorMessage:
            'Il file locale non esiste più.',
        clearUploadedAt:
            true,
        clearServerMaterialId:
            true,
      );

      await _repository.update(
        failed,
      );

      return failed;
    }

    final PendingUploadLocal pending =
        existing.copyWith(
      status:
          PendingUploadStatus.pending,
      clearErrorMessage:
          true,
      clearUploadedAt:
          true,
      clearServerMaterialId:
          true,
    );

    await _repository.update(
      pending,
    );

    return upload(
      pending,
    );
  }

  Future<List<PendingUploadLocal>>
      syncWaiting(
    int userId,
  ) async {
    await _repository
        .resetInterruptedUploads(
      userId,
    );

    final List<PendingUploadLocal>
        waiting =
        await _repository
            .getWaitingForSync(
      userId,
    );

    final List<PendingUploadLocal>
        results =
        <PendingUploadLocal>[];

    for (
      final PendingUploadLocal item
      in waiting
    ) {
      final PendingUploadLocal result =
          await upload(
        item,
      );

      results.add(
        result,
      );
    }

    return results;
  }

  Future<PendingUploadLocal?> getById(
    int uploadId,
  ) {
    return _repository.getById(
      uploadId,
    );
  }

  Future<List<PendingUploadLocal>>
      getByUser(
    int userId,
  ) {
    return _repository.getByUser(
      userId,
    );
  }

  Future<List<PendingUploadLocal>>
      getByGroup({
    required int userId,
    required int groupId,
  }) {
    return _repository.getByGroup(
      userId:
          userId,
      groupId:
          groupId,
    );
  }

  Future<List<PendingUploadLocal>>
      getWaiting(
    int userId,
  ) {
    return _repository
        .getWaitingForSync(
      userId,
    );
  }

  Future<List<PendingUploadLocal>>
      getFailed(
    int userId,
  ) {
    return _repository.getFailed(
      userId,
    );
  }

  Future<int> countWaiting(
    int userId,
  ) {
    return _repository.countWaiting(
      userId,
    );
  }

  Future<void> remove(
    int uploadId,
  ) async {
    final PendingUploadLocal? upload =
        await _repository.getById(
      uploadId,
    );

    if (upload == null) {
      return;
    }

    try {
      await _fileService.delete(
        upload.localPath,
      );
    } finally {
      await _repository.delete(
        uploadId,
      );
    }
  }

  Future<int> clearUploaded(
    int userId,
  ) async {
    final List<PendingUploadLocal>
        uploads =
        await _repository.getByUser(
      userId,
    );

    for (
      final PendingUploadLocal upload
      in uploads
    ) {
      if (!upload.isUploaded) {
        continue;
      }

      await _fileService.delete(
        upload.localPath,
      );
    }

    return _repository.deleteUploaded(
      userId,
    );
  }

  Future<void>
      resetInterruptedUploads(
    int userId,
  ) async {
    await _repository
        .resetInterruptedUploads(
      userId,
    );
  }

  Future<bool> fileExists(
    PendingUploadLocal upload,
  ) {
    return _fileService.exists(
      upload.localPath,
    );
  }

  Future<String?> getFile(
    PendingUploadLocal upload,
  ) async {
    return await _fileService.exists(upload.localPath)
        ? upload.localPath
        : null;
  }


  String _normalizeOriginalName(
    String originalName, {
    String? sourcePath,
  }) {
    final String normalized =
        originalName
            .trim();

    if (normalized.isNotEmpty) {
      return normalized;
    }

    if (
      sourcePath != null &&
      sourcePath.trim().isNotEmpty
    ) {
      final String path =
          sourcePath.replaceAll(
        '\\',
        '/',
      );

      final List<String> segments =
          path.split(
        '/',
      );

      if (
        segments.isNotEmpty &&
        segments.last.trim().isNotEmpty
      ) {
        return segments.last.trim();
      }
    }

    return 'materiale';
  }

  String _friendlyUploadError(
    Object error,
  ) {
    final String value =
        error.toString().toLowerCase();

    if (
      value.contains('sessione') ||
      value.contains('autentic') ||
      value.contains('401')
    ) {
      return 'La sessione è scaduta. Accedi nuovamente.';
    }

    if (
      value.contains('non autorizz') ||
      value.contains('403')
    ) {
      return 'Non hai i permessi per caricare questo materiale.';
    }

    if (
      value.contains('dimensione massima') ||
      value.contains('250 mb') ||
      value.contains('too large')
    ) {
      return 'Il file supera la dimensione massima consentita.';
    }

    if (
      value.contains('tipo di file') ||
      value.contains('mime') ||
      value.contains('unsupported')
    ) {
      return 'Questo tipo di file non è supportato.';
    }

    if (
      value.contains('non esiste') ||
      value.contains('non disponibile') ||
      value.contains('not found')
    ) {
      return 'Il file o il gruppo non è più disponibile.';
    }

    if (
      value.contains('timeout') ||
      value.contains('socket') ||
      value.contains('network') ||
      value.contains('connection')
    ) {
      return 'Connessione non disponibile. Riprova quando sei online.';
    }

    return 'Non è stato possibile caricare il materiale. Riprova.';
  }

  int _extractServerMaterialId(
    Map<String, dynamic> result,
  ) {
    final dynamic value =
        result['id'] ??
        result['material_id'];

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    final int? parsed =
        int.tryParse(
      value?.toString() ??
          '',
    );

    if (parsed != null) {
      return parsed;
    }

    throw StateError(
      'Upload completato ma il server non ha restituito un id materiale valido.',
    );
  }
}