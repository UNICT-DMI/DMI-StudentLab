import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../services/auth_session.dart';

/// Chiamate al backend del Dizionario. La lettura funziona anche per gli
/// ospiti; scrittura e revisione richiedono admin o docente della materia.
class DictionaryApiService {
  DictionaryApiService() : _base = ApiService().baseUrl;

  final String _base;

  bool get isAuthenticated => AuthSession.instance.isAuthenticated;

  Map<String, String> get _headers {
    final String? token = AuthSession.instance.accessToken;
    return <String, String>{
      if (token != null && token.trim().isNotEmpty) 'Authorization': 'Bearer ${token.trim()}',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  Uri uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(_base);
    final basePath = base.path.endsWith('/') ? base.path.substring(0, base.path.length - 1) : base.path;
    return base.replace(path: '$basePath$path', queryParameters: query == null || query.isEmpty ? null : query);
  }

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

  // Lettura -----------------------------------------------------------------

  Future<List<Map<String, dynamic>>> subjects() async =>
      _list(_decode(await http.get(uri('/dictionary/subjects'), headers: _headers), 'Dizionario non disponibile.'));

  Future<Map<String, dynamic>> subject(int id, {String? year}) async => _map(_decode(
      await http.get(uri('/dictionary/subjects/$id', {if (year != null) 'year': year}), headers: _headers),
      'Materia non disponibile.'));

  Future<Map<String, dynamic>> entry(int id, {String? year}) async => _map(_decode(
      await http.get(uri('/dictionary/entries/$id', {if (year != null) 'year': year}), headers: _headers),
      'Termine non disponibile.'));

  Future<List<Map<String, dynamic>>> quiz(int entryId, {String? year}) async => _list(_decode(
      await http.get(uri('/dictionary/entries/$entryId/quiz', {if (year != null) 'year': year}), headers: _headers),
      'Domande non disponibili.'));

  Future<List<Map<String, dynamic>>> search(String query, {int? subjectId}) async {
    if (query.trim().length < 2) return const [];
    return _list(_decode(
        await http.get(uri('/dictionary/search', {'q': query.trim(), if (subjectId != null) 'subject_id': '$subjectId'}),
            headers: _headers),
        'Ricerca non disponibile.'));
  }

  /// Indirizzo del PDF di un argomento (si apre nel browser, anche da ospite).
  Uri topicPdfUri(int topicId, String year) => uri('/dictionary/topics/$topicId/pdf', {'year': year});

  // Scrittura ---------------------------------------------------------------

  Future<List<Map<String, dynamic>>> editableSubjects() async => _list(
      _decode(await http.get(uri('/dictionary/editable-subjects'), headers: _headers), 'Materie non disponibili.'));

  /// Importa un dizionario JSON: i termini diventano BOZZE da moderare.
  /// [source] registra il file tra le fonti (nome, impronta, estratto).
  Future<Map<String, dynamic>> importDictionary(Map<String, dynamic> dictionary,
          {int? subjectId, String? academicYear, bool preview = false, Map<String, dynamic>? source}) async =>
      _map(_decode(
          await http.post(uri('/dictionary/import'),
              headers: _headers,
              body: jsonEncode({
                'dictionary': dictionary,
                if (subjectId != null) 'subject_id': subjectId,
                if (academicYear != null) 'academic_year': academicYear,
                'preview': preview,
                if (source != null) 'source': source,
              })),
          'Importazione non riuscita.'));

  // Fonti e moderazione --------------------------------------------------------

  /// Materie che l'utente può moderare (admin: tutte; docente: le sue verificate).
  Future<Map<String, dynamic>> moderationSubjects() async => _map(
      _decode(await http.get(uri('/dictionary/moderation/subjects'), headers: _headers), 'Moderazione non disponibile.'));

  Future<List<Map<String, dynamic>>> sources({int? subjectId, String? status, String? kind, String? query}) async =>
      _list(_decode(
          await http.get(
              uri('/dictionary/sources', {
                if (subjectId != null) 'subject_id': '$subjectId',
                if (status != null) 'status': status,
                if (kind != null) 'kind': kind,
                if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
              }),
              headers: _headers),
          'Fonti non disponibili.'));

  Future<Map<String, dynamic>> source(int id) async =>
      _map(_decode(await http.get(uri('/dictionary/sources/$id'), headers: _headers), 'Fonte non disponibile.'));

  Future<Map<String, dynamic>> createSource(Map<String, dynamic> body) async => _map(_decode(
      await http.post(uri('/dictionary/sources'), headers: _headers, body: jsonEncode(body)), 'Fonte non salvata.'));

  Future<Map<String, dynamic>> updateSource(int id, Map<String, dynamic> body) async => _map(_decode(
      await http.patch(uri('/dictionary/sources/$id'), headers: _headers, body: jsonEncode(body)), 'Fonte non salvata.'));

  Future<void> deleteSource(int id) async =>
      _decode(await http.delete(uri('/dictionary/sources/$id'), headers: _headers), 'Fonte non eliminata.');

  Future<Map<String, dynamic>> drafts({
    int? subjectId,
    String status = 'pending',
    int? sourceId,
    String? kind,
    String? query,
    int limit = 200,
    int offset = 0,
  }) async =>
      _map(_decode(
          await http.get(
              uri('/dictionary/drafts', {
                if (subjectId != null) 'subject_id': '$subjectId',
                'status': status,
                if (sourceId != null) 'source_id': '$sourceId',
                if (kind != null) 'kind': kind,
                if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
                'limit': '$limit',
                'offset': '$offset',
              }),
              headers: _headers),
          'Bozze non disponibili.'));

  Future<Map<String, dynamic>> draft(int id) async =>
      _map(_decode(await http.get(uri('/dictionary/drafts/$id'), headers: _headers), 'Bozza non disponibile.'));

  Future<Map<String, dynamic>> updateDraft(int id, Map<String, dynamic> body) async => _map(_decode(
      await http.put(uri('/dictionary/drafts/$id'), headers: _headers, body: jsonEncode(body)), 'Bozza non salvata.'));

  Future<Map<String, dynamic>> approveDraft(int id, {int? mergeIntoEntryId}) async => _map(_decode(
      await http.post(uri('/dictionary/drafts/$id/approve'),
          headers: _headers, body: jsonEncode({if (mergeIntoEntryId != null) 'merge_into_entry_id': mergeIntoEntryId})),
      'Pubblicazione non riuscita.'));

  Future<Map<String, dynamic>> rejectDraft(int id, {String? note}) async => _map(_decode(
      await http.post(uri('/dictionary/drafts/$id/reject'),
          headers: _headers, body: jsonEncode({if (note != null && note.trim().isNotEmpty) 'note': note.trim()})),
      'Operazione non riuscita.'));

  Future<Map<String, dynamic>> bulkDrafts(List<int> ids, String action, {String? note}) async => _map(_decode(
      await http.post(uri('/dictionary/drafts/bulk'),
          headers: _headers,
          body: jsonEncode({'ids': ids, 'action': action, if (note != null && note.trim().isNotEmpty) 'note': note.trim()})),
      'Operazione non riuscita.'));

  Future<List<Map<String, dynamic>>> questionBank(int subjectId, String query) async => _list(_decode(
      await http.get(uri('/dictionary/moderation/question-bank', {'subject_id': '$subjectId', 'q': query}),
          headers: _headers),
      'Banca domande non disponibile.'));

  Future<Map<String, dynamic>> saveEntry({int? entryId, required int subjectId, required Map<String, dynamic> body}) async {
    final response = entryId == null
        ? await http.post(uri('/dictionary/subjects/$subjectId/entries'), headers: _headers, body: jsonEncode(body))
        : await http.put(uri('/dictionary/entries/$entryId'), headers: _headers, body: jsonEncode(body));
    return _map(_decode(response, 'Termine non salvato.'));
  }

  Future<void> deleteEntry(int entryId) async =>
      _decode(await http.delete(uri('/dictionary/entries/$entryId'), headers: _headers), 'Termine non eliminato.');

  // Revisione (admin) ----------------------------------------------------------

  Future<Map<String, dynamic>> reviewQueue({int? subjectId, String state = 'to_review', String? year}) async =>
      _map(_decode(
          await http.get(
              uri('/dictionary/review', {
                if (subjectId != null) 'subject_id': '$subjectId',
                'state': state,
                if (year != null) 'year': year,
              }),
              headers: _headers),
          'Revisione non disponibile.'));

  Future<Map<String, dynamic>> review(int versionId, String action, {int? teacherUserId}) async => _map(_decode(
      await http.post(uri('/dictionary/versions/$versionId/review'),
          headers: _headers,
          body: jsonEncode({'action': action, if (teacherUserId != null) 'teacher_user_id': teacherUserId})),
      'Operazione non riuscita.'));

  Future<List<Map<String, dynamic>>> subjectTeachers(int subjectId) async => _list(_decode(
      await http.get(uri('/dictionary/subjects/$subjectId/teachers'), headers: _headers), 'Docenti non disponibili.'));

  Future<Map<String, dynamic>> rollover(int subjectId, String fromYear, String toYear) async => _map(_decode(
      await http.post(uri('/dictionary/subjects/$subjectId/rollover'),
          headers: _headers, body: jsonEncode({'from_year': fromYear, 'to_year': toYear})),
      'Copia non riuscita.'));
}

/// Termini salvati e visti di recente: sul dispositivo, anche per gli ospiti.
class DictionaryLocalStore {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _savedKey = 'studentlab.dictionary.saved';
  static const String _recentKey = 'studentlab.dictionary.recent';

  static Future<List<Map<String, dynamic>>> _read(String key) async {
    try {
      final raw = await _storage.read(key: key);
      final value = raw == null ? null : jsonDecode(raw);
      return value is List ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> _write(String key, List<Map<String, dynamic>> items) async {
    try {
      await _storage.write(key: key, value: jsonEncode(items));
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> saved() => _read(_savedKey);
  static Future<List<Map<String, dynamic>>> recent() => _read(_recentKey);

  static Future<bool> isSaved(int entryId) async => (await saved()).any((e) => e['id'] == entryId);

  static Future<bool> toggleSaved(Map<String, dynamic> entry) async {
    final items = await saved();
    final exists = items.any((e) => e['id'] == entry['id']);
    if (exists) {
      items.removeWhere((e) => e['id'] == entry['id']);
    } else {
      items.insert(0, entry);
    }
    await _write(_savedKey, items.take(300).toList());
    return !exists;
  }

  static Future<void> addRecent(Map<String, dynamic> entry) async {
    final items = await recent();
    items.removeWhere((e) => e['id'] == entry['id']);
    items.insert(0, entry);
    await _write(_recentKey, items.take(12).toList());
  }
}
