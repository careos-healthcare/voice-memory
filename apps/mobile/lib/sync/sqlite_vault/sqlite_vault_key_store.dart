import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the 256-bit AES vault key in the device keychain / secure enclave.
///
/// The key never leaves secure storage and is never uploaded to iCloud.
abstract class SqliteVaultKeyStore {
  static const keyByteLength = 32;

  Future<Uint8List?> readKey();

  Future<void> writeKey(Uint8List keyBytes);

  Future<void> deleteKey();

  Future<Uint8List> ensureKey();
}

final class SecureSqliteVaultKeyStore implements SqliteVaultKeyStore {
  SecureSqliteVaultKeyStore({
    required String accountNamespace,
    FlutterSecureStorage? secureStorage,
  })  : _secureStorage = secureStorage ?? _defaultSecureStorage,
        _storageKey = 'sqlite_vault_aes_key_v1__$accountNamespace';

  static const _defaultSecureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  final FlutterSecureStorage _secureStorage;
  final String _storageKey;
  final Random _secureRandom = Random.secure();

  @override
  Future<Uint8List?> readKey() async {
    final encoded = await _secureStorage.read(key: _storageKey);
    if (encoded == null || encoded.isEmpty) return null;
    return Uint8List.fromList(base64Decode(encoded));
  }

  @override
  Future<void> writeKey(Uint8List keyBytes) async {
    if (keyBytes.length != SqliteVaultKeyStore.keyByteLength) {
      throw ArgumentError.value(
        keyBytes.length,
        'keyBytes.length',
        'expected ${SqliteVaultKeyStore.keyByteLength} bytes',
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
  Future<Uint8List> ensureKey() async {
    final existing = await readKey();
    if (existing != null && existing.length == SqliteVaultKeyStore.keyByteLength) {
      return existing;
    }

    final keyBytes = Uint8List.fromList(
      List.generate(SqliteVaultKeyStore.keyByteLength, (_) => _secureRandom.nextInt(256)),
    );
    await writeKey(keyBytes);
    return keyBytes;
  }
}

/// In-memory vault key store for unit tests.
final class InMemorySqliteVaultKeyStore implements SqliteVaultKeyStore {
  Uint8List? _keyBytes;

  @override
  Future<void> deleteKey() async {
    _keyBytes = null;
  }

  @override
  Future<Uint8List> ensureKey() async {
    if (_keyBytes != null && _keyBytes!.length == SqliteVaultKeyStore.keyByteLength) {
      return Uint8List.fromList(_keyBytes!);
    }
    final keyBytes = Uint8List.fromList(
      List.generate(SqliteVaultKeyStore.keyByteLength, (index) => index),
    );
    _keyBytes = keyBytes;
    return Uint8List.fromList(keyBytes);
  }

  @override
  Future<Uint8List?> readKey() async =>
      _keyBytes == null ? null : Uint8List.fromList(_keyBytes!);

  @override
  Future<void> writeKey(Uint8List keyBytes) async {
    _keyBytes = Uint8List.fromList(keyBytes);
  }
}
