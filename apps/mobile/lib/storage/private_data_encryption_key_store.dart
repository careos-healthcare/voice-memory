import 'dart:convert';
import 'dart:math';

import 'package:archiveme_mobile/storage/secure_storage.dart';
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

/// Production key store backed by [SecureStorageService].
class SecurePrivateDataEncryptionKeyStore
    implements PrivateDataEncryptionKeyStore {
  SecurePrivateDataEncryptionKeyStore({
    SecureStorageService? secure,
    String? keyAlias,
  }) : _secure = secure ?? SecureStorageService(),
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