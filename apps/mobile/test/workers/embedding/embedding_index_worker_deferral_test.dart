import 'package:archiveme_mobile/core/hardware/resource_guard.dart';
import 'package:archiveme_mobile/features/search/reflection_text_processor.dart';
import 'package:archiveme_mobile/services/thermal_throttling/thermal_throttling_service.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/embedding_deferred_queue_store.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_014_embedding_deferred_queue.dart';
import 'package:archiveme_mobile/workers/embedding/embedding_index_worker_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

import '../../storage/sqlite/support/sqlite_test_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(AppSqliteDatabase.resetForTest);

  group('EmbeddingIndexWorkerService battery deferral', () {
    late Directory dir;
    late String dbPath;
    late AppSqliteDatabase sqlite;
    late EmbeddingDeferredQueueStore queueStore;
    late ThermalThrottlingService throttling;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('embedding_defer_');
      dbPath = '${dir.path}/defer.sqlite';
      sqlite = await AppSqliteDatabase.open(
        filePath: dbPath,
        password: testSqliteEncryptionPassword,
      );
      queueStore = EmbeddingDeferredQueueStore(sqlite.database);
      throttling = ThermalThrottlingService(
        resourceGuard: ResourceGuard.shared,
      );
      throttling.debugForceDeferEmbedding = true;
      EmbeddingIndexWorkerService.instance.configure(
        thermalThrottling: throttling,
        deferredQueue: queueStore,
      );
    });

    tearDown(() async {
      throttling.dispose();
      await EmbeddingIndexWorkerService.instance.dispose();
      await sqlite.close();
      await dir.delete(recursive: true);
    });

    test('indexReflection enqueues deferred task when battery constrained', () async {
      const entryId = 'entry-deferred-reflection';
      const text =
          'Work has been overwhelming and I keep accepting more tasks even when I need rest.';
      expect(text.length, greaterThanOrEqualTo(ReflectionTextProcessor.minTextChars));

      final indexed = await EmbeddingIndexWorkerService.instance.indexReflection(
        filePath: dbPath,
        entryId: entryId,
        text: text,
        contentHash: 'hash-1',
        encryptionPassword: testSqliteEncryptionPassword,
      );

      expect(indexed, isFalse);
      expect(await queueStore.pendingCount(), 1);

      final pending = await queueStore.listPending();
      expect(pending.single.operation,
          Migration014EmbeddingDeferredQueue.operationIndexReflection);
      expect(pending.single.entryId, entryId);
    });

    test('flushDeferredQueue processes queued tasks once power is available', () async {
      const entryId = 'entry-deferred-flush';
      const text =
          'Another late night at work because I said yes again despite feeling exhausted.';

      await EmbeddingIndexWorkerService.instance.indexReflection(
        filePath: dbPath,
        entryId: entryId,
        text: text,
        contentHash: 'hash-2',
        encryptionPassword: testSqliteEncryptionPassword,
      );
      expect(await queueStore.pendingCount(), 1);

      throttling.debugForceDeferEmbedding = false;
      final flushed = await EmbeddingIndexWorkerService.instance.flushDeferredQueue();

      expect(flushed, 1);
      expect(await queueStore.pendingCount(), 0);
    });
  });
}
