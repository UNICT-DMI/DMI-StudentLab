class MaterialSyncStateLocal {
  final int? id;

  final int userId;

  final DateTime? lastManifestAt;

  final DateTime? lastSuccessfulSyncAt;

  final DateTime updatedAt;


  const MaterialSyncStateLocal({
    this.id,
    required this.userId,
    this.lastManifestAt,
    this.lastSuccessfulSyncAt,
    required this.updatedAt,
  });


  MaterialSyncStateLocal copyWith({
    int? id,
    int? userId,
    DateTime? lastManifestAt,
    DateTime? lastSuccessfulSyncAt,
    DateTime? updatedAt,
    bool clearLastManifestAt = false,
    bool clearLastSuccessfulSyncAt = false,
  }) {
    return MaterialSyncStateLocal(
      id:
          id ??
          this.id,
      userId:
          userId ??
          this.userId,
      lastManifestAt:
          clearLastManifestAt
              ? null
              : lastManifestAt ??
                  this.lastManifestAt,
      lastSuccessfulSyncAt:
          clearLastSuccessfulSyncAt
              ? null
              : lastSuccessfulSyncAt ??
                  this.lastSuccessfulSyncAt,
      updatedAt:
          updatedAt ??
          this.updatedAt,
    );
  }


  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null)
        'id':
            id,
      'user_id':
          userId,
      'last_manifest_at':
          lastManifestAt
              ?.toUtc()
              .toIso8601String(),
      'last_successful_sync_at':
          lastSuccessfulSyncAt
              ?.toUtc()
              .toIso8601String(),
      'updated_at':
          updatedAt
              .toUtc()
              .toIso8601String(),
    };
  }


  factory MaterialSyncStateLocal.fromMap(
    Map<String, Object?> map,
  ) {
    return MaterialSyncStateLocal(
      id:
          _asInt(
        map['id'],
      ),
      userId:
          _asInt(
            map['user_id'],
          ) ??
          0,
      lastManifestAt:
          _asNullableDateTime(
        map['last_manifest_at'],
      ),
      lastSuccessfulSyncAt:
          _asNullableDateTime(
        map['last_successful_sync_at'],
      ),
      updatedAt:
          _asDateTime(
        map['updated_at'],
      ),
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
      value?.toString() ??
          '',
    );
  }


  static DateTime _asDateTime(
    Object? value,
  ) {
    final DateTime? parsed =
        DateTime.tryParse(
      value?.toString() ??
          '',
    );

    return (
      parsed ??
      DateTime.fromMillisecondsSinceEpoch(
        0,
        isUtc: true,
      )
    ).toUtc();
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