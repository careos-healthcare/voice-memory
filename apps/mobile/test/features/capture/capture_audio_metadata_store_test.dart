import 'dart:io';

import 'package:archiveme_mobile/features/capture/models/capture_audio_metadata.dart';
import 'package:archiveme_mobile/features/capture/storage/capture_audio_metadata_store.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_017_capture_audio_metadata.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../storage/sqlite/support/configure_sqlite_test_ffi.dart';

void main() {
  configureSqliteTestFfi();

  group('CaptureAudioMetadataStore', () {
    late Database db;
    late CaptureAudioMetadataStore store;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await Migration017CaptureAudioMetadata().up(db);
      store = CaptureAudioMetadataStore(
        sqliteFilePath: inMemoryDatabasePath,
        openDatabaseOverride: () async => db,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('insertPendingOptimistic writes pending_analysis within budget', () async {
      final row = await store.insertPendingOptimistic(
        id: 'capture-1',
        filePath: '/tmp/capture-1.m4a',
        createdAt: DateTime.utc(2026, 1, 1),
      );

      expect(row.status, Migration017CaptureAudioMetadata.statusPendingAnalysis);
      final loaded = await store.findById('capture-1');
      expect(loaded?.filePath, '/tmp/capture-1.m4a');
    });

    test('completeProcessing deletes file and marks completed', () async {
      final tempDir = await Directory.systemTemp.createTemp('capture-meta');
      addTearDown(tempDir.deleteSync);
      final file = File('${tempDir.path}/capture-2.m4a');
      await file.writeAsString('audio');

      await store.insertPendingOptimistic(
        id: 'capture-2',
        filePath: file.path,
      );

      await store.completeProcessing('capture-2');

      expect(file.existsSync(), isFalse);
      final loaded = await store.findById('capture-2');
      expect(loaded?.status, 'completed');
    });
  });
}
