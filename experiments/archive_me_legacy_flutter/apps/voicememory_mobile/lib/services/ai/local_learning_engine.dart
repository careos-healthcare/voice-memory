import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../core/graph/personal_knowledge_graph_store.dart';
import '../../features/ai_engines/models/ai_accuracy_feedback.dart';
import '../../features/ai_engines/models/ai_explainability.dart';
import 'local_semantic_store.dart';

class LocalLearningResult {
  const LocalLearningResult({
    required this.graph,
    required this.affectedNodeIds,
    this.affectedEdgeIds = const {},
  });

  final PersonalKnowledgeGraph graph;
  final Set<String> affectedNodeIds;
  final Set<String> affectedEdgeIds;
}

class LocalLearningEngine {
  const LocalLearningEngine({
    required this.graphStore,
    required this.semanticStore,
  });

  final PersonalKnowledgeGraphStore graphStore;
  final LocalSemanticStore semanticStore;

  Future<LocalLearningResult> apply({
    required AiAccuracyFeedback feedback,
    required List<VerifiableCitation> citations,
    Set<String> linkedNodeIds = const {},
    Set<String> linkedEdgeIds = const {},
  }) async {
    final graph = await graphStore.load();
    final citedEntryIds = citations
        .map((citation) => citation.sourceEntryId)
        .toSet();
    final resolvedIds = {
      ...linkedNodeIds,
      for (final node in graph.nodes)
        if (node.evidence.any(
          (evidence) => citedEntryIds.contains(evidence.entryId),
        ))
          node.id,
    };
    if (feedback.feedbackState == AiFeedbackState.correct) {
      final next = _boost(graph, resolvedIds, linkedEdgeIds);
      await semanticStore.recordHighTrustAnchors(
        conclusionId: feedback.conclusionId,
        sourceEntryIds: citedEntryIds,
      );
      await graphStore.save(next);
      return LocalLearningResult(
        graph: next,
        affectedNodeIds: resolvedIds,
        affectedEdgeIds: linkedEdgeIds,
      );
    }
    if (feedback.feedbackState == AiFeedbackState.incorrect) {
      final rejectedNodeIds = linkedEdgeIds.isEmpty
          ? resolvedIds
          : linkedNodeIds;
      await semanticStore.recordNegativeConstraint(
        conclusionId: feedback.conclusionId,
        nodeIds: rejectedNodeIds,
        edgeIds: linkedEdgeIds,
        correctionNote: feedback.correctionNote,
      );
      final next = await semanticStore.applyGraphConstraints(graph);
      await graphStore.save(next);
      return LocalLearningResult(
        graph: next,
        affectedNodeIds: rejectedNodeIds,
        affectedEdgeIds: linkedEdgeIds,
      );
    }
    return LocalLearningResult(graph: graph, affectedNodeIds: const {});
  }

  static PersonalKnowledgeGraph _boost(
    PersonalKnowledgeGraph graph,
    Set<String> linkedNodeIds,
    Set<String> linkedEdgeIds,
  ) => PersonalKnowledgeGraph(
    schemaVersion: graph.schemaVersion,
    nodes: [
      for (final node in graph.nodes)
        GraphNode(
          id: node.id,
          type: node.type,
          label: node.label,
          confidence: linkedNodeIds.contains(node.id)
              ? node.confidence + .1
              : node.confidence,
          evidence: node.evidence,
          origin: node.origin,
          externalSource: node.externalSource,
          tags: node.tags,
        ),
    ],
    edges: [
      for (final edge in graph.edges)
        GraphEdge(
          id: edge.id,
          sourceNodeId: edge.sourceNodeId,
          targetNodeId: edge.targetNodeId,
          type: edge.type,
          isDirected: edge.isDirected,
          weight:
              linkedEdgeIds.contains(edge.id) ||
                  linkedNodeIds.contains(edge.sourceNodeId) ||
                  linkedNodeIds.contains(edge.targetNodeId)
              ? edge.weight + .1
              : edge.weight,
          interactionDate: edge.interactionDate,
          emotionalValenceScore: edge.emotionalValenceScore,
          intensity: edge.intensity,
          evidence: edge.evidence,
          origin: edge.origin,
          externalSource: edge.externalSource,
        ),
    ],
    trajectories: graph.trajectories,
    materialization: graph.materialization,
    clock: graph.clock,
  );
}
