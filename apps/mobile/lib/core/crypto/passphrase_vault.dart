import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SaltStore {
  SaltStore({Map<String, String>? memory})
    : _memory = memory ?? {},
      _read = null,
      _write = null;

  SaltStore.backed({
    required Future<String?> Function(String key) read,
    required Future<void> Function(String key, String value) write,
  }) : _memory = {},
       _read = read,
       _write = write;

  final Map<String, String> _memory;
  final Future<String?> Function(String key)? _read;
  final Future<void> Function(String key, String value)? _write;

  static SaltStore secureStorage({FlutterSecureStorage? storage}) {
    final box = storage ?? const FlutterSecureStorage();
    return SaltStore.backed(
      read: (key) => box.read(key: key),
      write: (key, value) => box.write(key: key, value: value),
    );
  }

  Future<String?> read(String key) {
    final backed = _read;
    if (backed != null) return backed(key);
    return Future.value(_memory[key]);
  }

  Future<void> write(String key, String value) {
    final backed = _write;
    if (backed != null) return backed(key, value);
    _memory[key] = value;
    return Future.value();
  }
}

class CiphertextBlob {
  const CiphertextBlob({
    required this.ciphertext,
    required this.nonce,
    required this.salt,
  });

  final String ciphertext;
  final String nonce;
  final String salt;
}

/// AES-256-GCM with a key derived from a passphrase and a random salt.
class PassphraseVault {
  PassphraseVault._(this._secretKey, this.salt);

  final SecretKey _secretKey;
  final List<int> salt;
  static const iterations = 10000;

  static Future<PassphraseVault> open({
    required String passphrase,
    required SaltStore store,
    String saltKey = 'e2ee_salt',
  }) async {
    final existing = await store.read(saltKey);
    final salt = existing == null
        ? _randomSalt()
        : base64Decode(existing);
    if (existing == null) {
      await store.write(saltKey, base64Encode(salt));
    }
    final secret = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    ).deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
    return PassphraseVault._(secret, salt);
  }

  static List<int> _randomSalt() {
    final random = Random.secure();
    return List<int>.generate(16, (_) => random.nextInt(256));
  }

  Future<CiphertextBlob> encrypt(List<int> plaintext) async {
    final box = await AesGcm.with256bits().encrypt(
      plaintext,
      secretKey: _secretKey,
    );
    return CiphertextBlob(
      ciphertext: base64Encode([...box.cipherText, ...box.mac.bytes]),
      nonce: base64Encode(box.nonce),
      salt: base64Encode(salt),
    );
  }

  Future<List<int>> decrypt(CiphertextBlob blob) async {
    final wire = base64Decode(blob.ciphertext);
    final cipherText = wire.sublist(0, wire.length - 16);
    final mac = wire.sublist(wire.length - 16);
    return AesGcm.with256bits().decrypt(
      SecretBox(cipherText, nonce: base64Decode(blob.nonce), mac: Mac(mac)),
      secretKey: _secretKey,
    );
  }
}
