import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Marks moments that stay out of search until the private vault is unlocked.
class Migration025PrivateVault implements SqliteMigration {
  @override
  int get version => 25;

  @override
  String get id => '025_private_vault';

  static const column = 'is_hidden';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      ALTER TABLE journal_entries
      ADD COLUMN $column INTEGER NOT NULL DEFAULT 0
    ''');
  }
}
