import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Detects legacy plaintext SQLite files and rewrites them as SQLCipher DBs.
abstract final class SqliteEncryptionMigrator {
  SqliteEncryptionMigrator._();

  static const _sqliteMagic = 'SQLite format 3';

  static Future<void> migratePlaintextIfNeeded({
    required String filePath,
    required String password,
    required Future<void> Function(
      String targetPath,
      String password,
      Future<void> Function(dynamic db) body,
    )
    openEncrypted,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) return;
    if (!await _isPlaintextSqlite(file)) return;

    final tempEncryptedPath = p.setExtension(filePath, '.encrypted-temp');
    if (await File(tempEncryptedPath).exists()) {
      await File(tempEncryptedPath).delete();
    }

    await openEncrypted(tempEncryptedPath, password, (encryptedDb) async {
      final escapedPath = filePath.replaceAll("'", "''");
      await encryptedDb.execute(
        "ATTACH DATABASE '$escapedPath' AS plaintext KEY ''",
      );
      await encryptedDb.execute("SELECT sqlcipher_export('plaintext')");
      await encryptedDb.execute('DETACH DATABASE plaintext');
    });

    await file.delete();
    await File(tempEncryptedPath).rename(filePath);
  }

  static Future<bool> _isPlaintextSqlite(File file) async {
    final raf = await file.open();
    try {
      final header = await raf.read(16);
      if (header.length < 16) return false;
      return String.fromCharCodes(header).startsWith(_sqliteMagic);
    } finally {
      await raf.close();
    }
  }
}
