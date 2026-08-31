import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// A SQLCipher-compatible secret derived from a 256-bit key or a legacy passphrase.
final class SqliteDatabaseEncryptionKey {
  const SqliteDatabaseEncryptionKey._(
    this.sqlcipherPassword,
    this._rawKeyBytes,
  );

  /// Password string passed to [sqflite_sqlcipher] `openDatabase`.
  final String sqlcipherPassword;

  final Uint8List? _rawKeyBytes;

  static const keyByteLength = 32;

  /// Deterministic 256-bit key shared by all unit/integration test suites.
  static final SqliteDatabaseEncryptionKey testInstance =
      SqliteDatabaseEncryptionKey._(
        base64Encode(Uint8List.fromList(List.filled(keyByteLength, 0x42))),
        Uint8List.fromList(List.filled(keyByteLength, 0x42)),
      );

  /// Raw 256-bit key material when this key was generated or loaded from v2 storage.
  Uint8List? get rawKeyBytes =>
      _rawKeyBytes == null ? null : Uint8List.fromList(_rawKeyBytes!);

  /// Generates a fresh 256-bit key for first-boot provisioning.
  factory SqliteDatabaseEncryptionKey.generate() {
    final bytes = Uint8List(keyByteLength);
    final random = Random.secure();
    for (var i = 0; i < keyByteLength; i++) {
      bytes[i] = random.nextInt(256);
    }
    return SqliteDatabaseEncryptionKey._(base64Encode(bytes), bytes);
  }

  /// Parses secure-storage payloads — v2 raw keys or legacy v1 passphrases.
  factory SqliteDatabaseEncryptionKey.fromStored(String stored) {
    final trimmed = stored.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('stored encryption key must not be empty');
    }

    final decoded = base64Decode(trimmed);
    if (decoded.length == keyByteLength) {
      return SqliteDatabaseEncryptionKey._(
        trimmed,
        Uint8List.fromList(decoded),
      );
    }

    final legacyPassphrase = utf8.decode(decoded);
    if (legacyPassphrase.length < keyByteLength) {
      throw FormatException('stored SQLCipher secret is too short');
    }
    return SqliteDatabaseEncryptionKey._(legacyPassphrase, null);
  }
}
