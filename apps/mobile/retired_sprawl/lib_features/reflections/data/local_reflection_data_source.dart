import 'package:archiveme_mobile/api/models/capture_dto.dart';
import 'package:archiveme_mobile/features/reflections/data/local_reflection_heuristic_inference.dart';
import 'package:archiveme_mobile/features/reflections/data/offline_reflection_knowledge_graph.dart';
import 'package:archiveme_mobile/features/reflections/data/onnx_reflection_inference.dart';
import 'package:archiveme_mobile/features/reflections/data/reflection_inference.dart';
import 'package:archiveme_mobile/features/reflections/data/reflection_output_parser.dart';
import 'package:archiveme_mobile/features/reflections/data/reflection_transcript_processor.dart';

/// Result of on-device reflection inference — structured fields + local graph.
class LocalReflectionInferenceResult {
  const LocalReflectionInferenceResult({
    required this.reflection,
    required this.knowledgeGraph,
    required this.usedOnnx,
  });

  final ReflectionDto reflection;
  final OfflineReflectionKnowledgeGraph knowledgeGraph;
  final bool usedOnnx;
}

/// Loads the bundled ONNX model (when present) and maps transcripts into
/// [ReflectionDto] entirely on-device for offline knowledge graph construction.
class LocalReflectionDataSource {
  LocalReflectionDataSource({
    required ReflectionInference inference,
    LocalReflectionHeuristicInference? heuristic,
  }) : _inference = inference,
       _heuristic = heuristic ?? const LocalReflectionHeuristicInference();

  final ReflectionInference _inference;
  final LocalReflectionHeuristicInference _heuristic;

  /// Prefers bundled ONNX; falls back to heuristic logits when the asset is missing.
  static Future<LocalReflectionDataSource> create({
    ReflectionInference? inferenceOverride,
  }) async {
    final inference =
        inferenceOverride ??
        await OnnxReflectionInference.tryCreateFromAsset() ??
        const LocalReflectionHeuristicInference();
    return LocalReflectionDataSource(inference: inference);
  }

  bool get usesOnnx => _inference is OnnxReflectionInference;

  /// Parses [transcript], runs ONNX inference, and returns structured reflection
  /// data plus graph edges for [entryId].
  Future<LocalReflectionInferenceResult> inferFromTranscript({
    required String transcript,
    required String entryId,
  }) async {
    final trimmed = transcript.trim();
    if (trimmed.length < ReflectionTranscriptProcessor.minTranscriptChars) {
      throw ArgumentError.value(
        transcript,
        'transcript',
        'too short for local reflection inference',
      );
    }

    final inputTensor = ReflectionTranscriptProcessor.buildInputTensor(trimmed);
    final logits = _inference is LocalReflectionHeuristicInference
        ? await _heuristic.runForTranscript(trimmed)
        : await _inference.runReflectionLogits(inputTensor);

    final reflection = ReflectionOutputParser.toReflectionDto(
      transcript: trimmed,
      logits: logits,
    );
    final graph = ReflectionOutputParser.buildKnowledgeGraph(
      entryId: entryId,
      reflection: reflection,
    );

    return LocalReflectionInferenceResult(
      reflection: reflection,
      knowledgeGraph: graph,
      usedOnnx: _inference is OnnxReflectionInference,
    );
  }
}
