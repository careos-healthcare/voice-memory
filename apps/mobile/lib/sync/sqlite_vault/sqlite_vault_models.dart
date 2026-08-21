/// Result of uploading an encrypted SQLite vault to iCloud.
sealed class SqliteVaultUploadResult {
  const SqliteVaultUploadResult._();

  const factory SqliteVaultUploadResult.success({
    required DateTime uploadedAt,
    required String cloudRelativePath,
    required int sealedByteLength,
  }) = SqliteVaultUploadSuccess;

  const factory SqliteVaultUploadResult.failure(SqliteVaultUploadFailure failure) =
      SqliteVaultUploadFailureResult;
}

final class SqliteVaultUploadSuccess extends SqliteVaultUploadResult {
  const SqliteVaultUploadSuccess({
    required this.uploadedAt,
    required this.cloudRelativePath,
    required this.sealedByteLength,
  }) : super._();

  final DateTime uploadedAt;
  final String cloudRelativePath;
  final int sealedByteLength;

  bool get succeeded => true;
}

final class SqliteVaultUploadFailureResult extends SqliteVaultUploadResult {
  const SqliteVaultUploadFailureResult(this.failure) : super._();

  final SqliteVaultUploadFailure failure;

  bool get succeeded => false;
}

enum SqliteVaultUploadFailure {
  cloudUnavailable,
  missingDatabase,
  encryptionFailed,
  uploadFailed,
}

/// Result of restoring a SQLite database from an encrypted iCloud vault.
sealed class SqliteVaultRestoreResult {
  const SqliteVaultRestoreResult._();

  const factory SqliteVaultRestoreResult.success({
    required DateTime restoredAt,
    required String cloudRelativePath,
  }) = SqliteVaultRestoreSuccess;

  const factory SqliteVaultRestoreResult.failure(SqliteVaultRestoreFailure failure) =
      SqliteVaultRestoreFailureResult;
}

final class SqliteVaultRestoreSuccess extends SqliteVaultRestoreResult {
  const SqliteVaultRestoreSuccess({
    required this.restoredAt,
    required this.cloudRelativePath,
  }) : super._();

  final DateTime restoredAt;
  final String cloudRelativePath;

  bool get succeeded => true;
}

final class SqliteVaultRestoreFailureResult extends SqliteVaultRestoreResult {
  const SqliteVaultRestoreFailureResult(this.failure) : super._();

  final SqliteVaultRestoreFailure failure;

  bool get succeeded => false;
}

enum SqliteVaultRestoreFailure {
  cloudUnavailable,
  vaultNotFound,
  decryptionFailed,
  restoreFailed,
}
