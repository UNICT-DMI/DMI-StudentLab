import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../services/auth_session.dart';

class SupportApiService {
  static const String _baseUrl =
      'https://dmi-student-lab.vercel.app';

  Map<String, String> get _headers {
    final String? token =
        AuthSession.instance.accessToken;

    if (token == null || token.trim().isEmpty) {
      throw StateError('Utente non autenticato.');
    }

    return <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token.trim()}',
    };
  }

  Uri _uri(
    String path, [
    Map<String, String>? query,
  ]) {
    return Uri.parse('$_baseUrl$path').replace(
      queryParameters:
          query == null || query.isEmpty
              ? null
              : query,
    );
  }

  Future<Map<String, dynamic>> createSession({
    required String summary,
    String? details,
  }) async {
    return _map(
      await http.post(
        _uri('/support/sessions'),
        headers: _headers,
        body: jsonEncode(<String, dynamic>{
          'issue_summary': summary.trim(),
          'issue_details': details?.trim(),
        }),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> mySessions() async {
    return _list(
      await http.get(
        _uri('/support/sessions/me'),
        headers: _headers,
      ),
    );
  }

  Future<Map<String, dynamic>> getSession(
    int sessionId,
  ) async {
    return _map(
      await http.get(
        _uri('/support/sessions/$sessionId'),
        headers: _headers,
      ),
    );
  }

  Future<Map<String, dynamic>> consent({
    required int sessionId,
    required bool accepted,
    String scope = 'diagnostic',
  }) async {
    return _map(
      await http.post(
        _uri('/support/sessions/$sessionId/consent'),
        headers: _headers,
        body: jsonEncode(<String, dynamic>{
          'accepted': accepted,
          'scope': scope,
        }),
      ),
    );
  }

  Future<Map<String, dynamic>> heartbeat(
    int sessionId,
  ) async {
    return _map(
      await http.post(
        _uri('/support/sessions/$sessionId/heartbeat'),
        headers: _headers,
        body: jsonEncode(<String, dynamic>{}),
      ),
    );
  }

  Future<Map<String, dynamic>> sendSnapshot({
    required int sessionId,
    required Map<String, dynamic> payload,
    int? databaseVersion,
    String? appVersion,
    String? platform,
  }) async {
    return _map(
      await http.post(
        _uri('/support/sessions/$sessionId/snapshot'),
        headers: _headers,
        body: jsonEncode(<String, dynamic>{
          'payload': payload,
          'database_version': databaseVersion,
          'app_version': appVersion,
          'platform': platform,
        }),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> pendingActions(
    int sessionId,
  ) async {
    return _list(
      await http.get(
        _uri('/support/sessions/$sessionId/actions'),
        headers: _headers,
      ),
    );
  }

  Future<Map<String, dynamic>> ackAction({
    required int sessionId,
    required int actionId,
    required String status,
    Map<String, dynamic>? result,
  }) async {
    return _map(
      await http.patch(
        _uri('/support/sessions/$sessionId/actions/$actionId'),
        headers: _headers,
        body: jsonEncode(<String, dynamic>{
          'status': status,
          'result': result,
        }),
      ),
    );
  }

  Future<Map<String, dynamic>> revoke(
    int sessionId,
  ) async {
    return _map(
      await http.post(
        _uri('/support/sessions/$sessionId/revoke'),
        headers: _headers,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> adminSessions({
    String? status,
  }) async {
    return _list(
      await http.get(
        _uri(
          '/support/admin/sessions',
          status == null
              ? null
              : <String, String>{
                  'status': status,
                },
        ),
        headers: _headers,
      ),
    );
  }

  Future<Map<String, dynamic>> adminSession(
    int sessionId,
  ) async {
    return _map(
      await http.get(
        _uri('/support/admin/sessions/$sessionId'),
        headers: _headers,
      ),
    );
  }

  Future<Map<String, dynamic>> acceptSession(
    int sessionId, {
    int minutes = 60,
  }) async {
    return _map(
      await http.post(
        _uri('/support/admin/sessions/$sessionId/accept'),
        headers: _headers,
        body: jsonEncode(<String, dynamic>{
          'session_minutes': minutes,
        }),
      ),
    );
  }

  Future<Map<String, dynamic>> createAction({
    required int sessionId,
    required String action,
    Map<String, dynamic>? payload,
  }) async {
    return _map(
      await http.post(
        _uri('/support/admin/sessions/$sessionId/actions'),
        headers: _headers,
        body: jsonEncode(<String, dynamic>{
          'action': action,
          'payload': payload,
        }),
      ),
    );
  }

  Future<Map<String, dynamic>> closeSession(
    int sessionId, {
    bool resolved = true,
  }) async {
    return _map(
      await http.post(
        _uri(
          '/support/admin/sessions/$sessionId/close',
          <String, String>{
            'resolved': resolved ? 'true' : 'false',
          },
        ),
        headers: _headers,
      ),
    );
  }

  Map<String, dynamic> _map(
    http.Response response,
  ) {
    final dynamic decoded =
        response.body.trim().isEmpty
            ? <String, dynamic>{}
            : jsonDecode(response.body);

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    throw Exception(_message(decoded));
  }

  List<Map<String, dynamic>> _list(
    http.Response response,
  ) {
    final dynamic decoded =
        response.body.trim().isEmpty
            ? <dynamic>[]
            : jsonDecode(response.body);

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        decoded is List) {
      return decoded
          .whereType<Map>()
          .map(
            (Map<dynamic, dynamic> value) =>
                Map<String, dynamic>.from(value),
          )
          .toList();
    }

    throw Exception(_message(decoded));
  }

  String _message(dynamic decoded) {
    if (decoded is Map) {
      final String detail =
          decoded['detail']?.toString().trim() ?? '';

      if (detail.isNotEmpty) {
        return detail;
      }
    }

    return 'Operazione di assistenza non riuscita.';
  }
}
