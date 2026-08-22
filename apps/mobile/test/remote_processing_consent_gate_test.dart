import 'dart:io';

import 'package:archiveme_mobile/core/di/network_providers.dart';
import 'package:archiveme_mobile/core/network/api_failure.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/capture_api_client.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/offline_vault_manifest.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:archiveme_mobile/models/attest_result.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/security/api_usage_guard.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Proves the live capture-time consent boundary: decline or revocation
/// blocks remote transcription and reflection before any HTTP call is made.
const _spokenTranscript = 'I felt pressure before saying yes again today.';

class _ConsentGateFakeApi implements CaptureApiClient {
  _ConsentGateFakeApi({this.onAnalyzeCalled});

  int postTranscribeCallCount = 0;
  int postAnalyzeRawCallCount = 0;
  int postCaptureAttestCallCount = 0;

  final Future<void> Function()? onAnalyzeCalled;

  @override
  Future<ApiResult<AttestResult>> postCaptureAttest(
    String deviceId, {
    NetworkCancelToken? cancelToken,
  }) async {
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

Future<_ConsentGateFakeApi> _initPipeline({
  required bool grantConsentByDefault,
  Future<void> Function()? onAnalyzeCalled,
}) async {
  final api = _ConsentGateFakeApi(onAnalyzeCalled: onAnalyzeCalled);
  final dir = Directory.systemTemp.createTempSync('vm_consent_gate_journal_');
  await AppServices.resetForTest(
    journalPath: '${dir.path}/journal.json',
    networkOverrides: [captureApiClientProvider.overrideWithValue(api)],
    grantRemoteProcessingConsentByDefault: grantConsentByDefault,
  );
  AppServices.instance.tokenCache.setToken(
    'test-capture-token',
    expiresInSeconds: 3600,
  );
  return api;
}

void main() {
  setUp(ApiUsageGuard.resetForTest);

  test('consent granted: transcription and analysis proceed normally', () async {
    final api = await _initPipeline(grantConsentByDefault: true);
    final audio = await _usableAudioFile();

    final result = await AppServices.instance.pipeline.run(
      audioFile: audio,
      durationSeconds: 20,
    );

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
      onAnalyzeCalled: () async {
        await consentStore.withdraw();
      },
    );
    consentStore = RemoteProcessingConsentStore(AppServices.instance.prefs);
    final audio = await _usableAudioFile();

    final result = await AppServices.instance.pipeline.run(
      audioFile: audio,
      durationSeconds: 20,
    );

    expect(api.postAnalyzeRawCallCount, 1);
    expect(result.analysisSucceeded, isFalse);
    expect(result.entry.transcript, _spokenTranscript);
  });

  test('transcription consent is checked before postTranscribe (decline blocks '
      'network)', () async {
    final api = await _initPipeline(grantConsentByDefault: false);
    final audio = await _usableAudioFile();

    final result = await AppServices.instance.pipeline.run(
      audioFile: audio,
      durationSeconds: 20,
    );

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
      final api = await _initPipeline(grantConsentByDefault: false);
      await RemoteProcessingConsentStore(AppServices.instance.prefs).grant(
        purposes: {RemoteProcessingPurpose.remoteTranscription},
      );
      AppServices.instance.tokenCache.setToken(
        'test-capture-token',
        expiresInSeconds: 3600,
      );
      final audio = await _usableAudioFile();

      final result = await AppServices.instance.pipeline.run(
        audioFile: audio,
        durationSeconds: 20,
      );

      expect(api.postTranscribeCallCount, 1);
      expect(api.postAnalyzeRawCallCount, 0);
      expect(result.analysisSucceeded, isFalse);
      expect(result.localSaved, isTrue);
      expect(result.entry.transcript, _spokenTranscript);
    },
  );

  test(
    'granted, then withdrawn: the next save makes zero network calls',
    () async {
      final api = await _initPipeline(grantConsentByDefault: true);
      final firstAudio = await _usableAudioFile();

      final first = await AppServices.instance.pipeline.run(
        audioFile: firstAudio,
        durationSeconds: 20,
      );
      expect(first.analysisSucceeded, isTrue);
      expect(api.postTranscribeCallCount, 1);
      expect(api.postAnalyzeRawCallCount, 1);

      await RemoteProcessingConsentStore(AppServices.instance.prefs).withdraw();

      AppServices.instance.tokenCache.setToken(
        'test-capture-token-2',
        expiresInSeconds: 3600,
      );

      final secondAudio = await _usableAudioFile();
      final second = await AppServices.instance.pipeline.run(
        audioFile: secondAudio,
        durationSeconds: 20,
      );

      expect(api.postTranscribeCallCount, 1);
      expect(api.postAnalyzeRawCallCount, 1);
      expect(second.analysisSucceeded, isFalse);
      expect(second.localSaved, isTrue);
      expect(second.entry.localAudioPath, isNotNull);
      expect(
        second.entry.transcript,
        contains('Recording saved locally'),
      );
    },
  );

  test('saveTextThought is gated: declined consent saves locally with zero '
      'network calls', () async {
    final api = await _initPipeline(grantConsentByDefault: false);

    final result = await AppServices.instance.pipeline.saveTextThought(
      transcript: 'I keep saying yes when I have no capacity left.',
    );

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

  test('remote failure after consent does not erase a locally saved entry',
      () async {
    final dir = Directory.systemTemp.createTempSync('vm_consent_fail_journal_');
    final api = _ConsentGateFakeApi();
    await AppServices.resetForTest(
      journalPath: '${dir.path}/journal.json',
      networkOverrides: [
        captureApiClientProvider.overrideWith(
          (ref) => _AnalyzeFailingApi(api),
        ),
      ],
      grantRemoteProcessingConsentByDefault: true,
    );
    AppServices.instance.tokenCache.setToken(
      'test-capture-token',
      expiresInSeconds: 3600,
    );
    final audio = await _usableAudioFile();

    final result = await AppServices.instance.pipeline.run(
      audioFile: audio,
      durationSeconds: 20,
    );

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
