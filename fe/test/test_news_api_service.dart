import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fe/services/auth_session.dart';
import 'package:fe/services/news_api_service.dart';
import 'package:fe/services/news_write_token_store.dart';
import 'package:fe/social/news/models/news_board.dart';
import 'package:fe/social/social_models.dart';

class FakeNewsWriteTokenStore extends NewsWriteTokenStore {
  final Map<String, String> tokens = <String, String>{};

  @override
  Future<void> save({
    required String newsId,
    required String writeToken,
  }) async {
    tokens[newsId] = writeToken;
  }

  @override
  Future<String?> read(String newsId) async {
    return tokens[newsId];
  }

  @override
  Future<void> remove(String newsId) async {
    tokens.remove(newsId);
  }

  @override
  Future<void> clear() async {
    tokens.clear();
  }
}

SocialUser _user(int id) {
  return SocialUser(
    id: id,
    firstName: 'Anna',
    lastName: 'Rossi',
    email: 'anna@example.com',
    department: 'DMI',
    course: 'Informatica',
    subjects: const <SocialSubject>[],
    description: '',
    type: SocialUserType.student,
    available: true,
    availableForHelp: false,
    availableForPrivateLessons: false,
    isActive: true,
  );
}

Map<String, dynamic> _avvisoPayload({
  String id = 'abc123',
  String? writeToken = 'token-1',
}) {
  return <String, dynamic>{
    'id': id,
    'author_id': 200,
    'author_name': 'Marco Bianchi',
    'author_role': 'admin',
    'title': 'Manutenzione',
    'content': 'Domani stop',
    'created_at': '2026-08-26T10:00:00+00:00',
    'updated_at': '2026-08-26T10:00:00+00:00',
    'replies': <dynamic>[],
    'can_delete': true,
    'write_token': writeToken,
  };
}

void main() {
  late FakeNewsWriteTokenStore tokenStore;

  setUp(() {
    tokenStore = FakeNewsWriteTokenStore();

    AuthSession.instance.setRestoredSession(
      accessToken: 'jwt-token',
      user: _user(100),
    );
  });

  NewsApiService serviceWith(MockClient client) {
    return NewsApiService(
      tokenStore: tokenStore,
      client: client,
    );
  }

  test('getAvvisi richiede la lista paginata e la deserializza', () async {
    Uri? requested;

    final NewsApiService service = serviceWith(
      MockClient((http.Request request) async {
        requested = request.url;

        return http.Response(
          jsonEncode({
            'items': [
              _avvisoPayload(writeToken: null),
            ],
            'total': 1,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final NewsAvvisoListResult result = await service.getAvvisi(
      limit: 500,
      offset: -3,
    );

    expect(requested?.scheme, 'https');
    expect(requested?.host, 'dmi-student-lab.vercel.app');
    expect(requested?.path, '/news/avvisi');
    expect(requested?.queryParameters['limit'], '100');
    expect(requested?.queryParameters['offset'], '0');

    expect(result.total, 1);
    expect(result.items.single.title, 'Manutenzione');
    expect(result.items.single.writeToken, '');
  });

  test('createAvviso invia il token di sessione e memorizza il write token',
      () async {
    http.Request? captured;

    final NewsApiService service = serviceWith(
      MockClient((http.Request request) async {
        captured = request;

        return http.Response(
          jsonEncode(_avvisoPayload()),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final NewsAvviso avviso = await service.createAvviso(
      title: '  Manutenzione  ',
      content: '  Domani stop  ',
    );

    expect(captured?.method, 'POST');
    expect(captured?.url.path, '/news/avvisi');
    expect(captured?.headers['Authorization'], 'Bearer jwt-token');

    final Map<String, dynamic> body = jsonDecode(captured!.body) as Map<String, dynamic>;

    expect(body['title'], 'Manutenzione');
    expect(body['content'], 'Domani stop');

    expect(avviso.id, 'abc123');
    expect(tokenStore.tokens['abc123'], 'token-1');
  });

  test('createAvviso rifiuta un titolo vuoto senza chiamare il backend',
      () async {
    bool called = false;

    final NewsApiService service = serviceWith(
      MockClient((http.Request request) async {
        called = true;
        return http.Response('{}', 201);
      }),
    );

    await expectLater(
      service.createAvviso(title: '   ', content: 'Contenuto'),
      throwsA(isA<ArgumentError>()),
    );

    expect(called, isFalse);
  });

  test('deleteAvviso usa il write token salvato e lo rimuove', () async {
    tokenStore.tokens['abc123'] = 'token-1';

    http.Request? captured;

    final NewsApiService service = serviceWith(
      MockClient((http.Request request) async {
        captured = request;

        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Avviso eliminato.',
            'news_id': 'abc123',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await service.deleteAvviso('abc123');

    expect(captured?.method, 'DELETE');
    expect(captured?.url.path, '/news/avvisi/abc123');
    expect(captured?.headers['X-News-Write-Token'], 'token-1');
    expect(tokenStore.tokens.containsKey('abc123'), isFalse);
  });

  test('deleteAvviso senza write token non contatta il backend', () async {
    bool called = false;

    final NewsApiService service = serviceWith(
      MockClient((http.Request request) async {
        called = true;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      service.deleteAvviso('abc123'),
      throwsA(isA<StateError>()),
    );

    expect(called, isFalse);
  });

  test('deleteAvviso mantiene il token quando il backend rifiuta', () async {
    tokenStore.tokens['abc123'] = 'token-1';

    final NewsApiService service = serviceWith(
      MockClient((http.Request request) async {
        return http.Response(
          jsonEncode({
            'detail': 'Token di modifica non valido.',
          }),
          403,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await expectLater(
      service.deleteAvviso('abc123'),
      throwsA(
        isA<Exception>().having(
          (Exception error) => error.toString(),
          'messaggio',
          contains('Token di modifica non valido.'),
        ),
      ),
    );

    expect(tokenStore.tokens['abc123'], 'token-1');
  });

  test('getGroupNews interroga il gruppo richiesto', () async {
    Uri? requested;

    final NewsApiService service = serviceWith(
      MockClient((http.Request request) async {
        requested = request.url;

        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'g1',
                'group_id': 12,
                'group_name': 'Reti',
                'author_id': 100,
                'author_name': 'Anna Rossi',
                'author_role': 'student',
                'content': 'ciao gruppo',
                'created_at': '2026-08-26T10:00:00+00:00',
                'updated_at': '2026-08-26T10:00:00+00:00',
                'replies': <dynamic>[],
                'can_delete': true,
                'write_token': null,
              },
            ],
            'total': 1,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final NewsGroupPostListResult result = await service.getGroupNews(
      groupId: 12,
    );

    expect(requested?.path, '/news/groups/12');
    expect(result.items.single.groupName, 'Reti');
    expect(result.items.single.content, 'ciao gruppo');
  });

  test('sendPrivateNews invia solo ciphertext e metadata', () async {
    http.Request? captured;

    final NewsApiService service = serviceWith(
      MockClient((http.Request request) async {
        captured = request;

        return http.Response(
          jsonEncode({
            'id': 'p1',
            'conversation_id': '3_100',
            'sender_id': 100,
            'recipient_id': 3,
            'algo': 'x25519-aesgcm',
            'ciphertext': 'BASE64CIPHERTEXT',
            'metadata': {'nonce': 'abc'},
            'created_at': '2026-08-26T10:00:00+00:00',
            'can_delete': true,
            'write_token': 'token-p1',
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final NewsPrivateMessage message = await service.sendPrivateNews(
      recipientId: 3,
      ciphertext: 'BASE64CIPHERTEXT',
      algo: 'x25519-aesgcm',
      metadata: const <String, dynamic>{'nonce': 'abc'},
    );

    final Map<String, dynamic> body = jsonDecode(captured!.body) as Map<String, dynamic>;

    expect(body.keys, containsAll(<String>['recipient_id', 'ciphertext', 'algo', 'metadata']));
    expect(body['ciphertext'], 'BASE64CIPHERTEXT');
    expect(body.containsKey('content'), isFalse);

    expect(message.conversationId, '3_100');
    expect(message.counterpartId(100), 3);
    expect(tokenStore.tokens['p1'], 'token-p1');
  });

  test('sendPrivateNews rifiuta se stesso come destinatario', () async {
    bool called = false;

    final NewsApiService service = serviceWith(
      MockClient((http.Request request) async {
        called = true;
        return http.Response('{}', 201);
      }),
    );

    await expectLater(
      service.sendPrivateNews(
        recipientId: 100,
        ciphertext: 'CIPHER',
        algo: 'x25519-aesgcm',
      ),
      throwsA(isA<ArgumentError>()),
    );

    expect(called, isFalse);
  });

  test('un identificativo con slash viene rifiutato', () async {
    final NewsApiService service = serviceWith(
      MockClient((http.Request request) async {
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      service.getAvviso('../avvisi'),
      throwsA(isA<ArgumentError>()),
    );
  });
}
