import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archiveme_mobile/api/models/capture_dto.dart';
import 'package:archiveme_mobile/models/encrypted_payload_dto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

export 'package:archiveme_mobile/models/encrypted_payload_dto.dart';

/// AES-256-GCM encryption for sync payloads. Plaintext never leaves the device
/// unencrypted — callers must encrypt locally before push/sync.
class SyncCrypto {
  SyncCrypto(List<int> masterKeyBytes)
    : _secretKey = SecretKey(masterKeyBytes),
      _algorithm = AesGcm.with256bits();

  final SecretKey _secretKey;
  final AesGcm _algorithm;

  static const int _gcmMacLength = 16;

  /// Metadata binding string — validated client-side before encrypt/decrypt and
  /// mirrored in push envelope fields (account, blob type/id, schema version).
  static String envelopeBinding({
    required String accountNamespace,
    required String blobType,
    required String blobId,
    required int schemaVersion,
  }) => '$accountNamespace|$blobType|$blobId|$schemaVersion';

  /// Canonical JSON string for a [ReflectionDto] (UTF-8 JSON, stable field order
  /// from generated [ReflectionDto.toJson]).
  static String serializeReflectionDto(ReflectionDto reflection) {
    return jsonEncode(reflection.toJson());
  }

  /// Parses JSON produced by [serializeReflectionDto].
  static ReflectionDto deserializeReflectionDto(String jsonString) {
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw SyncCryptoException('INVALID_REFLECTION_JSON');
    }
    return ReflectionDto.fromJson(decoded);
  }

  /// Encrypts [reflection] locally into an [EncryptedPayloadDto] for sync.
  Future<EncryptedPayloadDto> encryptReflection(ReflectionDto reflection) async {
    final envelope = await encryptJson(reflection.toJson());
    return EncryptedPayloadDto.fromDomain(envelope);
  }

  /// Decrypts a synced [EncryptedPayloadDto] back into structured reflection data.
  Future<ReflectionDto> decryptReflection(EncryptedPayloadDto payload) async {
    final map = await decryptJson(payload.toDomain());
    return ReflectionDto.fromJson(map);
  }

  Future<EncryptedPayload> encryptJson(Map<String, dynamic> payload) async {
    final clearText = utf8.encode(jsonEncode(payload));
    final secretBox = await _algorithm.encrypt(
      clearText,
      secretKey: _secretKey,
    );
    final wireBytes = Uint8List.fromList([
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);
    return EncryptedPayload(
      ciphertext: base64Encode(wireBytes),
      iv: base64Encode(secretBox.nonce),
    );
  }

  Future<Map<String, dynamic>> decryptJson(EncryptedPayload envelope) async {
    if (envelope.version != 1) {
      throw SyncCryptoException('UNSUPPORTED_ENCRYPTION_VERSION');
    }
    final wireBytes = base64Decode(envelope.ciphertext);
    if (wireBytes.length <= _gcmMacLength) {
      throw SyncCryptoException('INVALID_ENCRYPTED_ENVELOPE');
    }
    final cipherText = wireBytes.sublist(0, wireBytes.length - _gcmMacLength);
    final macBytes = wireBytes.sublist(wireBytes.length - _gcmMacLength);
    final secretBox = SecretBox(
      cipherText,
      nonce: base64Decode(envelope.iv),
      mac: Mac(macBytes),
    );
    final clearText = await _algorithm.decrypt(
      secretBox,
      secretKey: _secretKey,
    );
    return jsonDecode(utf8.decode(clearText)) as Map<String, dynamic>;
  }
}

/// Account-scoped sync master key persisted in the device keychain / secure
/// enclave via [FlutterSecureStorage]. Never transmitted to the server.
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
  }) : _secureStorage =
           secureStorage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(encryptedSharedPreferences: true),
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.first_unlock_this_device,
             ),
           ),
       _storageKey = 'sync_master_key_v1__$accountNamespace';

  static const keyByteLength = 32;

  final FlutterSecureStorage _secureStorage;
  final String _storageKey;

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

/// High-level helper: loads the secure master key and encrypts/decrypts reflections
/// before any network sync occurs.
class ReflectionEncryptionService {
  ReflectionEncryptionService({required SyncCryptoKeyStore keyStore})
    : _keyStore = keyStore;

  final SyncCryptoKeyStore _keyStore;

  Future<SyncCrypto> _crypto() async {
    final keyBytes = await _keyStore.ensureKey();
    return SyncCrypto(keyBytes);
  }

  Future<EncryptedPayloadDto> encryptReflection(ReflectionDto reflection) async {
    return (await _crypto()).encryptReflection(reflection);
  }

  Future<ReflectionDto> decryptReflection(EncryptedPayloadDto payload) async {
    return (await _crypto()).decryptReflection(payload);
  }
}

class SyncCryptoException implements Exception {
  SyncCryptoException(this.code);
  final String code;
  @override
  String toString() => 'SyncCryptoException($code)';
}
