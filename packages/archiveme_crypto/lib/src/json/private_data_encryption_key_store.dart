import 'dart:math';
import 'dart:typed_data';

import 'package:archiveme_crypto/src/key_material_store.dart';
import 'package:cryptography/cryptography.dart';

/// Stores the local AES key for private JSON files at rest.
///
/// The key lives only in platform secure storage — never in SharedPreferences
/// or plaintext prefs files.
abstract class PrivateDataEncryptionKeyStore {
  Future<List<int>?> readKeyBytes();

  Future<void> writeKeyBytes(List<int> keyBytes);

  Future<void> deleteKey();
}

/// Production key store backed by a [KeyMaterialStore].
///
/// Logical keys: [storageKey] or `private_journal_encryption_key_v1__$keyAlias`.
/// Single stored format: raw 32 bytes. The app's `SecureStorageService`
/// (as [KeyMaterialStore]) persists `base64Encode(bytes)` under `vm_flutter_`
/// + the logical key. There is no v1→v2 payload migration.
class SecurePrivateDataEncryptionKeyStore
    implements PrivateDataEncryptionKeyStore {
  SecurePrivateDataEncryptionKeyStore({
    required KeyMaterialStore store,
    String? keyAlias,
  }) : _store = store,
       _storageKey = keyAlias == null || keyAlias.isEmpty
           ? storageKey
           : 'private_journal_encryption_key_v1__$keyAlias';

  /// Legacy, pre-per-account default alias — kept unchanged so existing
  /// installs continue decrypting their single shared journal without any
  /// key rotation. New per-account namespaces must pass a distinct
  /// [keyAlias] (see `AccountNamespace`) so each account's data is
  /// encrypted with its own key and one account's key material never
  /// decrypts another account's file.
  static const storageKey = 'private_journal_encryption_key_v1';
  static const keyByteLength = 32;

  final KeyMaterialStore _store;
  final String _storageKey;

  @override
  Future<List<int>?> readKeyBytes() async {
    final bytes = await _store.readKey(_storageKey);
    if (bytes == null || bytes.isEmpty) return null;
    return List<int>.from(bytes);
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
    await _store.writeKey(_storageKey, Uint8List.fromList(keyBytes));
  }

  @override
  Future<void> deleteKey() => _store.deleteKey(_storageKey);

  /// Generates and persists a fresh 256-bit key when none exists.
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

/// In-memory key store for unit tests — never persisted to disk.
class InMemoryPrivateDataEncryptionKeyStore
    implements PrivateDataEncryptionKeyStore {
  InMemoryPrivateDataEncryptionKeyStore({List<int>? seedKey})
    : _keyBytes = seedKey;

  List<int>? _keyBytes;

  @override
  Future<List<int>?> readKeyBytes() async =>
      _keyBytes == null ? null : List<int>.from(_keyBytes!);

  @override
  Future<void> writeKeyBytes(List<int> keyBytes) async {
    _keyBytes = List<int>.from(keyBytes);
  }

  @override
  Future<void> deleteKey() async {
    _keyBytes = null;
  }

  Future<List<int>> ensureKey() async {
    final existing = await readKeyBytes();
    if (existing != null &&
        existing.length == SecurePrivateDataEncryptionKeyStore.keyByteLength) {
      return existing;
    }
    final algorithm = AesGcm.with256bits();
    final secretKey = await algorithm.newSecretKey();
    final keyBytes = await secretKey.extractBytes();
    await writeKeyBytes(keyBytes);
    return keyBytes;
  }
}
