import 'package:archiveme_mobile/features/reflections/data/offline_reflection_knowledge_graph.dart';
import 'package:archiveme_mobile/services/local_llm/local_llm_knowledge_graph_extractor.dart';

/// Result of the unified offline capture pipeline (STT + entity extraction).
class AiCapturePipelineResult {
  const AiCapturePipelineResult({
    required this.entryId,
    required this.transcript,
    required this.graphUpdate,
    this.transcriptSource = AiTranscriptSource.provided,
  });

  final String entryId;
  final String transcript;
  final LocalLlmGraphUpdate graphUpdate;
  final AiTranscriptSource transcriptSource;

  OfflineReflectionKnowledgeGraph get knowledgeGraph =>
      graphUpdate.toKnowledgeGraph();
}

enum AiTranscriptSource {
  provided,
  onDeviceStt,
}

/// Progress callback for model downloads (0–100).
typedef AiModelInstallProgress = void Function(int percent);
