import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

class EncryptedPayload {
  const EncryptedPayload({
    required this.ciphertext,
    required this.nonce,
    required this.mac,
    required this.salt,
  });

  final String ciphertext;
  final String nonce;
  final String mac;
  final String salt;
}

class E2EEncryptionService {
  E2EEncryptionService({Random? random}) : _random = random ?? Random.secure();

  static const iterations = 100000;
  final Random _random;
  final AesGcm _algorithm = AesGcm.with256bits();

  Future<EncryptedPayload> encryptText(
    String plaintext,
    String passphrase,
  ) async {
    final salt = _randomBytes(16);
    final key = await _derive(passphrase, salt);
    final box = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
    );
    return EncryptedPayload(
      ciphertext: base64Encode(box.cipherText),
      nonce: base64Encode(box.nonce),
      mac: base64Encode(box.mac.bytes),
      salt: base64Encode(salt),
    );
  }

  Future<String> decryptText(
    EncryptedPayload payload,
    String passphrase,
  ) async {
    final key = await _derive(passphrase, base64Decode(payload.salt));
    final clear = await _algorithm.decrypt(
      SecretBox(
        base64Decode(payload.ciphertext),
        nonce: base64Decode(payload.nonce),
        mac: Mac(base64Decode(payload.mac)),
      ),
      secretKey: key,
    );
    return utf8.decode(clear);
  }

  Future<SecretKey> _derive(String passphrase, List<int> salt) {
    return Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    ).deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
  }

  List<int> _randomBytes(int length) {
    return List<int>.generate(length, (_) => _random.nextInt(256));
  }
}

