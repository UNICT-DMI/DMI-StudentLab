import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fe/services/auth_session.dart';
import 'package:fe/services/news_report_api_service.dart';
import 'package:fe/social/news/models/news_report.dart';
import 'package:fe/social/social_models.dart';

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

Map<String, dynamic> _reportPayload({
  String category = 'private',
  String? disclosureConsentAt = '2026-08-26T10:00:00+00:00',
}) {
  return <String, dynamic>{
    'id': 11,
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

void main() {
  setUp(() {
    AuthSession.instance.setRestoredSession(
      accessToken: 'jwt-token',
      user: _user(3),
    );
  });

  test('reportPrivateMessage invia consenso e chiave del messaggio', () async {
    http.Request? captured;

    final NewsReportApiService api = NewsReportApiService(
      client: MockClient((http.Request request) async {
        captured = request;

        return http.Response(
          jsonEncode(_reportPayload()),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final NewsReport report = await api.reportPrivateMessage(
      otherUserId: 7,
      newsId: 'msg-1',
      reason: 'harassment',
      disclosedContentKey: 'CEK-BASE64',
      description: '  Messaggio offensivo  ',
    );

    expect(captured?.method, 'POST');
    expect(captured?.url.path, '/news-reports');

    final Map<String, dynamic> body =
        jsonDecode(captured!.body) as Map<String, dynamic>;

    expect(body['category'], 'private');
    expect(body['other_user_id'], 7);
    expect(body['disclosure_consent'], isTrue);
    expect(body['disclosed_content_key'], 'CEK-BASE64');
    expect(body['description'], 'Messaggio offensivo');

    expect(report.hasDisclosureConsent, isTrue);
    expect(report.reasonLabel, 'Molestie o minacce');
    expect(report.isPending, isTrue);
  });

  test('senza chiave la segnalazione privata è rifiutata sul client',
      () async {
    bool called = false;

    final NewsReportApiService api = NewsReportApiService(
      client: MockClient((http.Request request) async {
        called = true;
        return http.Response('{}', 201);
      }),
    );

    await expectLater(
      api.reportPrivateMessage(
        otherUserId: 7,
        newsId: 'msg-1',
        reason: 'harassment',
        disclosedContentKey: '   ',
      ),
      throwsA(isA<ArgumentError>()),
    );

    expect(called, isFalse);
  });

  test('un motivo non previsto è rifiutato', () async {
    final NewsReportApiService api = NewsReportApiService(
      client: MockClient((http.Request request) async {
        return http.Response('{}', 201);
      }),
    );

    await expectLater(
      api.reportAvviso(
        newsId: 'abc',
        reason: 'qualsiasi_cosa',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('la segnalazione di un avviso non manda chiavi', () async {
    http.Request? captured;

    final NewsReportApiService api = NewsReportApiService(
      client: MockClient((http.Request request) async {
        captured = request;

        return http.Response(
          jsonEncode(
            _reportPayload(
              category: 'avvisi',
              disclosureConsentAt: null,
            ),
          ),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final NewsReport report = await api.reportAvviso(
      newsId: 'abc123',
      reason: 'spam',
    );

    final Map<String, dynamic> body =
        jsonDecode(captured!.body) as Map<String, dynamic>;

    expect(body.containsKey('disclosed_content_key'), isFalse);
    expect(body.containsKey('disclosure_consent'), isFalse);
    expect(report.hasDisclosureConsent, isFalse);
  });

  test('moderare con azione richiede una motivazione', () async {
    bool called = false;

    final NewsReportApiService api = NewsReportApiService(
      client: MockClient((http.Request request) async {
        called = true;
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      api.moderateReport(
        reportId: 11,
        status: 'resolved',
        action: 'hide_news',
      ),
      throwsA(isA<ArgumentError>()),
    );

    expect(called, isFalse);
  });

  test('openDisclosure restituisce il contenuto verificato', () async {
    final NewsReportApiService api = NewsReportApiService(
      client: MockClient((http.Request request) async {
        expect(request.url.path, '/admin/news-reports/11/disclosure');

        return http.Response(
          jsonEncode({
            'report_id': 11,
            'category': 'private',
            'news_id': 'msg-1',
            'author_id': 7,
            'author_name': '',
            'created_at': '2026-08-26T10:00:00+00:00',
            'content': 'Contenuto illecito da segnalare',
            'verified': true,
            'wrap_targets': ['3:device-recipient'],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final NewsReportDisclosure disclosure = await api.openDisclosure(11);

    expect(disclosure.verified, isTrue);
    expect(disclosure.content, 'Contenuto illecito da segnalare');
    expect(disclosure.wrapTargets, ['3:device-recipient']);
  });

  test('il backend che rifiuta la disclosure produce un errore leggibile',
      () async {
    final NewsReportApiService api = NewsReportApiService(
      client: MockClient((http.Request request) async {
        return http.Response(
          jsonEncode({
            'detail':
                'La chiave fornita non decifra questo messaggio: la '
                    'segnalazione non è verificabile.',
          }),
          400,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await expectLater(
      api.openDisclosure(11),
      throwsA(
        isA<Exception>().having(
          (Exception error) => error.toString(),
          'messaggio',
          contains('non è verificabile'),
        ),
      ),
    );
  });
}
