import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/storage/account_namespace.dart';
import 'package:archiveme_mobile/sync/cloud_backup_models.dart';
import 'package:archiveme_mobile/sync/cloud_backup_packager.dart';
import 'package:archiveme_mobile/sync/sqlite_vault/sqlite_vault_cloud_transport.dart';
import 'package:archiveme_mobile/sync/sqlite_vault/sqlite_vault_config.dart';
import 'package:archiveme_mobile/sync/sqlite_vault/sqlite_vault_crypto.dart';
import 'package:archiveme_mobile/sync/sqlite_vault/sqlite_vault_key_store.dart';
import 'package:archiveme_mobile/sync/sqlite_vault/sqlite_vault_models.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// End-to-end encrypted SQLite vault sync: local seal → iCloud upload.
///
/// Plaintext database bytes never leave the device. Encryption uses AES-256-GCM
/// via the `encrypt` package; the 256-bit key lives in secure storage through
/// [SqliteVaultKeyStore].
class EncryptedSqliteVaultSyncPipeline {
  EncryptedSqliteVaultSyncPipeline({
    required this.sqliteFilePath,
    required this.accountNamespace,
    required this.keyStore,
    required this.cloudTransport,
    this.openDatabase,
    this.closeDatabase,
    this.reopenDatabase,
    this.containerId = SqliteVaultConfig.iCloudContainerId,
  });

  final String sqliteFilePath;
  final AccountNamespace accountNamespace;
  final SqliteVaultKeyStore keyStore;
  final SqliteVaultCloudTransport cloudTransport;
  final Database? openDatabase;
  final Future<void> Function()? closeDatabase;
  final Future<void> Function()? reopenDatabase;
  final String containerId;

  static bool get supportsICloudVault =>
      !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  String get _cloudRelativePath =>
      SqliteVaultConfig.vaultRelativePath(accountNamespace.key);

  /// Snapshots the local SQLite file, seals it with AES-GCM, and uploads the
  /// ciphertext to the private iCloud container.
  Future<SqliteVaultUploadResult> uploadVault({
    void Function(double progress)? onProgress,
  }) async {
    if (!await cloudTransport.isAvailable()) {
      return const SqliteVaultUploadResult.failure(
        SqliteVaultUploadFailure.cloudUnavailable,
      );
    }

    final dbFile = File(sqliteFilePath);
    if (!await dbFile.exists()) {
      return const SqliteVaultUploadResult.failure(
        SqliteVaultUploadFailure.missingDatabase,
      );
    }

    File? tempEncryptedFile;
    try {
      final snapshot = await CloudBackupPackager.snapshotDatabaseFile(
        databaseFile: dbFile,
        accountNamespace: accountNamespace.key,
        openDatabase: openDatabase,
      );

      final keyBytes = await keyStore.ensureKey();
      final crypto = SqliteVaultCrypto.fromKey(keyBytes);
      final sealedBytes = crypto.sealDatabaseBytes(
        Uint8List.fromList(snapshot.databaseBytes),
      );

      final tempDir = await getTemporaryDirectory();
      tempEncryptedFile = File(
        '${tempDir.path}/archiveme_vault_${DateTime.now().millisecondsSinceEpoch}.enc',
      );
      await tempEncryptedFile.writeAsBytes(sealedBytes, flush: true);

      await cloudTransport.uploadEncryptedVault(
        localEncryptedFilePath: tempEncryptedFile.path,
        cloudRelativePath: _cloudRelativePath,
        onProgress: onProgress,
      );

      AppLogger.debug(
        'Encrypted SQLite vault uploaded to iCloud '
        '(${sealedBytes.length} sealed bytes)',
        name: 'SqliteVaultSync',
      );

      return SqliteVaultUploadResult.success(
        uploadedAt: DateTime.now().toUtc(),
        cloudRelativePath: _cloudRelativePath,
        sealedByteLength: sealedBytes.length,
      );
    } on SqliteVaultCryptoException {
      return const SqliteVaultUploadResult.failure(
        SqliteVaultUploadFailure.encryptionFailed,
      );
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'SQLite vault upload failed',
        name: 'SqliteVaultSync',
        error: error,
        stackTrace: stackTrace,
      );
      return const SqliteVaultUploadResult.failure(
        SqliteVaultUploadFailure.uploadFailed,
      );
    } finally {
      if (tempEncryptedFile != null && await tempEncryptedFile.exists()) {
        await tempEncryptedFile.delete();
      }
    }
  }

  /// Downloads the sealed vault from iCloud, decrypts locally, and replaces
  /// the on-device SQLite database.
  Future<SqliteVaultRestoreResult> restoreVaultFromCloud({
    void Function(double progress)? onProgress,
  }) async {
    if (!await cloudTransport.isAvailable()) {
      return const SqliteVaultRestoreResult.failure(
        SqliteVaultRestoreFailure.cloudUnavailable,
      );
    }

    File? tempEncryptedFile;
    try {
      final tempDir = await getTemporaryDirectory();
      tempEncryptedFile = File(
        '${tempDir.path}/archiveme_vault_restore_${DateTime.now().millisecondsSinceEpoch}.enc',
      );

      try {
        await cloudTransport.downloadEncryptedVault(
          cloudRelativePath: _cloudRelativePath,
          localDestinationFilePath: tempEncryptedFile.path,
          onProgress: onProgress,
        );
      } on SqliteVaultCloudTransportException catch (error) {
        if (error.code == 'VAULT_NOT_FOUND') {
          return const SqliteVaultRestoreResult.failure(
            SqliteVaultRestoreFailure.vaultNotFound,
          );
        }
        rethrow;
      }

      final sealedBytes = await tempEncryptedFile.readAsBytes();
      final keyBytes = await keyStore.readKey();
      if (keyBytes == null) {
        return const SqliteVaultRestoreResult.failure(
          SqliteVaultRestoreFailure.decryptionFailed,
        );
      }

      final crypto = SqliteVaultCrypto.fromKey(keyBytes);
      final databaseBytes = crypto.openSealedDatabaseBytes(
        Uint8List.fromList(sealedBytes),
      );

      await closeDatabase?.call();

      final snapshot = CloudBackupDriftSnapshot(
        accountNamespace: accountNamespace.key,
        exportedAt: DateTime.now().toUtc(),
        databaseBytes: databaseBytes,
        sha256Base64: _sha256Base64(databaseBytes),
      );

      await CloudBackupPackager.restoreDatabaseFile(
        snapshot: snapshot,
        targetDatabaseFile: File(sqliteFilePath),
      );

      await reopenDatabase?.call();

      AppLogger.debug(
        'Encrypted SQLite vault restored from iCloud',
        name: 'SqliteVaultSync',
      );

      return SqliteVaultRestoreResult.success(
        restoredAt: DateTime.now().toUtc(),
        cloudRelativePath: _cloudRelativePath,
      );
    } on SqliteVaultCryptoException {
      return const SqliteVaultRestoreResult.failure(
        SqliteVaultRestoreFailure.decryptionFailed,
      );
    } on CloudBackupException {
      return const SqliteVaultRestoreResult.failure(
        SqliteVaultRestoreFailure.restoreFailed,
      );
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'SQLite vault restore failed',
        name: 'SqliteVaultSync',
        error: error,
        stackTrace: stackTrace,
      );
      return const SqliteVaultRestoreResult.failure(
        SqliteVaultRestoreFailure.restoreFailed,
      );
    } finally {
      if (tempEncryptedFile != null && await tempEncryptedFile.exists()) {
        await tempEncryptedFile.delete();
      }
    }
  }

  String _sha256Base64(List<int> bytes) =>
      base64Encode(sha256.convert(bytes).bytes);
}
