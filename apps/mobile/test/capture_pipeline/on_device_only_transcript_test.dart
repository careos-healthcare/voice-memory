import 'dart:io';

import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/features/privacy/on_device_processing_store.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/native_speech_transcription.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/speech_locale_store.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:archiveme_mobile/models/transcript_provenance.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/swift_native_speech_double.dart';
import 'capture_pipeline_test_support.dart';

const _spoken = 'I said yes again when I meant to say I was tired.';

/// Every remote call is a failure of the test, not a result to assert on.
class _TripwireApi extends AnalyzeCaptureApi {
  var transcribeCalls = 0;
  var analyzeCalls = 0;

  @override
  Future<ApiResult<String>> postTranscribe({
    required File audioFile,
    required int durationSeconds,
    required String captureToken,
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  }) async {
    transcribeCalls += 1;
    throw StateError('on-device-only mode posted audio for transcription');
  }

  @override
  Future<ApiResult<RawModelResponse>> postAnalyzeRaw({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorEvidence = const [],
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  }) async {
    analyzeCalls += 1;
    throw StateError('on-device-only mode posted a transcript for analysis');
  }
}

void main() {
  group('a default iOS install produces a transcript', () {
    late Directory tempDir;
    late JournalStore journal;
    late MobilePrefsStore prefs;
    late RemoteProcessingConsentStore consentStore;
    late SpeechLocaleStore localeStore;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('vm_on_device_only_');
      journal = JournalStore(file: File('${tempDir.path}/journal.json'));
      prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      consentStore = RemoteProcessingConsentStore(prefs);
      localeStore = SpeechLocaleStore(prefs);

      // The shipped default: nothing consented, on-device-only on, and no
      // bundled Whisper ONNX asset for the local-AI step to load.
      await consentStore.withdraw();
      await OnDeviceProcessingStore.resetForTest();
      OnDeviceProcessingStore.debugPlatformOverride = 'ios';
      NativeSpeechTranscription.debugPlatformOverride = 'ios';
    });

    tearDown(() async {
      NativeSpeechTranscription.testPlatform = null;
      NativeSpeechTranscription.debugPlatformOverride = null;
      OnDeviceProcessingStore.debugPlatformOverride = null;
      await OnDeviceProcessingStore.resetForTest();
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    Future<({JournalStore journal, _TripwireApi api})> run() async {
      final api = _TripwireApi();
      final built = await buildCapturePipelineFacade(
        prefs: prefs,
        journal: journal,
        consentStore: consentStore,
        api: api,
        speechLocale: localeStore.read,
      );
      final audio = File('${tempDir.path}/voice.m4a')
        ..writeAsBytesSync(List.filled(VoiceCaptureQuality.minAudioBytes, 9));
      await built.facade.run(audioFile: audio, durationSeconds: 11);
      return (journal: journal, api: api);
    }

    test('the entry is saved with the words that were said', () async {
      expect(OnDeviceProcessingStore.enabled, isTrue);
      NativeSpeechTranscription.testPlatform =
          SwiftContractNativeSpeechPlatform(transcript: _spoken);
      await localeStore.confirm(ConfirmedSpeechLocale.confirmed('en-GB')!);

      final result = await run();
      final saved = await result.journal.loadAll();

      expect(saved, hasLength(1));
      expect(saved.single.transcript, contains('said yes again'));
      expect(result.api.transcribeCalls, 0);
      expect(result.api.analyzeCalls, 0);
    });

    test('the transcript is stamped speech-to-text', () async {
      NativeSpeechTranscription.testPlatform =
          SwiftContractNativeSpeechPlatform(transcript: _spoken);
      await localeStore.confirm(ConfirmedSpeechLocale.confirmed('en-GB')!);

      final saved = (await run()).journal;
      final entry = (await saved.loadAll()).single;

      expect(entry.transcriptProvenance, TranscriptProvenance.speechToText);
    });

    test('no entry claims it was sent away for processing', () async {
      // `EntryProcessingTrustChip` reads `processingUsedOnnx` as the
      // on-device/cloud switch. `false` there would render "Sent securely for
      // higher-accuracy processing" over a recording that never left.
      NativeSpeechTranscription.testPlatform =
          SwiftContractNativeSpeechPlatform(transcript: _spoken);
      await localeStore.confirm(ConfirmedSpeechLocale.confirmed('en-GB')!);

      final entry = (await (await run()).journal.loadAll()).single;

      expect(entry.processingUsedOnnx, isNot(false));
    });

    test('an unconfirmed language saves the audio and no invented text',
        () async {
      final platform = SwiftContractNativeSpeechPlatform(transcript: _spoken);
      NativeSpeechTranscription.testPlatform = platform;

      final result = await run();
      final entry = (await result.journal.loadAll()).single;

      expect(
        platform.callCount,
        0,
        reason: 'nothing may pick a language on the customer’s behalf',
      );
      expect(entry.transcript, isNot(contains('said yes again')));
      expect(entry.localAudioPath, isNotNull);
      expect(result.api.transcribeCalls, 0);
    });

    test('a truncated recognition saves the audio and no partial text',
        () async {
      NativeSpeechTranscription.testPlatform =
          SwiftContractNativeSpeechPlatform(
        transcript: _spoken,
        coverage: NativeSpeechCoverageVerdict.truncated,
      );
      await localeStore.confirm(ConfirmedSpeechLocale.confirmed('en-GB')!);

      final result = await run();
      final entry = (await result.journal.loadAll()).single;

      expect(entry.transcript, isNot(contains('said yes again')));
      expect(entry.localAudioPath, isNotNull);
      expect(result.api.transcribeCalls, 0);
    });
  });
}
