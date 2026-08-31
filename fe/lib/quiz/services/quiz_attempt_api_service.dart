import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../services/auth_session.dart';

class QuizAttemptApiService {
  static const String _baseUrl = 'https://dmi-student-lab.vercel.app';

  Uri _uri(String path) => Uri.parse('$_baseUrl${path.startsWith('/') ? path : '/$path'}');

  Map<String, String> get _headers {
    final token = AuthSession.instance.accessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Utente non autenticato.');
    }
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token.trim()}',
    };
  }

  dynamic _decode(http.Response response, String fallback) {
    dynamic body;
    if (response.body.trim().isNotEmpty) {
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = null;
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    if (body is Map && body['detail'] is String && (body['detail'] as String).trim().isNotEmpty) {
      throw Exception((body['detail'] as String).trim());
    }
    throw Exception(fallback);
  }

  Future<Map<String, dynamic>> startAssignedQuiz(int assignmentId) async {
    final response = await http.post(
      _uri('/quiz-attempts/assignments/$assignmentId/start'),
      headers: _headers,
    );
    return Map<String, dynamic>.from(
      _decode(response, 'Non è stato possibile avviare il quiz.') as Map,
    );
  }

  Future<Map<String, dynamic>> resumeAttempt(int attemptId) async {
    final response = await http.get(
      _uri('/quiz-attempts/$attemptId/resume'),
      headers: _headers,
    );
    return Map<String, dynamic>.from(
      _decode(response, 'Non è stato possibile riprendere il quiz.') as Map,
    );
  }

  Future<void> registerInterruption(int attemptId) async {
    final response = await http.post(
      _uri('/quiz-attempts/$attemptId/interruption'),
      headers: _headers,
    );
    _decode(response, 'Non è stato possibile registrare l’interruzione.');
  }

  Future<Map<String, dynamic>> completeAttempt({
    required int attemptId,
    required List<Map<String, dynamic>> answers,
    required int elapsedSeconds,
    required String completionReason,
    required int interruptionCount,
  }) async {
    final response = await http.post(
      _uri('/quiz-attempts/$attemptId/complete'),
      headers: _headers,
      body: jsonEncode({
        'answers': answers,
        'elapsed_seconds': elapsedSeconds,
        'completion_reason': completionReason,
        'interruption_count': interruptionCount,
      }),
    );
    return Map<String, dynamic>.from(
      _decode(response, 'Non è stato possibile consegnare il quiz.') as Map,
    );
  }
}