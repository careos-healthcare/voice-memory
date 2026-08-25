import 'dart:io';
import 'dart:isolate';

import 'package:archiveme_mobile/core/constants/database_constants.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/security/sqlite/sqlite_encryption_key_store.dart';
import 'package:archiveme_mobile/storage/sqlite/isolate_safe_sqlite_database_initializer.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_bulk_sync.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_database_encryption_key.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_database_initializer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  setUpAll(() {
    IsolateSafeSqliteDatabaseInitializer.ensureWorkerRuntime(
      initializeTestFfi: true,
    );
  });

  group('IsolateSafeSqliteDatabaseInitializer', () {
    test('resolvePassword reads from key store without lock service', () async {
      final store = InMemorySqliteEncryptionKeyStore(
        seed: SqliteDatabaseEncryptionKey.generate(),
      );

      final password = await IsolateSafeSqliteDatabaseInitializer.resolvePassword(
        keyStore: store,
      );

      expect(password, (await store.readEncryptionKey())!.sqlcipherPassword);
    });

    test('resolvePassword prefers passwordOverride', () async {
      const override = 'explicit-worker-password-override!!';

      final password = await IsolateSafeSqliteDatabaseInitializer.resolvePassword(
        passwordOverride: override,
        keyStore: InMemorySqliteEncryptionKeyStore(),
      );

      expect(password, override);
    });

    test('openWorkerConnection uses singleInstance false WAL connection', () async {
      final dir = await Directory.systemTemp.createTemp('vm_isolate_sqlite_');
      addTearDown(() => dir.delete(recursive: true));
      final filePath = p.join(dir.path, 'worker.db');

      final db = await IsolateSafeSqliteDatabaseInitializer.openWorkerConnection(
        filePath: filePath,
        passwordOverride: SqliteDatabaseInitializer.testEncryptionPassword,
      );
      addTearDown(db.close);

      await db.execute(
        'CREATE TABLE IF NOT EXISTS probe (id INTEGER PRIMARY KEY)',
      );
      await db.insert('probe', {'id': 1});

      final journalMode = await db.rawQuery('PRAGMA journal_mode');
      expect(journalMode.first.values.first.toString().toLowerCase(), 'wal');
    });

    test('worker isolate opens encrypted database independently', () async {
      final dir = await Directory.systemTemp.createTemp('vm_isolate_spawn_');
      addTearDown(() => dir.delete(recursive: true));
      final filePath = p.join(dir.path, 'worker_spawn.db');
      const password = 'worker-isolate-password-thirty-two!!';

      final resultPort = ReceivePort();
      await Isolate.spawn(
        _workerOpenProbe,
        _WorkerOpenProbeArgs(
          resultPort: resultPort.sendPort,
          filePath: filePath,
          passwordOverride: password,
        ),
      );

      final result = await resultPort.first;
      resultPort.close();
      expect(result, isTrue);

      final verifyDb =
          await IsolateSafeSqliteDatabaseInitializer.openWorkerConnection(
        filePath: filePath,
        passwordOverride: password,
      );
      addTearDown(verifyDb.close);

      final rows = await verifyDb.query(DatabaseConstants.journalEntriesTable);
      expect(rows, hasLength(1));
      expect(rows.single['id'], 'worker-probe');
    });
  });
}

final class _WorkerOpenProbeArgs {
  const _WorkerOpenProbeArgs({
    required this.resultPort,
    required this.filePath,
    required this.passwordOverride,
  });

  final SendPort resultPort;
  final String filePath;
  final String passwordOverride;
}

Future<void> _workerOpenProbe(_WorkerOpenProbeArgs args) async {
  try {
    IsolateSafeSqliteDatabaseInitializer.ensureWorkerRuntime(
      initializeTestFfi: true,
    );

    final db = await IsolateSafeSqliteDatabaseInitializer.openWorkerConnection(
      filePath: args.filePath,
      passwordOverride: args.passwordOverride,
    );
    await JournalSqliteBulkSync.upsertEntries(
      db,
      [
        JournalEntry(
          id: 'worker-probe',
          createdAt: DateTime.utc(2026),
          transcript: 'probe',
          durationSeconds: 1,
          reflection: const Reflection(
            mood: 'calm',
            emotionalIntensity: 1,
            recurringThemes: ['focus'],
            exactLanguagePattern: 'pattern',
            concreteObservation: 'observation',
            repeatedSignal: 'signal',
          ),
        ),
      ],
    );
    await db.close();
    args.resultPort.send(true);
  } on Object catch (error) {
    args.resultPort.send(error.toString());
  }
}
