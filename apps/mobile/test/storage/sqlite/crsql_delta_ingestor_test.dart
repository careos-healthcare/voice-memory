import 'dart:io';

import 'package:archiveme_mobile/storage/sqlite/crsql_delta_ingestor.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_030_sync_purgatory.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_database_initializer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'support/sqlite_test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'orphan clips wait in local purgatory until the transcript arrives',
    () async {
      final root = await Directory.systemTemp.createTemp('sync-purgatory');
      final db = await SqliteDatabaseInitializer.open(
        filePath: '${root.path}/mesh.db',
        passwordOverride: testSqliteEncryptionPassword,
        runDeferredBackfill: false,
        scheduleVectorExtensions: false,
      );
      addTearDown(() async {
        await db.close();
        if (root.existsSync()) root.deleteSync(recursive: true);
      });

      final trace = <String>[];
      final ingestor = CrsqlDeltaIngestor(db, pragmaTrace: trace);
      final early = await ingestor.ingest([
        const CrsqlDeltaPacket(
          table: 'clips',
          pk: 'clip-1',
          cid: 'entry_id',
          val: 'moment-1',
          siteId: 'phone-b',
        ),
        const CrsqlDeltaPacket(
          table: 'coach_action_items',
          pk: 'moment-1:0',
          cid: 'entry_id',
          val: 'moment-1',
          siteId: 'phone-b',
        ),
      ]);

      expect(early.applied, 0);
      expect(early.parked, 2);
      expect(early.restored, 0);
      expect(await _count(db, 'clips'), 0);
      expect(await _count(db, 'coach_action_items'), 0);
      expect(await _count(db, Migration030SyncPurgatory.table), 2);
      expect(trace, ['OFF', 'ON']);
      expect(await _foreignKeys(db), 1);

      final schema = await db.rawQuery(
        'SELECT sql FROM sqlite_master WHERE name = ?',
        [Migration030SyncPurgatory.table],
      );
      expect('${schema.single['sql']}', contains('CREATE TABLE'));
      expect('${schema.single['sql']}'.toLowerCase(), isNot(contains('crsql')));

      final later = await ingestor.ingest([
        const CrsqlDeltaPacket(
          table: 'journal_entries',
          pk: 'moment-1',
          cid: 'transcript',
          val: 'Met Ada',
          siteId: 'phone-b',
        ),
      ]);

      expect(later.applied, 1);
      expect(later.restored, 2);
      expect(await _count(db, 'clips'), 1);
      expect(await _count(db, 'coach_action_items'), 1);
      expect(await _count(db, Migration030SyncPurgatory.table), 0);
      expect(await _foreignKeys(db), 1);
      expect(trace, ['OFF', 'ON', 'OFF', 'ON']);
    },
  );

  test('a failed batch still turns foreign keys back on', () async {
    final root = await Directory.systemTemp.createTemp('sync-purgatory-fail');
    final db = await SqliteDatabaseInitializer.open(
      filePath: '${root.path}/mesh.db',
      passwordOverride: testSqliteEncryptionPassword,
      runDeferredBackfill: false,
      scheduleVectorExtensions: false,
    );
    addTearDown(() async {
      await db.close();
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    final trace = <String>[];
    final ingestor = CrsqlDeltaIngestor(db, pragmaTrace: trace);
    await expectLater(
      ingestor.ingest([
        const CrsqlDeltaPacket(
          table: 'missing_table',
          pk: '1',
          cid: 'name',
          val: 'x',
        ),
      ]),
      throwsA(isA<DatabaseException>()),
    );
    expect(trace, ['OFF', 'ON']);
    expect(await _foreignKeys(db), 1);
  });
}

Future<int> _count(Database db, String table) async {
  final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM $table');
  return (rows.single['n'] as num).toInt();
}

Future<int> _foreignKeys(Database db) async {
  final rows = await db.rawQuery('PRAGMA foreign_keys');
  return (rows.single['foreign_keys'] as num).toInt();
}
