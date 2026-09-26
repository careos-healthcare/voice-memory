import 'dart:convert';
import 'dart:math';

import 'package:archiveme_mobile/features/sync/services/bip39_english.dart';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// 32-byte key produced by Argon2id, plus the salt that derived it.
class MasterKey {
  const MasterKey({required this.bytes, required this.salt});

  final List<int> bytes;
  final List<int> salt;
}

/// Twenty-four BIP-0039 words that recover the passphrase.
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

/// Derives the master key with Argon2id and builds a 24-word recovery key.
abstract final class CryptoVault {
  CryptoVault._();

  /// OWASP Argon2id: 19 MiB, 2 iterations, parallelism 1, 256-bit output.
  static final Argon2id productionKdf = Argon2id(
    parallelism: 1,
    memory: 19 * 1024,
    iterations: 2,
    hashLength: 32,
  );

  @visibleForTesting
  static Argon2id? debugKdf;

  static String generateRecoveryPhrase([Random? random]) {
    final source = random ?? Random.secure();
    final entropy = List<int>.generate(32, (_) => source.nextInt(256));
    return _phraseForEntropy(entropy);
  }

  static Future<MasterKey> deriveMasterKey({
    required String passphrase,
    required List<int> salt,
  }) async {
    final algorithm = debugKdf ?? productionKdf;
    final secret = await algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
    return MasterKey(
      bytes: await secret.extractBytes(),
      salt: List<int>.from(salt),
    );
  }

  static List<int> randomSalt([Random? random]) {
    final source = random ?? Random.secure();
    return List<int>.generate(16, (_) => source.nextInt(256));
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
}
