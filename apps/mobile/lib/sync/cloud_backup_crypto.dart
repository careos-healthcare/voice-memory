import 'dart:convert';
import 'dart:math';

import 'package:archiveme_mobile/models/encrypted_payload_dto.dart';
import 'package:archiveme_mobile/sync/cloud_backup_models.dart';
import 'package:archiveme_mobile/sync/record_sync.dart';
import 'package:cryptography/cryptography.dart';

/// Derives backup encryption keys from a user passphrase — never persisted.
abstract final class CloudBackupPassphraseKdf {
  CloudBackupPassphraseKdf._();

  static const saltByteLength = 16;

  static Future<({List<int> keyBytes, String saltBase64})> deriveKey({
    required String passphrase,
    List<int>? saltBytes,
  }) async {
    final trimmed = passphrase.trim();
    if (trimmed.length < 8) {
      throw CloudBackupException('PASSPHRASE_TOO_SHORT');
    }

    final salt = saltBytes ?? _randomSalt();
    if (salt.length != saltByteLength) {
      throw ArgumentError.value(
        salt.length,
        'saltBytes.length',
        'expected $saltByteLength bytes',
      );
    }

    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: CloudBackupFormat.kdfIterations,
      bits: 256,
    );
    final secretKey = await pbkdf2.deriveKeyFromPassword(
      password: trimmed,
      nonce: salt,
    );
    final keyBytes = await secretKey.extractBytes();
    return (keyBytes: keyBytes, saltBase64: base64Encode(salt));
  }

  static List<int> decodeSalt(String saltBase64) {
    final decoded = base64Decode(saltBase64);
    if (decoded.length != saltByteLength) {
      throw CloudBackupException('INVALID_BACKUP_SALT');
    }
    return decoded;
  }

  static List<int> _randomSalt() {
    final random = Random.secure();
    return List<int>.generate(saltByteLength, (_) => random.nextInt(256));
  }
}

/// Encrypts/decrypts drift snapshots with [RecordSync] and a passphrase-derived key.
class CloudBackupCrypto {
  CloudBackupCrypto(this._keyBytes);

  final List<int> _keyBytes;

  static Future<CloudBackupCrypto> fromPassphrase({
    required String passphrase,
    required List<int> saltBytes,
  }) async {
    final derived = await CloudBackupPassphraseKdf.deriveKey(
      passphrase: passphrase,
      saltBytes: saltBytes,
    );
    return CloudBackupCrypto(derived.keyBytes);
  }

  Future<Map<String, dynamic>> encryptSnapshot(
    CloudBackupDriftSnapshot snapshot,
  ) async {
    final payload = snapshot.toJson();
    payload['database_bytes'] = base64Encode(snapshot.databaseBytes);
    return (await RecordSync.sealJson(
      accountKey: _keyBytes,
      plaintext: payload,
    )).toJson();
  }

  Future<CloudBackupDriftSnapshot> decryptSnapshot(
    Map<String, dynamic> encryptedPayload,
  ) async {
    final envelope = EncryptedPayload.fromJson(encryptedPayload);
    final decoded = await RecordSync.openJson(
      accountKey: _keyBytes,
      envelope: envelope,
    );
    final bytesBase64 = decoded['database_bytes'];
    if (bytesBase64 is! String || bytesBase64.isEmpty) {
      throw CloudBackupException('INVALID_ENCRYPTED_PAYLOAD');
    }
    decoded['database_bytes'] = base64Decode(bytesBase64);
    final snapshot = CloudBackupDriftSnapshot.tryParse(decoded);
    if (snapshot == null) {
      throw CloudBackupException('INVALID_SNAPSHOT_PAYLOAD');
    }
    return snapshot;
  }
}
