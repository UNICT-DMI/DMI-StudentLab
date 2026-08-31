import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../local_storage/repositories/quiz_attempt_local_repository.dart';
import '../../../services/auth_session.dart';

class StudentQuizReviewService {
  static const String _baseUrl =
      'https://dmi-student-lab.vercel.app';

  final QuizAttemptLocalRepository
      _localRepository;

  StudentQuizReviewService({
    QuizAttemptLocalRepository?
        localRepository,
  }) : _localRepository =
            localRepository ??
                QuizAttemptLocalRepository();

  bool get _guest =>
      AuthSession.instance.isGuest;

  Uri _uri(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    final Uri base =
        Uri.parse(_baseUrl);

    return base.replace(
      path: path.startsWith('/')
          ? path
          : '/$path',
      queryParameters:
          queryParameters == null ||
                  queryParameters.isEmpty
              ? null
              : queryParameters,
    );
  }

  Map<String, String> get _headers {
    final String? token =
        AuthSession.instance.accessToken;

    if (token == null ||
        token.trim().isEmpty) {
      throw StateError(
        'Sessione StudentLab non disponibile.',
      );
    }

    return <String, String>{
      'Accept': 'application/json',
      'Authorization':
          'Bearer ${token.trim()}',
    };
  }

  Future<dynamic> _decode(
    http.Response response,
    String fallback,
  ) async {
    dynamic decoded;

    if (response.body.trim().isNotEmpty) {
      try {
        decoded =
            jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return decoded;
    }

    String message =
        fallback;

    if (decoded is Map) {
      final dynamic detail =
          decoded['detail'] ??
              decoded['error'];

      if (detail is String &&
          detail.trim().isNotEmpty) {
        message =
            detail.trim();
      }
    }

    throw Exception(message);
  }

  Map<String, dynamic> _map(
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

  List<Map<String, dynamic>> _list(
    dynamic value,
    String message,
  ) {
    if (value is! List) {
      throw Exception(message);
    }

    return value
        .whereType<Map>()
        .map(
          (Map item) =>
              Map<String, dynamic>.from(
            item,
          ),
        )
        .toList();
  }

  Future<Map<String, dynamic>>
      getOverall() async {
    if (_guest) {
      return _localRepository
          .getGuestOverall();
    }

    final http.Response response =
        await http.get(
      _uri('/quiz-statistics/me/overall'),
      headers: _headers,
    );

    return _map(
      await _decode(
        response,
        'Non è stato possibile caricare le statistiche generali.',
      ),
      'Statistiche generali non valide.',
    );
  }

  Future<List<Map<String, dynamic>>>
      getSubjects() async {
    if (_guest) {
      return _localRepository
          .getGuestSubjects();
    }

    final http.Response response =
        await http.get(
      _uri('/quiz-statistics/me/subjects'),
      headers: _headers,
    );

    return _list(
      await _decode(
        response,
        'Non è stato possibile caricare le statistiche per materia.',
      ),
      'Statistiche delle materie non valide.',
    );
  }

  Future<List<Map<String, dynamic>>>
      getArguments({
    String? department,
    String? course,
    String? subject,
  }) async {
    if (_guest) {
      return _localRepository
          .getGuestArguments(
        department:
            department,
        course:
            course,
        subject:
            subject,
      );
    }

    final http.Response response =
        await http.get(
      _uri(
        '/quiz-statistics/me/arguments',
        queryParameters:
            _filters(
          department:
              department,
          course:
              course,
          subject:
              subject,
        ),
      ),
      headers: _headers,
    );

    return _list(
      await _decode(
        response,
        'Non è stato possibile caricare le statistiche per argomento.',
      ),
      'Statistiche degli argomenti non valide.',
    );
  }

  Future<List<Map<String, dynamic>>>
      getWeakArguments({
    String? department,
    String? course,
    String? subject,
    double maximumAccuracy = 70,
    int minimumAnswers = 1,
  }) async {
    if (_guest) {
      return _localRepository
          .getGuestWeakArguments(
        department:
            department,
        course:
            course,
        subject:
            subject,
        maximumAccuracy:
            maximumAccuracy,
        minimumAnswers:
            minimumAnswers,
      );
    }

    final Map<String, String> query =
        _filters(
      department:
          department,
      course:
          course,
      subject:
          subject,
    );

    query['maximum_accuracy'] =
        maximumAccuracy.toString();

    query['minimum_answers'] =
        minimumAnswers.toString();

    final http.Response response =
        await http.get(
      _uri(
        '/quiz-statistics/me/weak-arguments',
        queryParameters:
            query,
      ),
      headers: _headers,
    );

    return _list(
      await _decode(
        response,
        'Non è stato possibile caricare gli argomenti da rafforzare.',
      ),
      'Argomenti da rafforzare non validi.',
    );
  }

  Future<List<Map<String, dynamic>>>
      getReview({
    String? department,
    String? course,
    String? subject,
    String? argument,
    bool includeCorrect = false,
  }) async {
    if (_guest) {
      return _localRepository
          .getGuestReview(
        department:
            department,
        course:
            course,
        subject:
            subject,
        argument:
            argument,
        includeCorrect:
            includeCorrect,
      );
    }

    final Map<String, String> query =
        _filters(
      department:
          department,
      course:
          course,
      subject:
          subject,
    );

    query['include_correct'] =
        includeCorrect
            ? 'true'
            : 'false';

    if (argument != null &&
        argument.trim().isNotEmpty) {
      query['argument'] =
          argument.trim();
    }

    final http.Response response =
        await http.get(
      _uri(
        '/quiz-statistics/me/review',
        queryParameters:
            query,
      ),
      headers: _headers,
    );

    return _list(
      await _decode(
        response,
        'Non è stato possibile caricare le domande da rivedere.',
      ),
      'Domande da rivedere non valide.',
    );
  }

  Map<String, String> _filters({
    String? department,
    String? course,
    String? subject,
  }) {
    return <String, String>{
      if (department != null &&
          department.trim().isNotEmpty)
        'department':
            department.trim(),
      if (course != null &&
          course.trim().isNotEmpty)
        'course':
            course.trim(),
      if (subject != null &&
          subject.trim().isNotEmpty)
        'subject':
            subject.trim(),
    };
  }
}
