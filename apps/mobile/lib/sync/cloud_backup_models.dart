// Wire format and result types for encrypted drift cloud backups.
import 'dart:convert';

abstract final class CloudBackupFormat {
  CloudBackupFormat._();

  static const envelopeVersion = 1;
  static const envelopeType = 'archiveme_cloud_backup_v1';
  static const payloadType = 'archiveme_drift_snapshot_v1';
  static const kdfAlgorithm = 'pbkdf2-sha256';
  static const kdfIterations = 210000;
  static const fileExtension = 'archiveme';
  static const mimeType = 'application/octet-stream';
}

enum CloudBackupExportFailure {
  notInitialized,
  missingDatabase,
  emptyPassphrase,
  encryptionFailed,
  writeFailed,
  shareFailed,
}

enum CloudBackupImportFailure {
  notInitialized,
  pickerCancelled,
  invalidEnvelope,
  wrongPassphrase,
  integrityFailed,
  namespaceMismatch,
  restoreFailed,
}

class CloudBackupExportResult {
  const CloudBackupExportResult.success({
    required this.outputPath,
    required this.byteLength,
    required this.accountNamespace,
  }) : failure = null;

  const CloudBackupExportResult.failure(this.failure)
    : outputPath = null,
      byteLength = 0,
      accountNamespace = null;

  final CloudBackupExportFailure? failure;
  final String? outputPath;
  final int byteLength;
  final String? accountNamespace;

  bool get succeeded => failure == null;
}

class CloudBackupImportResult {
  const CloudBackupImportResult.success({
    required this.byteLength,
    required this.accountNamespace,
    required this.exportedAt,
  }) : failure = null,
       cancelled = false;

  const CloudBackupImportResult.cancelled()
    : failure = null,
       cancelled = true,
       byteLength = 0,
       accountNamespace = null,
       exportedAt = null;

  const CloudBackupImportResult.failure(this.failure)
    : cancelled = false,
       byteLength = 0,
       accountNamespace = null,
       exportedAt = null;

  final CloudBackupImportFailure? failure;
  final bool cancelled;
  final int byteLength;
  final String? accountNamespace;
  final DateTime? exportedAt;

  bool get succeeded => failure == null && !cancelled;
}

/// Parsed outer backup envelope written to iCloud / Google Drive containers.
class CloudBackupEnvelope {
  const CloudBackupEnvelope({
    required this.format,
    required this.kdf,
    required this.kdfIterations,
    required this.saltBase64,
    required this.accountNamespace,
    required this.exportedAt,
    required this.payload,
  });

  final String format;
  final String kdf;
  final int kdfIterations;
  final String saltBase64;
  final String accountNamespace;
  final DateTime exportedAt;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
    'format': format,
    'kdf': kdf,
    'kdf_iterations': kdfIterations,
    'salt': saltBase64,
    'account_namespace': accountNamespace,
    'exported_at': exportedAt.toUtc().toIso8601String(),
    'payload': payload,
  };

  static CloudBackupEnvelope? tryParse(Map<String, dynamic> json) {
    final format = json['format'] as String?;
    if (format != CloudBackupFormat.envelopeType) return null;

    final kdf = json['kdf'] as String?;
    final iterations = json['kdf_iterations'];
    final salt = json['salt'] as String?;
    final namespace = json['account_namespace'] as String?;
    final exportedAtRaw = json['exported_at'] as String?;
    final payload = json['payload'];
    if (kdf == null ||
        iterations is! num ||
        salt == null ||
        salt.isEmpty ||
        namespace == null ||
        namespace.isEmpty ||
        exportedAtRaw == null ||
        payload is! Map<String, dynamic>) {
      return null;
    }

    final exportedAt = DateTime.tryParse(exportedAtRaw)?.toUtc();
    if (exportedAt == null) return null;

    return CloudBackupEnvelope(
      format: format!,
      kdf: kdf,
      kdfIterations: iterations.toInt(),
      saltBase64: salt,
      accountNamespace: namespace,
      exportedAt: exportedAt,
      payload: payload,
    );
  }
}

/// Decrypted drift snapshot payload sealed inside the backup envelope.
class CloudBackupDriftSnapshot {
  const CloudBackupDriftSnapshot({
    required this.accountNamespace,
    required this.exportedAt,
    required this.databaseBytes,
    required this.sha256Base64,
    this.schemaMigrationVersion,
  });

  final String accountNamespace;
  final DateTime exportedAt;
  final List<int> databaseBytes;
  final String sha256Base64;
  final int? schemaMigrationVersion;

  Map<String, dynamic> toJson() => {
    'format': CloudBackupFormat.payloadType,
    'account_namespace': accountNamespace,
    'exported_at': exportedAt.toUtc().toIso8601String(),
    'database_bytes': databaseBytes,
    'byte_length': databaseBytes.length,
    'sha256': sha256Base64,
    if (schemaMigrationVersion != null)
      'schema_migration_version': schemaMigrationVersion,
  };

  static CloudBackupDriftSnapshot? tryParse(Map<String, dynamic> json) {
    if (json['format'] != CloudBackupFormat.payloadType) return null;
    final namespace = json['account_namespace'] as String?;
    final exportedAtRaw = json['exported_at'] as String?;
    final bytesRaw = json['database_bytes'];
    final sha256 = json['sha256'] as String?;
    if (namespace == null ||
        namespace.isEmpty ||
        exportedAtRaw == null ||
        sha256 == null ||
        sha256.isEmpty) {
      return null;
    }

    final exportedAt = DateTime.tryParse(exportedAtRaw)?.toUtc();
    if (exportedAt == null) return null;

    final List<int> bytes;
    if (bytesRaw is List) {
      bytes = bytesRaw.whereType<int>().toList(growable: false);
    } else if (bytesRaw is String) {
      try {
        bytes = base64Decode(bytesRaw);
      } on Object {
        return null;
      }
    } else {
      return null;
    }

    if (bytes.isEmpty) return null;

    return CloudBackupDriftSnapshot(
      accountNamespace: namespace,
      exportedAt: exportedAt,
      databaseBytes: bytes,
      sha256Base64: sha256,
      schemaMigrationVersion: (json['schema_migration_version'] as num?)?.toInt(),
    );
  }
}

class CloudBackupException implements Exception {
  CloudBackupException(this.code);
  final String code;

  @override
  String toString() => 'CloudBackupException($code)';
}
