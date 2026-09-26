import 'dart:convert';
import 'dart:math';

import 'package:archiveme_mobile/core/storage/secure_storage_provider.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Account-scoped sync key persisted in the device keychain. Never sent
/// to the server.
abstract class SyncCryptoKeyStore {
  Future<List<int>?> readKeyBytes();

  Future<void> writeKeyBytes(List<int> keyBytes);

  Future<void> deleteKey();

  Future<List<int>> ensureKey();
}

class SecureSyncCryptoKeyStore implements SyncCryptoKeyStore {
  SecureSyncCryptoKeyStore({
    required String accountNamespace,
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ?? accountKeySecureStorage,
       _storageKey = 'sync_master_key_v1__$accountNamespace';

  static const keyByteLength = 32;

  final FlutterSecureStorage _secureStorage;
  final String _storageKey;

  /// Keychain slot this store reads/writes. Test-only: production code
  /// must go through [readKeyBytes]/[writeKeyBytes]/[ensureKey].
  @visibleForTesting
  String get storageKey => _storageKey;

  @override
  Future<List<int>?> readKeyBytes() async {
    final encoded = await _secureStorage.read(key: _storageKey);
    if (encoded == null || encoded.isEmpty) return null;
    return base64Decode(encoded);
  }

  @override
  Future<void> writeKeyBytes(List<int> keyBytes) async {
    if (keyBytes.length != keyByteLength) {
      throw ArgumentError.value(
        keyBytes.length,
        'keyBytes.length',
        'expected $keyByteLength bytes',
      );
    }
    await _secureStorage.write(
      key: _storageKey,
      value: base64Encode(keyBytes),
    );
  }

  @override
  Future<void> deleteKey() => _secureStorage.delete(key: _storageKey);

  @override
  Future<List<int>> ensureKey() async {
    final existing = await readKeyBytes();
    if (existing != null && existing.length == keyByteLength) {
      return existing;
    }
    final random = Random.secure();
    final keyBytes = List<int>.generate(
      keyByteLength,
      (_) => random.nextInt(256),
    );
    await writeKeyBytes(keyBytes);
    return keyBytes;
  }
}

/// In-memory key store for unit tests (no platform secure storage).
class InMemorySyncCryptoKeyStore implements SyncCryptoKeyStore {
  List<int>? _keyBytes;

  @override
  Future<void> deleteKey() async {
    _keyBytes = null;
  }

  @override
  Future<List<int>> ensureKey() async {
    if (_keyBytes != null &&
        _keyBytes!.length == SecureSyncCryptoKeyStore.keyByteLength) {
      return List<int>.from(_keyBytes!);
    }
    final random = Random.secure();
    _keyBytes = List<int>.generate(
      SecureSyncCryptoKeyStore.keyByteLength,
      (_) => random.nextInt(256),
    );
    return List<int>.from(_keyBytes!);
  }

  @override
  Future<List<int>?> readKeyBytes() async =>
      _keyBytes == null ? null : List<int>.from(_keyBytes!);

  @override
  Future<void> writeKeyBytes(List<int> keyBytes) async {
    _keyBytes = List<int>.from(keyBytes);
  }
}
