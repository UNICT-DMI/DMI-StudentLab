import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

class PrivateNewsRecipient {
  final String wrapTarget;
  final List<int> publicKey;

  const PrivateNewsRecipient({
    required this.wrapTarget,
    required this.publicKey,
  });

  factory PrivateNewsRecipient.device({
    required int userId,
    required String deviceId,
    required String publicKeyBase64,
  }) {
    return PrivateNewsRecipient(
      wrapTarget: '$userId:$deviceId',
      publicKey: base64Decode(publicKeyBase64),
    );
  }

  factory PrivateNewsRecipient.compliance({
    required String keyId,
    required String publicKeyBase64,
  }) {
    return PrivateNewsRecipient(
      wrapTarget:
          '${PrivateNewsCryptoService.compliancePrefix}${keyId.isEmpty ? 'default' : keyId}',
      publicKey: base64Decode(publicKeyBase64),
    );
  }
}

class EncryptedPrivateNews {
  final String ciphertext;
  final String algo;
  final Map<String, dynamic> metadata;

  const EncryptedPrivateNews({
    required this.ciphertext,
    required this.algo,
    required this.metadata,
  });
}

class PrivateNewsCryptoException implements Exception {
  final String message;

  const PrivateNewsCryptoException(this.message);

  @override
  String toString() => message;
}

class PrivateNewsCryptoService {
  PrivateNewsCryptoService({
    Random? random,
  }) : _random = random ?? Random.secure();

  static const String algo = 'x25519-hkdf-sha256+aes-256-gcm';

  static const String kexAlgo = 'x25519-hkdf-sha256';

  static const String cekAlgo = 'aes-256-gcm';

  static const String compliancePrefix = 'compliance:';

  static const int formatVersion = 1;

  static const int _contentKeyLength = 32;

  static const int _nonceLength = 12;

  static const int _saltLength = 16;

  final Random _random;

  final X25519 _keyExchange = X25519();

  final AesGcm _cipher = AesGcm.with256bits();

  final Hkdf _kdf = Hkdf(
    hmac: Hmac.sha256(),
    outputLength: 32,
  );

  Future<EncryptedPrivateNews> encrypt({
    required String plaintext,
    required int senderId,
    required String senderDeviceId,
    required List<PrivateNewsRecipient> recipients,
  }) async {
    if (plaintext.trim().isEmpty) {
      throw const PrivateNewsCryptoException(
        'Il messaggio non può essere vuoto.',
      );
    }

    if (recipients.isEmpty) {
      throw const PrivateNewsCryptoException(
        'Nessun destinatario disponibile per la cifratura.',
      );
    }

    final List<int> contentKey = _randomBytes(_contentKeyLength);
    final List<int> nonce = _randomBytes(_nonceLength);

    final List<int> aad = _associatedData(
      senderId: senderId,
      senderDeviceId: senderDeviceId,
    );

    final SecretBox box = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(contentKey),
      nonce: nonce,
      aad: aad,
    );

    final Map<String, dynamic> wrappedKeys = <String, dynamic>{};

    for (final PrivateNewsRecipient recipient in recipients) {
      wrappedKeys[recipient.wrapTarget] = await _wrapContentKey(
        contentKey: contentKey,
        recipient: recipient,
      );
    }

    return EncryptedPrivateNews(
      ciphertext: base64Encode(
        <int>[...box.cipherText, ...box.mac.bytes],
      ),
      algo: algo,
      metadata: <String, dynamic>{
        'v': formatVersion,
        'kex_alg': kexAlgo,
        'cek_alg': cekAlgo,
        'nonce': base64Encode(nonce),
        'sender_id': senderId,
        'sender_device': senderDeviceId,
        'wrapped_keys': wrappedKeys,
      },
    );
  }

  Future<String> decrypt({
    required String ciphertext,
    required Map<String, dynamic> metadata,
    required SimpleKeyPair keyPair,
    required String wrapTarget,
  }) async {
    final List<int> contentKey = await _unwrapContentKey(
      metadata: metadata,
      keyPair: keyPair,
      wrapTarget: wrapTarget,
    );

    return decryptWithContentKey(
      ciphertext: ciphertext,
      metadata: metadata,
      contentKeyBase64: base64Encode(contentKey),
    );
  }

  Future<String> decryptWithContentKey({
    required String ciphertext,
    required Map<String, dynamic> metadata,
    required String contentKeyBase64,
  }) async {
    final List<int> contentKey = base64Decode(contentKeyBase64);

    if (contentKey.length != _contentKeyLength) {
      throw const PrivateNewsCryptoException(
        'Chiave del messaggio non valida.',
      );
    }

    final List<int> raw = base64Decode(ciphertext);
    final int macLength = _cipher.macAlgorithm.macLength;

    if (raw.length <= macLength) {
      throw const PrivateNewsCryptoException(
        'Messaggio cifrato incompleto.',
      );
    }

    final SecretBox box = SecretBox(
      raw.sublist(0, raw.length - macLength),
      nonce: _requiredBytes(metadata['nonce'], 'nonce'),
      mac: Mac(raw.sublist(raw.length - macLength)),
    );

    try {
      final List<int> clear = await _cipher.decrypt(
        box,
        secretKey: SecretKey(contentKey),
        aad: _associatedData(
          senderId: _toInt(metadata['sender_id']) ?? 0,
          senderDeviceId: metadata['sender_device']?.toString() ?? '',
        ),
      );

      return utf8.decode(clear);
    } on SecretBoxAuthenticationError {
      throw const PrivateNewsCryptoException(
        'Il messaggio non supera la verifica di integrità.',
      );
    }
  }

  Future<Map<String, dynamic>> wrapContentKeyForRecipients({
    required String contentKeyBase64,
    required List<PrivateNewsRecipient> recipients,
  }) async {
    if (recipients.isEmpty) {
      throw const PrivateNewsCryptoException(
        'Nessun destinatario disponibile per la cifratura.',
      );
    }

    final List<int> contentKey = base64Decode(contentKeyBase64);

    if (contentKey.length != _contentKeyLength) {
      throw const PrivateNewsCryptoException(
        'Chiave del messaggio non valida.',
      );
    }

    final Map<String, dynamic> wrappedKeys = <String, dynamic>{};

    for (final PrivateNewsRecipient recipient in recipients) {
      wrappedKeys[recipient.wrapTarget] = await _wrapContentKey(
        contentKey: contentKey,
        recipient: recipient,
      );
    }

    return wrappedKeys;
  }

  Future<String> discloseContentKey({
    required Map<String, dynamic> metadata,
    required SimpleKeyPair keyPair,
    required String wrapTarget,
  }) async {
    final List<int> contentKey = await _unwrapContentKey(
      metadata: metadata,
      keyPair: keyPair,
      wrapTarget: wrapTarget,
    );

    return base64Encode(contentKey);
  }

  bool canDecrypt({
    required Map<String, dynamic> metadata,
    required String wrapTarget,
  }) {
    final dynamic wrapped = metadata['wrapped_keys'];

    return wrapped is Map && wrapped[wrapTarget] is Map;
  }

  Future<Map<String, dynamic>> _wrapContentKey({
    required List<int> contentKey,
    required PrivateNewsRecipient recipient,
  }) async {
    if (recipient.publicKey.length != _contentKeyLength) {
      throw PrivateNewsCryptoException(
        'Chiave pubblica non valida per ${recipient.wrapTarget}.',
      );
    }

    final SimpleKeyPair ephemeral = await _keyExchange.newKeyPair();
    final SimplePublicKey ephemeralPublicKey =
        await ephemeral.extractPublicKey();

    final List<int> salt = _randomBytes(_saltLength);
    final List<int> nonce = _randomBytes(_nonceLength);

    final SecretKey wrappingKey = await _wrappingKey(
      keyPair: ephemeral,
      remotePublicKey: SimplePublicKey(
        recipient.publicKey,
        type: KeyPairType.x25519,
      ),
      salt: salt,
      wrapTarget: recipient.wrapTarget,
    );

    final SecretBox box = await _cipher.encrypt(
      contentKey,
      secretKey: wrappingKey,
      nonce: nonce,
    );

    return <String, dynamic>{
      'epk': base64Encode(ephemeralPublicKey.bytes),
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'ct': base64Encode(
        <int>[...box.cipherText, ...box.mac.bytes],
      ),
    };
  }

  Future<List<int>> _unwrapContentKey({
    required Map<String, dynamic> metadata,
    required SimpleKeyPair keyPair,
    required String wrapTarget,
  }) async {
    final dynamic wrapped = metadata['wrapped_keys'];

    if (wrapped is! Map) {
      throw const PrivateNewsCryptoException(
        'Metadati di cifratura assenti.',
      );
    }

    final dynamic entry = wrapped[wrapTarget];

    if (entry is! Map) {
      throw PrivateNewsCryptoException(
        'Questo messaggio non è cifrato per $wrapTarget.',
      );
    }

    final Map<String, dynamic> wrap = Map<String, dynamic>.from(entry);

    final SecretKey wrappingKey = await _wrappingKey(
      keyPair: keyPair,
      remotePublicKey: SimplePublicKey(
        _requiredBytes(wrap['epk'], 'epk'),
        type: KeyPairType.x25519,
      ),
      salt: _requiredBytes(wrap['salt'], 'salt'),
      wrapTarget: wrapTarget,
    );

    final List<int> raw = _requiredBytes(wrap['ct'], 'ct');
    final int macLength = _cipher.macAlgorithm.macLength;

    if (raw.length <= macLength) {
      throw const PrivateNewsCryptoException(
        'Chiave del messaggio incompleta.',
      );
    }

    try {
      return await _cipher.decrypt(
        SecretBox(
          raw.sublist(0, raw.length - macLength),
          nonce: _requiredBytes(wrap['nonce'], 'nonce'),
          mac: Mac(raw.sublist(raw.length - macLength)),
        ),
        secretKey: wrappingKey,
      );
    } on SecretBoxAuthenticationError {
      throw const PrivateNewsCryptoException(
        'Impossibile sbloccare la chiave del messaggio.',
      );
    }
  }

  Future<SecretKey> _wrappingKey({
    required SimpleKeyPair keyPair,
    required SimplePublicKey remotePublicKey,
    required List<int> salt,
    required String wrapTarget,
  }) async {
    final SecretKey shared = await _keyExchange.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: remotePublicKey,
    );

    return _kdf.deriveKey(
      secretKey: shared,
      nonce: salt,
      info: utf8.encode('studentlab-private-news-wrap-v1:$wrapTarget'),
    );
  }

  List<int> _associatedData({
    required int senderId,
    required String senderDeviceId,
  }) {
    return utf8.encode(
      'studentlab-private-news-v$formatVersion|$senderId|$senderDeviceId',
    );
  }

  List<int> _requiredBytes(dynamic value, String field) {
    final String text = value?.toString().trim() ?? '';

    if (text.isEmpty) {
      throw PrivateNewsCryptoException(
        'Campo di cifratura mancante: $field.',
      );
    }

    try {
      return base64Decode(text);
    } catch (_) {
      throw PrivateNewsCryptoException(
        'Campo di cifratura non valido: $field.',
      );
    }
  }

  List<int> _randomBytes(int length) {
    return List<int>.generate(
      length,
      (_) => _random.nextInt(256),
    );
  }

  int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }
}
