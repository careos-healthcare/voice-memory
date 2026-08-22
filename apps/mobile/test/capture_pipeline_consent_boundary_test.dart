import 'dart:io';

import 'package:archiveme_mobile/core/di/app_provider_container.dart';
import 'package:archiveme_mobile/core/di/network_providers.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/capture_api_client.dart';
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
import 'package:archiveme_mobile/models/transcript_status.dart';
import 'package:archiveme_mobile/security/api_usage_guard.dart';
import 'package:archiveme_mobile/security/remote_processing_consent_gate.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/services.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const connectivity = MethodChannel(
      'dev.fluttercommunity.plus/connectivity',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivity, (call) async {
      if (call.method == 'check') return ['wifi'];
      return null;
    });

    // Capture attestation reads a device id from secure storage. Only the
    // positive control gets far enough to need it — which is the point of
    // having one, since the refusal case passes whether or not this works.
    const secureStorage = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    final secureValues = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorage, (call) async {
      final args = call.arguments as Map<Object?, Object?>? ?? const {};
      final key = args['key'] as String?;
      switch (call.method) {
        case 'read':
          return key == null ? null : secureValues[key];
        case 'write':
          if (key != null) secureValues[key] = args['value'] as String? ?? '';
          return null;
        case 'containsKey':
          return key != null && secureValues.containsKey(key);
        case 'readAll':
          return Map<String, String>.of(secureValues);
        case 'delete':
          secureValues.remove(key);
          return null;
        case 'deleteAll':
          secureValues.clear();
          return null;
        default:
          return null;
      }
    });
  });

  setUp(ApiUsageGuard.resetForTest);

  tearDown(() async {
    await OnDeviceProcessingStore.resetForTest();
  });

  /// Brings the pipeline up with both halves of the gate stated outright.
  ///
  /// The veto has to be set explicitly. `AppServices.resetForTest` never writes
  /// `OnDeviceProcessingStore`, and its unset value resolves from the host
  /// platform — true for everything except Android, so it is silently ON under
  /// `flutter test`. Left alone, it refuses every upload on its own and a
  /// consent assertion made from that state passes without consent being
  /// consulted at all.
  Future<RemoteProcessingConsentStore> initBoundary({
    required _ReconcileSpyApi api,
    required bool onDeviceOnly,
  }) async {
    final dir = Directory.systemTemp.createTempSync('vm_boundary_reconcile_');
    await AppServices.resetForTest(
      journalPath: '${dir.path}/journal.json',
      prefsPath: '${dir.path}/prefs.json',
      networkOverrides: [captureApiClientProvider.overrideWithValue(api)],
      grantRemoteProcessingConsentByDefault: true,
    );
    await OnDeviceProcessingStore.resetForTest();
    await OnDeviceProcessingStore.setEnabled(onDeviceOnly);
    return RemoteProcessingConsentStore(AppServices.instance.prefs);
  }

  Future<JournalEntry> saveProvisionalEntry({String id = 'entry-provisional'}) async {
    final audio = await _usableAudioFile();
    final entry = JournalEntry(
      id: id,
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
    return entry;
  }

  ProvisionalTranscriptReconciler reconcilerFor(
    RemoteProcessingConsentStore consentStore,
  ) {
    return ProvisionalTranscriptReconciler(
      captureRepository: appProviderContainer.read(captureRepositoryProvider),
      attest: AppServices.instance.attest,
      journalStore: AppServices.instance.journalStore,
      consentStore: consentStore,
    );
  }

  test('revoked transcription consent blocks provisional reconcile retries',
      () async {
    final api = _ReconcileSpyApi();
    final consentStore = await initBoundary(api: api, onDeviceOnly: false);
    final gate = RemoteProcessingConsentGate(consentStore);

    // With the veto off and consent on record the retry is genuinely available,
    // so the refusal below can only come from the withdrawal.
    expect(
      await gate.isPurposePermittedNow(
        RemoteProcessingPurpose.remoteTranscription,
      ),
      isTrue,
      reason: 'precondition: the retry is permitted before consent is revoked',
    );

    final entry = await saveProvisionalEntry();
    await consentStore.withdraw();

    expect(
      await gate.isPurposePermittedNow(
        RemoteProcessingPurpose.remoteTranscription,
      ),
      isFalse,
    );
    expect(await reconcilerFor(consentStore).reconcileEntry(entry), isFalse);
    expect(api.postTranscribeCallCount, 0);
  });

  test('control: the same retry does upload while consent stands', () async {
    // The positive control the case above needs. One variable differs — no
    // withdrawal — so a zero count here would mean the assertion above is
    // measuring a broken fixture rather than the consent boundary.
    final api = _ReconcileSpyApi();
    final consentStore = await initBoundary(api: api, onDeviceOnly: false);
    final entry = await saveProvisionalEntry(id: 'entry-provisional-control');

    expect(await reconcilerFor(consentStore).reconcileEntry(entry), isTrue);
    expect(api.postTranscribeCallCount, 1);
  });
}
