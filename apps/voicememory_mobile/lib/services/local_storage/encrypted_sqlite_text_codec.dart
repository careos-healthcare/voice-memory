import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

typedef SqliteEncryptionKeyProvider = Uint8List Function();

/// Synchronous authenticated field encryption for SQLite text columns.
///
/// The database can continue to use SQLite transactions while sensitive
/// values remain opaque on disk. Key bytes are requested per operation and
/// are never retained by this codec.
class EncryptedSqliteTextCodec {
  const EncryptedSqliteTextCodec(this._keyProvider);

  static const _prefix = 'vault:v1:';
  final SqliteEncryptionKeyProvider _keyProvider;

  String? encode(String? value) {
    if (value == null || value.isEmpty || value.startsWith(_prefix)) {
      return value;
    }
    final key = _keyProvider();
    try {
      if (key.length != 32) throw StateError('Vault key must be 256 bits.');
      final random = Random.secure();
      final nonce = Uint8List.fromList(
        List<int>.generate(12, (_) => random.nextInt(256)),
      );
      final cipher = GCMBlockCipher(AESEngine())
        ..init(
          true,
          AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)),
        );
      final encrypted = cipher.process(Uint8List.fromList(utf8.encode(value)));
      return '$_prefix${base64Encode([...nonce, ...encrypted])}';
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }

  String? decode(String? value) {
    if (value == null || value.isEmpty || !value.startsWith(_prefix)) {
      return value;
    }
    final key = _keyProvider();
    try {
      final payload = base64Decode(value.substring(_prefix.length));
      if (payload.length <= 28) {
        throw const FormatException('Invalid vault field');
      }
      final nonce = Uint8List.fromList(payload.sublist(0, 12));
      final cipherText = Uint8List.fromList(payload.sublist(12));
      final cipher = GCMBlockCipher(AESEngine())
        ..init(
          false,
          AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)),
        );
      return utf8.decode(cipher.process(cipherText));
    } on InvalidCipherTextException {
      throw StateError('SQLite vault field authentication failed.');
    } finally {
      key.fillRange(0, key.length, 0);
    }
  }
}
