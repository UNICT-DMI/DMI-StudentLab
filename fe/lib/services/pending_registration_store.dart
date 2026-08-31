import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../social/social_models.dart';

class PendingRegistration {
  final String registrationId;

  final String email;

  final SocialProfileDraft draft;

  const PendingRegistration({
    required this.registrationId,
    required this.email,
    required this.draft,
  });
}

class VerifiedRegistrationBanner {
  final String email;

  final DateTime verifiedAt;

  const VerifiedRegistrationBanner({
    required this.email,
    required this.verifiedAt,
  });
}

class PendingRegistrationStore {
  PendingRegistrationStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const String _pendingKey = 'studentlab_pending_registration';

  static const String _verifiedKey = 'studentlab_verified_registration_banner';

  static const Duration verifiedBannerTtl = Duration(minutes: 10);

  final FlutterSecureStorage _storage;

  Future<void> save(
    PendingRegistration pending,
  ) async {
    final Map<String, dynamic> data = {
      'registration_id': pending.registrationId,
      'email': pending.email,
      'draft': pending.draft.toStorageJson(),
    };

    await _storage.write(
      key: _pendingKey,
      value: jsonEncode(data),
    );
  }

  Future<PendingRegistration?> load() async {
    final String? raw = await _storage.read(
      key: _pendingKey,
    );

    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(jsonDecode(raw) as Map);

      final String registrationId =
          data['registration_id']?.toString() ?? '';

      if (registrationId.isEmpty) {
        await clear();
        return null;
      }

      final Map<String, dynamic> draftJson =
          Map<String, dynamic>.from(data['draft'] as Map);

      return PendingRegistration(
        registrationId: registrationId,
        email: data['email']?.toString() ?? '',
        draft: SocialProfileDraft.fromStorageJson(draftJson),
      );
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> updateIdentity({
    required String registrationId,
    required String email,
  }) async {
    final String? raw = await _storage.read(
      key: _pendingKey,
    );

    if (raw == null || raw.isEmpty) {
      return;
    }

    try {
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(jsonDecode(raw) as Map);

      data['registration_id'] = registrationId;
      data['email'] = email;

      await _storage.write(
        key: _pendingKey,
        value: jsonEncode(data),
      );
    } catch (_) {}
  }

  Future<void> clear() async {
    await _storage.delete(
      key: _pendingKey,
    );
  }

  Future<void> markVerified(
    String email,
    DateTime verifiedAt,
  ) async {
    await clear();

    await _storage.write(
      key: _verifiedKey,
      value: jsonEncode({
        'email': email,
        'verified_at': verifiedAt.toIso8601String(),
      }),
    );
  }

  Future<VerifiedRegistrationBanner?> loadVerifiedBanner(
    DateTime now,
  ) async {
    final String? raw = await _storage.read(
      key: _verifiedKey,
    );

    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final Map<String, dynamic> data =
          Map<String, dynamic>.from(jsonDecode(raw) as Map);

      final DateTime? verifiedAt =
          DateTime.tryParse(data['verified_at']?.toString() ?? '');

      if (verifiedAt == null ||
          now.difference(verifiedAt) >= verifiedBannerTtl) {
        await clearVerifiedBanner();
        return null;
      }

      return VerifiedRegistrationBanner(
        email: data['email']?.toString() ?? '',
        verifiedAt: verifiedAt,
      );
    } catch (_) {
      await clearVerifiedBanner();
      return null;
    }
  }

  Future<void> clearVerifiedBanner() async {
    await _storage.delete(
      key: _verifiedKey,
    );
  }
}
