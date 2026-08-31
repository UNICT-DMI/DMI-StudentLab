import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/device_public_key.dart';
import 'auth_session.dart';

class PublicKeyApiService {
  static const String _baseUrl = 'https://dmi-student-lab.vercel.app';
  static const String _host = 'dmi-student-lab.vercel.app';

  static const int maxDeviceLabelLength = 100;

  final AuthSession _session;
  final http.Client _client;

  PublicKeyApiService({
    AuthSession? session,
    http.Client? client,
  })  : _session = session ?? AuthSession.instance,
        _client = client ?? http.Client();

  Future<DevicePublicKey> registerDeviceKey({
    required String deviceId,
    required String publicKey,
    String algo = 'x25519',
    String deviceLabel = '',
  }) async {
    _requireAuthenticated();

    final String normalizedLabel = deviceLabel.trim();

    if (normalizedLabel.length > maxDeviceLabelLength) {
      throw ArgumentError('Nome del dispositivo troppo lungo.');
    }

    final http.Response response = await _client.post(
      _uri('/me/public-keys'),
      headers: _headers,
      body: jsonEncode({
        'device_id': _requireDeviceId(deviceId),
        'algo': algo.trim().toLowerCase(),
        'public_key': publicKey.trim(),
        'device_label': normalizedLabel.isEmpty ? null : normalizedLabel,
      }),
    );

    return DevicePublicKey.fromJson(
      _decodeMap(response, 'Impossibile registrare il dispositivo.'),
    );
  }

  Future<DevicePublicKeyListResult> getOwnDeviceKeys() async {
    _requireAuthenticated();

    final http.Response response = await _client.get(
      _uri('/me/public-keys'),
      headers: _headers,
    );

    return DevicePublicKeyListResult.fromJson(
      _decodeMap(response, 'Impossibile caricare i dispositivi.'),
    );
  }

  Future<void> revokeDeviceKey(String deviceId) async {
    _requireAuthenticated();

    final http.Response response = await _client.delete(
      _uri('/me/public-keys/${_requireDeviceId(deviceId)}'),
      headers: _headers,
    );

    _decodeMap(response, 'Impossibile revocare il dispositivo.');
  }

  Future<DevicePublicKeyListResult> getUserDeviceKeys(int userId) async {
    _requireAuthenticated();

    if (userId <= 0) {
      throw ArgumentError('Identificativo utente non valido.');
    }

    final http.Response response = await _client.get(
      _uri('/users/$userId/public-keys'),
      headers: _headers,
    );

    return DevicePublicKeyListResult.fromJson(
      _decodeMap(response, 'Impossibile caricare le chiavi del destinatario.'),
    );
  }

  Future<ComplianceKey> getComplianceKey() async {
    _requireAuthenticated();

    final http.Response response = await _client.get(
      _uri('/crypto/compliance-key'),
      headers: _headers,
    );

    return ComplianceKey.fromJson(
      _decodeMap(response, 'Impossibile caricare la chiave di conformità.'),
    );
  }

  Uri _uri(String path) {
    final Uri base = Uri.parse(_baseUrl);
    final String normalizedPath = path.startsWith('/') ? path : '/$path';

    final Uri result = base.replace(
      path: normalizedPath,
    );

    if (result.scheme != 'https' || result.host != _host) {
      throw StateError('Endpoint backend non autorizzato.');
    }

    return result;
  }

  Map<String, String> get _headers {
    final String? token = _session.accessToken;

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decodeMap(
    http.Response response,
    String fallbackMessage,
  ) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.trim().isEmpty) {
        return <String, dynamic>{};
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }

      throw Exception(fallbackMessage);
    }

    String detail = '';
    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map) {
        detail = decoded['detail']?.toString().trim() ?? '';
      }
    } catch (_) {}

    throw Exception(
      detail.isNotEmpty
          ? '${response.statusCode}: $detail'
          : '${response.statusCode}: $fallbackMessage',
    );
  }

  void _requireAuthenticated() {
    if (!_session.isAuthenticated || _session.currentUserId == null) {
      throw StateError('Utente non autenticato.');
    }
  }

  String _requireDeviceId(String value) {
    final String normalized = value.trim();

    if (!RegExp(r'^[A-Za-z0-9._-]{8,64}$').hasMatch(normalized)) {
      throw ArgumentError('Identificativo del dispositivo non valido.');
    }

    return normalized;
  }
}
