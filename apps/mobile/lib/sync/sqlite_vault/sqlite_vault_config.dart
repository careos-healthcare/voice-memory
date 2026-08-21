/// iCloud container + object paths for encrypted SQLite vault sync.
abstract final class SqliteVaultConfig {
  SqliteVaultConfig._();

  /// Ubiquity container configured in Apple Developer Portal / Xcode.
  static const iCloudContainerId = 'iCloud.com.voicememory.mobile';

  static const encryptedVaultFileName = 'archiveme_sqlite_vault.enc';

  /// Relative path inside the private iCloud container (not user-visible).
  static String vaultRelativePath(String accountNamespace) {
    final safeNamespace = accountNamespace.trim().isEmpty
        ? 'guest'
        : accountNamespace.trim();
    return 'vault/$safeNamespace/$encryptedVaultFileName';
  }
}
