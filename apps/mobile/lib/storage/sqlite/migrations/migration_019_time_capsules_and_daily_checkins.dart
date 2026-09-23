import 'package:archiveme_mobile/storage/sqlite/sqlite_migration.dart';
import 'package:sqflite/sqflite.dart';

/// Adds time-capsule columns to [journal_entries] and the daily check-in table.
///
/// Fresh installs already receive the columns from migrations 004 and 007.
/// This step adds them when an existing database stopped at version 18, and
/// always creates [dailyCheckinsTable].
class Migration019TimeCapsulesAndDailyCheckins implements SqliteMigration {
  @override
  int get version => 19;

  @override
  String get id => '019_time_capsules_and_daily_checkins';

  static const journalEntriesTable = 'journal_entries';
  static const dailyCheckinsTable = 'daily_checkins';

  static const isTimeCapsuleColumn = 'is_time_capsule';
  static const unlockDateColumn = 'unlock_date';
  static const unlockMilestoneEntryCountColumn = 'unlock_milestone_entry_count';

  @override
  Future<void> up(DatabaseExecutor db) async {
    await _addColumnIfMissing(
      db,
      column: isTimeCapsuleColumn,
      definition: 'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      column: unlockDateColumn,
      definition: 'INTEGER',
    );
    await _addColumnIfMissing(
      db,
      column: unlockMilestoneEntryCountColumn,
      definition: 'INTEGER',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $dailyCheckinsTable (
        id TEXT PRIMARY KEY NOT NULL,
        date_string TEXT NOT NULL UNIQUE,
        mood_score INTEGER NOT NULL CHECK (mood_score BETWEEN 1 AND 5),
        energy_level INTEGER NOT NULL CHECK (energy_level BETWEEN 1 AND 5),
        habits_json TEXT NOT NULL DEFAULT '[]'
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_daily_checkins_date
      ON $dailyCheckinsTable(date_string)
    ''');
  }

  Future<void> _addColumnIfMissing(
    DatabaseExecutor db, {
    required String column,
    required String definition,
  }) async {
    final rows = await db.rawQuery('PRAGMA table_info($journalEntriesTable)');
    final exists = rows.any((row) => row['name'] == column);
    if (exists) return;
    await db.execute(
      'ALTER TABLE $journalEntriesTable ADD COLUMN $column $definition',
    );
  }
}
