import 'dart:convert';
import 'dart:typed_data';

import 'package:archiveme_mobile/storage/secure_storage.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_database_encryption_key.dart';

/// Persists the SQLCipher 256-bit database key per account namespace in secure
/// storage. The raw key never enters prefs or the encrypted DB file itself.
abstract class SqliteEncryptionKeyStore {
  Future<SqliteDatabaseEncryptionKey?> readEncryptionKey();

  Future<void> writeEncryptionKey(SqliteDatabaseEncryptionKey key);

  Future<void> deleteEncryptionKey();

  /// Loads an existing key or generates and stores a 256-bit key on first boot.
  Future<SqliteDatabaseEncryptionKey> ensureEncryptionKey();

  /// Legacy alias used by [SecureSqliteLockService].
  Future<String?> readPassphrase() async =>
      (await readEncryptionKey())?.sqlcipherPassword;

  Future<void> writePassphrase(String passphrase) async {
    await writeEncryptionKey(SqliteDatabaseEncryptionKey.fromStored(
      base64Encode(utf8.encode(passphrase)),
    ));
  }

  Future<void> deletePassphrase() => deleteEncryptionKey();

  Future<String> ensurePassphrase() async =>
      (await ensureEncryptionKey()).sqlcipherPassword;
}

class SecureSqliteEncryptionKeyStore extends SqliteEncryptionKeyStore {
  SecureSqliteEncryptionKeyStore({
    SecureStorageService? secure,
    String? keyAlias,
  }) : _secure = secure ?? SecureStorageService(),
       _storageKeyV2 = _storageKeyFor(
         version: 2,
         keyAlias: keyAlias ?? '',
       ),
       _storageKeyV1 = _storageKeyFor(
         version: 1,
         keyAlias: keyAlias ?? '',
       );

  static const _defaultStorageKeyV2 = 'sqlite_encryption_key_v2';
  static const _defaultStorageKeyV1 = 'sqlite_encryption_passphrase_v1';

  final SecureStorageService _secure;
  final String _storageKeyV2;
  final String _storageKeyV1;

  static String _storageKeyFor({
    required int version,
    required String keyAlias,
  }) {
    final base = version == 2 ? _defaultStorageKeyV2 : _defaultStorageKeyV1;
    if (keyAlias.isEmpty) return base;
    return '${base}__$keyAlias';
  }

  @override
  Future<void> deleteEncryptionKey() async {
    await _secure.delete(_storageKeyV2);
    await _secure.delete(_storageKeyV1);
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
    final v2 = await _secure.read(_storageKeyV2);
    if (v2 != null && v2.isNotEmpty) {
      return SqliteDatabaseEncryptionKey.fromStored(v2);
    }

    final v1 = await _secure.read(_storageKeyV1);
    if (v1 != null && v1.isNotEmpty) {
      return SqliteDatabaseEncryptionKey.fromStored(v1);
    }
    return null;
  }

  @override
  Future<void> writeEncryptionKey(SqliteDatabaseEncryptionKey key) async {
    final raw = key.rawKeyBytes;
    if (raw != null && raw.length == SqliteDatabaseEncryptionKey.keyByteLength) {
      await _secure.write(_storageKeyV2, base64Encode(raw));
      return;
    }

    await _secure.write(
      _storageKeyV1,
      base64Encode(utf8.encode(key.sqlcipherPassword)),
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
