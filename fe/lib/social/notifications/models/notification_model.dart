class StudentLabNotification {
  final int id;
  final int userId;
  final int? actorUserId;
  final String type;
  final String title;
  final String message;
  final String? resourceType;
  final int? resourceId;
  final String? actionType;
  final int? actionResourceId;
  final String actionStatus;
  final bool isRead;
  final DateTime? readAt;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudentLabNotification({
    required this.id,
    required this.userId,
    required this.actorUserId,
    required this.type,
    required this.title,
    required this.message,
    required this.resourceType,
    required this.resourceId,
    required this.actionType,
    required this.actionResourceId,
    required this.actionStatus,
    required this.isRead,
    required this.readAt,
    required this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasAction {
    return actionType != null &&
        actionType!.isNotEmpty &&
        actionStatus == 'pending';
  }

  bool get isOwnershipTransfer {
    return type == 'group_ownership_transfer' &&
        actionType == 'accept_reject_group_ownership';
  }

  bool get isPending {
    return actionStatus == 'pending';
  }

  bool get isAccepted {
    return actionStatus == 'accepted';
  }

  bool get isRejected {
    return actionStatus == 'rejected';
  }

  bool get isExpired {
    return actionStatus == 'expired';
  }

  bool get isCompleted {
    return actionStatus == 'completed';
  }

  bool get isCancelled {
    return actionStatus == 'cancelled';
  }

  bool get hasExpired {
    if (expiresAt == null) {
      return false;
    }

    return DateTime.now().isAfter(
      expiresAt!,
    );
  }

  factory StudentLabNotification.fromJson(
    Map<String, dynamic> json,
  ) {
    return StudentLabNotification(
      id: _parseInt(
        json['id'],
      ),
      userId: _parseInt(
        json['user_id'],
      ),
      actorUserId: _parseNullableInt(
        json['actor_user_id'],
      ),
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      resourceType: json['resource_type']?.toString(),
      resourceId: _parseNullableInt(
        json['resource_id'],
      ),
      actionType: json['action_type']?.toString(),
      actionResourceId: _parseNullableInt(
        json['action_resource_id'],
      ),
      actionStatus:
          json['action_status']?.toString() ?? 'none',
      isRead: json['is_read'] == true,
      readAt: _parseNullableDateTime(
        json['read_at'],
      ),
      expiresAt: _parseNullableDateTime(
        json['expires_at'],
      ),
      createdAt: _parseDateTime(
        json['created_at'],
      ),
      updatedAt: _parseDateTime(
        json['updated_at'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'actor_user_id': actorUserId,
      'type': type,
      'title': title,
      'message': message,
      'resource_type': resourceType,
      'resource_id': resourceId,
      'action_type': actionType,
      'action_resource_id': actionResourceId,
      'action_status': actionStatus,
      'is_read': isRead,
      'read_at': readAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  StudentLabNotification copyWith({
    int? id,
    int? userId,
    int? actorUserId,
    bool clearActorUserId = false,
    String? type,
    String? title,
    String? message,
    String? resourceType,
    bool clearResourceType = false,
    int? resourceId,
    bool clearResourceId = false,
    String? actionType,
    bool clearActionType = false,
    int? actionResourceId,
    bool clearActionResourceId = false,
    String? actionStatus,
    bool? isRead,
    DateTime? readAt,
    bool clearReadAt = false,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudentLabNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      actorUserId: clearActorUserId
          ? null
          : actorUserId ?? this.actorUserId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      resourceType: clearResourceType
          ? null
          : resourceType ?? this.resourceType,
      resourceId: clearResourceId
          ? null
          : resourceId ?? this.resourceId,
      actionType: clearActionType
          ? null
          : actionType ?? this.actionType,
      actionResourceId: clearActionResourceId
          ? null
          : actionResourceId ?? this.actionResourceId,
      actionStatus: actionStatus ?? this.actionStatus,
      isRead: isRead ?? this.isRead,
      readAt: clearReadAt
          ? null
          : readAt ?? this.readAt,
      expiresAt: clearExpiresAt
          ? null
          : expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static int _parseInt(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  static int? _parseNullableInt(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(
      value.toString(),
    );
  }

  static DateTime _parseDateTime(
    dynamic value,
  ) {
    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(
          value?.toString() ?? '',
        ) ??
        DateTime.fromMillisecondsSinceEpoch(
          0,
          isUtc: true,
        );
  }

  static DateTime? _parseNullableDateTime(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(
      value.toString(),
    );
  }
}


class NotificationListResult {
  final List<StudentLabNotification> notifications;
  final int unreadCount;

  const NotificationListResult({
    required this.notifications,
    required this.unreadCount,
  });

  factory NotificationListResult.fromJson(
    Map<String, dynamic> json,
  ) {
    final dynamic rawNotifications =
        json['notifications'];

    final List<dynamic> notificationList =
        rawNotifications is List
            ? rawNotifications
            : const [];

    return NotificationListResult(
      notifications: notificationList
          .whereType<Map>()
          .map(
            (Map item) =>
                StudentLabNotification.fromJson(
              Map<String, dynamic>.from(
                item,
              ),
            ),
          )
          .toList(),
      unreadCount: _parseInt(
        json['unread_count'],
      ),
    );
  }

  static int _parseInt(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }
}