import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import '../../storage/secure_storage.dart';

/// Account-scoped sync encryption key — never sent to the server in plaintext.
abstract class SyncMasterKeyStore {
  Future<List<int>?> readKeyBytes();

  Future<void> writeKeyBytes(List<int> keyBytes);

  Future<void> deleteKey();

  Future<List<int>> ensureKey();
}

class SecureSyncMasterKeyStore implements SyncMasterKeyStore {
  SecureSyncMasterKeyStore({
    required String accountNamespace,
    SecureStorageService? secure,
  }) : _secure = secure ?? SecureStorageService(),
       _storageKey = 'sync_master_key_v1__$accountNamespace';

  static const keyByteLength = 32;

  final SecureStorageService _secure;
  final String _storageKey;

  @override
  Future<List<int>?> readKeyBytes() async {
    final encoded = await _secure.read(_storageKey);
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
    await _secure.write(_storageKey, base64Encode(keyBytes));
  }

  @override
  Future<void> deleteKey() => _secure.delete(_storageKey);

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

/// In-memory key store for unit tests.
class InMemorySyncMasterKeyStore implements SyncMasterKeyStore {
  List<int>? _keyBytes;

  @override
  Future<void> deleteKey() async {
    _keyBytes = null;
  }

  @override
  Future<List<int>> ensureKey() async {
    if (_keyBytes != null &&
        _keyBytes!.length == SecureSyncMasterKeyStore.keyByteLength) {
      return List<int>.from(_keyBytes!);
    }
    final algorithm = AesGcm.with256bits();
    final secretKey = await algorithm.newSecretKey();
    _keyBytes = await secretKey.extractBytes();
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
