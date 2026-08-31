import 'dart:convert';

import 'package:http/http.dart' as http;

import '../social/news/models/news_board.dart';
import 'auth_session.dart';
import 'news_write_token_store.dart';

class NewsApiService {
  static const String _baseUrl = 'https://dmi-student-lab.vercel.app';
  static const String _host = 'dmi-student-lab.vercel.app';
  static const String _writeTokenHeader = 'X-News-Write-Token';

  static const int maxTitleLength = 160;
  static const int maxContentLength = 5000;
  static const int maxCiphertextLength = 200000;

  final AuthSession _session;
  final NewsWriteTokenStore _tokenStore;
  final http.Client _client;

  NewsApiService({
    AuthSession? session,
    NewsWriteTokenStore? tokenStore,
    http.Client? client,
  })  : _session = session ?? AuthSession.instance,
        _tokenStore = tokenStore ?? NewsWriteTokenStore(),
        _client = client ?? http.Client();

  Future<NewsAvvisoListResult> getAvvisi({
    int limit = 30,
    int offset = 0,
  }) async {
    final http.Response response = await _client.get(
      _uri(
        '/news/avvisi',
        query: _pagination(limit, offset),
      ),
      headers: _headers,
    );

    return NewsAvvisoListResult.fromJson(
      _decodeMap(response, 'Impossibile caricare gli avvisi.'),
    );
  }

  Future<NewsAvviso> getAvviso(String newsId) async {
    final String id = _requireId(newsId);

    final http.Response response = await _client.get(
      _uri('/news/avvisi/$id'),
      headers: _headers,
    );

    return NewsAvviso.fromJson(
      _decodeMap(response, 'Impossibile caricare l’avviso.'),
    );
  }

  Future<NewsAvviso> createAvviso({
    required String title,
    required String content,
  }) async {
    _requireAuthenticated();

    final String normalizedTitle = _requireText(
      title,
      maxTitleLength,
      'Titolo dell’avviso non valido.',
    );

    final String normalizedContent = _requireText(
      content,
      maxContentLength,
      'Contenuto dell’avviso non valido.',
    );

    final http.Response response = await _client.post(
      _uri('/news/avvisi'),
      headers: _headers,
      body: jsonEncode({
        'title': normalizedTitle,
        'content': normalizedContent,
      }),
    );

    final NewsAvviso avviso = NewsAvviso.fromJson(
      _decodeMap(response, 'Impossibile pubblicare l’avviso.'),
    );

    await _rememberWriteToken(avviso.id, avviso.writeToken);

    return avviso;
  }

  Future<NewsReply> replyToAvviso({
    required String newsId,
    required String content,
  }) async {
    _requireAuthenticated();

    final String id = _requireId(newsId);

    final http.Response response = await _client.post(
      _uri('/news/avvisi/$id/replies'),
      headers: _headers,
      body: jsonEncode({
        'content': _requireText(
          content,
          maxContentLength,
          'Contenuto della risposta non valido.',
        ),
      }),
    );

    return NewsReply.fromJson(
      _decodeMap(response, 'Impossibile inviare la risposta.'),
    );
  }

  Future<void> deleteAvviso(
    String newsId, {
    String writeToken = '',
  }) async {
    _requireAuthenticated();

    final String id = _requireId(newsId);
    final String token = await _resolveWriteToken(id, writeToken);

    final http.Response response = await _client.delete(
      _uri('/news/avvisi/$id'),
      headers: _headersWithWriteToken(token),
    );

    _decodeMap(response, 'Impossibile eliminare l’avviso.');

    await _tokenStore.remove(id);
  }

  Future<NewsGroupPostListResult> getGroupNews({
    required int groupId,
    int limit = 30,
    int offset = 0,
  }) async {
    _requireAuthenticated();
    _requirePositiveId(groupId);

    final http.Response response = await _client.get(
      _uri(
        '/news/groups/$groupId',
        query: _pagination(limit, offset),
      ),
      headers: _headers,
    );

    return NewsGroupPostListResult.fromJson(
      _decodeMap(response, 'Impossibile caricare le news del gruppo.'),
    );
  }

  Future<NewsGroupPost> createGroupNews({
    required int groupId,
    required String content,
  }) async {
    _requireAuthenticated();
    _requirePositiveId(groupId);

    final http.Response response = await _client.post(
      _uri('/news/groups/$groupId'),
      headers: _headers,
      body: jsonEncode({
        'content': _requireText(
          content,
          maxContentLength,
          'Contenuto della news non valido.',
        ),
      }),
    );

    final NewsGroupPost post = NewsGroupPost.fromJson(
      _decodeMap(response, 'Impossibile pubblicare la news.'),
    );

    await _rememberWriteToken(post.id, post.writeToken);

    return post;
  }

  Future<NewsReply> replyToGroupNews({
    required int groupId,
    required String newsId,
    required String content,
  }) async {
    _requireAuthenticated();
    _requirePositiveId(groupId);

    final String id = _requireId(newsId);

    final http.Response response = await _client.post(
      _uri('/news/groups/$groupId/$id/replies'),
      headers: _headers,
      body: jsonEncode({
        'content': _requireText(
          content,
          maxContentLength,
          'Contenuto della risposta non valido.',
        ),
      }),
    );

    return NewsReply.fromJson(
      _decodeMap(response, 'Impossibile inviare la risposta.'),
    );
  }

  Future<void> deleteGroupNews({
    required int groupId,
    required String newsId,
    String writeToken = '',
  }) async {
    _requireAuthenticated();
    _requirePositiveId(groupId);

    final String id = _requireId(newsId);
    final String token = await _resolveWriteToken(id, writeToken);

    final http.Response response = await _client.delete(
      _uri('/news/groups/$groupId/$id'),
      headers: _headersWithWriteToken(token),
    );

    _decodeMap(response, 'Impossibile eliminare la news.');

    await _tokenStore.remove(id);
  }

  Future<NewsPrivateMessageListResult> getPrivateInbox({
    int limit = 30,
    int offset = 0,
  }) async {
    _requireAuthenticated();

    final http.Response response = await _client.get(
      _uri(
        '/news/private',
        query: _pagination(limit, offset),
      ),
      headers: _headers,
    );

    return NewsPrivateMessageListResult.fromJson(
      _decodeMap(response, 'Impossibile caricare i messaggi privati.'),
    );
  }

  Future<NewsPrivateMessageListResult> getPrivateConversation({
    required int otherUserId,
    int limit = 30,
    int offset = 0,
  }) async {
    _requireAuthenticated();
    _requirePositiveId(otherUserId);

    final http.Response response = await _client.get(
      _uri(
        '/news/private/$otherUserId',
        query: _pagination(limit, offset),
      ),
      headers: _headers,
    );

    return NewsPrivateMessageListResult.fromJson(
      _decodeMap(response, 'Impossibile caricare la conversazione.'),
    );
  }

  Future<NewsPrivateMessageListResult> getPendingPrivateNews({
    int limit = 30,
    int offset = 0,
  }) async {
    _requireAuthenticated();

    final http.Response response = await _client.get(
      _uri(
        '/news/private/pending',
        query: _pagination(limit, offset),
      ),
      headers: _headers,
    );

    return NewsPrivateMessageListResult.fromJson(
      _decodeMap(response, 'Impossibile caricare i messaggi in attesa.'),
    );
  }

  Future<NewsPrivateMessage> completePrivateDelivery({
    required int otherUserId,
    required String newsId,
    required Map<String, dynamic> wrappedKeys,
  }) async {
    _requireAuthenticated();
    _requirePositiveId(otherUserId);

    if (wrappedKeys.isEmpty) {
      throw ArgumentError('Nessuna chiave da aggiungere.');
    }

    final http.Response response = await _client.post(
      _uri('/news/private/$otherUserId/${_requireId(newsId)}/wrap'),
      headers: _headers,
      body: jsonEncode({
        'wrapped_keys': wrappedKeys,
      }),
    );

    return NewsPrivateMessage.fromJson(
      _decodeMap(response, 'Impossibile completare la consegna.'),
    );
  }

  Future<NewsPrivateMessage> sendPrivateNews({
    required int recipientId,
    required String ciphertext,
    required String algo,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    _requireAuthenticated();
    _requirePositiveId(recipientId);

    if (recipientId == _session.currentUserId) {
      throw ArgumentError('Non puoi inviare un messaggio a te stesso.');
    }

    final String normalizedCiphertext = _requireText(
      ciphertext,
      maxCiphertextLength,
      'Contenuto cifrato non valido.',
    );

    final String normalizedAlgo = _requireText(
      algo,
      64,
      'Algoritmo di cifratura non valido.',
    );

    final http.Response response = await _client.post(
      _uri('/news/private'),
      headers: _headers,
      body: jsonEncode({
        'recipient_id': recipientId,
        'ciphertext': normalizedCiphertext,
        'algo': normalizedAlgo,
        'metadata': metadata,
      }),
    );

    final NewsPrivateMessage message = NewsPrivateMessage.fromJson(
      _decodeMap(response, 'Impossibile inviare il messaggio.'),
    );

    await _rememberWriteToken(message.id, message.writeToken);

    return message;
  }

  Future<void> deletePrivateNews({
    required int otherUserId,
    required String newsId,
    String writeToken = '',
  }) async {
    _requireAuthenticated();
    _requirePositiveId(otherUserId);

    final String id = _requireId(newsId);
    final String token = await _resolveWriteToken(id, writeToken);

    final http.Response response = await _client.delete(
      _uri('/news/private/$otherUserId/$id'),
      headers: _headersWithWriteToken(token),
    );

    _decodeMap(response, 'Impossibile eliminare il messaggio.');

    await _tokenStore.remove(id);
  }

  Map<String, dynamic> _pagination(int limit, int offset) {
    return {
      'limit': limit.clamp(1, 100),
      'offset': offset < 0 ? 0 : offset,
    };
  }

  Uri _uri(String path, {Map<String, dynamic>? query}) {
    final Uri base = Uri.parse(_baseUrl);
    final String normalizedPath = path.startsWith('/') ? path : '/$path';
    final Map<String, String> parameters = {};

    if (query != null) {
      for (final MapEntry<String, dynamic> entry in query.entries) {
        if (entry.value != null) {
          parameters[entry.key] = entry.value.toString();
        }
      }
    }

    final Uri result = base.replace(
      path: normalizedPath,
      queryParameters: parameters.isEmpty ? null : parameters,
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

  Map<String, String> _headersWithWriteToken(String writeToken) {
    return {
      ..._headers,
      _writeTokenHeader: writeToken,
    };
  }

  Future<void> _rememberWriteToken(String newsId, String writeToken) async {
    if (writeToken.isEmpty) {
      return;
    }

    await _tokenStore.save(
      newsId: newsId,
      writeToken: writeToken,
    );
  }

  Future<String> _resolveWriteToken(
    String newsId,
    String provided,
  ) async {
    final String explicit = provided.trim();

    if (explicit.isNotEmpty) {
      return explicit;
    }

    final String? stored = await _tokenStore.read(newsId);

    if (stored == null || stored.isEmpty) {
      throw StateError(
        'Token di modifica non disponibile su questo dispositivo.',
      );
    }

    return stored;
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

  void _requirePositiveId(int value) {
    if (value <= 0) {
      throw ArgumentError('Identificativo non valido.');
    }
  }

  String _requireId(String value) {
    final String normalized = value.trim();

    if (normalized.isEmpty || normalized.contains('/')) {
      throw ArgumentError('Identificativo della news non valido.');
    }

    return normalized;
  }

  String _requireText(
    String value,
    int maxLength,
    String message,
  ) {
    final String normalized = value.trim();

    if (normalized.isEmpty || normalized.length > maxLength) {
      throw ArgumentError(message);
    }

    return normalized;
  }
}
