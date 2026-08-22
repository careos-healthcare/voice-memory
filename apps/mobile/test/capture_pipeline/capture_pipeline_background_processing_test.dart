import 'dart:io';
import '../storage/sqlite/support/sqlite_test_database.dart';

import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/privacy/on_device_processing_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/vision/image_embedding_service.dart';
import 'package:archiveme_mobile/features/vision/local_visual_projection_inference.dart';
import 'package:archiveme_mobile/models/image_evidence.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/security/api_usage_guard.dart';
import 'package:archiveme_mobile/security/release_logger.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_dependencies.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_facade.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_models.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_proof_analyzer.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/image_attachment_embedding_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'capture_pipeline_test_support.dart';

class FailingLoadAllJournalStore extends JournalStore {
  FailingLoadAllJournalStore({required super.file});

  @override
  Future<List<JournalEntry>> loadAll() async {
    throw StateError('journal load failed');
  }
}

class ThrowingImageEmbeddingService extends ImageEmbeddingService {
  ThrowingImageEmbeddingService({
    required ImageAttachmentEmbeddingRepository repository,
  }) : super(
          inference: LocalVisualProjectionInference(),
          repository: repository,
        );

  @override
  Future<void> indexJournalAttachment({
    required String entryId,
    required ImageEvidence evidence,
    JournalEntry? journalEntryForMirror,
  }) async {
    throw StateError('embedding index failed');
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    ApiUsageGuard.resetForTest();
    ReleaseLogger.resetForTest();
    ReleaseLogger.forceReleaseSanitizationForTest = true;
    AppSqliteDatabase.resetForTest();
  });

  group('capture background processing failures', () {
    test('_relatedSources logs and degrades when journal load fails', () async {
      final dir = await Directory.systemTemp.createTemp('related_sources_test_');
      final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
      final consentStore = RemoteProcessingConsentStore(prefs);
      await OnDeviceProcessingStore.resetForTest();
      await OnDeviceProcessingStore.setEnabled(false);
      await consentStore.grant();

      final built = await buildCapturePipelineFacade(
        prefs: prefs,
        journal: FailingLoadAllJournalStore(
          file: File('${dir.path}/journal.json'),
        ),
        consentStore: consentStore,
      );
      final analyzer = CaptureProofAnalyzer(built.facade.dependencies);

      final proof = await analyzer.postAndAdmit(
        transcript: 'I keep saying I want more balance but I still take on extra work.',
        captureToken: 'capture-token',
        idempotencyKey: 'idem-related-sources',
        entryId: 'entry-related-sources',
        sourceType: ProofSourceType.userTyped,
      );

      expect(proof.reflection.concreteObservation, isNotEmpty);
      final line = ReleaseLogger.testLines.singleWhere(
        (entry) => entry.contains('event=capture_background_processing_failed'),
      );
      expect(line, contains('operation=related_sources'));
      expect(line, contains('error_code=invalid_state'));
      expect(line, isNot(contains('journal load failed')));

      await dir.delete(recursive: true);
    });

    test('_indexImageEmbedding logs and does not block caption save', () async {
      final dir = await Directory.systemTemp.createTemp('image_embed_fail_test_');
      final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
      final consentStore = RemoteProcessingConsentStore(prefs);
      await consentStore.withdraw();

      final journal = JournalStore(file: File('${dir.path}/journal.json'));
      final built = await buildCapturePipelineFacade(
        prefs: prefs,
        journal: journal,
        consentStore: consentStore,
      );
      final db = await openTestAppSqliteDatabase();
      final embeddingService = ThrowingImageEmbeddingService(
        repository: ImageAttachmentEmbeddingRepository(db),
      );
      final deps = CapturePipelineDependencies(
        captureRepository: built.facade.dependencies.captureRepository,
        attest: built.facade.dependencies.attest,
        journalStore: journal,
        consentStore: consentStore,
        usageGuard: built.facade.dependencies.usageGuard,
        proofAdmission: built.facade.dependencies.proofAdmission,
        scopeProvider: built.facade.dependencies.scopeProvider,
        imageEmbeddingService: embeddingService,
      );
      final facade = CapturePipelineFacade.standard(deps);

      final result = (await facade.saveImageCaptionEntry(
        caption: 'A photo of the garden after the rain.',
        imageEvidence: ImageEvidence(
          evidenceId: 'evidence-1',
          caption: 'A photo of the garden after the rain.',
          mimeType: 'image/jpeg',
          attachedAt: DateTime.utc(2026, 8, 18),
        ),
      )).getOrThrow();

      expect(result.localSaved, isTrue);
      final saved = await journal.loadAll();
      expect(saved, hasLength(1));
      expect(saved.single.imageEvidence?.evidenceId, 'evidence-1');

      final line = ReleaseLogger.testLines.singleWhere(
        (entry) => entry.contains('event=capture_background_processing_failed'),
      );
      expect(line, contains('operation=image_embedding_index'));
      expect(line, contains('error_code=invalid_state'));
      expect(line, isNot(contains('embedding index failed')));

      await dir.delete(recursive: true);
    });
  });
}
