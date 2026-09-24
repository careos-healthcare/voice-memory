import 'package:archiveme_mobile/models/daily_check_in.dart';
import 'package:archiveme_mobile/models/time_capsule_lock.dart';
import 'package:archiveme_mobile/storage/sqlite/memory_transcript_search_repository.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_005_hybrid_search.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_019_time_capsules_and_daily_checkins.dart';
import 'package:archiveme_mobile/storage/sqlite/time_capsule_visibility.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/sqlite_migration_test_harness.dart';

void main() {
  configureSqliteMigrationTests();

  test('migration 019 adds capsule columns and daily_checkins', () async {
    final harness = SqliteMigrationTestHarness();
    final db = await harness.openLatest();

    final columns = await db.rawQuery('PRAGMA table_info(journal_entries)');
    final names = columns.map((row) => row['name']).toSet();
    expect(names, contains('is_time_capsule'));
    expect(names, contains('unlock_date'));
    expect(names, contains('unlock_milestone_entry_count'));

    await harness.expectTableExists(
      db,
      Migration019TimeCapsulesAndDailyCheckins.dailyCheckinsTable,
    );

    final checkIn = DailyCheckIn(
      id: 'check-1',
      dateString: '2026-09-21',
      moodScore: 4,
      energyLevel: 3,
      habitsJson: '["walk"]',
    );
    await db.insert(
      Migration019TimeCapsulesAndDailyCheckins.dailyCheckinsTable,
      checkIn.toRow(),
    );
    final stored = DailyCheckIn.fromRow(
      (await db.query(
        Migration019TimeCapsulesAndDailyCheckins.dailyCheckinsTable,
      )).single,
    );
    expect(stored.moodScore, 4);
    expect(stored.habitsJson, '["walk"]');
    expect(
      () => DailyCheckIn(
        id: 'bad',
        dateString: '2026-09-21',
        moodScore: 0,
        energyLevel: 3,
      ),
      throwsArgumentError,
    );
  });

  test(
    'locked capsules stay out of full-text search until they open',
    () async {
      final harness = SqliteMigrationTestHarness();
      final db = await harness.openLatest();
      await db.execute('''
      INSERT INTO journal_entries (
        id, created_at, updated_at, is_archived, transcript,
        has_verified_proof, payload_json, is_time_capsule, unlock_date,
        unlock_milestone_entry_count
      ) VALUES
        ('open', 1, 1, 0, 'morning walk', 0, '{}', 0, NULL, NULL),
        ('sealed', 2, 2, 0, 'morning letter', 0, '{}', 1, 9999999999999, NULL)
    ''');
      await db.execute('''
      INSERT INTO ${Migration005HybridSearch.ftsTable} (entry_id, transcript)
      VALUES ('open', 'morning walk'), ('sealed', 'morning letter')
    ''');

      final search = MemoryTranscriptSearchRepository.fromWorkerDatabase(db);
      final sealed = await search.keywordSearch(query: 'morning');
      expect(sealed, ['open']);

      final locked = TimeCapsuleLock(
        isTimeCapsule: true,
        unlockDateMillis: 9999999999999,
      );
      expect(
        locked.isUnlocked(nowMillis: 10, activeEntryCount: 2),
        isFalse,
      );

      await db.update(
        'journal_entries',
        {'unlock_date': 1},
        where: 'id = ?',
        whereArgs: ['sealed'],
      );
      final opened = await search.keywordSearch(query: 'morning');
      expect(opened, containsAll(['open', 'sealed']));

      await db.update(
        'journal_entries',
        {'unlock_date': null, 'unlock_milestone_entry_count': 100},
        where: 'id = ?',
        whereArgs: ['sealed'],
      );
      expect(await TimeCapsuleVisibility.isEntryLocked(db, 'sealed'), isTrue);
      expect(await search.keywordSearch(query: 'morning'), ['open']);
    },
  );
}
