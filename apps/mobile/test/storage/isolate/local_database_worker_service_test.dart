import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/storage/isolate/local_database_worker_service.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/journal_sqlite_bulk_sync.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_heavy_operation_runner.dart';
import '../../storage/sqlite/support/sqlite_test_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

JournalEntry _entry(String id, {String transcript = 'hello'}) {
  final now = DateTime.utc(2026, 1, 1);
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

  group('LocalDatabaseWorkerService', () {
    test('reuses one worker isolate for multiple requests', () async {
      final service = LocalDatabaseWorkerService.instance;
      await service.ensureStarted();
      expect(service.isRunning, isTrue);

      final tempDir = await Directory.systemTemp.createTemp('db-worker');
      addTearDown(() => tempDir.delete(recursive: true));
      final filePath = p.join(tempDir.path, 'journal.db');

      final entries = List.generate(
        SqliteHeavyOperationRunner.entryBatchThreshold,
        (index) => _entry('entry-$index', transcript: 'worker $index'),
      );

      await service.runJournalUpsert(
        filePath: filePath,
        encryptionPassword: testSqliteEncryptionPassword,
        entries: entries,
      );
      await service.runJournalUpsert(
        filePath: filePath,
        encryptionPassword: testSqliteEncryptionPassword,
        entries: [
          _entry('entry-follow-up', transcript: 'second batch'),
        ],
      );

      final db = await openTestAppSqliteDatabase(filePath: filePath);
      final rows = await db.database.query(JournalSqliteBulkSync.table);
      expect(rows.length, entries.length + 1);
    });

    test('encryptJsonBatch round-trips through decryptJsonBatch', () async {
      final keyBytes = Uint8List.fromList(List<int>.filled(32, 7));
      const payloads = [
        {'id': 'a', 'note': 'alpha'},
        {'id': 'b', 'note': 'beta'},
      ];

      final encrypted = await LocalDatabaseWorkerService.instance.encryptJsonBatch(
        masterKeyBytes: keyBytes,
        payloadMaps: payloads,
      );
      expect(encrypted, hasLength(2));

      final decrypted =
          await LocalDatabaseWorkerService.instance.decryptJsonBatch(
        masterKeyBytes: keyBytes,
        encryptedPayloadMaps: encrypted.map((item) => item.toJson()).toList(),
      );

      expect(jsonEncode(decrypted), jsonEncode(payloads));
    });

    test('rejects in-memory sqlite paths via runner guard', () async {
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
