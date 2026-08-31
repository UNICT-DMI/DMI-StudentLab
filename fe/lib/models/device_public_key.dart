class DevicePublicKey {
  final int id;
  final int userId;
  final String deviceId;
  final String deviceLabel;
  final String algo;
  final String publicKey;
  final DateTime createdAt;
  final DateTime? rotatedAt;
  final DateTime? revokedAt;

  const DevicePublicKey({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.deviceLabel,
    required this.algo,
    required this.publicKey,
    required this.createdAt,
    required this.rotatedAt,
    required this.revokedAt,
  });

  bool get isActive => revokedAt == null;

  String get wrapTarget => '$userId:$deviceId';

  factory DevicePublicKey.fromJson(Map<String, dynamic> json) {
    return DevicePublicKey(
      id: _toInt(json['id']) ?? 0,
      userId: _toInt(json['user_id']) ?? 0,
      deviceId: json['device_id']?.toString().trim() ?? '',
      deviceLabel: json['device_label']?.toString().trim() ?? '',
      algo: json['algo']?.toString().trim().toLowerCase() ?? '',
      publicKey: json['public_key']?.toString().trim() ?? '',
      createdAt: _parseDate(json['created_at']),
      rotatedAt: _parseNullableDate(json['rotated_at']),
      revokedAt: _parseNullableDate(json['revoked_at']),
    );
  }
}

class DevicePublicKeyListResult {
  final List<DevicePublicKey> items;
  final int total;

  const DevicePublicKeyListResult({
    required this.items,
    required this.total,
  });

  List<DevicePublicKey> get activeItems =>
      items.where((DevicePublicKey key) => key.isActive).toList();

  factory DevicePublicKeyListResult.fromJson(Map<String, dynamic> json) {
    final dynamic rawItems = json['items'];

    final List<DevicePublicKey> items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map(
              (Map<dynamic, dynamic> item) => DevicePublicKey.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList()
        : <DevicePublicKey>[];

    return DevicePublicKeyListResult(
      items: items,
      total: _toInt(json['total']) ?? items.length,
    );
  }
}

class ComplianceKey {
  final bool configured;
  final String keyId;
  final String algo;
  final String publicKey;

  const ComplianceKey({
    required this.configured,
    required this.keyId,
    required this.algo,
    required this.publicKey,
  });

  bool get isUsable => configured && publicKey.isNotEmpty;

  factory ComplianceKey.fromJson(Map<String, dynamic> json) {
    return ComplianceKey(
      configured: json['configured'] == true,
      keyId: json['key_id']?.toString().trim() ?? '',
      algo: json['algo']?.toString().trim().toLowerCase() ?? '',
      publicKey: json['public_key']?.toString().trim() ?? '',
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
