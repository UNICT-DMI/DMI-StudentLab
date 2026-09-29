import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../services/auth_session.dart';

/// Il catalogo storico può usare nomi diversi per lo stesso corso.
String faqCourseLabel(String? value) {
  final name = (value ?? '').trim();
  final key = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  const aliases = {
    'informatica': 'Informatica L-31',
    'informatica l 31': 'Informatica L-31',
    'l 31 informatica': 'Informatica L-31',
    'l 31': 'Informatica L-31',
    'scienze e tecnologie informatiche': 'Informatica L-31',
    'informatica magistrale': 'Informatica magistrale (LM-18)',
    'informatica magistrale lm 18': 'Informatica magistrale (LM-18)',
    'lm 18': 'Informatica magistrale (LM-18)',
    'matematica': 'Matematica L-35',
    'matematica l 35': 'Matematica L-35',
    'l 35 matematica': 'Matematica L-35',
    'l 35': 'Matematica L-35',
    'matematica magistrale': 'Matematica magistrale (LM-40)',
    'matematica magistrale lm 40': 'Matematica magistrale (LM-40)',
    'lm 40': 'Matematica magistrale (LM-40)',
    'scienze biologiche': 'Scienze Biologiche L-13',
    'scienze biologiche l 13': 'Scienze Biologiche L-13',
    'l 13': 'Scienze Biologiche L-13',
  };
  return aliases[key] ?? name;
}

/// Chiamate al backend per "Domande" (FAQ universitaria) e "Com'è l'esame".
///
/// Tutto ciò che si scrive (domande, risposte, racconti) resta "in attesa"
/// finché un admin non lo approva. Le risposte si possono dare anche da
/// ospite: il dispositivo ha una chiave casuale per ritrovare le sue risposte
/// in attesa.
class FaqApiService {
  FaqApiService() : _base = ApiService().baseUrl;

  final String _base;
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _guestKeyName = 'studentlab.faq.guest_key';
  static String? _guestKey;

  bool get isAuthenticated => AuthSession.instance.isAuthenticated;

  Map<String, String> get _authHeader {
    final String? token = AuthSession.instance.accessToken;
    return <String, String>{
      if (token != null && token.trim().isNotEmpty) 'Authorization': 'Bearer ${token.trim()}',
      'Accept': 'application/json',
    };
  }

  Map<String, String> get _jsonHeaders => {..._authHeader, 'Content-Type': 'application/json'};

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(_base);
    final basePath = base.path.endsWith('/') ? base.path.substring(0, base.path.length - 1) : base.path;
    return base.replace(path: '$basePath$path', queryParameters: query == null || query.isEmpty ? null : query);
  }

  /// Indirizzo completo di un file allegato (serve anche il token se c'è).
  Uri fileUri(String path) => _uri(path);
  Map<String, String> get fileHeaders => _authHeader;

  dynamic _decode(http.Response response, String fallback) {
    final dynamic decoded =
        response.body.trim().isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
    String message = fallback;
    if (decoded is Map) {
      final detail = decoded['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        message = detail.trim();
      } else if (detail is List && detail.isNotEmpty && detail.first is Map) {
        message = (detail.first as Map)['msg']?.toString() ?? fallback;
      }
    }
    if (response.statusCode == 401) message = 'Accedi per continuare.';
    throw Exception(message);
  }

  List<Map<String, dynamic>> _list(dynamic value) =>
      value is List ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];

  Map<String, dynamic> _map(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : {};

  /// Chiave casuale del dispositivo per le risposte da ospite.
  Future<String> guestKey() async {
    if (_guestKey != null) return _guestKey!;
    String? stored;
    try {
      stored = await _storage.read(key: _guestKeyName);
    } catch (_) {}
    if (stored == null || stored.length < 16) {
      final random = Random.secure();
      stored = List<int>.generate(24, (_) => random.nextInt(256))
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      try {
        await _storage.write(key: _guestKeyName, value: stored);
      } catch (_) {}
    }
    return _guestKey = stored;
  }

  // Filtri --------------------------------------------------------------------

  /// Materie attive con ateneo, dipartimento e corso (per i chip).
  Future<List<Map<String, dynamic>>> filters() async {
    final values = _list(_decode(
        await http.get(_uri('/faq/filters'), headers: _authHeader), 'Filtri non disponibili.'));
    for (final value in values) {
      value['course'] = faqCourseLabel(value['course']?.toString());
    }
    return values;
  }

  // Domande -------------------------------------------------------------------

  Future<Map<String, dynamic>> questions({
    String? university,
    String? department,
    String? course,
    int? subjectId,
    String? category,
    String query = '',
    String view = 'all',
    String sort = 'useful',
    int limit = 30,
    int offset = 0,
  }) async {
    final r = await http.get(
        _uri('/faq/questions', {
          if (university != null) 'university': university,
          if (department != null) 'department': department,
          if (course != null) 'course': course,
          if (subjectId != null) 'subject_id': '$subjectId',
          if (category != null) 'category': category,
          if (query.trim().isNotEmpty) 'q': query.trim(),
          'view': view,
          'sort': sort,
          'limit': '$limit',
          'offset': '$offset',
        }),
        headers: _authHeader);
    return _map(_decode(r, 'Impossibile caricare le domande.'));
  }

  Future<List<Map<String, dynamic>>> suggestions(String text, {int? subjectId}) async {
    if (text.trim().length < 3) return const [];
    final r = await http.get(
        _uri('/faq/suggestions', {'q': text.trim(), if (subjectId != null) 'subject_id': '$subjectId'}),
        headers: _authHeader);
    return _list(_decode(r, 'Ricerca non disponibile.'));
  }

  Future<Map<String, dynamic>> question(int id) async {
    final key = isAuthenticated ? null : await guestKey();
    final r = await http.get(_uri('/faq/questions/$id', {if (key != null) 'guest_key': key}), headers: _authHeader);
    return _map(_decode(r, 'Domanda non disponibile.'));
  }

  Future<Map<String, dynamic>> createQuestion({
    required String title,
    String? body,
    required String category,
    int? subjectId,
    String? university,
    String? department,
    String? course,
    bool anonymous = true,
    bool askTeacher = false,
  }) async {
    final r = await http.post(_uri('/faq/questions'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'title': title,
          if (body != null && body.trim().isNotEmpty) 'body': body.trim(),
          'category': category,
          if (subjectId != null) 'subject_id': subjectId,
          if (university != null) 'university': university,
          if (department != null) 'department': department,
          if (course != null) 'course': course,
          'is_anonymous': anonymous,
          'ask_teacher': askTeacher,
        }));
    return _map(_decode(r, 'Domanda non inviata.'));
  }

  /// Risposta con testo e, facoltativi, un file o un materiale delle Dispense.
  Future<Map<String, dynamic>> answer(
    int questionId,
    String body, {
    int? materialId,
    Uint8List? fileBytes,
    String? fileName,
    String? guestName,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/faq/questions/$questionId/answers'))
      ..headers.addAll(_authHeader)
      ..fields['body'] = body;
    if (materialId != null) request.fields['public_material_id'] = '$materialId';
    if (!isAuthenticated) {
      request.fields['guest_key'] = await guestKey();
      if (guestName != null && guestName.trim().isNotEmpty) request.fields['guest_name'] = guestName.trim();
    }
    if (fileBytes != null && fileName != null) {
      request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName));
    }
    final response = await http.Response.fromStream(await request.send());
    return _map(_decode(response, 'Risposta non inviata.'));
  }

  Future<Map<String, dynamic>> voteQuestion(int id, String kind) async => _map(_decode(
      await http.post(_uri('/faq/questions/$id/votes'), headers: _jsonHeaders, body: jsonEncode({'kind': kind})),
      'Voto non registrato.'));

  Future<Map<String, dynamic>> voteAnswer(int id) async =>
      _map(_decode(await http.post(_uri('/faq/answers/$id/votes'), headers: _jsonHeaders), 'Voto non registrato.'));

  Future<Map<String, dynamic>> accept(int questionId, int? answerId) async => _map(_decode(
      await http.post(_uri('/faq/questions/$questionId/accept'),
          headers: _jsonHeaders, body: jsonEncode({'answer_id': answerId})),
      'Operazione non riuscita.'));

  Future<Uint8List> downloadAnswerFile(String path) async {
    final r = await http.get(_uri(path), headers: _authHeader);
    if (r.statusCode >= 200 && r.statusCode < 300) return r.bodyBytes;
    _decode(r, 'File non disponibile.');
    return Uint8List(0);
  }

  // Com'è l'esame -------------------------------------------------------------

  Future<Map<String, dynamic>> examSummary(int subjectId) async => _map(_decode(
      await http.get(_uri('/faq/exam', {'subject_id': '$subjectId'}), headers: _authHeader),
      'Racconti non disponibili.'));

  Future<Map<String, dynamic>> createExamReport({
    required int subjectId,
    required DateTime examDate,
    required String format,
    int? durationMinutes,
    required int difficulty,
    required List<String> topics,
    String? body,
    bool anonymous = true,
  }) async {
    final date = '${examDate.year.toString().padLeft(4, '0')}-${examDate.month.toString().padLeft(2, '0')}-'
        '${examDate.day.toString().padLeft(2, '0')}';
    final r = await http.post(_uri('/faq/exam'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'subject_id': subjectId,
          'exam_date': date,
          'exam_format': format,
          if (durationMinutes != null) 'duration_minutes': durationMinutes,
          'difficulty': difficulty,
          'topics': topics,
          if (body != null && body.trim().isNotEmpty) 'body': body.trim(),
          'is_anonymous': anonymous,
        }));
    return _map(_decode(r, 'Racconto non inviato.'));
  }

  // I miei contenuti ------------------------------------------------------------

  Future<Map<String, dynamic>> mine() async =>
      _map(_decode(await http.get(_uri('/faq/mine'), headers: _authHeader), 'Contenuti non disponibili.'));

  // Moderazione (admin) -------------------------------------------------------

  Future<Map<String, dynamic>> moderationCounts() async => _map(
      _decode(await http.get(_uri('/faq/moderation/counts'), headers: _authHeader), 'Code non disponibili.'));

  Future<List<Map<String, dynamic>>> moderationQueue(String kind) async => _list(
      _decode(await http.get(_uri('/faq/moderation/$kind'), headers: _authHeader), 'Coda non disponibile.'));

  Future<void> moderate(String kind, int id, String action, {String? note}) async => _decode(
      await http.post(_uri('/faq/moderation/$kind/$id'),
          headers: _jsonHeaders,
          body: jsonEncode({'action': action, if (note != null && note.trim().isNotEmpty) 'note': note.trim()})),
      'Operazione non riuscita.');
}
