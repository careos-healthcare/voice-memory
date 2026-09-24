import 'package:archiveme_mobile/models/daily_check_in.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_019_time_capsules_and_daily_checkins.dart';
import 'package:sqflite/sqflite.dart';

/// Persists one check-in per calendar day in `daily_checkins`.
class DailyCheckInStore {
  const DailyCheckInStore();

  static const String table =
      Migration019TimeCapsulesAndDailyCheckins.dailyCheckinsTable;

  Future<void> save(Database db, DailyCheckIn checkIn) async {
    await db.rawInsert(
      '''
      INSERT INTO $table (
        id, date_string, mood_score, energy_level, habits_json
      ) VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(date_string) DO UPDATE SET
        mood_score = excluded.mood_score,
        energy_level = excluded.energy_level,
        habits_json = excluded.habits_json
      ''',
      [
        checkIn.id,
        checkIn.dateString,
        checkIn.moodScore,
        checkIn.energyLevel,
        checkIn.habitsJson,
      ],
    );
  }

  Future<List<DailyCheckIn>> loadAll(Database db) async {
    final rows = await db.query(table, orderBy: 'date_string ASC');
    return [for (final row in rows) DailyCheckIn.fromRow(row)];
  }
}
