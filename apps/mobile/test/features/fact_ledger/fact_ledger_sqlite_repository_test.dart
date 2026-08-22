import 'dart:io';
import '../../storage/sqlite/support/sqlite_test_database.dart';

import 'package:archiveme_mobile/features/fact_ledger/archive_fact.dart';
import 'package:archiveme_mobile/features/fact_ledger/fact_ledger_sqlite_repository.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(AppSqliteDatabase.resetForTest);

  group('FactLedgerSqliteRepository', () {
    test('counts facts and distinct entries', () async {
      final db = await openTestAppSqliteDatabase();
      final repository = FactLedgerSqliteRepository(db);
      final now = DateTime.utc(2026, 1, 2);

      await repository.upsert(
        ArchiveFact(
          id: 'fact_a',
          sourceEntryId: 'entry_1',
          label: 'Anchor',
          value: 'Value one',
          note: '',
          createdAt: now,
          updatedAt: now,
          factType: FactType.other.id,
        ),
      );
      await repository.upsert(
        ArchiveFact(
          id: 'fact_b',
          sourceEntryId: 'entry_1',
          label: 'Anchor',
          value: 'Value two',
          note: '',
          createdAt: now,
          updatedAt: now,
          factType: FactType.other.id,
        ),
      );
      await repository.upsert(
        ArchiveFact(
          id: 'fact_c',
          sourceEntryId: 'entry_2',
          label: 'Anchor',
          value: 'Value three',
          note: '',
          createdAt: now,
          updatedAt: now,
          factType: FactType.other.id,
        ),
      );

      expect(await repository.countFacts(), 3);
      expect(await repository.countDistinctEntries(), 2);
    });

    test('backfills from prefs archiveFacts map', () async {
      final db = await openTestAppSqliteDatabase();
      final repository = FactLedgerSqliteRepository(db);
      final tempDir = await Directory.systemTemp.createTemp('fact_ledger_test');
      addTearDown(() async {
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });
      final prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      final now = DateTime.utc(2026, 2).toIso8601String();

      await prefs.updateMap('archiveFacts', (_) => {
        'fact_1': {
          'id': 'fact_1',
          'sourceEntryId': 'entry_1',
          'label': 'Label',
          'value': 'Value',
          'note': '',
          'createdAt': now,
          'updatedAt': now,
          'factType': FactType.projectDetail.id,
        },
      });

      await repository.ensureBackfilledFromPrefs(prefs);

      expect(await repository.countFacts(), 1);
      expect(await repository.countDistinctEntries(), 1);
    });
  });
}