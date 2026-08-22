import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/api/models/capture_dto.dart';
import 'package:archiveme_mobile/api/retrofit/voice_memory_capture_api.dart';
import 'package:archiveme_mobile/features/reflections/data/local_ai_confidence.dart';
import 'package:archiveme_mobile/features/privacy/on_device_processing_store.dart';
import 'package:archiveme_mobile/features/reflections/data/local_ai_remote_fallback.dart';
import 'package:archiveme_mobile/features/reflections/data/local_reflection_data_source.dart';
import 'package:archiveme_mobile/features/reflections/data/local_reflection_heuristic_inference.dart';
import 'package:archiveme_mobile/features/reflections/data/onnx_llm_reflection_extractor.dart';
import 'package:archiveme_mobile/features/reflections/data/whisper_audio_processor.dart';
import 'package:archiveme_mobile/features/reflections/data/onnx_whisper_transcription.dart';
import 'package:archiveme_mobile/features/reflections/local_ai_pipeline.dart';
import 'package:archiveme_mobile/services/audio_structuring/audio_structuring_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalAiConfidence', () {
    test('combines transcription and reflection scores geometrically', () {
      final overall = LocalAiConfidence.overall(
        transcription: 0.9,
        reflection: 0.81,
      );
      expect(overall, closeTo(0.854, 0.01));
    });

    test('flags low-quality transcripts', () {
      expect(
        LocalAiConfidence.transcriptionConfidence(transcript: 'um'),
        0.0,
      );
    });
  });

  group('WhisperAudioProcessor', () {
    test('builds mel tensor from mono PCM16', () {
      final pcm = Int16List(16000);
      for (var i = 0; i < pcm.length; i++) {
        pcm[i] = (12000 * (i.isEven ? 1 : -1)).toInt();
      }
      final mel = WhisperAudioProcessor.buildMelFeaturesFromPcm(
        pcm,
        sampleRateHz: 16000,
      );
      expect(mel, isNotEmpty);
      expect(mel.any((value) => value != 0), isTrue);
    });

    test('reads PCM from WAV sidecar files', () async {
      final dir = await Directory.systemTemp.createTemp('local_ai_wav_');
      final wav = File('${dir.path}/chunk.wav');
      await wav.writeAsBytes(_minimalWav(pcmSamples: 8000));
      final mel = WhisperAudioProcessor.buildMelFeaturesFromFile(wav);
      expect(mel, isNotNull);
      await dir.delete(recursive: true);
    });
  });

  group('LocalAiPipeline', () {
    test('structures local STT transcript before reflection extraction', () async {
      AudioStructuringService? structuringService;
      final pipeline = LocalAiPipeline(
        reflectionExtractor: LocalReflectionExtractor(
          logitsSource: LocalReflectionDataSource(
            inference: const LocalReflectionHeuristicInference(),
          ),
        ),
        audioStructuringResolver: () async {
          structuringService ??= await AudioStructuringService.createStub();
          return structuringService;
        },
        localSttOverride: (_) async => const WhisperTranscriptionResult(
          transcript:
              'um so work has been heavy but I keep taking on more uh yeah',
          confidence: 0.9,
          usedOnnx: true,
        ),
      );

      final dir = await Directory.systemTemp.createTemp('local_ai_structure_');
      final wav = File('${dir.path}/voice.wav');
      await wav.writeAsBytes(_minimalWav(pcmSamples: 8000));

      final result = await pipeline.processAudio(
        audioFile: wav,
        durationSeconds: 12,
        entryId: 'entry-structured',
      );

      expect(result.succeeded, isTrue);
      expect(result.usedLocalStt, isTrue);
      expect(result.usedLocalStructuring, isTrue);
      expect(result.transcript?.toLowerCase(), contains('work has been heavy'));
      expect(result.transcript?.toLowerCase(), isNot(contains(' um ')));
      await dir.delete(recursive: true);
    });

    test('processTranscript skips structuring when transcript is pre-supplied via processTranscript', () async {
      var structuringCalls = 0;
      final pipeline = LocalAiPipeline(
        reflectionExtractor: LocalReflectionExtractor(
          logitsSource: LocalReflectionDataSource(
            inference: const LocalReflectionHeuristicInference(),
          ),
        ),
        audioStructuringResolver: () async {
          structuringCalls++;
          return AudioStructuringService.createStub();
        },
      );

      final result = await pipeline.processTranscript(
        transcript:
            'Work has been heavy but I keep taking on more. '
            'Tomorrow I will leave on time and rest.',
        durationSeconds: 12,
        entryId: 'entry-local',
      );

      expect(result.succeeded, isTrue);
      expect(result.usedLocalStructuring, isFalse);
      expect(structuringCalls, 0);
    });

    test('processTranscript succeeds with heuristic extractor offline', () async {
      final pipeline = LocalAiPipeline(
        reflectionExtractor: LocalReflectionExtractor(
          logitsSource: LocalReflectionDataSource(
            inference: const LocalReflectionHeuristicInference(),
          ),
        ),
      );

      final result = await pipeline.processTranscript(
        transcript:
            'Work has been heavy but I keep taking on more. '
            'Tomorrow I will leave on time and rest.',
        durationSeconds: 12,
        entryId: 'entry-local',
      );

      expect(result.succeeded, isTrue);
      expect(result.reflection, isNotNull);
      expect(result.reflection!.tensionOrContradiction, isNotNull);
      expect(result.reflection!.nextSmallAction, isNotNull);
      expect(result.overallConfidence, greaterThan(0.5));
      expect(result.fellBackToRemote, isFalse);
    });

    test('never invokes remote fallback when on-device-only mode is enabled', () async {
      await OnDeviceProcessingStore.resetForTest();
      await OnDeviceProcessingStore.setEnabled(true);

      var analyzeCalls = 0;
      final pipeline = LocalAiPipeline(
        reflectionExtractor: LocalReflectionExtractor(
          logitsSource: LocalReflectionDataSource(
            inference: const LocalReflectionHeuristicInference(),
          ),
        ),
        remoteFallback: LocalAiRemoteFallback(
          _CountingCaptureApi(onAnalyze: () => analyzeCalls++),
        ),
        confidenceThreshold: 0.99,
      );

      final result = await pipeline.processTranscript(
        transcript:
            'Work has been heavy but I keep taking on more. '
            'Tomorrow I will leave on time and rest.',
        durationSeconds: 12,
        entryId: 'entry-never-remote',
        captureToken: 'capture-token',
      );

      expect(analyzeCalls, 0);
      expect(result.fellBackToRemote, isFalse);
      expect(result.succeeded, isTrue);
    });

    test('returns failure when transcript is empty and no remote fallback', () async {
      final pipeline = await LocalAiPipeline.create();
      final dir = await Directory.systemTemp.createTemp('local_ai_empty_');
      final empty = File('${dir.path}/empty.wav');
      await empty.writeAsBytes(_minimalWav(pcmSamples: 0));

      final result = await pipeline.processAudio(
        audioFile: empty,
        durationSeconds: 1,
        entryId: 'entry-empty',
      );

      expect(result.succeeded, isFalse);
      await dir.delete(recursive: true);
    });
  });
}

Uint8List _minimalWav({required int pcmSamples}) {
  final dataSize = pcmSamples * 2;
  final buffer = BytesBuilder();
  buffer.add('RIFF'.codeUnits);
  buffer.add(_le32(36 + dataSize));
  buffer.add('WAVE'.codeUnits);
  buffer.add('fmt '.codeUnits);
  buffer.add(_le32(16));
  buffer.add(_le16(1));
  buffer.add(_le16(1));
  buffer.add(_le32(16000));
  buffer.add(_le32(32000));
  buffer.add(_le16(2));
  buffer.add(_le16(16));
  buffer.add('data'.codeUnits);
  buffer.add(_le32(dataSize));
  for (var i = 0; i < pcmSamples; i++) {
    buffer.add([0, 0]);
  }
  return buffer.toBytes();
}

Uint8List _le16(int value) =>
    Uint8List(2)..buffer.asByteData().setUint16(0, value, Endian.little);

Uint8List _le32(int value) =>
    Uint8List(4)..buffer.asByteData().setUint32(0, value, Endian.little);

class _CountingCaptureApi implements VoiceMemoryCaptureApi {
  _CountingCaptureApi({required this.onAnalyze});

  final void Function() onAnalyze;

  @override
  Future<AnalyzeResponseDto> analyze(
    Map<String, dynamic> body, {
    required String captureToken,
    String? idempotencyKey,
  }) async {
    onAnalyze();
    return const AnalyzeResponseDto(
      reflection: ReflectionDto(
        mood: 'neutral',
        emotionalIntensity: 3,
        recurringThemes: [],
      ),
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
  }) {
    throw UnimplementedError();
  }
}
