import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:fe/services/api_service.dart';
import 'package:fe/services/auth_session.dart';
import 'package:fe/quiz/exercises/exercise_models.dart';

/// Chiamate del modulo esercizi (/exercises/...). La correzione è sempre del server.
class ExerciseApiService {
  final String _base;

  ExerciseApiService() : _base = ApiService().baseUrl;

  String? get _token {
    final String? value = AuthSession.instance.accessToken;
    return value == null || value.trim().isEmpty ? null : value.trim();
  }

  bool get isLoggedIn => !AuthSession.instance.isGuest && _token != null;

  Map<String, String> get _headers => <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri uri(String path, [Map<String, String>? query]) {
    final Uri base = Uri.parse(_base);
    return base.replace(
      path: '${base.path.replaceAll(RegExp(r'/$'), '')}$path',
      queryParameters: query == null || query.isEmpty ? null : query,
    );
  }

  dynamic _decode(http.Response response, String fallback) {
    dynamic decoded;
    if (response.body.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        decoded = null;
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
    if (decoded is Map) {
      final dynamic detail = decoded['detail'];
      if (detail is String && detail.trim().isNotEmpty) throw Exception(detail.trim());
    }
    if (response.statusCode == 401) throw Exception('Accedi per continuare.');
    if (response.statusCode == 429) throw Exception('Troppe richieste: riprova tra qualche minuto.');
    throw Exception(fallback);
  }

  Map<String, dynamic> _subject(String department, String course, String subject) =>
      <String, dynamic>{'department': department, 'course': course, 'subject': subject};

  Future<dynamic> _post(String path, Map<String, dynamic> body, String fallback) async =>
      _decode(await http.post(uri(path), headers: _headers, body: jsonEncode(body)), fallback);

  // --------------------------------------------------------------- studente
  Future<Map<String, dynamic>> catalog(String department, String course, String subject) async =>
      asMap(await _post('/exercises/catalog', _subject(department, course, subject), 'Catalogo non disponibile.'));

  Future<List<ExerciseItem>> practice({
    required String department,
    required String course,
    required String subject,
    List<String> types = const <String>[],
    List<String> arguments = const <String>[],
    int count = 10,
    List<String> itemIds = const <String>[],
    ExerciseChoice? choice,
    List<Map<String, dynamic>> history = const <Map<String, dynamic>>[],
  }) async {
    final Map<String, dynamic> data = asMap(await _post('/exercises/practice', <String, dynamic>{
      ..._subject(department, course, subject),
      ...?choice?.toJson(),
      'types': types,
      if (choice == null) 'arguments': arguments,
      'count': count,
      if (itemIds.isNotEmpty) 'item_ids': itemIds,
      if (history.isNotEmpty) 'history': history,
    }, 'Esercizi non disponibili.'));
    return asMapList(data['items']).map(ExerciseItem.fromJson).toList();
  }

  /// Passo 2 della scelta: per ogni tipo di esercizio quanti ce ne sono con i filtri scelti,
  /// per quali argomenti, durata media, difficoltà e i risultati dello studente.
  /// Senza account lo storico arriva dal telefono (history).
  Future<Map<String, dynamic>> overview({
    required String department,
    required String course,
    required String subject,
    ExerciseChoice choice = const ExerciseChoice(),
    List<Map<String, dynamic>> history = const <Map<String, dynamic>>[],
  }) async =>
      asMap(await _post('/exercises/overview', <String, dynamic>{
        ..._subject(department, course, subject),
        ...choice.toJson(),
        if (history.isNotEmpty) 'history': history,
      }, 'Esercizi non disponibili.'));

  Future<ExerciseResult> check({
    required String department,
    required String course,
    required String subject,
    required String itemId,
    required Map<String, dynamic> answer,
    Map<String, dynamic>? scope,
  }) async =>
      ExerciseResult.fromJson(asMap(await _post('/exercises/check', <String, dynamic>{
        ..._subject(department, course, subject),
        'item_id': itemId,
        'answer': answer,
        if (scope != null) 'scope': scope,
      }, 'Correzione non riuscita.')));

  /// Controllo dentro un tentativo salvato: il server conta i tentativi e, nei compiti
  /// assegnati, mostra la soluzione solo a risposta giusta o a tentativi finiti.
  /// Restituisce la risposta grezza: {..esito, tries, max_tries, final}.
  Future<Map<String, dynamic>> attemptCheck({
    required int attemptId,
    required String itemId,
    required Map<String, dynamic> answer,
    Map<String, dynamic>? scope,
  }) async =>
      asMap(await _post('/exercises/attempts/$attemptId/check', <String, dynamic>{
        'item_id': itemId,
        'answer': answer,
        if (scope != null) 'scope': scope,
      }, 'Correzione non riuscita.'));

  /// Domande a risposta multipla dentro una sessione mista (endpoint di sempre).
  Future<ExerciseResult> checkMultipleChoice({
    required String department,
    required String course,
    required String subject,
    required String questionId,
    required String optionId,
  }) async {
    final Map<String, dynamic> data = asMap(await _post('/validate_answer', <String, dynamic>{
      'id_question': questionId,
      'id_choice': optionId,
      ..._subject(department, course, subject),
    }, 'Correzione non riuscita.'));
    final String correct = data['correct_option_id']?.toString() ?? '';
    final String formal = data['formal_explanation']?.toString() ?? '';
    final String informal = data['informal_explanation']?.toString() ?? '';
    return ExerciseResult(
      isCorrect: data['is_correct'] == true,
      score: data['is_correct'] == true ? 1 : 0,
      feedback: const <String, dynamic>{},
      solution: <String, dynamic>{'correct': <String>[correct]},
      explanation: <String>[formal, informal].where((String t) => t.trim().isNotEmpty).join('\n\n'),
      solutionText: '',
    );
  }

  Future<Map<String, dynamic>> runCode({
    required String department,
    required String course,
    required String subject,
    required String itemId,
    required String code,
  }) async =>
      asMap(await _post('/exercises/run', <String, dynamic>{
        ..._subject(department, course, subject),
        'item_id': itemId,
        'code': code,
      }, 'Esecuzione non riuscita.'));

  /// Esercitazione salvata nello storico (serve l'account).
  Future<Map<String, dynamic>> start({
    required String department,
    required String course,
    required String subject,
    List<String> types = const <String>[],
    List<String> arguments = const <String>[],
    int count = 10,
    ExerciseChoice? choice,
    int? timeLimitSeconds,
    bool quiz = false,
  }) async =>
      asMap(await _post('/exercises/start', <String, dynamic>{
        ..._subject(department, course, subject),
        ...?choice?.toJson(),
        'types': types,
        if (choice == null) 'arguments': arguments,
        'count': count,
        if (timeLimitSeconds != null && timeLimitSeconds > 0) 'time_limit_seconds': timeLimitSeconds,
        if (quiz) 'quiz': true,
      }, 'Non è stato possibile avviare gli esercizi.'));

  /// Consegna di un tentativo (anche di un'assegnazione mista domande + esercizi).
  Future<Map<String, dynamic>> complete({
    required int attemptId,
    required List<Map<String, dynamic>> answers,
    required int elapsedSeconds,
    String completionReason = 'completed',
  }) async =>
      asMap(await _post('/quiz-attempts/$attemptId/complete', <String, dynamic>{
        'answers': answers,
        'elapsed_seconds': elapsedSeconds,
        'completion_reason': completionReason,
      }, 'Consegna non riuscita.'));

  Future<Map<String, dynamic>> attempt(int attemptId) async => asMap(_decode(
      await http.get(uri('/quiz-attempts/$attemptId'), headers: _headers), 'Tentativo non disponibile.'));

  // --------------------------------------------------------------- flashcard
  Future<Map<String, dynamic>> flashcardDeck({
    required String department,
    required String course,
    required String subject,
    List<String> arguments = const <String>[],
    int limit = 20,
  }) async =>
      asMap(await _post('/exercises/flashcards/deck', <String, dynamic>{
        ..._subject(department, course, subject),
        'arguments': arguments,
        'limit': limit,
      }, 'Schede non disponibili.'));

  Future<Map<String, dynamic>> flashcardReview({
    required String department,
    required String course,
    required String subject,
    required String cardId,
    required int grade,
  }) async =>
      asMap(await _post('/exercises/flashcards/review', <String, dynamic>{
        ..._subject(department, course, subject),
        'card_id': cardId,
        'grade': grade,
      }, 'Voto non salvato.'));

  // --------------------------------------------------------------- allegati
  /// Gli allegati sono serviti dal server leggendo il percorso dalla banca:
  /// l'app conosce solo l'id dell'allegato.
  Uri exerciseAttachmentUri(String department, String course, String subject, String itemId, String attachmentId) {
    final Uri base = Uri.parse(_base);
    return base.replace(pathSegments: <String>[
      ...base.pathSegments.where((String s) => s.isNotEmpty),
      'exercises', 'attachments', department, course, subject, itemId, attachmentId,
    ]);
  }

  Uri questionAttachmentUri(String department, String course, String subject, String questionId, String attachmentId) {
    final Uri base = Uri.parse(_base);
    return base.replace(pathSegments: <String>[
      ...base.pathSegments.where((String s) => s.isNotEmpty),
      'question-attachments', 'content', department, course, subject, questionId, attachmentId,
    ]);
  }

  // --------------------------------------------------------------- docente / admin
  Future<List<Map<String, dynamic>>> manageableSubjects({String? query}) async => asMapList(_decode(
      await http.get(uri('/exercises/subjects', <String, String>{if (query != null && query.trim().isNotEmpty) 'q': query}),
          headers: _headers),
      'Materie non disponibili.'));

  Future<Map<String, dynamic>> manageList(String department, String course, String subject,
          {String? type, String? argument, String? query}) async =>
      asMap(_decode(
          await http.get(
              uri('/exercises/manage', <String, String>{
                'department': department,
                'course': course,
                'subject': subject,
                if (type != null) 'type': type,
                if (argument != null) 'argument': argument,
                if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
              }),
              headers: _headers),
          'Banca esercizi non disponibile.'));

  Future<Map<String, dynamic>> manageGet(String department, String course, String subject, String id) async =>
      asMap(_decode(
          await http.get(_manageUri(department, course, subject, id), headers: _headers), 'Esercizio non disponibile.'));

  Uri _manageUri(String department, String course, String subject, String id, [String? action]) {
    final Uri base = Uri.parse(_base);
    return base.replace(pathSegments: <String>[
      ...base.pathSegments.where((String s) => s.isNotEmpty),
      'exercises', 'manage', department, course, subject, id,
      if (action != null) action,
    ]);
  }

  Future<Map<String, dynamic>> manageCreate(String department, String course, String subject,
          Map<String, dynamic> exercise) async =>
      asMap(await _post('/exercises/manage', <String, dynamic>{
        ..._subject(department, course, subject),
        'exercise': exercise,
      }, 'Esercizio non salvato.'));

  Future<Map<String, dynamic>> manageUpdate(String department, String course, String subject, String id,
          Map<String, dynamic> exercise) async =>
      asMap(_decode(
          await http.put(_manageUri(department, course, subject, id), headers: _headers, body: jsonEncode(exercise)),
          'Esercizio non salvato.'));

  Future<Map<String, dynamic>> manageStatus(String department, String course, String subject, String id,
          {bool? isActive, bool? isHidden}) async =>
      asMap(_decode(
          await http.post(_manageUri(department, course, subject, id, 'status'),
              headers: _headers,
              body: jsonEncode(<String, dynamic>{
                if (isActive != null) 'is_active': isActive,
                if (isHidden != null) 'is_hidden': isHidden,
              })),
          'Stato non aggiornato.'));

  Future<void> manageDelete(String department, String course, String subject, String id) async =>
      _decode(await http.delete(_manageUri(department, course, subject, id), headers: _headers),
          'Esercizio non eliminato.');

  Future<Map<String, dynamic>> managePreview(String department, String course, String subject,
          Map<String, dynamic> exercise) async =>
      asMap(await _post('/exercises/manage/preview', <String, dynamic>{
        ..._subject(department, course, subject),
        'exercise': exercise,
      }, 'Anteprima non disponibile.'));

  Future<Map<String, dynamic>> manageImport(String department, String course, String subject, dynamic payload,
          {bool dryRun = false}) async =>
      asMap(await _post('/exercises/manage/import', <String, dynamic>{
        ..._subject(department, course, subject),
        'payload': payload,
        'dry_run': dryRun,
      }, 'Importazione non riuscita.'));

  Future<List<Map<String, dynamic>>> generators() async =>
      asMapList(_decode(await http.get(uri('/exercises/generators'), headers: _headers), 'Generatori non disponibili.'));

  // --------------------------------------------------------------- aree didattiche (v24)
  /// Dipartimenti → area → tipi di esercizio consigliati (configurazione dell'admin).
  Future<Map<String, dynamic>> areas() async =>
      asMap(_decode(await http.get(uri('/exercises/areas'), headers: _headers), 'Aree non disponibili.'));

  /// Area di un corso: {id, label, types, examples, matched, department}.
  Future<Map<String, dynamic>> areaFor(String department, String course, {String? subject}) async =>
      asMap(_decode(
          await http.get(
              uri('/exercises/areas/resolve', <String, String>{
                'department': department,
                'course': course,
                if (subject != null && subject.trim().isNotEmpty) 'subject': subject.trim(),
              }),
              headers: _headers),
          'Area non disponibile.'));

  Future<Map<String, dynamic>> saveAreas(Map<String, dynamic> config) async =>
      asMap(_decode(await http.put(uri('/exercises/areas'), headers: _headers, body: jsonEncode(config)),
          'Aree non salvate.'));

  Future<Map<String, dynamic>> resetAreas() async =>
      asMap(_decode(await http.delete(uri('/exercises/areas'), headers: _headers), 'Aree non ripristinate.'));
}

String cleanError(Object error, [String fallback = 'Qualcosa non ha funzionato.']) {
  final String text = error.toString().replaceFirst('Exception: ', '').trim();
  return text.isEmpty ? fallback : text;
}
