import '../graph/graph_node.dart';
import '../graph/personal_knowledge_graph.dart';
import 'evidence_reference.dart';

class EvidenceCoachingObservation {
  EvidenceCoachingObservation({
    required this.firstDomain,
    required this.firstLabel,
    required this.secondDomain,
    required this.secondLabel,
    required this.observation,
    required this.optionalReflection,
    required num confidence,
    required Iterable<EvidenceReference> evidence,
  }) : confidence = clampGraphScore(confidence),
       evidence = List.unmodifiable(evidence);

  final NodeType firstDomain;
  final String firstLabel;
  final NodeType secondDomain;
  final String secondLabel;
  final String observation;
  final String optionalReflection;
  final double confidence;
  final List<EvidenceReference> evidence;
}

class EvidenceCoachingEngine {
  const EvidenceCoachingEngine(this.graph);

  final PersonalKnowledgeGraph graph;

  List<EvidenceCoachingObservation> find({
    Duration window = const Duration(hours: 24),
  }) {
    if (window <= Duration.zero) {
      throw ArgumentError.value(window, 'window', 'Must be positive');
    }
    final result = <EvidenceCoachingObservation>[];
    for (var i = 0; i < graph.nodes.length; i++) {
      for (var j = i + 1; j < graph.nodes.length; j++) {
        final a = graph.nodes[i];
        final b = graph.nodes[j];
        if (a.type == b.type) continue;
        final nearby = <String, EvidenceReference>{};
        for (final left in referencesForNode(graph, a)) {
          for (final right in referencesForNode(graph, b)) {
            if (left.observedAt.difference(right.observedAt).abs() <= window) {
              nearby[left.entryId] = left;
              nearby[right.entryId] = right;
            }
          }
        }
        if (nearby.length < 2) continue;
        final evidence = nearby.values.toList()
          ..sort((x, y) => x.observedAt.compareTo(y.observedAt));
        result.add(
          EvidenceCoachingObservation(
            firstDomain: a.type,
            firstLabel: a.label,
            secondDomain: b.type,
            secondLabel: b.label,
            observation:
                '${a.label} and ${b.label} appeared within '
                '${window.inHours} hours in ${nearby.length} entries.',
            optionalReflection:
                'You might consider whether this timing feels meaningful to you.',
            confidence: (nearby.length / 5).clamp(0.0, 1.0),
            evidence: evidence,
          ),
        );
      }
    }
    return List.unmodifiable(result);
  }
}
