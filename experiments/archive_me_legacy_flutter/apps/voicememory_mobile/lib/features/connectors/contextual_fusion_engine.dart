import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';

class ContextualCorrelation {
  const ContextualCorrelation({
    required this.id,
    required this.statement,
    required this.confidence,
    required this.sourceNodeIds,
    required this.journalEvidence,
  });

  final String id;
  final String statement;
  final double confidence;
  final List<String> sourceNodeIds;
  final List<GraphNodeEvidence> journalEvidence;
}

class ContextualFusionEngine {
  const ContextualFusionEngine();

  List<ContextualCorrelation> analyze(PersonalKnowledgeGraph graph) {
    final external = graph.nodes
        .where((node) => node.origin == NodeOrigin.external)
        .toList();
    if (external.isEmpty) return const [];
    final journalEvidence = graph.nodes
        .where((node) => node.origin != NodeOrigin.external)
        .expand((node) => node.evidence);
    final focusByDay = <String, int>{};
    final evidenceByDay = <String, List<GraphNodeEvidence>>{};
    for (final evidence in journalEvidence) {
      final count = RegExp(
        r'\bfocus(?:ed|ing)?\b',
        caseSensitive: false,
      ).allMatches(evidence.excerpt).length;
      if (count > 0) {
        final key = _dayKey(evidence.observedAt);
        focusByDay[key] = (focusByDay[key] ?? 0) + count;
        (evidenceByDay[key] ??= []).add(evidence);
      }
    }
    final byDay = <String, List<GraphNode>>{};
    for (final node in external) {
      (byDay[_dayKey(node.createdAt)] ??= []).add(node);
    }
    var qualifyingDays = 0;
    var focusMentions = 0;
    final sourceIds = <String>{};
    final citations = <GraphNodeEvidence>[];
    for (final entry in byDay.entries) {
      final sleep = _metric(entry.value, 'Sleep:', suffix: 'h');
      final energy = _metric(entry.value, 'Music energy:', suffix: '%');
      if (sleep != null && sleep >= 7 && energy != null && energy >= 60) {
        qualifyingDays++;
        focusMentions += focusByDay[entry.key] ?? 0;
        sourceIds.addAll(entry.value.map((node) => node.id));
        citations.addAll(evidenceByDay[entry.key] ?? const []);
      }
    }
    if (qualifyingDays == 0 || focusMentions == 0) return const [];
    return [
      ContextualCorrelation(
        id: stableGraphId('external-correlation', [
          'sleep',
          'music-energy',
          'focus',
        ]),
        statement:
            'Across $qualifyingDays day${qualifyingDays == 1 ? '' : 's'} '
            'with at least 7 hours of sleep and high-energy music, your '
            'journal language mentioned focus $focusMentions '
            'time${focusMentions == 1 ? '' : 's'}.',
        confidence: (0.55 + qualifyingDays * .08).clamp(.55, .92),
        sourceNodeIds: sourceIds.toList()..sort(),
        journalEvidence: citations,
      ),
    ];
  }

  double? _metric(
    List<GraphNode> nodes,
    String prefix, {
    required String suffix,
  }) {
    for (final node in nodes) {
      if (!node.label.startsWith(prefix)) continue;
      final raw = node.label
          .substring(prefix.length)
          .trim()
          .replaceAll(suffix, '');
      return double.tryParse(raw);
    }
    return null;
  }
}

String _dayKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
