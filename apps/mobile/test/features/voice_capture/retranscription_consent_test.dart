import 'dart:io';

import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/capture_api_client.dart';
import 'package:archiveme_mobile/data/repositories/capture_repository.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/offline_vault_manifest.dart';
import 'package:archiveme_mobile/features/privacy/on_device_processing_store.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/provisional_transcript_reconciler.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:archiveme_mobile/models/attest_result.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/models/transcript_provenance.dart';
import 'package:archiveme_mobile/models/transcript_status.dart';
import 'package:archiveme_mobile/security/api_usage_guard.dart';
import 'package:archiveme_mobile/storage/capture_token_cache.dart';
import 'package:archiveme_mobile/services/capture_attest_service.dart';
import 'package:archiveme_mobile/storage/device_id.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts every call that would put a recording on the wire.
///
/// `/api/transcribe` forwards audio to OpenAI Whisper, so a non-zero count in
/// a case where the user has not agreed to that is a mental-health recording
/// leaving the device when it should not have.
class _TranscribeSpyApi implements CaptureApiClient {
  int postTranscribeCallCount = 0;

  @override
  Future<ApiResult<AttestResult>> postCaptureAttest(
    String deviceId, {
    NetworkCancelToken? cancelToken,
  }) async {
    return ApiSuccess(
      AttestResult.capture(token: 'retranscribe-token', expiresInSeconds: 3600),
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
    return const ApiSuccess(
      'I said yes to the extra project even though I am already stretched.',
    );
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

class _FakeDeviceIdStore extends DeviceIdStore {
  @override
  Future<String> getOrCreate() async => '00000000-0000-4000-8000-000000000001';
}

void main() {
  late Directory dir;
  late _TranscribeSpyApi api;
  late RemoteProcessingConsentStore consentStore;
  late JournalStore journalStore;
  late ProvisionalTranscriptReconciler reconciler;
  late String audioPath;

  JournalEntry provisionalEntry({String id = 'entry-provisional'}) =>
      JournalEntry(
        id: id,
        createdAt: DateTime.utc(2026, 8, 5),
        transcript: 'provisional device transcript',
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
        localAudioPath: audioPath,
        transcriptStatus: TranscriptStatus.provisional,
      );

  setUp(() async {
    ApiUsageGuard.resetForTest();
    await OnDeviceProcessingStore.resetForTest();

    dir = await Directory.systemTemp.createTemp('vm_retranscribe_');
    audioPath = '${dir.path}/voice.m4a';
    File(audioPath).writeAsBytesSync(
      List.filled(VoiceCaptureQuality.minAudioBytes, 1),
    );

    api = _TranscribeSpyApi();
    final captureRepository = CaptureRepository(
      api: api,
      requestScope: NetworkRequestScope(),
    );
    consentStore = RemoteProcessingConsentStore(
      await MobilePrefsStore.open('${dir.path}/prefs.json'),
    );
    journalStore = JournalStore(file: File('${dir.path}/journal.json'));
    reconciler = ProvisionalTranscriptReconciler(
      captureRepository: captureRepository,
      attest: CaptureAttestService(
        captureRepository: captureRepository,
        deviceIds: _FakeDeviceIdStore(),
        tokenCache: CaptureTokenCache()
          ..setToken('capture-token', expiresInSeconds: 3600),
      ),
      journalStore: journalStore,
      consentStore: consentStore,
    );
  });

  tearDown(() async {
    await OnDeviceProcessingStore.resetForTest();
  });

  test('the on-device-only default alone blocks the upload', () async {
    // Consent for remote transcription is granted here, so this test turns
    // entirely on the local switch. It is at its shipped default: a user who
    // has never opened settings must not have their recordings uploaded.
    await consentStore.grantPurpose(
      RemoteProcessingPurpose.remoteTranscription,
    );
    expect(OnDeviceProcessingStore.defaultEnabled, isTrue);
    expect(OnDeviceProcessingStore.enabled, isTrue);
    expect(
      await consentStore.isPurposeGrantedNow(
        RemoteProcessingPurpose.remoteTranscription,
      ),
      isTrue,
    );

    final entry = provisionalEntry();
    await journalStore.save(entry, first25Source: 'test');

    expect(await reconciler.reconcileEntry(entry), isFalse);
    expect(api.postTranscribeCallCount, 0);
  });

  test('turning the switch off is not enough without consent', () async {
    await OnDeviceProcessingStore.setEnabled(false);
    await consentStore.withdraw();

    final entry = provisionalEntry();
    await journalStore.save(entry, first25Source: 'test');

    expect(await reconciler.reconcileEntry(entry), isFalse);
    expect(api.postTranscribeCallCount, 0);
  });

  test('consent for a different purpose does not unlock transcription',
      () async {
    await OnDeviceProcessingStore.setEnabled(false);
    await consentStore.grant(
      purposes: {RemoteProcessingPurpose.remoteReflection},
    );

    final entry = provisionalEntry();
    await journalStore.save(entry, first25Source: 'test');

    expect(await reconciler.reconcileEntry(entry), isFalse);
    expect(api.postTranscribeCallCount, 0);
  });

  test('neither gate open means no upload', () async {
    await consentStore.withdraw();

    final entry = provisionalEntry();
    await journalStore.save(entry, first25Source: 'test');

    expect(await reconciler.reconcileEntry(entry), isFalse);
    expect(api.postTranscribeCallCount, 0);
  });

  test('a sweep of the whole archive uploads nothing under the default',
      () async {
    // The shape a bulk recovery migration would take. Under shipped defaults
    // it must move no audio at all.
    await consentStore.grantPurpose(
      RemoteProcessingPurpose.remoteTranscription,
    );
    for (var i = 0; i < 5; i++) {
      await journalStore.save(
        provisionalEntry(id: 'entry-$i'),
        first25Source: 'test',
      );
    }

    expect(await reconciler.reconcileAll(), 0);
    expect(api.postTranscribeCallCount, 0);
  });

  test('both gates open re-transcribes and stamps the result speech-to-text',
      () async {
    // The permissive case, so the refusals above are shown to be gates rather
    // than an unconditional no.
    await OnDeviceProcessingStore.setEnabled(false);
    await consentStore.grantPurpose(
      RemoteProcessingPurpose.remoteTranscription,
    );

    final entry = provisionalEntry();
    await journalStore.save(entry, first25Source: 'test');

    expect(await reconciler.reconcileEntry(entry), isTrue);
    expect(api.postTranscribeCallCount, 1);

    final stored = await journalStore.getById(entry.id);
    expect(stored, isNotNull);
    expect(stored!.transcriptProvenance, TranscriptProvenance.speechToText);
    expect(stored.transcriptStatus, TranscriptStatus.finalTranscript);
  });
}
