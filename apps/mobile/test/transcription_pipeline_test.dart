import 'dart:io';

import 'package:archiveme_mobile/api/api_exceptions.dart';
import 'package:archiveme_mobile/core/di/network_providers.dart';
import 'package:archiveme_mobile/core/network/api_failure_mapper.dart';
import 'package:archiveme_mobile/core/network/api_result.dart';
import 'package:archiveme_mobile/core/network/network_cancel_token.dart';
import 'package:archiveme_mobile/data/network/capture_api_client.dart';
import 'package:archiveme_mobile/features/live_audio/domain/models/offline_vault_manifest.dart';
import 'package:archiveme_mobile/features/privacy/on_device_processing_store.dart';
import 'package:archiveme_mobile/features/proof_admission/proof_admission_models.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/timeline/timeline_entry_display.dart';
import 'package:archiveme_mobile/features/voice_capture/transcription/transcription_service.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_copy.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_post_save.dart';
import 'package:archiveme_mobile/features/voice_capture/voice_capture_quality.dart';
import 'package:archiveme_mobile/models/attest_result.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/sync_status.dart';
import 'package:archiveme_mobile/security/api_usage_guard.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/services/capture_pipeline/capture_pipeline_models.dart';
import 'package:archiveme_mobile/services/capture_save_messages.dart';
import 'package:flutter_test/flutter_test.dart';

const _spokenTranscript = 'I felt pressure before saying yes again today.';

class _TranscriptionPipelineFakeApi implements CaptureApiClient {
  _TranscriptionPipelineFakeApi({
    this.transcript = _spokenTranscript,
    this.transcribeError,
    this.analyzeError,
  });

  final String transcript;
  final Object? transcribeError;
  final Object? analyzeError;

  @override
  Future<ApiResult<AttestResult>> postCaptureAttest(
    String deviceId, {
    NetworkCancelToken? cancelToken,
  }) async {
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
    final error = transcribeError;
    if (error != null) {
      return ApiFailureResult(ApiFailureMapper.fromException(error));
    }
    return ApiSuccess(transcript);
  }

  @override
  Future<ApiResult<RawModelResponse>> postAnalyzeRaw({
    required String transcript,
    required String captureToken,
    List<Map<String, dynamic>> priorEvidence = const [],
    String? idempotencyKey,
    NetworkCancelToken? cancelToken,
  }) async {
    final error = analyzeError;
    if (error != null) {
      return ApiFailureResult(ApiFailureMapper.fromException(error));
    }
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
        receivedAt: DateTime.utc(2026, 8, 4),
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
  final dir = Directory.systemTemp.createTempSync('vm_transcription_');
  return File('${dir.path}/voice.m4a')
    ..writeAsBytesSync(List.filled(VoiceCaptureQuality.minAudioBytes, 1));
}

Future<void> _initPipeline(_TranscriptionPipelineFakeApi api) async {
  final dir = Directory.systemTemp.createTempSync('vm_transcription_journal_');
  await AppServices.resetForTest(
    journalPath: '${dir.path}/journal.json',
    networkOverrides: [captureApiClientProvider.overrideWithValue(api)],
  );
  AppServices.instance.tokenCache.setToken(
    'test-capture-token',
    expiresInSeconds: 3600,
  );
  await RemoteProcessingConsentStore(AppServices.instance.prefs).grant();
  await OnDeviceProcessingStore.clearForGrantedRemoteConsent();
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
  setUp(ApiUsageGuard.resetForTest);

  group('TranscriptionService', () {
    test('active mode is server with native fallback available on mobile', () {
      expect(TranscriptionService.activeMode(), TranscriptionMode.server);
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
      'recording saved with transcript when transcription succeeds',
      () async {
        await _initPipeline(_TranscriptionPipelineFakeApi());
        final audio = await _usableAudioFile();

        final result = (await AppServices.instance.pipeline.run(
          audioFile: audio,
          durationSeconds: 20,
        )).getOrThrow();

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

        final result = (await AppServices.instance.pipeline.run(
          audioFile: audio,
          durationSeconds: 20,
        )).getOrThrow();

        expect(result.syncSucceeded, isFalse);
        expect(result.entry.localAudioPath, audio.path);
        expect(File(result.entry.localAudioPath!).existsSync(), isTrue);
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

      final result = (await AppServices.instance.pipeline
          .attachTypedTextToVoiceEntry(
            entry: degraded,
            transcript: 'I said yes when I had no capacity left.',
          )).getOrThrow();

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

    test('transcription failure never deletes audio', () async {
      await _initPipeline(
        _TranscriptionPipelineFakeApi(
          transcribeError: const SocketException('Connection refused'),
        ),
      );
      final audio = await _usableAudioFile();
      final originalBytes = audio.readAsBytesSync();

      final result = (await AppServices.instance.pipeline.run(
        audioFile: audio,
        durationSeconds: 20,
      )).getOrThrow();

      expect(result.entry.localAudioPath, audio.path);
      expect(audio.existsSync(), isTrue);
      expect(audio.readAsBytesSync(), originalBytes);
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

        final result = (await AppServices.instance.pipeline.run(
          audioFile: audio,
          durationSeconds: 20,
        )).getOrThrow();

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

        final result = (await AppServices.instance.pipeline.run(
          audioFile: audio,
          durationSeconds: 20,
        )).getOrThrow();

        expect(result.entry.transcript, _spokenTranscript);
        expect(VoiceCaptureQuality.hasUsableSpokenText(result.entry), isTrue);
      },
    );

    test(
      'low-quality transcript preserves audio and routes to typed fallback',
      () async {
        await _initPipeline(_TranscriptionPipelineFakeApi(transcript: '...'));
        final audio = await _usableAudioFile();

        final result = (await AppServices.instance.pipeline.run(
          audioFile: audio,
          durationSeconds: 20,
        )).getOrThrow();

        expect(result.syncSucceeded, isFalse);
        expect(result.lowQualityTranscript, isTrue);
        expect(result.entry.localAudioPath, audio.path);
        expect(File(result.entry.localAudioPath!).existsSync(), isTrue);
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

      final result = (await AppServices.instance.pipeline.run(
        audioFile: audio,
        durationSeconds: 20,
      )).getOrThrow();

      expect(result.syncSucceeded, isTrue);
      expect(result.lowQualityTranscript, isFalse);
      expect(result.entry.transcript, spoken);
      expect(VoiceCaptureQuality.hasUsableSpokenText(result.entry), isTrue);
      expect(
        VoiceCapturePostSave.showTypedFallbackPrimary(result.entry),
        isFalse,
      );
    });

    test('api guard skip keeps audio and degraded fallback state', () async {
      ApiUsageGuard.resetForTest(
        replacement: ApiUsageGuard(maxAttemptsPerScope: 1),
      );
      await _initPipeline(
        _TranscriptionPipelineFakeApi(
          transcribeError: ApiException('Service unavailable', statusCode: 503),
        ),
      );
      final audio = await _usableAudioFile();

      await AppServices.instance.pipeline.run(
        audioFile: audio,
        durationSeconds: 20,
      );

      final blocked = (await AppServices.instance.pipeline.run(
        audioFile: audio,
        durationSeconds: 20,
      )).getOrThrow();

      expect(blocked.syncSucceeded, isFalse);
      expect(blocked.entry.localAudioPath, audio.path);
      expect(VoiceCaptureQuality.isDegradedVoiceCapture(blocked.entry), isTrue);
      expect(
        VoiceCapturePostSave.showTypedFallbackPrimary(blocked.entry),
        isTrue,
      );
    });
  });
}