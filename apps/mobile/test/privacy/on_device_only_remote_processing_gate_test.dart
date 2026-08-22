import 'dart:io';

import 'package:archiveme_mobile/core/di/app_provider_container.dart';
import 'package:archiveme_mobile/core/di/network_providers.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/capture_api_client.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/offline_vault_manifest.dart';
import 'package:archiveme_mobile/features/privacy/on_device_processing_store.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_service.dart';
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
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_dependencies.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_middleware.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_proof_analyzer.dart';
import 'package:archiveme_mobile/services/sync/deferred_proof_admission_reconciler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../capture_pipeline/capture_pipeline_test_support.dart';

/// Counts every remote call so a leak shows up as a non-zero count rather than
/// as an assertion about a return value alone.
class _RemoteCallSpyApi implements CaptureApiClient {
  int postTranscribeCallCount = 0;
  int postAnalyzeRawCallCount = 0;

  @override
  Future<ApiResult<AttestResult>> postCaptureAttest(
    String deviceId, {
    NetworkCancelToken? cancelToken,
  }) async {
    return ApiSuccess(
      AttestResult.capture(token: 'gate-token', expiresInSeconds: 3600),
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
    postAnalyzeRawCallCount += 1;
    return ApiSuccess(
      RawModelResponse(
        payload: {
          'reflection': {
            'mood': 'thoughtful',
            'emotionalIntensity': 2,
            'recurringThemes': ['work'],
            'exactLanguagePattern': 'balance',
            'concreteObservation': transcript,
            'repeatedSignal': 'pattern',
          },
        },
        receivedAt: DateTime.utc(2026, 8, 18),
      ),
    );
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
  final dir = Directory.systemTemp.createTempSync('vm_on_device_audio_');
  return File('${dir.path}/voice.m4a')
    ..writeAsBytesSync(List.filled(VoiceCaptureQuality.minAudioBytes, 1));
}

JournalEntry _entry({
  required String id,
  required TranscriptStatus transcriptStatus,
  String? localAudioPath,
}) {
  return JournalEntry(
    id: id,
    createdAt: DateTime.utc(2026, 8, 5),
    transcript: 'something I said out loud that I would not say in a room',
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
    localAudioPath: localAudioPath,
    transcriptStatus: transcriptStatus,
  );
}

CapturePipelineMiddleware _middlewareFor(
  RemoteProcessingConsentStore consentStore,
) {
  final dependencies = CapturePipelineDependencies(
    captureRepository: appProviderContainer.read(captureRepositoryProvider),
    attest: AppServices.instance.attest,
    journalStore: AppServices.instance.journalStore,
    consentStore: consentStore,
    usageGuard: ApiUsageGuard.shared,
    proofAdmission: CanonicalProofAdmissionService(),
    scopeProvider: const FixedScopeProvider(),
  );
  return CapturePipelineMiddleware(
    dependencies,
    CaptureProofAnalyzer(dependencies),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RemoteCallSpyApi api;
  late Directory dir;
  late RemoteProcessingConsentStore consentStore;

  setUpAll(() {
    // AppServices.resetForTest starts ConnectivityAwareNetworkSource, which
    // throws MissingPluginException without this stub.
    const connectivity = MethodChannel(
      'dev.fluttercommunity.plus/connectivity',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivity, (call) async {
      if (call.method == 'check') return ['wifi'];
      return null;
    });

    // Capture attestation reads a device id from secure storage; without this
    // the positive controls below never reach the upload they must prove.
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

  setUp(() async {
    ApiUsageGuard.resetForTest();
    api = _RemoteCallSpyApi();
    dir = Directory.systemTemp.createTempSync('vm_on_device_gate_');
    await AppServices.resetForTest(
      journalPath: '${dir.path}/journal.json',
      prefsPath: '${dir.path}/prefs.json',
      networkOverrides: [captureApiClientProvider.overrideWithValue(api)],
    );
    consentStore = RemoteProcessingConsentStore(AppServices.instance.prefs);
    // Both conditions the toggle copy promises the customer: remote consent is
    // granted, and "never send to server" is still on. Remote must stay shut.
    await consentStore.grant(
      purposes: RemoteProcessingPurposeStorage.onboardingGrant,
    );
    await OnDeviceProcessingStore.resetForTest();
    await OnDeviceProcessingStore.setEnabled(true);
  });

  tearDown(() async {
    await OnDeviceProcessingStore.resetForTest();
  });

  test(
    'on-device-only blocks provisional reconcile even with transcription '
    'consent granted',
    () async {
      final audio = await _usableAudioFile();
      final entry = _entry(
        id: 'entry-provisional',
        transcriptStatus: TranscriptStatus.provisional,
        localAudioPath: audio.path,
      );
      await AppServices.instance.journalStore.save(
        entry,
        first25Source: 'test',
      );

      expect(
        await consentStore.isPurposeGrantedNow(
          RemoteProcessingPurpose.remoteTranscription,
        ),
        isTrue,
        reason: 'precondition: raw consent is granted',
      );
      expect(OnDeviceProcessingStore.enabled, isTrue);

      final reconciler = ProvisionalTranscriptReconciler(
        captureRepository: appProviderContainer.read(captureRepositoryProvider),
        attest: AppServices.instance.attest,
        journalStore: AppServices.instance.journalStore,
        consentStore: consentStore,
      );

      expect(await reconciler.reconcileEntry(entry), isFalse);
      expect(api.postTranscribeCallCount, 0);
    },
  );

  test(
    'on-device-only blocks deferred proof admission even with reflection '
    'consent granted',
    () async {
      final entry = _entry(
        id: 'entry-deferred',
        transcriptStatus: TranscriptStatus.finalTranscript,
      );
      await AppServices.instance.journalStore.save(
        entry,
        first25Source: 'test',
      );

      final reconciler = DeferredProofAdmissionReconciler(
        middleware: _middlewareFor(consentStore),
        journalStore: AppServices.instance.journalStore,
        consentStore: consentStore,
      );

      expect(
        DeferredProofAdmissionReconciler.needsDeferredProofAdmission(entry),
        isTrue,
        reason: 'precondition: this entry is a deferred-admission candidate',
      );

      expect(await reconciler.reconcileEntry(entry), isFalse);
      expect(await reconciler.reconcileAll(), 0);
      expect(api.postAnalyzeRawCallCount, 0);
    },
  );

  // Positive controls. Without these, the two assertions above could pass for
  // an unrelated reason (a mis-wired spy, a usage guard, a missing file) and
  // silently stop proving anything about the on-device-only setting.
  test('control: provisional reconcile does upload once on-device-only is off',
      () async {
    await OnDeviceProcessingStore.setEnabled(false);
    final audio = await _usableAudioFile();
    final entry = _entry(
      id: 'entry-provisional-control',
      transcriptStatus: TranscriptStatus.provisional,
      localAudioPath: audio.path,
    );
    await AppServices.instance.journalStore.save(entry, first25Source: 'test');

    final reconciler = ProvisionalTranscriptReconciler(
      captureRepository: appProviderContainer.read(captureRepositoryProvider),
      attest: AppServices.instance.attest,
      journalStore: AppServices.instance.journalStore,
      consentStore: consentStore,
    );

    expect(await reconciler.reconcileEntry(entry), isTrue);
    expect(api.postTranscribeCallCount, 1);
  });

  test('control: deferred admission does analyze once on-device-only is off',
      () async {
    await OnDeviceProcessingStore.setEnabled(false);
    final entry = _entry(
      id: 'entry-deferred-control',
      transcriptStatus: TranscriptStatus.finalTranscript,
    );
    await AppServices.instance.journalStore.save(entry, first25Source: 'test');

    final reconciler = DeferredProofAdmissionReconciler(
      middleware: _middlewareFor(consentStore),
      journalStore: AppServices.instance.journalStore,
      consentStore: consentStore,
    );

    // Whether the proof is admitted depends on evidence-quality rules that are
    // irrelevant here; what matters is that the transcript reached the server.
    await reconciler.reconcileEntry(entry);
    expect(api.postAnalyzeRawCallCount, 1);
  });

  test('consent gate composes on-device-only with per-purpose consent',
      () async {
    final gate = RemoteProcessingConsentGate(consentStore);

    for (final purpose in RemoteProcessingPurpose.values) {
      final decision = await gate.evaluateFor(purpose);
      expect(decision.permitted, isFalse, reason: '$purpose while on-device');
      expect(decision.currentPermission, isTrue);
      expect(await gate.isPurposePermittedNow(purpose), isFalse);
    }

    await OnDeviceProcessingStore.setEnabled(false);

    for (final purpose in RemoteProcessingPurpose.values) {
      expect(await gate.isPurposePermittedNow(purpose), isTrue);
    }
  });
}
