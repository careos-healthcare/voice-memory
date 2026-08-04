import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class VaultKeyStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

final class PlatformVaultKeyStore implements VaultKeyStore {
  PlatformVaultKeyStore(FlutterSecureStorage storage) : _storage = storage;
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() =>
      _storage.read(key: VaultKeyProvider.keyStorageAlias);
  @override
  Future<void> write(String value) =>
      _storage.write(key: VaultKeyProvider.keyStorageAlias, value: value);
  @override
  Future<void> delete() =>
      _storage.delete(key: VaultKeyProvider.keyStorageAlias);
}

final class InMemoryVaultKeyStore implements VaultKeyStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    this.value = value;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

/// Secure generation and retrieval of the 256-bit master key for [VaultCipher].
class VaultKeyProvider {
  VaultKeyProvider({
    FlutterSecureStorage? secureStorage,
    VaultKeyStore? keyStore,
    SecretKey? initialKey,
    this._testingKeyBytes,
  }) : _keyStore =
           keyStore ??
           PlatformVaultKeyStore(secureStorage ?? const FlutterSecureStorage()),
       _cachedKey = initialKey;

  static const keyStorageAlias = 'vault_master_aes256_key';
  static const keyByteLength = 32;

  final VaultKeyStore _keyStore;
  final List<int>? _testingKeyBytes;
  SecretKey? _cachedKey;

  /// Stable in-memory provider for unit tests.
  factory VaultKeyProvider.testing({List<int>? keyBytes}) {
    final bytes =
        keyBytes ?? List<int>.generate(keyByteLength, (index) => index + 1);
    if (bytes.length != keyByteLength) {
      throw ArgumentError.value(
        bytes.length,
        'keyBytes.length',
        'expected $keyByteLength bytes',
      );
    }
    return VaultKeyProvider(
      keyStore: InMemoryVaultKeyStore(),
      initialKey: SecretKey(bytes),
      testingKeyBytes: List<int>.from(bytes),
    );
  }

  Future<SecretKey> getOrCreateMasterKey() async {
    if (_cachedKey != null) {
      return _cachedKey!;
    }

    final testingKeyBytes = _testingKeyBytes;
    if (testingKeyBytes != null) {
      _cachedKey = SecretKey(List<int>.from(testingKeyBytes));
      return _cachedKey!;
    }

    final existingHex = await _keyStore.read();
    if (existingHex != null && existingHex.isNotEmpty) {
      final keyBytes = _hexToBytes(existingHex);
      if (keyBytes.length == keyByteLength) {
        _cachedKey = SecretKey(keyBytes);
        return _cachedKey!;
      }
    }

    final newKey = await AesGcm.with256bits().newSecretKey();
    final newBytes = await newKey.extractBytes();
    try {
      await _keyStore.write(_bytesToHex(newBytes));
    } finally {
      newBytes.fillRange(0, newBytes.length, 0);
    }

    _cachedKey = newKey;
    return newKey;
  }

  void clearCache() => _cachedKey = null;

  Future<void> destroyMasterKeyForPrivacyWipe() async {
    _cachedKey = null;
    await _keyStore.delete();
  }

  /// Newly-owned portable bytes; callers must zero them.
  Future<Uint8List> exportMasterKey() async {
    final key = await getOrCreateMasterKey();
    return Uint8List.fromList(await key.extractBytes());
  }

  Future<VaultKeyReplacement> installMasterKey(Uint8List keyBytes) async {
    if (keyBytes.length != keyByteLength) {
      throw ArgumentError.value(
        keyBytes.length,
        'keyBytes.length',
        'expected $keyByteLength bytes',
      );
    }
    Uint8List? previous;
    final encoded = await _keyStore.read();
    if (encoded != null && encoded.isNotEmpty) {
      previous = Uint8List.fromList(_hexToBytes(encoded));
    }
    final installed = Uint8List.fromList(keyBytes);
    try {
      await _keyStore.write(_bytesToHex(installed));
      _cachedKey = SecretKey(List<int>.from(installed));
      return VaultKeyReplacement._(this, previous);
    } finally {
      installed.fillRange(0, installed.length, 0);
      previous?.fillRange(0, previous.length, 0);
    }
  }

  Future<void> rollbackMasterKey(VaultKeyReplacement replacement) async {
    if (!identical(replacement._owner, this) || replacement._consumed) {
      throw StateError('Invalid or already-consumed vault key replacement.');
    }
    replacement._consumed = true;
    final previous = replacement._previous;
    try {
      if (previous == null) {
        await _keyStore.delete();
        _cachedKey = null;
      } else {
        await _keyStore.write(_bytesToHex(previous));
        _cachedKey = SecretKey(List<int>.from(previous));
      }
    } finally {
      previous?.fillRange(0, previous.length, 0);
    }
  }

  void commitMasterKey(VaultKeyReplacement replacement) {
    if (!identical(replacement._owner, this) || replacement._consumed) {
      throw StateError('Invalid or already-consumed vault key replacement.');
    }
    replacement._consumed = true;
    final previous = replacement._previous;
    previous?.fillRange(0, previous.length, 0);
  }

  String _bytesToHex(List<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  List<int> _hexToBytes(String hex) {
    final result = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }
}

final class VaultKeyReplacement {
  VaultKeyReplacement._(this._owner, Uint8List? previous)
    : _previous = previous == null ? null : Uint8List.fromList(previous);

  final VaultKeyProvider _owner;
  final Uint8List? _previous;
  bool _consumed = false;
}
