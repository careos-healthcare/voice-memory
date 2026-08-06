import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Server-compatible encrypted envelope (AES-GCM, version 1).
///
/// Wire format matches web `encryptJsonPayload`: base64 IV + base64 ciphertext
/// where ciphertext includes the 16-byte GCM authentication tag appended.
class EncryptedPayload {
  const EncryptedPayload({
    required this.ciphertext,
    required this.iv,
    this.version = 1,
  });

  final String ciphertext;
  final String iv;
  final int version;

  Map<String, dynamic> toJson() => {
    'ciphertext': ciphertext,
    'iv': iv,
    'version': version,
  };

  factory EncryptedPayload.fromJson(Map<String, dynamic> json) {
    return EncryptedPayload(
      ciphertext: json['ciphertext'] as String? ?? '',
      iv: json['iv'] as String? ?? '',
      version: json['version'] is int ? json['version'] as int : 1,
    );
  }
}

/// Authenticated encryption for sync blobs using the account-scoped master key.
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

class SyncCryptoException implements Exception {
  SyncCryptoException(this.code);
  final String code;
  @override
  String toString() => 'SyncCryptoException($code)';
}
