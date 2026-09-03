import 'dart:convert';
import 'dart:typed_data';

import 'package:archiveme_crypto/archiveme_crypto.dart';
import 'package:test/test.dart';

import 'support/from_stored_vectors.dart';

void main() {
  test('generate produces 32 raw bytes whose password is their base64', () {
    final key = SqliteDatabaseEncryptionKey.generate();
    expect(key.rawKeyBytes, hasLength(SqliteDatabaseEncryptionKey.keyByteLength));
    expect(key.sqlcipherPassword, base64Encode(key.rawKeyBytes!));
    final again = SqliteDatabaseEncryptionKey.generate();
    expect(again.sqlcipherPassword, isNot(key.sqlcipherPassword));
  });

  test('fromStored v2: 32 decoded bytes — password is the stored string', () {
    // Input is the literal, not base64Encode(anything) in this test.
    final key = SqliteDatabaseEncryptionKey.fromStored(v2Stored);
    expect(key.sqlcipherPassword, v2Stored);
    expect(
      key.rawKeyBytes,
      Uint8List.fromList(List<int>.filled(32, v2RawFillByte)),
    );
  });

  test('fromStored v1: longer utf8 passphrase — password is the passphrase', () {
    final key = SqliteDatabaseEncryptionKey.fromStored(v1Stored);
    expect(key.sqlcipherPassword, v1Passphrase);
    expect(key.rawKeyBytes, isNull);
    expect(key.sqlcipherPassword, isNot(v1Stored));
  });

  test('fromStored: 32-byte utf8 payload is v2, not a passphrase', () {
    final key = SqliteDatabaseEncryptionKey.fromStored(
      v2LooksLikePassphraseStored,
    );
    expect(key.sqlcipherPassword, v2LooksLikePassphraseStored);
    expect(key.rawKeyBytes, utf8.encode(v2LooksLikePassphrase));
    expect(key.sqlcipherPassword, isNot(v2LooksLikePassphrase));
  });

  test('fromStored rejects empty and too-short secrets', () {
    expect(() => SqliteDatabaseEncryptionKey.fromStored(''), throwsArgumentError);
    expect(() => SqliteDatabaseEncryptionKey.fromStored('   '), throwsArgumentError);
    expect(
      () => SqliteDatabaseEncryptionKey.fromStored(shortSecretStored),
      throwsA(isA<FormatException>()),
    );
  });

  test('testInstance is a stable 32-byte 0x42 key', () {
    final key = SqliteDatabaseEncryptionKey.testInstance;
    expect(key.rawKeyBytes, List<int>.filled(32, 0x42));
    expect(key.sqlcipherPassword, base64Encode(key.rawKeyBytes!));
  });
}
