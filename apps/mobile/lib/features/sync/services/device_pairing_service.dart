import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the master key may be read after the phone unlocks.
enum MasterKeyKeychainScope {
  /// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Stays on this phone.
  thisDeviceOnly,

  /// Synced iCloud Keychain, available after the first unlock.
  iCloud,
}

/// Maps a scope onto the iOS Keychain flags Flutter secure storage writes.
IOSOptions iosOptionsForMasterKey(MasterKeyKeychainScope scope) {
  switch (scope) {
    case MasterKeyKeychainScope.thisDeviceOnly:
      return const IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
        synchronizable: false,
      );
    case MasterKeyKeychainScope.iCloud:
      return const IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
        synchronizable: true,
      );
  }
}

class PairingExpired implements Exception {
  const PairingExpired();
}

/// A short-lived QR payload that carries the master key to a new phone.
class PairingCode {
  const PairingCode({required this.payload, required this.expiresAt});

  final String payload;
  final DateTime expiresAt;
}

/// Stores the master key in Keychain and moves it with a one-time QR code.
class DevicePairingService {
  DevicePairingService({
    this.scope = MasterKeyKeychainScope.thisDeviceOnly,
    Future<void> Function(String key, String value)? write,
    Future<String?> Function(String key)? read,
    Random? random,
  }) : _write = write,
       _read = read,
       _random = random ?? Random.secure();

  static const storageKey = 'thoughtprint_master_key';
  static const pairingLifetime = Duration(minutes: 2);
  static const _prefix = 'tp-pair:';

  final MasterKeyKeychainScope scope;
  final Future<void> Function(String key, String value)? _write;
  final Future<String?> Function(String key)? _read;
  final Random _random;

  IOSOptions get iosOptions => iosOptionsForMasterKey(scope);

  Future<void> saveMasterKey({
    required List<int> masterKey,
    required List<int> salt,
  }) async {
    final encoded = jsonEncode({
      'masterKey': base64Encode(masterKey),
      'salt': base64Encode(salt),
    });
    final write = _write;
    if (write != null) {
      await write(storageKey, encoded);
      return;
    }
    final box = FlutterSecureStorage(iOptions: iosOptions);
    await box.write(key: storageKey, value: encoded);
  }

  Future<({List<int> masterKey, List<int> salt})?> readMasterKey() async {
    final read = _read;
    final raw = read != null
        ? await read(storageKey)
        : await FlutterSecureStorage(
            iOptions: iosOptions,
          ).read(key: storageKey);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return (
      masterKey: base64Decode(decoded['masterKey'] as String),
      salt: base64Decode(decoded['salt'] as String),
    );
  }

  /// Seals the master key for two minutes. The new phone scans [PairingCode.payload].
  Future<PairingCode> createPairingCode({
    required List<int> masterKey,
    required List<int> salt,
    DateTime? now,
  }) async {
    final issued = (now ?? DateTime.now()).toUtc();
    final expires = issued.add(pairingLifetime);
    final wrap = List<int>.generate(32, (_) => _random.nextInt(256));
    final box = await AesGcm.with256bits().encrypt(
      masterKey,
      secretKey: SecretKey(wrap),
    );
    final body = jsonEncode({
      'v': 1,
      'exp': expires.millisecondsSinceEpoch,
      'nonce': base64Encode(box.nonce),
      'ciphertext': base64Encode([...box.cipherText, ...box.mac.bytes]),
      'wrap': base64Encode(wrap),
      'salt': base64Encode(salt),
    });
    return PairingCode(
      payload: '$_prefix${base64Url.encode(utf8.encode(body))}',
      expiresAt: expires,
    );
  }

  /// Opens a scanned code and stores the master key in Keychain.
  Future<({List<int> masterKey, List<int> salt})> acceptPairingCode(
    String payload, {
    DateTime? now,
  }) async {
    final opened = await _open(payload, now: now ?? DateTime.now());
    await saveMasterKey(masterKey: opened.masterKey, salt: opened.salt);
    return opened;
  }

  @visibleForTesting
  Future<({List<int> masterKey, List<int> salt})> openPairingCode(
    String payload, {
    DateTime? now,
  }) {
    return _open(payload, now: now ?? DateTime.now());
  }

  Future<({List<int> masterKey, List<int> salt})> _open(
    String payload, {
    required DateTime now,
  }) async {
    final trimmed = payload.trim();
    if (!trimmed.startsWith(_prefix)) {
      throw const FormatException('Pairing code was not recognized.');
    }
    final decoded = jsonDecode(
      utf8.decode(base64Url.decode(trimmed.substring(_prefix.length))),
    );
    if (decoded is! Map || decoded['v'] != 1) {
      throw const FormatException('Pairing code was not recognized.');
    }
    final expires = DateTime.fromMillisecondsSinceEpoch(
      decoded['exp'] as int,
      isUtc: true,
    );
    if (!now.toUtc().isBefore(expires)) throw const PairingExpired();
    final wire = base64Decode(decoded['ciphertext'] as String);
    final clear = await AesGcm.with256bits().decrypt(
      SecretBox(
        wire.sublist(0, wire.length - 16),
        nonce: base64Decode(decoded['nonce'] as String),
        mac: Mac(wire.sublist(wire.length - 16)),
      ),
      secretKey: SecretKey(base64Decode(decoded['wrap'] as String)),
    );
    return (masterKey: clear, salt: base64Decode(decoded['salt'] as String));
  }
}
