import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Salted, iterated PIN hashing. Pure functions only — no storage, no
/// platform code, no logging. The raw PIN never leaves the call stack:
/// only the salt and the derived hash are ever returned.
abstract final class PinHash {
  PinHash._();

  static const int minLength = 4;
  static const int maxLength = 6;

  /// Bytes of secure random salt per PIN.
  static const int saltBytes = 16;

  /// SHA-256 stretching rounds — keeps offline guessing slow without
  /// noticeable unlock latency on device.
  static const int iterations = 10000;

  static final RegExp _pinShape = RegExp(r'^[0-9]{4,6}$');

  /// True for a 4–6 digit PIN.
  static bool isValidPin(String pin) => _pinShape.hasMatch(pin);

  /// A new base64 salt from a cryptographically secure source.
  static String generateSalt({Random? random}) {
    final rng = random ?? Random.secure();
    final bytes = List<int>.generate(saltBytes, (_) => rng.nextInt(256));
    return base64Encode(bytes);
  }

  /// Derives the stored hash for [pin] under [salt]. Deterministic for the
  /// same inputs; never equal to (or containing) the raw PIN.
  static String hash({required String pin, required String salt}) {
    var digest = sha256.convert(utf8.encode('$salt:$pin')).bytes;
    for (var i = 1; i < iterations; i++) {
      digest = sha256.convert(digest).bytes;
    }
    return base64Encode(digest);
  }

  /// Constant-time comparison of a PIN attempt against the stored values.
  static bool verify({
    required String pin,
    required String salt,
    required String expectedHash,
  }) {
    if (!isValidPin(pin)) return false;
    final attempt = hash(pin: pin, salt: salt);
    if (attempt.length != expectedHash.length) return false;
    var mismatch = 0;
    for (var i = 0; i < attempt.length; i++) {
      mismatch |= attempt.codeUnitAt(i) ^ expectedHash.codeUnitAt(i);
    }
    return mismatch == 0;
  }
}
