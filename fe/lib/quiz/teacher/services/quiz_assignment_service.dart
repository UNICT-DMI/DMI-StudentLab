import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../services/auth_session.dart';


class QuizAssignmentService {
  static const String _baseUrl =
      'https://dmi-student-lab.vercel.app';

  Uri _uri(
    String path,
  ) {
    final Uri base =
        Uri.parse(
      _baseUrl,
    );

    return base.replace(
      path:
          path.startsWith('/')
              ? path
              : '/$path',
    );
  }


  Map<String, String> get _headers {
    final String? token =
        AuthSession.instance.accessToken;

    if (
      token == null ||
      token.trim().isEmpty
    ) {
      throw Exception(
        'Utente non autenticato.',
      );
    }

    return {
      'Accept':
          'application/json',
      'Content-Type':
          'application/json',
      'Authorization':
          'Bearer ${token.trim()}',
    };
  }


  Future<dynamic> _decode(
    http.Response response,
    String fallback,
  ) async {
    dynamic decoded;

    if (
      response.body
          .trim()
          .isNotEmpty
    ) {
      try {
        decoded =
            jsonDecode(
          response.body,
        );
      } catch (_) {
        decoded =
            null;
      }
    }

    if (
      response.statusCode >= 200 &&
      response.statusCode < 300
    ) {
      return decoded;
    }

    String message =
        fallback;

    if (decoded is Map) {
      final dynamic detail =
          decoded['detail'] ??
          decoded['error'];

      if (
        detail is String &&
        detail.trim().isNotEmpty
      ) {
        message =
            detail.trim();
      }
    }

    throw Exception(
      message,
    );
  }


  Map<String, dynamic> _map(
    dynamic value,
    String message,
  ) {
    if (
      value is Map<String, dynamic>
    ) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(
        value,
      );
    }

    throw Exception(
      message,
    );
  }


  List<Map<String, dynamic>> _list(
    dynamic value,
    String message,
  ) {
    if (value is! List) {
      throw Exception(
        message,
      );
    }

    return value
        .whereType<Map>()
        .map(
          (
            Map item,
          ) =>
              Map<String, dynamic>.from(
            item,
          ),
        )
        .toList();
  }


  Future<List<Map<String, dynamic>>>
      getTeacherAssignments() async {
    final http.Response response =
        await http.get(
      _uri(
        '/quiz-assignments/teacher',
      ),
      headers:
          _headers,
    );

    return _list(
      await _decode(
        response,
        'Non è stato possibile caricare i quiz assegnati.',
      ),
      'Elenco quiz non valido.',
    );
  }


  Future<Map<String, dynamic>>
      getAssignment(
    int assignmentId,
  ) async {
    final http.Response response =
        await http.get(
      _uri(
        '/quiz-assignments/$assignmentId',
      ),
      headers:
          _headers,
    );

    return _map(
      await _decode(
        response,
        'Non è stato possibile caricare il quiz.',
      ),
      'Quiz non valido.',
    );
  }


  Future<Map<String, dynamic>>
      createAssignment(
    Map<String, dynamic> data,
  ) async {
    final http.Response response =
        await http.post(
      _uri(
        '/quiz-assignments',
      ),
      headers:
          _headers,
      body:
          jsonEncode(
        data,
      ),
    );

    return _map(
      await _decode(
        response,
        'Non è stato possibile creare il quiz.',
      ),
      'Quiz non valido.',
    );
  }


  Future<Map<String, dynamic>>
      updateAssignment({
    required int assignmentId,
    required Map<String, dynamic> data,
  }) async {
    final http.Response response =
        await http.patch(
      _uri(
        '/quiz-assignments/$assignmentId',
      ),
      headers:
          _headers,
      body:
          jsonEncode(
        data,
      ),
    );

    return _map(
      await _decode(
        response,
        'Non è stato possibile aggiornare il quiz.',
      ),
      'Quiz non valido.',
    );
  }


  Future<Map<String, dynamic>>
      deactivateAssignment(
    int assignmentId,
  ) async {
    final http.Response response =
        await http.post(
      _uri(
        '/quiz-assignments/$assignmentId/deactivate',
      ),
      headers:
          _headers,
    );

    return _map(
      await _decode(
        response,
        'Non è stato possibile disattivare il quiz.',
      ),
      'Quiz non valido.',
    );
  }


  Future<Map<String, dynamic>>
      activateAssignment(
    int assignmentId,
  ) async {
    return updateAssignment(
      assignmentId:
          assignmentId,
      data: {
        'is_active':
            true,
      },
    );
  }


  Future<void> deleteAssignment(
    int assignmentId,
  ) async {
    final http.Response response =
        await http.delete(
      _uri(
        '/quiz-assignments/$assignmentId',
      ),
      headers:
          _headers,
    );

    await _decode(
      response,
      'Non è stato possibile eliminare il quiz.',
    );
  }


  Future<List<Map<String, dynamic>>>
      getAssignmentResults(
    int assignmentId,
  ) async {
    final http.Response response =
        await http.get(
      _uri(
        '/quiz-assignments/$assignmentId/results',
      ),
      headers:
          _headers,
    );

    return _list(
      await _decode(
        response,
        'Non è stato possibile caricare i risultati.',
      ),
      'Risultati quiz non validi.',
    );
  }
}