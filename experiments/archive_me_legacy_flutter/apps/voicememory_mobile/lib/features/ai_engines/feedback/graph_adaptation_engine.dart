import '../../../core/graph/personal_knowledge_graph_store.dart';
import '../../../services/ai/local_learning_engine.dart';
import '../../../services/ai/local_semantic_store.dart';
import '../models/ai_accuracy_feedback.dart';
import '../models/ai_explainability.dart';

typedef GraphAdaptationResult = LocalLearningResult;

class GraphAdaptationEngine {
  const GraphAdaptationEngine({
    required this.graphStore,
    required this.semanticStore,
  });

  final PersonalKnowledgeGraphStore graphStore;
  final LocalSemanticStore semanticStore;

  Future<GraphAdaptationResult> apply({
    required AiAccuracyFeedback feedback,
    required List<VerifiableCitation> citations,
    Set<String> linkedNodeIds = const {},
    Set<String> linkedEdgeIds = const {},
  }) =>
      LocalLearningEngine(
        graphStore: graphStore,
        semanticStore: semanticStore,
      ).apply(
        feedback: feedback,
        citations: citations,
        linkedNodeIds: linkedNodeIds,
        linkedEdgeIds: linkedEdgeIds,
      );
}
