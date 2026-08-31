import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fe/services/auth_session.dart';
import 'package:fe/services/news_report_api_service.dart';
import 'package:fe/social/admin/admin_news_reports_page.dart';
import 'package:fe/social/social_models.dart';

SocialUser _admin(int id) {
  return SocialUser(
    id: id,
    firstName: 'Marco',
    lastName: 'Bianchi',
    email: 'marco@example.com',
    department: 'DMI',
    course: 'Informatica',
    subjects: const <SocialSubject>[],
    description: '',
    type: SocialUserType.teacher,
    available: true,
    availableForHelp: false,
    availableForPrivateLessons: false,
    isActive: true,
  );
}

Map<String, dynamic> _report({
  int id = 11,
  String category = 'private',
  String? disclosureConsentAt = '2026-08-26T10:00:00+00:00',
}) {
  return <String, dynamic>{
    'id': id,
    'category': category,
    'news_id': 'msg-1',
    'group_id': null,
    'conversation_id': '3_7',
    'reporter_user_id': 3,
    'reported_user_id': 7,
    'reason': 'harassment',
    'description': 'Messaggio offensivo',
    'status': 'pending',
    'moderation_action': 'none',
    'moderation_note': null,
    'reviewed_by_user_id': null,
    'reviewed_at': null,
    'disclosure_consent_at': disclosureConsentAt,
    'disclosure_opened_at': null,
    'created_at': '2026-08-26T10:00:00+00:00',
    'updated_at': '2026-08-26T10:00:00+00:00',
  };
}

String _listBody(List<Map<String, dynamic>> items) {
  return jsonEncode(<String, dynamic>{
    'items': items,
    'total': items.length,
    'limit': 50,
    'offset': 0,
  });
}

Future<void> _pumpPage(
  WidgetTester tester,
  NewsReportApiService api,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: AdminNewsReportsPage(reportApi: api),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    AuthSession.instance.setRestoredSession(
      accessToken: 'jwt-token',
      user: _admin(1),
    );
  });

  testWidgets('la coda mostra categoria, motivo e stato di ogni segnalazione', (
    WidgetTester tester,
  ) async {
    final NewsReportApiService api = NewsReportApiService(
      client: MockClient((http.Request request) async {
        return http.Response(
          _listBody(<Map<String, dynamic>>[_report()]),
          200,
          headers: const <String, String>{
            'content-type': 'application/json',
          },
        );
      }),
    );

    await _pumpPage(tester, api);

    expect(find.textContaining('Messaggio privato'), findsOneWidget);
    expect(find.text('Molestie o minacce'), findsOneWidget);
    expect(find.text('Messaggio offensivo'), findsOneWidget);
    expect(find.text('Segnalante #3'), findsOneWidget);
  });

  testWidgets('lo stato selezionato viene passato come filtro al backend', (
    WidgetTester tester,
  ) async {
    final List<Uri> requested = <Uri>[];

    final NewsReportApiService api = NewsReportApiService(
      client: MockClient((http.Request request) async {
        requested.add(request.url);

        return http.Response(
          _listBody(<Map<String, dynamic>>[]),
          200,
          headers: const <String, String>{
            'content-type': 'application/json',
          },
        );
      }),
    );

    await _pumpPage(tester, api);

    expect(requested.single.queryParameters['status'], 'pending');
    expect(requested.single.queryParameters.containsKey('category'), isFalse);
  });

  testWidgets(
    'senza consenso alla disclosure il contenuto privato non è apribile',
    (WidgetTester tester) async {
      final NewsReportApiService api = NewsReportApiService(
        client: MockClient((http.Request request) async {
          return http.Response(
            _listBody(<Map<String, dynamic>>[
              _report(disclosureConsentAt: null),
            ]),
            200,
            headers: const <String, String>{
              'content-type': 'application/json',
            },
          );
        }),
      );

      await _pumpPage(tester, api);

      expect(find.text('Apri contenuto'), findsNothing);
      expect(
        find.textContaining('Nessuna chiave condivisa'),
        findsOneWidget,
      );
    },
  );

  testWidgets('aprire un messaggio privato richiede una conferma esplicita', (
    WidgetTester tester,
  ) async {
    final List<String> paths = <String>[];

    final NewsReportApiService api = NewsReportApiService(
      client: MockClient((http.Request request) async {
        paths.add(request.url.path);

        if (request.url.path.endsWith('/disclosure')) {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'report_id': 11,
              'category': 'private',
              'news_id': 'msg-1',
              'author_id': 7,
              'author_name': 'Luca Verdi',
              'created_at': '2026-08-26T10:00:00+00:00',
              'content': 'Testo del messaggio segnalato',
              'verified': true,
              'wrap_targets': <String>['7:device-a', 'compliance:key-1'],
            }),
            200,
            headers: const <String, String>{
              'content-type': 'application/json',
            },
          );
        }

        return http.Response(
          _listBody(<Map<String, dynamic>>[_report()]),
          200,
          headers: const <String, String>{
            'content-type': 'application/json',
          },
        );
      }),
    );

    await _pumpPage(tester, api);

    await tester.tap(find.text('Apri contenuto'));
    await tester.pumpAndSettle();

    expect(find.text('Aprire il messaggio privato?'), findsOneWidget);

    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();

    expect(
      paths.where((String path) => path.endsWith('/disclosure')),
      isEmpty,
    );
    expect(find.text('Testo del messaggio segnalato'), findsNothing);

    await tester.tap(find.text('Apri contenuto'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apri'));
    await tester.pumpAndSettle();

    expect(find.text('Testo del messaggio segnalato'), findsOneWidget);
    expect(find.textContaining('compliance:key-1'), findsOneWidget);
    expect(find.text('Contenuto aperto'), findsOneWidget);
  });

  testWidgets(
    'un avviso segnalato si apre senza dialogo di consenso',
    (WidgetTester tester) async {
      final NewsReportApiService api = NewsReportApiService(
        client: MockClient((http.Request request) async {
          if (request.url.path.endsWith('/disclosure')) {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'report_id': 12,
                'category': 'avvisi',
                'news_id': 'msg-1',
                'author_id': 7,
                'author_name': 'Luca Verdi',
                'created_at': '2026-08-26T10:00:00+00:00',
                'content': 'Titolo\n\nCorpo dell’avviso',
                'verified': true,
                'wrap_targets': <String>[],
              }),
              200,
              headers: const <String, String>{
                'content-type': 'application/json',
              },
            );
          }

          return http.Response(
            _listBody(<Map<String, dynamic>>[
              _report(
                id: 12,
                category: 'avvisi',
                disclosureConsentAt: null,
              ),
            ]),
            200,
            headers: const <String, String>{
              'content-type': 'application/json',
            },
          );
        }),
      );

      await _pumpPage(tester, api);

      await tester.tap(find.text('Apri contenuto'));
      await tester.pumpAndSettle();

      expect(find.text('Aprire il messaggio privato?'), findsNothing);
      expect(find.textContaining('Corpo dell’avviso'), findsOneWidget);
    },
  );

  testWidgets(
    'nascondere un contenuto senza motivazione non chiama il backend',
    (WidgetTester tester) async {
      final List<String> methods = <String>[];

      final NewsReportApiService api = NewsReportApiService(
        client: MockClient((http.Request request) async {
          methods.add(request.method);

          return http.Response(
            _listBody(<Map<String, dynamic>>[_report()]),
            200,
            headers: const <String, String>{
              'content-type': 'application/json',
            },
          );
        }),
      );

      await _pumpPage(tester, api);

      await tester.tap(find.text('Gestisci'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nessuna azione'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nascondi contenuto').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salva'));
      await tester.pumpAndSettle();

      expect(methods.contains('PATCH'), isFalse);
      expect(
        find.textContaining('serve una motivazione'),
        findsOneWidget,
      );
    },
  );
}
