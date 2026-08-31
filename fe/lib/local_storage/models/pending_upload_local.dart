// =============================================================================
// STATO UPLOAD LOCALE
// =============================================================================

enum PendingUploadStatus {
  pending,
  uploading,
  uploaded,
  failed,
}


// =============================================================================
// PENDING UPLOAD LOCAL
// =============================================================================

class PendingUploadLocal {
  final int? id;

  final int userId;

  final int groupId;

  final String localPath;

  final String originalName;

  final String? mimeType;

  final int? size;

  final PendingUploadStatus status;

  final DateTime createdAt;

  final DateTime? uploadedAt;

  final int? serverMaterialId;

  final String? errorMessage;

  final int retryCount;

  final DateTime? lastAttemptAt;


  const PendingUploadLocal({
    this.id,

    required this.userId,

    required this.groupId,

    required this.localPath,

    required this.originalName,

    this.mimeType,

    this.size,

    this.status = PendingUploadStatus.pending,

    required this.createdAt,

    this.uploadedAt,

    this.serverMaterialId,

    this.errorMessage,

    this.retryCount = 0,

    this.lastAttemptAt,
  });


  // ===========================================================================
  // TO MAP
  // ===========================================================================

  Map<String, dynamic> toMap() {
    return {
      'id':
          id,

      'user_id':
          userId,

      'group_id':
          groupId,

      'local_path':
          localPath,

      'original_name':
          originalName,

      'mime_type':
          mimeType,

      'size':
          size,

      'status':
          status.name,

      'created_at':
          createdAt.toIso8601String(),

      'uploaded_at':
          uploadedAt?.toIso8601String(),

      'server_material_id':
          serverMaterialId,

      'error_message':
          errorMessage,

      'retry_count':
          retryCount,

      'last_attempt_at':
          lastAttemptAt?.toIso8601String(),
    };
  }


  // ===========================================================================
  // FROM MAP
  // ===========================================================================

  factory PendingUploadLocal.fromMap(
    Map<String, dynamic> map,
  ) {
    return PendingUploadLocal(
      id:
          _toNullableInt(
        map['id'],
      ),

      userId:
          _toInt(
        map['user_id'],
      ),

      groupId:
          _toInt(
        map['group_id'],
      ),

      localPath:
          map['local_path']
                  ?.toString() ??
              '',

      originalName:
          map['original_name']
                  ?.toString() ??
              '',

      mimeType:
          map['mime_type']
              ?.toString(),

      size:
          _toNullableInt(
        map['size'],
      ),

      status:
          _statusFromString(
        map['status']
            ?.toString(),
      ),

      createdAt:
          _toDateTime(
        map['created_at'],
      ),

      uploadedAt:
          _toNullableDateTime(
        map['uploaded_at'],
      ),

      serverMaterialId:
          _toNullableInt(
        map['server_material_id'],
      ),

      errorMessage:
          map['error_message']
              ?.toString(),

      retryCount:
          _toInt(
        map['retry_count'],
      ),

      lastAttemptAt:
          _toNullableDateTime(
        map['last_attempt_at'],
      ),
    );
  }


  // ===========================================================================
  // COPY WITH
  // ===========================================================================

  PendingUploadLocal copyWith({
    int? id,

    int? userId,

    int? groupId,

    String? localPath,

    String? originalName,

    String? mimeType,

    bool clearMimeType = false,

    int? size,

    bool clearSize = false,

    PendingUploadStatus? status,

    DateTime? createdAt,

    DateTime? uploadedAt,

    bool clearUploadedAt = false,

    int? serverMaterialId,

    bool clearServerMaterialId = false,

    String? errorMessage,

    bool clearErrorMessage = false,

    int? retryCount,

    DateTime? lastAttemptAt,

    bool clearLastAttemptAt = false,
  }) {
    return PendingUploadLocal(
      id:
          id ??
              this.id,

      userId:
          userId ??
              this.userId,

      groupId:
          groupId ??
              this.groupId,

      localPath:
          localPath ??
              this.localPath,

      originalName:
          originalName ??
              this.originalName,

      mimeType:
          clearMimeType
              ? null
              : mimeType ??
                  this.mimeType,

      size:
          clearSize
              ? null
              : size ??
                  this.size,

      status:
          status ??
              this.status,

      createdAt:
          createdAt ??
              this.createdAt,

      uploadedAt:
          clearUploadedAt
              ? null
              : uploadedAt ??
                  this.uploadedAt,

      serverMaterialId:
          clearServerMaterialId
              ? null
              : serverMaterialId ??
                  this.serverMaterialId,

      errorMessage:
          clearErrorMessage
              ? null
              : errorMessage ??
                  this.errorMessage,

      retryCount:
          retryCount ??
              this.retryCount,

      lastAttemptAt:
          clearLastAttemptAt
              ? null
              : lastAttemptAt ??
                  this.lastAttemptAt,
    );
  }


  // ===========================================================================
  // HELPERS STATO
  // ===========================================================================

  bool get isPending {
    return status ==
        PendingUploadStatus.pending;
  }


  bool get isUploading {
    return status ==
        PendingUploadStatus.uploading;
  }


  bool get isUploaded {
    return status ==
        PendingUploadStatus.uploaded;
  }


  bool get isFailed {
    return status ==
        PendingUploadStatus.failed;
  }


  // ===========================================================================
  // HELPERS RETRY
  // ===========================================================================

  bool get hasBeenRetried {
    return retryCount > 0;
  }


  bool get canRetry {
    return status ==
            PendingUploadStatus.failed ||
        status ==
            PendingUploadStatus.pending;
  }


  // ===========================================================================
  // UTILITY STATUS
  // ===========================================================================

  static PendingUploadStatus _statusFromString(
    String? value,
  ) {
    switch (
        value?.toLowerCase()) {
      case 'uploading':
        return PendingUploadStatus.uploading;

      case 'uploaded':
        return PendingUploadStatus.uploaded;

      case 'failed':
        return PendingUploadStatus.failed;

      case 'pending':
      default:
        return PendingUploadStatus.pending;
    }
  }


  // ===========================================================================
  // UTILITY INT
  // ===========================================================================

  static int _toInt(
    dynamic value,
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
        ) ??
        0;
  }


  static int? _toNullableInt(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value.toString(),
    );
  }


  // ===========================================================================
  // UTILITY DATETIME
  // ===========================================================================

  static DateTime _toDateTime(
    dynamic value,
  ) {
    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(
          value?.toString() ??
              '',
        ) ??
        DateTime.now();
  }


  static DateTime? _toNullableDateTime(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    final String text =
        value.toString();

    if (text.isEmpty) {
      return null;
    }

    return DateTime.tryParse(
      text,
    );
  }
}