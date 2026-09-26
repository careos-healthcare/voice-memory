import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/sync/services/crypto_vault.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// Argon2id parameters stored next to a wrapped account key.
class AccountKdfParams {
  const AccountKdfParams({
    required this.memoryKiB,
    required this.iterations,
    required this.parallelism,
    required this.hashLength,
  });

  /// 64 MB, 3 iterations, one lane, 256-bit output.
  static const production = AccountKdfParams(
    memoryKiB: 64 * 1024,
    iterations: 3,
    parallelism: 1,
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

  factory AccountKdfParams.fromJson(Map<String, Object?> json) {
    return AccountKdfParams(
      memoryKiB: json['memoryKiB'] as int? ?? production.memoryKiB,
      iterations: json['iterations'] as int? ?? production.iterations,
      parallelism: json['parallelism'] as int? ?? production.parallelism,
      hashLength: json['hashLength'] as int? ?? production.hashLength,
    );
  }
}

class WrappedAccountKey {
  const WrappedAccountKey({
    required this.ciphertext,
    required this.nonce,
    required this.salt,
    required this.kdf,
  });

  final String ciphertext;
  final String nonce;
  final String salt;
  final AccountKdfParams kdf;

  Map<String, Object> toJson() => {
    'ciphertext': ciphertext,
    'nonce': nonce,
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

/// The passphrase did not unwrap the account key.
class AccountKeyUnlockFailed implements Exception {
  const AccountKeyUnlockFailed();

  @override
  String toString() =>
      'That passphrase does not unlock this archive. Try the recovery key.';
}

/// A random 256-bit account key, wrapped by a passphrase and a recovery phrase.
abstract final class AccountSyncKey {
  AccountSyncKey._();

  /// Tests set a tiny Argon2id so they do not allocate 64 MB.
  @visibleForTesting
  static Argon2id? debugKdf;

  static List<int> generate([Random? random]) {
    final source = random ?? Random.secure();
    return List<int>.generate(32, (_) => source.nextInt(256));
  }

  static String recoveryPhrase([Random? random]) {
    return CryptoVault.generateRecoveryPhrase(random);
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
    final box = await Xchacha20.poly1305Aead().encrypt(
      accountKey,
      secretKey: derived,
    );
    return WrappedAccountKey(
      ciphertext: base64Encode(<int>[...box.cipherText, ...box.mac.bytes]),
      nonce: base64Encode(box.nonce),
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
      final packed = base64Decode(wrapped.ciphertext);
      if (packed.length < 16) throw const AccountKeyUnlockFailed();
      final clear = await Xchacha20.poly1305Aead().decrypt(
        SecretBox(
          packed.sublist(0, packed.length - 16),
          nonce: base64Decode(wrapped.nonce),
          mac: Mac(packed.sublist(packed.length - 16)),
        ),
        secretKey: derived,
      );
      return clear;
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

  static List<int> _randomBytes(int length) {
    final source = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => source.nextInt(256)),
    );
  }
}
