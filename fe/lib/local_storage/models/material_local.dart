import 'dart:convert';

enum MaterialSourceLocal {
  local,
  public,
  teacher,
  group,
  personalSync,
  sharedUser,
}

extension MaterialSourceLocalCodec on MaterialSourceLocal {
  String get storageValue {
    switch (this) {
      case MaterialSourceLocal.personalSync:
        return 'personal_sync';
      case MaterialSourceLocal.sharedUser:
        return 'shared_user';
      default:
        return name;
    }
  }

  static MaterialSourceLocal parse(Object? value) {
    switch (value?.toString()) {
      case 'public':
        return MaterialSourceLocal.public;
      case 'teacher':
        return MaterialSourceLocal.teacher;
      case 'group':
        return MaterialSourceLocal.group;
      case 'personal_sync':
        return MaterialSourceLocal.personalSync;
      case 'shared_user':
        return MaterialSourceLocal.sharedUser;
      default:
        return MaterialSourceLocal.local;
    }
  }
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
  final String courseScope;
  final List<String> pathSegments;
  final String? remoteFileHash;
  final String originalName;
  final int? fileId;
  final int? remoteVersion;
  final String? remoteStatus;
  final bool isAvailableRemote;
  final bool isPersonal;
  final String? cloudPolicy;
  final DateTime? cloudExpiresAt;
  final String? retentionStatus;
  final int? sharedByUserId;
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
    this.courseScope = 'degree',
    this.pathSegments = const <String>[],
    this.remoteFileHash,
    required this.originalName,
    this.fileId,
    this.remoteVersion,
    this.remoteStatus,
    required this.isAvailableRemote,
    required this.isPersonal,
    this.cloudPolicy,
    this.cloudExpiresAt,
    this.retentionStatus,
    this.sharedByUserId,
    required this.createdAt,
    required this.updatedAt,
    this.lastSyncedAt,
  });

  bool get isLocal => source == MaterialSourceLocal.local;
  bool get isPersonalSynced => source == MaterialSourceLocal.personalSync;
  bool get isShared => source == MaterialSourceLocal.sharedUser;
  bool get hasRemoteCopy => isAvailableRemote && remoteId != null;
  String get displayUniversity =>
      university?.trim().isNotEmpty == true ? university!.trim() : 'Altro';
  String get displayDepartment =>
      department?.trim().isNotEmpty == true ? department!.trim() : 'Altro';
  String get displayCourse =>
      course?.trim().isNotEmpty == true ? course!.trim() : 'Altro';
  String get displaySubjectName => subjectName?.trim().isNotEmpty == true
      ? subjectName!.trim()
      : 'Materiale';

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
    String? courseScope,
    List<String>? pathSegments,
    String? remoteFileHash,
    String? originalName,
    int? fileId,
    int? remoteVersion,
    String? remoteStatus,
    bool? isAvailableRemote,
    bool? isPersonal,
    String? cloudPolicy,
    DateTime? cloudExpiresAt,
    String? retentionStatus,
    int? sharedByUserId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastSyncedAt,
    bool clearFileId = false,
  }) {
    return MaterialLocal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      source: source ?? this.source,
      remoteKey: remoteKey ?? this.remoteKey,
      remoteId: remoteId ?? this.remoteId,
      subjectId: subjectId ?? this.subjectId,
      groupId: groupId ?? this.groupId,
      university: university ?? this.university,
      department: department ?? this.department,
      course: course ?? this.course,
      subjectName: subjectName ?? this.subjectName,
      courseScope: courseScope ?? this.courseScope,
      pathSegments: pathSegments ?? this.pathSegments,
      remoteFileHash: remoteFileHash ?? this.remoteFileHash,
      originalName: originalName ?? this.originalName,
      fileId: clearFileId ? null : fileId ?? this.fileId,
      remoteVersion: remoteVersion ?? this.remoteVersion,
      remoteStatus: remoteStatus ?? this.remoteStatus,
      isAvailableRemote: isAvailableRemote ?? this.isAvailableRemote,
      isPersonal: isPersonal ?? this.isPersonal,
      cloudPolicy: cloudPolicy ?? this.cloudPolicy,
      cloudExpiresAt: cloudExpiresAt ?? this.cloudExpiresAt,
      retentionStatus: retentionStatus ?? this.retentionStatus,
      sharedByUserId: sharedByUserId ?? this.sharedByUserId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'source': source.storageValue,
      'remote_key': remoteKey,
      'remote_id': remoteId,
      'subject_id': subjectId,
      'group_id': groupId,
      'university': university,
      'department': department,
      'course': course,
      'subject_name': subjectName,
      'course_scope': courseScope,
      'path_segments_json': jsonEncode(pathSegments),
      'remote_file_hash': remoteFileHash,
      'original_name': originalName,
      'file_id': fileId,
      'remote_version': remoteVersion,
      'remote_status': remoteStatus,
      'is_available_remote': isAvailableRemote ? 1 : 0,
      'is_personal': isPersonal ? 1 : 0,
      'cloud_policy': cloudPolicy,
      'cloud_expires_at': cloudExpiresAt?.toUtc().toIso8601String(),
      'retention_status': retentionStatus,
      'shared_by_user_id': sharedByUserId,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'last_synced_at': lastSyncedAt?.toUtc().toIso8601String(),
    };
  }

  static List<String> _readPathSegments(Object? value) {
    if (value == null) return const <String>[];
    try {
      final dynamic decoded = jsonDecode(value.toString());
      if (decoded is List) return decoded.whereType<String>().toList();
    } catch (_) { /* Rows created before v13 have no path. */ }
    return const <String>[];
  }

  factory MaterialLocal.fromMap(Map<String, Object?> map) {
    int? asInt(Object? v) => v is int
        ? v
        : v is num
        ? v.toInt()
        : int.tryParse(v?.toString() ?? '');
    DateTime date(Object? v) =>
        DateTime.tryParse(v?.toString() ?? '')?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    DateTime? nullableDate(Object? v) =>
        v == null ? null : DateTime.tryParse(v.toString())?.toUtc();
    bool asBool(Object? v) =>
        v == true ||
        v == 1 ||
        v?.toString() == '1' ||
        v?.toString().toLowerCase() == 'true';
    return MaterialLocal(
      id: asInt(map['id']),
      userId: asInt(map['user_id']) ?? 0,
      source: MaterialSourceLocalCodec.parse(map['source']),
      remoteKey: map['remote_key']?.toString(),
      remoteId: asInt(map['remote_id']),
      subjectId: asInt(map['subject_id']),
      groupId: asInt(map['group_id']),
      university: map['university']?.toString(),
      department: map['department']?.toString(),
      course: map['course']?.toString(),
      subjectName: map['subject_name']?.toString(),
      courseScope: map['course_scope']?.toString() == 'additional' ? 'additional' : 'degree',
      pathSegments: _readPathSegments(map['path_segments_json']),
      remoteFileHash: map['remote_file_hash']?.toString(),
      originalName: map['original_name']?.toString() ?? 'Materiale',
      fileId: asInt(map['file_id']),
      remoteVersion: asInt(map['remote_version']),
      remoteStatus: map['remote_status']?.toString(),
      isAvailableRemote: asBool(map['is_available_remote']),
      isPersonal: asBool(map['is_personal']),
      cloudPolicy: map['cloud_policy']?.toString(),
      cloudExpiresAt: nullableDate(map['cloud_expires_at']),
      retentionStatus: map['retention_status']?.toString(),
      sharedByUserId: asInt(map['shared_by_user_id']),
      createdAt: date(map['created_at']),
      updatedAt: date(map['updated_at']),
      lastSyncedAt: nullableDate(map['last_synced_at']),
    );
  }
}
