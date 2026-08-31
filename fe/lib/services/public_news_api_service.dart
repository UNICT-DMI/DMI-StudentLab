import 'dart:convert';

import 'package:http/http.dart' as http;

import '../social/news/models/public_news.dart';
import 'auth_session.dart';

class PublicNewsApiService {
  static const String _baseUrl = 'https://dmi-student-lab.vercel.app';
  static const String _host = 'dmi-student-lab.vercel.app';

  final AuthSession _session;

  PublicNewsApiService({
    AuthSession? session,
  }) : _session = session ?? AuthSession.instance;

  Future<PublicNewsFeedResult> getFeed({
    String search = '',
    String city = '',
    String university = '',
    String department = '',
    String course = '',
    int? subjectId,
    int limit = 30,
    int offset = 0,
  }) async {
    final Uri url = _uri(
      '/public-news',
      query: {
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (city.trim().isNotEmpty) 'city': city.trim(),
        if (university.trim().isNotEmpty) 'university': university.trim(),
        if (department.trim().isNotEmpty) 'department': department.trim(),
        if (course.trim().isNotEmpty) 'course': course.trim(),
        if (subjectId != null) 'subject_id': subjectId,
        'limit': limit.clamp(1, 100),
        'offset': offset < 0 ? 0 : offset,
      },
    );

    final http.Response response = await http.get(
      url,
      headers: _headers,
    );

    return PublicNewsFeedResult.fromJson(
      _decodeMap(response, 'Impossibile caricare le news.'),
    );
  }

  Future<PublicNews> getDetail(int newsId) async {
    _requirePositiveId(newsId);

    final http.Response response = await http.get(
      _uri('/public-news/$newsId'),
      headers: _headers,
    );

    return PublicNews.fromJson(
      _decodeMap(response, 'Impossibile caricare la news.'),
    );
  }

  Future<PublicNews> create({
    required String targetType,
    required String title,
    required String content,
    int? subjectId,
    String city = '',
    String university = '',
    String universityCode = '',
    String department = '',
    String departmentCode = '',
    String course = '',
    String courseCode = '',
  }) async {
    _requireAuthenticated();

    final String normalizedType = targetType.trim().toLowerCase();
    if (!{'all', 'university', 'department', 'course', 'subject'}
        .contains(normalizedType)) {
      throw ArgumentError('Destinazione della news non valida.');
    }

    final String normalizedTitle =
        title.trim().split(RegExp(r'\s+')).join(' ');
    final String normalizedContent = content.trim();

    if (normalizedTitle.isEmpty || normalizedTitle.length > 160) {
      throw ArgumentError('Titolo della news non valido.');
    }

    if (normalizedContent.isEmpty || normalizedContent.length > 5000) {
      throw ArgumentError('Contenuto della news non valido.');
    }

    if (normalizedType == 'subject' && (subjectId == null || subjectId <= 0)) {
      throw ArgumentError('Seleziona una materia.');
    }

    final http.Response response = await http.post(
      _uri('/public-news'),
      headers: _headers,
      body: jsonEncode({
        'target_type': normalizedType,
        'title': normalizedTitle,
        'content': normalizedContent,
        'subject_id': subjectId,
        'city': _nullable(city),
        'university': _nullable(university),
        'university_code': _nullable(universityCode),
        'department': _nullable(department),
        'department_code': _nullable(departmentCode),
        'course': _nullable(course),
        'course_code': _nullable(courseCode),
      }),
    );

    return PublicNews.fromJson(
      _decodeMap(response, 'Impossibile pubblicare la news.'),
    );
  }

  Future<void> delete(int newsId) async {
    _requireAuthenticated();
    _requirePositiveId(newsId);

    final http.Response response = await http.delete(
      _uri('/public-news/$newsId'),
      headers: _headers,
    );

    _decodeMap(response, 'Impossibile eliminare la news.');
  }

  Future<PublicNews> moderate({
    required int newsId,
    required String reason,
  }) async {
    _requireAuthenticated();
    _requirePositiveId(newsId);

    final String normalizedReason = reason.trim();
    if (normalizedReason.isEmpty || normalizedReason.length > 1000) {
      throw ArgumentError('Motivo della moderazione non valido.');
    }

    final http.Response response = await http.post(
      _uri('/public-news/$newsId/moderate'),
      headers: _headers,
      body: jsonEncode({
        'reason': normalizedReason,
      }),
    );

    return PublicNews.fromJson(
      _decodeMap(response, 'Impossibile moderare la news.'),
    );
  }

  Future<PublicNewsReport> report({
    required int newsId,
    required String reason,
    String description = '',
  }) async {
    _requireAuthenticated();
    _requirePositiveId(newsId);

    final http.Response response = await http.post(
      _uri('/public-news-reports/$newsId'),
      headers: _headers,
      body: jsonEncode({
        'reason': reason.trim(),
        'description': description.trim(),
      }),
    );

    return PublicNewsReport.fromJson(
      _decodeMap(response, 'Impossibile inviare la segnalazione.'),
    );
  }

  Future<PublicNewsReportsResult> getReports({
    String status = '',
    int limit = 50,
    int offset = 0,
  }) async {
    _requireAuthenticated();

    final http.Response response = await http.get(
      _uri(
        '/public-news-reports/admin',
        query: {
          if (status.trim().isNotEmpty) 'status': status.trim(),
          'limit': limit.clamp(1, 100),
          'offset': offset < 0 ? 0 : offset,
        },
      ),
      headers: _headers,
    );

    return PublicNewsReportsResult.fromJson(
      _decodeMap(response, 'Impossibile caricare le segnalazioni.'),
    );
  }

  Future<PublicNewsReport> moderateReport({
    required int reportId,
    required String status,
    required String action,
    String note = '',
  }) async {
    _requireAuthenticated();
    _requirePositiveId(reportId);

    final http.Response response = await http.patch(
      _uri('/public-news-reports/admin/$reportId'),
      headers: _headers,
      body: jsonEncode({
        'status': status.trim(),
        'action': action.trim(),
        'note': note.trim(),
      }),
    );

    return PublicNewsReport.fromJson(
      _decodeMap(response, 'Impossibile aggiornare la segnalazione.'),
    );
  }

  Future<void> blockAuthor(int userId) async {
    _requireAuthenticated();
    _requirePositiveId(userId);

    final http.Response response = await http.post(
      _uri('/user-blocks'),
      headers: _headers,
      body: jsonEncode({
        'blocked_user_id': userId,
      }),
    );

    _decodeMap(response, 'Impossibile bloccare l’utente.');
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

  void _requirePositiveId(int value) {
    if (value <= 0) {
      throw ArgumentError('Identificativo non valido.');
    }
  }

  String? _nullable(String value) {
    final String normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
