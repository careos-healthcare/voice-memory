import 'package:archiveme_mobile/features/feature_unlock/feature_unlock_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../storage/sqlite/support/configure_sqlite_test_ffi.dart';

void main() {
  setUpAll(configureSqliteTestFfi);

  late Database database;
  late FeatureUnlockService service;

  setUp(() async {
    database = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await database.execute('''
      CREATE TABLE journal_entries (
        id TEXT PRIMARY KEY,
        deleted_at INTEGER
      )
    ''');
    service = FeatureUnlockService(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('opens blind spots at 5 entries and theory engines at 10', () async {
    expect((await service.load()).canSeeBlindSpots, isFalse);
    expect(service, isNotNull);

    await _insert(database, 4);
    final four = await service.load();
    expect(four.entryCount, 4);
    expect(four.canSeeBlindSpots, isFalse);
    expect(four.canSeeTheoryEngines, isFalse);
    expect(four.remainingFor(FeatureUnlockMilestone.blindSpots), 1);
    expect(four.pendingCelebrations, isEmpty);

    await _insert(database, 1);
    final five = await service.load();
    expect(five.canSeeBlindSpots, isTrue);
    expect(five.canSeeTheoryEngines, isFalse);
    expect(five.pendingCelebrations, [FeatureUnlockMilestone.blindSpots]);

    final acknowledged = await service.acknowledge(
      FeatureUnlockMilestone.blindSpots,
    );
    expect(acknowledged.pendingCelebrations, isEmpty);
    expect(acknowledged.canSeeBlindSpots, isTrue);

    final again = await service.load();
    expect(again.pendingCelebrations, isEmpty);

    await _insert(database, 5);
    final ten = await service.load();
    expect(ten.entryCount, 10);
    expect(ten.canSeeTheoryEngines, isTrue);
    expect(ten.pendingCelebrations, [FeatureUnlockMilestone.theoryEngines]);
  });

  test('a deleted entry does not count toward the gate', () async {
    await _insert(database, 5);
    await database.update(
      'journal_entries',
      {'deleted_at': 1},
      where: 'id = ?',
      whereArgs: ['entry-0'],
    );
    final state = await service.load();
    expect(state.entryCount, 4);
    expect(state.canSeeBlindSpots, isFalse);
  });

  test('providers expose the flags from the sqlite count', () async {
    await _insert(database, 5);
    final container = ProviderContainer(
      overrides: [
        featureUnlockServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    await container.read(featureUnlockProvider.notifier).refresh();

    expect(container.read(canSeeBlindSpotsProvider), isTrue);
    expect(container.read(canSeeTheoryEnginesProvider), isFalse);
    expect(container.read(featureUnlockProvider).entryCount, 5);
  });
}

Future<void> _insert(Database database, int count) async {
  final existing = Sqflite.firstIntValue(
    await database.rawQuery('SELECT COUNT(*) FROM journal_entries'),
  );
  final start = existing ?? 0;
  for (var index = 0; index < count; index++) {
    await database.insert('journal_entries', {'id': 'entry-${start + index}'});
  }
}
