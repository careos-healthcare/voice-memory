import '../core/graph/personal_knowledge_graph.dart';
import '../core/llm/native/llama_inference_session.dart';
import '../core/llm/on_device_extractor.dart';
import '../core/llm/semantic_extraction_result.dart';
import '../models/journal_entry.dart';
import 'app_services.dart';

typedef AsyncLifeOsGraphBuilder =
    Future<PersonalKnowledgeGraph> Function(Iterable<JournalEntry> entries);

/// Production graph builder shared by providers, insights, exports, and backup.
///
/// Native inference is opportunistic: when no installed, foreground-unlocked
/// session is ready, the extractor retains its deterministic local fallback.
Future<PersonalKnowledgeGraph> buildProductionLifeOsGraph(
  Iterable<JournalEntry> entries,
) async {
  LlamaInferenceSession? session;
  if (AppServices.isInitialized) {
    session = await AppServices.instance.readyLlamaInferenceSession();
  }
  final extractor = OnDeviceSemanticExtractor(
    asyncDriver: session == null ? null : LlamaSessionSemanticDriver(session),
  );
  return PersonalKnowledgeGraphEngine(
    extractor: extractor,
  ).rebuildAsync(entries);
}

final class LlamaSessionSemanticDriver implements AsyncSemanticInferenceDriver {
  const LlamaSessionSemanticDriver(this.session);

  final LlamaInferenceSession session;

  @override
  bool get isReady => session.isReady;

  @override
  Future<SemanticExtractionResult> infer(String text) => session.infer(text);
}
