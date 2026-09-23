import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Habits linked to the entity graph, plus the moments that completed them.
class Migration026Habits implements SqliteMigration {
  @override
  int get version => 26;

  @override
  String get id => '026_habits';

  static const habitsTable = 'habits';
  static const logsTable = 'habit_logs';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $habitsTable (
        id TEXT PRIMARY KEY NOT NULL,
        entity_id TEXT,
        title TEXT NOT NULL,
        frequency TEXT NOT NULL,
        target_count INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $logsTable (
        id TEXT PRIMARY KEY NOT NULL,
        habit_id TEXT NOT NULL,
        entry_id TEXT,
        logged_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_habit_logs_habit_time
      ON $logsTable(habit_id, logged_at)
    ''');
  }
}
