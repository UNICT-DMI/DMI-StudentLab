import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../services/auth_session.dart';

class AdminMaterialStorageApiService {
  static const String _baseUrl =
      'https://dmi-student-lab.vercel.app';

  Map<String, String> get _headers {
    final String? token =
        AuthSession.instance.accessToken;

    if (token == null || token.trim().isEmpty) {
      throw StateError(
        'Sessione amministrativa non disponibile.',
      );
    }

    return <String, String>{
      'Authorization': 'Bearer ${token.trim()}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Uri _uri(
    String path, {
    Map<String, String>? query,
  }) {
    return Uri.parse('$_baseUrl$path').replace(
      queryParameters:
          query == null || query.isEmpty
              ? null
              : query,
    );
  }

  Future<Map<String, dynamic>> getOverview() async {
    final http.Response response = await http.get(
      _uri('/admin/material-storage/overview'),
      headers: _headers,
    );
    return _map(response, 'Errore caricamento storage');
  }

  Future<List<Map<String, dynamic>>> getItems({
    String? source,
    String? status,
  }) async {
    final Map<String, String> query = <String, String>{};

    if (source != null && source.trim().isNotEmpty) {
      query['source'] = source.trim();
    }

    if (status != null && status.trim().isNotEmpty) {
      query['status'] = status.trim();
    }

    final http.Response response = await http.get(
      _uri(
        '/admin/material-storage/items',
        query: query,
      ),
      headers: _headers,
    );

    return _list(response, 'Errore caricamento materiali');
  }

  Future<Map<String, dynamic>> rename({
    required String source,
    required int materialId,
    required String displayName,
  }) async {
    final http.Response response = await http.patch(
      _uri(
        '/admin/material-storage/'
        '$source/$materialId/display-name',
      ),
      headers: _headers,
      body: jsonEncode(
        <String, dynamic>{
          'display_name': displayName.trim(),
        },
      ),
    );

    return _map(response, 'Errore modifica nome');
  }

  Future<Map<String, dynamic>> retire({
    required String source,
    required int materialId,
    required String reason,
  }) async {
    final http.Response response = await http.post(
      _uri(
        '/admin/material-storage/'
        '$source/$materialId/retire',
      ),
      headers: _headers,
      body: jsonEncode(
        <String, dynamic>{
          'reason': reason.trim(),
        },
      ),
    );

    return _map(response, 'Errore ritiro materiale');
  }

  Future<Map<String, dynamic>> deleteBlob({
    required String source,
    required int materialId,
  }) async {
    final http.Response response = await http.post(
      _uri(
        '/admin/material-storage/'
        '$source/$materialId/delete-blob',
      ),
      headers: _headers,
      body: jsonEncode(
        <String, dynamic>{
          'confirmation': 'ELIMINA',
        },
      ),
    );

    return _map(response, 'Errore eliminazione file');
  }

  Future<Map<String, dynamic>> getCleanupDryRun() async {
    final http.Response response = await http.get(
      _uri('/admin/material-storage/cleanup/dry-run'),
      headers: _headers,
    );
    return _map(response, 'Errore analisi pulizia');
  }

  Future<Map<String, dynamic>> executeCleanup({
    bool rejectedPublications = true,
    bool removedMaterials = true,
    bool orphanBlobs = false,
  }) async {
    final http.Response response = await http.post(
      _uri('/admin/material-storage/cleanup/execute'),
      headers: _headers,
      body: jsonEncode(
        <String, dynamic>{
          'confirmation': 'ELIMINA',
          'rejected_publications': rejectedPublications,
          'removed_materials': removedMaterials,
          'orphan_blobs': orphanBlobs,
        },
      ),
    );

    return _map(response, 'Errore pulizia storage');
  }

  Map<String, dynamic> _map(
    http.Response response,
    String fallback,
  ) {
    final dynamic decoded =
        response.body.trim().isEmpty
            ? <String, dynamic>{}
            : jsonDecode(response.body);

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }

    throw Exception(_errorMessage(decoded, fallback));
  }

  List<Map<String, dynamic>> _list(
    http.Response response,
    String fallback,
  ) {
    final dynamic decoded =
        response.body.trim().isEmpty
            ? <dynamic>[]
            : jsonDecode(response.body);

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        decoded is List) {
      return decoded
          .whereType<Map>()
          .map(
            (Map<dynamic, dynamic> value) =>
                Map<String, dynamic>.from(value),
          )
          .toList();
    }

    throw Exception(_errorMessage(decoded, fallback));
  }

  String _errorMessage(
    dynamic decoded,
    String fallback,
  ) {
    if (decoded is Map) {
      final String detail =
          decoded['detail']?.toString().trim() ?? '';

      if (detail.isNotEmpty) {
        return detail;
      }
    }

    return fallback;
  }
}