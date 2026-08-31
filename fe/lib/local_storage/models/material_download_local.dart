enum MaterialDownloadStatusLocal {
  pending,
  downloading,
  verifying,
  completed,
  failed,
}


class MaterialDownloadLocal {
  final int? id;

  final int userId;

  final int materialId;

  final MaterialDownloadStatusLocal status;

  final String? tempPath;

  final String? expectedHash;

  final int? expectedSize;

  final int downloadedBytes;

  final DateTime? startedAt;

  final DateTime? completedAt;

  final String? errorMessage;


  const MaterialDownloadLocal({
    this.id,
    required this.userId,
    required this.materialId,
    required this.status,
    this.tempPath,
    this.expectedHash,
    this.expectedSize,
    required this.downloadedBytes,
    this.startedAt,
    this.completedAt,
    this.errorMessage,
  });


  MaterialDownloadLocal copyWith({
    int? id,
    int? userId,
    int? materialId,
    MaterialDownloadStatusLocal? status,
    String? tempPath,
    String? expectedHash,
    int? expectedSize,
    int? downloadedBytes,
    DateTime? startedAt,
    DateTime? completedAt,
    String? errorMessage,
    bool clearTempPath = false,
    bool clearExpectedHash = false,
    bool clearExpectedSize = false,
    bool clearStartedAt = false,
    bool clearCompletedAt = false,
    bool clearErrorMessage = false,
  }) {
    return MaterialDownloadLocal(
      id:
          id ??
          this.id,
      userId:
          userId ??
          this.userId,
      materialId:
          materialId ??
          this.materialId,
      status:
          status ??
          this.status,
      tempPath:
          clearTempPath
              ? null
              : tempPath ??
                  this.tempPath,
      expectedHash:
          clearExpectedHash
              ? null
              : expectedHash ??
                  this.expectedHash,
      expectedSize:
          clearExpectedSize
              ? null
              : expectedSize ??
                  this.expectedSize,
      downloadedBytes:
          downloadedBytes ??
          this.downloadedBytes,
      startedAt:
          clearStartedAt
              ? null
              : startedAt ??
                  this.startedAt,
      completedAt:
          clearCompletedAt
              ? null
              : completedAt ??
                  this.completedAt,
      errorMessage:
          clearErrorMessage
              ? null
              : errorMessage ??
                  this.errorMessage,
    );
  }


  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null)
        'id':
            id,
      'user_id':
          userId,
      'material_id':
          materialId,
      'status':
          status.name,
      'temp_path':
          tempPath,
      'expected_hash':
          expectedHash,
      'expected_size':
          expectedSize,
      'downloaded_bytes':
          downloadedBytes,
      'started_at':
          startedAt
              ?.toUtc()
              .toIso8601String(),
      'completed_at':
          completedAt
              ?.toUtc()
              .toIso8601String(),
      'error_message':
          errorMessage,
    };
  }


  factory MaterialDownloadLocal.fromMap(
    Map<String, Object?> map,
  ) {
    return MaterialDownloadLocal(
      id:
          _asInt(
        map['id'],
      ),
      userId:
          _asInt(
            map['user_id'],
          ) ??
          0,
      materialId:
          _asInt(
            map['material_id'],
          ) ??
          0,
      status:
          _statusFromString(
        map['status']
            ?.toString(),
      ),
      tempPath:
          map['temp_path']
              ?.toString(),
      expectedHash:
          map['expected_hash']
              ?.toString(),
      expectedSize:
          _asInt(
        map['expected_size'],
      ),
      downloadedBytes:
          _asInt(
            map['downloaded_bytes'],
          ) ??
          0,
      startedAt:
          _asNullableDateTime(
        map['started_at'],
      ),
      completedAt:
          _asNullableDateTime(
        map['completed_at'],
      ),
      errorMessage:
          map['error_message']
              ?.toString(),
    );
  }


  static MaterialDownloadStatusLocal _statusFromString(
    String? value,
  ) {
    for (
      final MaterialDownloadStatusLocal status
      in MaterialDownloadStatusLocal.values
    ) {
      if (status.name == value) {
        return status;
      }
    }

    return MaterialDownloadStatusLocal.pending;
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


  static DateTime? _asNullableDateTime(
    Object? value,
  ) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(
      value.toString(),
    )?.toUtc();
  }
}