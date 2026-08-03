import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

const int syncRecoverySchemaVersion = 1;
const int syncRecoveryPbkdf2Iterations = 310000;

final class SyncRecoveryException implements Exception {
  const SyncRecoveryException(this.code);
  final String code;

  @override
  String toString() => 'SyncRecoveryException($code)';
}

final class SyncRecoveryEnvelope {
  const SyncRecoveryEnvelope({
    required this.schemaVersion,
    required this.kdf,
    required this.kdfIterations,
    required this.algorithm,
    required this.ownerAccountId,
    required this.ownerArchiveId,
    required this.keyEpoch,
    required this.envelopeRevision,
    required this.salt,
    required this.nonce,
    required this.ciphertext,
    required this.mac,
    required this.createdAt,
    required this.updatedAt,
  });

  final int schemaVersion;
  final String kdf;
  final int kdfIterations;
  final String algorithm;
  final String ownerAccountId;
  final String ownerArchiveId;
  final int keyEpoch;
  final int envelopeRevision;
  final String salt;
  final String nonce;
  final String ciphertext;
  final String mac;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'kdf': kdf,
    'kdfIterations': kdfIterations,
    'algorithm': algorithm,
    'ownerAccountId': ownerAccountId,
    'ownerArchiveId': ownerArchiveId,
    'keyEpoch': keyEpoch,
    'envelopeRevision': envelopeRevision,
    'salt': salt,
    'nonce': nonce,
    'ciphertext': ciphertext,
    'mac': mac,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory SyncRecoveryEnvelope.fromJson(Map<String, dynamic> json) {
    try {
      return SyncRecoveryEnvelope(
        schemaVersion: (json['schemaVersion'] as num).toInt(),
        kdf: json['kdf'] as String,
        kdfIterations: (json['kdfIterations'] as num).toInt(),
        algorithm: json['algorithm'] as String,
        ownerAccountId: json['ownerAccountId'] as String,
        ownerArchiveId: json['ownerArchiveId'] as String,
        keyEpoch: (json['keyEpoch'] as num).toInt(),
        envelopeRevision: (json['envelopeRevision'] as num).toInt(),
        salt: json['salt'] as String,
        nonce: json['nonce'] as String,
        ciphertext: json['ciphertext'] as String,
        mac: json['mac'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
        updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      );
    } on Object {
      throw const SyncRecoveryException('invalid_envelope');
    }
  }
}

final class SyncRecoverySetup {
  const SyncRecoverySetup({required this.secret, required this.envelope});
  final String secret;
  final SyncRecoveryEnvelope envelope;
}

/// Uses package implementations of PBKDF2-HMAC-SHA256 and AES-256-GCM.
final class SyncRecoveryCrypto {
  const SyncRecoveryCrypto();

  static final _aes = AesGcm.with256bits();
  static final _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: syncRecoveryPbkdf2Iterations,
    bits: 256,
  );

  Future<SyncRecoverySetup> wrap({
    required List<int> syncKey,
    required String ownerAccountId,
    required String ownerArchiveId,
    required int keyEpoch,
    required int envelopeRevision,
    DateTime? createdAt,
    DateTime? now,
  }) async {
    _validateBinding(ownerAccountId, ownerArchiveId, keyEpoch);
    if (syncKey.length != 32 || envelopeRevision < 1) {
      throw const SyncRecoveryException('invalid_key_material');
    }
    final random = Random.secure();
    final secretBytes = List<int>.generate(32, (_) => random.nextInt(256));
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final nonce = List<int>.generate(12, (_) => random.nextInt(256));
    final timestamp = (now ?? DateTime.now()).toUtc();
    final firstCreatedAt = (createdAt ?? timestamp).toUtc();
    final secret = _formatSecret(secretBytes);
    try {
      final wrappingKey = await _kdf.deriveKey(
        secretKey: SecretKey(secretBytes),
        nonce: salt,
      );
      final metadata = _metadata(
        ownerAccountId: ownerAccountId,
        ownerArchiveId: ownerArchiveId,
        keyEpoch: keyEpoch,
        envelopeRevision: envelopeRevision,
        createdAt: firstCreatedAt,
        updatedAt: timestamp,
      );
      final box = await _aes.encrypt(
        syncKey,
        secretKey: wrappingKey,
        nonce: nonce,
        aad: utf8.encode(metadata),
      );
      return SyncRecoverySetup(
        secret: secret,
        envelope: SyncRecoveryEnvelope(
          schemaVersion: syncRecoverySchemaVersion,
          kdf: 'PBKDF2-HMAC-SHA256',
          kdfIterations: syncRecoveryPbkdf2Iterations,
          algorithm: 'AES-256-GCM',
          ownerAccountId: ownerAccountId,
          ownerArchiveId: ownerArchiveId,
          keyEpoch: keyEpoch,
          envelopeRevision: envelopeRevision,
          salt: base64UrlEncode(salt),
          nonce: base64UrlEncode(nonce),
          ciphertext: base64UrlEncode(box.cipherText),
          mac: base64UrlEncode(box.mac.bytes),
          createdAt: firstCreatedAt,
          updatedAt: timestamp,
        ),
      );
    } finally {
      secretBytes.fillRange(0, secretBytes.length, 0);
    }
  }

  Future<List<int>> unwrap({
    required SyncRecoveryEnvelope envelope,
    required String secret,
    required String expectedAccountId,
    required String expectedArchiveId,
    int? expectedKeyEpoch,
    int? minimumEnvelopeRevision,
  }) async {
    _validateEnvelope(
      envelope,
      expectedAccountId: expectedAccountId,
      expectedArchiveId: expectedArchiveId,
      expectedKeyEpoch: expectedKeyEpoch,
      minimumEnvelopeRevision: minimumEnvelopeRevision,
    );
    final secretBytes = _parseSecret(secret);
    try {
      final salt = _decode(envelope.salt, 16);
      final nonce = _decode(envelope.nonce, 12);
      final ciphertext = _decode(envelope.ciphertext, 32);
      final mac = _decode(envelope.mac, 16);
      final wrappingKey = await _kdf.deriveKey(
        secretKey: SecretKey(secretBytes),
        nonce: salt,
      );
      try {
        return await _aes.decrypt(
          SecretBox(ciphertext, nonce: nonce, mac: Mac(mac)),
          secretKey: wrappingKey,
          aad: utf8.encode(
            _metadata(
              ownerAccountId: envelope.ownerAccountId,
              ownerArchiveId: envelope.ownerArchiveId,
              keyEpoch: envelope.keyEpoch,
              envelopeRevision: envelope.envelopeRevision,
              createdAt: envelope.createdAt,
              updatedAt: envelope.updatedAt,
            ),
          ),
        );
      } on SecretBoxAuthenticationError {
        throw const SyncRecoveryException('authentication_failed');
      }
    } finally {
      secretBytes.fillRange(0, secretBytes.length, 0);
    }
  }

  static String _metadata({
    required String ownerAccountId,
    required String ownerArchiveId,
    required int keyEpoch,
    required int envelopeRevision,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) => jsonEncode({
    'algorithm': 'AES-256-GCM',
    'createdAt': createdAt.toUtc().toIso8601String(),
    'envelopeRevision': envelopeRevision,
    'kdf': 'PBKDF2-HMAC-SHA256',
    'kdfIterations': syncRecoveryPbkdf2Iterations,
    'keyEpoch': keyEpoch,
    'ownerAccountId': ownerAccountId,
    'ownerArchiveId': ownerArchiveId,
    'schemaVersion': syncRecoverySchemaVersion,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  });

  static void _validateEnvelope(
    SyncRecoveryEnvelope envelope, {
    required String expectedAccountId,
    required String expectedArchiveId,
    int? expectedKeyEpoch,
    int? minimumEnvelopeRevision,
  }) {
    if (envelope.schemaVersion != syncRecoverySchemaVersion ||
        envelope.kdf != 'PBKDF2-HMAC-SHA256' ||
        envelope.kdfIterations != syncRecoveryPbkdf2Iterations ||
        envelope.algorithm != 'AES-256-GCM') {
      throw const SyncRecoveryException('unsupported_envelope');
    }
    _validateBinding(
      envelope.ownerAccountId,
      envelope.ownerArchiveId,
      envelope.keyEpoch,
    );
    if (envelope.ownerAccountId != expectedAccountId ||
        envelope.ownerArchiveId != expectedArchiveId) {
      throw const SyncRecoveryException('owner_binding_mismatch');
    }
    if (expectedKeyEpoch != null && envelope.keyEpoch != expectedKeyEpoch) {
      throw const SyncRecoveryException('key_epoch_mismatch');
    }
    if (minimumEnvelopeRevision != null &&
        envelope.envelopeRevision < minimumEnvelopeRevision) {
      throw const SyncRecoveryException('replayed_envelope');
    }
    if (envelope.envelopeRevision < 1 ||
        envelope.updatedAt.isBefore(envelope.createdAt)) {
      throw const SyncRecoveryException('invalid_metadata');
    }
  }

  static void _validateBinding(String account, String archive, int epoch) {
    if (account.trim().isEmpty || archive.trim().isEmpty || epoch < 1) {
      throw const SyncRecoveryException('invalid_owner_binding');
    }
  }

  static List<int> _parseSecret(String value) {
    final normalized = value.replaceAll('.', '').replaceAll(' ', '');
    try {
      final bytes = base64Url.decode(base64Url.normalize(normalized));
      if (bytes.length != 32) throw const FormatException();
      return bytes;
    } on Object {
      throw const SyncRecoveryException('invalid_recovery_secret');
    }
  }

  static String _formatSecret(List<int> bytes) {
    final raw = base64UrlEncode(bytes).replaceAll('=', '');
    return [
      for (var offset = 0; offset < raw.length; offset += 4)
        raw.substring(offset, min(offset + 4, raw.length)),
    ].join('.');
  }

  static List<int> _decode(String value, int expectedLength) {
    try {
      final bytes = base64Url.decode(base64Url.normalize(value));
      if (bytes.length != expectedLength) throw const FormatException();
      return bytes;
    } on Object {
      throw const SyncRecoveryException('invalid_envelope');
    }
  }
}
