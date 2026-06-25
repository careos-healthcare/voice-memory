import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import 'private_data_encryption_key_store.dart';

/// Result of migrating a legacy plaintext JSON file to encrypted storage.
class EncryptedJsonMigrationResult {
  const EncryptedJsonMigrationResult({
    required this.migrated,
    this.plaintextRemoved = false,
  });

  final bool migrated;
  final bool plaintextRemoved;
}

/// Authenticated encryption for private JSON blobs on disk (AES-256-GCM).
class EncryptedJsonFileStore {
  EncryptedJsonFileStore({
    required this.file,
    required PrivateDataEncryptionKeyStore keyStore,
    AesGcm? algorithm,
  }) : _keyStore = keyStore,
       _algorithm = algorithm ?? AesGcm.with256bits();

  final File file;
  final PrivateDataEncryptionKeyStore _keyStore;
  final AesGcm _algorithm;

  static const envelopeVersion = 1;

  Future<void> ensureKey() async {
    if (_keyStore is SecurePrivateDataEncryptionKeyStore) {
      await (_keyStore as SecurePrivateDataEncryptionKeyStore).ensureKey();
      return;
    }
    if (_keyStore is InMemoryPrivateDataEncryptionKeyStore) {
      await (_keyStore as InMemoryPrivateDataEncryptionKeyStore).ensureKey();
      return;
    }
    final existing = await _keyStore.readKeyBytes();
    if (existing != null &&
        existing.length == SecurePrivateDataEncryptionKeyStore.keyByteLength) {
      return;
    }
    final key = await _algorithm.newSecretKey();
    final keyBytes = await key.extractBytes();
    await _keyStore.writeKeyBytes(keyBytes);
  }

  Future<bool> exists() async => file.exists();

  Future<dynamic> readJson() async {
    await ensureKey();
    if (!await file.exists()) return null;

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return null;

    final envelope = jsonDecode(raw) as Map<String, dynamic>;
    final version = envelope['v'] as int? ?? 0;
    if (version != envelopeVersion) {
      throw FormatException('Unsupported encrypted JSON envelope version: $version');
    }

    final keyBytes = await _keyStore.readKeyBytes();
    if (keyBytes == null || keyBytes.isEmpty) {
      throw StateError('Missing encryption key for ${file.path}');
    }

    final secretKey = SecretKey(keyBytes);
    final secretBox = SecretBox(
      base64Decode(envelope['c'] as String),
      nonce: base64Decode(envelope['n'] as String),
      mac: Mac(base64Decode(envelope['m'] as String)),
    );
    final clearBytes = await _algorithm.decrypt(secretBox, secretKey: secretKey);
    return jsonDecode(utf8.decode(clearBytes));
  }

  Future<void> writeJson(dynamic value) async {
    await ensureKey();
    final keyBytes = await _keyStore.readKeyBytes();
    if (keyBytes == null || keyBytes.isEmpty) {
      throw StateError('Missing encryption key for ${file.path}');
    }

    final secretKey = SecretKey(keyBytes);
    final clearBytes = utf8.encode(jsonEncode(value));
    final secretBox = await _algorithm.encrypt(
      clearBytes,
      secretKey: secretKey,
    );

    final envelope = jsonEncode({
      'v': envelopeVersion,
      'n': base64Encode(secretBox.nonce),
      'c': base64Encode(secretBox.cipherText),
      'm': base64Encode(secretBox.mac.bytes),
    });

    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(envelope);
  }

  /// Reads [plaintextFile] once, writes encrypted data here, then removes
  /// plaintext unless [keepPlaintextForTests] is true.
  Future<EncryptedJsonMigrationResult> migrateFromPlaintextFile(
    File plaintextFile, {
    bool keepPlaintextForTests = false,
  }) async {
    if (!await plaintextFile.exists()) {
      return const EncryptedJsonMigrationResult(migrated: false);
    }
    if (await file.exists()) {
      return const EncryptedJsonMigrationResult(migrated: false);
    }

    final raw = await plaintextFile.readAsString();
    if (raw.trim().isEmpty) {
      await writeJson([]);
      if (!keepPlaintextForTests) {
        await plaintextFile.delete();
      }
      return EncryptedJsonMigrationResult(
        migrated: true,
        plaintextRemoved: !keepPlaintextForTests,
      );
    }

    final decoded = jsonDecode(raw);
    await writeJson(decoded);
    var removed = false;
    if (!keepPlaintextForTests) {
      await plaintextFile.delete();
      removed = true;
    }
    return EncryptedJsonMigrationResult(
      migrated: true,
      plaintextRemoved: removed,
    );
  }

  /// True when [file] on disk does not contain [needle] as plaintext.
  static Future<bool> fileOmitsPlaintextNeedle(
    File target,
    String needle,
  ) async {
    if (!await target.exists()) return true;
    final raw = await target.readAsString();
    return !raw.contains(needle);
  }
}
