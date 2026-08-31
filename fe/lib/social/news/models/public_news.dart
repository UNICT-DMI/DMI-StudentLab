class PublicNewsAuthor {
  final int id;
  final String firstName;
  final String lastName;
  final String role;
  final String teacherVerificationStatus;

  const PublicNewsAuthor({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.teacherVerificationStatus,
  });

  String get fullName {
    final String value = [firstName.trim(), lastName.trim()]
        .where((String part) => part.isNotEmpty)
        .join(' ');
    return value.isEmpty ? 'Utente StudentLab' : value;
  }

  bool get isVerifiedTeacher =>
      role == 'teacher' && teacherVerificationStatus == 'verified';

  String get roleLabel {
    if (role == 'creator') {
      return 'Creator';
    }
    if (role == 'admin') {
      return 'Admin';
    }
    if (isVerifiedTeacher) {
      return 'Docente verificato';
    }
    if (role == 'teacher') {
      return 'Docente';
    }
    return 'Studente';
  }

  factory PublicNewsAuthor.fromJson(Map<String, dynamic> json) {
    return PublicNewsAuthor(
      id: _toInt(json['id']) ?? 0,
      firstName: json['first_name']?.toString().trim() ?? '',
      lastName: json['last_name']?.toString().trim() ?? '',
      role: json['role']?.toString().trim().toLowerCase() ?? 'student',
      teacherVerificationStatus:
          json['teacher_verification_status']?.toString().trim().toLowerCase() ??
              '',
    );
  }
}

class PublicNews {
  final int id;
  final int authorUserId;
  final int? subjectId;
  final String targetType;
  final String title;
  final String content;
  final String city;
  final String university;
  final String universityCode;
  final String department;
  final String departmentCode;
  final String course;
  final String courseCode;
  final String subjectName;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PublicNewsAuthor author;
  final bool canDelete;
  final bool canModerate;
  final bool canReport;
  final bool canBlockAuthor;

  const PublicNews({
    required this.id,
    required this.authorUserId,
    required this.subjectId,
    required this.targetType,
    required this.title,
    required this.content,
    required this.city,
    required this.university,
    required this.universityCode,
    required this.department,
    required this.departmentCode,
    required this.course,
    required this.courseCode,
    required this.subjectName,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.author,
    required this.canDelete,
    required this.canModerate,
    required this.canReport,
    required this.canBlockAuthor,
  });

  bool get isActive => status == 'active';

  bool get needsDedicatedPage =>
      title.trim().length > 90 || content.trim().length > 280;

  String get academicContext {
    final List<String> values = [
      city,
      university,
      department,
      course,
      subjectName,
    ].map((String value) => value.trim()).where((String value) => value.isNotEmpty).toList();
    return values.isEmpty ? 'StudentLab' : values.join(' • ');
  }

  factory PublicNews.fromJson(Map<String, dynamic> json) {
    final dynamic rawAuthor = json['author'];
    if (rawAuthor is! Map) {
      throw const FormatException('Autore della news non disponibile.');
    }

    return PublicNews(
      id: _toInt(json['id']) ?? 0,
      authorUserId: _toInt(json['author_user_id']) ?? 0,
      subjectId: _toInt(json['subject_id']),
      targetType: json['target_type']?.toString().trim().toLowerCase() ?? 'all',
      title: json['title']?.toString().trim() ?? '',
      content: json['content']?.toString().trim() ?? '',
      city: json['city']?.toString().trim() ?? '',
      university: json['university']?.toString().trim() ?? '',
      universityCode: json['university_code']?.toString().trim() ?? '',
      department: json['department']?.toString().trim() ?? '',
      departmentCode: json['department_code']?.toString().trim() ?? '',
      course: json['course']?.toString().trim() ?? '',
      courseCode: json['course_code']?.toString().trim() ?? '',
      subjectName: json['subject_name']?.toString().trim() ?? '',
      status: json['status']?.toString().trim().toLowerCase() ?? 'active',
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      author: PublicNewsAuthor.fromJson(
        Map<String, dynamic>.from(rawAuthor),
      ),
      canDelete: json['can_delete'] == true,
      canModerate: json['can_moderate'] == true,
      canReport: json['can_report'] == true,
      canBlockAuthor: json['can_block_author'] == true,
    );
  }
}

class PublicNewsFeedResult {
  final List<PublicNews> items;
  final int total;
  final int limit;
  final int offset;

  const PublicNewsFeedResult({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory PublicNewsFeedResult.fromJson(Map<String, dynamic> json) {
    final dynamic rawItems = json['items'];
    final List<PublicNews> items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map(
              (Map<dynamic, dynamic> item) =>
                  PublicNews.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList()
        : <PublicNews>[];

    return PublicNewsFeedResult(
      items: items,
      total: _toInt(json['total']) ?? items.length,
      limit: _toInt(json['limit']) ?? items.length,
      offset: _toInt(json['offset']) ?? 0,
    );
  }
}

class PublicNewsReport {
  final int id;
  final int newsId;
  final int reporterUserId;
  final int? reportedAuthorUserId;
  final String reason;
  final String description;
  final String status;
  final String moderationAction;
  final String moderationNote;
  final int? reviewedByUserId;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  const PublicNewsReport({
    required this.id,
    required this.newsId,
    required this.reporterUserId,
    required this.reportedAuthorUserId,
    required this.reason,
    required this.description,
    required this.status,
    required this.moderationAction,
    required this.moderationNote,
    required this.reviewedByUserId,
    required this.reviewedAt,
    required this.createdAt,
  });

  factory PublicNewsReport.fromJson(Map<String, dynamic> json) {
    return PublicNewsReport(
      id: _toInt(json['id']) ?? 0,
      newsId: _toInt(json['news_id']) ?? 0,
      reporterUserId: _toInt(json['reporter_user_id']) ?? 0,
      reportedAuthorUserId: _toInt(json['reported_author_user_id']),
      reason: json['reason']?.toString().trim() ?? '',
      description: json['description']?.toString().trim() ?? '',
      status: json['status']?.toString().trim().toLowerCase() ?? 'pending',
      moderationAction:
          json['moderation_action']?.toString().trim().toLowerCase() ?? 'none',
      moderationNote: json['moderation_note']?.toString().trim() ?? '',
      reviewedByUserId: _toInt(json['reviewed_by_user_id']),
      reviewedAt: _parseNullableDate(json['reviewed_at']),
      createdAt: _parseDate(json['created_at']),
    );
  }
}

class PublicNewsReportsResult {
  final List<PublicNewsReport> items;
  final int total;
  final int limit;
  final int offset;

  const PublicNewsReportsResult({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  factory PublicNewsReportsResult.fromJson(Map<String, dynamic> json) {
    final dynamic rawItems = json['items'];
    final List<PublicNewsReport> items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map(
              (Map<dynamic, dynamic> item) =>
                  PublicNewsReport.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList()
        : <PublicNewsReport>[];

    return PublicNewsReportsResult(
      items: items,
      total: _toInt(json['total']) ?? items.length,
      limit: _toInt(json['limit']) ?? items.length,
      offset: _toInt(json['offset']) ?? 0,
    );
  }
}

int? _toInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

DateTime _parseDate(dynamic value) {
  final DateTime? parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    throw const FormatException('Data non valida.');
  }
  return parsed.toLocal();
}

DateTime? _parseNullableDate(dynamic value) {
  final String text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text)?.toLocal();
}
