class NewsReply {
  final String id;
  final int authorId;
  final String authorName;
  final String content;
  final DateTime createdAt;
  final String writeToken;

  const NewsReply({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.createdAt,
    required this.writeToken,
  });

  factory NewsReply.fromJson(Map<String, dynamic> json) {
    return NewsReply(
      id: json['id']?.toString().trim() ?? '',
      authorId: _toInt(json['author_id']) ?? 0,
      authorName: json['author_name']?.toString().trim() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: _parseDate(json['created_at']),
      writeToken: json['write_token']?.toString().trim() ?? '',
    );
  }
}

class NewsAvviso {
  final String id;
  final int authorId;
  final String authorName;
  final String authorRole;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<NewsReply> replies;
  final bool canDelete;
  final String writeToken;

  const NewsAvviso({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.replies,
    required this.canDelete,
    required this.writeToken,
  });

  factory NewsAvviso.fromJson(Map<String, dynamic> json) {
    return NewsAvviso(
      id: json['id']?.toString().trim() ?? '',
      authorId: _toInt(json['author_id']) ?? 0,
      authorName: json['author_name']?.toString().trim() ?? '',
      authorRole: json['author_role']?.toString().trim().toLowerCase() ?? '',
      title: json['title']?.toString().trim() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      replies: _parseReplies(json['replies']),
      canDelete: json['can_delete'] == true,
      writeToken: json['write_token']?.toString().trim() ?? '',
    );
  }
}

class NewsAvvisoListResult {
  final List<NewsAvviso> items;
  final int total;

  const NewsAvvisoListResult({
    required this.items,
    required this.total,
  });

  factory NewsAvvisoListResult.fromJson(Map<String, dynamic> json) {
    final List<NewsAvviso> items = _parseItems(
      json['items'],
      NewsAvviso.fromJson,
    );

    return NewsAvvisoListResult(
      items: items,
      total: _toInt(json['total']) ?? items.length,
    );
  }
}

class NewsGroupPost {
  final String id;
  final int groupId;
  final String groupName;
  final int authorId;
  final String authorName;
  final String authorRole;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<NewsReply> replies;
  final bool canDelete;
  final String writeToken;

  const NewsGroupPost({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.authorId,
    required this.authorName,
    required this.authorRole,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    required this.replies,
    required this.canDelete,
    required this.writeToken,
  });

  factory NewsGroupPost.fromJson(Map<String, dynamic> json) {
    return NewsGroupPost(
      id: json['id']?.toString().trim() ?? '',
      groupId: _toInt(json['group_id']) ?? 0,
      groupName: json['group_name']?.toString().trim() ?? '',
      authorId: _toInt(json['author_id']) ?? 0,
      authorName: json['author_name']?.toString().trim() ?? '',
      authorRole: json['author_role']?.toString().trim().toLowerCase() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      replies: _parseReplies(json['replies']),
      canDelete: json['can_delete'] == true,
      writeToken: json['write_token']?.toString().trim() ?? '',
    );
  }
}

class NewsGroupPostListResult {
  final List<NewsGroupPost> items;
  final int total;

  const NewsGroupPostListResult({
    required this.items,
    required this.total,
  });

  factory NewsGroupPostListResult.fromJson(Map<String, dynamic> json) {
    final List<NewsGroupPost> items = _parseItems(
      json['items'],
      NewsGroupPost.fromJson,
    );

    return NewsGroupPostListResult(
      items: items,
      total: _toInt(json['total']) ?? items.length,
    );
  }
}

class NewsPrivateMessage {
  final String id;
  final String conversationId;
  final int senderId;
  final int recipientId;
  final String senderName;
  final String recipientName;
  final String algo;
  final String ciphertext;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final String delivery;
  final bool canDelete;
  final String writeToken;

  const NewsPrivateMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.recipientId,
    this.senderName = '',
    this.recipientName = '',
    required this.algo,
    required this.ciphertext,
    required this.metadata,
    required this.createdAt,
    this.delivery = 'delivered',
    required this.canDelete,
    required this.writeToken,
  });

  bool get isPendingDelivery => delivery == 'pending';

  int counterpartId(int viewerId) =>
      senderId == viewerId ? recipientId : senderId;

  String counterpartName(int viewerId) {
    final String name =
        senderId == viewerId ? recipientName : senderName;

    return name.trim().isEmpty ? 'Utente StudentLab' : name.trim();
  }

  factory NewsPrivateMessage.fromJson(Map<String, dynamic> json) {
    final dynamic rawMetadata = json['metadata'];

    return NewsPrivateMessage(
      id: json['id']?.toString().trim() ?? '',
      conversationId: json['conversation_id']?.toString().trim() ?? '',
      senderId: _toInt(json['sender_id']) ?? 0,
      recipientId: _toInt(json['recipient_id']) ?? 0,
      senderName: json['sender_name']?.toString().trim() ?? '',
      recipientName: json['recipient_name']?.toString().trim() ?? '',
      algo: json['algo']?.toString().trim() ?? '',
      ciphertext: json['ciphertext']?.toString() ?? '',
      metadata: rawMetadata is Map
          ? Map<String, dynamic>.from(rawMetadata)
          : <String, dynamic>{},
      createdAt: _parseDate(json['created_at']),
      delivery: json['delivery']?.toString().trim().isNotEmpty == true
          ? json['delivery'].toString().trim()
          : 'delivered',
      canDelete: json['can_delete'] == true,
      writeToken: json['write_token']?.toString().trim() ?? '',
    );
  }
}

class NewsPrivateMessageListResult {
  final List<NewsPrivateMessage> items;
  final int total;

  const NewsPrivateMessageListResult({
    required this.items,
    required this.total,
  });

  factory NewsPrivateMessageListResult.fromJson(Map<String, dynamic> json) {
    final List<NewsPrivateMessage> items = _parseItems(
      json['items'],
      NewsPrivateMessage.fromJson,
    );

    return NewsPrivateMessageListResult(
      items: items,
      total: _toInt(json['total']) ?? items.length,
    );
  }
}

List<NewsReply> _parseReplies(dynamic value) {
  return _parseItems(
    value,
    NewsReply.fromJson,
  );
}

List<T> _parseItems<T>(
  dynamic value,
  T Function(Map<String, dynamic>) build,
) {
  if (value is! List) {
    return <T>[];
  }

  return value
      .whereType<Map>()
      .map(
        (Map<dynamic, dynamic> item) => build(
          Map<String, dynamic>.from(item),
        ),
      )
      .toList();
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
