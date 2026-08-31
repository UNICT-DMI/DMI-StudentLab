import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../services/auth_session.dart';


class TeacherQuizStatisticsService {
  static const String _baseUrl =
      'https://dmi-student-lab.vercel.app';


  Uri _uri(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    final Uri base =
        Uri.parse(
      _baseUrl,
    );

    return base.replace(
      path:
          path.startsWith('/')
              ? path
              : '/$path',
      queryParameters:
          queryParameters,
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


  List<Map<String, dynamic>> _mapList(
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
      getStudentArguments({
    required int studentId,
    required String department,
    required String course,
    required String subject,
  }) async {
    final http.Response response =
        await http.get(
      _uri(
        '/quiz-statistics/students/$studentId/arguments',
        queryParameters: {
          'department':
              department,
          'course':
              course,
          'subject':
              subject,
        },
      ),
      headers:
          _headers,
    );

    return _mapList(
      await _decode(
        response,
        'Non è stato possibile caricare le statistiche per argomento.',
      ),
      'Statistiche per argomento non valide.',
    );
  }


  Future<List<Map<String, dynamic>>>
      getStudentQuestions({
    required int studentId,
    required String department,
    required String course,
    required String subject,
    String? argument,
  }) async {
    final Map<String, String> query = {
      'department':
          department,
      'course':
          course,
      'subject':
          subject,
      if (
        argument != null &&
        argument.trim().isNotEmpty
      )
        'argument':
            argument.trim(),
    };

    final http.Response response =
        await http.get(
      _uri(
        '/quiz-statistics/students/$studentId/questions',
        queryParameters:
            query,
      ),
      headers:
          _headers,
    );

    return _mapList(
      await _decode(
        response,
        'Non è stato possibile caricare le statistiche delle domande.',
      ),
      'Statistiche domande non valide.',
    );
  }


  Future<List<Map<String, dynamic>>>
      getStudentWeakArguments({
    required int studentId,
    required String department,
    required String course,
    required String subject,
    double maximumAccuracy = 70,
    int minimumAnswers = 1,
  }) async {
    final http.Response response =
        await http.get(
      _uri(
        '/quiz-statistics/students/$studentId/weak-arguments',
        queryParameters: {
          'department':
              department,
          'course':
              course,
          'subject':
              subject,
          'maximum_accuracy':
              maximumAccuracy.toString(),
          'minimum_answers':
              minimumAnswers.toString(),
        },
      ),
      headers:
          _headers,
    );

    return _mapList(
      await _decode(
        response,
        'Non è stato possibile caricare gli argomenti da ripassare.',
      ),
      'Argomenti deboli non validi.',
    );
  }


  Future<List<Map<String, dynamic>>>
      getStudentReview({
    required int studentId,
    required String department,
    required String course,
    required String subject,
    String? argument,
  }) async {
    final Map<String, String> query = {
      'department':
          department,
      'course':
          course,
      'subject':
          subject,
      'include_correct':
          'false',
      if (
        argument != null &&
        argument.trim().isNotEmpty
      )
        'argument':
            argument.trim(),
    };

    final http.Response response =
        await http.get(
      _uri(
        '/quiz-statistics/students/$studentId/review',
        queryParameters:
            query,
      ),
      headers:
          _headers,
    );

    return _mapList(
      await _decode(
        response,
        'Non è stato possibile caricare le domande da rivedere.',
      ),
      'Domande da rivedere non valide.',
    );
  }
}