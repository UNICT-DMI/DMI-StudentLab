class StudyGroup {
  final int id;
  final String name;
  final String description;
  final int? subjectId;
  final String subject;
  final String course;
  final String department;
  final String university;
  final int memberCount;
  final int materialCount;
  final bool isPrivate;
  final bool isOwner;
  final bool isAdmin;
  final String currentUserRole;
  final int? createdBy;
  final String creatorName;
  final bool currentUserCanPublishNews;

  const StudyGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.subjectId,
    required this.subject,
    required this.course,
    required this.department,
    required this.university,
    required this.memberCount,
    required this.materialCount,
    required this.isPrivate,
    required this.isOwner,
    this.isAdmin = false,
    this.currentUserRole = '',
    this.createdBy,
    this.creatorName = '',
    this.currentUserCanPublishNews = false,
  });

  bool get isManager {
    return isOwner || isAdmin;
  }

  bool get isMember {
    return currentUserRole.trim().isNotEmpty;
  }

  bool get canPublishNews {
    return isManager || currentUserCanPublishNews;
  }

  String get visibilityLabel {
    return isPrivate ? 'Privato' : 'Pubblico';
  }

  factory StudyGroup.fromJson(
    Map<String, dynamic> json, {
    int? currentUserId,
  }) {
    final dynamic membersData = json['members'];

    final int memberCount = membersData is List
        ? membersData.length
        : _toInt(json['member_count']) ?? 0;

    final int? createdBy = _toInt(json['created_by']);

    String currentUserRole = '';
    bool currentUserCanPublishNews = false;
    String creatorName = _extractCreatorName(json);

    if (membersData is List) {
      for (final dynamic rawMember in membersData) {
        if (rawMember is! Map) {
          continue;
        }

        final Map<String, dynamic> member =
            Map<String, dynamic>.from(rawMember);

        final int? memberUserId =
            _toInt(member['user_id'] ?? member['id']);

        final String role =
            member['role']?.toString().trim().toLowerCase() ?? '';

        if (creatorName.isEmpty &&
            (role == 'owner' ||
                (createdBy != null && memberUserId == createdBy))) {
          creatorName = _extractMemberName(member);
        }

        if (currentUserId == null || memberUserId != currentUserId) {
          continue;
        }

        currentUserRole = role;
        currentUserCanPublishNews =
            _readPublishNewsPermission(member);
      }
    }

    final bool ownerFromCreatedBy =
        currentUserId != null && createdBy == currentUserId;

    final bool ownerFromRole =
        currentUserRole == 'owner';

    final bool isOwner =
        ownerFromCreatedBy || ownerFromRole;

    if (isOwner && currentUserRole.isEmpty) {
      currentUserRole = 'owner';
    }

    final bool isAdmin =
        currentUserRole == 'admin';

    String subjectName = '';
    final dynamic subjectData = json['subject'];

    if (subjectData is Map) {
      subjectName =
          subjectData['name']?.toString().trim() ?? '';
    } else {
      subjectName =
          json['subject_name']?.toString().trim() ?? '';
    }

    return StudyGroup(
      id: _toInt(json['id']) ?? 0,
      name: json['name']?.toString().trim() ?? '',
      description:
          json['description']?.toString().trim() ?? '',
      subjectId: _toInt(json['subject_id']),
      subject: subjectName,
      course: json['course']?.toString().trim() ?? '',
      department:
          json['department']?.toString().trim() ?? '',
      university: (json['university'] ??
                  json['university_name'] ??
                  json['ateneo'])
              ?.toString()
              .trim() ??
          '',
      memberCount: memberCount,
      materialCount:
          _toInt(json['material_count']) ?? 0,
      isPrivate:
          _toBool(json['is_private']) ?? false,
      isOwner: isOwner,
      isAdmin: isAdmin,
      currentUserRole: currentUserRole,
      createdBy: createdBy,
      creatorName: creatorName,
      currentUserCanPublishNews:
          isOwner ||
          isAdmin ||
          currentUserCanPublishNews,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'subject_id': subjectId,
      'subject': subject,
      'course': course,
      'department': department,
      'university': university,
      'member_count': memberCount,
      'material_count': materialCount,
      'is_private': isPrivate,
      'is_owner': isOwner,
      'is_admin': isAdmin,
      'current_user_role': currentUserRole,
      'created_by': createdBy,
      'creator_name': creatorName,
      'can_publish_news': currentUserCanPublishNews,
    };
  }

  StudyGroup copyWith({
    int? id,
    String? name,
    String? description,
    int? subjectId,
    bool clearSubjectId = false,
    String? subject,
    String? course,
    String? department,
    String? university,
    int? memberCount,
    int? materialCount,
    bool? isPrivate,
    bool? isOwner,
    bool? isAdmin,
    String? currentUserRole,
    int? createdBy,
    bool clearCreatedBy = false,
    String? creatorName,
    bool? currentUserCanPublishNews,
  }) {
    return StudyGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      subjectId:
          clearSubjectId ? null : subjectId ?? this.subjectId,
      subject: subject ?? this.subject,
      course: course ?? this.course,
      department: department ?? this.department,
      university: university ?? this.university,
      memberCount: memberCount ?? this.memberCount,
      materialCount: materialCount ?? this.materialCount,
      isPrivate: isPrivate ?? this.isPrivate,
      isOwner: isOwner ?? this.isOwner,
      isAdmin: isAdmin ?? this.isAdmin,
      currentUserRole:
          currentUserRole ?? this.currentUserRole,
      createdBy:
          clearCreatedBy ? null : createdBy ?? this.createdBy,
      creatorName: creatorName ?? this.creatorName,
      currentUserCanPublishNews:
          currentUserCanPublishNews ??
              this.currentUserCanPublishNews,
    );
  }

  static bool _readPublishNewsPermission(
    Map<String, dynamic> member,
  ) {
    final bool? direct =
        _toBool(member['can_publish_news']);

    if (direct != null) {
      return direct;
    }

    final dynamic permissions = member['permissions'];

    if (permissions is Map) {
      return _toBool(
            permissions['can_publish_news'] ??
                permissions['publish_news'],
          ) ??
          false;
    }

    if (permissions is List) {
      return permissions
          .map((dynamic value) =>
              value.toString().trim().toLowerCase())
          .contains('publish_news');
    }

    return false;
  }

  static String _extractCreatorName(
    Map<String, dynamic> json,
  ) {
    final List<dynamic> candidates = [
      json['creator'],
      json['created_by_user'],
      json['owner'],
    ];

    for (final dynamic candidate in candidates) {
      if (candidate is! Map) {
        continue;
      }

      final String name =
          _nameFromMap(Map<String, dynamic>.from(candidate));

      if (name.isNotEmpty) {
        return name;
      }
    }

    return json['creator_name']
            ?.toString()
            .trim() ??
        '';
  }

  static String _extractMemberName(
    Map<String, dynamic> member,
  ) {
    final dynamic user = member['user'];

    if (user is Map) {
      final String name =
          _nameFromMap(Map<String, dynamic>.from(user));

      if (name.isNotEmpty) {
        return name;
      }
    }

    return _nameFromMap(member);
  }

  static String _nameFromMap(
    Map<String, dynamic> map,
  ) {
    final String directName =
        (map['name'] ?? map['full_name'])
                ?.toString()
                .trim() ??
            '';

    if (directName.isNotEmpty) {
      return directName;
    }

    final String firstName =
        map['first_name']?.toString().trim() ?? '';

    final String lastName =
        map['last_name']?.toString().trim() ?? '';

    return [
      firstName,
      lastName,
    ].where((String value) => value.isNotEmpty).join(' ');
  }

  static int? _toInt(
    dynamic value,
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

  static bool? _toBool(
    dynamic value,
  ) {
    if (value is bool) {
      return value;
    }

    final String normalized =
        value?.toString().trim().toLowerCase() ?? '';

    if (normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes') {
      return true;
    }

    if (normalized == 'false' ||
        normalized == '0' ||
        normalized == 'no') {
      return false;
    }

    return null;
  }
}