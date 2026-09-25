import 'dart:convert';
import 'dart:typed_data';

import 'package:archiveme_mobile/core/crypto/e2e_encryption_service.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = E2EEncryptionService();
  const passphrase = 'correct horse';
  const plaintext = 'private journal line';

  test('encrypt then decrypt returns the original text', () async {
    final payload = await service.encryptText(plaintext, passphrase);
    expect(payload.ciphertext, isNot(contains(plaintext)));
    expect(payload.mac, isNotEmpty);
    expect(payload.salt, isNotEmpty);
    expect(await service.decryptText(payload, passphrase), plaintext);
  });

  test('the wrong passphrase fails the MAC check', () async {
    final payload = await service.encryptText(plaintext, passphrase);
    expect(
      () => service.decryptText(payload, 'wrong passphrase'),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  test('a flipped ciphertext or MAC tag fails decryption', () async {
    final payload = await service.encryptText(plaintext, passphrase);
    final flippedCipher = EncryptedPayload(
      ciphertext: flipBase64Byte(payload.ciphertext),
      nonce: payload.nonce,
      mac: payload.mac,
      salt: payload.salt,
    );
    final flippedMac = EncryptedPayload(
      ciphertext: payload.ciphertext,
      nonce: payload.nonce,
      mac: flipBase64Byte(payload.mac),
      salt: payload.salt,
    );
    expect(
      () => service.decryptText(flippedCipher, passphrase),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
    expect(
      () => service.decryptText(flippedMac, passphrase),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });
}

String flipBase64Byte(String encoded) {
  final bytes = Uint8List.fromList(base64Decode(encoded));
  bytes[0] = bytes[0] ^ 0x01;
  return base64Encode(bytes);
}
