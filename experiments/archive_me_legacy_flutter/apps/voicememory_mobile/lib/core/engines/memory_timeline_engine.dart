import '../graph/graph_node.dart';
import '../graph/personal_knowledge_graph.dart';
import 'evidence_reference.dart';

class MentionFrequency {
  MentionFrequency({
    required this.query,
    required this.count,
    required Iterable<String> memoryEntryIds,
    required Iterable<EvidenceReference> evidence,
  }) : memoryEntryIds = List.unmodifiable(memoryEntryIds),
       evidence = List.unmodifiable(evidence);

  final String query;
  final int count;
  final List<String> memoryEntryIds;
  final List<EvidenceReference> evidence;
}

class TimelineCorrelation {
  TimelineCorrelation({
    required this.anchorNodeId,
    required this.anchorLabel,
    required this.relatedNodeId,
    required this.relatedLabel,
    required Iterable<EvidenceReference> evidence,
  }) : evidence = List.unmodifiable(evidence);

  final String anchorNodeId;
  final String anchorLabel;
  final String relatedNodeId;
  final String relatedLabel;
  final List<EvidenceReference> evidence;
}

class MemoryTimelineEngine {
  const MemoryTimelineEngine(this.graph);

  final PersonalKnowledgeGraph graph;

  MentionFrequency getMentionFrequency(
    String topicOrEntity, {
    DateTime? since,
  }) {
    final query = normalizeGraphLabel(topicOrEntity);
    if (query.isEmpty) {
      return MentionFrequency(
        query: query,
        count: 0,
        memoryEntryIds: const [],
        evidence: const [],
      );
    }
    final matches = <String, EvidenceReference>{};
    for (final node in graph.nodes) {
      final labelMatches = normalizeGraphLabel(node.label) == query;
      for (final item in referencesForNode(graph, node)) {
        final excerpt = normalizeGraphLabel(item.excerpt);
        if ((labelMatches || _containsTerm(excerpt, query)) &&
            (since == null || !item.observedAt.isBefore(since.toUtc()))) {
          matches[item.entryId] = item;
        }
      }
    }
    final evidence = matches.values.toList()
      ..sort((a, b) {
        final time = a.observedAt.compareTo(b.observedAt);
        return time != 0 ? time : a.entryId.compareTo(b.entryId);
      });
    return MentionFrequency(
      query: query,
      count: evidence.length,
      memoryEntryIds: evidence.map((e) => e.entryId),
      evidence: evidence,
    );
  }

  List<TimelineCorrelation> correlateAnchorEvents() {
    final result = <TimelineCorrelation>[];
    for (final anchor in graph.nodes.where((n) => n.type == NodeType.event)) {
      final anchorIds = referencesForNode(
        graph,
        anchor,
      ).map((e) => e.entryId).toSet();
      for (final related in graph.getConnectedNodes(anchor.id)) {
        final evidence = referencesForNode(
          graph,
          related,
        ).where((e) => anchorIds.contains(e.entryId)).toList();
        if (evidence.isEmpty) continue;
        result.add(
          TimelineCorrelation(
            anchorNodeId: anchor.id,
            anchorLabel: anchor.label,
            relatedNodeId: related.id,
            relatedLabel: related.label,
            evidence: evidence,
          ),
        );
      }
    }
    result.sort((a, b) {
      final anchor = a.anchorLabel.compareTo(b.anchorLabel);
      return anchor != 0 ? anchor : a.relatedLabel.compareTo(b.relatedLabel);
    });
    return List.unmodifiable(result);
  }

  static bool _containsTerm(String text, String query) =>
      text == query ||
      text.startsWith('$query ') ||
      text.endsWith(' $query') ||
      text.contains(' $query ');
}
