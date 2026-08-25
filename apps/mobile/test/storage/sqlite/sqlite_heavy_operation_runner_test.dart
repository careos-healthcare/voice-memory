import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/core/constants/database_constants.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/isolate/local_database_worker_service.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_011_reflection_graph_fts.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_database_initializer.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_heavy_operation_runner.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_migration_manager.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_migration_registry.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/sqlite_test_database.dart';

JournalEntry _entry(String id, {String transcript = 'hello'}) {
  final now = DateTime.utc(2026);
  return JournalEntry(
    id: id,
    createdAt: now,
    transcript: transcript,
    durationSeconds: 30,
    reflection: const Reflection(
      mood: 'calm',
      emotionalIntensity: 1,
      recurringThemes: ['focus'],
      exactLanguagePattern: 'pattern',
      concreteObservation: 'observation',
      repeatedSignal: 'signal',
    ),
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await LocalDatabaseWorkerService.instance.dispose();
    await AppSqliteDatabase.resetForTest();
  });

  group('SqliteHeavyOperationRunner', () {
    test('runJournalUpsert mirrors rows on a file-backed database', () async {
      final tempDir = await Directory.systemTemp.createTemp('sqlite-heavy-op');
      addTearDown(() => tempDir.delete(recursive: true));
      final filePath = p.join(tempDir.path, 'journal.db');

      final entries = List.generate(
        SqliteHeavyOperationRunner.entryBatchThreshold,
        (index) => _entry('entry-$index', transcript: 'mirror $index'),
      );

      await SqliteHeavyOperationRunner.runJournalUpsert(
        filePath: filePath,
        encryptionPassword: testSqliteEncryptionPassword,
        entries: entries,
      );

      final db = await openTestAppSqliteDatabase(filePath: filePath);
      final rows = await db.database.query(
        DatabaseConstants.journalEntriesTable,
      );
      expect(rows.length, entries.length);
    });

    test('runGraphBackfill indexes reflection payloads', () async {
      final tempDir = await Directory.systemTemp.createTemp('sqlite-backfill');
      addTearDown(() => tempDir.delete(recursive: true));
      final filePath = p.join(tempDir.path, 'journal.db');

      final schemaDb = await databaseFactoryFfi.openDatabase(
        filePath,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (configuredDb) async {
            await configuredDb.execute(
              "PRAGMA key = '${testSqliteEncryptionPassword.replaceAll("'", "''")}'",
            );
            await configuredDb.execute('PRAGMA foreign_keys = ON');
          },
        ),
      );
      addTearDown(schemaDb.close);

      await SqliteMigrationManager(
        migrations: SqliteMigrationRegistry.defaultMigrations
            .where((migration) => migration.version <= 11)
            .toList(),
      ).run(schemaDb);

      final now = DateTime.utc(2026).millisecondsSinceEpoch;
      await schemaDb.insert(DatabaseConstants.journalEntriesTable, {
        'id': 'graph-entry',
        'created_at': now,
        'updated_at': now,
        'deleted_at': null,
        'is_archived': 0,
        'transcript': 'graph me',
        'has_verified_proof': 0,
        'payload_json': jsonEncode({
          'durationSeconds': 30,
          'reflection': {
            'mood': 'calm',
            'emotionalIntensity': 1,
            'recurringThemes': ['sleep'],
            'exactLanguagePattern': 'pattern',
            'concreteObservation': 'observation',
            'repeatedSignal': 'signal',
            'tensionOrContradiction': 'late nights',
          },
        }),
      });
      await schemaDb.close();

      final backfilled = await SqliteHeavyOperationRunner.runGraphBackfill(
        filePath: filePath,
        encryptionPassword: testSqliteEncryptionPassword,
      );
      expect(backfilled, 1);

      final reopened = await openTestAppSqliteDatabase(filePath: filePath);
      final ftsRows = await reopened.database.query(
        Migration011ReflectionGraphFts.ftsTable,
      );
      expect(
        ftsRows.any(
          (row) =>
              row['entry_id'] == 'graph-entry' &&
              row['label'] == 'late nights',
        ),
        isTrue,
      );
    });

    test('rejects in-memory paths', () async {
      expect(
        () => SqliteHeavyOperationRunner.runJournalUpsert(
          filePath: inMemoryDatabasePath,
          encryptionPassword: testSqliteEncryptionPassword,
          entries: [_entry('one')],
        ),
        throwsStateError,
      );
    });
  });
}
