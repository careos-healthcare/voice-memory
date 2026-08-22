import 'package:archiveme_mobile/features/capture/storage/capture_audio_metadata_store.dart';
import 'package:archiveme_mobile/features/llm/application/llm_capture_analysis_service.dart';
import 'package:archiveme_mobile/features/llm/domain/llm_feed_card_state.dart';
import 'package:archiveme_mobile/features/llm/worker/llm_background_worker.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_bootstrap.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_017_capture_audio_metadata.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../storage/sqlite/support/configure_sqlite_test_ffi.dart';

void main() {
  configureSqliteTestFfi();

  group('LlmCaptureAnalysisService', () {
    late Database db;
    late CaptureAudioMetadataStore metadataStore;
    late LlmCaptureAnalysisService service;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      await Migration017CaptureAudioMetadata().up(db);
      metadataStore = CaptureAudioMetadataStore(
        sqliteFilePath: inMemoryDatabasePath,
        openDatabaseOverride: () async => db,
      );

      final llm = await LocalLlmBootstrap.createStub();
      service = LlmCaptureAnalysisService(
        metadataStore: metadataStore,
        worker: LlmBackgroundWorker().attachLoadedService(llm),
      );
    });

    tearDown(() async {
      await service.dispose();
      await db.close();
    });

    test('completes feed card state and metadata row', () async {
      final metadata = await metadataStore.insertPendingOptimistic(
        id: 'capture-1',
        filePath: '/tmp/capture-1.m4a',
      );
      service.registerPendingCapture(
        metadata,
        rawTranscript: 'I need clearer boundaries at work.',
      );

      await service.analyzeCapture(
        metadata: metadata,
        transcript: 'I need clearer boundaries at work.',
        entryId: 'entry-1',
      );

      final state = service.stateFor('capture-1');
      expect(state.status, LlmAnalysisStatus.completed);
      expect(state.summary, isNotEmpty);
      expect(state.nodes, isNotEmpty);

      final row = await metadataStore.findById('capture-1');
      expect(row?.status, 'completed');
    });
  });
}
