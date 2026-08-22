import 'dart:io';
import '../../storage/sqlite/support/sqlite_test_database.dart';

import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/quick_capture/quick_capture_background_handler.dart';
import 'package:archiveme_mobile/features/quick_capture/quick_capture_outbox_models.dart';
import 'package:archiveme_mobile/features/quick_capture/quick_capture_outbox_store.dart';
import 'package:archiveme_mobile/services/capture_pipeline_service.dart';
import 'package:archiveme_mobile/storage/drift/journal_database.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/sync/ulid.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../capture_pipeline/capture_pipeline_test_support.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(AppSqliteDatabase.resetForTest);

  test('processes text captures through capture pipeline', () async {
    final dir = await Directory.systemTemp.createTemp('quick_capture_handler_');
    final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
    final consentStore = RemoteProcessingConsentStore(prefs);
    await consentStore.grant();
    final journal = JournalStore(file: File('${dir.path}/journal.json'));
    final built = await buildCapturePipelineFacade(
      prefs: prefs,
      journal: journal,
      consentStore: consentStore,
    );
    final pipeline = CapturePipelineService(
      captureRepository: built.facade.dependencies.captureRepository,
      attest: built.facade.dependencies.attest,
      journalStore: journal,
      consentStore: consentStore,
      facade: built.facade,
    );
    final sqlite = await openTestAppSqliteDatabase();
    final outbox = QuickCaptureOutboxStore(AppDatabase.fromSqflite(sqlite.database));
    await outbox.enqueue(
      QuickCaptureOutboxPayload(
        captureId: generateUlid(),
        kind: QuickCaptureKind.text,
        text: 'Background widget note',
      ),
    );

    final handler = QuickCaptureBackgroundHandler(
      outbox: outbox,
      pipeline: pipeline,
    );
    final result = await handler.processPending();

    expect(result.processed, 1);
    expect(result.failed, 0);
    expect(await outbox.pendingCount(), 0);
    expect((await journal.loadAll()).single.transcript, 'Background widget note');

    await dir.delete(recursive: true);
  });
}
