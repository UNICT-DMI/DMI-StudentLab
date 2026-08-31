class NewsReportReasons {
  const NewsReportReasons._();

  static const Map<String, String> labels = <String, String>{
    'spam': 'Spam o pubblicità',
    'harassment': 'Molestie o minacce',
    'hate': 'Odio o discriminazione',
    'privacy': 'Violazione della privacy',
    'illegal_content': 'Contenuto illecito',
    'other': 'Altro',
  };

  static bool isValid(String reason) => labels.containsKey(reason);

  static String labelOf(String reason) => labels[reason] ?? 'Altro';
}

class NewsReport {
  final int id;
  final String category;
  final String newsId;
  final int? groupId;
  final String conversationId;
  final int reporterUserId;
  final int? reportedUserId;
  final String reason;
  final String description;
  final String status;
  final String moderationAction;
  final String moderationNote;
  final int? reviewedByUserId;
  final DateTime? reviewedAt;
  final DateTime? disclosureConsentAt;
  final DateTime? disclosureOpenedAt;
  final DateTime createdAt;

  const NewsReport({
    required this.id,
    required this.category,
    required this.newsId,
    required this.groupId,
    required this.conversationId,
    required this.reporterUserId,
    required this.reportedUserId,
    required this.reason,
    required this.description,
    required this.status,
    required this.moderationAction,
    required this.moderationNote,
    required this.reviewedByUserId,
    required this.reviewedAt,
    required this.disclosureConsentAt,
    required this.disclosureOpenedAt,
    required this.createdAt,
  });

  bool get isPending => status == 'pending' || status == 'under_review';

  bool get hasDisclosureConsent => disclosureConsentAt != null;

  bool get wasDisclosureOpened => disclosureOpenedAt != null;

  String get reasonLabel => NewsReportReasons.labelOf(reason);

  factory NewsReport.fromJson(Map<String, dynamic> json) {
    return NewsReport(
      id: _toInt(json['id']) ?? 0,
      category: json['category']?.toString().trim() ?? '',
      newsId: json['news_id']?.toString().trim() ?? '',
      groupId: _toInt(json['group_id']),
      conversationId: json['conversation_id']?.toString().trim() ?? '',
      reporterUserId: _toInt(json['reporter_user_id']) ?? 0,
      reportedUserId: _toInt(json['reported_user_id']),
      reason: json['reason']?.toString().trim() ?? 'other',
      description: json['description']?.toString().trim() ?? '',
      status: json['status']?.toString().trim() ?? 'pending',
      moderationAction:
          json['moderation_action']?.toString().trim() ?? 'none',
      moderationNote: json['moderation_note']?.toString().trim() ?? '',
      reviewedByUserId: _toInt(json['reviewed_by_user_id']),
      reviewedAt: _parseNullableDate(json['reviewed_at']),
      disclosureConsentAt: _parseNullableDate(json['disclosure_consent_at']),
      disclosureOpenedAt: _parseNullableDate(json['disclosure_opened_at']),
      createdAt: _parseDate(json['created_at']),
    );
  }
}

class NewsReportListResult {
  final List<NewsReport> items;
  final int total;

  const NewsReportListResult({
    required this.items,
    required this.total,
  });

  factory NewsReportListResult.fromJson(Map<String, dynamic> json) {
    final dynamic rawItems = json['items'];

    final List<NewsReport> items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map(
              (Map<dynamic, dynamic> item) => NewsReport.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList()
        : <NewsReport>[];

    return NewsReportListResult(
      items: items,
      total: _toInt(json['total']) ?? items.length,
    );
  }
}

class NewsReportDisclosure {
  final int reportId;
  final String category;
  final String newsId;
  final int? authorId;
  final String authorName;
  final DateTime? createdAt;
  final String content;
  final bool verified;
  final List<String> wrapTargets;

  const NewsReportDisclosure({
    required this.reportId,
    required this.category,
    required this.newsId,
    required this.authorId,
    required this.authorName,
    required this.createdAt,
    required this.content,
    required this.verified,
    required this.wrapTargets,
  });

  factory NewsReportDisclosure.fromJson(Map<String, dynamic> json) {
    final dynamic targets = json['wrap_targets'];

    return NewsReportDisclosure(
      reportId: _toInt(json['report_id']) ?? 0,
      category: json['category']?.toString().trim() ?? '',
      newsId: json['news_id']?.toString().trim() ?? '',
      authorId: _toInt(json['author_id']),
      authorName: json['author_name']?.toString().trim() ?? '',
      createdAt: _parseNullableDate(json['created_at']),
      content: json['content']?.toString() ?? '',
      verified: json['verified'] == true,
      wrapTargets: targets is List
          ? targets.map((dynamic item) => item.toString()).toList()
          : <String>[],
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
