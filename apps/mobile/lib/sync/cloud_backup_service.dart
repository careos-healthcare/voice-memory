import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/account_namespace.dart';
import 'package:archiveme_mobile/sync/cloud_backup_models.dart';
import 'package:archiveme_mobile/sync/cloud_backup_packager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

typedef CloudBackupShareHook = Future<void> Function(String filePath);
typedef CloudBackupPickHook = Future<String?> Function();

/// End-to-end encrypted drift export/import for personal cloud containers.
///
/// Plaintext never leaves the device unencrypted. The service writes a sealed
/// `.archiveme` file the user can place in iCloud Drive or Google Drive.
class EncryptedCloudBackupService {
  EncryptedCloudBackupService({
    required this.sqliteFilePath,
    required this.accountNamespace,
    this.openDatabase,
    this.closeDatabase,
    this.reopenDatabase,
    this.shareBackupFile,
    this.pickBackupFile,
  });

  final String sqliteFilePath;
  final AccountNamespace accountNamespace;
  final Database? openDatabase;
  final Future<void> Function()? closeDatabase;
  final Future<void> Function()? reopenDatabase;
  final CloudBackupShareHook? shareBackupFile;
  final CloudBackupPickHook? pickBackupFile;

  factory EncryptedCloudBackupService.fromAppServices(AppServices services) {
    return EncryptedCloudBackupService(
      sqliteFilePath: services.activeSqliteFilePath,
      accountNamespace: services.activeNamespace,
      openDatabase: services.sqliteDatabase.database,
      closeDatabase: () => services.sqliteDatabase.close(),
      reopenDatabase: () => services.reopenSqliteDatabase(),
    );
  }

  Future<CloudBackupExportResult> exportBackup({
    required String passphrase,
    String? outputDirectory,
  }) async {
    if (passphrase.trim().length < 8) {
      return const CloudBackupExportResult.failure(
        CloudBackupExportFailure.emptyPassphrase,
      );
    }

    try {
      final dbFile = File(sqliteFilePath);
      if (!await dbFile.exists()) {
        return const CloudBackupExportResult.failure(
          CloudBackupExportFailure.missingDatabase,
        );
      }

      final snapshot = await CloudBackupPackager.snapshotDatabaseFile(
        databaseFile: dbFile,
        accountNamespace: accountNamespace.key,
        openDatabase: openDatabase,
      );
      final envelope = await CloudBackupPackager.sealSnapshot(
        snapshot: snapshot,
        passphrase: passphrase,
      );

      final dirPath = outputDirectory ?? (await getTemporaryDirectory()).path;
      final stamp = DateTime.now().toUtc().toIso8601String().split('T').first;
      final outputPath =
          '$dirPath/archiveme_${accountNamespace.key}_$stamp.${CloudBackupFormat.fileExtension}';
      await File(outputPath).writeAsString(
        CloudBackupPackager.encodeEnvelope(envelope),
        flush: true,
      );

      return CloudBackupExportResult.success(
        outputPath: outputPath,
        byteLength: snapshot.databaseBytes.length,
        accountNamespace: accountNamespace.key,
      );
    } on CloudBackupException {
      return const CloudBackupExportResult.failure(
        CloudBackupExportFailure.encryptionFailed,
      );
    } on Object {
      return const CloudBackupExportResult.failure(
        CloudBackupExportFailure.writeFailed,
      );
    }
  }

  Future<CloudBackupExportResult> exportAndShare({
    required String passphrase,
  }) async {
    final exported = await exportBackup(passphrase: passphrase);
    if (!exported.succeeded || exported.outputPath == null) {
      return exported;
    }

    try {
      final share =
          shareBackupFile ??
          (path) => Share.shareXFiles(
            [
              XFile(
                path,
                mimeType: CloudBackupFormat.mimeType,
                name: path.split('/').last,
              ),
            ],
            subject: 'ArchiveMe encrypted backup',
            text:
                'Zero-knowledge encrypted ArchiveMe backup — store in your personal '
                'iCloud Drive or Google Drive folder.',
          );
      await share(exported.outputPath!);
      return exported;
    } on Object {
      return const CloudBackupExportResult.failure(
        CloudBackupExportFailure.shareFailed,
      );
    }
  }

  Future<CloudBackupImportResult> importBackup({
    required String rawEnvelope,
    required String passphrase,
    bool allowNamespaceMismatch = false,
  }) async {
    if (passphrase.trim().length < 8) {
      return const CloudBackupImportResult.failure(
        CloudBackupImportFailure.wrongPassphrase,
      );
    }

    try {
      final envelope = CloudBackupPackager.decodeEnvelope(rawEnvelope);
      final snapshot = await CloudBackupPackager.openSnapshot(
        envelope: envelope,
        passphrase: passphrase,
      );

      if (!allowNamespaceMismatch &&
          snapshot.accountNamespace != accountNamespace.key) {
        return const CloudBackupImportResult.failure(
          CloudBackupImportFailure.namespaceMismatch,
        );
      }

      await closeDatabase?.call();
      await CloudBackupPackager.restoreDatabaseFile(
        snapshot: snapshot,
        targetDatabaseFile: File(sqliteFilePath),
      );
      await reopenDatabase?.call();

      return CloudBackupImportResult.success(
        byteLength: snapshot.databaseBytes.length,
        accountNamespace: snapshot.accountNamespace,
        exportedAt: snapshot.exportedAt,
      );
    } on CloudBackupException catch (error, stackTrace) {
      return CloudBackupImportResult.failure(_mapImportFailure(error.code));
    } on Object {
      return const CloudBackupImportResult.failure(
        CloudBackupImportFailure.restoreFailed,
      );
    }
  }

  Future<CloudBackupImportResult> pickAndImport({
    required String passphrase,
    bool allowNamespaceMismatch = false,
  }) async {
    final raw = await _pickBackupEnvelope();
    if (raw == null) {
      return const CloudBackupImportResult.cancelled();
    }
    return importBackup(
      rawEnvelope: raw,
      passphrase: passphrase,
      allowNamespaceMismatch: allowNamespaceMismatch,
    );
  }

  Future<String?> _pickBackupEnvelope() async {
    final picked = pickBackupFile ?? _defaultPickBackupFile;
    return picked();
  }

  static Future<String?> _defaultPickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [CloudBackupFormat.fileExtension, 'json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.first;
    if (file.bytes != null) {
      return utf8.decode(file.bytes!);
    }
    final path = file.path;
    if (path == null || path.isEmpty) return null;
    return File(path).readAsString();
  }

  static CloudBackupImportFailure _mapImportFailure(String code) {
    return switch (code) {
      'WRONG_PASSPHRASE' || 'PASSPHRASE_TOO_SHORT' =>
        CloudBackupImportFailure.wrongPassphrase,
      'INTEGRITY_CHECK_FAILED' => CloudBackupImportFailure.integrityFailed,
      'INVALID_ENVELOPE' ||
      'INVALID_SNAPSHOT_PAYLOAD' ||
      'INVALID_ENCRYPTED_PAYLOAD' ||
      'UNSUPPORTED_KDF' ||
      'UNSUPPORTED_KDF_ITERATIONS' ||
      'INVALID_BACKUP_SALT' =>
        CloudBackupImportFailure.invalidEnvelope,
      _ => CloudBackupImportFailure.restoreFailed,
    };
  }
}

@visibleForTesting
Future<CloudBackupExportResult> exportEncryptedCloudBackupForTest({
  required String sqliteFilePath,
  required AccountNamespace accountNamespace,
  required String passphrase,
  String? outputDirectory,
}) {
  return EncryptedCloudBackupService(
    sqliteFilePath: sqliteFilePath,
    accountNamespace: accountNamespace,
  ).exportBackup(passphrase: passphrase, outputDirectory: outputDirectory);
}