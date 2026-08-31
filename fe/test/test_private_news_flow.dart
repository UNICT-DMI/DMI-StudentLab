import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/services/auth_session.dart';
import 'package:fe/services/private_news_messenger.dart';
import 'package:fe/social/news/models/news_board.dart';
import 'package:fe/social/news/private_conversation_page.dart';
import 'package:fe/social/news/private_news_page.dart';
import 'package:fe/social/social_models.dart';

const int _viewerId = 3;

SocialUser _user(
  int id, {
  String firstName = 'Anna',
  String lastName = 'Rossi',
  bool isActive = true,
}) {
  return SocialUser(
    id: id,
    firstName: firstName,
    lastName: lastName,
    email: '${firstName.toLowerCase()}@example.com',
    department: 'DMI',
    course: 'Informatica',
    subjects: const <SocialSubject>[],
    description: '',
    type: SocialUserType.student,
    available: true,
    availableForHelp: false,
    availableForPrivateLessons: false,
    isActive: isActive,
  );
}

PrivateConversationMessage _message({
  required String id,
  required int senderId,
  required int recipientId,
  String senderName = 'Luca Verdi',
  String recipientName = 'Anna Rossi',
  String text = 'Ciao',
  bool readable = true,
  String delivery = 'delivered',
  DateTime? createdAt,
}) {
  return PrivateConversationMessage(
    raw: NewsPrivateMessage(
      id: id,
      conversationId: '3_7',
      senderId: senderId,
      recipientId: recipientId,
      senderName: senderName,
      recipientName: recipientName,
      algo: 'aes-256-gcm',
      ciphertext: 'cipher',
      metadata: const <String, dynamic>{},
      createdAt: createdAt ?? DateTime(2026, 8, 26, 10),
      delivery: delivery,
      canDelete: true,
      writeToken: 'token',
    ),
    text: text,
    isReadable: readable,
  );
}

class _FakeMessenger extends PrivateNewsMessenger {
  _FakeMessenger({
    this.inboxMessages = const <PrivateConversationMessage>[],
    this.conversationMessages = const <PrivateConversationMessage>[],
    this.reachableThrows = false,
    this.sendError,
  });

  final List<PrivateConversationMessage> inboxMessages;
  final List<PrivateConversationMessage> conversationMessages;
  final bool reachableThrows;
  final Object? sendError;

  int reachableCalls = 0;
  int flushCalls = 0;
  final List<int> conversationRequests = <int>[];
  final List<(int, String)> sent = <(int, String)>[];

  @override
  Future<void> ensureReachable() async {
    reachableCalls += 1;

    if (reachableThrows) {
      throw StateError('Pubblicazione non riuscita.');
    }
  }

  @override
  Future<int> flushPendingDeliveries({int limit = 50}) async {
    flushCalls += 1;

    return 0;
  }

  @override
  Future<List<PrivateConversationMessage>> inbox({
    int limit = 30,
    int offset = 0,
  }) async {
    return offset == 0 ? inboxMessages : <PrivateConversationMessage>[];
  }

  @override
  Future<List<PrivateConversationMessage>> conversation({
    required int otherUserId,
    int limit = 30,
    int offset = 0,
  }) async {
    if (offset == 0) {
      conversationRequests.add(otherUserId);
    }

    return offset == 0
        ? conversationMessages
        : <PrivateConversationMessage>[];
  }

  @override
  Future<PrivateConversationMessage> send({
    required int recipientId,
    required String text,
  }) async {
    final Object? failure = sendError;

    if (failure != null) {
      throw failure;
    }

    sent.add((recipientId, text));

    return _message(
      id: 'sent-${sent.length}',
      senderId: _viewerId,
      recipientId: recipientId,
      text: text,
      createdAt: DateTime(2026, 8, 26, 12),
    );
  }
}

void main() {
  setUp(() {
    AuthSession.instance.setRestoredSession(
      accessToken: 'jwt-token',
      user: _user(_viewerId, firstName: 'Anna', lastName: 'Rossi'),
    );
  });

  group('PrivateNewsPage', () {
    testWidgets(
      'aprire la sezione pubblica la chiave del dispositivo',
      (WidgetTester tester) async {
        final _FakeMessenger messenger = _FakeMessenger();

        await tester.pumpWidget(
          MaterialApp(home: PrivateNewsPage(messenger: messenger)),
        );

        await tester.pumpAndSettle();

        expect(messenger.reachableCalls, 1);
        expect(
          find.textContaining('configurazione dei messaggi'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'se la chiave non si pubblica compare l’avviso di irraggiungibilità',
      (WidgetTester tester) async {
        final _FakeMessenger messenger = _FakeMessenger(
          reachableThrows: true,
        );

        await tester.pumpWidget(
          MaterialApp(home: PrivateNewsPage(messenger: messenger)),
        );

        await tester.pumpAndSettle();

        expect(
          find.textContaining('configurazione dei messaggi'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'l’inbox viene raggruppata per controparte, più recente in cima',
      (WidgetTester tester) async {
        final _FakeMessenger messenger = _FakeMessenger(
          inboxMessages: <PrivateConversationMessage>[
            _message(
              id: 'm-3',
              senderId: 9,
              recipientId: _viewerId,
              senderName: 'Marco Bianchi',
              text: 'Ultimo in assoluto',
              createdAt: DateTime(2026, 8, 26, 18),
            ),
            _message(
              id: 'm-2',
              senderId: 7,
              recipientId: _viewerId,
              senderName: 'Luca Verdi',
              text: 'Secondo di Luca',
              createdAt: DateTime(2026, 8, 26, 12),
            ),
            _message(
              id: 'm-1',
              senderId: _viewerId,
              recipientId: 7,
              recipientName: 'Luca Verdi',
              text: 'Primo mio',
              createdAt: DateTime(2026, 8, 26, 9),
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(home: PrivateNewsPage(messenger: messenger)),
        );

        await tester.pumpAndSettle();

        expect(find.text('Luca Verdi'), findsOneWidget);
        expect(find.text('Marco Bianchi'), findsOneWidget);
        expect(find.text('Secondo di Luca'), findsOneWidget);
        expect(find.text('Primo mio'), findsNothing);

        final double marco = tester.getTopLeft(find.text('Marco Bianchi')).dy;
        final double luca = tester.getTopLeft(find.text('Luca Verdi')).dy;

        expect(marco, lessThan(luca));
      },
    );

    testWidgets(
      'il selettore esclude sé stessi e apre la conversazione scelta',
      (WidgetTester tester) async {
        final _FakeMessenger messenger = _FakeMessenger();

        await tester.pumpWidget(
          MaterialApp(
            home: PrivateNewsPage(
              messenger: messenger,
              recipientsLoader: () async => <SocialUser>[
                _user(_viewerId, firstName: 'Anna', lastName: 'Rossi'),
                _user(7, firstName: 'Luca', lastName: 'Verdi'),
                _user(9, firstName: 'Marco', lastName: 'Bianchi'),
              ],
            ),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.text('Nuovo messaggio'));
        await tester.pumpAndSettle();

        expect(find.text('Luca Verdi'), findsOneWidget);
        expect(find.text('Marco Bianchi'), findsOneWidget);
        expect(find.text('Anna Rossi'), findsNothing);

        await tester.enterText(find.byType(TextField).first, 'luca');
        await tester.pumpAndSettle();

        expect(find.text('Marco Bianchi'), findsNothing);

        await tester.tap(find.text('Luca Verdi'));
        await tester.pumpAndSettle();

        expect(find.byType(PrivateConversationPage), findsOneWidget);
        expect(messenger.conversationRequests, <int>[7]);
      },
    );

    testWidgets(
      'gli utenti disattivati non sono selezionabili come destinatari',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: PrivateNewsPage(
              messenger: _FakeMessenger(),
              recipientsLoader: () async => <SocialUser>[
                _user(7, firstName: 'Luca', lastName: 'Verdi'),
                _user(
                  9,
                  firstName: 'Marco',
                  lastName: 'Bianchi',
                  isActive: false,
                ),
              ],
            ),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.text('Nuovo messaggio'));
        await tester.pumpAndSettle();

        expect(find.text('Luca Verdi'), findsOneWidget);
        expect(find.text('Marco Bianchi'), findsNothing);
      },
    );
  });

  group('Consegna in attesa', () {
    testWidgets(
      'aprire i messaggi tenta di consegnare quelli in attesa',
      (WidgetTester tester) async {
        final _FakeMessenger messenger = _FakeMessenger();

        await tester.pumpWidget(
          MaterialApp(home: PrivateNewsPage(messenger: messenger)),
        );

        await tester.pumpAndSettle();

        expect(messenger.flushCalls, 1);
      },
    );

    testWidgets(
      'un messaggio non ancora consegnato è marcato come in attesa',
      (WidgetTester tester) async {
        final _FakeMessenger messenger = _FakeMessenger(
          conversationMessages: <PrivateConversationMessage>[
            _message(
              id: 'm-1',
              senderId: _viewerId,
              recipientId: 7,
              recipientName: 'Luca Verdi',
              text: 'Ciao Luca',
              delivery: 'pending',
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: PrivateConversationPage(
              otherUserId: 7,
              otherUserName: 'Luca Verdi',
              messenger: messenger,
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('In attesa'), findsOneWidget);
        expect(
          find.text('Messaggio in attesa di consegna.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'i messaggi già consegnati non mostrano lo stato di attesa',
      (WidgetTester tester) async {
        final _FakeMessenger messenger = _FakeMessenger(
          conversationMessages: <PrivateConversationMessage>[
            _message(
              id: 'm-1',
              senderId: _viewerId,
              recipientId: 7,
              recipientName: 'Luca Verdi',
              text: 'Ciao Luca',
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: PrivateConversationPage(
              otherUserId: 7,
              otherUserName: 'Luca Verdi',
              messenger: messenger,
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('In attesa'), findsNothing);
      },
    );
  });

  group('PrivateConversationPage', () {
    testWidgets('il composer invia il messaggio alla controparte', (
      WidgetTester tester,
    ) async {
      final _FakeMessenger messenger = _FakeMessenger();

      await tester.pumpWidget(
        MaterialApp(
          home: PrivateConversationPage(
            otherUserId: 7,
            otherUserName: 'Luca Verdi',
            messenger: messenger,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Scrivi il primo messaggio'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Ciao Luca');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(messenger.sent, <(int, String)>[(7, 'Ciao Luca')]);
      expect(find.text('Ciao Luca'), findsOneWidget);
      expect(find.textContaining('Scrivi il primo messaggio'), findsNothing);
    });

    testWidgets(
      'se l’invio non riesce l’utente vede un messaggio generico',
      (WidgetTester tester) async {
        final _FakeMessenger messenger = _FakeMessenger(
          sendError: StateError(
            'Invio non disponibile in questo momento. Riprova più tardi.',
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: PrivateConversationPage(
              otherUserId: 7,
              otherUserName: 'Luca Verdi',
              messenger: messenger,
            ),
          ),
        );

        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'Ciao Luca');
        await tester.tap(find.byIcon(Icons.send_rounded));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Invio non disponibile'),
          findsOneWidget,
        );
        expect(messenger.sent, isEmpty);
      },
    );

    testWidgets(
      'I messaggi non leggibili sono segnalati',
      (WidgetTester tester) async {
        final _FakeMessenger messenger = _FakeMessenger(
          conversationMessages: <PrivateConversationMessage>[
            _message(
              id: 'm-1',
              senderId: 7,
              recipientId: _viewerId,
              readable: false,
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            home: PrivateConversationPage(
              otherUserId: 7,
              otherUserName: 'Luca Verdi',
              messenger: messenger,
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.textContaining('non disponibile'),
          findsOneWidget,
        );

        await tester.tap(find.text('Segnala'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Non è possibile segnalare questo messaggio'),
          findsOneWidget,
        );
      },
    );
  });
}
