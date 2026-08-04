import '../graph/graph_node.dart';
import '../graph/personal_knowledge_graph.dart';

/// Exact source evidence shared by every Life OS engine.
class EvidenceReference {
  EvidenceReference({
    required this.entryId,
    required DateTime observedAt,
    required this.excerpt,
    required num confidence,
    required this.startUtf16,
    required this.endUtf16,
  }) : observedAt = observedAt.toUtc(),
       confidence = clampGraphScore(confidence);

  final String entryId;
  final DateTime observedAt;
  final String excerpt;
  final double confidence;
  final int startUtf16;
  final int endUtf16;

  bool get hasStructurallyValidCitation =>
      entryId.isNotEmpty &&
      excerpt.isNotEmpty &&
      startUtf16 >= 0 &&
      endUtf16 > startUtf16 &&
      endUtf16 - startUtf16 == excerpt.length;
}

List<EvidenceReference> referencesForNode(
  PersonalKnowledgeGraph graph,
  GraphNode node,
) {
  final byEntry = <String, EvidenceReference>{};

  void add(
    String id,
    DateTime at,
    String excerpt,
    double confidence,
    int startUtf16,
    int endUtf16,
  ) {
    final candidate = EvidenceReference(
      entryId: id,
      observedAt: at,
      excerpt: excerpt,
      confidence: confidence,
      startUtf16: startUtf16,
      endUtf16: endUtf16,
    );
    if (!candidate.hasStructurallyValidCitation) return;
    final current = byEntry[id];
    if (current == null || candidate.observedAt.isBefore(current.observedAt)) {
      byEntry[id] = candidate;
    }
  }

  for (final item in node.evidence) {
    add(
      item.entryId,
      item.observedAt,
      item.excerpt,
      item.confidence,
      item.startUtf16,
      item.endUtf16,
    );
  }
  for (final edge in graph.edges.where(
    (edge) => edge.sourceNodeId == node.id || edge.targetNodeId == node.id,
  )) {
    for (final item in edge.evidence) {
      add(
        item.entryId,
        item.observedAt,
        item.excerpt,
        item.confidence,
        item.startUtf16,
        item.endUtf16,
      );
    }
  }

  final result = byEntry.values.toList()
    ..sort((a, b) {
      final time = a.observedAt.compareTo(b.observedAt);
      return time != 0 ? time : a.entryId.compareTo(b.entryId);
    });
  return List.unmodifiable(result);
}
