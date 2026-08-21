import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/storage/sqlite/sqlite_migration_manager.dart';
import 'package:archiveme_mobile/sync/cloud_backup_crypto.dart';
import 'package:archiveme_mobile/sync/cloud_backup_models.dart';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:sqflite/sqflite.dart';

/// Packages the on-device drift SQLite file into encrypted backup envelopes.
abstract final class CloudBackupPackager {
  CloudBackupPackager._();

  static Future<CloudBackupDriftSnapshot> snapshotDatabaseFile({
    required File databaseFile,
    required String accountNamespace,
    Database? openDatabase,
  }) async {
    if (!await databaseFile.exists()) {
      throw CloudBackupException('DATABASE_NOT_FOUND');
    }

    if (openDatabase != null) {
      try {
        await openDatabase.rawQuery('PRAGMA wal_checkpoint(FULL)');
      } on Object {
        // Best-effort — file copy still proceeds.
      }
    }

    final bytes = await databaseFile.readAsBytes();
    if (bytes.isEmpty) {
      throw CloudBackupException('DATABASE_EMPTY');
    }

    final schemaVersion = openDatabase == null
        ? null
        : await _readSchemaVersion(openDatabase);

    return CloudBackupDriftSnapshot(
      accountNamespace: accountNamespace,
      exportedAt: DateTime.now().toUtc(),
      databaseBytes: bytes,
      sha256Base64: base64Encode(sha256.convert(bytes).bytes),
      schemaMigrationVersion: schemaVersion,
    );
  }

  static Future<CloudBackupEnvelope> sealSnapshot({
    required CloudBackupDriftSnapshot snapshot,
    required String passphrase,
  }) async {
    _assertIntegrity(snapshot);

    final derived = await CloudBackupPassphraseKdf.deriveKey(
      passphrase: passphrase,
    );
    final crypto = CloudBackupCrypto(derived.keyBytes);
    final encryptedPayload = await crypto.encryptSnapshot(snapshot);

    return CloudBackupEnvelope(
      format: CloudBackupFormat.envelopeType,
      kdf: CloudBackupFormat.kdfAlgorithm,
      kdfIterations: CloudBackupFormat.kdfIterations,
      saltBase64: derived.saltBase64,
      accountNamespace: snapshot.accountNamespace,
      exportedAt: snapshot.exportedAt,
      payload: encryptedPayload,
    );
  }

  static Future<CloudBackupDriftSnapshot> openSnapshot({
    required CloudBackupEnvelope envelope,
    required String passphrase,
  }) async {
    if (envelope.kdf != CloudBackupFormat.kdfAlgorithm) {
      throw CloudBackupException('UNSUPPORTED_KDF');
    }
    if (envelope.kdfIterations != CloudBackupFormat.kdfIterations) {
      throw CloudBackupException('UNSUPPORTED_KDF_ITERATIONS');
    }

    final salt = CloudBackupPassphraseKdf.decodeSalt(envelope.saltBase64);
    final crypto = await CloudBackupCrypto.fromPassphrase(
      passphrase: passphrase,
      saltBytes: salt,
    );

    try {
      final snapshot = await crypto.decryptSnapshot(envelope.payload);
      _assertIntegrity(snapshot);
      return snapshot;
    } on SyncCryptoException {
      throw CloudBackupException('WRONG_PASSPHRASE');
    } on SecretBoxAuthenticationError {
      throw CloudBackupException('WRONG_PASSPHRASE');
    } on FormatException {
      throw CloudBackupException('WRONG_PASSPHRASE');
    }
  }

  static String encodeEnvelope(CloudBackupEnvelope envelope) {
    return const JsonEncoder.withIndent('  ').convert(envelope.toJson());
  }

  static CloudBackupEnvelope decodeEnvelope(String raw) {
    if (raw.trim().isEmpty) {
      throw CloudBackupException('INVALID_ENVELOPE');
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw CloudBackupException('INVALID_ENVELOPE');
    }
    final envelope = CloudBackupEnvelope.tryParse(decoded);
    if (envelope == null) {
      throw CloudBackupException('INVALID_ENVELOPE');
    }
    return envelope;
  }

  static void _assertIntegrity(CloudBackupDriftSnapshot snapshot) {
    final digest = base64Encode(sha256.convert(snapshot.databaseBytes).bytes);
    if (digest != snapshot.sha256Base64) {
      throw CloudBackupException('INTEGRITY_CHECK_FAILED');
    }
  }

  static Future<int?> _readSchemaVersion(Database db) async {
    try {
      final rows = await db.rawQuery('PRAGMA user_version');
      if (rows.isEmpty) {
        return null;
      }
      final value = rows.first['user_version'];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      return null;
    } on Object {
      return null;
    }
  }

  static Future<void> restoreDatabaseFile({
    required CloudBackupDriftSnapshot snapshot,
    required File targetDatabaseFile,
  }) async {
    _assertIntegrity(snapshot);
    await targetDatabaseFile.parent.create(recursive: true);

    final tempPath =
        '${targetDatabaseFile.path}.restore_${DateTime.now().millisecondsSinceEpoch}';
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(snapshot.databaseBytes, flush: true);

    if (await targetDatabaseFile.exists()) {
      final backupPath = '${targetDatabaseFile.path}.pre_restore';
      if (await File(backupPath).exists()) {
        await File(backupPath).delete();
      }
      await targetDatabaseFile.rename(backupPath);
    }

    await tempFile.rename(targetDatabaseFile.path);
  }
}
