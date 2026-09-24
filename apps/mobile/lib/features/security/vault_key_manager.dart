import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archiveme_mobile/security/app_lock_store.dart';
import 'package:cryptography/cryptography.dart';

/// Which password stretching protects a moment payload.
enum VaultKdf { pbkdf2, argon2 }

/// Keeps the database master key in the platform keystore and derives
/// payload keys with PBKDF2 or Argon2.
class VaultKeyManager {
  VaultKeyManager({AppLockSecureStore? store, Random? random})
    : _store = store ?? SecureAppLockStore(),
      _random = random ?? Random.secure();

  static const masterKeyName = 'archive_vault_master_key';
  static const pbkdf2Iterations = 10000;

  final AppLockSecureStore _store;
  final Random _random;

  /// Reads the 256-bit master key, creating it in Keychain or Keystore.
  Future<Uint8List> masterKey() async {
    final existing = await _store.read(masterKeyName);
    if (existing != null && existing.isNotEmpty) {
      return Uint8List.fromList(base64Decode(existing));
    }
    final created = Uint8List.fromList(
      List<int>.generate(32, (_) => _random.nextInt(256)),
    );
    await _store.write(masterKeyName, base64Encode(created));
    return created;
  }

  /// Stretches [passphrase] into a 256-bit key for a moment payload.
  Future<Uint8List> derivePayloadKey({
    required String passphrase,
    required List<int> salt,
    VaultKdf kdf = VaultKdf.pbkdf2,
  }) async {
    final secret = switch (kdf) {
      VaultKdf.pbkdf2 => await Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: pbkdf2Iterations,
        bits: 256,
      ).deriveKeyFromPassword(password: passphrase, nonce: salt),
      VaultKdf.argon2 => await Argon2id(
        parallelism: 1,
        memory: 4096,
        iterations: 2,
        hashLength: 32,
      ).deriveKeyFromPassword(password: passphrase, nonce: salt),
    };
    return Uint8List.fromList(await secret.extractBytes());
  }

  /// Encrypts [plaintext] and returns a JSON envelope.
  Future<String> sealPayload({
    required String plaintext,
    required String passphrase,
    VaultKdf kdf = VaultKdf.pbkdf2,
  }) async {
    final salt = Uint8List.fromList(
      List<int>.generate(16, (_) => _random.nextInt(256)),
    );
    final key = await derivePayloadKey(
      passphrase: passphrase,
      salt: salt,
      kdf: kdf,
    );
    final box = await AesGcm.with256bits().encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(key),
    );
    return jsonEncode({
      'kdf': kdf.name,
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'cipherText': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  /// Opens an envelope from [sealPayload].
  Future<String> openPayload({
    required String envelope,
    required String passphrase,
  }) async {
    final json = jsonDecode(envelope);
    if (json is! Map) {
      throw SecretBoxAuthenticationError();
    }
    final kdf = json['kdf'] == 'argon2' ? VaultKdf.argon2 : VaultKdf.pbkdf2;
    final key = await derivePayloadKey(
      passphrase: passphrase,
      salt: base64Decode('${json['salt']}'),
      kdf: kdf,
    );
    final clear = await AesGcm.with256bits().decrypt(
      SecretBox(
        base64Decode('${json['cipherText']}'),
        nonce: base64Decode('${json['nonce']}'),
        mac: Mac(base64Decode('${json['mac']}')),
      ),
      secretKey: SecretKey(key),
    );
    return utf8.decode(clear);
  }
}
