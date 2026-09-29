import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../services/auth_session.dart';
import 'package:fe/quiz/exercises/exercise_models.dart';

class AssignedQuizService {
  static const String _baseUrl = 'https://dmi-student-lab.vercel.app';
  static const String _host = 'dmi-student-lab.vercel.app';

  Uri _uri(String path) {
    final Uri base = Uri.parse(_baseUrl);
    final String normalizedPath = path.startsWith('/') ? path : '/$path';
    final Uri result = base.replace(path: normalizedPath);

    if (result.scheme != 'https' || result.host != _host) {
      throw StateError('Endpoint StudentLab non autorizzato.');
    }

    return result;
  }

  Map<String, String> get _headers {
    final String? token = AuthSession.instance.accessToken?.trim();

    if (token == null || token.isEmpty) {
      throw StateError('Utente non autenticato.');
    }

    return <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<dynamic> _decode(http.Response response, String fallback) async {
    dynamic body;

    if (response.body.trim().isNotEmpty) {
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = null;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    String detail = '';
    if (body is Map) {
      final dynamic rawDetail = body['detail'] ?? body['error'];
      if (rawDetail is String && rawDetail.trim().isNotEmpty) {
        detail = rawDetail.trim();
      }
    }

    switch (response.statusCode) {
      case 401:
        throw Exception(
          'La sessione non è più valida. Accedi nuovamente a StudentLab.',
        );
      case 403:
        throw Exception(
          detail.isNotEmpty
              ? detail
              : 'Non hai i permessi per visualizzare questi quiz.',
        );
      case 404:
        throw Exception(
          detail.isNotEmpty
              ? detail
              : 'La risorsa richiesta non è disponibile.',
        );
      default:
        if (response.statusCode >= 500) {
          throw Exception(
            'StudentLab non riesce a caricare i quiz assegnati in questo momento. Riprova tra poco.',
          );
        }
        throw Exception(detail.isNotEmpty ? detail : fallback);
    }
  }

  List<Map<String, dynamic>> _asList(dynamic value, String message) {
    if (value is! List) {
      throw Exception(message);
    }

    return value
        .whereType<Map>()
        .map((Map item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Map<String, dynamic> _asMap(dynamic value, String message) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    throw Exception(message);
  }

  Future<List<Map<String, dynamic>>> getAssignedQuizzes() async {
    final http.Response response = await http.get(
      _uri('/quiz-assignments/me'),
      headers: _headers,
    );

    return _asList(
      await _decode(
        response,
        'Non è stato possibile caricare i quiz assegnati.',
      ),
      'Il server ha restituito un elenco quiz non valido.',
    );
  }

  Future<Map<String, dynamic>> startAssignedQuiz(int assignmentId) async {
    final http.Response response = await http.post(
      // v18: i tipi di esercizio che questa app sa mostrare
      _uri('/quiz-attempts/assignments/$assignmentId/start').replace(
        queryParameters: <String, String>{'supported_types': kExerciseTypes.join(',')},
      ),
      headers: _headers,
    );

    return _asMap(
      await _decode(response, 'Non è stato possibile avviare il quiz.'),
      'Il server ha restituito un tentativo quiz non valido.',
    );
  }

  Future<Map<String, dynamic>> resumeAttempt(int attemptId) async {
    final http.Response response = await http.get(
      _uri('/quiz-attempts/$attemptId/resume'),
      headers: _headers,
    );

    return _asMap(
      await _decode(response, 'Non è stato possibile riprendere il quiz.'),
      'Il server ha restituito un tentativo quiz non valido.',
    );
  }

  Future<Map<String, dynamic>> getAttempt(int attemptId) async {
    final http.Response response = await http.get(
      _uri('/quiz-attempts/$attemptId'),
      headers: _headers,
    );

    return _asMap(
      await _decode(response, 'Non è stato possibile caricare il tentativo.'),
      'Il server ha restituito un tentativo quiz non valido.',
    );
  }

  Future<Map<String, dynamic>> completeAttempt({
    required int attemptId,
    required List<Map<String, dynamic>> answers,
    required int elapsedSeconds,
  }) async {
    final http.Response response = await http.post(
      _uri('/quiz-attempts/$attemptId/complete'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{
        'answers': answers,
        'elapsed_seconds': elapsedSeconds,
      }),
    );

    return _asMap(
      await _decode(response, 'Non è stato possibile completare il quiz.'),
      'Il server ha restituito un risultato quiz non valido.',
    );
  }

  Future<List<Map<String, dynamic>>> getHistory({
    bool includeHidden = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final Uri uri = _uri('/quiz-attempts/me').replace(
      queryParameters: <String, String>{
        'include_hidden': includeHidden ? 'true' : 'false',
        'limit': '$limit',
        'offset': '$offset',
      },
    );

    final http.Response response = await http.get(uri, headers: _headers);

    final dynamic decoded = await _decode(
      response,
      'Non è stato possibile caricare lo storico quiz.',
    );

    if (decoded is List) {
      return _asList(decoded, 'Storico quiz non valido.');
    }

    if (decoded is Map && decoded['attempts'] is List) {
      return _asList(decoded['attempts'], 'Storico quiz non valido.');
    }

    if (decoded is Map && decoded['items'] is List) {
      return _asList(decoded['items'], 'Storico quiz non valido.');
    }

    throw Exception('Storico quiz non valido.');
  }
}
