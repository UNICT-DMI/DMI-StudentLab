import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:fe/models/device_public_key.dart';
import 'package:fe/services/auth_session.dart';
import 'package:fe/services/device_key_service.dart';
import 'package:fe/services/public_key_api_service.dart';
import 'package:fe/social/social_models.dart';

class InMemoryKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async {
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
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

Map<String, dynamic> _keyPayload({
  int id = 1,
  int userId = 100,
  String deviceId = 'abcdef1234567890',
  String publicKey = 'AAAA',
  String? revokedAt,
}) {
  return <String, dynamic>{
    'id': id,
    'user_id': userId,
    'device_id': deviceId,
    'device_label': 'Pixel',
    'algo': 'x25519',
    'public_key': publicKey,
    'created_at': '2026-08-26T10:00:00+00:00',
    'rotated_at': null,
    'revoked_at': revokedAt,
  };
}

void main() {
  late InMemoryKeyValueStore store;

  setUp(() {
    store = InMemoryKeyValueStore();

    AuthSession.instance.setRestoredSession(
      accessToken: 'jwt-token',
      user: _user(100),
    );
  });

  DeviceKeyService serviceWith(MockClient client) {
    return DeviceKeyService(
      api: PublicKeyApiService(client: client),
      store: store,
    );
  }

  test('ensureDeviceKeys genera e riusa la stessa identità', () async {
    final DeviceKeyService service = serviceWith(
      MockClient((http.Request request) async {
        return http.Response('{}', 200);
      }),
    );

    final DeviceKeyMaterial first = await service.ensureDeviceKeys();

    expect(first.deviceId.length, 32);
    expect(base64Decode(first.publicKey).length, 32);
    expect(store.values.containsKey('studentlab_device_id'), isTrue);
    expect(
      base64Decode(store.values['studentlab_device_private_seed']!).length,
      32,
    );

    final DeviceKeyMaterial second = await service.ensureDeviceKeys();

    expect(second.deviceId, first.deviceId);
    expect(second.publicKey, first.publicKey);
  });

  test('la chiave privata resta locale e produce un segreto condiviso valido',
      () async {
    final DeviceKeyService service = serviceWith(
      MockClient((http.Request request) async {
        return http.Response('{}', 200);
      }),
    );

    final DeviceKeyMaterial material = await service.ensureDeviceKeys();

    final X25519 algorithm = X25519();
    final SimpleKeyPair peer = await algorithm.newKeyPair();
    final SimplePublicKey peerPublicKey = await peer.extractPublicKey();

    final SecretKey fromDevice = await algorithm.sharedSecretKey(
      keyPair: material.keyPair,
      remotePublicKey: peerPublicKey,
    );

    final SecretKey fromPeer = await algorithm.sharedSecretKey(
      keyPair: peer,
      remotePublicKey: SimplePublicKey(
        base64Decode(material.publicKey),
        type: KeyPairType.x25519,
      ),
    );

    expect(
      await fromDevice.extractBytes(),
      await fromPeer.extractBytes(),
    );
  });

  test('publishDeviceKey invia device_id, algo e chiave pubblica', () async {
    http.Request? captured;

    final DeviceKeyService service = serviceWith(
      MockClient((http.Request request) async {
        captured = request;

        return http.Response(
          jsonEncode(_keyPayload()),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final DevicePublicKey published = await service.publishDeviceKey(
      deviceLabel: '  Pixel  ',
    );

    expect(captured?.method, 'POST');
    expect(captured?.url.path, '/me/public-keys');
    expect(captured?.headers['Authorization'], 'Bearer jwt-token');

    final Map<String, dynamic> body =
        jsonDecode(captured!.body) as Map<String, dynamic>;

    expect(body['algo'], 'x25519');
    expect(body['device_label'], 'Pixel');
    expect(body['device_id'], store.values['studentlab_device_id']);
    expect(base64Decode(body['public_key'] as String).length, 32);

    expect(published.deviceId, 'abcdef1234567890');
    expect(published.isActive, isTrue);
  });

  test('rotateDeviceKey sostituisce il seed mantenendo il device_id', () async {
    final DeviceKeyService service = serviceWith(
      MockClient((http.Request request) async {
        return http.Response(
          jsonEncode(_keyPayload()),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final DeviceKeyMaterial before = await service.ensureDeviceKeys();
    final String seedBefore = store.values['studentlab_device_private_seed']!;

    await service.rotateDeviceKey();

    final DeviceKeyMaterial after = await service.ensureDeviceKeys();

    expect(after.deviceId, before.deviceId);
    expect(store.values['studentlab_device_private_seed'], isNot(seedBefore));
    expect(after.publicKey, isNot(before.publicKey));
  });

  test('recipientDevices scarta i dispositivi revocati', () async {
    final DeviceKeyService service = serviceWith(
      MockClient((http.Request request) async {
        expect(request.url.path, '/users/3/public-keys');

        return http.Response(
          jsonEncode({
            'items': [
              _keyPayload(
                id: 1,
                userId: 3,
                deviceId: 'device-attivo-01',
              ),
              _keyPayload(
                id: 2,
                userId: 3,
                deviceId: 'device-revocato',
                revokedAt: '2026-08-26T11:00:00+00:00',
              ),
            ],
            'total': 2,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final List<DevicePublicKey> devices = await service.recipientDevices(3);

    expect(devices.length, 1);
    expect(devices.single.deviceId, 'device-attivo-01');
    expect(devices.single.wrapTarget, '3:device-attivo-01');
  });

  test('complianceKey segnala quando la chiave non è configurata', () async {
    final DeviceKeyService service = serviceWith(
      MockClient((http.Request request) async {
        expect(request.url.path, '/crypto/compliance-key');

        return http.Response(
          jsonEncode({
            'configured': false,
            'key_id': '',
            'algo': 'x25519',
            'public_key': '',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final ComplianceKey key = await service.complianceKey();

    expect(key.configured, isFalse);
    expect(key.isUsable, isFalse);
  });

  test('forgetLocalKeys cancella identità e seed', () async {
    final DeviceKeyService service = serviceWith(
      MockClient((http.Request request) async {
        return http.Response('{}', 200);
      }),
    );

    await service.ensureDeviceKeys();

    expect(store.values, isNotEmpty);

    await service.forgetLocalKeys();

    expect(store.values, isEmpty);
  });

  test('un device_id non valido viene rifiutato dal client', () async {
    final PublicKeyApiService api = PublicKeyApiService(
      client: MockClient((http.Request request) async {
        return http.Response('{}', 201);
      }),
    );

    await expectLater(
      api.registerDeviceKey(
        deviceId: 'corto',
        publicKey: 'AAAA',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });
}
