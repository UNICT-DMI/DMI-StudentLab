import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../services/auth_session.dart';

import '../models/developer_models.dart';
import '../services/developer_api_mapper.dart';

class DeveloperApiRepository {
  static const String _baseUrl =
      'https://dmi-student-lab.vercel.app';

  const DeveloperApiRepository();

  Uri _uri(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    final Uri base = Uri.parse(_baseUrl);

    return base.replace(
      path: path.startsWith('/')
          ? path
          : '/$path',
      queryParameters: queryParameters,
    );
  }

  Map<String, String> get _headers {
    final String? token =
        AuthSession.instance.accessToken;

    if (token == null ||
        token.trim().isEmpty) {
      throw Exception(
        'Sessione Developer non autenticata.',
      );
    }

    return {
      'Accept': 'application/json',
      'Authorization':
          'Bearer ${token.trim()}',
    };
  }

  Future<dynamic> _get(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final http.Response response =
        await http.get(
      _uri(
        path,
        queryParameters: queryParameters,
      ),
      headers: _headers,
    );

    dynamic decoded;

    if (response.body.trim().isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return decoded;
    }

    String message =
        'Errore Developer & System.';

    if (decoded is Map) {
      final dynamic detail =
          decoded['detail'] ??
              decoded['error'];

      if (detail is String &&
          detail.trim().isNotEmpty) {
        message = detail.trim();
      }
    }

    throw DeveloperApiException(
      statusCode: response.statusCode,
      message: message,
    );
  }

  Future<DeveloperAccessResult>
      getAccess() async {
    final dynamic data =
        await _get('/developer/access');

    final Map<String, dynamic> map =
        _asMap(
      data,
      'Risposta accesso Developer non valida.',
    );

    return DeveloperAccessResult(
      authorized:
          map['authorized'] == true,
      role: map['role']?.toString(),
    );
  }

  Future<bool> canAccess() async {
    try {
      final DeveloperAccessResult result =
          await getAccess();

      return result.authorized;
    } on DeveloperApiException catch (
      error
    ) {
      if (error.statusCode == 401 ||
          error.statusCode == 403) {
        return false;
      }

      rethrow;
    }
  }

  Future<DeveloperRepositoryStatus>
      getStatus() async {
    final Map<String, dynamic> data =
        _asMap(
      await _get('/developer/status'),
      'Stato repository non valido.',
    );

    return DeveloperApiMapper.status(
      data,
    );
  }

  Future<DeveloperTreeNode>
      getTree() async {
    final Map<String, dynamic> data =
        _asMap(
      await _get('/developer/tree'),
      'Albero repository non valido.',
    );

    return DeveloperApiMapper.treeNode(
      data,
    );
  }

  Future<List<DeveloperFileDoc>>
      getFiles() async {
    final List<Map<String, dynamic>>
        data = _asMapList(
      await _get('/developer/files'),
      'Elenco file Developer non valido.',
    );

    return data
        .map(
          DeveloperApiMapper.file,
        )
        .toList();
  }

  Future<DeveloperFileDoc> getFile(
    String path,
  ) async {
    final Map<String, dynamic> data =
        _asMap(
      await _get(
        '/developer/file',
        queryParameters: {
          'path': path,
        },
      ),
      'Scheda file Developer non valida.',
    );

    return DeveloperApiMapper.file(
      data,
    );
  }

  Future<List<DeveloperSearchResult>>
      search(
    String query, {
    int limit = 30,
  }) async {
    final String normalized =
        query.trim();

    if (normalized.length < 2) {
      return const [];
    }

    final List<Map<String, dynamic>>
        data = _asMapList(
      await _get(
        '/developer/search',
        queryParameters: {
          'q': normalized,
          'limit': limit.toString(),
        },
      ),
      'Risultati ricerca Developer non validi.',
    );

    return data
        .map(
          DeveloperApiMapper.searchResult,
        )
        .toList();
  }

  Future<List<DeveloperFlowDoc>>
      getFlows() async {
    final List<Map<String, dynamic>>
        data = _asMapList(
      await _get('/developer/flows'),
      'Elenco flow Developer non valido.',
    );

    return data
        .map(
          DeveloperApiMapper.flow,
        )
        .toList();
  }

  Future<DeveloperFlowDoc> getFlow(
    String flowId,
  ) async {
    final String normalized =
        flowId.trim();

    if (normalized.isEmpty) {
      throw Exception(
        'Identificativo flow non valido.',
      );
    }

    final Map<String, dynamic> data =
        _asMap(
      await _get(
        '/developer/flow/'
        '${Uri.encodeComponent(normalized)}',
      ),
      'Flow Developer non valido.',
    );

    return DeveloperApiMapper.flow(
      data,
    );
  }

  Future<DeveloperImpactAnalysis>
      getImpact({
    required String path,
    String? functionName,
  }) async {
    final String normalizedPath =
        path.trim();

    if (normalizedPath.isEmpty) {
      throw Exception(
        'Percorso file non valido.',
      );
    }

    final Map<String, String>
        queryParameters = {
      'path': normalizedPath,
    };

    final String? normalizedFunction =
        functionName?.trim();

    if (normalizedFunction != null &&
        normalizedFunction.isNotEmpty) {
      queryParameters['function'] =
          normalizedFunction;
    }

    final Map<String, dynamic> data =
        _asMap(
      await _get(
        '/developer/impact',
        queryParameters:
            queryParameters,
      ),
      'Impact analysis non valida.',
    );

    return DeveloperApiMapper.impact(
      data,
    );
  }

  Future<DeveloperSourceCode> getSource({
    required String path,
    String? functionName,
  }) async {
    final String normalizedPath =
        path.trim();

    if (normalizedPath.isEmpty) {
      throw Exception(
        'Percorso sorgente non valido.',
      );
    }

    final Map<String, String>
        queryParameters = {
      'path': normalizedPath,
    };

    final String? normalizedFunction =
        functionName?.trim();

    if (normalizedFunction != null &&
        normalizedFunction.isNotEmpty) {
      queryParameters['function'] =
          normalizedFunction;
    }

    final Map<String, dynamic> data =
        _asMap(
      await _get(
        '/developer/source',
        queryParameters:
            queryParameters,
      ),
      'Sorgente Developer non valido.',
    );

    return DeveloperApiMapper.source(
      data,
    );
  }

  Future<DeveloperApiContract>
      getApiContract({
    required String path,
    required String functionName,
  }) async {
    final String normalizedPath =
        path.trim();

    final String normalizedFunction =
        functionName.trim();

    if (normalizedPath.isEmpty ||
        normalizedFunction.isEmpty) {
      throw Exception(
        'File o funzione non validi.',
      );
    }

    final Map<String, dynamic> data =
        _asMap(
      await _get(
        '/developer/api-contract',
        queryParameters: {
          'path': normalizedPath,
          'function':
              normalizedFunction,
        },
      ),
      'Contratto API Developer non valido.',
    );

    return DeveloperApiMapper.apiContract(
      data,
    );
  }

  Future<DeveloperRuntimeRisk>
      getRuntimeRisk({
    required String path,
    required String functionName,
  }) async {
    final String normalizedPath =
        path.trim();

    final String normalizedFunction =
        functionName.trim();

    if (normalizedPath.isEmpty ||
        normalizedFunction.isEmpty) {
      throw Exception(
        'File o funzione non validi.',
      );
    }

    final Map<String, dynamic> data =
        _asMap(
      await _get(
        '/developer/runtime-risk',
        queryParameters: {
          'path': normalizedPath,
          'function':
              normalizedFunction,
        },
      ),
      'Runtime Risk Developer non valido.',
    );

    return DeveloperApiMapper.runtimeRisk(
      data,
    );
  }

  Future<DeveloperGraphData>
      getGraph() async {
    final Map<String, dynamic> data =
        _asMap(
      await _get('/developer/graph'),
      'Grafo Developer non valido.',
    );

    return DeveloperApiMapper.graph(
      data,
    );
  }

  Map<String, dynamic> _asMap(
    dynamic value,
    String message,
  ) {
    if (value
        is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(
        value,
      );
    }

    throw Exception(message);
  }

  List<Map<String, dynamic>>
      _asMapList(
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
}

class DeveloperApiException
    implements Exception {
  final int statusCode;
  final String message;

  const DeveloperApiException({
    required this.statusCode,
    required this.message,
  });

  @override
  String toString() => message;
}
