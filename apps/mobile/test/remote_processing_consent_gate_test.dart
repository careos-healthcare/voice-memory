import 'dart:io';

import 'package:archiveme_mobile/core/di/network_providers.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/capture_api_client.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/offline_vault_manifest.dart';
import 'package:archiveme_mobile/features/privacy/on_device_processing_store.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:archiveme_mobile/models/attest_result.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/security/api_usage_guard.dart';
import 'package:archiveme_mobile/security/remote_processing_consent_gate.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Proves the live capture-time consent boundary: decline or revocation
/// blocks remote transcription and reflection before any HTTP call is made.
///
/// Two conditions must both hold for anything to leave the device, and
/// [_initPipeline] makes each one explicit at every call site rather than
/// letting either be inherited:
///
///  * remote-processing consent for the specific purpose, which
///    `AppServices.resetForTest` pre-grants unless asked not to; and
///  * the "Never send to server" veto, which the harness never touches at all.
///    `OnDeviceProcessingStore` is a static resolving from the *host* platform,
///    and `defaultEnabledFor` is true for everything except Android — so under
///    `flutter test` the veto is silently ON. A case that leaves it alone
///    measures the veto and learns nothing about consent, which is how a
///    "declined consent sends nothing" assertion can be green while never
///    having been in the state it names.
const _spokenTranscript = 'I felt pressure before saying yes again today.';

/// Fails from inside the intercepted call rather than counting afterwards, so
/// an escaped request names the method that leaked instead of surfacing as a
/// number compared at the end of a test that may never have got that far.
class _ConsentGateFakeApi implements CaptureApiClient {
  _ConsentGateFakeApi({this.onAnalyzeCalled});

  /// Set true only by cases that intend a request to reach the wire.
  bool allowCalls = false;

  int postTranscribeCallCount = 0;
  int postAnalyzeRawCallCount = 0;
  int postCaptureAttestCallCount = 0;

  final Future<void> Function()? onAnalyzeCalled;

  void _trip(String method) {
    if (!allowCalls) fail('remote call escaped the consent gate: $method');
  }

  @override
  Future<ApiResult<AttestResult>> postCaptureAttest(
    String deviceId, {
    NetworkCancelToken? cancelToken,
  }) async {
    _trip('postCaptureAttest');
    postCaptureAttestCallCount += 1;
    return ApiSuccess(
      AttestResult.capture(token: 'test-token', expiresInSeconds: 3600),
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
    postTranscribeCallCount += 1;
    return const ApiSuccess(_spokenTranscript);
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
    postAnalyzeRawCallCount += 1;
    await onAnalyzeCalled?.call();
    return ApiSuccess(
      RawModelResponse(
        payload: {
          'reflection': {
            'mood': 'neutral',
            'emotionalIntensity': 1,
            'recurringThemes': <String>[],
            'exactLanguagePattern': transcript,
            'concreteObservation': transcript,
            'repeatedSignal': '',
          },
        },
        receivedAt: DateTime.utc(2026, 8, 5),
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
  final dir = Directory.systemTemp.createTempSync('vm_consent_gate_');
  return File('${dir.path}/voice.m4a')
    ..writeAsBytesSync(List.filled(VoiceCaptureQuality.minAudioBytes, 1));
}

/// Brings up the pipeline with both gate conditions stated outright.
///
/// [onDeviceOnly] is required rather than defaulted: the whole failure this
/// file guards against is a case that forgot the veto exists.
Future<_ConsentGateFakeApi> _initPipeline({
  required bool grantConsentByDefault,
  required bool onDeviceOnly,
  Future<void> Function()? onAnalyzeCalled,
}) async {
  final api = _ConsentGateFakeApi(onAnalyzeCalled: onAnalyzeCalled);
  final dir = Directory.systemTemp.createTempSync('vm_consent_gate_journal_');
  await AppServices.resetForTest(
    journalPath: '${dir.path}/journal.json',
    networkOverrides: [captureApiClientProvider.overrideWithValue(api)],
    grantRemoteProcessingConsentByDefault: grantConsentByDefault,
  );
  await OnDeviceProcessingStore.resetForTest();
  await OnDeviceProcessingStore.setEnabled(onDeviceOnly);
  AppServices.instance.tokenCache.setToken(
    'test-capture-token',
    expiresInSeconds: 3600,
  );
  return api;
}

RemoteProcessingConsentGate get _gate =>
    RemoteProcessingConsentGate(RemoteProcessingConsentStore(
      AppServices.instance.prefs,
    ));

/// Asserts what the gate answers before the pipeline runs.
///
/// Every "nothing was sent" case below pairs with one of these, so a green run
/// records which of the two conditions was actually under test instead of
/// leaving it to the reader to infer.
Future<void> _expectPermitted({
  required bool transcription,
  required bool reflection,
}) async {
  final gate = _gate;
  expect(
    await gate.isPurposePermittedNow(
      RemoteProcessingPurpose.remoteTranscription,
    ),
    transcription,
    reason: 'precondition: remote transcription permitted == $transcription',
  );
  expect(
    await gate.isPurposePermittedNow(RemoteProcessingPurpose.remoteReflection),
    reflection,
    reason: 'precondition: remote reflection permitted == $reflection',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // `resetForTest` starts ConnectivityAwareNetworkSource, which throws
    // MissingPluginException without this. That exception lands in setUp, so
    // without the stub every case here dies before reaching an assertion.
    const connectivity = MethodChannel(
      'dev.fluttercommunity.plus/connectivity',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivity, (call) async {
      if (call.method == 'check') return ['wifi'];
      return null;
    });

    // Saving an entry schedules an automated-graph flush that reads secure
    // storage on a later turn of the event loop. Whether it lands inside the
    // test or after it depends on machine load, so stubbing this is what keeps
    // the suite from failing only when the box is busy.
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

  group('both gates open', () {
    test('consent granted: transcription and analysis proceed normally',
        () async {
      final api = await _initPipeline(
        grantConsentByDefault: true,
        onDeviceOnly: false,
      );
      await _expectPermitted(transcription: true, reflection: true);
      api.allowCalls = true;
      final audio = await _usableAudioFile();

      final result = (await AppServices.instance.pipeline.run(
        audioFile: audio,
        durationSeconds: 20,
      )).getOrThrow();

      expect(result.analysisSucceeded, isTrue);
      expect(api.postTranscribeCallCount, 1);
      expect(api.postAnalyzeRawCallCount, 1);
    });

    test('stamp-at-creation-time: a withdrawal that lands during the network '
        'round trip is reflected in what gets stamped, not the stale answer '
        'the earlier pre-call gate saw', () async {
      late RemoteProcessingConsentStore consentStore;
      final api = await _initPipeline(
        grantConsentByDefault: true,
        onDeviceOnly: false,
        onAnalyzeCalled: () async {
          await consentStore.withdraw();
        },
      );
      consentStore = RemoteProcessingConsentStore(AppServices.instance.prefs);
      await _expectPermitted(transcription: true, reflection: true);
      api.allowCalls = true;
      final audio = await _usableAudioFile();

      final result = (await AppServices.instance.pipeline.run(
        audioFile: audio,
        durationSeconds: 20,
      )).getOrThrow();

      expect(api.postAnalyzeRawCallCount, 1);
      expect(result.analysisSucceeded, isFalse);
      expect(result.entry.transcript, _spokenTranscript);
    });
  });

  group('consent closed, veto open', () {
    // The veto is deliberately off in this group. That isolates consent as the
    // only thing that can refuse, which is the claim these cases are named for.

    test('transcription consent is checked before postTranscribe (decline '
        'blocks network)', () async {
      final api = await _initPipeline(
        grantConsentByDefault: false,
        onDeviceOnly: false,
      );
      await _expectPermitted(transcription: false, reflection: false);
      final audio = await _usableAudioFile();

      final result = (await AppServices.instance.pipeline.run(
        audioFile: audio,
        durationSeconds: 20,
      )).getOrThrow();

      expect(api.postCaptureAttestCallCount, 0);
      expect(api.postTranscribeCallCount, 0);
      expect(api.postAnalyzeRawCallCount, 0);
      expect(result.analysisSucceeded, isFalse);
      expect(result.syncSucceeded, isFalse);
      expect(result.localSaved, isTrue);
      expect(result.entry.localAudioPath, isNotNull);
      expect(
        result.entry.transcript,
        contains('Recording saved locally'),
        reason: 'local-only voice receipt uses draft placeholder, not remote STT',
      );
      expect(result.entry.syncStatus, SyncStatus.pendingUpload);
    });

    test(
      'transcription-only grant: audio is transcribed but reflection is not '
      'called',
      () async {
        final api = await _initPipeline(
          grantConsentByDefault: false,
          onDeviceOnly: false,
        );
        await RemoteProcessingConsentStore(AppServices.instance.prefs).grant(
          purposes: {RemoteProcessingPurpose.remoteTranscription},
        );
        AppServices.instance.tokenCache.setToken(
          'test-capture-token',
          expiresInSeconds: 3600,
        );
        await _expectPermitted(transcription: true, reflection: false);
        api.allowCalls = true;
        final audio = await _usableAudioFile();

        final result = (await AppServices.instance.pipeline.run(
          audioFile: audio,
          durationSeconds: 20,
        )).getOrThrow();

        expect(api.postTranscribeCallCount, 1);
        expect(
          api.postAnalyzeRawCallCount,
          0,
          reason: 'the granted purpose is transcription, and only that one',
        );
        expect(result.analysisSucceeded, isFalse);
        expect(result.localSaved, isTrue);
        expect(result.entry.transcript, _spokenTranscript);
      },
    );

    test(
      'granted, then withdrawn: the next save makes zero network calls',
      () async {
        final api = await _initPipeline(
          grantConsentByDefault: true,
          onDeviceOnly: false,
        );
        await _expectPermitted(transcription: true, reflection: true);
        api.allowCalls = true;
        final firstAudio = await _usableAudioFile();

        final first = (await AppServices.instance.pipeline.run(
          audioFile: firstAudio,
          durationSeconds: 20,
        )).getOrThrow();
        expect(first.analysisSucceeded, isTrue);
        expect(api.postTranscribeCallCount, 1);
        expect(api.postAnalyzeRawCallCount, 1);

        // The first leg above is the positive control for the second: same
        // pipeline, same audio shape, one variable changed.
        await RemoteProcessingConsentStore(AppServices.instance.prefs)
            .withdraw();
        await _expectPermitted(transcription: false, reflection: false);
        api.allowCalls = false;

        AppServices.instance.tokenCache.setToken(
          'test-capture-token-2',
          expiresInSeconds: 3600,
        );

        final secondAudio = await _usableAudioFile();
        final second = (await AppServices.instance.pipeline.run(
          audioFile: secondAudio,
          durationSeconds: 20,
        )).getOrThrow();

        expect(api.postTranscribeCallCount, 1);
        expect(api.postAnalyzeRawCallCount, 1);
        expect(second.analysisSucceeded, isFalse);
        expect(second.localSaved, isTrue);
        expect(second.entry.localAudioPath, isNotNull);
        expect(second.entry.transcript, contains('Recording saved locally'));
      },
    );

    test('saveTextThought is gated: declined consent saves locally with zero '
        'network calls', () async {
      final api = await _initPipeline(
        grantConsentByDefault: false,
        onDeviceOnly: false,
      );
      await _expectPermitted(transcription: false, reflection: false);

      final result = (await AppServices.instance.pipeline.saveTextThought(
        transcript: 'I keep saying yes when I have no capacity left.',
      )).getOrThrow();

      expect(api.postCaptureAttestCallCount, 0);
      expect(api.postAnalyzeRawCallCount, 0);
      expect(result.analysisSucceeded, isFalse);
      expect(result.syncSucceeded, isFalse);
      expect(result.localSaved, isTrue);
      expect(
        result.entry.transcript,
        'I keep saying yes when I have no capacity left.',
      );
    });

    test('control: saveTextThought does reach analyze once consent is given',
        () async {
      // Same call, same transcript, consent the only difference. Without this
      // the case above would also pass if `saveTextThought` had simply stopped
      // calling the network for an unrelated reason.
      final api = await _initPipeline(
        grantConsentByDefault: true,
        onDeviceOnly: false,
      );
      await _expectPermitted(transcription: true, reflection: true);
      api.allowCalls = true;

      final result = (await AppServices.instance.pipeline.saveTextThought(
        transcript: 'I keep saying yes when I have no capacity left.',
      )).getOrThrow();

      expect(api.postAnalyzeRawCallCount, 1);
      expect(result.localSaved, isTrue);
    });
  });

  group('consent open, veto closed', () {
    test('the on-device-only veto alone blocks a fully consented capture',
        () async {
      // The mirror of the group above: consent is granted, so anything refused
      // here is refused by the local switch and nothing else.
      final api = await _initPipeline(
        grantConsentByDefault: true,
        onDeviceOnly: true,
      );
      final store = RemoteProcessingConsentStore(AppServices.instance.prefs);
      for (final purpose in RemoteProcessingPurpose.values) {
        expect(
          await store.isPurposeGrantedNow(purpose),
          isTrue,
          reason: 'precondition: consent itself is on record for $purpose',
        );
      }
      await _expectPermitted(transcription: false, reflection: false);
      final audio = await _usableAudioFile();

      final result = (await AppServices.instance.pipeline.run(
        audioFile: audio,
        durationSeconds: 20,
      )).getOrThrow();

      expect(api.postTranscribeCallCount, 0);
      expect(api.postAnalyzeRawCallCount, 0);
      expect(result.localSaved, isTrue);
    });
  });

  test('remote failure after consent does not erase a locally saved entry',
      () async {
    final dir = Directory.systemTemp.createTempSync('vm_consent_fail_journal_');
    final api = _ConsentGateFakeApi()..allowCalls = true;
    await AppServices.resetForTest(
      journalPath: '${dir.path}/journal.json',
      networkOverrides: [
        captureApiClientProvider.overrideWith(
          (ref) => _AnalyzeFailingApi(api),
        ),
      ],
      grantRemoteProcessingConsentByDefault: true,
    );
    await OnDeviceProcessingStore.resetForTest();
    await OnDeviceProcessingStore.setEnabled(false);
    AppServices.instance.tokenCache.setToken(
      'test-capture-token',
      expiresInSeconds: 3600,
    );
    await _expectPermitted(transcription: true, reflection: true);
    final audio = await _usableAudioFile();

    final result = (await AppServices.instance.pipeline.run(
      audioFile: audio,
      durationSeconds: 20,
    )).getOrThrow();

    expect(result.localSaved, isTrue);
    expect(result.entry.transcript, _spokenTranscript);
    final reloaded = await AppServices.instance.journalStore.loadAll();
    expect(reloaded, isNotEmpty);
    expect(reloaded.first.transcript, _spokenTranscript);
  });
}

class _AnalyzeFailingApi implements CaptureApiClient {
  _AnalyzeFailingApi(this._inner);

  final _ConsentGateFakeApi _inner;

  @override
  Future<ApiResult<AttestResult>> postCaptureAttest(
    String deviceId, {
    NetworkCancelToken? cancelToken,
  }) =>
      _inner.postCaptureAttest(deviceId, cancelToken: cancelToken);

  @override
  Future<ApiResult<String>> postTranscribe({
    required File audioFile,
    required int durationSeconds,
    required String captureToken,
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  }) =>
      _inner.postTranscribe(
        audioFile: audioFile,
        durationSeconds: durationSeconds,
        captureToken: captureToken,
        idempotencyKey: idempotencyKey,
        cancelToken: cancelToken,
      );

  @override
  Future<ApiResult<RawModelResponse>> postAnalyzeRaw({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorEvidence = const [],
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  }) async {
    _inner.postAnalyzeRawCallCount += 1;
    return const ApiFailureResult(
      ApiFailureServer(message: 'analyze_failed', statusCode: 500),
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
  }) {
    throw UnimplementedError('postVaultRecovery');
  }
}
