import 'dart:typed_data';

import 'package:archiveme_crypto/archiveme_crypto.dart';
import 'package:test/test.dart';

void main() {
  Uint8List key({int fill = 0x6a}) =>
      Uint8List.fromList(List<int>.filled(SqliteVaultCrypto.keyByteLength, fill));

  Uint8List dbBytes() => Uint8List.fromList([0x53, 0x51, 0x4c, 0x01, 0x02, 0x03]);

  test('fromKey rejects the wrong length', () {
    expect(
      () => SqliteVaultCrypto.fromKey(Uint8List(16)),
      throwsArgumentError,
    );
  });

  test('seal then open returns the original database bytes', () {
    final crypto = SqliteVaultCrypto.fromKey(key());
    final opened = crypto.openSealedDatabaseBytes(crypto.sealDatabaseBytes(dbBytes()));
    expect(opened, dbBytes());
  });

  test('two seals of the same plaintext differ (random IV)', () {
    final crypto = SqliteVaultCrypto.fromKey(key());
    final a = crypto.sealDatabaseBytes(dbBytes());
    final b = crypto.sealDatabaseBytes(dbBytes());
    expect(a, isNot(b));
    expect(crypto.openSealedDatabaseBytes(a), dbBytes());
    expect(crypto.openSealedDatabaseBytes(b), dbBytes());
  });

  test('sealed blob is IV plus ciphertext (longer than plaintext)', () {
    final sealed = SqliteVaultCrypto.fromKey(key()).sealDatabaseBytes(dbBytes());
    expect(sealed.length, greaterThan(dbBytes().length + SqliteVaultCrypto.ivByteLength));
    expect(sealed.length, greaterThan(SqliteVaultCrypto.ivByteLength));
  });

  test('empty database bytes are rejected', () {
    expect(
      () => SqliteVaultCrypto.fromKey(key()).sealDatabaseBytes(Uint8List(0)),
      throwsA(
        isA<SqliteVaultCryptoException>().having(
          (e) => e.code,
          'code',
          'DATABASE_EMPTY',
        ),
      ),
    );
  });

  test('a blob shorter than one IV is rejected', () {
    expect(
      () => SqliteVaultCrypto.fromKey(key()).openSealedDatabaseBytes(
        Uint8List(SqliteVaultCrypto.ivByteLength),
      ),
      throwsA(
        isA<SqliteVaultCryptoException>().having(
          (e) => e.code,
          'code',
          'INVALID_SEALED_BLOB',
        ),
      ),
    );
  });

  test('flipping a ciphertext byte fails closed', () {
    final crypto = SqliteVaultCrypto.fromKey(key());
    final sealed = crypto.sealDatabaseBytes(dbBytes());
    sealed[sealed.length - 1] ^= 0xff;
    expect(
      () => crypto.openSealedDatabaseBytes(sealed),
      throwsA(
        isA<SqliteVaultCryptoException>().having(
          (e) => e.code,
          'code',
          'DECRYPTION_FAILED',
        ),
      ),
    );
  });

  test('a different key cannot open the blob', () {
    final sealed = SqliteVaultCrypto.fromKey(key(fill: 0x6a)).sealDatabaseBytes(dbBytes());
    expect(
      () => SqliteVaultCrypto.fromKey(key(fill: 0x6b)).openSealedDatabaseBytes(sealed),
      throwsA(isA<SqliteVaultCryptoException>()),
    );
  });
}
