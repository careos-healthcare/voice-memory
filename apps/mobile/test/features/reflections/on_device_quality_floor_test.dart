import 'dart:io';

import 'package:archiveme_mobile/api/models/capture_dto.dart';
import 'package:archiveme_mobile/api/retrofit/voice_memory_capture_api.dart';
import 'package:archiveme_mobile/features/privacy/on_device_processing_store.dart';
import 'package:archiveme_mobile/features/reflections/data/local_reflection_data_source.dart';
import 'package:archiveme_mobile/features/reflections/data/local_reflection_heuristic_inference.dart';
import 'package:archiveme_mobile/features/reflections/local_ai_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

/// A transcript long enough for local inference and rich enough that the
/// heuristic extractor finds a tension span, an action span and a theme.
const _transcript =
    'Work has been heavy but I keep taking on more. '
    'Tomorrow I will leave on time and rest.';

LocalAiPipeline _pipeline({
  required double sttConfidence,
  VoiceMemoryCaptureApi? remoteApi,
}) {
  return LocalAiPipeline(
    reflectionExtractor: LocalReflectionExtractor(
      logitsSource: LocalReflectionDataSource(
        inference: const LocalReflectionHeuristicInference(),
      ),
    ),
    remoteFallback: remoteApi == null ? null : LocalAiRemoteFallback(remoteApi),
    localSttOverride: (_) async => WhisperTranscriptionResult(
      transcript: _transcript,
      confidence: sttConfidence,
      usedOnnx: true,
    ),
  );
}

Future<LocalAiPipelineResult> _runAudio(
  LocalAiPipeline pipeline, {
  String? captureToken,
}) {
  // `localSttOverride` short-circuits before the file is opened, so this path
  // never needs to exist on disk.
  return pipeline.processAudio(
    audioFile: File('/nonexistent/never-read.wav'),
    durationSeconds: 12,
    entryId: 'entry-quality-floor',
    captureToken: captureToken,
  );
}

void main() {
  setUp(() async {
    // Set the toggle explicitly in every test. `OnDeviceProcessingStore.enabled`
    // otherwise resolves `defaultEnabled`, which is platform-conditional and
    // true on the host VM — an assertion that relied on it would pass without
    // ever exercising the branch it names.
    await OnDeviceProcessingStore.resetForTest();
  });

  tearDown(() async {
    await OnDeviceProcessingStore.resetForTest();
  });

  group('on-device-only quality floor', () {
    test('a below-floor local reflection is reported as unscored, not passed',
        () async {
      await OnDeviceProcessingStore.setEnabled(true);

      final result = await _runAudio(_pipeline(sttConfidence: 0.20));

      expect(
        result.overallConfidence,
        lessThan(LocalAiConfidence.onDeviceOnlyQualityFloor),
        reason: 'fixture must sit below the floor for this test to mean '
            'anything',
      );
      // The point of the change: the reflection is still returned and still
      // kept on-device, but it is no longer indistinguishable from one that
      // cleared a bar.
      expect(result.reflection, isNotNull);
      expect(result.fellBackToRemote, isFalse);
      expect(result.fallbackBlockedReason, 'on_device_processing_only');
    });

    test('an above-floor local reflection still passes unmarked', () async {
      await OnDeviceProcessingStore.setEnabled(true);

      final result = await _runAudio(_pipeline(sttConfidence: 0.90));

      expect(
        result.overallConfidence,
        greaterThanOrEqualTo(LocalAiConfidence.onDeviceOnlyQualityFloor),
      );
      expect(result.succeeded, isTrue);
      expect(result.reflection, isNotNull);
      expect(result.fallbackBlockedReason, isNull);
      expect(result.fellBackToRemote, isFalse);
    });

    test('no request leaves the device in on-device-only mode, at any score',
        () async {
      await OnDeviceProcessingStore.setEnabled(true);

      for (final score in <double>[0.05, 0.20, 0.54, 0.90]) {
        final result = await _runAudio(
          _pipeline(
            sttConfidence: score,
            // Fails from inside the call rather than counting afterwards, so a
            // miscounted or swallowed invocation cannot pass silently.
            remoteApi: _FailingCaptureApi(),
          ),
          captureToken: 'capture-token',
        );
        expect(result.fellBackToRemote, isFalse);
        expect(result.reflection, isNotNull);
      }
    });

    test(
        'positive control: the same wiring does call out when permitted, so the '
        'zero-call assertion above is not vacuous', () async {
      await OnDeviceProcessingStore.setEnabled(false);

      final calls = <String>[];
      final result = await _runAudio(
        _pipeline(
          sttConfidence: 0.20,
          remoteApi: _CountingCaptureApi(calls.add),
        ),
        captureToken: 'capture-token',
      );

      // Same pipeline, same score, same call site — only the toggle differs.
      // These are the exact methods `_FailingCaptureApi` fails from, so the
      // zero-call assertion above is testing a path that does fire.
      expect(
        calls,
        ['transcribe', 'analyze'],
        reason: 'if this is empty the on-device-only assertion proves nothing',
      );
      expect(result.fellBackToRemote, isTrue);
    });
  });

  group('save decision is unchanged', () {
    test('the save gate still reads 0.0 in on-device-only mode', () async {
      await OnDeviceProcessingStore.setEnabled(true);
      expect(await LocalAiConfidence.effectiveRemoteFallbackThreshold(), 0.0);
      expect(
        await LocalAiConfidence.effectiveQualityFloor(),
        LocalAiConfidence.onDeviceOnlyQualityFloor,
      );
    });

    test('a below-floor entry still satisfies the save predicate', () async {
      await OnDeviceProcessingStore.setEnabled(true);

      final result = await _runAudio(_pipeline(sttConfidence: 0.20));

      // Mirrors voice_capture_handler.dart `_attemptLocalAiPipeline`, which is
      // the gate that decides whether the entry is written at all.
      final saveThreshold =
          await LocalAiConfidence.effectiveRemoteFallbackThreshold();
      final wouldSave = result.succeeded &&
          result.overallConfidence >= saveThreshold &&
          result.toDomainReflection() != null &&
          (result.transcript?.trim().isNotEmpty ?? false);

      expect(
        wouldSave,
        isTrue,
        reason: 'raising the quality floor must not drop a journal entry',
      );
    });

    test('non-on-device behaviour is untouched at both call sites', () async {
      await OnDeviceProcessingStore.setEnabled(false);
      expect(
        await LocalAiConfidence.effectiveRemoteFallbackThreshold(),
        LocalAiConfidence.remoteFallbackThreshold,
      );
      expect(
        await LocalAiConfidence.effectiveQualityFloor(),
        LocalAiConfidence.remoteFallbackThreshold,
      );
    });
  });

  group('distribution probe', () {
    test('reports where the current extractor actually scores', () async {
      await OnDeviceProcessingStore.setEnabled(true);

      const corpus = <String, String>{
        'rich (tension + action + theme)': _transcript,
        'tension only': 'I said I was fine but I have not been sleeping much '
            'at all this week.',
        'action only': 'Tomorrow I will call the clinic and book the '
            'appointment I keep putting off.',
        'hedged, no spans': 'Today was maybe kind of a lot, I am not really '
            'sure how to put it.',
        'flat narration, no spans': 'I went to the shop and then I walked '
            'home along the river path.',
      };

      final lines = <String>[];
      for (final entry in corpus.entries) {
        final extractor = LocalReflectionExtractor(
          logitsSource: LocalReflectionDataSource(
            inference: const LocalReflectionHeuristicInference(),
          ),
        );
        final extraction = await extractor.extract(
          transcript: entry.value,
          entryId: 'probe',
        );
        final reflection = LocalAiConfidence.reflectionConfidence(
          reflection: extraction.reflection,
          modelScore: extraction.confidence,
          usedOnnx: extraction.usedOnnx,
        );
        final typed = LocalAiConfidence.transcriptionConfidence(
          transcript: entry.value,
        );
        String overallAt(double t) => LocalAiConfidence.overall(
              transcription: t,
              reflection: reflection,
            ).toStringAsFixed(3);

        lines.add(
          '${entry.key.padRight(32)} '
          'refl=${reflection.toStringAsFixed(3)} '
          'typedT=${typed.toStringAsFixed(3)} '
          'overall[typed]=${overallAt(typed)} '
          'overall[stt .88]=${overallAt(0.88)} '
          'overall[stt .82]=${overallAt(0.82)} '
          'overall[stt .40]=${overallAt(0.40)}',
        );
      }
      // ignore: avoid_print
      print('\n=== on-device confidence distribution ===\n${lines.join('\n')}');

      expect(lines, hasLength(corpus.length));
    });
  });
}

class _FailingCaptureApi implements VoiceMemoryCaptureApi {
  @override
  Future<AnalyzeResponseDto> analyze(
    Map<String, dynamic> body, {
    required String captureToken,
    String? idempotencyKey,
  }) async {
    fail('analyze() reached the network in on-device-only mode');
  }

  @override
  Future<CaptureAttestResponseDto> attest(Map<String, dynamic> body) async {
    fail('attest() reached the network in on-device-only mode');
  }

  @override
  Future<TranscribeResponseDto> transcribe({
    required String durationSeconds,
    required File audio,
    required String captureToken,
    String? idempotencyKey,
  }) async {
    fail('transcribe() reached the network in on-device-only mode');
  }
}

class _CountingCaptureApi implements VoiceMemoryCaptureApi {
  _CountingCaptureApi(this.record);

  final void Function(String) record;

  @override
  Future<AnalyzeResponseDto> analyze(
    Map<String, dynamic> body, {
    required String captureToken,
    String? idempotencyKey,
  }) async {
    record('analyze');
    return const AnalyzeResponseDto(
      reflection: ReflectionDto(mood: 'neutral', emotionalIntensity: 3),
    );
  }

  @override
  Future<CaptureAttestResponseDto> attest(Map<String, dynamic> body) {
    throw UnimplementedError();
  }

  @override
  Future<TranscribeResponseDto> transcribe({
    required String durationSeconds,
    required File audio,
    required String captureToken,
    String? idempotencyKey,
  }) async {
    record('transcribe');
    return const TranscribeResponseDto(transcript: _transcript);
  }
}
