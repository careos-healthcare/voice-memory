import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/api/api_exceptions.dart';
import 'package:voicememory_mobile/features/timeline/timeline_entry_display.dart';
import 'package:voicememory_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:voicememory_mobile/features/voice_capture/transcription/transcript_quality.dart';
import 'package:voicememory_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:voicememory_mobile/features/voice_capture/voice_capture_post_save.dart';
import 'package:voicememory_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/security/api_usage_guard.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/capture_save_messages.dart';

const _spokenTranscript = 'I felt pressure before saying yes again today.';

class _VoicePipelineFakeApi extends ApiClient {
  _VoicePipelineFakeApi({
    this.transcript = _spokenTranscript,
    this.analyzeError,
  }) : super(baseUrl: 'http://test.invalid');

  final String transcript;
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
  }) async => transcript;

  @override
  Future<RawModelResponse> postAnalyzeRaw({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorEvidence = const [],
    String? idempotencyKey,
  }) async {
    final error = analyzeError;
    if (error != null) throw error;
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
      receivedAt: DateTime.utc(2026, 8, 4),
    );
  }
}

JournalEntry _voiceEntry({
  String transcript = '',
  String observation = '',
  String? localAudioPath = '/tmp/audio.m4a',
}) => JournalEntry(
  id: 'v1',
  createdAt: DateTime(2026, 6, 12, 12),
  transcript: transcript,
  durationSeconds: 20,
  localAudioPath: localAudioPath,
  reflection: Reflection(
    mood: 'neutral',
    emotionalIntensity: 0,
    recurringThemes: const [],
    exactLanguagePattern: '',
    concreteObservation: observation,
    repeatedSignal: '',
  ),
  syncStatus: SyncStatus.pendingUpload,
);

void main() {
  late Directory tempDir;

  Future<void> initPipelineTest(_VoicePipelineFakeApi api) async {
    await AppServices.resetForTest(
      journalPath:
          '${tempDir.path}/journal_${DateTime.now().microsecondsSinceEpoch}.json',
      api: api,
    );
    AppServices.instance.tokenCache.setToken(
      'test-capture-token',
      expiresInSeconds: 3600,
    );
  }

  setUp(() async {
    ApiUsageGuard.resetForTest();
    tempDir = Directory.systemTemp.createTempSync('vm_voice_quality_');
    await AppServices.resetForTest(journalPath: '${tempDir.path}/journal.json');
  });

  group('VoiceCaptureQuality', () {
    test('rejects tiny audio files', () {
      final dir = Directory.systemTemp.createTempSync('vm_audio_');
      final tiny = File('${dir.path}/tiny.m4a')
        ..writeAsBytesSync(List.filled(10, 0));

      expect(VoiceCaptureQuality.audioFileUsable(tiny), isFalse);
    });

    test('accepts audio files above minimum size', () {
      final dir = Directory.systemTemp.createTempSync('vm_audio_');
      final file = File('${dir.path}/ok.m4a')
        ..writeAsBytesSync(List.filled(VoiceCaptureQuality.minAudioBytes, 1));

      expect(VoiceCaptureQuality.audioFileUsable(file), isTrue);
    });

    test('detects degraded voice capture without usable text', () {
      final entry = _voiceEntry(
        transcript:
            '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected',
      );

      expect(VoiceCaptureQuality.isDegradedVoiceCapture(entry), isTrue);
      expect(VoiceCaptureQuality.hasUsableSpokenText(entry), isFalse);
      expect(VoiceCaptureQuality.displayTextLength(entry), 0);
    });

    test('detects usable spoken text from transcript', () {
      final entry = _voiceEntry(
        transcript: 'I felt pressure before saying yes again.',
      );

      expect(VoiceCaptureQuality.hasUsableSpokenText(entry), isTrue);
      expect(VoiceCaptureQuality.isDegradedVoiceCapture(entry), isFalse);
      expect(VoiceCaptureQuality.displayTextLength(entry), greaterThan(0));
      expect(
        VoiceCaptureQuality.displayTextSource(entry),
        EntryDisplayTextSource.transcript,
      );
    });

    test('transcript with saved locally phrase still has display text', () {
      final entry = _voiceEntry(
        transcript: 'I saved locally on my phone when I moved last year.',
      );

      expect(VoiceCaptureQuality.displayTextLength(entry), greaterThan(0));
      expect(VoiceCaptureQuality.isDegradedVoiceCapture(entry), isFalse);
      expect(
        resolveEntryDisplayText(entry).source,
        EntryDisplayTextSource.transcript,
      );
    });

    test('body-only voice entry has display text from body field', () {
      final entry = _voiceEntry(
        transcript:
            '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected',
        observation: 'I felt pressure before saying yes again.',
      );

      expect(VoiceCaptureQuality.displayTextLength(entry), greaterThan(0));
      expect(VoiceCaptureQuality.isDegradedVoiceCapture(entry), isFalse);
      expect(
        resolveEntryDisplayText(entry).source,
        EntryDisplayTextSource.body,
      );
    });

    test(
      'degraded only when transcript and body are both empty placeholders',
      () {
        final entry = _voiceEntry(
          transcript:
              '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected',
        );

        expect(hasPersistedCaptureText(entry), isFalse);
        expect(VoiceCaptureQuality.isDegradedVoiceCapture(entry), isTrue);
        expect(VoiceCaptureQuality.displayTextLength(entry), 0);
      },
    );

    test('typed fallback text makes entry usable', () {
      final degraded = _voiceEntry(
        transcript:
            '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected',
      );
      expect(VoiceCaptureQuality.isDegradedVoiceCapture(degraded), isTrue);

      final enriched = _voiceEntry(
        transcript: 'I said yes when I had no capacity left.',
      );
      expect(VoiceCaptureQuality.hasUsableSpokenText(enriched), isTrue);
      expect(VoiceCaptureQuality.isDegradedVoiceCapture(enriched), isFalse);
    });
  });

  group('TranscriptQuality', () {
    test('rejects junk transcript for evidence display', () {
      expect(TranscriptQuality.isUsableEvidence('...'), isFalse);
      expect(TranscriptQuality.isUsableEvidence('um'), isFalse);
      expect(
        TranscriptQuality.isUsableEvidence('I felt pressure today'),
        isTrue,
      );
    });

    test('degraded voice entry with junk transcript text is not usable', () {
      final entry = _voiceEntry(transcript: '...');
      expect(VoiceCaptureQuality.hasUsableSpokenText(entry), isFalse);
      expect(VoiceCaptureQuality.isDegradedVoiceCapture(entry), isTrue);
    });
  });

  group('VoiceCaptureCopy', () {
    test('includes insufficient audio and fallback strings', () {
      expect(VoiceCaptureCopy.notEnoughAudio, isNotEmpty);
      expect(VoiceCaptureCopy.savedPrivatelySuccess, isNotEmpty);
      expect(VoiceCaptureCopy.transcriptionFailedIssue, isNotEmpty);
      expect(VoiceCaptureCopy.typeWhatYouSaid, isNotEmpty);
    });
  });

  group('VoiceCapturePostSave', () {
    test('degraded voice entry shows typed fallback primary CTA policy', () {
      final degraded = _voiceEntry(
        transcript:
            '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected',
      );
      expect(VoiceCapturePostSave.showTypedFallbackPrimary(degraded), isTrue);
      expect(VoiceCapturePostSave.showViewPatternsPrimary(degraded), isFalse);
    });

    test('usable voice entry keeps View patterns primary policy', () {
      final usable = _voiceEntry(
        transcript: 'I felt pressure before saying yes again.',
      );
      expect(VoiceCapturePostSave.showTypedFallbackPrimary(usable), isFalse);
      expect(VoiceCapturePostSave.showViewPatternsPrimary(usable), isTrue);
    });

    test('typed fallback updates display text length', () {
      final enriched = _voiceEntry(
        transcript: 'I said yes when I had no capacity left.',
      );
      expect(VoiceCaptureQuality.displayTextLength(enriched), greaterThan(0));
      expect(
        VoiceCaptureQuality.displayTextLength(enriched),
        isNot(ConsumerUiCopy.savedPrivatelyOnDevice.length),
      );
    });
  });

  group('attachTypedTextToVoiceEntry', () {
    test('saves typed transcript locally when backend is unavailable', () async {
      final degraded = _voiceEntry(
        transcript:
            '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected',
      );
      await AppServices.instance.journalStore.save(degraded);

      final result = await AppServices.instance.pipeline
          .attachTypedTextToVoiceEntry(
            entry: degraded,
            transcript: 'I said yes when I had no capacity left.',
          );

      expect(result.attachedTypedTextToVoiceEntry, isTrue);
      expect(
        result.entry.transcript,
        'I said yes when I had no capacity left.',
      );
      expect(result.entry.localAudioPath, '/tmp/audio.m4a');
      expect(VoiceCaptureQuality.isDegradedVoiceCapture(result.entry), isFalse);

      final stored = await AppServices.instance.journalStore.getById('v1');
      expect(stored?.transcript, 'I said yes when I had no capacity left.');
    });
  });

  group('resolveFinalCaptureTranscript', () {
    test('skips draft placeholder and returns spoken text', () {
      final draft =
          '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected';
      expect(
        resolveFinalCaptureTranscript(
          transcript: draft,
          body: _spokenTranscript,
        ),
        _spokenTranscript,
      );
    });

    test('never allows draft to overwrite real transcript on apply', () {
      final draft =
          '[draft] ${CaptureSaveMessages.recordingSavedLocally} — transcribe when connected';
      final entry = _voiceEntry(transcript: _spokenTranscript);
      final applied = applyFinalTranscriptToVoiceEntry(
        entry,
        finalTranscript: null,
        draftPlaceholder: draft,
      );
      expect(applied.transcript, _spokenTranscript);
      expect(applied.reflection.concreteObservation, _spokenTranscript);
    });
  });

  group('voice capture pipeline', () {
    Future<File> _usableAudioFile() async {
      final dir = Directory.systemTemp.createTempSync('vm_audio_pipeline_');
      return File('${dir.path}/voice.m4a')
        ..writeAsBytesSync(List.filled(VoiceCaptureQuality.minAudioBytes, 1));
    }

    test(
      'transcribe ok + analyze FormatException saves spoken display text',
      () async {
        await initPipelineTest(
          _VoicePipelineFakeApi(
            analyzeError: FormatException('Unexpected HTML'),
          ),
        );
        final audio = await _usableAudioFile();

        final result = await AppServices.instance.pipeline.run(
          audioFile: audio,
          durationSeconds: 20,
        );

        expect(result.syncSucceeded, isFalse);
        expect(
          VoiceCaptureQuality.displayTextLength(result.entry),
          greaterThan(0),
        );
        expect(
          VoiceCaptureQuality.isDegradedVoiceCapture(result.entry),
          isFalse,
        );
        expect(
          VoiceCapturePostSave.showViewPatternsPrimary(result.entry),
          isTrue,
        );
        expect(
          VoiceCapturePostSave.showTypedFallbackPrimary(result.entry),
          isFalse,
        );
        expect(result.entry.transcript, _spokenTranscript);
        expect(result.entry.reflection.concreteObservation, _spokenTranscript);

        final reloaded = await AppServices.instance.journalStore.getById(
          result.entry.id,
        );
        expect(reloaded, isNotNull);
        expect(
          VoiceCaptureQuality.displayTextLength(reloaded!),
          greaterThan(0),
        );
        expect(hasPersistedCaptureText(reloaded), isTrue);
      },
    );

    test('transcribe ok + analyze 404 saves spoken display text', () async {
      await initPipelineTest(
        _VoicePipelineFakeApi(
          analyzeError: ApiException('Not found', statusCode: 404),
        ),
      );
      final audio = await _usableAudioFile();

      final result = await AppServices.instance.pipeline.run(
        audioFile: audio,
        durationSeconds: 20,
      );

      expect(result.syncSucceeded, isFalse);
      expect(
        VoiceCaptureQuality.displayTextLength(result.entry),
        greaterThan(0),
      );
      expect(VoiceCaptureQuality.isDegradedVoiceCapture(result.entry), isFalse);
      expect(
        VoiceCapturePostSave.showViewPatternsPrimary(result.entry),
        isTrue,
      );
    });
  });

  group('offline voice transcript persistence', () {
    test(
      'partial transcript persists display text and avoids degraded flag',
      () async {
        final dir = Directory.systemTemp.createTempSync('vm_audio_persist_');
        final audio = File('${dir.path}/voice.m4a')
          ..writeAsBytesSync(List.filled(VoiceCaptureQuality.minAudioBytes, 1));
        const spoken = 'I felt pressure before saying yes again today.';

        final entry = JournalEntry(
          id: 'offline-voice',
          createdAt: DateTime(2026, 6, 12, 12),
          transcript: spoken,
          durationSeconds: 20,
          localAudioPath: audio.path,
          reflection: Reflection(
            mood: 'neutral',
            emotionalIntensity: 0,
            recurringThemes: const [],
            exactLanguagePattern: '',
            concreteObservation: spoken,
            repeatedSignal: '',
          ),
          syncStatus: SyncStatus.pendingUpload,
        );
        await AppServices.instance.journalStore.save(entry);

        expect(entrySanitizedTranscript(entry).length, greaterThan(0));
        expect(entrySanitizedBody(entry).length, greaterThan(0));
        expect(VoiceCaptureQuality.displayTextLength(entry), greaterThan(0));
        expect(VoiceCaptureQuality.isDegradedVoiceCapture(entry), isFalse);
        expect(hasPersistedCaptureText(entry), isTrue);
        expect(
          resolveEntryDisplayText(entry).source,
          EntryDisplayTextSource.transcript,
        );
        expect(VoiceCapturePostSave.showViewPatternsPrimary(entry), isTrue);
      },
    );
  });
}
