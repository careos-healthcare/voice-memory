import 'dart:io';

import 'package:archiveme_mobile/features/live_audio/infrastructure/network_connectivity_source.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/models/transcript_status.dart';
import 'package:archiveme_mobile/security/api_usage_guard.dart';
import 'package:archiveme_mobile/security/release_logger.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_middleware.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_proof_analyzer.dart';
import 'package:archiveme_mobile/services/sync/background_sync_queue_gateway.dart';
import 'package:archiveme_mobile/services/sync/background_sync_queue_worker.dart';
import 'package:archiveme_mobile/services/sync/deferred_proof_admission_reconciler.dart';
import 'package:archiveme_mobile/services/sync_service.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/provisional_transcript_reconciler.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../capture_pipeline/capture_pipeline_test_support.dart';

Reflection _reflection() => const Reflection(
  mood: 'calm',
  emotionalIntensity: 1,
  recurringThemes: [],
  exactLanguagePattern: 'exact phrase',
  concreteObservation: 'concrete observation',
  repeatedSignal: 'signal',
);

class _RecordingSyncService implements SyncService {
  _RecordingSyncService(this._inner);

  final SyncService _inner;
  int syncNowCalls = 0;

  @override
  Future<SyncResult> syncNow() async {
    syncNowCalls++;
    return _inner.syncNow();
  }

  @override
  Future<String> lastSyncLabel() => _inner.lastSyncLabel();
}

class _NoCloudSyncService implements SyncService {
  @override
  Future<SyncResult> syncNow() async {
    return const SyncResult(
      cloudSyncSucceeded: false,
      message: 'skipped',
      pushed: 0,
      pulled: 0,
    );
  }

  @override
  Future<String> lastSyncLabel() async => 'never';
}

Future<BackgroundSyncQueueWorker> _buildWorker({
  required JournalStore journal,
  required MobilePrefsStore prefs,
  required SyncService syncService,
  Future<bool> Function()? uploadSqliteVault,
}) async {
  final consentStore = RemoteProcessingConsentStore(prefs);
  final built = await buildCapturePipelineFacade(
    prefs: prefs,
    journal: journal,
    consentStore: consentStore,
  );
  final deps = built.facade.dependencies;
  return BackgroundSyncQueueWorker(
    journalStore: journal,
    syncService: syncService,
    attest: deps.attest,
    transcriptReconciler: ProvisionalTranscriptReconciler(
      captureRepository: deps.captureRepository,
      attest: deps.attest,
      journalStore: journal,
      consentStore: consentStore,
    ),
    proofReconciler: DeferredProofAdmissionReconciler(
      middleware: CapturePipelineMiddleware(
        deps,
        CaptureProofAnalyzer(deps),
      ),
      journalStore: journal,
      consentStore: consentStore,
    ),
    uploadSqliteVault: uploadSqliteVault,
    debounce: Duration.zero,
  );
}

void main() {
  setUp(ApiUsageGuard.resetForTest);

  setUp(() {
    ReleaseLogger.resetForTest();
    ReleaseLogger.forceReleaseSanitizationForTest = true;
  });

  group('BackgroundSyncQueueWorker', () {
    test('needsBackgroundWork detects pending upload and provisional entries', () {
      final pending = JournalEntry(
        id: 'a',
        createdAt: DateTime.utc(2026),
        transcript: 'hello',
        durationSeconds: 1,
        reflection: _reflection(),
        syncStatus: SyncStatus.pendingUpload,
      );
      final provisional = pending.copyWith(
        transcriptStatus: TranscriptStatus.provisional,
      );
      final synced = pending.copyWith(syncStatus: SyncStatus.synced);

      expect(BackgroundSyncQueueWorker.needsBackgroundWork(pending), isTrue);
      expect(BackgroundSyncQueueWorker.needsBackgroundWork(provisional), isTrue);
      expect(BackgroundSyncQueueWorker.needsBackgroundWork(synced), isFalse);
    });

    test('DeferredProofAdmissionReconciler detects placeholder reflection', () {
      final needsProof = JournalEntry(
        id: 'text-local',
        createdAt: DateTime.utc(2026),
        transcript: 'I want more balance at work.',
        durationSeconds: 1,
        reflection: const Reflection(
          mood: 'neutral',
          emotionalIntensity: 0,
          recurringThemes: [],
          exactLanguagePattern: '',
          concreteObservation: '',
          repeatedSignal: '',
        ),
        syncStatus: SyncStatus.pendingUpload,
      );
      expect(
        DeferredProofAdmissionReconciler.needsDeferredProofAdmission(needsProof),
        isTrue,
      );
    });

    test('enqueue and flush attempt cloud sync for pending uploads', () async {
      final dir = Directory.systemTemp.createTempSync('sync_queue_worker_');
      final journal = await JournalStore.open('${dir.path}/journal.json', encryptAtRest: false);
      final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
      final innerSync = _NoCloudSyncService();
      final syncService = _RecordingSyncService(innerSync);
      final worker = await _buildWorker(
        journal: journal,
        prefs: prefs,
        syncService: syncService,
      );

      final entry = JournalEntry(
        id: 'entry-1',
        createdAt: DateTime.utc(2026),
        transcript: 'offline thought',
        durationSeconds: 1,
        reflection: _reflection(),
        syncStatus: SyncStatus.pendingUpload,
      );
      await journal.save(entry);
      worker.enqueue(entry);

      await worker.flush();

      expect(
        ReleaseLogger.testLines.any(
          (line) =>
              line.contains('event=sync_queue_flush_completed') &&
              line.contains('cloud_sync_attempted=true'),
        ),
        isTrue,
      );
    });

    test('journal save schedules encrypted sqlite vault upload', () async {
      final dir = Directory.systemTemp.createTempSync('sync_queue_vault_');
      final journal = await JournalStore.open(
        '${dir.path}/journal.json',
        encryptAtRest: false,
      );
      final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
      var vaultUploadCalls = 0;
      final worker = await _buildWorker(
        journal: journal,
        prefs: prefs,
        syncService: _NoCloudSyncService(),
        uploadSqliteVault: () async {
          vaultUploadCalls++;
          return true;
        },
      );

      final entry = JournalEntry(
        id: 'vault-entry',
        createdAt: DateTime.utc(2026),
        transcript: 'saved locally',
        durationSeconds: 1,
        reflection: _reflection(),
        syncStatus: SyncStatus.synced,
      );
      await journal.save(entry);
      worker.requestSqliteVaultUpload();

      await worker.flush();

      expect(vaultUploadCalls, 1);
      expect(
        ReleaseLogger.testLines.any(
          (line) =>
              line.contains('event=sync_queue_flush_completed') &&
              line.contains('vault_upload_attempted=true') &&
              line.contains('vault_upload_succeeded=true'),
        ),
        isTrue,
      );
    });

    test('retries vault upload when upload fails', () async {
      final dir = Directory.systemTemp.createTempSync('sync_queue_vault_retry_');
      final journal = await JournalStore.open(
        '${dir.path}/journal.json',
        encryptAtRest: false,
      );
      final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
      var vaultUploadCalls = 0;
      final worker = await _buildWorker(
        journal: journal,
        prefs: prefs,
        syncService: _NoCloudSyncService(),
        uploadSqliteVault: () async {
          vaultUploadCalls++;
          return vaultUploadCalls >= 2;
        },
      );

      worker.requestSqliteVaultUpload();
      await worker.flush();
      expect(vaultUploadCalls, 1);

      await worker.flush();
      expect(vaultUploadCalls, 2);
    });
  });

  group('BackgroundSyncQueueGateway', () {
    test('connectivity restore scans pending entries', () async {
      final dir = Directory.systemTemp.createTempSync('sync_queue_gateway_');
      final journal = await JournalStore.open('${dir.path}/journal.json', encryptAtRest: false);
      final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
      final consentStore = RemoteProcessingConsentStore(prefs);
      await consentStore.grant();

      final syncService = _RecordingSyncService(_NoCloudSyncService());
      final connectivity = LifecycleNetworkConnectivitySource();
      final worker = await _buildWorker(
        journal: journal,
        prefs: prefs,
        syncService: syncService,
      );

      await journal.save(
        JournalEntry(
          id: 'entry-2',
          createdAt: DateTime.utc(2026),
          transcript: 'queued offline',
          durationSeconds: 1,
          reflection: _reflection(),
          syncStatus: SyncStatus.pendingUpload,
        ),
      );

      final gateway = BackgroundSyncQueueGateway(
        connectivity: connectivity,
        consentStore: consentStore,
        worker: worker,
      );
      addTearDown(gateway.dispose);

      syncService.syncNowCalls = 0;
      connectivity.notifyConnectivityRestored();
      await Future<void>.delayed(Duration.zero);
      await worker.flush();

      expect(
        ReleaseLogger.testLines.any(
          (line) => line.contains('event=sync_queue_flush_started'),
        ),
        isTrue,
      );
    });

    test('consent restore triggers pending scan', () async {
      final dir = Directory.systemTemp.createTempSync('sync_queue_consent_');
      final journal = await JournalStore.open('${dir.path}/journal.json', encryptAtRest: false);
      final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
      final consentStore = RemoteProcessingConsentStore(prefs);
      await consentStore.withdraw();

      final syncService = _RecordingSyncService(_NoCloudSyncService());
      final connectivity = LifecycleNetworkConnectivitySource();
      final worker = await _buildWorker(
        journal: journal,
        prefs: prefs,
        syncService: syncService,
      );

      await journal.save(
        JournalEntry(
          id: 'entry-3',
          createdAt: DateTime.utc(2026),
          transcript: 'needs sync',
          durationSeconds: 1,
          reflection: _reflection(),
          syncStatus: SyncStatus.pendingUpload,
        ),
      );

      final gateway = BackgroundSyncQueueGateway(
        connectivity: connectivity,
        consentStore: consentStore,
        worker: worker,
      );
      addTearDown(gateway.dispose);

      await consentStore.grant(
        purposes: RemoteProcessingPurposeStorage.onboardingGrant,
      );
      await Future<void>.delayed(Duration.zero);
      await worker.flush();

      expect(
        ReleaseLogger.testLines.any(
          (line) => line.contains('event=sync_queue_flush_started'),
        ),
        isTrue,
      );
    });
  });
}