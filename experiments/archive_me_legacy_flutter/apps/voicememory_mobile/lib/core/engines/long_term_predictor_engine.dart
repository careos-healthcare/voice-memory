import '../graph/graph_node.dart';
import '../graph/personal_knowledge_graph.dart';
import '../../features/ai_engines/models/ai_explainability.dart';
import 'evidence_reference.dart';

enum TrajectoryDirection { increasing, stable, decreasing }

class MonthlyObservation {
  const MonthlyObservation({
    required this.year,
    required this.month,
    required this.mentionCount,
  });

  final int year;
  final int month;
  final int mentionCount;
}

class ConditionalTrajectoryForecast {
  ConditionalTrajectoryForecast({
    required this.nodeId,
    required this.label,
    required this.type,
    required this.direction,
    required num probability,
    required this.conditionalStatement,
    required Iterable<MonthlyObservation> monthlyObservations,
    required Iterable<EvidenceReference> evidence,
  }) : probability = clampGraphScore(probability),
       monthlyObservations = List.unmodifiable(monthlyObservations),
       evidence = List.unmodifiable(evidence);

  final String nodeId;
  final String label;
  final NodeType type;
  final TrajectoryDirection direction;
  final double probability;
  final String conditionalStatement;
  final List<MonthlyObservation> monthlyObservations;
  final List<EvidenceReference> evidence;

  double get confidence => probability;

  List<String> get reasoning => [
    'Monthly mentions were counted across ${monthlyObservations.length} months.',
    'Recent direction was classified as ${direction.name}.',
    'Evidence coverage constrained the conditional probability.',
  ];

  String get alternativeExplanation =>
      'Changes in how often you record may explain the trend without a '
      'corresponding change in your life.';

  String get uncertainty =>
      'This is conditional on the observed pattern continuing and is not a '
      'prediction of a certain outcome.';

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
    reasoning: reasoning,
    alternativeExplanation: alternativeExplanation,
    uncertainty: uncertainty,
  );
}

class LongTermPredictorEngine {
  const LongTermPredictorEngine(
    this.graph, {
    this.minimumEvidence = 4,
    this.minimumMonths = 3,
  });

  final PersonalKnowledgeGraph graph;
  final int minimumEvidence;
  final int minimumMonths;

  List<ConditionalTrajectoryForecast> forecast() {
    final forecasts = <ConditionalTrajectoryForecast>[];
    for (final node in graph.nodes.where(
      (n) => n.type == NodeType.habit || n.type == NodeType.fear,
    )) {
      final evidence = referencesForNode(graph, node);
      final counts = <String, int>{};
      for (final item in evidence) {
        final key =
            '${item.observedAt.year.toString().padLeft(4, '0')}-'
            '${item.observedAt.month.toString().padLeft(2, '0')}';
        counts[key] = (counts[key] ?? 0) + 1;
      }
      if (evidence.length < minimumEvidence || counts.length < minimumMonths) {
        continue;
      }
      final keys = counts.keys.toList()..sort();
      final observations = keys.map((key) {
        final parts = key.split('-');
        return MonthlyObservation(
          year: int.parse(parts[0]),
          month: int.parse(parts[1]),
          mentionCount: counts[key]!,
        );
      }).toList();
      final values = observations
          .map((o) => o.mentionCount.toDouble())
          .toList();
      final firstSlope = values[1] - values[0];
      final recentSlope = values.last - values[values.length - 2];
      final acceleration = recentSlope - firstSlope;
      final nonlinearMomentum = recentSlope * 0.7 + acceleration * 0.3;
      final direction = nonlinearMomentum > 0.2
          ? TrajectoryDirection.increasing
          : nonlinearMomentum < -0.2
          ? TrajectoryDirection.decreasing
          : TrajectoryDirection.stable;
      final strength = (nonlinearMomentum.abs() / (values.last + 1)).clamp(
        0.0,
        1.0,
      );
      final coverage = (evidence.length / 12).clamp(0.0, 1.0);
      final probability = 0.5 + strength * 0.3 + coverage * 0.2;
      forecasts.add(
        ConditionalTrajectoryForecast(
          nodeId: node.id,
          label: node.label,
          type: node.type,
          direction: direction,
          probability: probability,
          conditionalStatement:
              'If the observed monthly pattern continues, mentions of '
              '${node.label} may be ${direction.name}.',
          monthlyObservations: observations,
          evidence: evidence,
        ),
      );
    }
    forecasts.sort((a, b) => a.label.compareTo(b.label));
    return List.unmodifiable(forecasts);
  }
}
