import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SyncEncryptionKey {
  SyncEncryptionKey(List<int> bytes) : bytes = Uint8List.fromList(bytes) {
    if (this.bytes.length != 32) {
      throw ArgumentError.value(bytes.length, 'bytes', 'Expected 32 bytes.');
    }
  }

  final Uint8List bytes;

  void destroy() => bytes.fillRange(0, bytes.length, 0);
}

abstract class SyncIdentityStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class PlatformSyncIdentityStore implements SyncIdentityStore {
  PlatformSyncIdentityStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _storage;
  static const _prefix = 'vm_e2ee_sync_';

  @override
  Future<String?> read(String key) => _storage.read(key: '$_prefix$key');

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: '$_prefix$key', value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: '$_prefix$key');
}

class MemorySyncIdentityStore implements SyncIdentityStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class SyncIdentityService {
  SyncIdentityService({
    required SyncIdentityStore store,
    Random? random,
    // ignore: prefer_initializing_formals
  }) : _store = store,
       _random = random ?? Random.secure();

  static const _phraseKey = 'recovery_phrase_v1';
  static const _saltKey = 'derivation_salt_v1';
  static const _epochKey = 'key_epoch_v1';
  static const _kdfIterations = 310000;
  static const _pairingIterations = 180000;
  static const _pairingAad = 'ArchiveMe.E2EE.Pairing.v1';
  static final _derivationSalt = utf8.encode('ArchiveMe.SyncEncryptionKey.v1');

  final SyncIdentityStore _store;
  final Random _random;
  final _cipher = AesGcm.with256bits();

  Future<bool> get isEnabled async => (await _store.read(_phraseKey)) != null;

  Future<int> get keyEpoch async =>
      int.tryParse(await _store.read(_epochKey) ?? '') ?? 1;

  Future<String> enable() async {
    final existing = await recoveryPhrase();
    if (existing != null) return existing;
    final phrase = Mnemonic.generate(
      Language.english,
      length: MnemonicLength.words12,
    ).sentence;
    await installRecoveryPhrase(phrase);
    return phrase;
  }

  Future<void> installRecoveryPhrase(String phrase) async {
    final normalized = _validatePhrase(phrase);
    await _store.write(_phraseKey, normalized);
    await _store.write(_saltKey, base64Encode(_derivationSalt));
    await _store.write(_epochKey, '1');
  }

  Future<String?> recoveryPhrase() => _store.read(_phraseKey);

  Future<SyncEncryptionKey> requireKey() async {
    final phrase = await recoveryPhrase();
    final saltText = await _store.read(_saltKey);
    if (phrase == null || saltText == null) {
      throw StateError('Encrypted sync has not been enabled.');
    }
    final kdf = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _kdfIterations,
      bits: 256,
    );
    final key = await kdf.deriveKeyFromPassword(
      password: phrase,
      nonce: _derivationSalt,
    );
    return SyncEncryptionKey(await key.extractBytes());
  }

  Future<String> rotate() async {
    final oldEpoch = await keyEpoch;
    final phrase = Mnemonic.generate(
      Language.english,
      length: MnemonicLength.words12,
    ).sentence;
    await _store.write(_phraseKey, phrase);
    await _store.write(_saltKey, base64Encode(_derivationSalt));
    await _store.write(_epochKey, '${oldEpoch + 1}');
    return phrase;
  }

  Future<String> createPairingPayload(String pairingCode) async {
    final phrase = await recoveryPhrase();
    final saltText = await _store.read(_saltKey);
    if (phrase == null || saltText == null) {
      throw StateError('Encrypted sync has not been enabled.');
    }
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final wrappingKey = await _pairingKey(pairingCode, salt);
    final cleartext = utf8.encode(
      jsonEncode({
        'phrase': phrase,
        'derivationSalt': saltText,
        'epoch': await keyEpoch,
      }),
    );
    final box = await _cipher.encrypt(
      cleartext,
      secretKey: wrappingKey,
      nonce: nonce,
      aad: utf8.encode(_pairingAad),
    );
    return jsonEncode({
      'v': 1,
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce),
      'blob': base64Encode([...box.cipherText, ...box.mac.bytes]),
    });
  }

  Future<void> acceptPairingPayload(
    String payload, {
    required String pairingCode,
  }) async {
    final json = jsonDecode(payload);
    if (json is! Map || json['v'] != 1) {
      throw const FormatException('Unsupported pairing payload.');
    }
    final salt = base64Decode('${json['salt']}');
    final nonce = base64Decode('${json['nonce']}');
    final combined = base64Decode('${json['blob']}');
    if (combined.length <= 16) throw const FormatException('Invalid payload.');
    final wrappingKey = await _pairingKey(pairingCode, salt);
    final cleartext = await _cipher.decrypt(
      SecretBox(
        combined.sublist(0, combined.length - 16),
        nonce: nonce,
        mac: Mac(combined.sublist(combined.length - 16)),
      ),
      secretKey: wrappingKey,
      aad: utf8.encode(_pairingAad),
    );
    final bundle = jsonDecode(utf8.decode(cleartext));
    if (bundle is! Map) throw const FormatException('Invalid pairing bundle.');
    final phrase = _validatePhrase('${bundle['phrase']}');
    base64Decode('${bundle['derivationSalt']}');
    await _store.write(_phraseKey, phrase);
    await _store.write(_saltKey, base64Encode(_derivationSalt));
    await _store.write(_epochKey, '${bundle['epoch'] ?? 1}');
  }

  /// Serializes the sync identity for transfer inside an already authenticated
  /// mesh session. The returned bytes are plaintext key material and must only
  /// be sent through the ECDH-derived AEAD channel, then wiped by the caller.
  Future<Uint8List> createMeshSessionPairingBundle() async {
    final phrase = await recoveryPhrase();
    if (phrase == null) {
      throw StateError('Encrypted sync has not been enabled.');
    }
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'version': 1,
          'recoveryPhrase': phrase,
          'keyEpoch': await keyEpoch,
        }),
      ),
    );
  }

  /// Installs key material received through a confirmed authenticated mesh
  /// session. This method does not accept unauthenticated discovery payloads.
  Future<void> acceptMeshSessionPairingBundle(List<int> bytes) async {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map ||
          decoded.length != 3 ||
          decoded['version'] != 1 ||
          decoded['recoveryPhrase'] is! String ||
          decoded['keyEpoch'] is! num) {
        throw const FormatException('Invalid mesh pairing bundle.');
      }
      final epoch = (decoded['keyEpoch'] as num).toInt();
      if (epoch < 1 || epoch != decoded['keyEpoch']) {
        throw const FormatException('Invalid mesh pairing key epoch.');
      }
      final phrase = _validatePhrase(decoded['recoveryPhrase'] as String);
      await _store.write(_phraseKey, phrase);
      await _store.write(_saltKey, base64Encode(_derivationSalt));
      await _store.write(_epochKey, '$epoch');
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException('Invalid mesh pairing bundle: $error');
    }
  }

  Future<void> disable() async {
    await _store.delete(_phraseKey);
    await _store.delete(_saltKey);
    await _store.delete(_epochKey);
  }

  String _validatePhrase(String phrase) {
    final normalized = phrase.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    final mnemonic = Mnemonic.fromSentence(normalized, Language.english);
    if (mnemonic.words.length != 12) {
      throw const FormatException('A 12-word BIP39 phrase is required.');
    }
    return mnemonic.sentence;
  }

  Future<SecretKey> _pairingKey(String code, List<int> salt) {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const FormatException('Pairing code must contain six digits.');
    }
    return Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pairingIterations,
      bits: 256,
    ).deriveKeyFromPassword(password: code, nonce: salt);
  }

  List<int> _randomBytes(int length) =>
      List<int>.generate(length, (_) => _random.nextInt(256));
}
