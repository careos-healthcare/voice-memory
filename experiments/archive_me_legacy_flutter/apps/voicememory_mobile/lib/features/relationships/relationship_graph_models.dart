import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';

class RelationshipInteraction {
  const RelationshipInteraction({
    required this.person,
    required this.interaction,
    required this.emotion,
    required this.occurredAt,
    required this.emotionalValenceScore,
    required this.intensity,
    required this.evidence,
  });

  final GraphNode person;
  final GraphNode interaction;
  final GraphNode emotion;
  final DateTime occurredAt;
  final double emotionalValenceScore;
  final double intensity;
  final List<GraphEdgeEvidence> evidence;
}

class RelationshipGraphSnapshot {
  const RelationshipGraphSnapshot({
    required this.person,
    required this.interactions,
  });

  final GraphNode person;
  final List<RelationshipInteraction> interactions;

  static RelationshipGraphSnapshot forPerson(
    PersonalKnowledgeGraph graph,
    GraphNode person,
  ) {
    final nodes = {for (final node in graph.nodes) node.id: node};
    final personEdges = graph.edges.where(
      (edge) =>
          edge.type == EdgeType.interactedWith &&
          edge.sourceNodeId == person.id,
    );
    final interactions = <RelationshipInteraction>[];
    for (final personEdge in personEdges) {
      final interaction = nodes[personEdge.targetNodeId];
      if (interaction?.type != NodeType.interaction) continue;
      for (final emotionEdge in graph.edges.where(
        (edge) =>
            edge.type == EdgeType.evokedEmotion &&
            edge.sourceNodeId == interaction!.id,
      )) {
        final emotion = nodes[emotionEdge.targetNodeId];
        if (emotion?.type != NodeType.emotion) continue;
        final validEmotion = emotion!;
        final evidence = {
          for (final item in [...personEdge.evidence, ...emotionEdge.evidence])
            '${item.entryId}:${item.startUtf16}:${item.endUtf16}': item,
        }.values.toList()..sort((a, b) => a.observedAt.compareTo(b.observedAt));
        if (evidence.isEmpty) continue;
        interactions.add(
          RelationshipInteraction(
            person: person,
            interaction: interaction!,
            emotion: validEmotion,
            occurredAt:
                emotionEdge.interactionDate ??
                personEdge.interactionDate ??
                evidence.first.observedAt,
            emotionalValenceScore: emotionEdge.emotionalValenceScore ?? 0,
            intensity: emotionEdge.intensity ?? emotionEdge.weight,
            evidence: List.unmodifiable(evidence),
          ),
        );
      }
    }
    interactions.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return RelationshipGraphSnapshot(
      person: person,
      interactions: List.unmodifiable(interactions),
    );
  }
}

PersonalKnowledgeGraph graphAtTime(
  PersonalKnowledgeGraph graph,
  DateTime cutoff,
) {
  final utcCutoff = cutoff.toUtc();
  final nodes = graph.nodes
      .where(
        (node) => node.evidence.any(
          (evidence) => !evidence.observedAt.isAfter(utcCutoff),
        ),
      )
      .toList();
  final nodeIds = nodes.map((node) => node.id).toSet();
  final edges = graph.edges
      .where(
        (edge) =>
            nodeIds.contains(edge.sourceNodeId) &&
            nodeIds.contains(edge.targetNodeId) &&
            edge.evidence.any(
              (evidence) => !evidence.observedAt.isAfter(utcCutoff),
            ),
      )
      .toList();
  final trajectories = graph.trajectories
      .where(
        (trajectory) =>
            nodeIds.contains(trajectory.subjectNodeId) &&
            (trajectory.relatedNodeId == null ||
                nodeIds.contains(trajectory.relatedNodeId)),
      )
      .toList();
  return PersonalKnowledgeGraph(
    schemaVersion: graph.schemaVersion,
    nodes: nodes,
    edges: edges,
    trajectories: trajectories,
    materialization: graph.materialization,
    clock: graph.clock,
  );
}
