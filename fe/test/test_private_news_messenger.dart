import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/models/device_public_key.dart';
import 'package:fe/services/auth_session.dart';
import 'package:fe/services/device_key_service.dart';
import 'package:fe/services/news_api_service.dart';
import 'package:fe/services/private_news_crypto.dart';
import 'package:fe/services/private_news_messenger.dart';
import 'package:fe/social/news/models/news_board.dart';
import 'package:fe/social/social_models.dart';

class FakeDeviceKeyService extends DeviceKeyService {
  FakeDeviceKeyService({
    required this.material,
    required this.ownKeys,
    required this.recipientKeys,
    required this.compliance,
  });

  final DeviceKeyMaterial material;
  final List<DevicePublicKey> ownKeys;
  final List<DevicePublicKey> recipientKeys;
  final ComplianceKey compliance;

  bool published = false;

  @override
  Future<DeviceKeyMaterial> ensureDeviceKeys() async => material;

  @override
  Future<DevicePublicKey> publishDeviceKey({String deviceLabel = ''}) async {
    published = true;

    return _devicePublicKey(
      userId: 7,
      deviceId: material.deviceId,
      publicKey: material.publicKey,
    );
  }

  @override
  Future<DevicePublicKeyListResult> ownDevices() async {
    return DevicePublicKeyListResult(
      items: ownKeys,
      total: ownKeys.length,
    );
  }

  @override
  Future<List<DevicePublicKey>> recipientDevices(int userId) async {
    return recipientKeys;
  }

  @override
  Future<ComplianceKey> complianceKey() async => compliance;
}

class FakeNewsApiService extends NewsApiService {
  final List<NewsPrivateMessage> stored = <NewsPrivateMessage>[];

  Map<String, dynamic>? lastMetadata;
  String? lastCiphertext;
  String? lastAlgo;
  String? lastDeleteToken;

  @override
  Future<NewsPrivateMessage> sendPrivateNews({
    required int recipientId,
    required String ciphertext,
    required String algo,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    lastCiphertext = ciphertext;
    lastMetadata = metadata;
    lastAlgo = algo;

    final NewsPrivateMessage message = NewsPrivateMessage(
      id: 'msg-${stored.length + 1}',
      conversationId: '3_7',
      senderId: 7,
      recipientId: recipientId,
      algo: algo,
      ciphertext: ciphertext,
      metadata: metadata,
      createdAt: DateTime.utc(2026, 8, 26, 10),
      canDelete: true,
      writeToken: 'token-${stored.length + 1}',
    );

    stored.add(message);

    return message;
  }

  @override
  Future<NewsPrivateMessageListResult> getPrivateConversation({
    required int otherUserId,
    int limit = 30,
    int offset = 0,
  }) async {
    return NewsPrivateMessageListResult(
      items: stored,
      total: stored.length,
    );
  }

  @override
  Future<void> deletePrivateNews({
    required int otherUserId,
    required String newsId,
    String writeToken = '',
  }) async {
    lastDeleteToken = writeToken;

    stored.removeWhere((NewsPrivateMessage item) => item.id == newsId);
  }
}

DevicePublicKey _devicePublicKey({
  required int userId,
  required String deviceId,
  required String publicKey,
}) {
  return DevicePublicKey(
    id: 1,
    userId: userId,
    deviceId: deviceId,
    deviceLabel: '',
    algo: 'x25519',
    publicKey: publicKey,
    createdAt: DateTime.utc(2026, 8, 26),
    rotatedAt: null,
    revokedAt: null,
  );
}

Future<DeviceKeyMaterial> _material(String deviceId) async {
  final SimpleKeyPair keyPair = await X25519().newKeyPair();
  final SimplePublicKey publicKey = await keyPair.extractPublicKey();

  return DeviceKeyMaterial(
    deviceId: deviceId,
    publicKey: base64Encode(publicKey.bytes),
    keyPair: keyPair,
  );
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

void main() {
  final PrivateNewsCryptoService crypto = PrivateNewsCryptoService();

  late DeviceKeyMaterial senderMaterial;
  late DeviceKeyMaterial recipientMaterial;
  late DeviceKeyMaterial complianceMaterial;
  late FakeNewsApiService newsApi;

  setUp(() async {
    senderMaterial = await _material('device-sender-1');
    recipientMaterial = await _material('device-recipient');
    complianceMaterial = await _material('compliance-device');
    newsApi = FakeNewsApiService();

    AuthSession.instance.setRestoredSession(
      accessToken: 'jwt-token',
      user: _user(7),
    );
  });

  FakeDeviceKeyService deviceKeys({
    bool complianceConfigured = true,
    bool recipientHasDevices = true,
  }) {
    return FakeDeviceKeyService(
      material: senderMaterial,
      ownKeys: <DevicePublicKey>[
        _devicePublicKey(
          userId: 7,
          deviceId: senderMaterial.deviceId,
          publicKey: senderMaterial.publicKey,
        ),
      ],
      recipientKeys: recipientHasDevices
          ? <DevicePublicKey>[
              _devicePublicKey(
                userId: 3,
                deviceId: recipientMaterial.deviceId,
                publicKey: recipientMaterial.publicKey,
              ),
            ]
          : <DevicePublicKey>[],
      compliance: ComplianceKey(
        configured: complianceConfigured,
        keyId: complianceConfigured ? 'compliance-2026-08' : '',
        algo: 'x25519',
        publicKey:
            complianceConfigured ? complianceMaterial.publicKey : '',
      ),
    );
  }

  PrivateNewsMessenger messengerWith(
    FakeDeviceKeyService keys, {
    bool requireComplianceWrap = true,
  }) {
    return PrivateNewsMessenger(
      newsApi: newsApi,
      deviceKeys: keys,
      crypto: crypto,
      requireComplianceWrap: requireComplianceWrap,
    );
  }

  test('send cifra per mittente, destinatario e chiave di conformità',
      () async {
    final FakeDeviceKeyService keys = deviceKeys();

    final PrivateConversationMessage sent = await messengerWith(keys).send(
      recipientId: 3,
      text: 'Ci vediamo in aula 3',
    );

    expect(keys.published, isTrue);
    expect(sent.text, 'Ci vediamo in aula 3');
    expect(newsApi.lastAlgo, PrivateNewsCryptoService.algo);
    expect(newsApi.lastCiphertext, isNot(contains('aula')));

    final Map<String, dynamic> wrapped = Map<String, dynamic>.from(
      newsApi.lastMetadata!['wrapped_keys'] as Map,
    );

    expect(
      wrapped.keys,
      containsAll(<String>[
        '7:${senderMaterial.deviceId}',
        '3:${recipientMaterial.deviceId}',
        'compliance:compliance-2026-08',
      ]),
    );
  });

  test('il destinatario decifra il messaggio inviato dal messenger', () async {
    await messengerWith(deviceKeys()).send(
      recipientId: 3,
      text: 'Messaggio riservato',
    );

    final String text = await crypto.decrypt(
      ciphertext: newsApi.lastCiphertext!,
      metadata: newsApi.lastMetadata!,
      keyPair: recipientMaterial.keyPair,
      wrapTarget: '3:${recipientMaterial.deviceId}',
    );

    expect(text, 'Messaggio riservato');
  });

  test('senza chiave di conformità l’invio è bloccato', () async {
    await expectLater(
      messengerWith(
        deviceKeys(
          complianceConfigured: false,
        ),
      ).send(
        recipientId: 3,
        text: 'Messaggio',
      ),
      throwsA(isA<StateError>()),
    );

    expect(newsApi.stored, isEmpty);
  });

  test('la conformità può essere disattivata esplicitamente', () async {
    await messengerWith(
      deviceKeys(
        complianceConfigured: false,
      ),
      requireComplianceWrap: false,
    ).send(
      recipientId: 3,
      text: 'Messaggio',
    );

    final Map<String, dynamic> wrapped = Map<String, dynamic>.from(
      newsApi.lastMetadata!['wrapped_keys'] as Map,
    );

    expect(
      wrapped.keys.any(
        (String key) => key.startsWith(
          PrivateNewsCryptoService.compliancePrefix,
        ),
      ),
      isFalse,
    );
  });

  test(
    'il messaggio è in attesa',
    () async {
      await messengerWith(
        deviceKeys(
          recipientHasDevices: false,
        ),
      ).send(
        recipientId: 3,
        text: 'Messaggio',
      );

      expect(newsApi.stored, hasLength(1));

      final Map<String, dynamic> wrapped = Map<String, dynamic>.from(
        newsApi.lastMetadata!['wrapped_keys'] as Map,
      );

      expect(
        wrapped.keys.any((String key) => key.startsWith('3:')),
        isFalse,
      );

      expect(
        wrapped.keys.any(
          (String key) => key.startsWith(
            PrivateNewsCryptoService.compliancePrefix,
          ),
        ),
        isTrue,
      );
    },
  );

  test('conversation decifra i propri messaggi', () async {
    final PrivateNewsMessenger messenger = messengerWith(deviceKeys());

    await messenger.send(
      recipientId: 3,
      text: 'Primo messaggio',
    );

    final List<PrivateConversationMessage> messages =
        await messenger.conversation(
      otherUserId: 3,
    );

    expect(messages.single.isReadable, isTrue);
    expect(messages.single.text, 'Primo messaggio');
    expect(messages.single.isMine(7), isTrue);
  });

  test('un messaggio non cifrato per il device risulta illeggibile', () async {
    final EncryptedPrivateNews foreign = await crypto.encrypt(
      plaintext: 'Non per te',
      senderId: 3,
      senderDeviceId: recipientMaterial.deviceId,
      recipients: <PrivateNewsRecipient>[
        PrivateNewsRecipient.device(
          userId: 3,
          deviceId: recipientMaterial.deviceId,
          publicKeyBase64: recipientMaterial.publicKey,
        ),
      ],
    );

    newsApi.stored.add(
      NewsPrivateMessage(
        id: 'msg-estraneo',
        conversationId: '3_7',
        senderId: 3,
        recipientId: 7,
        algo: foreign.algo,
        ciphertext: foreign.ciphertext,
        metadata: foreign.metadata,
        createdAt: DateTime.utc(2026, 8, 26, 9),
        canDelete: false,
        writeToken: '',
      ),
    );

    final List<PrivateConversationMessage> messages =
        await messengerWith(deviceKeys()).conversation(
      otherUserId: 3,
    );

    expect(messages.single.isReadable, isFalse);
    expect(messages.single.text, isEmpty);
  });

  test('discloseContentKey produce una CEK che verifica il testo segnalato',
      () async {
    final PrivateNewsMessenger messenger = messengerWith(deviceKeys());

    await messenger.send(
      recipientId: 3,
      text: 'Contenuto da segnalare',
    );

    final List<PrivateConversationMessage> messages =
        await messenger.conversation(
      otherUserId: 3,
    );

    final String contentKey = await messenger.discloseContentKey(
      messages.single,
    );

    final String verified = await crypto.decryptWithContentKey(
      ciphertext: messages.single.raw.ciphertext,
      metadata: messages.single.raw.metadata,
      contentKeyBase64: contentKey,
    );

    expect(verified, 'Contenuto da segnalare');
  });

  test('delete inoltra il write token del messaggio', () async {
    final PrivateNewsMessenger messenger = messengerWith(deviceKeys());

    await messenger.send(
      recipientId: 3,
      text: 'Da eliminare',
    );

    final List<PrivateConversationMessage> messages =
        await messenger.conversation(
      otherUserId: 3,
    );

    await messenger.delete(
      otherUserId: 3,
      message: messages.single,
    );

    expect(newsApi.lastDeleteToken, 'token-1');
    expect(newsApi.stored, isEmpty);
  });

  test('non è possibile inviare un messaggio a se stessi', () async {
    await expectLater(
      messengerWith(deviceKeys()).send(
        recipientId: 7,
        text: 'Messaggio',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}
