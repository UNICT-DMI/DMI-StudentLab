enum MaterialSourceLocal {
  local,
  public,
  teacher,
  group,
}


class MaterialLocal {
  final int? id;

  final int userId;

  final MaterialSourceLocal source;

  final String? remoteKey;

  final int? remoteId;

  final int? subjectId;

  final int? groupId;

  final String? university;

  final String? department;

  final String? course;

  final String? subjectName;

  final String originalName;

  final int? fileId;

  final int? remoteVersion;

  final String? remoteStatus;

  final bool isAvailableRemote;

  final bool isPersonal;

  final DateTime createdAt;

  final DateTime updatedAt;

  final DateTime? lastSyncedAt;


  const MaterialLocal({
    this.id,
    required this.userId,
    required this.source,
    this.remoteKey,
    this.remoteId,
    this.subjectId,
    this.groupId,
    this.university,
    this.department,
    this.course,
    this.subjectName,
    required this.originalName,
    this.fileId,
    this.remoteVersion,
    this.remoteStatus,
    required this.isAvailableRemote,
    required this.isPersonal,
    required this.createdAt,
    required this.updatedAt,
    this.lastSyncedAt,
  });


  bool get isRemote =>
      source !=
      MaterialSourceLocal.local;


  bool get isDownloaded =>
      fileId !=
      null;


  MaterialLocal copyWith({
    int? id,
    int? userId,
    MaterialSourceLocal? source,
    String? remoteKey,
    int? remoteId,
    int? subjectId,
    int? groupId,
    String? university,
    String? department,
    String? course,
    String? subjectName,
    String? originalName,
    int? fileId,
    int? remoteVersion,
    String? remoteStatus,
    bool? isAvailableRemote,
    bool? isPersonal,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastSyncedAt,
    bool clearRemoteKey = false,
    bool clearRemoteId = false,
    bool clearSubjectId = false,
    bool clearGroupId = false,
    bool clearUniversity = false,
    bool clearDepartment = false,
    bool clearCourse = false,
    bool clearSubjectName = false,
    bool clearFileId = false,
    bool clearRemoteVersion = false,
    bool clearRemoteStatus = false,
    bool clearLastSyncedAt = false,
  }) {
    return MaterialLocal(
      id:
          id ??
          this.id,
      userId:
          userId ??
          this.userId,
      source:
          source ??
          this.source,
      remoteKey:
          clearRemoteKey
              ? null
              : remoteKey ??
                  this.remoteKey,
      remoteId:
          clearRemoteId
              ? null
              : remoteId ??
                  this.remoteId,
      subjectId:
          clearSubjectId
              ? null
              : subjectId ??
                  this.subjectId,
      groupId:
          clearGroupId
              ? null
              : groupId ??
                  this.groupId,
      university:
          clearUniversity
              ? null
              : university ??
                  this.university,
      department:
          clearDepartment
              ? null
              : department ??
                  this.department,
      course:
          clearCourse
              ? null
              : course ??
                  this.course,
      subjectName:
          clearSubjectName
              ? null
              : subjectName ??
                  this.subjectName,
      originalName:
          originalName ??
          this.originalName,
      fileId:
          clearFileId
              ? null
              : fileId ??
                  this.fileId,
      remoteVersion:
          clearRemoteVersion
              ? null
              : remoteVersion ??
                  this.remoteVersion,
      remoteStatus:
          clearRemoteStatus
              ? null
              : remoteStatus ??
                  this.remoteStatus,
      isAvailableRemote:
          isAvailableRemote ??
          this.isAvailableRemote,
      isPersonal:
          isPersonal ??
          this.isPersonal,
      createdAt:
          createdAt ??
          this.createdAt,
      updatedAt:
          updatedAt ??
          this.updatedAt,
      lastSyncedAt:
          clearLastSyncedAt
              ? null
              : lastSyncedAt ??
                  this.lastSyncedAt,
    );
  }


  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null)
        'id':
            id,
      'user_id':
          userId,
      'source':
          source.name,
      'remote_key':
          remoteKey,
      'remote_id':
          remoteId,
      'subject_id':
          subjectId,
      'group_id':
          groupId,
      'university':
          university,
      'department':
          department,
      'course':
          course,
      'subject_name':
          subjectName,
      'original_name':
          originalName,
      'file_id':
          fileId,
      'remote_version':
          remoteVersion,
      'remote_status':
          remoteStatus,
      'is_available_remote':
          isAvailableRemote
              ? 1
              : 0,
      'is_personal':
          isPersonal
              ? 1
              : 0,
      'created_at':
          createdAt
              .toUtc()
              .toIso8601String(),
      'updated_at':
          updatedAt
              .toUtc()
              .toIso8601String(),
      'last_synced_at':
          lastSyncedAt
              ?.toUtc()
              .toIso8601String(),
    };
  }


  factory MaterialLocal.fromMap(
    Map<String, Object?> map,
  ) {
    return MaterialLocal(
      id:
          _asInt(
        map['id'],
      ),
      userId:
          _asInt(
            map['user_id'],
          ) ??
          0,
      source:
          _sourceFromString(
        map['source']
            ?.toString(),
      ),
      remoteKey:
          map['remote_key']
              ?.toString(),
      remoteId:
          _asInt(
        map['remote_id'],
      ),
      subjectId:
          _asInt(
        map['subject_id'],
      ),
      groupId:
          _asInt(
        map['group_id'],
      ),
      university:
          map['university']
              ?.toString(),
      department:
          map['department']
              ?.toString(),
      course:
          map['course']
              ?.toString(),
      subjectName:
          map['subject_name']
              ?.toString(),
      originalName:
          map['original_name']
              ?.toString() ??
          '',
      fileId:
          _asInt(
        map['file_id'],
      ),
      remoteVersion:
          _asInt(
        map['remote_version'],
      ),
      remoteStatus:
          map['remote_status']
              ?.toString(),
      isAvailableRemote:
          _asBool(
        map['is_available_remote'],
      ),
      isPersonal:
          _asBool(
        map['is_personal'],
      ),
      createdAt:
          _asDateTime(
        map['created_at'],
      ),
      updatedAt:
          _asDateTime(
        map['updated_at'],
      ),
      lastSyncedAt:
          _asNullableDateTime(
        map['last_synced_at'],
      ),
    );
  }


  static MaterialSourceLocal _sourceFromString(
    String? value,
  ) {
    for (
      final MaterialSourceLocal source
      in MaterialSourceLocal.values
    ) {
      if (source.name == value) {
        return source;
      }
    }

    return MaterialSourceLocal.local;
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


  static bool _asBool(
    Object? value,
  ) {
    if (value is bool) {
      return value;
    }

    return _asInt(
          value,
        ) ==
        1;
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