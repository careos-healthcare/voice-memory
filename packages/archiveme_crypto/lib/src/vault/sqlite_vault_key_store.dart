import 'dart:math';
import 'dart:typed_data';

import 'package:archiveme_crypto/src/key_material_store.dart';

/// Persists the 256-bit AES vault key in the host key store.
///
/// The key never leaves the host store.
abstract class SqliteVaultKeyStore {
  static const keyByteLength = 32;

  Future<Uint8List?> readKey();

  Future<void> writeKey(Uint8List keyBytes);

  Future<void> deleteKey();

  Future<Uint8List> ensureKey();
}

/// Production vault key store backed by a [KeyMaterialStore].
///
/// Logical key: `sqlite_vault_aes_key_v1__$accountNamespace`. There is no
/// un-namespaced default. Single stored format: raw 32 bytes.
///
/// The host must pass an **unprefixed** [KeyMaterialStore]. A prefixed
/// adapter would write a different physical key and break existing installs.
final class SecureSqliteVaultKeyStore implements SqliteVaultKeyStore {
  SecureSqliteVaultKeyStore({
    required KeyMaterialStore store,
    required String accountNamespace,
  }) : _store = store,
       _storageKey = 'sqlite_vault_aes_key_v1__$accountNamespace';

  /// Logical-key prefix. Physical key == logical key when the host adapter
  /// is unprefixed.
  static const storageKeyPrefix = 'sqlite_vault_aes_key_v1__';

  final KeyMaterialStore _store;
  final String _storageKey;
  final Random _secureRandom = Random.secure();

  @override
  Future<Uint8List?> readKey() async {
    final bytes = await _store.readKey(_storageKey);
    if (bytes == null || bytes.isEmpty) return null;
    return Uint8List.fromList(bytes);
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
    await _store.writeKey(_storageKey, Uint8List.fromList(keyBytes));
  }

  @override
  Future<void> deleteKey() => _store.deleteKey(_storageKey);

  @override
  Future<Uint8List> ensureKey() async {
    final existing = await readKey();
    if (existing != null &&
        existing.length == SqliteVaultKeyStore.keyByteLength) {
      return existing;
    }

    final keyBytes = Uint8List.fromList(
      List.generate(
        SqliteVaultKeyStore.keyByteLength,
        (_) => _secureRandom.nextInt(256),
      ),
    );
    await writeKey(keyBytes);
    return keyBytes;
  }
}

/// In-memory vault key store for unit tests.
///
/// [ensureKey] without a prior write uses a deterministic
/// `List.generate(32, (i) => i)` so pipeline tests stay stable.
final class InMemorySqliteVaultKeyStore implements SqliteVaultKeyStore {
  Uint8List? _keyBytes;

  @override
  Future<void> deleteKey() async {
    _keyBytes = null;
  }

  @override
  Future<Uint8List> ensureKey() async {
    if (_keyBytes != null &&
        _keyBytes!.length == SqliteVaultKeyStore.keyByteLength) {
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
