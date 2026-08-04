import '../graph/graph_node.dart';
import '../graph/personal_knowledge_graph.dart';
import '../../features/ai_engines/models/ai_explainability.dart';
import 'evidence_reference.dart';

class IdentityBeliefShift {
  IdentityBeliefShift({
    required this.beforeBelief,
    required this.afterBelief,
    required DateTime boundary,
    required this.evidenceBackedReason,
    required num confidence,
    required Iterable<EvidenceReference> beforeEvidence,
    required Iterable<EvidenceReference> afterEvidence,
    required Iterable<EvidenceReference> reasonEvidence,
  }) : boundary = boundary.toUtc(),
       confidence = clampGraphScore(confidence),
       beforeEvidence = List.unmodifiable(beforeEvidence),
       afterEvidence = List.unmodifiable(afterEvidence),
       reasonEvidence = List.unmodifiable(reasonEvidence);

  final String beforeBelief;
  final String afterBelief;
  final DateTime boundary;
  final String evidenceBackedReason;
  final double confidence;
  final List<EvidenceReference> beforeEvidence;
  final List<EvidenceReference> afterEvidence;
  final List<EvidenceReference> reasonEvidence;

  List<EvidenceReference> get evidence => [
    ...beforeEvidence,
    ...afterEvidence,
    ...reasonEvidence,
  ];

  String get reasoning => evidenceBackedReason;

  String get alternativeExplanation =>
      'Both beliefs may still coexist in different situations rather than '
      'representing a complete identity shift.';

  String get uncertainty =>
      'The graph only observes recorded statements around the selected boundary.';

  AiExplainability get explainability => AiExplainability(
    confidence: (confidence * 100).round(),
    evidence: evidence
        .map(
          (item) => AiEvidenceSource(
            sourceId: item.entryId,
            excerpt: item.excerpt,
            startUtf16: item.startUtf16,
            endUtf16: item.endUtf16,
          ),
        )
        .toList(),
    reasoning: [reasoning],
    alternativeExplanation: alternativeExplanation,
    uncertainty: uncertainty,
  );
}

class IdentityEvolutionEngine {
  const IdentityEvolutionEngine(this.graph);

  final PersonalKnowledgeGraph graph;

  List<IdentityBeliefShift> analyze({required DateTime boundary}) {
    final utcBoundary = boundary.toUtc();
    final byId = {for (final node in graph.nodes) node.id: node};
    final shifts = <IdentityBeliefShift>[];
    for (final edge in graph.edges.where(
      (e) => e.type == EdgeType.evolvedInto,
    )) {
      final before = byId[edge.sourceNodeId];
      final after = byId[edge.targetNodeId];
      if (before?.type != NodeType.belief || after?.type != NodeType.belief) {
        continue;
      }
      final beforeEvidence = _directEvidence(
        before!,
      ).where((e) => e.observedAt.isBefore(utcBoundary)).toList();
      final afterEvidence = _directEvidence(
        after!,
      ).where((e) => !e.observedAt.isBefore(utcBoundary)).toList();
      if (beforeEvidence.isEmpty || afterEvidence.isEmpty) continue;
      final reasonEvidence = edge.evidence
          .map(
            (e) => EvidenceReference(
              entryId: e.entryId,
              observedAt: e.observedAt,
              excerpt: e.excerpt,
              confidence: e.confidence,
              startUtf16: e.startUtf16,
              endUtf16: e.endUtf16,
            ),
          )
          .toList();
      if (reasonEvidence.isEmpty) continue;
      shifts.add(
        IdentityBeliefShift(
          beforeBelief: before.label,
          afterBelief: after.label,
          boundary: utcBoundary,
          evidenceBackedReason:
              'The graph records "${before.label}" evolved into '
              '"${after.label}".',
          confidence: edge.weight,
          beforeEvidence: beforeEvidence,
          afterEvidence: afterEvidence,
          reasonEvidence: reasonEvidence,
        ),
      );
    }
    return List.unmodifiable(shifts);
  }

  static List<EvidenceReference> _directEvidence(GraphNode node) {
    final result =
        node.evidence
            .map(
              (e) => EvidenceReference(
                entryId: e.entryId,
                observedAt: e.observedAt,
                excerpt: e.excerpt,
                confidence: e.confidence,
                startUtf16: e.startUtf16,
                endUtf16: e.endUtf16,
              ),
            )
            .toList()
          ..sort((a, b) => a.observedAt.compareTo(b.observedAt));
    return result;
  }
}
