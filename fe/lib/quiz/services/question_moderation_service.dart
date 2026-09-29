import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../services/auth_session.dart';

class QuestionModerationService {
  static const String _baseUrl = 'https://dmi-student-lab.vercel.app';

  Map<String, String> get _headers {
    final String? token = AuthSession.instance.accessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Utente non autenticato.');
    }
    return <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token.trim()}',
    };
  }

  Uri _uri(String path, {Map<String, String>? query}) {
    return Uri.parse(_baseUrl).replace(path: path, queryParameters: query);
  }

  Future<dynamic> _decode(http.Response response, String fallback) async {
    dynamic decoded;
    if (response.body.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {}
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    String message = fallback;
    if (decoded is Map && decoded['detail'] != null) {
      message = decoded['detail'].toString().trim();
    }
    throw Exception(message.isEmpty ? fallback : message);
  }

  Future<Map<String, dynamic>> reportQuestion({
    required String department,
    required String course,
    required String subject,
    required String questionId,
    required String reason,
    String? message,
  }) async {
    final http.Response response = await http.post(
      _uri('/question-moderation/reports'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{
        'department': department.trim(),
        'course': course.trim(),
        'subject': subject.trim(),
        'question_id': questionId.trim(),
        'reason': reason,
        'message': message?.trim().isEmpty == true ? null : message?.trim(),
      }),
    );
    final dynamic decoded = await _decode(
      response,
      'Non è stato possibile inviare la segnalazione.',
    );
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createProposal({
    required String department,
    required String course,
    required String subject,
    required Map<String, dynamic> question,
  }) async {
    final http.Response response = await http.post(
      _uri('/question-moderation/proposals'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{
        'department': department.trim(),
        'course': course.trim(),
        'subject': subject.trim(),
        'question': question,
      }),
    );
    final dynamic decoded = await _decode(
      response,
      'Non è stato possibile inviare la proposta.',
    );
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> createProposalBatch(
    List<Map<String, dynamic>> proposals,
  ) async {
    final http.Response response = await http.post(
      _uri('/question-moderation/proposals/batch'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{'proposals': proposals}),
    );
    final dynamic decoded = await _decode(
      response,
      'Non è stato possibile importare le proposte.',
    );
    if (decoded is! List) {
      return <Map<String, dynamic>>[];
    }
    return decoded
        .whereType<Map>()
        .map((Map item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> myProposals() async {
    final http.Response response = await http.get(
      _uri('/question-moderation/mine'),
      headers: _headers,
    );
    final dynamic decoded = await _decode(
      response,
      'Non è stato possibile caricare le tue proposte.',
    );
    if (decoded is! List) {
      return <Map<String, dynamic>>[];
    }
    return decoded
        .whereType<Map>()
        .map((Map item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> updateProposal({
    required int itemId,
    required Map<String, dynamic> question,
  }) async {
    final http.Response response = await http.patch(
      _uri('/question-moderation/$itemId/proposal'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{'question': question}),
    );
    final dynamic decoded = await _decode(
      response,
      'Non è stato possibile aggiornare la proposta.',
    );
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
  }

  Future<void> deleteMyProposal(int itemId) async {
    final http.Response response = await http.delete(
      _uri('/question-moderation/proposals/$itemId'),
      headers: _headers,
    );
    await _decode(response, 'Non è stato possibile eliminare la proposta.');
  }

  Future<void> cleanupTemporaryAttachments(
    List<Map<String, dynamic>> attachments,
  ) async {
    if (attachments.isEmpty) {
      return;
    }
    final http.Response response = await http.post(
      _uri('/question-moderation/temporary-attachments/cleanup'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{'attachments': attachments}),
    );
    await _decode(
      response,
      'Non è stato possibile completare la pulizia degli allegati.',
    );
  }

  Future<List<Map<String, dynamic>>> listItems({
    String? status,
    String? department,
    String? course,
    String? subject,
  }) async {
    final Map<String, String> query = <String, String>{};
    if (status != null && status.trim().isNotEmpty)
      query['status'] = status.trim();
    if (department != null && department.trim().isNotEmpty)
      query['department'] = department.trim();
    if (course != null && course.trim().isNotEmpty)
      query['course'] = course.trim();
    if (subject != null && subject.trim().isNotEmpty)
      query['subject'] = subject.trim();
    final http.Response response = await http.get(
      _uri('/question-moderation', query: query.isEmpty ? null : query),
      headers: _headers,
    );
    final dynamic decoded = await _decode(
      response,
      'Non è stato possibile caricare le revisioni.',
    );
    if (decoded is! List) return <Map<String, dynamic>>[];
    return decoded
        .whereType<Map>()
        .map((Map item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> claim(int itemId) async {
    final http.Response response = await http.post(
      _uri('/question-moderation/$itemId/claim'),
      headers: _headers,
      body: '{}',
    );
    final dynamic decoded = await _decode(
      response,
      'Non è stato possibile prendere in carico la revisione.',
    );
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> resolve({
    required int itemId,
    required String status,
    String? resolutionNote,
  }) async {
    final http.Response response = await http.patch(
      _uri('/question-moderation/$itemId/resolution'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{
        'status': status,
        'resolution_note': resolutionNote?.trim().isEmpty == true
            ? null
            : resolutionNote?.trim(),
      }),
    );
    final dynamic decoded = await _decode(
      response,
      'Non è stato possibile completare la revisione.',
    );
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
  }
}
