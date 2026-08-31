import 'dart:convert';
import 'dart:typed_data';

import 'package:archiveme_crypto/src/key_material_store.dart';
import 'package:archiveme_crypto/src/sqlcipher/sqlite_database_encryption_key.dart';

/// Persists the SQLCipher 256-bit database key per account namespace in secure
/// storage. The raw key never enters prefs or the encrypted DB file itself.
abstract class SqliteEncryptionKeyStore {
  Future<SqliteDatabaseEncryptionKey?> readEncryptionKey();

  Future<void> writeEncryptionKey(SqliteDatabaseEncryptionKey key);

  Future<void> deleteEncryptionKey();

  /// Loads an existing key or generates and stores a 256-bit key on first boot.
  ///
  /// This is **not** a v1→v2 write-forward. If a v1 passphrase is present
  /// and v2 is absent, the v1 key is returned and v2 stays absent. Minting
  /// a v2 key here would change the SQLCipher password and lock the user
  /// out of an existing journal (see `v1_only_ensure.json`).
  Future<SqliteDatabaseEncryptionKey> ensureEncryptionKey();

  /// Legacy alias used by `SecureSqliteLockService`.
  Future<String?> readPassphrase() async =>
      (await readEncryptionKey())?.sqlcipherPassword;

  Future<void> writePassphrase(String passphrase) async {
    await writeEncryptionKey(
      SqliteDatabaseEncryptionKey.fromStored(
        base64Encode(utf8.encode(passphrase)),
      ),
    );
  }

  Future<void> deletePassphrase() => deleteEncryptionKey();

  Future<String> ensurePassphrase() async =>
      (await ensureEncryptionKey()).sqlcipherPassword;
}

/// Production SQLCipher key store backed by a [KeyMaterialStore].
///
/// Logical keys: `sqlite_encryption_key_v2` / `sqlite_encryption_passphrase_v1`
/// (+ `__$keyAlias`). Must go through the app's **prefixed**
/// `SecureStorageService` (`vm_flutter_` + logical key). Do **not** route
/// these through the unprefixed vault adapter — that would orphan existing
/// installs the other direction from file 7.
///
/// Read prefers v2, then v1. Write of a v2 key does not delete a leftover
/// v1 slot; write of a v1 key does not delete v2. [ensureEncryptionKey]
/// never writes v2 when v1 is already present.
class SecureSqliteEncryptionKeyStore extends SqliteEncryptionKeyStore {
  SecureSqliteEncryptionKeyStore({
    required KeyMaterialStore store,
    String? keyAlias,
  }) : _store = store,
       _storageKeyV2 = _storageKeyFor(
         version: 2,
         keyAlias: keyAlias ?? '',
       ),
       _storageKeyV1 = _storageKeyFor(
         version: 1,
         keyAlias: keyAlias ?? '',
       );

  static const defaultStorageKeyV2 = 'sqlite_encryption_key_v2';
  static const defaultStorageKeyV1 = 'sqlite_encryption_passphrase_v1';

  final KeyMaterialStore _store;
  final String _storageKeyV2;
  final String _storageKeyV1;

  static String _storageKeyFor({
    required int version,
    required String keyAlias,
  }) {
    final base = version == 2 ? defaultStorageKeyV2 : defaultStorageKeyV1;
    if (keyAlias.isEmpty) return base;
    return '${base}__$keyAlias';
  }

  @override
  Future<void> deleteEncryptionKey() async {
    await _store.deleteKey(_storageKeyV2);
    await _store.deleteKey(_storageKeyV1);
  }

  @override
  Future<SqliteDatabaseEncryptionKey> ensureEncryptionKey() async {
    final existing = await readEncryptionKey();
    if (existing != null) {
      return existing;
    }

    final generated = SqliteDatabaseEncryptionKey.generate();
    await writeEncryptionKey(generated);
    return generated;
  }

  @override
  Future<SqliteDatabaseEncryptionKey?> readEncryptionKey() async {
    final v2 = await _store.readKey(_storageKeyV2);
    if (v2 != null && v2.isNotEmpty) {
      return SqliteDatabaseEncryptionKey.fromStored(base64Encode(v2));
    }

    final v1 = await _store.readKey(_storageKeyV1);
    if (v1 != null && v1.isNotEmpty) {
      return SqliteDatabaseEncryptionKey.fromStored(base64Encode(v1));
    }
    return null;
  }

  @override
  Future<void> writeEncryptionKey(SqliteDatabaseEncryptionKey key) async {
    final raw = key.rawKeyBytes;
    if (raw != null && raw.length == SqliteDatabaseEncryptionKey.keyByteLength) {
      await _store.writeKey(_storageKeyV2, Uint8List.fromList(raw));
      return;
    }

    await _store.writeKey(
      _storageKeyV1,
      Uint8List.fromList(utf8.encode(key.sqlcipherPassword)),
    );
  }
}

class InMemorySqliteEncryptionKeyStore extends SqliteEncryptionKeyStore {
  InMemorySqliteEncryptionKeyStore({SqliteDatabaseEncryptionKey? seed})
    : _key = seed;

  SqliteDatabaseEncryptionKey? _key;

  @override
  Future<void> deleteEncryptionKey() async {
    _key = null;
  }

  @override
  Future<SqliteDatabaseEncryptionKey> ensureEncryptionKey() async {
    _key ??= SqliteDatabaseEncryptionKey.generate();
    return _key!;
  }

  @override
  Future<SqliteDatabaseEncryptionKey?> readEncryptionKey() async => _key;

  @override
  Future<void> writeEncryptionKey(SqliteDatabaseEncryptionKey key) async {
    _key = key;
  }
}
