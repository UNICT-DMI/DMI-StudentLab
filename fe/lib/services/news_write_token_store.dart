import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class NewsWriteTokenStore {
  NewsWriteTokenStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  static const String _key = 'studentlab_news_write_tokens';

  static const int _maxTokens = 500;

  final FlutterSecureStorage _storage;

  Future<void> save({
    required String newsId,
    required String writeToken,
  }) async {
    final String id = newsId.trim();
    final String token = writeToken.trim();

    if (id.isEmpty || token.isEmpty) {
      return;
    }

    final Map<String, String> tokens = await _load();

    tokens.remove(id);
    tokens[id] = token;

    while (tokens.length > _maxTokens) {
      tokens.remove(tokens.keys.first);
    }

    await _persist(tokens);
  }

  Future<String?> read(String newsId) async {
    final String id = newsId.trim();

    if (id.isEmpty) {
      return null;
    }

    final Map<String, String> tokens = await _load();

    return tokens[id];
  }

  Future<void> remove(String newsId) async {
    final String id = newsId.trim();

    if (id.isEmpty) {
      return;
    }

    final Map<String, String> tokens = await _load();

    if (tokens.remove(id) == null) {
      return;
    }

    await _persist(tokens);
  }

  Future<void> clear() async {
    await _storage.delete(
      key: _key,
    );
  }

  Future<Map<String, String>> _load() async {
    final String? raw = await _storage.read(
      key: _key,
    );

    if (raw == null || raw.trim().isEmpty) {
      return <String, String>{};
    }

    try {
      final dynamic decoded = jsonDecode(raw);

      if (decoded is! Map) {
        return <String, String>{};
      }

      final Map<String, String> tokens = <String, String>{};

      decoded.forEach((dynamic key, dynamic value) {
        final String id = key?.toString().trim() ?? '';
        final String token = value?.toString().trim() ?? '';

        if (id.isNotEmpty && token.isNotEmpty) {
          tokens[id] = token;
        }
      });

      return tokens;
    } catch (_) {
      return <String, String>{};
    }
  }

  Future<void> _persist(Map<String, String> tokens) async {
    if (tokens.isEmpty) {
      await clear();
      return;
    }

    await _storage.write(
      key: _key,
      value: jsonEncode(tokens),
    );
  }
}
