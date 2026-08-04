import '../graph/graph_node.dart';
import '../graph/personal_knowledge_graph.dart';
import 'evidence_reference.dart';

class GoalAssociation {
  GoalAssociation({
    required this.nodeId,
    required this.label,
    required this.type,
    required Iterable<EvidenceReference> evidence,
  }) : evidence = List.unmodifiable(evidence);

  final String nodeId;
  final String label;
  final NodeType type;
  final List<EvidenceReference> evidence;
}

class GoalEvidenceRecord {
  GoalEvidenceRecord({
    required this.goalNodeId,
    required this.goal,
    required this.mentionCount,
    required Iterable<GoalAssociation> associatedHabitsAndActions,
    required Iterable<EvidenceReference> evidence,
  }) : associatedHabitsAndActions = List.unmodifiable(
         associatedHabitsAndActions,
       ),
       evidence = List.unmodifiable(evidence);

  final String goalNodeId;
  final String goal;
  final int mentionCount;
  final List<GoalAssociation> associatedHabitsAndActions;
  final List<EvidenceReference> evidence;
}

class GoalEvidenceEngine {
  const GoalEvidenceEngine(this.graph);

  final PersonalKnowledgeGraph graph;

  List<GoalEvidenceRecord> build() {
    final records = <GoalEvidenceRecord>[];
    for (final goal in graph.nodes.where((n) => n.type == NodeType.goal)) {
      final directEvidence = <String, EvidenceReference>{
        for (final evidence in goal.evidence)
          evidence.entryId: EvidenceReference(
            entryId: evidence.entryId,
            observedAt: evidence.observedAt,
            excerpt: evidence.excerpt,
            confidence: evidence.confidence,
            startUtf16: evidence.startUtf16,
            endUtf16: evidence.endUtf16,
          ),
      }.values.toList()..sort((a, b) => a.observedAt.compareTo(b.observedAt));
      final associations =
          graph
              .getConnectedNodes(goal.id)
              .where(
                (n) => n.type == NodeType.habit || n.type == NodeType.event,
              )
              .map(
                (node) => GoalAssociation(
                  nodeId: node.id,
                  label: node.label,
                  type: node.type,
                  evidence: referencesForNode(graph, node),
                ),
              )
              .toList()
            ..sort((a, b) => a.label.compareTo(b.label));
      records.add(
        GoalEvidenceRecord(
          goalNodeId: goal.id,
          goal: goal.label,
          mentionCount: directEvidence.length,
          associatedHabitsAndActions: associations,
          evidence: directEvidence,
        ),
      );
    }
    records.sort((a, b) => a.goal.compareTo(b.goal));
    return List.unmodifiable(records);
  }
}
