import 'dart:convert';
import 'dart:typed_data';

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

  /// Pubblica un file caricato dall'admin: destinazione 'dispense' o
  /// 'drive_only', percorso, destinatari ed eventuale richiesta da chiudere.
  Future<Map<String, dynamic>> publishAdminUpload({
    required int requestId,
    required String destination,
    required List<String> pathSegments,
    required String audienceType,
    int? audienceId,
    String? title,
    int? answerRequestId,
    String? answerMessage,
    bool allowDriveDuplicate = false,
  }) async {
    final response = await http.post(
      _uri('/admin/material-storage/uploads/$requestId/publish'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{
        'destination': destination,
        'path_segments': pathSegments,
        'audience_type': audienceType,
        if (audienceId != null) 'audience_id': audienceId,
        if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
        if (answerRequestId != null) 'answer_request_id': answerRequestId,
        if (answerMessage != null && answerMessage.trim().isNotEmpty) 'answer_message': answerMessage.trim(),
        'allow_drive_duplicate': allowDriveDuplicate,
      }),
    );
    return _map(response, 'Pubblicazione non riuscita');
  }

  Future<Map<String, dynamic>> getOverview() async {
    final http.Response response = await http.get(
      _uri('/admin/material-storage/overview'),
      headers: _headers,
    );
    return _map(response, 'Errore caricamento storage');
  }

  Future<Map<String, dynamic>> getDriveStatus() async {
    final response = await http.get(_uri('/admin/material-storage/drive/status'),
      headers: _headers);
    return _map(response, 'Impossibile leggere lo stato di Google Drive');
  }

  Future<Map<String, dynamic>> getDriveTree([String? folderId, String? pageToken]) async {
    final response = await http.get(_uri('/admin/material-storage/drive/tree',
      query: {if (folderId != null) 'folder_id': folderId,
        if (pageToken != null) 'page_token': pageToken}), headers: _headers);
    return _map(response, 'Impossibile leggere i file della cartella Drive');
  }

  Future<List<Map<String, dynamic>>> getDriveImportOptions() async {
    final response = await http.get(_uri('/admin/material-storage/drive/import-options'),
      headers: _headers);
    return _list(response, 'Impossibile caricare le materie del catalogo');
  }

  Future<Map<String, dynamic>> getCatalogSnapshot() async {
    final response = await http.get(_uri('/admin/material-storage/catalog/draft'),
      headers: _headers);
    return _map(response, 'Impossibile leggere la bozza');
  }

  Future<Map<String, dynamic>> stageCatalogFolder({required int subjectId,
      required List<String> pathSegments}) async => _map(await http.post(
        _uri('/admin/material-storage/catalog/folders'), headers: _headers,
        body: jsonEncode({'subject_id': subjectId, 'path_segments': pathSegments})),
      'Impossibile salvare la cartella nella bozza');

  Future<Map<String, dynamic>> stageDriveImport({required String fileId,
      required int subjectId, required List<String> pathSegments,
      required String audienceType, int? audienceId,
      bool allowDuplicate = false}) async => _map(await http.post(
        _uri('/admin/material-storage/catalog/import'), headers: _headers,
        body: jsonEncode({'file_id': fileId, 'subject_id': subjectId,
          'path_segments': pathSegments, 'audience_type': audienceType,
          'audience_id': audienceId, 'allow_duplicate': allowDuplicate})),
      'Impossibile aggiungere il file alla bozza');

  Future<Map<String, dynamic>> stageCatalogFile({required int materialId,
      required int subjectId, required List<String> pathSegments,
      required String visibilityState, required String audienceType,
      int? audienceId}) async {
    final response = await http.put(_uri('/admin/material-storage/catalog/draft/$materialId'),
      headers: _headers, body: jsonEncode({
        'subject_id': subjectId, 'path_segments': pathSegments,
        'visibility_state': visibilityState, 'audience_type': audienceType,
        'audience_id': audienceId,
      }));
    return _map(response, 'Impossibile salvare la bozza');
  }

  Future<Map<String, dynamic>> discardCatalogDraft() async => _map(
      await http.delete(_uri('/admin/material-storage/catalog/draft'), headers: _headers),
      'Impossibile scartare la bozza');

  Future<Map<String, dynamic>> publishCatalogDraft() async => _map(
      await http.post(_uri('/admin/material-storage/catalog/publish'), headers: _headers),
      'Impossibile pubblicare la struttura');

  Future<Map<String, dynamic>> previewCatalog({int? userId}) async => _map(
      await http.get(_uri('/admin/material-storage/catalog/preview', query: {
        if (userId != null) 'user_id': '$userId',
      }), headers: _headers), 'Impossibile caricare l’anteprima');

  Future<Map<String, dynamic>> importDriveFile({required String fileId,
      required int subjectId, required String audienceType, int? audienceId}) async {
    final response = await http.post(_uri('/admin/material-storage/drive/import'),
      headers: _headers, body: jsonEncode({'file_id': fileId,
        'subject_id': subjectId, 'audience_type': audienceType,
        'audience_id': audienceId}));
    return _map(response, 'Impossibile registrare il file nel catalogo');
  }

  Future<Map<String, dynamic>> previewPublicDrive(int materialId,
      {List<String>? path}) async {
    final response = await http.post(
      _uri('/admin/material-storage/public/$materialId/drive-preview'),
      headers: _headers, body: jsonEncode({'path': path}));
    return _map(response, 'Impossibile controllare le cartelle Drive');
  }

  Future<Uint8List> downloadDriveFilePreview(String fileId) async {
    final response = await http.get(_uri(
      '/admin/material-storage/drive/file/${Uri.encodeComponent(fileId)}/preview'),
      headers: _headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Anteprima Drive non disponibile');
    }
    return response.bodyBytes;
  }

  Future<Uint8List> downloadPublicMaterialPreview(int materialId) async {
    final response = await http.get(_uri('/admin/public_materials/$materialId/file'),
      headers: _headers);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('File proposto non disponibile');
    }
    return response.bodyBytes;
  }

  Future<Map<String, dynamic>> copyPublicToDrive(int materialId,
      {List<String>? path, bool allowDuplicate = false}) async {
    final response = await http.post(
      _uri('/admin/material-storage/public/$materialId/drive-copy'),
      headers: _headers,
      body: jsonEncode({'path': path, 'allow_duplicate': allowDuplicate}));
    return _map(response, 'Impossibile copiare il materiale su Google Drive');
  }

  Future<Map<String, dynamic>> deletePublicDriveCopy(int materialId) async {
    final response = await http.delete(
      _uri('/admin/material-storage/public/$materialId/drive-copy',
        query: const {'confirmation': 'ELIMINA'}), headers: _headers);
    return _map(response, 'Impossibile eliminare la copia Drive');
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

  Future<Map<String, dynamic>> setPublicVisibility({
    required int materialId,
    required String state,
  }) async {
    final response = await http.patch(
      _uri('/admin/material-storage/public/$materialId/visibility'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{'state': state}),
    );
    return _map(response, 'Impossibile cambiare la visibilità');
  }

  Future<Map<String, dynamic>> setPublicAudience({
    required int materialId, required String audienceType, int? audienceId,
  }) async {
    final response = await http.patch(
      _uri('/admin/material-storage/public/$materialId/audience'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{
        'audience_type': audienceType,
        'audience_id': audienceId,
      }),
    );
    return _map(response, 'Impossibile modificare i destinatari');
  }

  Future<Map<String, dynamic>> placePublicFile({
    required int materialId,
    required int subjectId,
    required List<String> pathSegments,
  }) async {
    final response = await http.patch(
      _uri('/admin/material-storage/public/$materialId/placement'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{
        'subject_id': subjectId,
        'path_segments': pathSegments,
      }),
    );
    return _map(response, 'Impossibile modificare il percorso');
  }

  Future<Map<String, dynamic>> movePublicFolder({
    required int sourceSubjectId,
    required List<String> sourcePath,
    required int destinationSubjectId,
    required List<String> destinationPath,
  }) async {
    final response = await http.post(_uri('/admin/material-storage/folders/move'),
      headers: _headers,
      body: jsonEncode(<String, dynamic>{
        'source_subject_id': sourceSubjectId,
        'source_path': sourcePath,
        'destination_subject_id': destinationSubjectId,
        'destination_path': destinationPath,
      }),
    );
    return _map(response, 'Impossibile spostare la cartella');
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

    throw Exception(response.statusCode == 404
        ? '$fallback: endpoint non disponibile (HTTP 404). Aggiorna il backend.'
        : _errorMessage(decoded, fallback));
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
