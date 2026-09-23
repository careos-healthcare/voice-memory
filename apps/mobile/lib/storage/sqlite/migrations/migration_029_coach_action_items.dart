import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Action items and timeline estimates kept inside the encrypted database.
class Migration029CoachActionItems implements SqliteMigration {
  @override
  int get version => 29;

  @override
  String get id => '029_coach_action_items';

  static const table = 'coach_action_items';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        id TEXT PRIMARY KEY,
        entry_id TEXT NOT NULL,
        text TEXT NOT NULL,
        timeline_label TEXT NOT NULL,
        estimate_minutes INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_coach_action_items_entry
      ON $table(entry_id, id)
    ''');
  }
}
