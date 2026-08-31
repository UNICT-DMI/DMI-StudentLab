import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/quiz_model.dart';
import '../social/social_models.dart';
import '../social/notifications/models/notification_model.dart';
import '../social/news/models/group_news.dart';

import 'auth_session.dart';
import 'blob_upload_service.dart';

class ApiRegistrationResponse {
  final String registrationId;

  final String email;

  final bool emailVerificationRequired;

  final int expiresIn;

  const ApiRegistrationResponse({
    required this.registrationId,
    required this.email,
    required this.emailVerificationRequired,
    required this.expiresIn,
  });

  factory ApiRegistrationResponse.fromJson(Map<String, dynamic> json) {
    final String registrationId =
        json['registration_id']?.toString().trim() ?? '';

    final String email = json['email']?.toString().trim() ?? '';

    final bool emailVerificationRequired =
        json['email_verification_required'] == true;

    final int expiresIn = _parseApiInt(json['expires_in']) ?? 0;

    if (registrationId.isEmpty) {
      throw Exception('Identificativo di registrazione non valido.');
    }

    if (email.isEmpty) {
      throw Exception('Email di registrazione non valida.');
    }

    if (expiresIn <= 0) {
      throw Exception('Durata della verifica email non valida.');
    }

    return ApiRegistrationResponse(
      registrationId: registrationId,
      email: email,
      emailVerificationRequired: emailVerificationRequired,
      expiresIn: expiresIn,
    );
  }
}

class ApiLoginResponse {
  final bool authenticated;

  final bool emailVerificationRequired;

  final String? accessToken;

  final String? registrationId;

  final String? email;

  final int expiresIn;

  const ApiLoginResponse({
    required this.authenticated,
    required this.emailVerificationRequired,
    this.accessToken,
    this.registrationId,
    this.email,
    required this.expiresIn,
  });

  factory ApiLoginResponse.fromJson(Map<String, dynamic> json) {
    final bool authenticated = json['authenticated'] == true;

    final bool emailVerificationRequired =
        json['email_verification_required'] == true;

    final String? accessToken = json['access_token']?.toString().trim();

    final String? registrationId = json['registration_id']?.toString().trim();

    final String? email = json['email']?.toString().trim();

    final int expiresIn = _parseApiInt(json['expires_in']) ?? 0;

    if (authenticated) {
      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('Token di accesso non restituito dal server.');
      }

      return ApiLoginResponse(
        authenticated: true,
        emailVerificationRequired: false,
        accessToken: accessToken,
        expiresIn: 0,
      );
    }

    if (emailVerificationRequired) {
      if (registrationId == null || registrationId.isEmpty) {
        throw Exception('Identificativo di verifica non valido.');
      }

      if (email == null || email.isEmpty) {
        throw Exception('Email di verifica non valida.');
      }

      return ApiLoginResponse(
        authenticated: false,
        emailVerificationRequired: true,
        registrationId: registrationId,
        email: email,
        expiresIn: expiresIn < 0 ? 0 : expiresIn,
      );
    }

    throw Exception('Risposta di accesso non valida.');
  }
}

class ApiEmailVerificationCooldownException implements Exception {
  final int retryAfterSeconds;

  const ApiEmailVerificationCooldownException(this.retryAfterSeconds);

  @override
  String toString() =>
      'Potrai richiedere un nuovo codice tra $retryAfterSeconds secondi.';
}

class ApiEmailVerificationResendResponse {
  final String registrationId;

  final String email;

  final int expiresIn;

  final String message;

  const ApiEmailVerificationResendResponse({
    required this.registrationId,
    required this.email,
    required this.expiresIn,
    required this.message,
  });

  factory ApiEmailVerificationResendResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final String registrationId =
        json['registration_id']?.toString().trim() ?? '';

    final String email = json['email']?.toString().trim() ?? '';

    final int expiresIn = _parseApiInt(json['expires_in']) ?? 0;

    final String message = json['message']?.toString().trim() ?? '';

    if (registrationId.isEmpty) {
      throw Exception('Identificativo di registrazione non valido.');
    }

    if (email.isEmpty) {
      throw Exception('Email di verifica non valida.');
    }

    if (expiresIn <= 0) {
      throw Exception('Durata della verifica email non valida.');
    }

    return ApiEmailVerificationResendResponse(
      registrationId: registrationId,
      email: email,
      expiresIn: expiresIn,
      message: message,
    );
  }
}

int? _parseApiInt(dynamic value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '');
}

class ApiService {
  static const String _productionBaseUrl = 'https://dmi-student-lab.vercel.app';

  static const String _productionHost = 'dmi-student-lab.vercel.app';

  static const int maxMaterialFileSize = 250 * 1024 * 1024;

  final String baseUrl;

  ApiService({String? overrideBaseUrl})
    : baseUrl = _validateBaseUrl(overrideBaseUrl ?? _productionBaseUrl);

  static String _validateBaseUrl(String value) {
    final String normalized = value.trim().replaceFirst(RegExp(r'/+$'), '');

    final Uri? uri = Uri.tryParse(normalized);

    if (uri == null) {
      throw StateError('Backend URL non valido.');
    }

    if (!uri.hasScheme || !uri.hasAuthority) {
      throw StateError('Backend URL incompleto.');
    }

    if (uri.scheme.toLowerCase() != 'https') {
      throw StateError('Connessione backend rifiutata: HTTPS obbligatorio.');
    }

    if (uri.host.toLowerCase() != _productionHost) {
      throw StateError('Host backend non autorizzato.');
    }

    if (uri.userInfo.isNotEmpty) {
      throw StateError('Backend URL non sicuro.');
    }

    if (uri.query.isNotEmpty || uri.fragment.isNotEmpty) {
      throw StateError('Backend URL non valido.');
    }

    return normalized;
  }

  Uri _apiUri(String path, {Map<String, dynamic>? queryParameters}) {
    final Uri base = Uri.parse(baseUrl);

    String normalizedPath = path.trim();

    if (!normalizedPath.startsWith('/')) {
      normalizedPath = '/$normalizedPath';
    }

    final Map<String, String> query = {};

    if (queryParameters != null) {
      for (final MapEntry<String, dynamic> entry in queryParameters.entries) {
        final dynamic value = entry.value;

        if (value == null) {
          continue;
        }

        query[entry.key] = value.toString();
      }
    }

    final Uri uri = base.replace(
      path: normalizedPath,
      queryParameters: query.isEmpty ? null : query,
    );

    if (uri.scheme != 'https' || uri.host != _productionHost) {
      throw StateError('Endpoint backend non autorizzato.');
    }

    return uri;
  }

  Future<List<String>> getArguments(
    String department,
    String course,
    String sub,
  ) async {
    final Uri url = Uri.parse('$baseUrl/arguments');

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({
        'department': department,
        'course': course,
        'sub': sub,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! List) {
        throw Exception('Risposta non valida dal server.');
      }

      return decoded.map<String>((dynamic item) => item.toString()).toList();
    }

    throw Exception(
      'Errore caricamento argomenti: '
      '${response.statusCode} - '
      '${response.body}',
    );
  }

  Future<int> getQuestionCount(
    String department,
    String course,
    String sub,
    List<String> arguments,
  ) async {
    final Uri url = Uri.parse('$baseUrl/question_count');

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({
        'department': department,
        'course': course,
        'sub': sub,
        'arguments': arguments,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final dynamic decoded = jsonDecode(response.body);

      if (decoded is int) {
        return decoded;
      }

      if (decoded is Map && decoded['count'] is num) {
        return (decoded['count'] as num).toInt();
      }

      throw Exception('Risposta non valida per il conteggio.');
    }

    throw Exception(
      'Errore conteggio domande: '
      '${response.statusCode} - '
      '${response.body}',
    );
  }

  Future<List<QuizModel>> shuffleFilter(
    String department,
    String course,
    String sub,
    List<String> selectedArguments,
    int numberOfQuestions,
  ) async {
    final Uri url = Uri.parse('$baseUrl/shuffleFilter');

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({
        'department': department,
        'course': course,
        'sub': sub,
        'arguments': selectedArguments,
        'number_of_questions': numberOfQuestions,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! List) {
        throw Exception('Risposta quiz non valida.');
      }

      return decoded
          .whereType<Map>()
          .map<QuizModel>(
            (Map<dynamic, dynamic> item) =>
                QuizModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    }

    throw Exception(
      'Impossibile caricare le domande: '
      '${response.statusCode} - '
      '${response.body}',
    );
  }

  Future<bool> validateQuest(
    String idQuestion,
    String idChoice,
    String department,
    String sub,
  ) async {
    final Uri url = Uri.parse('$baseUrl/validate_answer');

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({
        'idQuestion': idQuestion,
        'idChoice': idChoice,
        'department': department,
        'sub': sub,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) == true;
    }

    throw Exception(
      'Errore validate: '
      '${response.statusCode} - '
      '${response.body}',
    );
  }

  Future<List<String>> getSubjects(String department, String course) async {
    final Uri url = Uri.parse('$baseUrl/subjects');

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({'department': department, 'course': course}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! List) {
        throw Exception('Risposta materie non valida.');
      }

      return decoded.map<String>((dynamic item) => item.toString()).toList();
    }

    throw Exception(
      'Errore caricamento materie: '
      '${response.statusCode} - '
      '${response.body}',
    );
  }

  Future<List<AcademicUniversity>> getUniversities() async {
    final Uri url = Uri.parse('$baseUrl/universities');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    final List<Map<String, dynamic>> data = _decodeListResponse(
      response,
      'Errore caricamento atenei',
    );

    return data
        .map(AcademicUniversity.fromJson)
        .where(
          (AcademicUniversity university) =>
              university.code.isNotEmpty && university.name.isNotEmpty,
        )
        .toList();
  }

  Future<List<AcademicDepartment>> getDepartments(String universityCode) async {
    final String encodedUniversityCode = Uri.encodeComponent(universityCode);

    final Uri url = Uri.parse(
      '$baseUrl/universities/'
      '$encodedUniversityCode/'
      'departments',
    );

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    final List<Map<String, dynamic>> data = _decodeListResponse(
      response,
      'Errore caricamento dipartimenti',
    );

    return data
        .map(AcademicDepartment.fromJson)
        .where(
          (AcademicDepartment department) =>
              department.code.isNotEmpty && department.name.isNotEmpty,
        )
        .toList();
  }

  Future<List<AcademicCourse>> getCourses({
    required String universityCode,
    required String departmentCode,
  }) async {
    final String encodedUniversityCode = Uri.encodeComponent(universityCode);

    final String encodedDepartmentCode = Uri.encodeComponent(departmentCode);

    final Uri url = Uri.parse(
      '$baseUrl/universities/'
      '$encodedUniversityCode/'
      'departments/'
      '$encodedDepartmentCode/'
      'courses',
    );

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    final List<Map<String, dynamic>> data = _decodeListResponse(
      response,
      'Errore caricamento corsi',
    );

    return data
        .map(AcademicCourse.fromJson)
        .where(
          (AcademicCourse course) =>
              course.code.isNotEmpty && course.name.isNotEmpty,
        )
        .toList();
  }

  Future<List<SocialSubject>> getCatalogSubjects({
    required String universityCode,
    required String departmentCode,
    required String courseCode,
    int? studyYear,
  }) async {
    final String encodedUniversityCode = Uri.encodeComponent(universityCode);

    final String encodedDepartmentCode = Uri.encodeComponent(departmentCode);

    final String encodedCourseCode = Uri.encodeComponent(courseCode);

    Uri url = Uri.parse(
      '$baseUrl/universities/'
      '$encodedUniversityCode/'
      'departments/'
      '$encodedDepartmentCode/'
      'courses/'
      '$encodedCourseCode/'
      'subjects',
    );

    if (studyYear != null) {
      url = url.replace(queryParameters: {'study_year': studyYear.toString()});
    }

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    final List<Map<String, dynamic>> data = _decodeListResponse(
      response,
      'Errore caricamento catalogo materie',
    );

    return data.map(SocialSubject.fromJson).toList();
  }

  Future<List<SocialUser>> getSocialUsers() async {
    final Uri url = Uri.parse('$baseUrl/users');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    final List<Map<String, dynamic>> data = _decodeListResponse(
      response,
      'Errore caricamento utenti',
    );

    return data.map(SocialUser.fromJson).toList();
  }

  Future<SocialUser> getSocialUser(int userId) async {
    final Uri url = Uri.parse('$baseUrl/user/$userId');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore caricamento utente',
    );

    return SocialUser.fromJson(data);
  }

  Future<SocialUser> updateSocialUser({
    required int userId,
    String? firstName,
    String? lastName,
    String? university,
    String? department,
    String? course,
    String? description,
    bool? available,
    bool? availableForHelp,
    bool? availableForPrivateLessons,
  }) async {
    final Map<String, dynamic> body = {};

    if (firstName != null) {
      body['first_name'] = firstName;
    }

    if (lastName != null) {
      body['last_name'] = lastName;
    }

    if (university != null) {
      body['university'] = university;
    }

    if (department != null) {
      body['department'] = department;
    }

    if (course != null) {
      body['course'] = course;
    }

    if (description != null) {
      body['description'] = description;
    }

    if (available != null) {
      body['available'] = available;
    }

    if (availableForHelp != null) {
      body['available_for_help'] = availableForHelp;
    }

    if (availableForPrivateLessons != null) {
      body['available_for_private_lessons'] = availableForPrivateLessons;
    }

    final Uri url = Uri.parse('$baseUrl/update_user/$userId');

    final http.Response response = await http.patch(
      url,
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore aggiornamento utente',
    );

    return SocialUser.fromJson(data);
  }

  Future<List<SocialAcademicPath>> getUserAcademicPaths(int userId) async {
    final Uri url = Uri.parse('$baseUrl/user/$userId/academic_paths');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    final List<Map<String, dynamic>> data = _decodeListResponse(
      response,
      'Errore caricamento percorsi accademici',
    );

    return data.map(SocialAcademicPath.fromJson).toList();
  }

  Future<SocialAcademicPath> createAcademicPath({
    required String university,
    required String universityCode,
    required String department,
    required String departmentCode,
    required String course,
    required String courseCode,
    String degreeType = '',
    AcademicPathStatus status = AcademicPathStatus.enrolled,
    int? startYear,
    int? graduationYear,
    bool isCurrent = false,
    bool isPrimary = false,
  }) async {
    final Uri url = Uri.parse('$baseUrl/me/academic_paths');

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({
        'university': university,
        'university_code': universityCode,
        'department': department,
        'department_code': departmentCode,
        'course': course,
        'course_code': courseCode,
        'degree_type': degreeType.isEmpty ? null : degreeType,
        'status': _academicPathStatusValue(status),
        'start_year': startYear,
        'graduation_year': graduationYear,
        'is_current': isCurrent,
        'is_primary': isPrimary,
      }),
    );

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore creazione percorso accademico',
    );

    return SocialAcademicPath.fromJson(data);
  }

  Future<SocialAcademicPath> updateAcademicPath({
    required int academicPathId,
    String? university,
    String? universityCode,
    String? department,
    String? departmentCode,
    String? course,
    String? courseCode,
    String? degreeType,
    AcademicPathStatus? status,
    int? startYear,
    bool clearStartYear = false,
    int? graduationYear,
    bool clearGraduationYear = false,
    bool? isCurrent,
    bool? isPrimary,
  }) async {
    final Map<String, dynamic> body = {};

    if (university != null) {
      body['university'] = university;
    }

    if (universityCode != null) {
      body['university_code'] = universityCode;
    }

    if (department != null) {
      body['department'] = department;
    }

    if (departmentCode != null) {
      body['department_code'] = departmentCode;
    }

    if (course != null) {
      body['course'] = course;
    }

    if (courseCode != null) {
      body['course_code'] = courseCode;
    }

    if (degreeType != null) {
      body['degree_type'] = degreeType;
    }

    if (status != null) {
      body['status'] = _academicPathStatusValue(status);
    }

    if (clearStartYear) {
      body['start_year'] = null;
    } else if (startYear != null) {
      body['start_year'] = startYear;
    }

    if (clearGraduationYear) {
      body['graduation_year'] = null;
    } else if (graduationYear != null) {
      body['graduation_year'] = graduationYear;
    }

    if (isCurrent != null) {
      body['is_current'] = isCurrent;
    }

    if (isPrimary != null) {
      body['is_primary'] = isPrimary;
    }

    final Uri url = Uri.parse(
      '$baseUrl/me/academic_paths/'
      '$academicPathId',
    );

    final http.Response response = await http.patch(
      url,
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore modifica percorso accademico',
    );

    return SocialAcademicPath.fromJson(data);
  }

  Future<SocialAcademicPath> setCurrentAcademicPath(int academicPathId) async {
    final Uri url = Uri.parse(
      '$baseUrl/me/academic_paths/'
      '$academicPathId/'
      'set_current',
    );

    final http.Response response = await http.post(url, headers: _jsonHeaders);

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore impostazione percorso corrente',
    );

    return SocialAcademicPath.fromJson(data);
  }

  Future<SocialAcademicPath> setPrimaryAcademicPath(int academicPathId) async {
    final Uri url = Uri.parse(
      '$baseUrl/me/academic_paths/'
      '$academicPathId/'
      'set_primary',
    );

    final http.Response response = await http.post(url, headers: _jsonHeaders);

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore impostazione percorso principale',
    );

    return SocialAcademicPath.fromJson(data);
  }

  Future<void> removeAcademicPath(int academicPathId) async {
    final Uri url = Uri.parse(
      '$baseUrl/me/academic_paths/'
      '$academicPathId',
    );

    final http.Response response = await http.delete(
      url,
      headers: _jsonHeaders,
    );

    _checkSuccess(response, 'Errore rimozione percorso accademico');
  }

  Future<List<SocialSubject>> getSocialSubjects(
    String department,
    String course,
  ) async {
    final String encodedDepartment = Uri.encodeComponent(department);

    final String encodedCourse = Uri.encodeComponent(course);

    final Uri url = Uri.parse(
      '$baseUrl/social_subjects/'
      '$encodedDepartment/'
      '$encodedCourse',
    );

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    final List<Map<String, dynamic>> data = _decodeListResponse(
      response,
      'Errore caricamento materie Social',
    );

    return data.map(SocialSubject.fromJson).toList();
  }

  Future<SocialUser> addUserSubject({
    required int userId,
    required int subjectId,
    int? grade,
    String? note,
    bool canHelp = false,
    bool canGivePrivateLessons = false,
  }) async {
    final Uri url = Uri.parse(
      '$baseUrl/add_user_subject/'
      '$userId',
    );

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({
        'subject_id': subjectId,
        'grade': grade,
        'note': note,
        'can_help': canHelp,
        'can_give_private_lessons': canGivePrivateLessons,
      }),
    );

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore aggiunta materia',
    );

    return SocialUser.fromJson(data);
  }

  Future<void> removeUserSubject({
    required int userId,
    required int subjectId,
  }) async {
    final Uri url = Uri.parse(
      '$baseUrl/remove_user_subject/'
      '$userId/'
      '$subjectId',
    );

    final http.Response response = await http.delete(
      url,
      headers: _jsonHeaders,
    );

    _checkSuccess(response, 'Errore rimozione materia');
  }

  Future<Map<String, dynamic>> getUserReviewsData(int userId) async {
    final Uri url = Uri.parse('$baseUrl/users/$userId/reviews');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeMapResponse(response, 'Errore caricamento recensioni');
  }

  Future<List<SocialReview>> getUserReviews(int userId) async {
    final Map<String, dynamic> data = await getUserReviewsData(userId);

    final dynamic reviewsData = data['reviews'];

    if (reviewsData is! List) {
      return [];
    }

    return reviewsData
        .whereType<Map>()
        .map(
          (Map<dynamic, dynamic> item) =>
              SocialReview.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<double> getUserAverageRating(int userId) async {
    final Map<String, dynamic> data = await getUserReviewsData(userId);

    final dynamic summary = data['summary'];

    if (summary is! Map) {
      return 0;
    }

    final dynamic value = summary['average_rating'];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<int> getUserReviewCount(int userId) async {
    final Map<String, dynamic> data = await getUserReviewsData(userId);

    final dynamic summary = data['summary'];

    if (summary is! Map) {
      return 0;
    }

    return _toInt(summary['review_count']) ?? 0;
  }

  Future<SocialReview?> getMyReviewForUser(int userId) async {
    final Uri url = Uri.parse('$baseUrl/users/$userId/reviews/me');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final String body = response.body.trim();

      if (body.isEmpty || body == 'null') {
        return null;
      }

      final dynamic decoded = jsonDecode(body);

      if (decoded is Map) {
        return SocialReview.fromJson(Map<String, dynamic>.from(decoded));
      }

      throw Exception('Risposta recensione non valida.');
    }

    throw Exception(
      'Errore caricamento recensione: '
      '${response.statusCode} - '
      '${response.body}',
    );
  }

  Future<SocialReview> createReview({
    required int userId,
    required int rating,
    required String comment,
    int? subjectId,
  }) async {
    if (rating < 1 || rating > 5) {
      throw Exception('La valutazione deve essere compresa tra 1 e 5 stelle.');
    }

    final Uri url = Uri.parse('$baseUrl/users/$userId/reviews');

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({
        'rating': rating,
        'comment': comment.trim(),
        'subject_id': subjectId,
      }),
    );

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore creazione recensione',
    );

    return SocialReview.fromJson(data);
  }

  Future<SocialReview> updateMyReview({
    required int userId,
    int? rating,
    String? comment,
    int? subjectId,
    bool clearSubject = false,
  }) async {
    if (rating != null && (rating < 1 || rating > 5)) {
      throw Exception('La valutazione deve essere compresa tra 1 e 5 stelle.');
    }

    final Map<String, dynamic> body = {};

    if (rating != null) {
      body['rating'] = rating;
    }

    if (comment != null) {
      body['comment'] = comment.trim();
    }

    if (subjectId != null) {
      body['subject_id'] = subjectId;
    }

    if (clearSubject) {
      body['clear_subject'] = true;
    }

    final Uri url = Uri.parse('$baseUrl/users/$userId/reviews/me');

    final http.Response response = await http.put(
      url,
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore modifica recensione',
    );

    return SocialReview.fromJson(data);
  }

  Future<void> deleteMyReview(int userId) async {
    final Uri url = Uri.parse('$baseUrl/users/$userId/reviews/me');

    final http.Response response = await http.delete(
      url,
      headers: _jsonHeaders,
    );

    _checkSuccess(response, 'Errore eliminazione recensione');
  }

  Future<List<SocialReview>> getAdminReviews({
    ReviewModerationStatus? moderationStatus,
  }) async {
    Uri url = Uri.parse('$baseUrl/admin/reviews');

    if (moderationStatus != null) {
      url = url.replace(
        queryParameters: {
          'moderation_status': _reviewModerationStatusValue(moderationStatus),
        },
      );
    }

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore caricamento recensioni amministrazione',
    );

    return _reviewsFromMap(data);
  }

  Future<List<SocialReview>> getPendingReviews() async {
    final Uri url = Uri.parse('$baseUrl/admin/reviews/pending');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore caricamento recensioni da moderare',
    );

    return _reviewsFromMap(data);
  }

  Future<SocialReview> moderateReview({
    required int reviewId,
    required ReviewModerationStatus status,
  }) async {
    if (status == ReviewModerationStatus.pending) {
      throw Exception('Lo stato pending non può essere impostato manualmente.');
    }

    final Uri url = Uri.parse(
      '$baseUrl/admin/reviews/'
      '$reviewId/'
      'moderation',
    );

    final http.Response response = await http.patch(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({'status': _reviewModerationStatusValue(status)}),
    );

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore moderazione recensione',
    );

    return SocialReview.fromJson(data);
  }

  Future<SocialReview> approveReview(int reviewId) async {
    return moderateReview(
      reviewId: reviewId,
      status: ReviewModerationStatus.approved,
    );
  }

  Future<SocialReview> rejectReview(int reviewId) async {
    return moderateReview(
      reviewId: reviewId,
      status: ReviewModerationStatus.rejected,
    );
  }

  Future<SocialReview> hideReview(int reviewId) async {
    return moderateReview(
      reviewId: reviewId,
      status: ReviewModerationStatus.hidden,
    );
  }

  Future<SocialReview> restoreReview(int reviewId) async {
    final Uri url = Uri.parse(
      '$baseUrl/admin/reviews/'
      '$reviewId/'
      'restore',
    );

    final http.Response response = await http.post(url, headers: _jsonHeaders);

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore ripristino recensione',
    );

    return SocialReview.fromJson(data);
  }

  Future<Map<String, dynamic>> createGroup({
    required String name,
    required String description,
    required int? subjectId,
    required String university,
    required String department,
    required String course,
    required bool isPrivate,
  }) async {
    final Uri url = _apiUri('/create_group');

    final Map<String, dynamic> body = {
      'name': name,
      'description': description,
      'subject_id': subjectId,
      'university': university,
      'department': department,
      'course': course,
      'is_private': isPrivate,
    };

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );

    return _decodeMapResponse(response, 'Errore creazione gruppo');
  }

  Future<List<Map<String, dynamic>>> getGroups() async {
    final Uri url = _apiUri('/groups');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeListResponse(response, 'Errore caricamento gruppi');
  }

  Future<Map<String, dynamic>> getGroup(int groupId) async {
    final Uri url = Uri.parse('$baseUrl/group/$groupId');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeMapResponse(response, 'Errore caricamento gruppo');
  }

  Future<List<Map<String, dynamic>>> getUserGroups(int userId) async {
    final Uri url = Uri.parse('$baseUrl/user_groups/$userId');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeListResponse(response, 'Errore caricamento gruppi utente');
  }

  Future<Map<String, dynamic>> addGroupMember({
    required int groupId,
    required int userId,
    String role = 'member',
  }) async {
    final Uri url = Uri.parse(
      '$baseUrl/add_group_member/'
      '$groupId',
    );

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({'user_id': userId, 'role': role}),
    );

    return _decodeMapResponse(response, 'Errore aggiunta membro');
  }

  Future<void> removeGroupMember({
    required int groupId,
    required int userId,
  }) async {
    final Uri url = Uri.parse(
      '$baseUrl/remove_group_member/'
      '$groupId/'
      '$userId',
    );

    final http.Response response = await http.delete(
      url,
      headers: _jsonHeaders,
    );

    _checkSuccess(response, 'Errore rimozione membro');
  }

  Future<Map<String, dynamic>> updateGroupMemberRole({
    required int groupId,
    required int userId,
    required String role,
  }) async {
    final Uri url = Uri.parse(
      '$baseUrl/update_group_member_role/'
      '$groupId/'
      '$userId',
    );

    final http.Response response = await http.patch(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({'role': role}),
    );

    return _decodeMapResponse(response, 'Errore modifica ruolo membro');
  }

  Future<Map<String, dynamic>> updateGroup({
    required int groupId,
    String? name,
    String? description,
    int? subjectId,
    String? university,
    String? department,
    String? course,
    bool? isPrivate,
  }) async {
    final Map<String, dynamic> body = {};

    if (name != null) {
      body['name'] = name;
    }

    if (description != null) {
      body['description'] = description;
    }

    if (subjectId != null) {
      body['subject_id'] = subjectId;
    }

    if (university != null) {
      body['university'] = university;
    }

    if (department != null) {
      body['department'] = department;
    }

    if (course != null) {
      body['course'] = course;
    }

    if (isPrivate != null) {
      body['is_private'] = isPrivate;
    }

    final Uri url = Uri.parse(
      '$baseUrl/update_group/'
      '$groupId',
    );

    final http.Response response = await http.patch(
      url,
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );

    return _decodeMapResponse(response, 'Errore aggiornamento gruppo');
  }

  Future<void> deleteGroup(int groupId) async {
    final Uri url = Uri.parse('$baseUrl/delete_group/$groupId');

    final http.Response response = await http.delete(
      url,
      headers: _jsonHeaders,
    );

    _checkSuccess(response, 'Errore eliminazione gruppo');
  }

  Future<Map<String, dynamic>> requestJoinGroup({required int groupId}) async {
    final Uri url = Uri.parse(
      '$baseUrl/request_join_group/'
      '$groupId',
    );

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({}),
    );

    return _decodeMapResponse(response, 'Errore partecipazione gruppo');
  }

  Future<List<Map<String, dynamic>>> getGroupRequests(int groupId) async {
    final Uri url = Uri.parse(
      '$baseUrl/group_requests/'
      '$groupId',
    );

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeListResponse(response, 'Errore caricamento richieste gruppo');
  }

  Future<Map<String, dynamic>> acceptGroupRequest(int requestId) async {
    final Uri url = Uri.parse(
      '$baseUrl/accept_group_request/'
      '$requestId',
    );

    final http.Response response = await http.post(url, headers: _jsonHeaders);

    return _decodeMapResponse(response, 'Errore accettazione richiesta');
  }

  Future<Map<String, dynamic>> rejectGroupRequest(int requestId) async {
    final Uri url = Uri.parse(
      '$baseUrl/reject_group_request/'
      '$requestId',
    );

    final http.Response response = await http.post(url, headers: _jsonHeaders);

    return _decodeMapResponse(response, 'Errore rifiuto richiesta');
  }

  Future<Map<String, dynamic>> createGroupNewsReport({
    required int newsId,
    required String reason,
    String description = '',
  }) async {
    if (newsId <= 0) {
      throw ArgumentError('Identificativo comunicazione non valido.');
    }

    final String normalizedReason = reason.trim().toLowerCase();
    final String normalizedDescription = description.trim();

    if (normalizedReason.isEmpty) {
      throw ArgumentError('Seleziona il motivo della segnalazione.');
    }

    final Uri url = _apiUri('/group-news-reports/news/$newsId');

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({
        'reason': normalizedReason,
        'description': normalizedDescription,
      }),
    );

    return _decodeMapResponse(
      response,
      'Errore invio segnalazione comunicazione',
    );
  }

  Future<GroupNewsPrivateInboxResult> getPrivateGroupNews({
    int limit = 50,
    int offset = 0,
  }) async {
    final Uri url = _apiUri(
      '/group-news/private',
      queryParameters: {
        'limit': limit.clamp(1, 100),
        'offset': offset < 0 ? 0 : offset,
      },
    );

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore caricamento comunicazioni private',
    );

    return GroupNewsPrivateInboxResult.fromJson(data);
  }

  Future<GroupNewsFeedResult> getGroupNews({
    required int groupId,
    int limit = 50,
    int offset = 0,
  }) async {
    if (groupId <= 0) {
      throw ArgumentError('Identificativo gruppo non valido.');
    }

    final Uri url = _apiUri(
      '/group-news/groups/$groupId',
      queryParameters: {
        'limit': limit.clamp(1, 100),
        'offset': offset < 0 ? 0 : offset,
      },
    );

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore caricamento news del gruppo',
    );

    return GroupNewsFeedResult.fromJson(data);
  }

  Future<GroupNews> createGroupNews({
    required int groupId,
    required String content,
    String visibility = 'group',
    int? recipientUserId,
    int? parentNewsId,
  }) async {
    if (groupId <= 0) {
      throw ArgumentError('Identificativo gruppo non valido.');
    }

    final String normalizedContent = content.trim();

    if (normalizedContent.isEmpty) {
      throw ArgumentError('Inserisci il contenuto della comunicazione.');
    }

    final String normalizedVisibility = visibility.trim().toLowerCase();

    if (normalizedVisibility != 'group' && normalizedVisibility != 'private') {
      throw ArgumentError('Visibilità della comunicazione non valida.');
    }

    if (normalizedVisibility == 'private' &&
        (recipientUserId == null || recipientUserId <= 0)) {
      throw ArgumentError('Seleziona un destinatario valido.');
    }

    final Uri url = _apiUri('/group-news/groups/$groupId');

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({
        'visibility': normalizedVisibility,
        'recipient_user_id': recipientUserId,
        'parent_news_id': parentNewsId,
        'content': normalizedContent,
      }),
    );

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore pubblicazione comunicazione',
    );

    final Map<String, dynamic> normalized = {
      ...data,
      'is_private': data['visibility'] == 'private',
      'can_reply': true,
      'can_delete': true,
      'can_moderate': false,
      'can_report': false,
      'can_block_author': false,
      'group_name': data['group_name'] ?? '',
      'subject_name': data['subject_name'] ?? '',
    };

    return GroupNews.fromJson(normalized);
  }

  Future<void> deleteGroupNews(int newsId) async {
    if (newsId <= 0) {
      throw ArgumentError('Identificativo comunicazione non valido.');
    }

    final Uri url = _apiUri('/group-news/$newsId');

    final http.Response response = await http.delete(
      url,
      headers: _jsonHeaders,
    );

    _checkSuccess(response, 'Errore eliminazione comunicazione');
  }

  Future<GroupNews> moderateGroupNews({
    required int newsId,
    required String reason,
    bool platformModeration = false,
  }) async {
    if (newsId <= 0) {
      throw ArgumentError('Identificativo comunicazione non valido.');
    }

    final String normalizedReason = reason.trim();

    if (normalizedReason.isEmpty) {
      throw ArgumentError('Inserisci il motivo della moderazione.');
    }

    final Uri url = _apiUri(
      platformModeration
          ? '/group-news/$newsId/platform-moderate'
          : '/group-news/$newsId/moderate',
    );

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({'action': 'remove_news', 'reason': normalizedReason}),
    );

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore moderazione comunicazione',
    );

    final Map<String, dynamic> normalized = {
      ...data,
      'is_private': data['visibility'] == 'private',
      'can_reply': false,
      'can_delete': false,
      'can_moderate': false,
      'can_report': false,
      'can_block_author': false,
      'group_name': data['group_name'] ?? '',
      'subject_name': data['subject_name'] ?? '',
    };

    return GroupNews.fromJson(normalized);
  }

  Future<Map<String, dynamic>> getMaterialSyncManifest({
    DateTime? since,
  }) async {
    final Uri url = _apiUri(
      '/materials/sync-manifest',
      queryParameters: {
        if (since != null) 'since': since.toUtc().toIso8601String(),
      },
    );

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeMapResponse(response, 'Errore sincronizzazione materiali');
  }

  Future<Uint8List> downloadMaterial({
    required String source,
    required int materialId,
  }) async {
    if (materialId <= 0) {
      throw ArgumentError('Identificativo materiale non valido.');
    }

    final String normalizedSource = source.trim().toLowerCase();

    if (normalizedSource != 'public' &&
        normalizedSource != 'teacher' &&
        normalizedSource != 'group') {
      throw ArgumentError('Sorgente materiale non valida.');
    }

    final Uri url = _apiUri(
      '/materials/'
      '$normalizedSource/'
      '$materialId/'
      'download',
    );

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }

    if (response.statusCode == 401) {
      throw Exception('Sessione non valida. Accedi nuovamente.');
    }

    if (response.statusCode == 403 || response.statusCode == 404) {
      throw Exception('Il materiale non è più disponibile.');
    }

    throw Exception('Non è stato possibile scaricare il materiale.');
  }

  Future<List<Map<String, dynamic>>> getPublicMaterials() async {
    final Uri url = _apiUri('/public_materials');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeListResponse(
      response,
      'Errore caricamento materiali StudentLab',
    );
  }

  Future<List<Map<String, dynamic>>> getPublicMaterialsBySubject(
    int subjectId,
  ) async {
    final Uri url = _apiUri('/public_materials/subject/$subjectId');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeListResponse(
      response,
      'Errore caricamento materiali della materia',
    );
  }

  Future<List<Map<String, dynamic>>> getPublicMaterialsByCatalog({
    required String universityCode,
    required String departmentCode,
    required String courseCode,
    required int subjectId,
  }) async {
    final String encodedUniversityCode = Uri.encodeComponent(universityCode);

    final String encodedDepartmentCode = Uri.encodeComponent(departmentCode);

    final String encodedCourseCode = Uri.encodeComponent(courseCode);

    final Uri url = _apiUri(
      '/public_materials/catalog/'
      '$encodedUniversityCode/'
      '$encodedDepartmentCode/'
      '$encodedCourseCode/'
      '$subjectId',
    );

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeListResponse(
      response,
      'Errore caricamento materiali StudentLab',
    );
  }

  Future<Map<String, dynamic>> getPublicMaterial(int materialId) async {
    final Uri url = _apiUri('/public_materials/$materialId');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeMapResponse(
      response,
      'Errore caricamento materiale StudentLab',
    );
  }

  Future<Uint8List> downloadPublicMaterial(int materialId) {
    return downloadMaterial(source: 'public', materialId: materialId);
  }

  Future<Uint8List> viewPublicMaterial(int materialId) async {
    final Uri url = _apiUri('/public_materials/$materialId/view');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }

    throw Exception('Non è stato possibile aprire il materiale.');
  }

  Future<Map<String, dynamic>> addGroupMaterial({
    required int groupId,
    required String filePath,
    String? originalName,
    String? mimeType,
  }) async {
    _requireCurrentUserId();

    return StudentLabUploadService().uploadGroupMaterial(
      groupId: groupId,
      filePath: filePath,
      originalName: originalName,
      mimeType: mimeType,
    );
  }

  Future<Map<String, dynamic>> addGroupMaterialBytes({
    required int groupId,
    required Uint8List bytes,
    required String originalName,
    String? mimeType,
  }) async {
    _requireCurrentUserId();
    return StudentLabUploadService().uploadGroupMaterialBytes(
      groupId: groupId,
      bytes: bytes,
      originalName: originalName,
      mimeType: mimeType,
    );
  }

  Future<List<Map<String, dynamic>>> getGroupMaterials(int groupId) async {
    final Uri url = Uri.parse(
      '$baseUrl/group_materials/'
      '$groupId',
    );

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeListResponse(response, 'Errore caricamento materiali');
  }

  Future<Uint8List> downloadGroupMaterial(int materialId) {
    return downloadMaterial(source: 'group', materialId: materialId);
  }

  Future<void> removeGroupMaterial(int materialId) async {
    final Uri url = Uri.parse(
      '$baseUrl/remove_group_material/'
      '$materialId',
    );

    final http.Response response = await http.delete(
      url,
      headers: _jsonHeaders,
    );

    _checkSuccess(response, 'Errore eliminazione materiale');
  }

  Future<List<SocialUser>> getGroupParticipants(int groupId) async {
    final Map<String, dynamic> group = await getGroup(groupId);

    final dynamic membersData = group['members'];

    if (membersData is! List) {
      return [];
    }

    final List<SocialUser> result = [];

    for (final dynamic item in membersData) {
      if (item is! Map) {
        continue;
      }

      final Map<String, dynamic> member = Map<String, dynamic>.from(item);

      final int? userId = _toInt(member['user_id']);

      if (userId == null) {
        continue;
      }

      try {
        result.add(await getSocialUser(userId));
      } catch (_) {}
    }

    return result;
  }

  Future<ApiRegistrationResponse> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required DateTime dateOfBirth,
    required String policyVersion,
    required bool privacyAcknowledged,
    required bool termsAccepted,
    String university = '',
    String universityCode = '',
    String department = '',
    String departmentCode = '',
    String course = '',
    String courseCode = '',
    String degreeType = '',
    AcademicPathStatus academicStatus = AcademicPathStatus.enrolled,
    int? startYear,
    int? graduationYear,
    required String description,
    required String role,
    required bool available,
    required bool availableForHelp,
    required bool availableForPrivateLessons,
  }) async {
    final Uri url = Uri.parse('$baseUrl/register');

    final String dateOfBirthValue =
        '${dateOfBirth.year.toString().padLeft(4, '0')}-'
        '${dateOfBirth.month.toString().padLeft(2, '0')}-'
        '${dateOfBirth.day.toString().padLeft(2, '0')}';

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'password': password,
        'date_of_birth': dateOfBirthValue,
        'policy_version': policyVersion,
        'privacy_acknowledged': privacyAcknowledged,
        'terms_accepted': termsAccepted,
        'university': university.isEmpty ? null : university,
        'university_code': universityCode.isEmpty ? null : universityCode,
        'department': department.isEmpty ? null : department,
        'department_code': departmentCode.isEmpty ? null : departmentCode,
        'course': course.isEmpty ? null : course,
        'course_code': courseCode.isEmpty ? null : courseCode,
        'degree_type': degreeType.isEmpty ? null : degreeType,
        'academic_status': _academicPathStatusValue(academicStatus),
        'start_year': startYear,
        'graduation_year': graduationYear,
        'description': description,
        'role': role,
        'available': available,
        'available_for_help': availableForHelp,
        'available_for_private_lessons': availableForPrivateLessons,
        'willing_to_teach': availableForPrivateLessons,
      }),
    );

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore registrazione',
    );

    return ApiRegistrationResponse.fromJson(data);
  }

  Future<ApiRegistrationResponse> registerDraft(
    SocialProfileDraft draft, {
    required String policyVersion,
    required bool privacyAcknowledged,
    required bool termsAccepted,
  }) async {
    return register(
      firstName: draft.firstName,
      lastName: draft.lastName,
      email: draft.email,
      password: draft.password,
      dateOfBirth: draft.dateOfBirth,
      policyVersion: policyVersion,
      privacyAcknowledged: privacyAcknowledged,
      termsAccepted: termsAccepted,
      university: draft.university,
      universityCode: draft.universityCode,
      department: draft.department,
      departmentCode: draft.departmentCode,
      course: draft.course,
      courseCode: draft.courseCode,
      degreeType: draft.degreeType,
      academicStatus: draft.academicStatus,
      startYear: draft.startYear,
      graduationYear: draft.graduationYear,
      description: draft.description,
      role: draft.role,
      available: draft.available,
      availableForHelp: draft.availableForHelp,
      availableForPrivateLessons: draft.availableForPrivateLessons,
    );
  }

  Future<String> verifyEmail({
    required String registrationId,
    required String code,
  }) async {
    final Uri url = Uri.parse('$baseUrl/auth/email/verify');

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({'registration_id': registrationId, 'code': code}),
    );

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore verifica email',
    );

    final String? token = data['access_token']?.toString().trim();

    if (token == null || token.isEmpty) {
      throw Exception('Token di accesso non restituito dal server.');
    }

    return token;
  }

  Future<ApiEmailVerificationResendResponse> resendEmailVerification({
    required String registrationId,
  }) async {
    final Uri url = Uri.parse('$baseUrl/auth/email/resend');

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({'registration_id': registrationId}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final Map<String, dynamic> data = _decodeMapResponse(
        response,
        'Errore reinvio codice di verifica',
      );

      return ApiEmailVerificationResendResponse.fromJson(data);
    }

    final String detail = _extractApiErrorDetail(response);
    final RegExpMatch? cooldownMatch = RegExp(
      r'(?:attendi|tra)\s+(\d+)\s+second',
      caseSensitive: false,
    ).firstMatch(detail);

    if (cooldownMatch != null) {
      final int retryAfterSeconds =
          int.tryParse(cooldownMatch.group(1) ?? '') ?? 1;

      throw ApiEmailVerificationCooldownException(
        retryAfterSeconds < 1 ? 1 : retryAfterSeconds,
      );
    }

    if (response.statusCode == 503) {
      throw Exception(
        'Il servizio email non è temporaneamente disponibile. Riprova tra qualche momento.',
      );
    }

    throw Exception(
      detail.isEmpty
          ? 'Non è stato possibile reinviare il codice di verifica.'
          : detail,
    );
  }

  Future<ApiLoginResponse> login({
    required String email,
    required String password,
  }) async {
    final Uri url = Uri.parse('$baseUrl/login');

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({'email': email, 'password': password}),
    );

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore accesso',
    );

    return ApiLoginResponse.fromJson(data);
  }

  Future<SocialUser> getCurrentUser({String? token}) async {
    final String? accessToken = token ?? AuthSession.instance.accessToken;

    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Nessun token di autenticazione disponibile.');
    }

    final Uri url = Uri.parse('$baseUrl/me');

    final http.Response response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore caricamento utente corrente',
    );

    return SocialUser.fromJson(data);
  }

  Future<List<SocialUser>> getPendingTeachers() async {
    final Uri url = Uri.parse('$baseUrl/admin/teachers/pending');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    final List<Map<String, dynamic>> data = _decodeListResponse(
      response,
      'Errore caricamento docenti da verificare',
    );

    return data.map(SocialUser.fromJson).toList();
  }

  Future<SocialUser> updateTeacherVerification({
    required int userId,
    required bool verified,
  }) async {
    final Uri url = Uri.parse(
      '$baseUrl/admin/teachers/'
      '$userId/'
      'verification',
    );

    final http.Response response = await http.patch(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({'status': verified ? 'verified' : 'rejected'}),
    );

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore verifica docente',
    );

    return SocialUser.fromJson(data);
  }

  Future<List<Map<String, dynamic>>> getPendingGrades() async {
    final Uri url = Uri.parse('$baseUrl/admin/grades/pending');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeListResponse(
      response,
      'Errore caricamento voti da verificare',
    );
  }

  Future<Map<String, dynamic>> verifyGrade({
    required int userId,
    required int subjectId,
  }) async {
    final Uri url = Uri.parse(
      '$baseUrl/admin/users/'
      '$userId/'
      'subjects/'
      '$subjectId/'
      'verify_grade',
    );

    final http.Response response = await http.post(url, headers: _jsonHeaders);

    return _decodeMapResponse(response, 'Errore verifica voto');
  }

  Future<Map<String, dynamic>> rejectGrade({
    required int userId,
    required int subjectId,
  }) async {
    final Uri url = Uri.parse(
      '$baseUrl/admin/users/'
      '$userId/'
      'subjects/'
      '$subjectId/'
      'reject_grade',
    );

    final http.Response response = await http.post(url, headers: _jsonHeaders);

    return _decodeMapResponse(response, 'Errore rifiuto voto');
  }

  Future<List<SocialAcademicPath>> getPendingAcademicPaths() async {
    final Uri url = Uri.parse('$baseUrl/admin/academic_paths/pending');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    final List<Map<String, dynamic>> data = _decodeListResponse(
      response,
      'Errore caricamento lauree da verificare',
    );

    return data.map(SocialAcademicPath.fromJson).toList();
  }

  Future<SocialAcademicPath> updateAcademicPathVerification({
    required int academicPathId,
    required bool verified,
  }) async {
    final Uri url = Uri.parse(
      '$baseUrl/admin/academic_paths/'
      '$academicPathId/'
      'verification',
    );

    final http.Response response = await http.patch(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({'status': verified ? 'verified' : 'rejected'}),
    );

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore verifica percorso accademico',
    );

    return SocialAcademicPath.fromJson(data);
  }

  Future<SocialUser> setUserActiveStatus({
    required int userId,
    required bool isActive,
  }) async {
    final Uri url = Uri.parse(
      '$baseUrl/admin/users/'
      '$userId/'
      'active_status',
    );

    final http.Response response = await http.patch(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({'is_active': isActive}),
    );

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore modifica stato utente',
    );

    return SocialUser.fromJson(data);
  }

  Future<Map<String, dynamic>> getUserBlockStatus(int userId) async {
    if (userId <= 0) {
      throw ArgumentError('Identificativo utente non valido.');
    }

    final Uri url = _apiUri('/user-blocks/$userId/status');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeMapResponse(
      response,
      'Errore caricamento stato blocco utente',
    );
  }

  Future<Map<String, dynamic>> blockUser(int userId) async {
    if (userId <= 0) {
      throw ArgumentError('Identificativo utente non valido.');
    }

    final Uri url = _apiUri('/user-blocks');

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({'blocked_user_id': userId}),
    );

    return _decodeMapResponse(response, 'Errore blocco utente');
  }

  Future<Map<String, dynamic>> unblockUser(int userId) async {
    if (userId <= 0) {
      throw ArgumentError('Identificativo utente non valido.');
    }

    final Uri url = _apiUri('/user-blocks/$userId');

    final http.Response response = await http.delete(
      url,
      headers: _jsonHeaders,
    );

    return _decodeMapResponse(response, 'Errore sblocco utente');
  }

  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    final Uri url = _apiUri('/user-blocks');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore caricamento utenti bloccati',
    );

    final dynamic items = data['items'];

    if (items is! List) {
      return [];
    }

    return items
        .whereType<Map>()
        .map((Map<dynamic, dynamic> item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> createUserReport({
    required int reportedUserId,
    required String reason,
    String description = '',
  }) async {
    final Uri url = _apiUri('/user-reports');

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({
        'reported_user_id': reportedUserId,
        'reason': reason.trim(),
        'description': description.trim(),
      }),
    );

    return _decodeMapResponse(response, 'Errore invio segnalazione utente');
  }

  Future<List<Map<String, dynamic>>> getMyUserReports() async {
    final Uri url = _apiUri('/me/user-reports');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeListResponse(
      response,
      'Errore caricamento segnalazioni utenti',
    );
  }

  Future<Map<String, dynamic>> getUserReport(int reportId) async {
    final Uri url = _apiUri('/user-reports/$reportId');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeMapResponse(
      response,
      'Errore caricamento segnalazione utente',
    );
  }

  Future<Map<String, dynamic>> deactivateUserReport(int reportId) async {
    final Uri url = _apiUri('/user-reports/$reportId');

    final http.Response response = await http.delete(
      url,
      headers: _jsonHeaders,
    );

    return _decodeMapResponse(
      response,
      'Errore annullamento segnalazione utente',
    );
  }

  Future<Map<String, dynamic>> createProfileErrorReport({
    required String category,
    required String description,
  }) async {
    final Uri url = _apiUri('/me/profile-error-reports');

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({
        'category': category.trim(),
        'description': description.trim(),
      }),
    );

    return _decodeMapResponse(response, 'Errore invio segnalazione profilo');
  }

  Future<List<Map<String, dynamic>>> getMyProfileErrorReports() async {
    final Uri url = _apiUri('/me/profile-error-reports');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeListResponse(
      response,
      'Errore caricamento segnalazioni profilo',
    );
  }

  Future<Map<String, dynamic>> getProfileErrorReport(int reportId) async {
    final Uri url = _apiUri('/profile-error-reports/$reportId');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeMapResponse(
      response,
      'Errore caricamento segnalazione profilo',
    );
  }

  Future<Map<String, dynamic>> createGroupReport({
    required int groupId,
    required String reason,
    String description = '',
  }) async {
    final Uri url = _apiUri('/group-reports');

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({
        'group_id': groupId,
        'reason': reason.trim(),
        'description': description.trim(),
      }),
    );

    return _decodeMapResponse(response, 'Errore invio segnalazione gruppo');
  }

  Future<List<Map<String, dynamic>>> getMyGroupReports() async {
    final Uri url = _apiUri('/me/group-reports');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeListResponse(
      response,
      'Errore caricamento segnalazioni gruppi',
    );
  }

  Future<Map<String, dynamic>> getGroupReport(int reportId) async {
    final Uri url = _apiUri('/group-reports/$reportId');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeMapResponse(
      response,
      'Errore caricamento segnalazione gruppo',
    );
  }

  Future<Map<String, dynamic>> createGroupContentReport({
    required int groupId,
    required String contentType,
    required int contentId,
    int? authorUserId,
    required String reason,
    String description = '',
  }) async {
    final Uri url = _apiUri('/group-content-reports');

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({
        'group_id': groupId,
        'content_type': contentType.trim(),
        'content_id': contentId,
        'author_user_id': authorUserId,
        'reason': reason.trim(),
        'description': description.trim(),
      }),
    );

    return _decodeMapResponse(response, 'Errore invio segnalazione contenuto');
  }

  Future<List<Map<String, dynamic>>> getMyGroupContentReports() async {
    final Uri url = _apiUri('/me/group-content-reports');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeListResponse(
      response,
      'Errore caricamento segnalazioni contenuti',
    );
  }

  Future<Map<String, dynamic>> getGroupContentReport(int reportId) async {
    final Uri url = _apiUri('/group-content-reports/$reportId');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeMapResponse(
      response,
      'Errore caricamento segnalazione contenuto',
    );
  }

  Future<Map<String, dynamic>> createAccountDeletionRequest({
    String reason = 'user_request',
    String note = '',
  }) async {
    final Uri url = _apiUri('/me/account-deletion');

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({'reason': reason.trim(), 'note': note.trim()}),
    );

    return _decodeMapResponse(
      response,
      'Errore richiesta eliminazione account',
    );
  }

  Future<Map<String, dynamic>> getMyAccountDeletionRequest() async {
    final Uri url = _apiUri('/me/account-deletion');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeMapResponse(
      response,
      'Errore caricamento richiesta eliminazione account',
    );
  }

  Future<Map<String, dynamic>> getMyAccountDeletionDetail() async {
    final Uri url = _apiUri('/me/account-deletion/detail');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeMapResponse(
      response,
      'Errore caricamento dettagli eliminazione account',
    );
  }

  Future<Map<String, dynamic>> cancelAccountDeletionRequest() async {
    final Uri url = _apiUri('/me/account-deletion/cancel');

    final http.Response response = await http.post(url, headers: _jsonHeaders);

    return _decodeMapResponse(
      response,
      'Errore annullamento eliminazione account',
    );
  }

  Future<Map<String, dynamic>> completeAccountDeletion() async {
    final Uri url = _apiUri('/me/account-deletion/complete');

    final http.Response response = await http.post(url, headers: _jsonHeaders);

    return _decodeMapResponse(
      response,
      'Errore completamento eliminazione account',
    );
  }

  Future<Map<String, dynamic>> createGroupOwnershipTransfer({
    required int groupId,
    required int proposedOwnerId,
    int? accountDeletionRequestId,
  }) async {
    final Uri url = _apiUri(
      '/groups/$groupId/ownership-transfer',
      queryParameters: {
        'account_deletion_request_id': accountDeletionRequestId,
      },
    );

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({'proposed_owner_id': proposedOwnerId}),
    );

    return _decodeMapResponse(
      response,
      'Errore richiesta trasferimento proprietà gruppo',
    );
  }

  Future<List<Map<String, dynamic>>>
  getIncomingGroupOwnershipTransfers() async {
    final Uri url = _apiUri('/group-ownership-transfers/incoming');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeListResponse(
      response,
      'Errore caricamento trasferimenti ricevuti',
    );
  }

  Future<List<Map<String, dynamic>>>
  getOutgoingGroupOwnershipTransfers() async {
    final Uri url = _apiUri('/group-ownership-transfers/outgoing');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeListResponse(
      response,
      'Errore caricamento trasferimenti inviati',
    );
  }

  Future<Map<String, dynamic>> getGroupOwnershipTransfer(int transferId) async {
    final Uri url = _apiUri('/group-ownership-transfers/$transferId');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeMapResponse(
      response,
      'Errore caricamento trasferimento proprietà gruppo',
    );
  }

  Future<Map<String, dynamic>> respondGroupOwnershipTransfer({
    required int transferId,
    required String action,
  }) async {
    final String normalizedAction = action.trim().toLowerCase();

    if (normalizedAction != 'accept' && normalizedAction != 'reject') {
      throw Exception('Azione trasferimento non valida.');
    }

    final Uri url = _apiUri(
      '/group-ownership-transfers/'
      '$transferId/'
      'respond',
    );

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({'action': normalizedAction}),
    );

    return _decodeMapResponse(
      response,
      'Errore risposta trasferimento proprietà gruppo',
    );
  }

  Future<Map<String, dynamic>> cancelGroupOwnershipTransfer(
    int transferId,
  ) async {
    final Uri url = _apiUri(
      '/group-ownership-transfers/'
      '$transferId/'
      'cancel',
    );

    final http.Response response = await http.post(url, headers: _jsonHeaders);

    return _decodeMapResponse(
      response,
      'Errore annullamento trasferimento proprietà gruppo',
    );
  }

  Future<List<Map<String, dynamic>>> getAdminUserReports({
    String? status,
  }) async {
    final Uri url = _apiUri(
      '/admin/user-reports',
      queryParameters: {'report_status': status},
    );

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeListResponse(
      response,
      'Errore caricamento segnalazioni utenti',
    );
  }

  Future<List<Map<String, dynamic>>> getPendingUserReports() async {
    final Uri url = _apiUri('/admin/user-reports/pending');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeListResponse(
      response,
      'Errore caricamento segnalazioni utenti pendenti',
    );
  }

  Future<Map<String, dynamic>> moderateUserReport({
    required int reportId,
    required String status,
    String moderationNote = '',
  }) async {
    final Uri url = _apiUri(
      '/admin/user-reports/'
      '$reportId/'
      'moderation',
    );

    final http.Response response = await http.patch(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({
        'status': status.trim(),
        'moderation_note': moderationNote.trim(),
      }),
    );

    return _decodeMapResponse(
      response,
      'Errore moderazione segnalazione utente',
    );
  }

  Future<List<Map<String, dynamic>>> getAdminProfileErrorReports({
    String? status,
    String? category,
  }) async {
    final Uri url = _apiUri(
      '/admin/profile-error-reports',
      queryParameters: {'report_status': status, 'category': category},
    );

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeListResponse(
      response,
      'Errore caricamento segnalazioni profilo',
    );
  }

  Future<List<Map<String, dynamic>>> getPendingProfileErrorReports() async {
    final Uri url = _apiUri('/admin/profile-error-reports/pending');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeListResponse(
      response,
      'Errore caricamento segnalazioni profilo pendenti',
    );
  }

  Future<Map<String, dynamic>> moderateProfileErrorReport({
    required int reportId,
    required String status,
    String resolutionNote = '',
  }) async {
    final Uri url = _apiUri(
      '/admin/profile-error-reports/'
      '$reportId/'
      'moderation',
    );

    final http.Response response = await http.patch(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({
        'status': status.trim(),
        'resolution_note': resolutionNote.trim(),
      }),
    );

    return _decodeMapResponse(
      response,
      'Errore moderazione segnalazione profilo',
    );
  }

  Future<List<Map<String, dynamic>>> getAdminGroupReports({
    String? status,
    String? reason,
  }) async {
    final Uri url = _apiUri(
      '/admin/group-reports',
      queryParameters: {'report_status': status, 'reason': reason},
    );

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeListResponse(
      response,
      'Errore caricamento segnalazioni gruppi',
    );
  }

  Future<List<Map<String, dynamic>>> getPendingGroupReports() async {
    final Uri url = _apiUri('/admin/group-reports/pending');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeListResponse(
      response,
      'Errore caricamento segnalazioni gruppi pendenti',
    );
  }

  Future<Map<String, dynamic>> moderateGroupReport({
    required int reportId,
    required String status,
    String moderationNote = '',
  }) async {
    final Uri url = _apiUri(
      '/admin/group-reports/'
      '$reportId/'
      'moderation',
    );

    final http.Response response = await http.patch(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({
        'status': status.trim(),
        'moderation_note': moderationNote.trim(),
      }),
    );

    return _decodeMapResponse(
      response,
      'Errore moderazione segnalazione gruppo',
    );
  }

  Future<List<Map<String, dynamic>>> getAdminGroupContentReports({
    String? status,
    String? contentType,
    String? reason,
    int? groupId,
  }) async {
    final Uri url = _apiUri(
      '/admin/group-content-reports',
      queryParameters: {
        'report_status': status,
        'content_type': contentType,
        'reason': reason,
        'group_id': groupId,
      },
    );

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeListResponse(
      response,
      'Errore caricamento segnalazioni contenuti',
    );
  }

  Future<List<Map<String, dynamic>>> getPendingGroupContentReports() async {
    final Uri url = _apiUri('/admin/group-content-reports/pending');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeListResponse(
      response,
      'Errore caricamento segnalazioni contenuti pendenti',
    );
  }

  Future<Map<String, dynamic>> moderateGroupContentReport({
    required int reportId,
    required String status,
    String moderationAction = 'none',
    String moderationNote = '',
  }) async {
    final Uri url = _apiUri(
      '/admin/group-content-reports/'
      '$reportId/'
      'moderation',
    );

    final http.Response response = await http.patch(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({
        'status': status.trim(),
        'moderation_action': moderationAction.trim(),
        'moderation_note': moderationNote.trim(),
      }),
    );

    return _decodeMapResponse(
      response,
      'Errore moderazione segnalazione contenuto',
    );
  }

  Future<List<Map<String, dynamic>>> getPendingAccountDeletions() async {
    final Uri url = _apiUri('/admin/account-deletions');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeListResponse(
      response,
      'Errore caricamento richieste eliminazione account',
    );
  }

  Future<Map<String, dynamic>> getAdminAccountDeletionDetail(
    int requestId,
  ) async {
    final Uri url = _apiUri('/admin/account-deletions/$requestId');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeMapResponse(
      response,
      'Errore caricamento richiesta eliminazione account',
    );
  }



  String _fileNameFromPath(String filePath) {
    final String normalized = filePath.replaceAll('\\', '/');

    final List<String> parts = normalized.split('/');

    if (parts.isEmpty) {
      return 'file';
    }

    final String name = parts.last;

    if (name.isEmpty) {
      return 'file';
    }

    return name;
  }

  String _materialMimeType(String fileName) {
    final String lower = fileName.toLowerCase();

    if (lower.endsWith('.pdf')) {
      return 'application/pdf';
    }

    if (lower.endsWith('.txt')) {
      return 'text/plain';
    }

    if (lower.endsWith('.zip')) {
      return 'application/zip';
    }

    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }

    if (lower.endsWith('.pptx')) {
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    }

    throw Exception('Tipo di file non supportato.');
  }

  int _requireCurrentUserId() {
    final int? userId = AuthSession.instance.currentUserId;

    if (userId == null) {
      throw Exception('Utente non autenticato.');
    }

    return userId;
  }

  Map<String, String> get _jsonHeaders {
    final String? token = AuthSession.instance.accessToken;

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  String _extractApiErrorDetail(http.Response response) {
    final String body = response.body.trim();

    if (body.isEmpty) {
      return '';
    }

    try {
      final dynamic decoded = jsonDecode(body);

      if (decoded is Map) {
        final dynamic detail = decoded['detail'];

        if (detail is String) {
          return detail.trim();
        }

        if (detail != null) {
          return detail.toString().trim();
        }
      }
    } catch (_) {}

    return body;
  }

  Map<String, dynamic> _decodeMapResponse(
    http.Response response,
    String errorMessage,
  ) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.trim().isEmpty) {
        return {};
      }

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      throw Exception(
        '$errorMessage: '
        'risposta JSON non valida.',
      );
    }

    throw Exception(
      '$errorMessage: '
      '${response.statusCode} - '
      '${response.body}',
    );
  }

  List<Map<String, dynamic>> _decodeListResponse(
    http.Response response,
    String errorMessage,
  ) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.trim().isEmpty) {
        return [];
      }

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! List) {
        throw Exception(
          '$errorMessage: '
          'risposta JSON non valida.',
        );
      }

      return decoded
          .whereType<Map>()
          .map((Map<dynamic, dynamic> item) => Map<String, dynamic>.from(item))
          .toList();
    }

    throw Exception(
      '$errorMessage: '
      '${response.statusCode} - '
      '${response.body}',
    );
  }

  void _checkSuccess(http.Response response, String errorMessage) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw Exception(
      '$errorMessage: '
      '${response.statusCode} - '
      '${response.body}',
    );
  }

  int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  String _academicPathStatusValue(AcademicPathStatus status) {
    switch (status) {
      case AcademicPathStatus.enrolled:
        return 'enrolled';

      case AcademicPathStatus.graduated:
        return 'graduated';

      case AcademicPathStatus.suspended:
        return 'suspended';

      case AcademicPathStatus.withdrawn:
        return 'withdrawn';

      case AcademicPathStatus.transferred:
        return 'transferred';
    }
  }

  String _reviewModerationStatusValue(ReviewModerationStatus status) {
    switch (status) {
      case ReviewModerationStatus.pending:
        return 'pending';

      case ReviewModerationStatus.approved:
        return 'approved';

      case ReviewModerationStatus.rejected:
        return 'rejected';

      case ReviewModerationStatus.hidden:
        return 'hidden';
    }
  }

  List<SocialReview> _reviewsFromMap(Map<String, dynamic> data) {
    final dynamic reviews = data['reviews'];

    if (reviews is! List) {
      return [];
    }

    return reviews
        .whereType<Map>()
        .map(
          (Map<dynamic, dynamic> item) =>
              SocialReview.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<NotificationListResult> getNotifications({
    bool unreadOnly = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final Uri url = _apiUri(
      '/notifications',
      queryParameters: {
        'unread_only': unreadOnly,
        'limit': limit,
        'offset': offset,
      },
    );

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore caricamento notifiche',
    );

    return NotificationListResult.fromJson(data);
  }

  Future<int> getUnreadNotificationCount() async {
    final Uri url = _apiUri('/notifications/unread-count');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore caricamento notifiche non lette',
    );

    return _toInt(data['unread_count']) ?? 0;
  }

  Future<StudentLabNotification> getNotification(int notificationId) async {
    final Uri url = _apiUri('/notifications/$notificationId');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore caricamento notifica',
    );

    return StudentLabNotification.fromJson(data);
  }

  Future<void> markNotificationAsRead(int notificationId) async {
    final Uri url = _apiUri('/notifications/$notificationId/read');

    final http.Response response = await http.post(url, headers: _jsonHeaders);

    _checkSuccess(response, 'Errore aggiornamento notifica');
  }

  Future<void> markNotificationAsUnread(int notificationId) async {
    final Uri url = _apiUri('/notifications/$notificationId/unread');

    final http.Response response = await http.post(url, headers: _jsonHeaders);

    _checkSuccess(response, 'Errore aggiornamento notifica');
  }

  Future<void> markAllNotificationsAsRead() async {
    final Uri url = _apiUri('/notifications/read-all');

    final http.Response response = await http.post(url, headers: _jsonHeaders);

    _checkSuccess(response, 'Errore aggiornamento notifiche');
  }

  Future<void> deleteNotification(int notificationId) async {
    final Uri url = _apiUri('/notifications/$notificationId');

    final http.Response response = await http.delete(
      url,
      headers: _jsonHeaders,
    );

    _checkSuccess(response, 'Errore eliminazione notifica');
  }

  Future<void> deleteAllNotifications() async {
    final Uri url = _apiUri('/notifications');

    final http.Response response = await http.delete(
      url,
      headers: _jsonHeaders,
    );

    _checkSuccess(response, 'Errore eliminazione notifiche');
  }

  Future<Map<String, dynamic>> acceptGroupOwnershipTransfer(
    int transferId,
  ) async {
    final Uri url = _apiUri(
      '/group-ownership-transfers/'
      '$transferId/'
      'accept',
    );

    final http.Response response = await http.post(url, headers: _jsonHeaders);

    return _decodeMapResponse(response, 'Errore accettazione proprietà gruppo');
  }

  Future<Map<String, dynamic>> rejectGroupOwnershipTransfer(
    int transferId,
  ) async {
    final Uri url = _apiUri(
      '/group-ownership-transfers/'
      '$transferId/'
      'reject',
    );

    final http.Response response = await http.post(url, headers: _jsonHeaders);

    return _decodeMapResponse(response, 'Errore rifiuto proprietà gruppo');
  }

  Future<bool> canAccessAdminPanel() async {
    final Uri url = _apiUri('/admin/access');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    if (response.statusCode == 200) {
      return true;
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      return false;
    }

    throw Exception(
      'Impossibile verificare i permessi amministrativi: '
      '${response.statusCode} - ${response.body}',
    );
  }

  Future<bool> canAccessTeacherArea() async {
    final Uri url = _apiUri('/teacher/access');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    if (response.statusCode == 200) {
      return true;
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      return false;
    }

    throw Exception(
      'Impossibile verificare i permessi docente: '
      '${response.statusCode} - ${response.body}',
    );
  }

  Future<List<Map<String, dynamic>>> getTeacherSubjects() async {
    final Uri url = _apiUri('/teacher/subjects');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeListResponse(response, 'Errore caricamento materie docente');
  }

  Future<List<Map<String, dynamic>>> getTeacherMaterials() async {
    final Uri url = _apiUri('/teacher/materials');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeListResponse(
      response,
      'Errore caricamento materiali docente',
    );
  }

  Future<List<Map<String, dynamic>>> getTeacherMaterialAssignments({
    required int materialId,
    bool includeRevoked = false,
  }) async {
    if (materialId <= 0) {
      throw ArgumentError('Identificativo materiale non valido.');
    }

    final Uri url = _apiUri(
      '/teacher/materials/$materialId/assignments',
      queryParameters: {'include_revoked': includeRevoked},
    );

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeListResponse(
      response,
      'Errore caricamento assegnazioni materiale',
    );
  }

  Future<Map<String, dynamic>> createTeacherMaterialAssignment({
    required int materialId,
    int? userId,
    int? groupId,
  }) async {
    if (materialId <= 0) {
      throw ArgumentError('Identificativo materiale non valido.');
    }

    final bool hasUser = userId != null;
    final bool hasGroup = groupId != null;

    if (hasUser == hasGroup) {
      throw ArgumentError(
        'Seleziona un solo destinatario tra studente e gruppo.',
      );
    }

    if (userId != null && userId <= 0) {
      throw ArgumentError('Identificativo studente non valido.');
    }

    if (groupId != null && groupId <= 0) {
      throw ArgumentError('Identificativo gruppo non valido.');
    }

    final Uri url = _apiUri('/teacher/materials/$materialId/assignments');

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({'user_id': userId, 'group_id': groupId}),
    );

    return _decodeMapResponse(response, 'Errore assegnazione materiale');
  }

  Future<List<Map<String, dynamic>>> createTeacherMaterialAssignmentsBulk({
    required int materialId,
    List<int> userIds = const [],
    List<int> groupIds = const [],
  }) async {
    if (materialId <= 0) {
      throw ArgumentError('Identificativo materiale non valido.');
    }

    final List<int> normalizedUserIds = userIds
        .where((int id) => id > 0)
        .toSet()
        .toList();
    final List<int> normalizedGroupIds = groupIds
        .where((int id) => id > 0)
        .toSet()
        .toList();

    if (normalizedUserIds.isEmpty && normalizedGroupIds.isEmpty) {
      throw ArgumentError('Seleziona almeno uno studente o un gruppo.');
    }

    final Uri url = _apiUri('/teacher/materials/$materialId/assignments/bulk');

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({
        'user_ids': normalizedUserIds,
        'group_ids': normalizedGroupIds,
      }),
    );

    return _decodeListResponse(
      response,
      'Errore assegnazione multipla materiale',
    );
  }

  Future<Map<String, dynamic>> getTeacherMaterialAssignment(
    int assignmentId,
  ) async {
    if (assignmentId <= 0) {
      throw ArgumentError('Identificativo assegnazione non valido.');
    }

    final Uri url = _apiUri('/teacher-material-assignments/$assignmentId');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeMapResponse(
      response,
      'Errore caricamento assegnazione materiale',
    );
  }

  Future<Map<String, dynamic>> revokeTeacherMaterialAssignment(
    int assignmentId,
  ) async {
    if (assignmentId <= 0) {
      throw ArgumentError('Identificativo assegnazione non valido.');
    }

    final Uri url = _apiUri(
      '/teacher-material-assignments/$assignmentId/revoke',
    );

    final http.Response response = await http.patch(url, headers: _jsonHeaders);

    return _decodeMapResponse(response, 'Errore revoca assegnazione materiale');
  }

  Future<Map<String, dynamic>> getTeacherMaterial(int materialId) async {
    final Uri url = _apiUri('/teacher/materials/$materialId');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeMapResponse(response, 'Errore caricamento materiale docente');
  }

  Future<Map<String, dynamic>> updateTeacherMaterial({
    required int materialId,
    String? title,
    String? description,
    String? visibility,
    bool? isActive,
  }) async {
    final Map<String, dynamic> body = {};

    if (title != null) {
      body['title'] = title;
    }

    if (description != null) {
      body['description'] = description;
    }

    if (visibility != null) {
      body['visibility'] = visibility;
    }

    if (isActive != null) {
      body['is_active'] = isActive;
    }

    final Uri url = _apiUri('/teacher/materials/$materialId');

    final http.Response response = await http.patch(
      url,
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );

    return _decodeMapResponse(
      response,
      'Errore aggiornamento materiale docente',
    );
  }

  Future<void> deleteTeacherMaterial(int materialId) async {
    final Uri url = _apiUri('/teacher/materials/$materialId');

    final http.Response response = await http.delete(
      url,
      headers: _jsonHeaders,
    );

    _checkSuccess(response, 'Errore eliminazione materiale docente');
  }

  Future<List<Map<String, dynamic>>> getSubjectTeacherMaterials(
    int subjectId,
  ) async {
    final Uri url = _apiUri('/subjects/$subjectId/teacher-materials');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeListResponse(
      response,
      'Errore caricamento materiali docente',
    );
  }

  Future<Map<String, dynamic>> requestTeacherMaterialUpload({
    required int subjectId,
    required String originalName,
    required String mimeType,
    required int size,
    String? fileHash,
  }) async {
    final Uri url = _apiUri('/teacher/materials/upload-request');

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({
        'subject_id': subjectId,
        'original_name': originalName,
        'mime_type': mimeType,
        'size': size,
        'file_hash': fileHash,
      }),
    );

    return _decodeMapResponse(response, 'Errore autorizzazione upload docente');
  }

  Future<Map<String, dynamic>> completeTeacherMaterial({
    required int subjectId,
    required String title,
    required String description,
    required String originalName,
    required String storedName,
    required String filePath,
    required String mimeType,
    required int size,
    String? fileHash,
    String visibility = 'students',
  }) async {
    final Uri url = _apiUri('/teacher/materials/complete');

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({
        'subject_id': subjectId,
        'title': title,
        'description': description,
        'original_name': originalName,
        'stored_name': storedName,
        'file_path': filePath,
        'mime_type': mimeType,
        'size': size,
        'file_hash': fileHash,
        'visibility': visibility,
      }),
    );

    return _decodeMapResponse(
      response,
      'Errore registrazione materiale docente',
    );
  }

  Future<Map<String, dynamic>> uploadTeacherMaterial({
    required int subjectId,
    required String title,
    required String description,
    required String visibility,
    required String filePath,
  }) async {
    _requireCurrentUserId();

    return StudentLabUploadService().uploadTeacherMaterial(
      subjectId: subjectId,
      title: title,
      description: description,
      visibility: visibility,
      filePath: filePath,
    );
  }

  Future<Map<String, dynamic>> uploadTeacherMaterialBytes({
    required int subjectId,
    required String title,
    required String description,
    required String visibility,
    required Uint8List bytes,
    required String originalName,
  }) async {
    _requireCurrentUserId();
    return StudentLabUploadService().uploadTeacherMaterialBytes(
      subjectId: subjectId,
      title: title,
      description: description,
      visibility: visibility,
      bytes: bytes,
      originalName: originalName,
    );
  }

  Future<Map<String, dynamic>> requestMaterialPublicationUpload({
    required int subjectId,
    required String title,
    required String description,
    required String originalName,
    required String mimeType,
    required int size,
    required String fileHash,
  }) async {
    _requireCurrentUserId();

    final Uri url = _apiUri('/material_publication/upload-request');

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({
        'subject_id': subjectId,
        'title': title.trim(),
        'description': description.trim(),
        'original_name': originalName,
        'mime_type': mimeType,
        'size': size,
        'file_hash': fileHash.trim().toLowerCase(),
      }),
    );

    return _decodeMapResponse(response, 'Errore controllo materiale');
  }

  Future<Map<String, dynamic>> completeMaterialPublication(
    Map<String, dynamic> payload,
  ) async {
    _requireCurrentUserId();

    final Uri url = _apiUri('/material_publication/complete');

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode(payload),
    );

    return _decodeMapResponse(response, 'Errore invio materiale in revisione');
  }

  Future<List<Map<String, dynamic>>> getMyMaterialPublicationRequests() async {
    _requireCurrentUserId();

    final Uri url = _apiUri('/material_publication/me');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeListResponse(
      response,
      'Errore caricamento richieste materiali',
    );
  }

  Future<Map<String, dynamic>> getMyMaterialPublicationRequest(
    int requestId,
  ) async {
    _requireCurrentUserId();

    final Uri url = _apiUri('/material_publication/me/$requestId');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeMapResponse(
      response,
      'Errore caricamento richiesta materiale',
    );
  }

  Future<Map<String, dynamic>> uploadMaterialPublication({
    required int subjectId,
    required String title,
    required String description,
    required String filePath,
    Future<void> Function()? onPossibleDuplicate,
  }) async {
    _requireCurrentUserId();

    return StudentLabUploadService().uploadMaterialPublication(
      subjectId: subjectId,
      title: title,
      description: description,
      filePath: filePath,
      onPossibleDuplicate: onPossibleDuplicate,
    );
  }

  Future<Map<String, dynamic>> uploadMaterialPublicationBytes({
    required int subjectId,
    required String title,
    required String description,
    required Uint8List bytes,
    required String originalName,
    Future<void> Function()? onPossibleDuplicate,
  }) async {
    _requireCurrentUserId();
    return StudentLabUploadService().uploadMaterialPublicationBytes(
      subjectId: subjectId,
      title: title,
      description: description,
      bytes: bytes,
      originalName: originalName,
      onPossibleDuplicate: onPossibleDuplicate,
    );
  }

  Future<List<Map<String, dynamic>>> getAdminMaterialPublications({
    String? status,
  }) async {
    final Uri url = _apiUri(
      '/admin/material_publications',
      queryParameters: {
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      },
    );

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeListResponse(
      response,
      'Errore caricamento richieste materiali',
    );
  }

  Future<List<Map<String, dynamic>>>
  getPendingAdminMaterialPublications() async {
    final Uri url = _apiUri('/admin/material_publications/pending');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeListResponse(
      response,
      'Errore caricamento materiali da verificare',
    );
  }

  Future<Map<String, dynamic>> getAdminMaterialPublication(
    int requestId,
  ) async {
    final Uri url = _apiUri('/admin/material_publications/$requestId');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeMapResponse(
      response,
      'Errore caricamento richiesta materiale',
    );
  }

  Future<Uint8List> downloadAdminMaterialPublicationFile(int requestId) async {
    final Uri url = _apiUri(
      '/admin/material_publications/'
      '$requestId/file',
    );

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }

    throw Exception('Impossibile caricare il file della richiesta.');
  }

  Future<Map<String, dynamic>> getAdminPossibleDuplicateMaterial(
    int requestId,
  ) async {
    final Uri url = _apiUri(
      '/admin/material_publications/'
      '$requestId/possible-duplicate',
    );

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    return _decodeMapResponse(
      response,
      'Errore caricamento possibile duplicato',
    );
  }

  Future<Uint8List> downloadAdminPossibleDuplicateFile(int requestId) async {
    final Uri url = _apiUri(
      '/admin/material_publications/'
      '$requestId/possible-duplicate/file',
    );

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }

    throw Exception('Impossibile caricare il possibile duplicato.');
  }

  Future<Map<String, dynamic>> reviewAdminMaterialDuplicate({
    required int requestId,
    required Map<String, dynamic> data,
  }) async {
    final Uri url = _apiUri(
      '/admin/material_publications/'
      '$requestId/duplicate',
    );

    final http.Response response = await http.patch(
      url,
      headers: _jsonHeaders,
      body: jsonEncode(data),
    );

    return _decodeMapResponse(response, 'Errore verifica duplicato materiale');
  }

  Future<Map<String, dynamic>> approveAdminMaterialPublication({
    required int requestId,
    required Map<String, dynamic> data,
  }) async {
    final Uri url = _apiUri(
      '/admin/material_publications/'
      '$requestId/approve',
    );

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode(data),
    );

    return _decodeMapResponse(response, 'Errore approvazione materiale');
  }

  Future<Map<String, dynamic>> rejectAdminMaterialPublication({
    required int requestId,
    required Map<String, dynamic> data,
  }) async {
    final Uri url = _apiUri(
      '/admin/material_publications/'
      '$requestId/reject',
    );

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode(data),
    );

    return _decodeMapResponse(response, 'Errore rifiuto materiale');
  }

  Future<List<TeacherAssignment>> getMyTeacherAssignments() async {
    final Uri url = Uri.parse('$baseUrl/me/teacher_assignments');

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    final List<Map<String, dynamic>> data = _decodeListResponse(
      response,
      'Errore caricamento insegnamenti docente',
    );

    return data.map(TeacherAssignment.fromJson).toList();
  }

  Future<List<TeacherAssignment>> getTeacherAssignments(int userId) async {
    final Uri url = Uri.parse(
      '$baseUrl/user/'
      '$userId/'
      'teacher_assignments',
    );

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    final List<Map<String, dynamic>> data = _decodeListResponse(
      response,
      'Errore caricamento insegnamenti docente',
    );

    return data.map(TeacherAssignment.fromJson).toList();
  }

  Future<TeacherAssignment> createTeacherAssignment({
    required int subjectId,
    int? offeringId,
    bool isCurrent = true,
  }) async {
    final Uri url = Uri.parse('$baseUrl/me/teacher_assignments');

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({
        'subject_id': subjectId,

        'offering_id': offeringId,

        'is_current': isCurrent,
      }),
    );

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore creazione insegnamento docente',
    );

    return TeacherAssignment.fromJson(data);
  }

  Future<TeacherAssignment> updateTeacherAssignment({
    required int assignmentId,
    int? subjectId,
    int? offeringId,
    bool clearOffering = false,
    bool? isCurrent,
  }) async {
    final Map<String, dynamic> body = {};

    if (subjectId != null) {
      body['subject_id'] = subjectId;
    }

    if (clearOffering) {
      body['offering_id'] = null;
    } else if (offeringId != null) {
      body['offering_id'] = offeringId;
    }

    if (isCurrent != null) {
      body['is_current'] = isCurrent;
    }

    final Uri url = Uri.parse(
      '$baseUrl/me/'
      'teacher_assignments/'
      '$assignmentId',
    );

    final http.Response response = await http.patch(
      url,
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore aggiornamento insegnamento docente',
    );

    return TeacherAssignment.fromJson(data);
  }

  Future<void> deleteTeacherAssignment(int assignmentId) async {
    final Uri url = Uri.parse(
      '$baseUrl/me/'
      'teacher_assignments/'
      '$assignmentId',
    );

    final http.Response response = await http.delete(
      url,
      headers: _jsonHeaders,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Errore eliminazione insegnamento docente: '
        '${response.statusCode} - '
        '${response.body}',
      );
    }
  }

  Future<List<TeacherAssignment>> getPendingTeacherAssignments() async {
    final Uri url = Uri.parse(
      '$baseUrl/admin/'
      'teacher_assignments/'
      'pending',
    );

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    final List<Map<String, dynamic>> data = _decodeListResponse(
      response,
      'Errore caricamento insegnamenti da verificare',
    );

    return data.map(TeacherAssignment.fromJson).toList();
  }

  Future<List<TeacherAssignment>> getAdminTeacherAssignments({
    String? status,
  }) async {
    final String query =
        (status != null && status.isNotEmpty && status != 'all')
        ? '?status=$status'
        : '';

    final Uri url = Uri.parse(
      '$baseUrl/admin/'
      'teacher_assignments'
      '$query',
    );

    final http.Response response = await http.get(url, headers: _jsonHeaders);

    final List<Map<String, dynamic>> data = _decodeListResponse(
      response,
      'Errore caricamento insegnamenti',
    );

    return data.map(TeacherAssignment.fromJson).toList();
  }

  Future<TeacherAssignment> verifyTeacherAssignment({
    required int assignmentId,
    required bool approve,
  }) async {
    return setTeacherAssignmentStatus(
      assignmentId: assignmentId,
      status: approve ? 'verified' : 'rejected',
    );
  }

  Future<TeacherAssignment> setTeacherAssignmentStatus({
    required int assignmentId,
    required String status,
  }) async {
    final Uri url = Uri.parse(
      '$baseUrl/admin/'
      'teacher_assignments/'
      '$assignmentId/'
      'verification',
    );

    final http.Response response = await http.patch(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({'status': status}),
    );

    final Map<String, dynamic> data = _decodeMapResponse(
      response,
      'Errore aggiornamento insegnamento docente',
    );

    return TeacherAssignment.fromJson(data);
  }

  Future<Uint8List> downloadTeacherMaterial(int materialId) {
    return downloadMaterial(source: 'teacher', materialId: materialId);
  }

  Future<Map<String, dynamic>> deleteAdminUser(int userId) async {
    if (userId <= 0) {
      throw ArgumentError('Identificativo utente non valido.');
    }

    final Uri url = _apiUri('/admin/users/$userId');

    final http.Response response = await http.delete(
      url,
      headers: _jsonHeaders,
    );

    return _decodeMapResponse(response, 'Errore eliminazione account utente');
  }

  Future<Map<String, dynamic>> contactUser({
    required int userId,
    required String requestType,
    int? subjectId,
    required String subject,
    required String message,
  }) async {
    if (userId <= 0) {
      throw ArgumentError('Destinatario non valido.');
    }

    final String normalizedType = requestType.trim().toLowerCase();

    if (!{'general', 'help', 'private_lesson'}.contains(normalizedType)) {
      throw ArgumentError('Tipo di richiesta non valido.');
    }

    if ((normalizedType == 'help' || normalizedType == 'private_lesson') &&
        (subjectId == null || subjectId <= 0)) {
      throw ArgumentError('Seleziona una materia valida.');
    }

    final String normalizedSubject = subject
        .trim()
        .split(RegExp(r'\s+'))
        .join(' ');
    final String normalizedMessage = message.trim();

    if (normalizedSubject.isEmpty) {
      throw ArgumentError('Inserisci l’oggetto della richiesta.');
    }

    if (normalizedSubject.length > 160 ||
        normalizedSubject.contains('\n') ||
        normalizedSubject.contains('\r')) {
      throw ArgumentError('Oggetto della richiesta non valido.');
    }

    if (normalizedMessage.isEmpty) {
      throw ArgumentError('Inserisci il messaggio.');
    }

    if (normalizedMessage.length > 5000) {
      throw ArgumentError('Il messaggio è troppo lungo.');
    }

    final Uri url = _apiUri('/contact/users/$userId');

    final http.Response response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({
        'request_type': normalizedType,
        'subject_id': subjectId,
        'subject': normalizedSubject,
        'message': normalizedMessage,
      }),
    );

    return _decodeMapResponse(response, 'Errore invio richiesta');
  }
}
