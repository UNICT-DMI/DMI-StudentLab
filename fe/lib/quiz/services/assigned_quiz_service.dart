import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../services/auth_session.dart';

class AssignedQuizService {
  static const String _baseUrl =
      'https://dmi-student-lab.vercel.app';

  Uri _uri(String path) {
    final base = Uri.parse(_baseUrl);
    return base.replace(
      path: path.startsWith('/')
          ? path
          : '/$path',
    );
  }

  Map<String, String> get _headers {
    final token =
        AuthSession.instance.accessToken?.trim();

    if (token == null || token.isEmpty) {
      throw Exception(
        'Utente non autenticato.',
      );
    }

    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> _decode(
    http.Response response,
    String fallback,
  ) async {
    dynamic body;

    if (response.body.trim().isNotEmpty) {
      try {
        body = jsonDecode(
          response.body,
        );
      } catch (_) {
        body = null;
      }
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return body;
    }

    String message = fallback;

    if (body is Map) {
      final detail =
          body['detail'] ?? body['error'];

      if (detail is String &&
          detail.trim().isNotEmpty) {
        message = detail.trim();
      }
    }

    throw Exception(message);
  }

  List<Map<String, dynamic>> _asList(
    dynamic value,
    String message,
  ) {
    if (value is! List) {
      throw Exception(message);
    }

    return value
        .whereType<Map>()
        .map(
          (item) =>
              Map<String, dynamic>.from(
            item,
          ),
        )
        .toList();
  }

  Map<String, dynamic> _asMap(
    dynamic value,
    String message,
  ) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(
        value,
      );
    }

    throw Exception(message);
  }

  Future<List<Map<String, dynamic>>>
      getAssignedQuizzes() async {
    final response = await http.get(
      _uri(
        '/quiz-assignments/student',
      ),
      headers: _headers,
    );

    return _asList(
      await _decode(
        response,
        'Non è stato possibile caricare i quiz assegnati.',
      ),
      'Elenco quiz assegnati non valido.',
    );
  }

  Future<Map<String, dynamic>>
      startAssignedQuiz(
    int assignmentId,
  ) async {
    final response = await http.post(
      _uri(
        '/quiz-attempts/assignments/$assignmentId/start',
      ),
      headers: _headers,
    );

    return _asMap(
      await _decode(
        response,
        'Non è stato possibile avviare il quiz.',
      ),
      'Tentativo quiz non valido.',
    );
  }

  Future<Map<String, dynamic>>
      getAttempt(
    int attemptId,
  ) async {
    final response = await http.get(
      _uri(
        '/quiz-attempts/$attemptId',
      ),
      headers: _headers,
    );

    return _asMap(
      await _decode(
        response,
        'Non è stato possibile caricare il tentativo.',
      ),
      'Tentativo quiz non valido.',
    );
  }

  Future<Map<String, dynamic>>
      completeAttempt({
    required int attemptId,
    required List<Map<String, dynamic>>
        answers,
    required int elapsedSeconds,
  }) async {
    final response = await http.post(
      _uri(
        '/quiz-attempts/$attemptId/complete',
      ),
      headers: _headers,
      body: jsonEncode({
        'answers': answers,
        'elapsed_seconds':
            elapsedSeconds,
      }),
    );

    return _asMap(
      await _decode(
        response,
        'Non è stato possibile completare il quiz.',
      ),
      'Risultato quiz non valido.',
    );
  }

  Future<List<Map<String, dynamic>>>
      getHistory({
    bool includeHidden = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final base = _uri(
      '/quiz-attempts/me',
    );

    final uri = base.replace(
      queryParameters: {
        'include_hidden':
            includeHidden
                ? 'true'
                : 'false',
        'limit': '$limit',
        'offset': '$offset',
      },
    );

    final response =
        await http.get(
      uri,
      headers: _headers,
    );

    final decoded = await _decode(
      response,
      'Non è stato possibile caricare lo storico quiz.',
    );

    if (decoded is List) {
      return _asList(
        decoded,
        'Storico quiz non valido.',
      );
    }

    if (decoded is Map &&
        decoded['attempts'] is List) {
      return _asList(
        decoded['attempts'],
        'Storico quiz non valido.',
      );
    }

    if (decoded is Map &&
        decoded['items'] is List) {
      return _asList(
        decoded['items'],
        'Storico quiz non valido.',
      );
    }

    throw Exception(
      'Storico quiz non valido.',
    );
  }
}