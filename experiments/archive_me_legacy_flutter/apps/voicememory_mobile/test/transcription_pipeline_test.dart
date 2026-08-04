import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/api/api_exceptions.dart';
import 'package:voicememory_mobile/features/timeline/timeline_entry_display.dart';
import 'package:voicememory_mobile/features/voice_capture/transcription/transcription_service.dart';
import 'package:voicememory_mobile/features/voice_capture/transcription/on_device_transcription_engine.dart';
import 'package:voicememory_mobile/features/voice_capture/transcription/transcription_connectivity.dart';
import 'package:voicememory_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:voicememory_mobile/features/voice_capture/voice_capture_post_save.dart';
import 'package:voicememory_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/security/api_usage_guard.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';
import 'package:voicememory_mobile/services/privacy/audio_vault_service.dart';

const _spokenTranscript = 'I felt pressure before saying yes again today.';

class _TranscriptionPipelineFakeApi extends VoiceCaptureApiClient {
  _TranscriptionPipelineFakeApi({
    this.transcript = _spokenTranscript,
    this.transcribeError,
    this.analyzeError,
  }) : super(ApiTransport(baseUrl: 'http://test.invalid'));

  final String transcript;
  final Object? transcribeError;
  final Object? analyzeError;

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
  }) async {
    final error = transcribeError;
    if (error != null) throw error;
    return transcript;
  }

  @override
  Future<Reflection> postAnalyze({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorEvidence = const [],
    String? idempotencyKey,
    String? entryId,
  }) async {
    final error = analyzeError;
    if (error != null) throw error;
    return Reflection(
      mood: 'neutral',
      emotionalIntensity: 1,
      recurringThemes: const [],
      exactLanguagePattern: '',
      concreteObservation: transcript,
      repeatedSignal: '',
    );
  }
}

class _FakeOnDeviceTranscriptionEngine implements OnDeviceTranscriptionEngine {
  _FakeOnDeviceTranscriptionEngine({this.error}) : transcript = null;

  final String? transcript;
  final Object? error;
  int transcribeCalls = 0;

  @override
  Future<bool> isReady() async => true;

  @override
  Future<void> prepare() async {}

  @override
  Future<String> transcribe(File audioFile) async {
    transcribeCalls += 1;
    if (error != null) throw error!;
    return transcript ?? _spokenTranscript;
  }
}

Future<File> _usableAudioFile() async {
  final dir = Directory.systemTemp.createTempSync('vm_transcription_');
  return File('${dir.path}/voice.m4a')
    ..writeAsBytesSync(List.filled(VoiceCaptureQuality.minAudioBytes, 1));
}

Future<void> _initPipeline(
  _TranscriptionPipelineFakeApi api, {
  OnDeviceTranscriptionEngine? onDeviceTranscription,
  TranscriptionConnectivity transcriptionConnectivity =
      const FixedTranscriptionConnectivity(true),
}) async {
  final dir = Directory.systemTemp.createTempSync('vm_transcription_journal_');
  await AppServices.resetForTest(
    journalPath: '${dir.path}/journal.json',
    voiceCaptureApi: api,
    onDeviceTranscription: onDeviceTranscription,
    transcriptionConnectivity: transcriptionConnectivity,
  );
  AppServices.instance.tokenCache.setToken(
    'test-capture-token',
    expiresInSeconds: 3600,
  );
}

JournalEntry _degradedVoiceEntry({required String audioPath}) => JournalEntry(
  id: 'v1',
  createdAt: DateTime(2026, 6, 12),
  transcript:
      '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected',
  durationSeconds: 20,
  localAudioPath: audioPath,
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

void main() {
  setUp(() {
    ApiUsageGuard.resetForTest();
  });

  group('TranscriptionService', () {
    test('active mode routes online to server and offline to local', () {
      expect(TranscriptionService.localIosSpeechRecognitionImplemented, isTrue);
      expect(TranscriptionService.activeMode(), TranscriptionMode.server);
      expect(
        TranscriptionService.activeMode(isOnline: false),
        TranscriptionMode.local,
      );
    });

    test('failureReason maps ApiException to readable reason', () {
      expect(
        TranscriptionService.failureReason(
          ApiException('Not found', statusCode: 404, code: 'not_found'),
        ),
        'not_found:Not found',
      );
    });
  });

  group('voice transcription pipeline', () {
    test(
      'offline local transcription saves standard processable text',
      () async {
        final local = _FakeOnDeviceTranscriptionEngine();
        await _initPipeline(
          _TranscriptionPipelineFakeApi(
            analyzeError: const SocketException('offline'),
          ),
          onDeviceTranscription: local,
          transcriptionConnectivity: const FixedTranscriptionConnectivity(
            false,
          ),
        );
        final audio = await _usableAudioFile();

        final result = await AppServices.instance.pipeline.run(
          audioFile: audio,
          durationSeconds: 20,
        );

        expect(local.transcribeCalls, 1);
        expect(result.entry.transcript, _spokenTranscript);
        expect(result.entry.transcript, isNot(startsWith('[draft]')));
        expect(VoiceCaptureQuality.hasUsableSpokenText(result.entry), isTrue);
        expect(
          VoiceCapturePostSave.showViewPatternsPrimary(result.entry),
          isTrue,
        );
      },
    );

    test(
      'offline local failure is the only path that keeps draft state',
      () async {
        final local = _FakeOnDeviceTranscriptionEngine(
          error: StateError('local model unavailable'),
        );
        await _initPipeline(
          _TranscriptionPipelineFakeApi(),
          onDeviceTranscription: local,
          transcriptionConnectivity: const FixedTranscriptionConnectivity(
            false,
          ),
        );
        final audio = await _usableAudioFile();

        final result = await AppServices.instance.pipeline.run(
          audioFile: audio,
          durationSeconds: 20,
        );

        expect(local.transcribeCalls, 1);
        expect(result.entry.transcript, startsWith('[draft]'));
        expect(
          VoiceCaptureQuality.isDegradedVoiceCapture(result.entry),
          isTrue,
        );
      },
    );

    test(
      'cloud transcription failure immediately falls back on-device',
      () async {
        final local = _FakeOnDeviceTranscriptionEngine();
        await _initPipeline(
          _TranscriptionPipelineFakeApi(
            transcribeError: ApiException('Unavailable', statusCode: 503),
          ),
          onDeviceTranscription: local,
        );
        final audio = await _usableAudioFile();

        final result = await AppServices.instance.pipeline.run(
          audioFile: audio,
          durationSeconds: 20,
        );

        expect(local.transcribeCalls, 1);
        expect(result.entry.transcript, _spokenTranscript);
        expect(result.entry.transcript, isNot(startsWith('[draft]')));
      },
    );

    test(
      'recording saved with transcript when transcription succeeds',
      () async {
        await _initPipeline(_TranscriptionPipelineFakeApi());
        final audio = await _usableAudioFile();

        final result = await AppServices.instance.pipeline.run(
          audioFile: audio,
          durationSeconds: 20,
        );

        expect(result.syncSucceeded, isTrue);
        expect(result.entry.transcript, _spokenTranscript);
        expect(
          VoiceCaptureQuality.isDegradedVoiceCapture(result.entry),
          isFalse,
        );
        expect(
          VoiceCapturePostSave.showTypedFallbackPrimary(result.entry),
          isFalse,
        );
        expect(VoiceCaptureQuality.hasUsableSpokenText(result.entry), isTrue);
      },
    );

    test(
      'recording saved with manual fallback when transcription fails',
      () async {
        await _initPipeline(
          _TranscriptionPipelineFakeApi(
            transcribeError: ApiException(
              'Service unavailable',
              statusCode: 503,
            ),
          ),
        );
        final audio = await _usableAudioFile();

        final result = await AppServices.instance.pipeline.run(
          audioFile: audio,
          durationSeconds: 20,
        );

        expect(result.syncSucceeded, isFalse);
        expect(result.entry.localAudioPath, isNull);
        expect(
          result.entry.localAudioVaultRef,
          startsWith(AudioVaultService.referencePrefix),
        );
        expect(audio.existsSync(), isFalse);
        expect(
          VoiceCaptureQuality.isDegradedVoiceCapture(result.entry),
          isTrue,
        );
        expect(
          VoiceCapturePostSave.showTypedFallbackPrimary(result.entry),
          isTrue,
        );
      },
    );

    test('manual transcript save persists and clears degraded state', () async {
      await _initPipeline(_TranscriptionPipelineFakeApi());
      final audio = await _usableAudioFile();
      final degraded = _degradedVoiceEntry(audioPath: audio.path);
      await AppServices.instance.journalStore.save(degraded);

      final result = await AppServices.instance.pipeline
          .attachTypedTextToVoiceEntry(
            entry: degraded,
            transcript: 'I said yes when I had no capacity left.',
          );

      expect(result.attachedTypedTextToVoiceEntry, isTrue);
      expect(result.entry.localAudioPath, audio.path);
      expect(
        result.entry.transcript,
        'I said yes when I had no capacity left.',
      );
      expect(VoiceCaptureQuality.isDegradedVoiceCapture(result.entry), isFalse);
      expect(
        resolveEntryDisplayText(result.entry).text,
        'I said yes when I had no capacity left.',
      );

      final stored = await AppServices.instance.journalStore.getById('v1');
      expect(stored?.transcript, 'I said yes when I had no capacity left.');
    });

    test('transcription failure retains audio only in the vault', () async {
      await _initPipeline(
        _TranscriptionPipelineFakeApi(
          transcribeError: const SocketException('Connection refused'),
        ),
      );
      final audio = await _usableAudioFile();
      final originalBytes = audio.readAsBytesSync();

      final result = await AppServices.instance.pipeline.run(
        audioFile: audio,
        durationSeconds: 20,
      );

      expect(result.entry.localAudioPath, isNull);
      expect(
        result.entry.localAudioVaultRef,
        startsWith(AudioVaultService.referencePrefix),
      );
      expect(audio.existsSync(), isFalse);
      expect(
        await AppServices.instance.journalAudioVault.readPlaintextBytes(
          result.entry.localAudioVaultRef!,
        ),
        originalBytes,
      );
    });

    test(
      'transcription success with analysis failure saves transcript and success state',
      () async {
        await _initPipeline(
          _TranscriptionPipelineFakeApi(
            analyzeError: ApiException(
              'Voice processing is temporarily unavailable.',
              statusCode: 503,
              code: 'ANALYZE_UNAVAILABLE',
            ),
          ),
        );
        final audio = await _usableAudioFile();

        final result = await AppServices.instance.pipeline.run(
          audioFile: audio,
          durationSeconds: 20,
        );

        expect(result.syncSucceeded, isFalse);
        expect(result.analysisSucceeded, isFalse);
        expect(result.entry.transcript, _spokenTranscript);
        expect(
          VoiceCaptureQuality.isDegradedVoiceCapture(result.entry),
          isFalse,
        );
        expect(
          VoiceCapturePostSave.showTypedFallbackPrimary(result.entry),
          isFalse,
        );
        expect(
          VoiceCapturePostSave.showViewPatternsPrimary(result.entry),
          isTrue,
        );
        expect(result.syncNote, VoiceCaptureCopy.analysisUnavailableNote);
        expect(
          VoiceCaptureQuality.displayTextSource(result.entry),
          EntryDisplayTextSource.transcript,
        );
      },
    );

    test(
      'analysis failure does not use transcription failed logging path',
      () async {
        await _initPipeline(
          _TranscriptionPipelineFakeApi(
            analyzeError: ApiException(
              'Voice processing is temporarily unavailable.',
              statusCode: 503,
              code: 'ANALYZE_UNAVAILABLE',
            ),
          ),
        );
        final audio = await _usableAudioFile();

        final result = await AppServices.instance.pipeline.run(
          audioFile: audio,
          durationSeconds: 20,
        );

        expect(result.entry.transcript, _spokenTranscript);
        expect(VoiceCaptureQuality.hasUsableSpokenText(result.entry), isTrue);
      },
    );

    test(
      'low-quality transcript preserves audio and routes to typed fallback',
      () async {
        await _initPipeline(_TranscriptionPipelineFakeApi(transcript: '...'));
        final audio = await _usableAudioFile();

        final result = await AppServices.instance.pipeline.run(
          audioFile: audio,
          durationSeconds: 20,
        );

        expect(result.syncSucceeded, isFalse);
        expect(result.lowQualityTranscript, isTrue);
        expect(result.entry.localAudioPath, isNull);
        expect(
          result.entry.localAudioVaultRef,
          startsWith(AudioVaultService.referencePrefix),
        );
        expect(audio.existsSync(), isFalse);
        expect(
          VoiceCaptureQuality.isDegradedVoiceCapture(result.entry),
          isTrue,
        );
        expect(
          VoiceCapturePostSave.showTypedFallbackPrimary(result.entry),
          isTrue,
        );
        expect(result.syncNote, VoiceCaptureCopy.lowQualityTranscriptIssue);
        expect(VoiceCaptureQuality.hasUsableSpokenText(result.entry), isFalse);
      },
    );

    test('valid short sentence transcript is accepted', () async {
      const spoken = 'I felt pressure today';
      await _initPipeline(_TranscriptionPipelineFakeApi(transcript: spoken));
      final audio = await _usableAudioFile();

      final result = await AppServices.instance.pipeline.run(
        audioFile: audio,
        durationSeconds: 20,
      );

      expect(result.syncSucceeded, isTrue);
      expect(result.lowQualityTranscript, isFalse);
      expect(result.entry.transcript, spoken);
      expect(VoiceCaptureQuality.hasUsableSpokenText(result.entry), isTrue);
      expect(
        VoiceCapturePostSave.showTypedFallbackPrimary(result.entry),
        isFalse,
      );
    });

    test(
      'api guard skip keeps vaulted audio and degraded fallback state',
      () async {
        ApiUsageGuard.resetForTest(
          replacement: ApiUsageGuard(maxAttemptsPerScope: 1),
        );
        await _initPipeline(
          _TranscriptionPipelineFakeApi(
            transcribeError: ApiException(
              'Service unavailable',
              statusCode: 503,
            ),
          ),
        );
        final audio = await _usableAudioFile();

        await AppServices.instance.pipeline.run(
          audioFile: audio,
          durationSeconds: 20,
        );
        final retryAudio = await _usableAudioFile();

        final blocked = await AppServices.instance.pipeline.run(
          audioFile: retryAudio,
          durationSeconds: 20,
        );

        expect(blocked.syncSucceeded, isFalse);
        expect(blocked.entry.localAudioPath, isNull);
        expect(
          blocked.entry.localAudioVaultRef,
          startsWith(AudioVaultService.referencePrefix),
        );
        expect(
          VoiceCaptureQuality.isDegradedVoiceCapture(blocked.entry),
          isTrue,
        );
        expect(
          VoiceCapturePostSave.showTypedFallbackPrimary(blocked.entry),
          isTrue,
        );
      },
    );
  });
}
