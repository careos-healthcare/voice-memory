import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:voicememory_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:voicememory_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/security/api_usage_guard.dart';
import 'package:voicememory_mobile/services/app_services.dart';

/// Proves B3's live capture-time gate: a withdrawal blocks the *next* remote
/// analysis attempt before `postAnalyzeRaw` is ever called, core
/// audio-to-text transcription still runs, and a journal entry can still be
/// saved locally throughout.
const _spokenTranscript = 'I felt pressure before saying yes again today.';

class _ConsentGateFakeApi extends ApiClient {
  _ConsentGateFakeApi({this.onAnalyzeCalled})
    : super(baseUrl: 'http://test.invalid');

  int postAnalyzeRawCallCount = 0;

  /// Awaited from inside `postAnalyzeRaw`, before it returns — lets a test
  /// simulate consent being withdrawn (and that withdrawal fully persisted)
  /// *during* the network round trip, to exercise the live re-check in
  /// `CapturePipelineService._postAndAdmit` rather than only the earlier
  /// pre-call gate.
  final Future<void> Function()? onAnalyzeCalled;

  @override
  Future<AttestResult> postCaptureAttest(String deviceId) async {
    return AttestResult.capture(token: 'test-token', expiresInSeconds: 3600);
  }

  @override
  Future<String> postTranscribe({
    required File audioFile,
    required int durationSeconds,
    required String captureToken,
    String? idempotencyKey,
  }) async => _spokenTranscript;

  @override
  Future<RawModelResponse> postAnalyzeRaw({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorEvidence = const [],
    String? idempotencyKey,
  }) async {
    postAnalyzeRawCallCount += 1;
    await onAnalyzeCalled?.call();
    return RawModelResponse(
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
    );
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
    api: api,
    grantRemoteProcessingConsentByDefault: grantConsentByDefault,
  );
  AppServices.instance.tokenCache.setToken(
    'test-capture-token',
    expiresInSeconds: 3600,
  );
  return api;
}

void main() {
  setUp(() {
    ApiUsageGuard.resetForTest();
  });

  test('consent granted: analysis proceeds normally', () async {
    final api = await _initPipeline(grantConsentByDefault: true);
    final audio = await _usableAudioFile();

    final result = await AppServices.instance.pipeline.run(
      audioFile: audio,
      durationSeconds: 20,
    );

    expect(result.analysisSucceeded, isTrue);
    expect(api.postAnalyzeRawCallCount, 1);
  });

  test('stamp-at-creation-time: a withdrawal that lands during the network '
      'round trip is reflected in what gets stamped, not the stale answer '
      'the earlier pre-call gate saw', () async {
    late RemoteProcessingConsentStore consentStore;
    final api = await _initPipeline(
      grantConsentByDefault: true,
      onAnalyzeCalled: () async {
        // Withdraws consent, fully persisted, before the network call
        // returns and before `_postAndAdmit` re-reads consent to stamp
        // the resulting source.
        await consentStore.withdraw();
      },
    );
    consentStore = RemoteProcessingConsentStore(AppServices.instance.prefs);
    final audio = await _usableAudioFile();

    final result = await AppServices.instance.pipeline.run(
      audioFile: audio,
      durationSeconds: 20,
    );

    expect(
      api.postAnalyzeRawCallCount,
      1,
      reason: 'the pre-call gate saw consent=true, so the call was made',
    );
    expect(
      result.analysisSucceeded,
      isFalse,
      reason:
          'the source was stamped consented=false at the moment it was '
          'actually created, so evidence_verifier rejects the admission '
          'rather than quietly admitting a proof built from an '
          'unconsented source',
    );
    expect(
      result.entry.transcript,
      _spokenTranscript,
      reason: 'the transcript itself is still saved locally either way',
    );
  });

  test('consent withdrawn before the first save: analysis is never attempted, '
      'and the entry saves locally with a real transcript', () async {
    final api = await _initPipeline(grantConsentByDefault: false);
    final audio = await _usableAudioFile();

    final result = await AppServices.instance.pipeline.run(
      audioFile: audio,
      durationSeconds: 20,
    );

    expect(
      api.postAnalyzeRawCallCount,
      0,
      reason: 'the gate must block the call before it is ever made',
    );
    expect(result.analysisSucceeded, isFalse);
    expect(result.syncSucceeded, isFalse);
    expect(
      result.entry.transcript,
      _spokenTranscript,
      reason:
          'core audio-to-text transcription must not be gated by '
          'remote-processing consent — only the analysis call is',
    );
    expect(result.entry.syncStatus, SyncStatus.pendingUpload);
  });

  test(
    'granted, then withdrawn: the next save is blocked from analysis even '
    'though an earlier save under the same pipeline instance succeeded',
    () async {
      final api = await _initPipeline(grantConsentByDefault: true);
      final firstAudio = await _usableAudioFile();

      final first = await AppServices.instance.pipeline.run(
        audioFile: firstAudio,
        durationSeconds: 20,
      );
      expect(first.analysisSucceeded, isTrue);
      expect(api.postAnalyzeRawCallCount, 1);

      await RemoteProcessingConsentStore(AppServices.instance.prefs).withdraw();

      // A successful save clears the capture token, so the next run() would
      // otherwise re-attest via `DeviceIdStore` (secure storage), which is
      // not mocked in this test environment. Re-seeding it keeps this test
      // focused on the consent gate rather than attestation plumbing.
      AppServices.instance.tokenCache.setToken(
        'test-capture-token-2',
        expiresInSeconds: 3600,
      );

      final secondAudio = await _usableAudioFile();
      final second = await AppServices.instance.pipeline.run(
        audioFile: secondAudio,
        durationSeconds: 20,
      );

      expect(
        api.postAnalyzeRawCallCount,
        1,
        reason:
            'withdrawal must block the very next attempt, not just a '
            'future one',
      );
      expect(second.analysisSucceeded, isFalse);
      expect(second.entry.transcript, _spokenTranscript);
    },
  );

  test('saveTextThought is also gated: withdrawn consent saves the typed '
      'thought locally without ever calling analysis', () async {
    final api = await _initPipeline(grantConsentByDefault: false);

    final result = await AppServices.instance.pipeline.saveTextThought(
      transcript: 'I keep saying yes when I have no capacity left.',
    );

    expect(api.postAnalyzeRawCallCount, 0);
    expect(result.analysisSucceeded, isFalse);
    expect(result.syncSucceeded, isFalse);
    expect(
      result.entry.transcript,
      'I keep saying yes when I have no capacity left.',
    );
  });
}
