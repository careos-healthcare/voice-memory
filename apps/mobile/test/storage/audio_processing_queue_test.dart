import 'dart:io';

import 'package:archiveme_mobile/models/audio_processing_queue_item.dart';
import 'package:archiveme_mobile/services/audio_processing_queue_service.dart';
import 'package:archiveme_mobile/storage/audio/local_audio_storage_service.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/audio_processing_queue_repository.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_016_audio_processing_queue.dart';
import 'package:archiveme_mobile/storage/sqlite/sqlite_database_initializer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('LocalAudioStorageService', () {
    late Directory docsDir;
    late LocalAudioStorageService storage;

    setUp(() {
      docsDir = Directory.systemTemp.createTempSync('local_audio_storage_');
      storage = LocalAudioStorageService(
        resolveDocumentsDirectory: () async => docsDir,
      );
    });

    tearDown(() {
      if (docsDir.existsSync()) {
        docsDir.deleteSync(recursive: true);
      }
    });

    test('copies recorder output into documents pending_audio directory', () async {
      final tempFile = File(p.join(docsDir.path, 'tmp_capture.m4a'))
        ..writeAsBytesSync(const [1, 2, 3, 4]);

      final storedPath = await storage.saveRecordingFile(
        sourceFile: tempFile,
        recordingId: 'rec-123',
      );

      expect(storedPath, contains('pending_audio'));
      expect(File(storedPath).existsSync(), isTrue);
      expect(File(storedPath).readAsBytesSync(), const [1, 2, 3, 4]);
    });
  });

  group('AudioProcessingQueueService', () {
    late Directory docsDir;
    late AppSqliteDatabase sqlite;
    late AudioProcessingQueueService service;

    setUp(() async {
      docsDir = Directory.systemTemp.createTempSync('audio_queue_test_');
      final dbPath = p.join(docsDir.path, 'queue.db');
      sqlite = await AppSqliteDatabase.open(
        filePath: dbPath,
        password: SqliteDatabaseInitializer.testEncryptionPassword,
      );
      service = AudioProcessingQueueService(
        storage: LocalAudioStorageService(
          resolveDocumentsDirectory: () async => docsDir,
        ),
        repository: AudioProcessingQueueRepository(sqlite),
        createId: () => 'queue-item-1',
      );
    });

    tearDown(() async {
      await sqlite.close();
      if (docsDir.existsSync()) {
        docsDir.deleteSync(recursive: true);
      }
    });

    test('enqueue persists file and inserts pending sqlite row', () async {
      final source = File(p.join(docsDir.path, 'tmp.m4a'))
        ..writeAsBytesSync(const [9, 8, 7]);

      final item = await service.enqueueRecording(
        sourceFile: source,
        durationMs: 4200,
        timestamp: DateTime.utc(2026, 1, 2),
      );

      expect(item.id, 'queue-item-1');
      expect(item.status, AudioProcessingQueueStatus.pending);
      expect(File(item.filePath).existsSync(), isTrue);

      final row = await AudioProcessingQueueRepository(sqlite).findById(item.id);
      expect(row?.durationMs, 4200);
      expect(row?.status, AudioProcessingQueueStatus.pending);
    });

    test('completeProcessing deletes file and marks row completed', () async {
      final source = File(p.join(docsDir.path, 'tmp2.m4a'))
        ..writeAsBytesSync(const [5, 5, 5]);
      final item = await service.enqueueRecording(
        sourceFile: source,
        durationMs: 1000,
      );

      await service.completeProcessing(item.id);

      expect(File(item.filePath).existsSync(), isFalse);
      final row = await AudioProcessingQueueRepository(sqlite).findById(item.id);
      expect(row?.status, AudioProcessingQueueStatus.completed);
    });
  });
}
