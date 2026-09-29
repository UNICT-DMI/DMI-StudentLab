import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../services/auth_session.dart';

/// Chiamate al backend del calendario accademico.
class CalendarApiService {
  CalendarApiService() : _base = ApiService().baseUrl;

  final String _base;

  bool get isAuthenticated => AuthSession.instance.isAuthenticated;

  Map<String, String> get _auth {
    final String? token = AuthSession.instance.accessToken;
    return <String, String>{
      if (token != null && token.trim().isNotEmpty) 'Authorization': 'Bearer ${token.trim()}',
      'Accept': 'application/json',
    };
  }

  Map<String, String> get _json => {..._auth, 'Content-Type': 'application/json'};

  Uri uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(_base);
    final basePath = base.path.endsWith('/') ? base.path.substring(0, base.path.length - 1) : base.path;
    return base.replace(path: '$basePath$path', queryParameters: query == null || query.isEmpty ? null : query);
  }

  dynamic _decode(http.Response response, String fallback) {
    final dynamic decoded = response.body.trim().isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes));
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

  List<Map<String, dynamic>> _list(dynamic v) =>
      v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];
  Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : {};

  String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<List<Map<String, dynamic>>> events({
    String? university,
    String? department,
    String? course,
    int? subjectId,
    String? kind,
    String? curriculum,
    bool excludeTimetable = false,
    bool timetableOnly = false,
    DateTime? from,
    DateTime? to,
  }) async =>
      _list(_decode(
          await http.get(
              uri('/calendar/events', {
                if (university != null) 'university': university,
                if (department != null) 'department': department,
                if (course != null) 'course': course,
                if (subjectId != null) 'subject_id': '$subjectId',
                if (kind != null) 'kind': kind,
                if (curriculum != null) 'curriculum': curriculum,
                if (excludeTimetable) 'exclude_timetable': 'true',
                if (timetableOnly) 'timetable_only': 'true',
                if (from != null) 'from': _day(from),
                if (to != null) 'to': _day(to),
              }),
              headers: _auth),
          'Calendario non disponibile.'));

  Future<List<Map<String, dynamic>>> currentPeriods({String? university, String? department, String? course}) async =>
      _list(_decode(
          await http.get(
              uri('/calendar/current-periods', {
                if (university != null) 'university': university,
                if (department != null) 'department': department,
                if (course != null) 'course': course,
              }),
              headers: _auth),
          'Periodi non disponibili.'));

  Future<Map<String, dynamic>> event(int id) async =>
      _map(_decode(await http.get(uri('/calendar/events/$id'), headers: _auth), 'Evento non disponibile.'));

  Uri icsUri(int id) => uri('/calendar/events/$id/ics');

  Future<Map<String, dynamic>> follow(int id, {List<int>? remindDays}) async => _map(_decode(
      await http.post(uri('/calendar/events/$id/follow'),
          headers: _json, body: jsonEncode({if (remindDays != null) 'remind_days': remindDays})),
      'Non è stato possibile seguire l’evento.'));

  Future<void> unfollow(int id) async =>
      _decode(await http.delete(uri('/calendar/events/$id/follow'), headers: _auth), 'Operazione non riuscita.');

  Future<List<Map<String, dynamic>>> followed() async =>
      _list(_decode(await http.get(uri('/calendar/followed'), headers: _auth), 'Eventi seguiti non disponibili.'));

  Future<List<int>> reminderSettings() async {
    final data = _map(_decode(await http.get(uri('/calendar/settings'), headers: _auth), 'Impostazioni non disponibili.'));
    return (data['remind_days'] as List? ?? const [7, 1]).map((e) => int.tryParse('$e') ?? 0).toList();
  }

  Future<List<int>> saveReminderSettings(List<int> days) async {
    final data = _map(_decode(
        await http.put(uri('/calendar/settings'), headers: _json, body: jsonEncode({'remind_days': days})),
        'Impostazioni non salvate.'));
    return (data['remind_days'] as List? ?? const []).map((e) => int.tryParse('$e') ?? 0).toList();
  }

  // Scrittura -------------------------------------------------------------------

  Future<Map<String, dynamic>> manageable() async =>
      _map(_decode(await http.get(uri('/calendar/manageable'), headers: _auth), 'Permessi non disponibili.'));

  Future<Map<String, dynamic>> saveEvent(Map<String, dynamic> body, {int? id}) async {
    final response = id == null
        ? await http.post(uri('/calendar/events'), headers: _json, body: jsonEncode(body))
        : await http.put(uri('/calendar/events/$id'), headers: _json, body: jsonEncode(body));
    return _map(_decode(response, 'Evento non salvato.'));
  }

  Future<void> deleteEvent(int id) async =>
      _decode(await http.delete(uri('/calendar/events/$id'), headers: _auth), 'Evento non eliminato.');

  Future<Map<String, dynamic>> importPreview({
    Uint8List? bytes,
    String? fileName,
    String? url,
    String? university,
    String? department,
    String? course,
    int? defaultYear,
  }) async {
    final request = http.MultipartRequest('POST', uri('/calendar/import/preview'))..headers.addAll(_auth);
    if (bytes != null && fileName != null) {
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
    }
    if (url != null && url.trim().isNotEmpty) request.fields['url'] = url.trim();
    if (university != null) request.fields['university'] = university;
    if (department != null) request.fields['department'] = department;
    if (course != null) request.fields['course'] = course;
    if (defaultYear != null) request.fields['default_year'] = '$defaultYear';
    final response = await http.Response.fromStream(await request.send());
    return _map(_decode(response, 'Non è stato possibile leggere il calendario.'));
  }

  Future<Map<String, dynamic>> importCommit(List<Map<String, dynamic>> events) async => _map(_decode(
      await http.post(uri('/calendar/import/commit'), headers: _json, body: jsonEncode({'events': events})),
      'Importazione non riuscita.'));
}
