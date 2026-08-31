import 'dart:convert';

import 'package:http/http.dart' as http;

import '../social/news/models/news_report.dart';
import 'auth_session.dart';

class NewsReportApiService {
  static const String _baseUrl = 'https://dmi-student-lab.vercel.app';
  static const String _host = 'dmi-student-lab.vercel.app';

  static const int maxDescriptionLength = 2000;

  final AuthSession _session;
  final http.Client _client;

  NewsReportApiService({
    AuthSession? session,
    http.Client? client,
  })  : _session = session ?? AuthSession.instance,
        _client = client ?? http.Client();

  Future<NewsReport> reportAvviso({
    required String newsId,
    required String reason,
    String description = '',
  }) async {
    return _create(
      body: <String, dynamic>{
        'category': 'avvisi',
        'news_id': _requireId(newsId),
        'reason': _requireReason(reason),
        'description': _description(description),
      },
    );
  }

  Future<NewsReport> reportGroupNews({
    required int groupId,
    required String newsId,
    required String reason,
    String description = '',
  }) async {
    if (groupId <= 0) {
      throw ArgumentError('Gruppo non valido.');
    }

    return _create(
      body: <String, dynamic>{
        'category': 'gruppi',
        'news_id': _requireId(newsId),
        'group_id': groupId,
        'reason': _requireReason(reason),
        'description': _description(description),
      },
    );
  }

  Future<NewsReport> reportPrivateMessage({
    required int otherUserId,
    required String newsId,
    required String reason,
    required String disclosedContentKey,
    String description = '',
  }) async {
    if (otherUserId <= 0) {
      throw ArgumentError('Utente non valido.');
    }

    final String contentKey = disclosedContentKey.trim();

    if (contentKey.isEmpty) {
      throw ArgumentError(
        'Senza la chiave del messaggio la segnalazione non sarebbe '
        'verificabile.',
      );
    }

    return _create(
      body: <String, dynamic>{
        'category': 'private',
        'news_id': _requireId(newsId),
        'other_user_id': otherUserId,
        'reason': _requireReason(reason),
        'description': _description(description),
        'disclosed_content_key': contentKey,
        'disclosure_consent': true,
      },
    );
  }

  Future<NewsReportListResult> getOwnReports({
    int limit = 50,
    int offset = 0,
  }) async {
    _requireAuthenticated();

    final http.Response response = await _client.get(
      _uri(
        '/me/news-reports',
        query: _pagination(limit, offset),
      ),
      headers: _headers,
    );

    return NewsReportListResult.fromJson(
      _decodeMap(response, 'Impossibile caricare le segnalazioni.'),
    );
  }

  Future<NewsReportListResult> getReports({
    String status = '',
    String category = '',
    int limit = 50,
    int offset = 0,
  }) async {
    _requireAuthenticated();

    final http.Response response = await _client.get(
      _uri(
        '/admin/news-reports',
        query: <String, dynamic>{
          if (status.trim().isNotEmpty) 'status': status.trim(),
          if (category.trim().isNotEmpty) 'category': category.trim(),
          ..._pagination(limit, offset),
        },
      ),
      headers: _headers,
    );

    return NewsReportListResult.fromJson(
      _decodeMap(response, 'Impossibile caricare le segnalazioni.'),
    );
  }

  Future<NewsReport> moderateReport({
    required int reportId,
    required String status,
    String action = 'none',
    String note = '',
  }) async {
    _requireAuthenticated();

    if (reportId <= 0) {
      throw ArgumentError('Segnalazione non valida.');
    }

    if (action != 'none' && note.trim().isEmpty) {
      throw ArgumentError(
        'Per nascondere o rimuovere un contenuto serve una motivazione.',
      );
    }

    final http.Response response = await _client.patch(
      _uri('/admin/news-reports/$reportId'),
      headers: _headers,
      body: jsonEncode({
        'status': status.trim(),
        'action': action.trim(),
        'note': note.trim(),
      }),
    );

    return NewsReport.fromJson(
      _decodeMap(response, 'Impossibile aggiornare la segnalazione.'),
    );
  }

  Future<NewsReportDisclosure> openDisclosure(int reportId) async {
    _requireAuthenticated();

    if (reportId <= 0) {
      throw ArgumentError('Segnalazione non valida.');
    }

    final http.Response response = await _client.get(
      _uri('/admin/news-reports/$reportId/disclosure'),
      headers: _headers,
    );

    return NewsReportDisclosure.fromJson(
      _decodeMap(response, 'Impossibile aprire il contenuto segnalato.'),
    );
  }

  Future<NewsReport> _create({
    required Map<String, dynamic> body,
  }) async {
    _requireAuthenticated();

    final http.Response response = await _client.post(
      _uri('/news-reports'),
      headers: _headers,
      body: jsonEncode(body),
    );

    return NewsReport.fromJson(
      _decodeMap(response, 'Impossibile inviare la segnalazione.'),
    );
  }

  Map<String, dynamic> _pagination(int limit, int offset) {
    return <String, dynamic>{
      'limit': limit.clamp(1, 100),
      'offset': offset < 0 ? 0 : offset,
    };
  }

  Uri _uri(String path, {Map<String, dynamic>? query}) {
    final Uri base = Uri.parse(_baseUrl);
    final String normalizedPath = path.startsWith('/') ? path : '/$path';
    final Map<String, String> parameters = {};

    if (query != null) {
      for (final MapEntry<String, dynamic> entry in query.entries) {
        if (entry.value != null) {
          parameters[entry.key] = entry.value.toString();
        }
      }
    }

    final Uri result = base.replace(
      path: normalizedPath,
      queryParameters: parameters.isEmpty ? null : parameters,
    );

    if (result.scheme != 'https' || result.host != _host) {
      throw StateError('Endpoint backend non autorizzato.');
    }

    return result;
  }

  Map<String, String> get _headers {
    final String? token = _session.accessToken;

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decodeMap(
    http.Response response,
    String fallbackMessage,
  ) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.trim().isEmpty) {
        return <String, dynamic>{};
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      throw Exception(fallbackMessage);
    }

    String detail = '';
    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map) {
        detail = decoded['detail']?.toString().trim() ?? '';
      }
    } catch (_) {}

    throw Exception(
      detail.isNotEmpty
          ? '${response.statusCode}: $detail'
          : '${response.statusCode}: $fallbackMessage',
    );
  }

  void _requireAuthenticated() {
    if (!_session.isAuthenticated || _session.currentUserId == null) {
      throw StateError('Utente non autenticato.');
    }
  }

  String _requireId(String value) {
    final String normalized = value.trim();

    if (normalized.isEmpty || normalized.contains('/')) {
      throw ArgumentError('Identificativo della news non valido.');
    }

    return normalized;
  }

  String _requireReason(String value) {
    final String normalized = value.trim().toLowerCase();

    if (!NewsReportReasons.isValid(normalized)) {
      throw ArgumentError('Motivo della segnalazione non valido.');
    }

    return normalized;
  }

  String _description(String value) {
    final String normalized = value.trim();

    if (normalized.length > maxDescriptionLength) {
      throw ArgumentError('Descrizione troppo lunga.');
    }

    return normalized;
  }
}
