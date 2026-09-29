import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../services/auth_session.dart';
import '../../services/device_key_service.dart';
import '../repositories/study_plan_local_repository.dart';

class StudyPlanSyncService {
  static const String _baseUrl = 'https://dmi-student-lab.vercel.app';
  static const String _host = 'dmi-student-lab.vercel.app';

  final AuthSession _session;
  final DeviceKeyService _deviceKeys;
  final StudyPlanLocalRepository _repository;

  StudyPlanSyncService({
    AuthSession? session,
    DeviceKeyService? deviceKeys,
    StudyPlanLocalRepository? repository,
  }) : _session = session ?? AuthSession.instance,
       _deviceKeys = deviceKeys ?? DeviceKeyService(),
       _repository = repository ?? StudyPlanLocalRepository();

  Future<void> refreshGuestPlan() async {
    final String deviceId = await _deviceKeys.getDeviceId();
    await _repository.refreshGuestFromQuizAttempts(deviceId);
  }

  Future<void> onAuthenticated(int userId) async {
    final String deviceId = await _deviceKeys.getDeviceId();
    await _repository.refreshGuestFromQuizAttempts(deviceId);
    await _claimPendingGuest(userId);
    await refreshRemote(userId);
  }

  /// Chiamato subito dopo la conclusione di un quiz.
  /// Guest: rilegge i tentativi SQLite.
  /// Account: forza il bootstrap dal server e aggiorna SQLite locale.
  Future<void> refreshAfterQuizCompletion() async {
    if (_session.isGuest) {
      await refreshGuestPlan();
      return;
    }

    final int? userId = _session.currentUserId;
    if (userId == null || !_session.isAuthenticated) {
      return;
    }

    await refreshRemote(userId);
  }

  Future<void> refreshRemote(int userId) async {
    if (!_session.isAuthenticated || _session.currentUserId != userId) {
      return;
    }

    final http.Response response = await http.get(
      _uri('/study-plan/bootstrap'),
      headers: _headers,
    );

    final Map<String, dynamic> plan = _decodeMap(response);
    await _repository.mergeBootstrap(userId, plan);
  }

  Future<void> _claimPendingGuest(int userId) async {
    final List<Map<String, dynamic>> pending = await _repository
        .pendingGuestSyncPayload(userId);

    for (final Map<String, dynamic> source in pending) {
      try {
        final http.Response response = await http.post(
          _uri('/study-plan/sync'),
          headers: <String, String>{
            ..._headers,
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, dynamic>{
            'session_uuid': source['session_uuid'],
            'device_id': source['device_id'],
            'device_label': source['device_label'],
            'source_type': 'guest',
            'contributions': source['contributions'],
          }),
        );

        _decodeMap(response);

        await _repository.markGuestClaimed(
          source['source_key'].toString(),
          userId,
        );
      } catch (_) {
        // Il login non deve fallire se il Ripasso non è temporaneamente
        // sincronizzabile. Il contributo resta pending e verrà ritentato.
      }
    }
  }

  Future<Map<String, dynamic>> setRemoteSessionEnabled(
    String sessionUuid,
    bool enabled,
  ) async {
    final http.Response response = await http.patch(
      _uri(
        '/study-plan/sessions/${Uri.encodeComponent(sessionUuid)}/association',
      ),
      headers: <String, String>{
        ..._headers,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{'contribution_enabled': enabled}),
    );

    final Map<String, dynamic> plan = _decodeMap(response);
    final int? userId = _session.currentUserId;

    if (userId != null) {
      await _repository.mergeBootstrap(userId, plan);
    }

    return plan;
  }

  Uri _uri(String path) {
    final Uri base = Uri.parse(_baseUrl);
    final String normalizedPath = path.startsWith('/') ? path : '/$path';
    final Uri result = base.replace(path: normalizedPath);

    if (result.scheme != 'https' || result.host != _host) {
      throw StateError('Endpoint StudentLab non autorizzato.');
    }

    return result;
  }

  Map<String, String> get _headers {
    final String? token = _session.accessToken?.trim();

    if (token == null || token.isEmpty) {
      throw StateError('Sessione StudentLab non disponibile.');
    }

    return <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    dynamic decoded;

    try {
      decoded = response.body.trim().isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    final String detail = decoded is Map
        ? decoded['detail']?.toString().trim() ?? ''
        : '';

    if (response.statusCode == 401) {
      throw StateError(
        'La sessione non è più valida. Accedi nuovamente a StudentLab.',
      );
    }

    if (response.statusCode >= 500) {
      throw Exception(
        'Il Ripasso non è temporaneamente sincronizzabile. I dati locali restano disponibili.',
      );
    }

    throw Exception(
      detail.isEmpty
          ? 'Non è stato possibile sincronizzare il Ripasso.'
          : detail,
    );
  }
}
