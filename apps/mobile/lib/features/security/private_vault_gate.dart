import 'package:archiveme_mobile/storage/sqlite/migrations/migration_025_private_vault.dart';
import 'package:sqflite/sqflite.dart';

/// Hides private moments from search and the heatmap until biometrics succeed.
abstract final class PrivateVaultGate {
  static bool unlocked = false;

  static void unlock() => unlocked = true;

  static void lock() => unlocked = false;

  /// SQL fragment that drops hidden rows while the vault is locked.
  static Future<String> andSql(DatabaseExecutor db, String alias) async {
    if (unlocked || !await _hasColumn(db)) return '';
    return filterSql(alias);
  }

  /// The locked-vault predicate. Empty once biometrics have succeeded.
  static String filterSql(String alias) {
    if (unlocked) return '';
    final column = alias.isEmpty
        ? Migration025PrivateVault.column
        : '$alias.${Migration025PrivateVault.column}';
    return ' AND COALESCE($column, 0) = 0';
  }

  static Future<void> hide(DatabaseExecutor db, String entryId) {
    return db.update(
      'journal_entries',
      {Migration025PrivateVault.column: 1},
      where: 'id = ?',
      whereArgs: [entryId],
    );
  }

  static Future<bool> _hasColumn(DatabaseExecutor db) async {
    try {
      final rows = await db.rawQuery('PRAGMA table_info(journal_entries)');
      return rows.any((row) => row['name'] == Migration025PrivateVault.column);
    } on Object catch (error) {
      error.runtimeType;
      return false;
    }
  }
}
