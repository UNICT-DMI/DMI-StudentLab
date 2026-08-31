class MaterialFileLocal {
  final int? id;
  final String localPath;
  final String? fileHash;
  final int? size;
  final String? mimeType;
  final bool existsLocally;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MaterialFileLocal({
    this.id,
    required this.localPath,
    this.fileHash,
    this.size,
    this.mimeType,
    required this.existsLocally,
    required this.createdAt,
    required this.updatedAt,
  });

  MaterialFileLocal copyWith({
    int? id,
    String? localPath,
    String? fileHash,
    int? size,
    String? mimeType,
    bool? existsLocally,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearFileHash = false,
    bool clearSize = false,
    bool clearMimeType = false,
  }) {
    return MaterialFileLocal(
      id: id ?? this.id,
      localPath: localPath ?? this.localPath,
      fileHash: clearFileHash
          ? null
          : fileHash ?? this.fileHash,
      size: clearSize
          ? null
          : size ?? this.size,
      mimeType: clearMimeType
          ? null
          : mimeType ?? this.mimeType,
      existsLocally:
          existsLocally ?? this.existsLocally,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'local_path': localPath,
      'file_hash': fileHash,
      'size': size,
      'mime_type': mimeType,
      'exists_locally':
          existsLocally ? 1 : 0,
      'created_at':
          createdAt.toUtc().toIso8601String(),
      'updated_at':
          updatedAt.toUtc().toIso8601String(),
    };
  }

  factory MaterialFileLocal.fromMap(
    Map<String, Object?> map,
  ) {
    return MaterialFileLocal(
      id: _asInt(map['id']),
      localPath:
          map['local_path']?.toString() ?? '',
      fileHash:
          map['file_hash']?.toString(),
      size: _asInt(map['size']),
      mimeType:
          map['mime_type']?.toString(),
      existsLocally:
          _asBool(map['exists_locally']),
      createdAt:
          _asDateTime(map['created_at']),
      updatedAt:
          _asDateTime(map['updated_at']),
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
      value?.toString() ?? '',
    );
  }

  static bool _asBool(
    Object? value,
  ) {
    if (value is bool) {
      return value;
    }

    return _asInt(value) == 1;
  }

  static DateTime _asDateTime(
    Object? value,
  ) {
    final DateTime? parsed =
        DateTime.tryParse(
      value?.toString() ?? '',
    );

    return (
      parsed ??
          DateTime.fromMillisecondsSinceEpoch(
            0,
            isUtc: true,
          )
    ).toUtc();
  }
}