import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archiveme_crypto/src/json/encrypted_json_file_hooks.dart';
import 'package:archiveme_crypto/src/json/encrypted_json_file_outcome.dart';
import 'package:archiveme_crypto/src/json/private_data_encryption_key_store.dart';
import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

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
///
/// Writes use a crash-safe protocol: encrypt → temp file → verify decrypt →
/// preserve last-known-good backup → atomic rename. Corruption never becomes
/// an empty archive silently.
class EncryptedJsonFileStore {
  EncryptedJsonFileStore({
    required this.file,
    required this._keyStore,
    AesGcm? algorithm,
    this._hooks = EncryptedJsonFileHooks.none,
  }) : _algorithm = algorithm ?? AesGcm.with256bits();

  final File file;
  final PrivateDataEncryptionKeyStore _keyStore;
  final AesGcm _algorithm;
  final EncryptedJsonFileHooks _hooks;

  static const envelopeVersion = 1;
  static const _uuid = Uuid();

  Future<void> _mutex = Future<void>.value();

  File get _backupFile => File('${file.path}.bak');

  Future<T> _serialized<T>(Future<T> Function() action) {
    final completer = Completer<void>();
    final previous = _mutex;
    _mutex = completer.future;
    return previous.then((_) async {
      try {
        return await action();
      } finally {
        completer.complete();
      }
    });
  }

  Future<void> ensureKey() async {
    if (_keyStore is SecurePrivateDataEncryptionKeyStore) {
      await _keyStore.ensureKey();
      return;
    }
    if (_keyStore is InMemoryPrivateDataEncryptionKeyStore) {
      await _keyStore.ensureKey();
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

  /// Legacy convenience — throws on unrecoverable corruption; never maps
  /// corruption to an empty archive.
  Future<dynamic> readJson() async {
    final outcome = await readJsonOutcome();
    return switch (outcome) {
      EncryptedJsonReadMissing() => null,
      EncryptedJsonReadPrimaryValid(:final value) => value,
      EncryptedJsonReadRecoveredFromBackup(:final value) => value,
      EncryptedJsonReadCorruptPrimaryValidBackup(:final value) => value,
      EncryptedJsonReadKeyUnavailable() => throw StateError(
        'Missing encryption key for ${file.path}',
      ),
      EncryptedJsonReadAuthenticationFailure() => throw StateError(
        'Encrypted JSON authentication failed',
      ),
      EncryptedJsonReadBothCopiesCorrupt() => throw const FormatException(
        'Encrypted JSON primary and backup are both corrupt',
      ),
    };
  }

  Future<EncryptedJsonReadOutcome> readJsonOutcome() async {
    await ensureKey();
    if (!await file.exists() && !await _backupFile.exists()) {
      return const EncryptedJsonReadMissing();
    }

    final keyBytes = await _keyStore.readKeyBytes();
    if (keyBytes == null || keyBytes.isEmpty) {
      return const EncryptedJsonReadKeyUnavailable();
    }

    if (await file.exists()) {
      final primary = await _tryDecryptFile(file, keyBytes);
      if (primary case _DecryptOk(:final value)) {
        return EncryptedJsonReadPrimaryValid(value);
      }
      if (await _backupFile.exists()) {
        final backup = await _tryDecryptFile(_backupFile, keyBytes);
        if (backup case _DecryptOk(:final value)) {
          return EncryptedJsonReadCorruptPrimaryValidBackup(value);
        }
        if (primary case _DecryptAuthFail()) {
          return const EncryptedJsonReadAuthenticationFailure();
        }
      } else if (primary case _DecryptAuthFail()) {
        return const EncryptedJsonReadAuthenticationFailure();
      }
    }

    if (await _backupFile.exists()) {
      final backup = await _tryDecryptFile(_backupFile, keyBytes);
      if (backup case _DecryptOk(:final value)) {
        return EncryptedJsonReadRecoveredFromBackup(value);
      }
      if (backup case _DecryptAuthFail()) {
        return const EncryptedJsonReadAuthenticationFailure();
      }
    }

    if (!await file.exists()) {
      return const EncryptedJsonReadMissing();
    }
    return const EncryptedJsonReadBothCopiesCorrupt();
  }

  Future<void> writeJson(dynamic value) async {
    final outcome = await writeJsonOutcome(value);
    switch (outcome) {
      case EncryptedJsonWriteSuccess():
        return;
      case EncryptedJsonWriteKeyUnavailable():
        throw StateError('Missing encryption key for ${file.path}');
      case EncryptedJsonWriteDiskFailure(:final message):
        throw FileSystemException(message);
      case EncryptedJsonWriteVerificationFailed(:final message):
        throw StateError(message);
    }
  }

  Future<EncryptedJsonWriteOutcome> writeJsonOutcome(dynamic value) {
    return _serialized(() => _writeJsonOutcomeImpl(value));
  }

  Future<EncryptedJsonWriteOutcome> _writeJsonOutcomeImpl(dynamic value) async {
    await ensureKey();
    final keyBytes = await _keyStore.readKeyBytes();
    if (keyBytes == null || keyBytes.isEmpty) {
      return const EncryptedJsonWriteKeyUnavailable();
    }

    File? tempFile;
    try {
      final envelope = await _encryptJson(value, keyBytes);
      if (_hooks.failAfterEncrypt) {
        return const EncryptedJsonWriteDiskFailure('injected_after_encrypt');
      }

      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }

      tempFile = File('${file.path}.tmp.${_uuid.v4()}');
      await tempFile.writeAsString(envelope, flush: true);
      if (_hooks.failAfterTempWrite) {
        return const EncryptedJsonWriteDiskFailure('injected_after_temp_write');
      }
      if (_hooks.corruptTempFile) {
        await tempFile.writeAsString('corrupt', flush: true);
      }

      final verified = await _tryDecryptFile(tempFile, keyBytes);
      if (verified is! _DecryptOk) {
        return const EncryptedJsonWriteVerificationFailed(
          'temp_file_verify_failed',
        );
      }
      if (_hooks.failAfterVerify) {
        return const EncryptedJsonWriteDiskFailure('injected_after_verify');
      }

      if (!_hooks.skipBackup && await file.exists()) {
        final primaryOk = await _tryDecryptFile(file, keyBytes);
        if (primaryOk is _DecryptOk) {
          await file.copy(_backupFile.path);
        }
      }

      if (_hooks.failBeforeRename) {
        return const EncryptedJsonWriteDiskFailure('injected_before_rename');
      }

      await tempFile.rename(file.path);
      tempFile = null;
      await _cleanStaleTempFiles();
      return const EncryptedJsonWriteSuccess();
    } on FileSystemException catch (e, stackTrace) {
      return EncryptedJsonWriteDiskFailure(e.message);
    } on Object catch (e, stackTrace) {
      return EncryptedJsonWriteDiskFailure('$e');
    } finally {
      if (tempFile != null && await tempFile.exists()) {
        await _safeDelete(tempFile);
      }
    }
  }

  Future<String> _encryptJson(dynamic value, List<int> keyBytes) async {
    final secretKey = SecretKey(keyBytes);
    final clearBytes = utf8.encode(jsonEncode(value));
    final secretBox = await _algorithm.encrypt(
      clearBytes,
      secretKey: secretKey,
    );
    return jsonEncode({
      'v': envelopeVersion,
      'n': base64Encode(secretBox.nonce),
      'c': base64Encode(secretBox.cipherText),
      'm': base64Encode(secretBox.mac.bytes),
    });
  }

  Future<_DecryptResult> _tryDecryptFile(
    File target,
    List<int> keyBytes,
  ) async {
    try {
      if (!await target.exists()) return const _DecryptCorrupt();
      final raw = await target.readAsString();
      if (raw.trim().isEmpty) return const _DecryptCorrupt();

      final envelope = jsonDecode(raw) as Map<String, dynamic>;
      final version = envelope['v'] as int? ?? 0;
      if (version != envelopeVersion) return const _DecryptCorrupt();

      final secretKey = SecretKey(keyBytes);
      final secretBox = SecretBox(
        base64Decode(envelope['c'] as String),
        nonce: base64Decode(envelope['n'] as String),
        mac: Mac(base64Decode(envelope['m'] as String)),
      );
      final clearBytes = await _algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );
      return _DecryptOk(jsonDecode(utf8.decode(clearBytes)));
    } on SecretBoxAuthenticationError {
      return const _DecryptAuthFail();
    } on FormatException {
      return const _DecryptCorrupt();
    } on Object catch (_, stackTrace) {
      return const _DecryptCorrupt();
    }
  }

  Future<void> _cleanStaleTempFiles() async {
    final dir = file.parent;
    if (!await dir.exists()) return;
    final prefix = '${file.path}.tmp.';
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      if (!entity.path.startsWith(prefix)) continue;
      await _safeDelete(entity);
    }
  }

  Future<void> _safeDelete(File target) async {
    if (await target.exists()) {
      await target.delete();
    }
  }

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

  static Future<bool> fileOmitsPlaintextNeedle(
    File target,
    String needle,
  ) async {
    if (!await target.exists()) return true;
    final raw = await target.readAsString();
    return !raw.contains(needle);
  }
}

sealed class _DecryptResult {
  const _DecryptResult();
}

final class _DecryptOk extends _DecryptResult {
  const _DecryptOk(this.value);
  final dynamic value;
}

final class _DecryptAuthFail extends _DecryptResult {
  const _DecryptAuthFail();
}

final class _DecryptCorrupt extends _DecryptResult {
  const _DecryptCorrupt();
}
