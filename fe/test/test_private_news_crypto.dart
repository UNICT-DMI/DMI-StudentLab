import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fe/services/private_news_crypto.dart';

class Party {
  final String wrapTarget;
  final SimpleKeyPair keyPair;
  final String publicKeyBase64;

  const Party({
    required this.wrapTarget,
    required this.keyPair,
    required this.publicKeyBase64,
  });
}

Future<Party> newParty(String wrapTarget) async {
  final SimpleKeyPair keyPair = await X25519().newKeyPair();
  final SimplePublicKey publicKey = await keyPair.extractPublicKey();

  return Party(
    wrapTarget: wrapTarget,
    keyPair: keyPair,
    publicKeyBase64: base64Encode(publicKey.bytes),
  );
}

void main() {
  final PrivateNewsCryptoService crypto = PrivateNewsCryptoService();

  const String plaintext = 'Ci vediamo in aula 3 alle 15';

  late Party senderDevice;
  late Party senderSecondDevice;
  late Party recipientDevice;
  late Party outsiderDevice;
  late Party compliance;

  late EncryptedPrivateNews encrypted;

  setUp(() async {
    senderDevice = await newParty('7:device-sender-1');
    senderSecondDevice = await newParty('7:device-sender-2');
    recipientDevice = await newParty('3:device-recipient');
    outsiderDevice = await newParty('9:device-outsider');
    compliance = await newParty('compliance:compliance-2026-08');

    encrypted = await crypto.encrypt(
      plaintext: plaintext,
      senderId: 7,
      senderDeviceId: 'device-sender-1',
      recipients: <PrivateNewsRecipient>[
        PrivateNewsRecipient.device(
          userId: 7,
          deviceId: 'device-sender-1',
          publicKeyBase64: senderDevice.publicKeyBase64,
        ),
        PrivateNewsRecipient.device(
          userId: 7,
          deviceId: 'device-sender-2',
          publicKeyBase64: senderSecondDevice.publicKeyBase64,
        ),
        PrivateNewsRecipient.device(
          userId: 3,
          deviceId: 'device-recipient',
          publicKeyBase64: recipientDevice.publicKeyBase64,
        ),
        PrivateNewsRecipient.compliance(
          keyId: 'compliance-2026-08',
          publicKeyBase64: compliance.publicKeyBase64,
        ),
      ],
    );
  });

  test('il payload non contiene il testo in chiaro', () {
    final String serialized = jsonEncode({
      'ciphertext': encrypted.ciphertext,
      'algo': encrypted.algo,
      'metadata': encrypted.metadata,
    });

    expect(serialized.contains('aula 3'), isFalse);
    expect(encrypted.algo, 'x25519-hkdf-sha256+aes-256-gcm');
    expect(encrypted.metadata['v'], 1);
    expect(
      (encrypted.metadata['wrapped_keys'] as Map).keys,
      containsAll(<String>[
        '7:device-sender-1',
        '7:device-sender-2',
        '3:device-recipient',
        'compliance:compliance-2026-08',
      ]),
    );
  });

  test('il destinatario decifra il messaggio', () async {
    final String text = await crypto.decrypt(
      ciphertext: encrypted.ciphertext,
      metadata: encrypted.metadata,
      keyPair: recipientDevice.keyPair,
      wrapTarget: recipientDevice.wrapTarget,
    );

    expect(text, plaintext);
  });

  test('anche il secondo dispositivo del mittente decifra', () async {
    final String text = await crypto.decrypt(
      ciphertext: encrypted.ciphertext,
      metadata: encrypted.metadata,
      keyPair: senderSecondDevice.keyPair,
      wrapTarget: senderSecondDevice.wrapTarget,
    );

    expect(text, plaintext);
  });

  test('un dispositivo estraneo non può decifrare', () async {
    expect(
      crypto.canDecrypt(
        metadata: encrypted.metadata,
        wrapTarget: outsiderDevice.wrapTarget,
      ),
      isFalse,
    );

    await expectLater(
      crypto.decrypt(
        ciphertext: encrypted.ciphertext,
        metadata: encrypted.metadata,
        keyPair: outsiderDevice.keyPair,
        wrapTarget: outsiderDevice.wrapTarget,
      ),
      throwsA(isA<PrivateNewsCryptoException>()),
    );
  });

  test('la chiave di un altro target non sblocca il wrap', () async {
    await expectLater(
      crypto.decrypt(
        ciphertext: encrypted.ciphertext,
        metadata: encrypted.metadata,
        keyPair: outsiderDevice.keyPair,
        wrapTarget: recipientDevice.wrapTarget,
      ),
      throwsA(isA<PrivateNewsCryptoException>()),
    );
  });

  test('la chiave di conformità decifra il messaggio archiviato', () async {
    final String text = await crypto.decrypt(
      ciphertext: encrypted.ciphertext,
      metadata: encrypted.metadata,
      keyPair: compliance.keyPair,
      wrapTarget: compliance.wrapTarget,
    );

    expect(text, plaintext);
  });

  test('la disclosure della CEK permette di verificare il testo segnalato',
      () async {
    final String contentKey = await crypto.discloseContentKey(
      metadata: encrypted.metadata,
      keyPair: recipientDevice.keyPair,
      wrapTarget: recipientDevice.wrapTarget,
    );

    expect(base64Decode(contentKey).length, 32);

    final String verified = await crypto.decryptWithContentKey(
      ciphertext: encrypted.ciphertext,
      metadata: encrypted.metadata,
      contentKeyBase64: contentKey,
    );

    expect(verified, plaintext);
  });

  test('una CEK diversa non decifra il messaggio', () async {
    final String otherKey = base64Encode(
      List<int>.filled(32, 7),
    );

    await expectLater(
      crypto.decryptWithContentKey(
        ciphertext: encrypted.ciphertext,
        metadata: encrypted.metadata,
        contentKeyBase64: otherKey,
      ),
      throwsA(isA<PrivateNewsCryptoException>()),
    );
  });

  test('un ciphertext alterato non supera la verifica di integrità', () async {
    final List<int> raw = base64Decode(encrypted.ciphertext);

    raw[0] = raw[0] ^ 0xFF;

    await expectLater(
      crypto.decrypt(
        ciphertext: base64Encode(raw),
        metadata: encrypted.metadata,
        keyPair: recipientDevice.keyPair,
        wrapTarget: recipientDevice.wrapTarget,
      ),
      throwsA(isA<PrivateNewsCryptoException>()),
    );
  });

  test('alterare il mittente dichiarato invalida il messaggio', () async {
    final Map<String, dynamic> tampered = Map<String, dynamic>.from(
      encrypted.metadata,
    );

    tampered['sender_id'] = 999;

    await expectLater(
      crypto.decrypt(
        ciphertext: encrypted.ciphertext,
        metadata: tampered,
        keyPair: recipientDevice.keyPair,
        wrapTarget: recipientDevice.wrapTarget,
      ),
      throwsA(isA<PrivateNewsCryptoException>()),
    );
  });

  test('ogni messaggio usa una CEK diversa', () async {
    final EncryptedPrivateNews second = await crypto.encrypt(
      plaintext: plaintext,
      senderId: 7,
      senderDeviceId: 'device-sender-1',
      recipients: <PrivateNewsRecipient>[
        PrivateNewsRecipient.device(
          userId: 3,
          deviceId: 'device-recipient',
          publicKeyBase64: recipientDevice.publicKeyBase64,
        ),
      ],
    );

    final String firstKey = await crypto.discloseContentKey(
      metadata: encrypted.metadata,
      keyPair: recipientDevice.keyPair,
      wrapTarget: recipientDevice.wrapTarget,
    );

    final String secondKey = await crypto.discloseContentKey(
      metadata: second.metadata,
      keyPair: recipientDevice.keyPair,
      wrapTarget: recipientDevice.wrapTarget,
    );

    expect(firstKey, isNot(secondKey));
    expect(encrypted.ciphertext, isNot(second.ciphertext));

    await expectLater(
      crypto.decryptWithContentKey(
        ciphertext: second.ciphertext,
        metadata: second.metadata,
        contentKeyBase64: firstKey,
      ),
      throwsA(isA<PrivateNewsCryptoException>()),
    );
  });

  test('senza destinatari la cifratura viene rifiutata', () async {
    await expectLater(
      crypto.encrypt(
        plaintext: plaintext,
        senderId: 7,
        senderDeviceId: 'device-sender-1',
        recipients: const <PrivateNewsRecipient>[],
      ),
      throwsA(isA<PrivateNewsCryptoException>()),
    );
  });
}
