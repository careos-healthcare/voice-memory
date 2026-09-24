import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// Raised when a release open asked for SQLCipher and the linked SQLite
/// has no cipher. Callers must surface this and must not reopen the file
/// without a key.
final class SqlcipherUnavailableException implements Exception {
  const SqlcipherUnavailableException();

  static const message =
      'SQLCipher is not linked. The journal database was not opened.';

  @override
  String toString() => message;
}

/// Checks `PRAGMA cipher_version` on an already-keyed connection.
abstract final class SqlcipherCipherGuard {
  SqlcipherCipherGuard._();

  static Future<String> readCipherVersion(Database database) async {
    final rows = await database.rawQuery('PRAGMA cipher_version');
    if (rows.isEmpty) return '';
    final value = rows.first.values.isEmpty ? null : rows.first.values.first;
    return value?.toString().trim() ?? '';
  }

  /// Release builds with an empty cipher version are refused.
  /// Debug and test builds record the version and still return it.
  static Future<String> assertReleaseCipher(Database database) async {
    final version = await readCipherVersion(database);
    refuseIfUnlinked(version);
    return version;
  }

  static void refuseIfUnlinked(
    String version, {
    bool release = kReleaseMode,
  }) {
    if (release && version.trim().isEmpty) {
      throw const SqlcipherUnavailableException();
    }
  }
}
