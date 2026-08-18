import 'dart:io';

import 'package:archiveme_mobile/core/di/app_provider_container.dart';
import 'package:archiveme_mobile/core/di/network_providers.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/capture_api_client.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/offline_vault_manifest.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/provisional_transcript_reconciler.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:archiveme_mobile/models/attest_result.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/models/transcript_status.dart';
import 'package:archiveme_mobile/security/api_usage_guard.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter_test/flutter_test.dart';

class _ReconcileSpyApi implements CaptureApiClient {
  int postTranscribeCallCount = 0;

  @override
  Future<ApiResult<AttestResult>> postCaptureAttest(
    String deviceId, {
    NetworkCancelToken? cancelToken,
  }) async {
    return ApiSuccess(
      AttestResult.capture(token: 'reconcile-token', expiresInSeconds: 3600),
    );
  }

  @override
  Future<ApiResult<String>> postTranscribe({
    required File audioFile,
    required int durationSeconds,
    required String captureToken,
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  }) async {
    postTranscribeCallCount += 1;
    return const ApiSuccess('final transcript from server');
  }

  @override
  Future<ApiResult<RawModelResponse>> postAnalyzeRaw({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorEvidence = const [],
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  }) async {
    throw UnimplementedError('postAnalyzeRaw');
  }

  @override
  Future<ApiResult<VaultRecoveryServerResult>> postVaultRecovery({
    required File vaultFile,
    required String sessionId,
    required int durationSeconds,
    required String captureToken,
    required String idempotencyKey,
    List<int>? recoverySecretKeyBytes,
    NetworkCancelToken? cancelToken,
  }) async {
    throw UnimplementedError('postVaultRecovery');
  }
}

Future<File> _usableAudioFile() async {
  final dir = Directory.systemTemp.createTempSync('vm_boundary_audio_');
  return File('${dir.path}/voice.m4a')
    ..writeAsBytesSync(List.filled(VoiceCaptureQuality.minAudioBytes, 1));
}

void main() {
  setUp(ApiUsageGuard.resetForTest);

  test('revoked transcription consent blocks provisional reconcile retries',
      () async {
    final api = _ReconcileSpyApi();
    final dir = Directory.systemTemp.createTempSync('vm_boundary_reconcile_');
    await AppServices.resetForTest(
      journalPath: '${dir.path}/journal.json',
      prefsPath: '${dir.path}/prefs.json',
      networkOverrides: [captureApiClientProvider.overrideWithValue(api)],
      grantRemoteProcessingConsentByDefault: true,
    );
    final consentStore = RemoteProcessingConsentStore(AppServices.instance.prefs);
    final audio = await _usableAudioFile();
    final entry = JournalEntry(
      id: 'entry-provisional',
      createdAt: DateTime.utc(2026, 8, 5),
      transcript: 'provisional text',
      durationSeconds: 10,
      reflection: const Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
      syncStatus: SyncStatus.pendingUpload,
      localAudioPath: audio.path,
      transcriptStatus: TranscriptStatus.provisional,
    );
    await AppServices.instance.journalStore.save(entry, first25Source: 'test');
    await consentStore.withdraw();

    final reconciler = ProvisionalTranscriptReconciler(
      captureRepository: appProviderContainer.read(captureRepositoryProvider),
      attest: AppServices.instance.attest,
      journalStore: AppServices.instance.journalStore,
      consentStore: consentStore,
    );

    expect(await reconciler.reconcileEntry(entry), isFalse);
    expect(api.postTranscribeCallCount, 0);
  });
}
