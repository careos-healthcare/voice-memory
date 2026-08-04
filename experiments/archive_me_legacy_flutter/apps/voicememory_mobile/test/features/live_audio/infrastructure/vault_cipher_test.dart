import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/live_audio/infrastructure/vault_cipher.dart';

void main() {
  group('VaultCipher', () {
    late VaultCipher cipher;
    late SecretKey secretKey;

    setUp(() {
      cipher = VaultCipher();
      secretKey = SecretKey(List<int>.filled(32, 7));
    });

    test('encryptChunk returns nonce + mac + ciphertext layout', () async {
      const rawBytes = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

      final encrypted = await cipher.encryptChunk(
        rawBytes: rawBytes,
        secretKey: secretKey,
      );

      expect(encrypted.length, greaterThanOrEqualTo(28));
      expect(encrypted.sublist(28), isNot(rawBytes));

      final decrypted = await cipher.decryptChunk(
        encryptedBytes: encrypted,
        secretKey: secretKey,
      );

      expect(decrypted, rawBytes);
    });

    test('decryptChunk rejects payloads shorter than nonce + mac', () async {
      expect(
        () => cipher.decryptChunk(
          encryptedBytes: List<int>.filled(
            VaultCipher.authenticatedOverhead - 1,
            1,
          ),
          secretKey: secretKey,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('encryptVaultFrameRecord preserves on-disk frame layout', () async {
      const rawBytes = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

      final record = await cipher.encryptVaultFrameRecord(
        rawBytes: rawBytes,
        secretKey: secretKey,
      );

      expect(VaultCipher.vaultFrameRecordLength(record, 0), record.length);

      final decrypted = await cipher.decryptVaultFrameRecord(
        encryptedRecordBytes: record,
        secretKey: secretKey,
      );
      expect(decrypted, rawBytes);
    });

    test('decryptChunk rejects tampered mac', () async {
      final encrypted = await cipher.encryptChunk(
        rawBytes: Uint8List.fromList([1, 2, 3, 4]),
        secretKey: secretKey,
      );

      encrypted[13] ^= 0xff;

      expect(
        () => cipher.decryptChunk(
          encryptedBytes: encrypted,
          secretKey: secretKey,
        ),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });

    test('decryptChunk rejects wrong secret key', () async {
      final encrypted = await cipher.encryptChunk(
        rawBytes: [9, 8, 7],
        secretKey: secretKey,
      );

      final wrongKey = SecretKey(List<int>.filled(32, 1));

      expect(
        () =>
            cipher.decryptChunk(encryptedBytes: encrypted, secretKey: wrongKey),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    });
  });
}
