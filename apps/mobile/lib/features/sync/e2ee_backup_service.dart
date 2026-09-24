import 'dart:math';
import 'dart:typed_data';

import 'package:archiveme_mobile/sync/cloud_backup_models.dart';
import 'package:cryptography/cryptography.dart';

/// AES-GCM payload produced on device. The passphrase never leaves with it.
class E2eeBackupBlob {
  const E2eeBackupBlob({
    required this.salt,
    required this.nonce,
    required this.ciphertext,
    required this.mac,
    required this.iterations,
  });

  final Uint8List salt;
  final Uint8List nonce;
  final Uint8List ciphertext;
  final Uint8List mac;
  final int iterations;

  Uint8List get wireBytes => Uint8List.fromList([
    ...salt,
    ...nonce,
    ...ciphertext,
    ...mac,
  ]);
}

class E2eeBackupException implements Exception {
  const E2eeBackupException(this.code);

  final String code;

  @override
  String toString() => 'E2eeBackupException($code)';
}

/// Encrypts a SQLite backup with a passphrase before any upload runs.
class E2eeBackupService {
  E2eeBackupService({
    this.iterations = CloudBackupFormat.kdfIterations,
    Random? random,
  }) : _random = random ?? Random.secure();

  final int iterations;
  final Random _random;
  final AesGcm _algorithm = AesGcm.with256bits();

  /// Derives a 256-bit key, seals [databaseBytes], then calls [upload].
  ///
  /// [upload] receives only the ciphertext envelope.
  Future<E2eeBackupBlob> backup({
    required Uint8List databaseBytes,
    required String passphrase,
    required Future<void> Function(E2eeBackupBlob blob) upload,
  }) async {
    final blob = await protect(
      databaseBytes: databaseBytes,
      passphrase: passphrase,
    );
    await upload(blob);
    return blob;
  }

  Future<E2eeBackupBlob> protect({
    required Uint8List databaseBytes,
    required String passphrase,
  }) async {
    final key = await _derive(passphrase, salt: _salt());
    final box = await _algorithm.encrypt(
      databaseBytes,
      secretKey: SecretKey(key.bytes),
    );
    return E2eeBackupBlob(
      salt: Uint8List.fromList(key.salt),
      nonce: Uint8List.fromList(box.nonce),
      ciphertext: Uint8List.fromList(box.cipherText),
      mac: Uint8List.fromList(box.mac.bytes),
      iterations: iterations,
    );
  }

  Future<Uint8List> restore({
    required E2eeBackupBlob blob,
    required String passphrase,
  }) async {
    final key = await _derive(passphrase, salt: blob.salt);
    try {
      final clear = await _algorithm.decrypt(
        SecretBox(
          blob.ciphertext,
          nonce: blob.nonce,
          mac: Mac(blob.mac),
        ),
        secretKey: SecretKey(key.bytes),
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const E2eeBackupException('WRONG_PASSPHRASE');
    }
  }

  List<int> _salt() {
    return List<int>.generate(16, (_) => _random.nextInt(256));
  }

  Future<({List<int> bytes, List<int> salt})> _derive(
    String passphrase, {
    required List<int> salt,
  }) async {
    final trimmed = passphrase.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(passphrase, 'passphrase', 'required');
    }
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    final secret = await pbkdf2.deriveKeyFromPassword(
      password: trimmed,
      nonce: salt,
    );
    return (bytes: await secret.extractBytes(), salt: salt);
  }
}
