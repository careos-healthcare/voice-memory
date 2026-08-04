import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../services/ai/local_semantic_store.dart';
import 'temporal_graph_history_store.dart';

class TemporalGraphEngine {
  const TemporalGraphEngine({required this.semanticStore, this.historyStore});

  final LocalSemanticStore semanticStore;
  final TemporalGraphHistoryStore? historyStore;

  Future<PersonalKnowledgeGraph> reconstruct({
    required PersonalKnowledgeGraph currentGraph,
    required DateTime targetTime,
  }) async {
    final target = targetTime.toUtc();
    final persisted = await historyStore?.snapshotAt(target);
    final source = persisted ?? currentGraph;
    final nodes = <GraphNode>[];
    for (final node in source.nodes) {
      if (node.createdAt.isAfter(target) ||
          (node.archivedAt != null && !node.archivedAt!.isAfter(target))) {
        continue;
      }
      final evidence = node.evidence
          .where((item) => !item.observedAt.isAfter(target))
          .toList();
      if (evidence.isEmpty) continue;
      var confidence = evidence
          .map((item) => item.confidence)
          .reduce((left, right) => left > right ? left : right);
      if (node.theoryId case final theoryId?) {
        final hypothesis = await semanticStore.hypothesisById(theoryId);
        final snapshots = hypothesis?.evolutionHistory
            .where((item) => !item.date.isAfter(target))
            .toList();
        if (snapshots != null && snapshots.isNotEmpty) {
          snapshots.sort((a, b) => a.date.compareTo(b.date));
          confidence = snapshots.last.confidenceScore / 100;
        }
      }
      nodes.add(
        GraphNode(
          id: node.id,
          type: node.type,
          label: node.label,
          confidence: confidence,
          evidence: evidence,
          origin: node.origin,
          createdAt: node.createdAt,
          archivedAt: node.archivedAt,
          theoryId: node.theoryId,
          externalSource: node.externalSource,
          tags: node.tags,
        ),
      );
    }
    final nodeIds = nodes.map((node) => node.id).toSet();
    final edges = <GraphEdge>[];
    for (final edge in source.edges) {
      if (!nodeIds.contains(edge.sourceNodeId) ||
          !nodeIds.contains(edge.targetNodeId) ||
          edge.createdAt.isAfter(target) ||
          (edge.archivedAt != null && !edge.archivedAt!.isAfter(target))) {
        continue;
      }
      final evidence = edge.evidence
          .where((item) => !item.observedAt.isAfter(target))
          .toList();
      if (evidence.isEmpty) continue;
      var weight = evidence
          .map((item) => item.confidence)
          .reduce((left, right) => left > right ? left : right);
      if (edge.theoryId case final theoryId?) {
        final hypothesis = await semanticStore.hypothesisById(theoryId);
        final snapshots = hypothesis?.evolutionHistory
            .where((item) => !item.date.isAfter(target))
            .toList();
        if (snapshots != null && snapshots.isNotEmpty) {
          snapshots.sort((a, b) => a.date.compareTo(b.date));
          weight = snapshots.last.confidenceScore / 100;
        }
      }
      edges.add(
        GraphEdge(
          id: edge.id,
          sourceNodeId: edge.sourceNodeId,
          targetNodeId: edge.targetNodeId,
          type: edge.type,
          isDirected: edge.isDirected,
          weight: weight,
          interactionDate: edge.interactionDate,
          emotionalValenceScore: edge.emotionalValenceScore,
          intensity: edge.intensity,
          evidence: evidence,
          origin: edge.origin,
          createdAt: edge.createdAt,
          archivedAt: edge.archivedAt,
          theoryId: edge.theoryId,
          externalSource: edge.externalSource,
        ),
      );
    }
    final trajectories = source.trajectories
        .where(
          (trajectory) =>
              nodeIds.contains(trajectory.subjectNodeId) &&
              (trajectory.relatedNodeId == null ||
                  nodeIds.contains(trajectory.relatedNodeId)),
        )
        .map(
          (trajectory) => GraphTrajectory(
            id: trajectory.id,
            type: trajectory.type,
            subjectNodeId: trajectory.subjectNodeId,
            relatedNodeId: trajectory.relatedNodeId,
            windows: trajectory.windows
                .where((window) => !window.end.isAfter(target))
                .toList(),
          ),
        )
        .where((trajectory) => trajectory.windows.isNotEmpty)
        .toList();
    return semanticStore.applyGraphConstraints(
      PersonalKnowledgeGraph(
        schemaVersion: source.schemaVersion,
        nodes: nodes,
        edges: edges,
        trajectories: trajectories,
        materialization: source.materialization,
      ),
    );
  }

  List<DateTime> markers(PersonalKnowledgeGraph graph) {
    final manualCounts = <DateTime, int>{};
    final markers = <DateTime>{};
    for (final node in graph.nodes) {
      final day = DateTime.utc(
        node.createdAt.year,
        node.createdAt.month,
        node.createdAt.day,
      );
      if (node.origin == NodeOrigin.manual) {
        manualCounts[day] = (manualCounts[day] ?? 0) + 1;
      }
      if (node.type == NodeType.identityShift) markers.add(day);
    }
    for (final entry in manualCounts.entries) {
      if (entry.value >= 5) markers.add(entry.key);
    }
    return markers.toList()..sort();
  }
}
