import 'package:archiveme_mobile/models/time_capsule_lock.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_019_time_capsules_and_daily_checkins.dart';
import 'package:sqflite/sqflite.dart';

/// Reads and writes time-capsule columns on `journal_entries`.
class TimeCapsuleSealStore {
  const TimeCapsuleSealStore();

  Future<TimeCapsuleLock> read(Database db, String entryId) async {
    final rows = await db.query(
      Migration019TimeCapsulesAndDailyCheckins.journalEntriesTable,
      columns: const [
        Migration019TimeCapsulesAndDailyCheckins.isTimeCapsuleColumn,
        Migration019TimeCapsulesAndDailyCheckins.unlockDateColumn,
        Migration019TimeCapsulesAndDailyCheckins
            .unlockMilestoneEntryCountColumn,
      ],
      where: 'id = ?',
      whereArgs: [entryId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return const TimeCapsuleLock(isTimeCapsule: false);
    }
    return TimeCapsuleLock.fromRow(rows.first);
  }

  Future<void> seal(
    Database db, {
    required String entryId,
    required DateTime unlockDate,
    required int milestoneEntryCount,
  }) async {
    await db.update(
      Migration019TimeCapsulesAndDailyCheckins.journalEntriesTable,
      {
        Migration019TimeCapsulesAndDailyCheckins.isTimeCapsuleColumn: 1,
        Migration019TimeCapsulesAndDailyCheckins.unlockDateColumn: unlockDate
            .toUtc()
            .millisecondsSinceEpoch,
        Migration019TimeCapsulesAndDailyCheckins
                .unlockMilestoneEntryCountColumn:
            milestoneEntryCount,
      },
      where: 'id = ?',
      whereArgs: [entryId],
    );
  }
}
