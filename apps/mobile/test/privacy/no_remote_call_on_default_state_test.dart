import 'dart:io';

import 'package:archiveme_mobile/core/di/app_provider_container.dart';
import 'package:archiveme_mobile/core/di/network_providers.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/capture_api_client.dart';
import 'package:archiveme_mobile/features/capture_flow/adapters/pipeline_capture_adapters.dart';
import 'package:archiveme_mobile/features/capture_flow/ui/local_transcription_unavailable_card.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/offline_vault_manifest.dart';
import 'package:archiveme_mobile/features/onboarding/ui/remote_processing_consent_step.dart';
import 'package:archiveme_mobile/features/privacy/on_device_processing_store.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/local_transcription_availability.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/local_transcription_choice_store.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale_store.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/native_speech_transcription.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/provisional_transcript_reconciler.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcription_capability_policy.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:archiveme_mobile/models/attest_result.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/models/transcript_status.dart';
import 'package:archiveme_mobile/security/api_usage_guard.dart';
import 'package:archiveme_mobile/security/remote_processing_consent_gate.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fails the test from inside the call rather than reporting a count later.
///
/// Prior work here produced assertions that passed because an unrelated channel
/// threw before execution ever reached the upload. A spy that calls [fail] names
/// the leaking method at the moment it happens, and the positive controls at the
/// bottom flip one variable each so a green run cannot be vacuous.
class _NetworkTripwireApi implements CaptureApiClient {
  bool allowCalls = false;
  int transcribeCalls = 0;

  void _trip(String method) {
    if (!allowCalls) fail('remote call escaped: $method');
  }

  @override
  Future<ApiResult<AttestResult>> postCaptureAttest(
    String deviceId, {
    NetworkCancelToken? cancelToken,
  }) async {
    _trip('postCaptureAttest');
    return ApiSuccess(
      AttestResult.capture(token: 'tripwire-token', expiresInSeconds: 3600),
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
    _trip('postTranscribe');
    transcribeCalls += 1;
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
    _trip('postAnalyzeRaw');
    return ApiSuccess(
      RawModelResponse(
        payload: const {
          'reflection': {
            'mood': 'neutral',
            'emotionalIntensity': 1,
            'recurringThemes': <String>[],
            'exactLanguagePattern': '',
            'concreteObservation': '',
            'repeatedSignal': '',
          },
        },
        receivedAt: DateTime.utc(2026, 8, 22),
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
    _trip('postVaultRecovery');
    throw UnimplementedError('postVaultRecovery');
  }
}

JournalEntry _provisionalEntry(String audioPath) => JournalEntry(
  id: 'tripwire-entry',
  createdAt: DateTime.utc(2026, 8, 22),
  transcript: 'something I would not say in a room',
  durationSeconds: 9,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _NetworkTripwireApi api;
  late Directory dir;
  late RemoteProcessingConsentStore consentStore;
  late LocalTranscriptionChoiceStore choiceStore;
  late SpeechLocaleStore speechLocaleStore;

  setUpAll(() {
    // AppServices.resetForTest starts ConnectivityAwareNetworkSource, which
    // throws MissingPluginException without this stub — and that exception is
    // exactly what made earlier "no remote call" assertions vacuous.
    const connectivity = MethodChannel(
      'dev.fluttercommunity.plus/connectivity',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivity, (call) async {
      if (call.method == 'check') return ['wifi'];
      return null;
    });

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
    api = _NetworkTripwireApi();
    dir = Directory.systemTemp.createTempSync('vm_tripwire_');
    await AppServices.resetForTest(
      journalPath: '${dir.path}/journal.json',
      prefsPath: '${dir.path}/prefs.json',
      networkOverrides: [captureApiClientProvider.overrideWithValue(api)],
      // The default is `true`, which pre-grants both remote purposes for the
      // convenience of tests that exercise remote analysis. A fresh install has
      // consented to nothing, and the first three cases below were reporting
      // "proceed" purely because of this flag — the same shape of false green
      // this file exists to rule out.
      grantRemoteProcessingConsentByDefault: false,
    );
    consentStore = RemoteProcessingConsentStore(AppServices.instance.prefs);
    choiceStore = LocalTranscriptionChoiceStore(AppServices.instance.prefs);
    speechLocaleStore = SpeechLocaleStore(AppServices.instance.prefs);
    // A fresh install has confirmed no language, so the iOS availability check
    // below would report `speechLanguageUnconfirmed` and change what these
    // cases are measuring. They are about the network, not the prompt, so the
    // language is confirmed up front and the language gap has its own tests.
    await speechLocaleStore.confirm(ConfirmedSpeechLocale.confirmed('en-GB')!);
    await OnDeviceProcessingStore.resetForTest();
  });

  tearDown(() async {
    await OnDeviceProcessingStore.resetForTest();
    OnDeviceProcessingStore.debugPlatformOverride = null;
    NativeSpeechTranscription.debugPlatformOverride = null;
  });

  StoreTranscriptionCapabilityPolicy policyFor(
    LocalTranscriptionAvailability availability,
  ) {
    return StoreTranscriptionCapabilityPolicy(
      consentStore: consentStore,
      choiceStore: choiceStore,
      speechLocaleStore: speechLocaleStore,
      availability: availability,
    );
  }

  group('rendering the new surfaces sends nothing', () {
    testWidgets('the onboarding consent step makes no remote call',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RemoteProcessingConsentStep(onDecision: (_) {})),
        ),
      );
      await tester.pumpAndSettle();
      expect(api.transcribeCalls, 0);
    });

    testWidgets('the unavailability card sends nothing, including on decline',
        (tester) async {
      var declined = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocalTranscriptionUnavailableCard(
              onChoice: (allow) => declined = !allow,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('local_transcription_choose_none')),
      );
      await tester.pumpAndSettle();

      expect(declined, isTrue);
      expect(api.transcribeCalls, 0);
    });
  });

  group('the default state sends nothing', () {
    test('iOS default: on-device-only on, capability check stays local',
        () async {
      OnDeviceProcessingStore.debugPlatformOverride = 'ios';
      NativeSpeechTranscription.debugPlatformOverride = 'ios';
      expect(OnDeviceProcessingStore.enabled, isTrue);

      final outcome = await policyFor(
        PlatformLocalTranscriptionAvailability(
          confirmedLocale: speechLocaleStore.read,
        ),
      ).evaluate();

      expect(outcome, TranscriptionCapabilityOutcome.proceed);
      expect(api.transcribeCalls, 0);
    });

    test('Android default: on-device-only off but nothing consented yet',
        () async {
      OnDeviceProcessingStore.debugPlatformOverride = 'android';
      NativeSpeechTranscription.debugPlatformOverride = 'android';
      expect(OnDeviceProcessingStore.enabled, isFalse);

      final outcome = await policyFor(
        PlatformLocalTranscriptionAvailability(
          confirmedLocale: speechLocaleStore.read,
        ),
      ).evaluate();

      // The Android default clears the veto, and clearing the veto alone
      // permits nothing: with no consent on record this is the ask, not an
      // upload.
      expect(outcome, TranscriptionCapabilityOutcome.askOnce);
      expect(api.transcribeCalls, 0);
    });

    test('a stored "no transcription" answer still sends nothing', () async {
      OnDeviceProcessingStore.debugPlatformOverride = 'android';
      NativeSpeechTranscription.debugPlatformOverride = 'android';
      await choiceStore.record(LocalTranscriptionChoice.noTranscription);

      final outcome = await policyFor(
        PlatformLocalTranscriptionAvailability(
          confirmedLocale: speechLocaleStore.read,
        ),
      ).evaluate();

      expect(outcome, TranscriptionCapabilityOutcome.respectNoTranscription);
      expect(api.transcribeCalls, 0);
    });
  });

  group('positive controls', () {
    test('control: accepting the prompt grants transcription and clears veto',
        () async {
      OnDeviceProcessingStore.debugPlatformOverride = 'ios';
      NativeSpeechTranscription.debugPlatformOverride = 'android';
      final gate = RemoteProcessingConsentGate(consentStore);

      expect(
        await gate.isPurposePermittedNow(
          RemoteProcessingPurpose.remoteTranscription,
        ),
        isFalse,
        reason: 'precondition: nothing is permitted before the answer',
      );

      await policyFor(
        StaticLocalTranscriptionAvailability.unavailable(
          LocalTranscriptionUnavailableReason.platformUnsupported,
        ),
      ).recordChoice(allowRemote: true);

      expect(OnDeviceProcessingStore.enabled, isFalse);
      expect(
        await gate.isPurposePermittedNow(
          RemoteProcessingPurpose.remoteTranscription,
        ),
        isTrue,
      );
      expect(
        await gate.isPurposePermittedNow(
          RemoteProcessingPurpose.remoteReflection,
        ),
        isFalse,
        reason: 'the prompt asks about transcription, so it grants that alone',
      );
      expect(
        await choiceStore.read(),
        LocalTranscriptionChoice.remoteTranscription,
      );
      expect(api.transcribeCalls, 0, reason: 'answering is not uploading');
    });

    test('control: with the answer recorded, an upload does happen', () async {
      // Flips exactly one variable against the "sends nothing" cases above: the
      // customer has now answered. If the tripwire were mis-wired, this would
      // report zero calls and the group above would prove nothing.
      OnDeviceProcessingStore.debugPlatformOverride = 'ios';
      await policyFor(
        StaticLocalTranscriptionAvailability.unavailable(
          LocalTranscriptionUnavailableReason.platformUnsupported,
        ),
      ).recordChoice(allowRemote: true);

      final audio = File('${dir.path}/voice.m4a')
        ..writeAsBytesSync(List.filled(VoiceCaptureQuality.minAudioBytes, 1));
      final entry = _provisionalEntry(audio.path);
      await AppServices.instance.journalStore.save(entry, first25Source: 'test');

      api.allowCalls = true;
      final reconciler = ProvisionalTranscriptReconciler(
        captureRepository: appProviderContainer.read(captureRepositoryProvider),
        attest: AppServices.instance.attest,
        journalStore: AppServices.instance.journalStore,
        consentStore: consentStore,
      );

      expect(await reconciler.reconcileEntry(entry), isTrue);
      expect(api.transcribeCalls, 1);
    });

    test('control: re-enabling the toggle vetoes that same upload', () async {
      OnDeviceProcessingStore.debugPlatformOverride = 'ios';
      await policyFor(
        StaticLocalTranscriptionAvailability.unavailable(
          LocalTranscriptionUnavailableReason.platformUnsupported,
        ),
      ).recordChoice(allowRemote: true);
      await OnDeviceProcessingStore.setEnabled(true);

      final audio = File('${dir.path}/voice.m4a')
        ..writeAsBytesSync(List.filled(VoiceCaptureQuality.minAudioBytes, 1));
      final entry = _provisionalEntry(audio.path);
      await AppServices.instance.journalStore.save(entry, first25Source: 'test');

      final reconciler = ProvisionalTranscriptReconciler(
        captureRepository: appProviderContainer.read(captureRepositoryProvider),
        attest: AppServices.instance.attest,
        journalStore: AppServices.instance.journalStore,
        consentStore: consentStore,
      );

      // Same setup as the control above minus the toggle. The tripwire fails
      // the test from inside the call if anything reaches the network.
      expect(await reconciler.reconcileEntry(entry), isFalse);
      expect(api.transcribeCalls, 0);
    });
  });
}
