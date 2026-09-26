import 'dart:convert';
import 'dart:math';

import 'package:archiveme_mobile/core/storage/secure_storage_provider.dart';
import 'package:archiveme_mobile/features/sync/services/bip39_english.dart';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Argon2id parameters stored next to a wrapped account key.
class AccountKdfParams {
  const AccountKdfParams({
    required this.memoryKiB,
    required this.iterations,
    required this.parallelism,
    required this.hashLength,
  });

  factory AccountKdfParams.fromJson(Map<String, Object?> json) {
    return AccountKdfParams(
      memoryKiB: json['memoryKiB'] as int? ?? production.memoryKiB,
      iterations: json['iterations'] as int? ?? production.iterations,
      parallelism: json['parallelism'] as int? ?? production.parallelism,
      hashLength: json['hashLength'] as int? ?? production.hashLength,
    );
  }

  /// 64 MB, 3 iterations, 4 lanes, 256-bit output.
  static const production = AccountKdfParams(
    memoryKiB: 64 * 1024,
    iterations: 3,
    parallelism: 4,
    hashLength: 32,
  );

  final int memoryKiB;
  final int iterations;
  final int parallelism;
  final int hashLength;

  Argon2id get algorithm => Argon2id(
    parallelism: parallelism,
    memory: memoryKiB,
    iterations: iterations,
    hashLength: hashLength,
  );

  Map<String, Object> toJson() => {
    'memoryKiB': memoryKiB,
    'iterations': iterations,
    'parallelism': parallelism,
    'hashLength': hashLength,
  };
}

class WrappedAccountKey {
  const WrappedAccountKey({
    required this.ciphertext,
    required this.nonce,
    required this.innerNonce,
    required this.salt,
    required this.kdf,
  });

  factory WrappedAccountKey.fromJson(Map<String, Object?> json) {
    final kdf = json['kdf'];
    return WrappedAccountKey(
      ciphertext: '${json['ciphertext'] ?? ''}',
      nonce: '${json['nonce'] ?? ''}',
      innerNonce: '${json['innerNonce'] ?? ''}',
      salt: '${json['salt'] ?? ''}',
      kdf: kdf is Map
          ? AccountKdfParams.fromJson(Map<String, Object?>.from(kdf))
          : AccountKdfParams.production,
    );
  }

  final String ciphertext;
  final String nonce;
  final String innerNonce;
  final String salt;
  final AccountKdfParams kdf;

  Map<String, Object> toJson() => {
    'ciphertext': ciphertext,
    'nonce': nonce,
    'innerNonce': innerNonce,
    'salt': salt,
    'kdf': kdf.toJson(),
  };
}

class AccountKeyBundle {
  const AccountKeyBundle({
    required this.wrappedByPassphrase,
    required this.wrappedByRecovery,
    required this.createdAt,
  });

  factory AccountKeyBundle.fromJson(Map<String, Object?> json) {
    final passphrase = json['wrappedByPassphrase'];
    final recovery = json['wrappedByRecovery'];
    if (passphrase is! Map || recovery is! Map) {
      throw const FormatException('Wrapped account key bundle was incomplete.');
    }
    return AccountKeyBundle(
      wrappedByPassphrase: WrappedAccountKey.fromJson(
        Map<String, Object?>.from(passphrase),
      ),
      wrappedByRecovery: WrappedAccountKey.fromJson(
        Map<String, Object?>.from(recovery),
      ),
      createdAt:
          DateTime.tryParse('${json['createdAt']}')?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  final WrappedAccountKey wrappedByPassphrase;
  final WrappedAccountKey wrappedByRecovery;
  final DateTime createdAt;

  Map<String, Object> toJson() => {
    'wrappedByPassphrase': wrappedByPassphrase.toJson(),
    'wrappedByRecovery': wrappedByRecovery.toJson(),
    'kdfParams': wrappedByPassphrase.kdf.toJson(),
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}

/// Twenty-four BIP-0039 words that recover the account key.
class RecoveryKey {
  const RecoveryKey(this.words);

  final List<String> words;

  String get phrase => words.join(' ');

  static final Set<String> _words = bip39English.toSet();

  static bool looksLike(String phrase) {
    final words = phrase
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
    if (words.length != 24) return false;
    return words.every(_words.contains);
  }
}

/// The passphrase did not unwrap the account key.
class AccountKeyUnlockFailed implements Exception {
  const AccountKeyUnlockFailed();

  @override
  String toString() =>
      'That passphrase does not unlock this archive. Try the recovery key.';
}

/// A random 256-bit account key, wrapped twice by a passphrase-derived key.
abstract final class AccountSyncKey {
  AccountSyncKey._();

  static const bundleStorageKey = 'account_sync_key_bundle_v1';

  /// Tests set a tiny Argon2id so they do not allocate 64 MB.
  @visibleForTesting
  static Argon2id? debugKdf;

  static List<int> generate([Random? random]) {
    final source = random ?? Random.secure();
    return List<int>.generate(32, (_) => source.nextInt(256));
  }

  static String recoveryPhrase([Random? random]) {
    final source = random ?? Random.secure();
    final entropy = List<int>.generate(32, (_) => source.nextInt(256));
    return _phraseForEntropy(entropy);
  }

  /// Confirms the phrase is 24 wordlist words with a valid BIP-0039 checksum.
  static bool verifyRecoveryPhrase(String phrase) {
    if (!RecoveryKey.looksLike(phrase)) return false;
    final words = phrase.trim().toLowerCase().split(RegExp(r'\s+'));
    final bits = StringBuffer();
    for (final word in words) {
      final index = bip39English.indexOf(word);
      if (index < 0) return false;
      bits.write(index.toRadixString(2).padLeft(11, '0'));
    }
    final raw = bits.toString();
    final entropy = _bytesFromBits(raw.substring(0, 256));
    final checksum = raw.substring(256);
    final expected = sha256
        .convert(entropy)
        .bytes[0]
        .toRadixString(2)
        .padLeft(8, '0');
    return checksum == expected;
  }

  static Future<AccountKeyBundle> wrap({
    required List<int> accountKey,
    required String passphrase,
    required String recoveryPhrase,
    DateTime? createdAt,
  }) async {
    final created = createdAt ?? DateTime.now().toUtc();
    return AccountKeyBundle(
      wrappedByPassphrase: await wrapWithSecret(
        accountKey: accountKey,
        secret: passphrase,
      ),
      wrappedByRecovery: await wrapWithSecret(
        accountKey: accountKey,
        secret: recoveryPhrase,
      ),
      createdAt: created,
    );
  }

  /// Encrypts the account key, then encrypts that box again with the same
  /// Argon2id key. Only the outer box is stored.
  static Future<WrappedAccountKey> wrapWithSecret({
    required List<int> accountKey,
    required String secret,
    List<int>? salt,
  }) async {
    final kdf = _params();
    final usedSalt = salt ?? _randomBytes(16);
    final derived = await kdf.algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(secret)),
      nonce: usedSalt,
    );
    final algorithm = Xchacha20.poly1305Aead();
    final inner = await algorithm.encrypt(accountKey, secretKey: derived);
    final outer = await algorithm.encrypt(
      <int>[...inner.cipherText, ...inner.mac.bytes],
      secretKey: derived,
    );
    return WrappedAccountKey(
      ciphertext: base64Encode(<int>[...outer.cipherText, ...outer.mac.bytes]),
      nonce: base64Encode(outer.nonce),
      innerNonce: base64Encode(inner.nonce),
      salt: base64Encode(usedSalt),
      kdf: kdf,
    );
  }

  static Future<List<int>> unwrap({
    required WrappedAccountKey wrapped,
    required String secret,
  }) async {
    try {
      final derived = await wrapped.kdf.algorithm.deriveKey(
        secretKey: SecretKey(utf8.encode(secret)),
        nonce: base64Decode(wrapped.salt),
      );
      final algorithm = Xchacha20.poly1305Aead();
      final outerPacked = base64Decode(wrapped.ciphertext);
      if (outerPacked.length < 16 || wrapped.innerNonce.isEmpty) {
        throw const AccountKeyUnlockFailed();
      }
      final innerPacked = await algorithm.decrypt(
        SecretBox(
          outerPacked.sublist(0, outerPacked.length - 16),
          nonce: base64Decode(wrapped.nonce),
          mac: Mac(outerPacked.sublist(outerPacked.length - 16)),
        ),
        secretKey: derived,
      );
      if (innerPacked.length < 16) throw const AccountKeyUnlockFailed();
      return algorithm.decrypt(
        SecretBox(
          innerPacked.sublist(0, innerPacked.length - 16),
          nonce: base64Decode(wrapped.innerNonce),
          mac: Mac(innerPacked.sublist(innerPacked.length - 16)),
        ),
        secretKey: derived,
      );
    } on SecretBoxAuthenticationError {
      throw const AccountKeyUnlockFailed();
    } on FormatException {
      throw const AccountKeyUnlockFailed();
    }
  }

  /// Re-wraps the same account key. Entry ciphertext is left unchanged.
  static Future<WrappedAccountKey> changePassphrase({
    required WrappedAccountKey wrapped,
    required String currentPassphrase,
    required String nextPassphrase,
  }) async {
    final accountKey = await unwrap(
      wrapped: wrapped,
      secret: currentPassphrase,
    );
    return wrapWithSecret(accountKey: accountKey, secret: nextPassphrase);
  }

  static Future<void> storeBundle(
    AccountKeyBundle bundle, {
    FlutterSecureStorage? storage,
  }) {
    final box = storage ?? accountKeySecureStorage;
    return box.write(
      key: bundleStorageKey,
      value: jsonEncode(bundle.toJson()),
    );
  }

  static Future<AccountKeyBundle?> readBundle({
    FlutterSecureStorage? storage,
  }) async {
    final raw = await (storage ?? accountKeySecureStorage).read(
      key: bundleStorageKey,
    );
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    return AccountKeyBundle.fromJson(Map<String, Object?>.from(decoded));
  }

  static AccountKdfParams _params() {
    final override = debugKdf;
    if (override == null) return AccountKdfParams.production;
    return AccountKdfParams(
      memoryKiB: override.memory,
      iterations: override.iterations,
      parallelism: override.parallelism,
      hashLength: override.hashLength,
    );
  }

  static String _phraseForEntropy(List<int> entropy) {
    final hash = sha256.convert(entropy).bytes[0];
    final bits = StringBuffer()
      ..write(_bitsFromBytes(entropy))
      ..write(hash.toRadixString(2).padLeft(8, '0'));
    final raw = bits.toString();
    final words = <String>[];
    for (var i = 0; i < 24; i++) {
      final index = int.parse(raw.substring(i * 11, (i + 1) * 11), radix: 2);
      words.add(bip39English[index]);
    }
    return words.join(' ');
  }

  static String _bitsFromBytes(List<int> bytes) {
    final bits = StringBuffer();
    for (final byte in bytes) {
      bits.write(byte.toRadixString(2).padLeft(8, '0'));
    }
    return bits.toString();
  }

  static List<int> _bytesFromBits(String bits) {
    final bytes = <int>[];
    for (var i = 0; i < bits.length; i += 8) {
      bytes.add(int.parse(bits.substring(i, i + 8), radix: 2));
    }
    return bytes;
  }

  static List<int> _randomBytes(int length) {
    final source = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => source.nextInt(256)),
    );
  }
}
