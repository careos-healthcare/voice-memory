import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

/// AES-256-GCM sealing for SQLite database bytes using the `encrypt` package.
///
/// Plaintext layout before encryption: `[database bytes][32-byte SHA-256]`.
/// Wire layout after encryption: `[12-byte IV][ciphertext+GCM tag]`.
final class SqliteVaultCrypto {
  SqliteVaultCrypto(this._keyBytes);

  factory SqliteVaultCrypto.fromKey(Uint8List keyBytes) {
    if (keyBytes.length != keyByteLength) {
      throw ArgumentError.value(
        keyBytes.length,
        'keyBytes.length',
        'expected $keyByteLength bytes',
      );
    }
    return SqliteVaultCrypto(keyBytes);
  }

  static const ivByteLength = 12;
  static const digestByteLength = 32;
  static const keyByteLength = 32;

  final Uint8List _keyBytes;
  final Random _secureRandom = Random.secure();

  /// Returns `[IV || ciphertext]` — only this blob may be transmitted or stored
  /// in iCloud.
  Uint8List sealDatabaseBytes(Uint8List databaseBytes) {
    if (databaseBytes.isEmpty) {
      throw SqliteVaultCryptoException('DATABASE_EMPTY');
    }

    final digest = Uint8List.fromList(sha256.convert(databaseBytes).bytes);
    final plaintext = Uint8List(databaseBytes.length + digestByteLength)
      ..setRange(0, databaseBytes.length, databaseBytes)
      ..setRange(
        databaseBytes.length,
        databaseBytes.length + digestByteLength,
        digest,
      );

    final iv = _randomIv();
    final encrypter = Encrypter(AES(Key(_keyBytes), mode: AESMode.gcm));
    final encrypted = encrypter.encryptBytes(plaintext, iv: IV(iv));

    return Uint8List.fromList([...iv, ...encrypted.bytes]);
  }

  /// Opens a sealed blob and returns verified plaintext database bytes.
  Uint8List openSealedDatabaseBytes(Uint8List sealedBytes) {
    if (sealedBytes.length <= ivByteLength) {
      throw SqliteVaultCryptoException('INVALID_SEALED_BLOB');
    }

    final iv = sealedBytes.sublist(0, ivByteLength);
    final ciphertext = sealedBytes.sublist(ivByteLength);

    final encrypter = Encrypter(AES(Key(_keyBytes), mode: AESMode.gcm));

    late final Uint8List plaintext;
    try {
      plaintext = Uint8List.fromList(
        encrypter.decryptBytes(Encrypted(ciphertext), iv: IV(iv)),
      );
    } on Object {
      throw SqliteVaultCryptoException('DECRYPTION_FAILED');
    }

    if (plaintext.length <= digestByteLength) {
      throw SqliteVaultCryptoException('INVALID_PLAINTEXT_LENGTH');
    }

    final databaseBytes = plaintext.sublist(
      0,
      plaintext.length - digestByteLength,
    );
    final digest = plaintext.sublist(
      plaintext.length - digestByteLength,
      plaintext.length,
    );
    final expected = sha256.convert(databaseBytes).bytes;

    if (!_constantTimeEquals(digest, Uint8List.fromList(expected))) {
      throw SqliteVaultCryptoException('INTEGRITY_CHECK_FAILED');
    }

    return databaseBytes;
  }

  Uint8List _randomIv() {
    return Uint8List.fromList(
      List.generate(ivByteLength, (_) => _secureRandom.nextInt(256)),
    );
  }

  bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

class SqliteVaultCryptoException implements Exception {
  SqliteVaultCryptoException(this.code);
  final String code;

  @override
  String toString() => 'SqliteVaultCryptoException($code)';
}
