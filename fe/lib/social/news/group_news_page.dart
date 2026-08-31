class GroupNewsUser {
  final int id;
  final String firstName;
  final String lastName;
  final String role;
  final String university;
  final String department;
  final String course;
  final String teacherVerificationStatus;

  const GroupNewsUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.university,
    required this.department,
    required this.course,
    required this.teacherVerificationStatus,
  });

  String get fullName {
    final String value = [
      firstName.trim(),
      lastName.trim(),
    ].where((String part) => part.isNotEmpty).join(' ');

    return value.isEmpty
        ? 'Utente StudentLab'
        : value;
  }

  bool get isTeacher {
    return role.trim().toLowerCase() ==
        'teacher';
  }

  bool get isVerifiedTeacher {
    return isTeacher &&
        teacherVerificationStatus
                .trim()
                .toLowerCase() ==
            'verified';
  }

  bool get isAdmin {
    final String normalized =
        role.trim().toLowerCase();

    return normalized == 'admin' ||
        normalized == 'creator';
  }

  factory GroupNewsUser.fromJson(
    Map<String, dynamic> json,
  ) {
    return GroupNewsUser(
      id: _toInt(
            json['id'],
          ) ??
          0,
      firstName:
          json['first_name']
                  ?.toString()
                  .trim() ??
              '',
      lastName:
          json['last_name']
                  ?.toString()
                  .trim() ??
              '',
      role:
          json['role']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              '',
      university:
          json['university']
                  ?.toString()
                  .trim() ??
              '',
      department:
          json['department']
                  ?.toString()
                  .trim() ??
              '',
      course:
          json['course']
                  ?.toString()
                  .trim() ??
              '',
      teacherVerificationStatus:
          json['teacher_verification_status']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'role': role,
      'university': university,
      'department': department,
      'course': course,
      'teacher_verification_status':
          teacherVerificationStatus,
    };
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
}


class GroupNews {
  final int id;
  final int groupId;
  final int authorUserId;
  final int? recipientUserId;
  final int? parentNewsId;
  final String visibility;
  final bool isPrivate;
  final String content;
  final DateTime createdAt;
  final DateTime expiresAt;
  final GroupNewsUser author;
  final GroupNewsUser? recipient;
  final bool canReply;
  final bool canDelete;
  final bool canModerate;
  final bool canReport;
  final bool canBlockAuthor;
  final String groupName;
  final int? subjectId;
  final String subjectName;

  const GroupNews({
    required this.id,
    required this.groupId,
    required this.authorUserId,
    required this.recipientUserId,
    required this.parentNewsId,
    required this.visibility,
    required this.isPrivate,
    required this.content,
    required this.createdAt,
    required this.expiresAt,
    required this.author,
    required this.recipient,
    required this.canReply,
    required this.canDelete,
    required this.canModerate,
    required this.canReport,
    required this.canBlockAuthor,
    required this.groupName,
    required this.subjectId,
    required this.subjectName,
  });

  bool get isGroupNews {
    return visibility ==
        'group';
  }

  bool get isExpired {
    return !expiresAt.isAfter(
      DateTime.now(),
    );
  }

  String get contextLabel {
    if (subjectName.trim().isNotEmpty &&
        groupName.trim().isNotEmpty) {
      return '$groupName • $subjectName';
    }

    if (groupName.trim().isNotEmpty) {
      return groupName;
    }

    if (subjectName.trim().isNotEmpty) {
      return subjectName;
    }

    return 'Gruppo StudentLab';
  }

  String get authorLabel {
    if (author.isVerifiedTeacher) {
      return 'Docente verificato';
    }

    if (author.isAdmin) {
      return author.role == 'creator'
          ? 'Creator'
          : 'Admin';
    }

    return 'Studente';
  }

  factory GroupNews.fromJson(
    Map<String, dynamic> json,
  ) {
    final dynamic authorData =
        json['author'];

    if (authorData is! Map) {
      throw const FormatException(
        'Autore della news non disponibile.',
      );
    }

    final dynamic recipientData =
        json['recipient'];

    final String visibility =
        json['visibility']
                ?.toString()
                .trim()
                .toLowerCase() ??
            '';

    final DateTime createdAt =
        _parseDate(
      json['created_at'],
    );

    final DateTime expiresAt =
        _parseDate(
      json['expires_at'],
    );

    return GroupNews(
      id: _toInt(
            json['id'],
          ) ??
          0,
      groupId: _toInt(
            json['group_id'],
          ) ??
          0,
      authorUserId: _toInt(
            json['author_user_id'],
          ) ??
          0,
      recipientUserId:
          _toInt(
        json['recipient_user_id'],
      ),
      parentNewsId:
          _toInt(
        json['parent_news_id'],
      ),
      visibility: visibility,
      isPrivate:
          json['is_private'] == true ||
              visibility == 'private',
      content:
          json['content']
                  ?.toString()
                  .trim() ??
              '',
      createdAt:
          createdAt,
      expiresAt:
          expiresAt,
      author:
          GroupNewsUser.fromJson(
        Map<String, dynamic>.from(
          authorData,
        ),
      ),
      recipient:
          recipientData is Map
              ? GroupNewsUser.fromJson(
                  Map<String, dynamic>.from(
                    recipientData,
                  ),
                )
              : null,
      canReply:
          json['can_reply'] == true,
      canDelete:
          json['can_delete'] == true,
      canModerate:
          json['can_moderate'] == true,
      canReport:
          json['can_report'] == true,
      canBlockAuthor:
          json['can_block_author'] ==
              true,
      groupName:
          json['group_name']
                  ?.toString()
                  .trim() ??
              '',
      subjectId:
          _toInt(
        json['subject_id'],
      ),
      subjectName:
          json['subject_name']
                  ?.toString()
                  .trim() ??
              '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'author_user_id': authorUserId,
      'recipient_user_id':
          recipientUserId,
      'parent_news_id':
          parentNewsId,
      'visibility': visibility,
      'is_private': isPrivate,
      'content': content,
      'created_at':
          createdAt.toUtc().toIso8601String(),
      'expires_at':
          expiresAt.toUtc().toIso8601String(),
      'author':
          author.toJson(),
      'recipient':
          recipient?.toJson(),
      'can_reply':
          canReply,
      'can_delete':
          canDelete,
      'can_moderate':
          canModerate,
      'can_report':
          canReport,
      'can_block_author':
          canBlockAuthor,
      'group_name':
          groupName,
      'subject_id':
          subjectId,
      'subject_name':
          subjectName,
    };
  }

  GroupNews copyWith({
    int? id,
    int? groupId,
    int? authorUserId,
    int? recipientUserId,
    bool clearRecipientUserId = false,
    int? parentNewsId,
    bool clearParentNewsId = false,
    String? visibility,
    bool? isPrivate,
    String? content,
    DateTime? createdAt,
    DateTime? expiresAt,
    GroupNewsUser? author,
    GroupNewsUser? recipient,
    bool clearRecipient = false,
    bool? canReply,
    bool? canDelete,
    bool? canModerate,
    bool? canReport,
    bool? canBlockAuthor,
    String? groupName,
    int? subjectId,
    bool clearSubjectId = false,
    String? subjectName,
  }) {
    return GroupNews(
      id:
          id ?? this.id,
      groupId:
          groupId ?? this.groupId,
      authorUserId:
          authorUserId ??
              this.authorUserId,
      recipientUserId:
          clearRecipientUserId
              ? null
              : recipientUserId ??
                  this.recipientUserId,
      parentNewsId:
          clearParentNewsId
              ? null
              : parentNewsId ??
                  this.parentNewsId,
      visibility:
          visibility ??
              this.visibility,
      isPrivate:
          isPrivate ??
              this.isPrivate,
      content:
          content ??
              this.content,
      createdAt:
          createdAt ??
              this.createdAt,
      expiresAt:
          expiresAt ??
              this.expiresAt,
      author:
          author ??
              this.author,
      recipient:
          clearRecipient
              ? null
              : recipient ??
                  this.recipient,
      canReply:
          canReply ??
              this.canReply,
      canDelete:
          canDelete ??
              this.canDelete,
      canModerate:
          canModerate ??
              this.canModerate,
      canReport:
          canReport ??
              this.canReport,
      canBlockAuthor:
          canBlockAuthor ??
              this.canBlockAuthor,
      groupName:
          groupName ??
              this.groupName,
      subjectId:
          clearSubjectId
              ? null
              : subjectId ??
                  this.subjectId,
      subjectName:
          subjectName ??
              this.subjectName,
    );
  }

  static DateTime _parseDate(
    dynamic value,
  ) {
    final DateTime? parsed =
        DateTime.tryParse(
      value?.toString() ?? '',
    );

    if (parsed == null) {
      throw const FormatException(
        'Data della news non valida.',
      );
    }

    return parsed.toLocal();
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
}


class GroupNewsFeedResult {
  final int groupId;
  final List<GroupNews> items;
  final int total;
  final int limit;
  final int offset;

  const GroupNewsFeedResult({
    required this.groupId,
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory GroupNewsFeedResult.fromJson(
    Map<String, dynamic> json,
  ) {
    final dynamic rawItems =
        json['items'];

    final List<GroupNews> items =
        rawItems is List
            ? rawItems
                .whereType<Map>()
                .map(
                  (
                    Map<dynamic, dynamic>
                        item,
                  ) =>
                      GroupNews.fromJson(
                    Map<String, dynamic>.from(
                      item,
                    ),
                  ),
                )
                .toList()
            : [];

    return GroupNewsFeedResult(
      groupId:
          _toInt(
            json['group_id'],
          ) ??
          0,
      items:
          items,
      total:
          _toInt(
            json['total'],
          ) ??
          items.length,
      limit:
          _toInt(
            json['limit'],
          ) ??
          items.length,
      offset:
          _toInt(
            json['offset'],
          ) ??
          0,
    );
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
}


class GroupNewsPrivateInboxResult {
  final List<GroupNews> items;
  final int total;
  final int limit;
  final int offset;

  const GroupNewsPrivateInboxResult({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory GroupNewsPrivateInboxResult.fromJson(
    Map<String, dynamic> json,
  ) {
    final dynamic rawItems =
        json['items'];

    final List<GroupNews> items =
        rawItems is List
            ? rawItems
                .whereType<Map>()
                .map(
                  (
                    Map<dynamic, dynamic>
                        item,
                  ) =>
                      GroupNews.fromJson(
                    Map<String, dynamic>.from(
                      item,
                    ),
                  ),
                )
                .toList()
            : [];

    return GroupNewsPrivateInboxResult(
      items:
          items,
      total:
          _toInt(
            json['total'],
          ) ??
          items.length,
      limit:
          _toInt(
            json['limit'],
          ) ??
          items.length,
      offset:
          _toInt(
            json['offset'],
          ) ??
          0,
    );
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
}