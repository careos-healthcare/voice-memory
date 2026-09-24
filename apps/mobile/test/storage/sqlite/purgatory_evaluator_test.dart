import 'dart:io';

import 'package:archiveme_mobile/storage/isolate/local_database_worker_service.dart';
import 'package:archiveme_mobile/storage/sqlite/crsql_delta_ingestor.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_030_sync_purgatory.dart';
import 'package:archiveme_mobile/storage/sqlite/purgatory_evaluator_service.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_database_initializer.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import 'support/sqlite_test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a missing parent stays parked and the next row still applies',
    () async {
      final root = await Directory.systemTemp.createTemp('purgatory-eval');
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

      final warnings = <String>[];
      final ingestor = CrsqlDeltaIngestor(
        db,
        warningSink: warnings.add,
      );
      final parked = await ingestor.ingest([
        const CrsqlDeltaPacket(
          table: 'clips',
          pk: 'clip-waiting',
          cid: 'entry_id',
          val: 'moment-missing',
          siteId: 'phone-b',
        ),
        const CrsqlDeltaPacket(
          table: 'clips',
          pk: 'clip-ready',
          cid: 'entry_id',
          val: 'moment-ready',
          siteId: 'phone-b',
        ),
      ]);
      expect(parked.parked, 2);
      expect(parked.restored, 0);

      await db.insert('journal_entries', {
        'id': 'moment-ready',
        'created_at': 1,
        'updated_at': 1,
        'transcript': 'Met Ada',
      });

      final restored = await ingestor.evaluateInTransaction();

      expect(restored, 1);
      expect(warnings, isNotEmpty);
      expect(await _count(db, 'clips'), 1);
      expect(await _count(db, Migration030SyncPurgatory.table), 1);
      final stillParked = await db.query(
        Migration030SyncPurgatory.table,
        columns: const ['pk'],
      );
      expect(stillParked.single['pk'], 'clip-waiting');
      expect(await _foreignKeys(db), 1);
    },
  );

  test('foreground, startup, and the session timer request a flush', () {
    fakeAsync((async) {
      var calls = 0;
      final service = PurgatoryEvaluatorService(
        evaluateOverride: () async {
          calls += 1;
          return 0;
        },
      );

      service.configure(filePath: '/tmp/archiveme.db');
      service.onStartup();
      service.onForeground();
      async.flushMicrotasks();
      expect(calls, 2);

      service.afterP2pBatch('/tmp/archiveme.db');
      async.flushMicrotasks();
      expect(service.sessionActive, isTrue);
      expect(calls, 3);

      async.elapse(const Duration(seconds: 30));
      async.flushMicrotasks();
      expect(calls, 4);

      service.endSyncSession();
      async.elapse(const Duration(seconds: 30));
      expect(service.sessionActive, isFalse);
      expect(calls, 4);
    });
  });

  test('the background isolate flushes a row once its parent exists', () async {
    final root = await Directory.systemTemp.createTemp('purgatory-isolate');
    final path = '${root.path}/mesh.db';
    final db = await SqliteDatabaseInitializer.open(
      filePath: path,
      passwordOverride: testSqliteEncryptionPassword,
      runDeferredBackfill: false,
      scheduleVectorExtensions: false,
    );
    addTearDown(() async {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    await CrsqlDeltaIngestor(db).ingest([
      const CrsqlDeltaPacket(
        table: 'clips',
        pk: 'clip-late',
        cid: 'entry_id',
        val: 'moment-late',
        siteId: 'phone-b',
      ),
    ]);
    await db.insert('journal_entries', {
      'id': 'moment-late',
      'created_at': 1,
      'updated_at': 1,
      'transcript': 'Met Ada',
    });
    await db.close();
    addTearDown(LocalDatabaseWorkerService.instance.dispose);

    final service = PurgatoryEvaluatorService();
    service.configure(
      filePath: path,
      encryptionPassword: testSqliteEncryptionPassword,
    );
    final restored = await service.evaluate();
    expect(restored, 1);

    final check = await SqliteDatabaseInitializer.open(
      filePath: path,
      passwordOverride: testSqliteEncryptionPassword,
      runDeferredBackfill: false,
      scheduleVectorExtensions: false,
    );
    addTearDown(check.close);
    expect(await _count(check, 'clips'), 1);
    expect(await _count(check, Migration030SyncPurgatory.table), 0);
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
