import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/audio/transcription/speaker_transcript.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';

/// Runs sherpa-onnx offline speaker diarization when model files are present.
class SherpaDiarizationService {
  SherpaDiarizationService({
    Future<List<TimedSpeakerSpan>> Function(Float32List samples)?
    processSamples,
  }) : _processSamples = processSamples;

  final Future<List<TimedSpeakerSpan>> Function(Float32List samples)?
  _processSamples;

  Future<DiarizedTranscript> diarize({
    required String transcript,
    Float32List? samples,
    String? segmentationModelPath,
    String? embeddingModelPath,
  }) async {
    final labeled = DiarizedTranscript.parseLabeled(transcript);
    final injected = _processSamples;
    if (injected != null && samples != null) {
      final spans = await injected(samples);
      final turns = alignTranscriptToSpeakers(
        transcript: transcript,
        spans: spans,
      );
      if (turns.isEmpty) {
        return labeled ?? DiarizedTranscript.singleSpeaker(transcript);
      }
      return DiarizedTranscript(turns: turns);
    }
    if (samples == null ||
        segmentationModelPath == null ||
        embeddingModelPath == null) {
      return labeled ?? DiarizedTranscript.singleSpeaker(transcript);
    }
    if (!File(segmentationModelPath).existsSync() ||
        !File(embeddingModelPath).existsSync()) {
      return labeled ?? DiarizedTranscript.singleSpeaker(transcript);
    }
    final process =
        _processSamples ??
        _sherpaProcess(
          segmentationModelPath: segmentationModelPath,
          embeddingModelPath: embeddingModelPath,
        );
    try {
      final spans = await process(samples);
      final turns = alignTranscriptToSpeakers(
        transcript: transcript,
        spans: spans,
      );
      if (turns.isEmpty) {
        return labeled ?? DiarizedTranscript.singleSpeaker(transcript);
      }
      return DiarizedTranscript(turns: turns);
    } on Object {
      return labeled ?? DiarizedTranscript.singleSpeaker(transcript);
    }
  }

  Future<List<TimedSpeakerSpan>> Function(Float32List samples) _sherpaProcess({
    required String segmentationModelPath,
    required String embeddingModelPath,
  }) {
    return (Float32List samples) async {
      initBindings();
      final diarizer = OfflineSpeakerDiarization(
        OfflineSpeakerDiarizationConfig(
          segmentation: OfflineSpeakerSegmentationModelConfig(
            pyannote: OfflineSpeakerSegmentationPyannoteModelConfig(
              model: segmentationModelPath,
            ),
          ),
          embedding: SpeakerEmbeddingExtractorConfig(
            model: embeddingModelPath,
          ),
          clustering: const FastClusteringConfig(),
        ),
      );
      try {
        final segments = diarizer.process(samples: samples);
        return [
          for (final segment in segments)
            TimedSpeakerSpan(
              start: segment.start,
              end: segment.end,
              speaker: segment.speaker,
            ),
        ];
      } finally {
        diarizer.free();
      }
    };
  }
}
