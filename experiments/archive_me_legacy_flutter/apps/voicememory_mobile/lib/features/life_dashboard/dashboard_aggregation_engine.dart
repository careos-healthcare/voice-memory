import '../../core/engines/goal_evidence_engine.dart';
import '../../core/engines/identity_evolution_engine.dart';
import '../../core/engines/long_term_predictor_engine.dart';
import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../features/ai_engines/models/ai_explainability.dart';
import '../../features/connectors/contextual_fusion_engine.dart';
import '../../features/relationships/relationship_graph_models.dart';
import '../../services/ai/local_semantic_store.dart';
import 'life_dashboard_models.dart';

typedef DashboardSynthesisLoader =
    Future<DashboardSynthesizedPayload?> Function(TimeHorizon horizon);

class DashboardAggregationEngine {
  const DashboardAggregationEngine({
    required this.graph,
    required this.semanticStore,
    this.clock = DateTime.now,
  });

  final PersonalKnowledgeGraph graph;
  final LocalSemanticStore semanticStore;
  final DateTime Function() clock;

  Future<LifeDashboardSnapshot> aggregate(
    TimeHorizon horizon, {
    DashboardSynthesizedPayload? cachedSynthesis,
    DashboardSynthesisLoader? refreshSynthesis,
  }) async {
    final now = clock().toUtc();
    final bounds = _bounds(horizon, now);
    final localGraph = graphAtTime(graph, bounds.end);
    final periodEntryIds = localGraph.nodes
        .expand((node) => node.evidence)
        .where(
          (item) =>
              !item.observedAt.isBefore(bounds.start) &&
              item.observedAt.isBefore(bounds.end),
        )
        .map((item) => item.entryId)
        .toSet();
    final semanticHits = await semanticStore.search(horizon.label, limit: 100);
    final localMatches = semanticHits
        .where((hit) => periodEntryIds.contains(hit.entryId))
        .length;
    final localIdentity = _identity(localGraph, bounds);
    final localGoals = _goals(localGraph, bounds);
    final localPredictions = [
      ..._predictions(localGraph),
      for (final correlation in const ContextualFusionEngine().analyze(
        localGraph,
      ))
        PredictiveHorizon(
          nodeId: correlation.id,
          statement: correlation.statement,
          category: 'Cross-domain context',
          probability: correlation.confidence,
          explainability: AiExplainability(
            confidence: (correlation.confidence * 100).round(),
            evidence: [
              for (final item in correlation.journalEvidence)
                VerifiableCitation(
                  sourceEntryId: item.entryId,
                  exactQuote: item.excerpt,
                  confidenceScore: item.confidence,
                  startUtf16: item.startUtf16,
                  endUtf16: item.endUtf16,
                ),
            ],
            reasoning: const [
              'Compared same-day passive context with journal language.',
            ],
            alternativeExplanation:
                'The association may reflect routine or another unmeasured factor.',
            uncertainty:
                'Passive observations show correlation, not causation.',
            externalSources: [
              for (final node in localGraph.nodes)
                if (correlation.sourceNodeIds.contains(node.id) &&
                    node.externalSource != null)
                  ExternalExplainabilitySource(
                    nodeId: node.id,
                    source: node.externalSource!,
                    label: node.label,
                    observedAt: node.createdAt,
                  ),
            ],
          ),
        ),
    ];

    DashboardSynthesizedPayload? synthesis = cachedSynthesis;
    var usedCloud = false;
    if (horizon != TimeHorizon.today && refreshSynthesis != null) {
      try {
        final refreshed = await refreshSynthesis(horizon);
        if (refreshed != null) {
          synthesis = refreshed;
          usedCloud = true;
        }
      } on Object {
        // Cached V4 synthesis remains usable when refresh is unavailable.
      }
    }
    return LifeDashboardSnapshot(
      horizon: horizon,
      generatedAt: now,
      identity: synthesis?.identity ?? localIdentity,
      dailyPulse: _dailyPulse(localGraph, bounds),
      habits: _habits(localGraph, bounds),
      relationships: _relationships(localGraph, bounds),
      goals: synthesis?.goals.isNotEmpty == true
          ? synthesis!.goals
          : localGoals,
      predictions: synthesis?.predictions.isNotEmpty == true
          ? synthesis!.predictions
          : localPredictions,
      localSemanticMatches: localMatches,
      usedCloudSynthesis: usedCloud,
    );
  }

  static IdentityDimension _identity(
    PersonalKnowledgeGraph graph,
    _DashboardBounds bounds,
  ) {
    final beliefs = graph.nodes
        .where(
          (node) =>
              node.type == NodeType.belief && _hasPeriodEvidence(node, bounds),
        )
        .toList();
    final shifts = IdentityEvolutionEngine(
      graph,
    ).analyze(boundary: bounds.start);
    return IdentityDimension(
      coreBeliefs: beliefs.map((node) => node.label).toList(),
      selfPerceptionShifts: shifts
          .map((shift) => '${shift.beforeBelief} → ${shift.afterBelief}')
          .toList(),
      nodeIds: {
        ...beliefs.map((node) => node.id),
        ...shifts.expand(
          (shift) => graph.nodes
              .where(
                (node) =>
                    node.label == shift.beforeBelief ||
                    node.label == shift.afterBelief,
              )
              .map((node) => node.id),
        ),
      },
      explainability:
          shifts.firstOrNull?.explainability ??
          _nodeExplainability(beliefs.firstOrNull, 'Identity evidence'),
    );
  }

  static LocalDailyPulse _dailyPulse(
    PersonalKnowledgeGraph graph,
    _DashboardBounds bounds,
  ) {
    final periodNodes = graph.nodes
        .where((node) => _hasPeriodEvidence(node, bounds))
        .toList();
    final emotionEvidence =
        periodNodes
            .where((node) => node.type == NodeType.emotion)
            .expand(
              (node) => node.evidence
                  .where((item) => _inBounds(item.observedAt, bounds))
                  .map((item) => (at: item.observedAt, text: node.label)),
            )
            .toList()
          ..sort((a, b) => a.at.compareTo(b.at));
    final midpoint = (emotionEvidence.length / 2).ceil();
    final earlier = emotionEvidence.take(midpoint).toList();
    final later = emotionEvidence.skip(midpoint).toList();
    double average(List<({DateTime at, String text})> values) => values.isEmpty
        ? 0
        : values.map((item) => _sentiment(item.text)).reduce((a, b) => a + b) /
              values.length;
    return LocalDailyPulse(
      immediateActionItems: periodNodes
          .where((node) => node.type == NodeType.actionItem)
          .map((node) => node.label)
          .toList(),
      activeHabitTallies: {
        for (final node in periodNodes.where(
          (node) => node.type == NodeType.habit,
        ))
          node.label: node.evidence
              .where((item) => _inBounds(item.observedAt, bounds))
              .length,
      },
      goalMentionFrequencies: {
        for (final node in periodNodes.where(
          (node) => node.type == NodeType.goal,
        ))
          node.label: node.evidence
              .where((item) => _inBounds(item.observedAt, bounds))
              .length,
      },
      emotionalVelocity: (average(later) - average(earlier))
          .clamp(-1, 1)
          .toDouble(),
    );
  }

  static List<HabitTracker> _habits(
    PersonalKnowledgeGraph graph,
    _DashboardBounds bounds,
  ) {
    final midpoint = bounds.start.add(bounds.end.difference(bounds.start) ~/ 2);
    return graph.nodes
        .where(
          (node) =>
              node.type == NodeType.habit && _hasPeriodEvidence(node, bounds),
        )
        .map((node) {
          final evidence = node.evidence
              .where((item) => _inBounds(item.observedAt, bounds))
              .toList();
          final earlier = evidence
              .where((item) => item.observedAt.isBefore(midpoint))
              .length;
          final later = evidence.length - earlier;
          return HabitTracker(
            nodeId: node.id,
            label: node.label,
            mentionCount: evidence.length,
            sentiment: _sentiment(
              evidence.map((item) => item.excerpt).join(' '),
            ),
            frictionPoints: evidence
                .where(
                  (item) => RegExp(
                    r'\b(?:hard|stuck|missed|failed|difficult|frustrated)\b',
                    caseSensitive: false,
                  ).hasMatch(item.excerpt),
                )
                .map((item) => item.excerpt)
                .take(3)
                .toList(),
            consistencyVelocity:
                ((later - earlier) / (evidence.isEmpty ? 1 : evidence.length))
                    .clamp(-1, 1)
                    .toDouble(),
          );
        })
        .toList();
  }

  static List<RelationshipPulse> _relationships(
    PersonalKnowledgeGraph graph,
    _DashboardBounds bounds,
  ) {
    final pulses = <RelationshipPulse>[];
    for (final person in graph.nodes.where(
      (node) => node.type == NodeType.person,
    )) {
      final interactions = RelationshipGraphSnapshot.forPerson(graph, person)
          .interactions
          .where((interaction) => _inBounds(interaction.occurredAt, bounds))
          .toList();
      if (interactions.isEmpty) continue;
      pulses.add(
        RelationshipPulse(
          personNodeId: person.id,
          personLabel: person.label,
          valenceTrend:
              interactions
                  .map((item) => item.emotionalValenceScore)
                  .reduce((a, b) => a + b) /
              interactions.length,
          recentTouchpoints: interactions.length,
          lastInteractionAt: interactions.last.occurredAt,
        ),
      );
    }
    pulses.sort((a, b) => b.lastInteractionAt.compareTo(a.lastInteractionAt));
    return pulses;
  }

  static List<GoalProgress> _goals(
    PersonalKnowledgeGraph graph,
    _DashboardBounds bounds,
  ) => GoalEvidenceEngine(graph)
      .build()
      .map((goal) {
        final evidence = goal.evidence
            .where((item) => _inBounds(item.observedAt, bounds))
            .toList();
        final actual = goal.associatedHabitsAndActions
            .expand((item) => item.evidence)
            .where((item) => _inBounds(item.observedAt, bounds))
            .map((item) => item.entryId)
            .toSet()
            .length;
        final goalNode = graph.nodes
            .where((node) => node.id == goal.goalNodeId)
            .firstOrNull;
        return GoalProgress(
          nodeId: goal.goalNodeId,
          label: goal.goal,
          statedIntentions: evidence.length,
          actualMentions: actual,
          momentum: (actual / (evidence.length + 1)).clamp(0, 1).toDouble(),
          explainability: _nodeExplainability(
            goalNode,
            'Goal progress evidence',
          ),
        );
      })
      .where((goal) => goal.statedIntentions > 0)
      .toList();

  static List<PredictiveHorizon> _predictions(PersonalKnowledgeGraph graph) =>
      LongTermPredictorEngine(graph)
          .forecast()
          .map(
            (forecast) => PredictiveHorizon(
              nodeId: forecast.nodeId,
              statement: forecast.conditionalStatement,
              category: forecast.type == NodeType.fear
                  ? 'Potential pressure warning'
                  : 'Pattern predictor',
              probability: forecast.probability,
              explainability: forecast.explainability,
            ),
          )
          .toList();

  static AiExplainability? _nodeExplainability(GraphNode? node, String reason) {
    if (node == null || node.evidence.isEmpty) return null;
    return AiExplainability(
      confidence: (node.confidence * 100).round(),
      evidence: node.evidence
          .map(
            (item) => VerifiableCitation(
              sourceEntryId: item.entryId,
              exactQuote: item.excerpt,
              confidenceScore: item.confidence,
              startUtf16: item.startUtf16,
              endUtf16: item.endUtf16,
            ),
          )
          .toList(),
      reasoning: [reason],
      alternativeExplanation:
          'Recording frequency may influence which pattern appears strongest.',
      uncertainty: 'Only journaled experiences are represented.',
    );
  }

  static bool _hasPeriodEvidence(GraphNode node, _DashboardBounds bounds) =>
      node.evidence.any((item) => _inBounds(item.observedAt, bounds));

  static bool _inBounds(DateTime value, _DashboardBounds bounds) =>
      !value.isBefore(bounds.start) && value.isBefore(bounds.end);

  static double _sentiment(String text) {
    final normalized = normalizeGraphLabel(text);
    const positive = ['calm', 'good', 'happy', 'consistent', 'energized'];
    const negative = ['hard', 'stuck', 'failed', 'frustrated', 'tired'];
    final up = positive.where(normalized.contains).length;
    final down = negative.where(normalized.contains).length;
    return (up - down) / ((up + down).clamp(1, 100));
  }

  static _DashboardBounds _bounds(TimeHorizon horizon, DateTime now) {
    final start = switch (horizon) {
      TimeHorizon.today => DateTime.utc(now.year, now.month, now.day),
      TimeHorizon.thisMonth => DateTime.utc(now.year, now.month),
      TimeHorizon.thisYear => DateTime.utc(now.year),
    };
    final end = switch (horizon) {
      TimeHorizon.today => start.add(const Duration(days: 1)),
      TimeHorizon.thisMonth => DateTime.utc(now.year, now.month + 1),
      TimeHorizon.thisYear => DateTime.utc(now.year + 1),
    };
    return (start: start, end: end);
  }
}

typedef _DashboardBounds = ({DateTime start, DateTime end});
