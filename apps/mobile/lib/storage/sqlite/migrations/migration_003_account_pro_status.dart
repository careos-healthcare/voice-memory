import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Persists merged Pro/Free entitlement snapshot for offline startup reads.
class Migration003AccountProStatus implements SqliteMigration {
  @override
  int get version => 3;

  @override
  String get id => '003_account_pro_status';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS account_pro_status (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        is_pro INTEGER NOT NULL DEFAULT 0,
        tier TEXT NOT NULL DEFAULT 'free',
        source TEXT NOT NULL DEFAULT 'unknown',
        entitlement_ids_json TEXT NOT NULL DEFAULT '[]',
        billing_connected INTEGER NOT NULL DEFAULT 0,
        synced_from TEXT NOT NULL DEFAULT 'unknown',
        updated_at INTEGER NOT NULL
      )
    ''');
  }
}