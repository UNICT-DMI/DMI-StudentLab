import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/device_public_key.dart';
import 'public_key_api_service.dart';

abstract class SecureKeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  const FlutterSecureKeyValueStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) {
    return _storage.read(key: key);
  }

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) {
    return _storage.delete(key: key);
  }
}

class DeviceKeyMaterial {
  final String deviceId;
  final String publicKey;
  final SimpleKeyPair keyPair;

  const DeviceKeyMaterial({
    required this.deviceId,
    required this.publicKey,
    required this.keyPair,
  });
}

class DeviceKeyService {
  DeviceKeyService({
    PublicKeyApiService? api,
    SecureKeyValueStore? store,
    Random? random,
  })  : _api = api ?? PublicKeyApiService(),
        _store = store ?? const FlutterSecureKeyValueStore(),
        _random = random ?? Random.secure();

  static const String algo = 'x25519';

  static const String _deviceIdKey = 'studentlab_device_id';

  static const String _privateSeedKey = 'studentlab_device_private_seed';

  static const int _seedLength = 32;

  final PublicKeyApiService _api;
  final SecureKeyValueStore _store;
  final Random _random;

  final X25519 _algorithm = X25519();

  Future<DeviceKeyMaterial> ensureDeviceKeys() async {
    final String deviceId = await _ensureDeviceId();
    final List<int> seed = await _ensurePrivateSeed();

    final SimpleKeyPair keyPair = await _algorithm.newKeyPairFromSeed(seed);
    final SimplePublicKey publicKey = await keyPair.extractPublicKey();

    return DeviceKeyMaterial(
      deviceId: deviceId,
      publicKey: base64Encode(publicKey.bytes),
      keyPair: keyPair,
    );
  }

  Future<DevicePublicKey> publishDeviceKey({
    String deviceLabel = '',
  }) async {
    final DeviceKeyMaterial material = await ensureDeviceKeys();

    return _api.registerDeviceKey(
      deviceId: material.deviceId,
      publicKey: material.publicKey,
      algo: algo,
      deviceLabel: deviceLabel,
    );
  }

  Future<DevicePublicKey> rotateDeviceKey({
    String deviceLabel = '',
  }) async {
    await _store.delete(_privateSeedKey);

    return publishDeviceKey(
      deviceLabel: deviceLabel,
    );
  }

  Future<DevicePublicKeyListResult> ownDevices() {
    return _api.getOwnDeviceKeys();
  }

  Future<List<DevicePublicKey>> recipientDevices(int userId) async {
    final DevicePublicKeyListResult result =
        await _api.getUserDeviceKeys(userId);

    return result.activeItems
        .where((DevicePublicKey key) => key.algo == algo)
        .toList();
  }

  Future<ComplianceKey> complianceKey() {
    return _api.getComplianceKey();
  }

  Future<void> revokeCurrentDevice() async {
    final String? deviceId = await _store.read(_deviceIdKey);

    if (deviceId == null || deviceId.isEmpty) {
      return;
    }

    await _api.revokeDeviceKey(deviceId);
  }

  Future<void> forgetLocalKeys() async {
    await _store.delete(_privateSeedKey);
    await _store.delete(_deviceIdKey);
  }

  Future<String> _ensureDeviceId() async {
    final String? stored = await _store.read(_deviceIdKey);

    if (stored != null && stored.trim().length >= 8) {
      return stored.trim();
    }

    final String generated = _randomHex(16);

    await _store.write(_deviceIdKey, generated);

    return generated;
  }

  Future<List<int>> _ensurePrivateSeed() async {
    final String? stored = await _store.read(_privateSeedKey);

    if (stored != null && stored.trim().isNotEmpty) {
      try {
        final List<int> decoded = base64Decode(stored.trim());

        if (decoded.length == _seedLength) {
          return decoded;
        }
      } catch (_) {}
    }

    final List<int> seed = List<int>.generate(
      _seedLength,
      (_) => _random.nextInt(256),
    );

    await _store.write(_privateSeedKey, base64Encode(seed));

    return seed;
  }

  String _randomHex(int bytes) {
    final StringBuffer buffer = StringBuffer();

    for (int index = 0; index < bytes; index++) {
      buffer.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }

    return buffer.toString();
  }
}
