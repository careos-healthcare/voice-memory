import '../../core/graph/graph_node.dart';
import '../../core/graph/personal_knowledge_graph.dart';
import '../../services/ai/local_semantic_store.dart';
import '../ai_engines/models/ai_explainability.dart';
import '../relationships/relationship_graph_models.dart';
import 'weekly_intelligence_models.dart';

class WeeklyDeltaEngine {
  const WeeklyDeltaEngine({
    required this.graph,
    required this.semanticStore,
    this.clock = DateTime.now,
    this.baselineWeeks = 3,
  });

  final PersonalKnowledgeGraph graph;
  final LocalSemanticStore semanticStore;
  final DateTime Function() clock;
  final int baselineWeeks;

  Future<WeeklyIntelligenceSnapshot> aggregate() async {
    final now = clock().toUtc();
    final weekStart = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - DateTime.monday));
    final weekEnd = weekStart.add(const Duration(days: 7));
    final baselineStart = weekStart.subtract(Duration(days: 7 * baselineWeeks));
    final periodEntryIds = graph.nodes
        .expand((node) => node.evidence)
        .where(
          (item) =>
              !item.observedAt.isBefore(baselineStart) &&
              item.observedAt.isBefore(weekEnd),
        )
        .map((item) => item.entryId)
        .toSet();
    final hits = await semanticStore.search(
      'behavioral change actions habits emotions relationships identity',
      limit: 100,
    );
    final deltas = <BehavioralDelta>[
      ..._actionIntent(weekStart, weekEnd, baselineStart),
      ..._emotion(weekStart, weekEnd, baselineStart),
      ..._habits(weekStart, weekEnd, baselineStart),
      ..._relationships(weekStart, weekEnd, baselineStart),
      ..._identity(weekStart, weekEnd, baselineStart),
    ];
    deltas.sort((a, b) => b.magnitude.abs().compareTo(a.magnitude.abs()));
    return WeeklyIntelligenceSnapshot(
      weekStart: weekStart,
      weekEnd: weekEnd,
      baselineWeekCount: baselineWeeks,
      deltas: List.unmodifiable(deltas),
      localSemanticMatches: hits
          .where((hit) => periodEntryIds.contains(hit.entryId))
          .length,
      generatedAt: now,
    );
  }

  List<BehavioralDelta> _actionIntent(
    DateTime currentStart,
    DateTime currentEnd,
    DateTime baselineStart,
  ) {
    final baselineIntents = _nodeEvidence(
      {NodeType.goal, NodeType.promise},
      baselineStart,
      currentStart,
    );
    final currentActions = _nodeEvidence(
      {NodeType.actionItem},
      currentStart,
      currentEnd,
    );
    if (baselineIntents.isEmpty || currentActions.isEmpty) return const [];
    final ratio = currentActions.length / baselineIntents.length;
    final magnitude = ratio - 1;
    return [
      ActionIntentRatio(
        id: 'weekly-action-intent',
        title: 'Intent moved toward action',
        statement:
            '${currentActions.length} verified action mentions followed '
            '${baselineIntents.length} earlier intentions.',
        magnitude: magnitude,
        direction: _direction(magnitude),
        nodeIds: {
          ...baselineIntents.map((item) => item.node.id),
          ...currentActions.map((item) => item.node.id),
        },
        explainability: _pairedExplainability(
          baselineIntents.first.evidence,
          currentActions.first.evidence,
          'Compared earlier stated intentions with this week’s reported actions.',
        ),
        baselineIntentCount: baselineIntents.length,
        currentActionCount: currentActions.length,
        executionRatio: ratio,
      ),
    ];
  }

  List<BehavioralDelta> _emotion(
    DateTime currentStart,
    DateTime currentEnd,
    DateTime baselineStart,
  ) {
    final baseline = _nodeEvidence(
      {NodeType.emotion},
      baselineStart,
      currentStart,
    );
    final current = _nodeEvidence({NodeType.emotion}, currentStart, currentEnd);
    if (baseline.isEmpty || current.isEmpty) return const [];
    final baselineTone = _averageTone(baseline);
    final currentTone = _averageTone(current);
    final magnitude = currentTone - baselineTone;
    return [
      EmotionalVelocity(
        id: 'weekly-emotional-velocity',
        title: 'Emotional velocity',
        statement:
            'Recorded emotional tone ${magnitude >= 0 ? 'rose' : 'fell'} '
            'by ${(magnitude.abs() * 100).round()}%.',
        magnitude: magnitude,
        direction: _direction(magnitude),
        nodeIds: {
          ...baseline.map((item) => item.node.id),
          ...current.map((item) => item.node.id),
        },
        explainability: _pairedExplainability(
          baseline.first.evidence,
          current.first.evidence,
          'Compared emotion evidence from baseline weeks with this week.',
        ),
        baselineTone: baselineTone,
        currentTone: currentTone,
      ),
    ];
  }

  List<BehavioralDelta> _habits(
    DateTime currentStart,
    DateTime currentEnd,
    DateTime baselineStart,
  ) {
    final result = <BehavioralDelta>[];
    for (final node in graph.nodes.where(
      (node) => node.type == NodeType.habit,
    )) {
      final baseline = node.evidence
          .where(
            (item) => _inRange(item.observedAt, baselineStart, currentStart),
          )
          .toList();
      final current = node.evidence
          .where((item) => _inRange(item.observedAt, currentStart, currentEnd))
          .toList();
      if (baseline.isEmpty || current.isEmpty) continue;
      final weeklyBaseline = baseline.length / baselineWeeks;
      final magnitude = current.length - weeklyBaseline;
      result.add(
        HabitDrift(
          id: 'weekly-habit-${node.id}',
          title: '${node.label} momentum',
          statement:
              '${node.label} moved from ${weeklyBaseline.toStringAsFixed(1)} '
              'baseline mentions to ${current.length} this week.',
          magnitude: magnitude,
          direction: _direction(magnitude),
          nodeIds: {node.id},
          explainability: _pairedExplainability(
            baseline.last,
            current.last,
            'Compared weekly mention frequency for the same routine.',
          ),
          habitLabel: node.label,
          baselineWeeklyMentions: weeklyBaseline,
          currentMentions: current.length,
          frictionPoints: current
              .where(
                (item) => RegExp(
                  r'\b(?:hard|stuck|missed|difficult|friction)\b',
                  caseSensitive: false,
                ).hasMatch(item.excerpt),
              )
              .map((item) => item.excerpt)
              .toList(),
        ),
      );
    }
    return result;
  }

  List<BehavioralDelta> _relationships(
    DateTime currentStart,
    DateTime currentEnd,
    DateTime baselineStart,
  ) {
    final result = <BehavioralDelta>[];
    for (final person in graph.nodes.where(
      (node) => node.type == NodeType.person,
    )) {
      final interactions = RelationshipGraphSnapshot.forPerson(
        graph,
        person,
      ).interactions;
      final baseline = interactions
          .where(
            (item) => _inRange(item.occurredAt, baselineStart, currentStart),
          )
          .toList();
      final current = interactions
          .where((item) => _inRange(item.occurredAt, currentStart, currentEnd))
          .toList();
      if (baseline.isEmpty || current.isEmpty) continue;
      final baselineValence =
          baseline
              .map((item) => item.emotionalValenceScore)
              .reduce((a, b) => a + b) /
          baseline.length;
      final currentValence =
          current
              .map((item) => item.emotionalValenceScore)
              .reduce((a, b) => a + b) /
          current.length;
      final valenceDelta = currentValence - baselineValence;
      final frequencyDelta = current.length - baseline.length / baselineWeeks;
      result.add(
        RelationshipDynamicsDelta(
          id: 'weekly-relationship-${person.id}',
          title: '${person.label} relationship drift',
          statement:
              'Interaction frequency changed by '
              '${frequencyDelta.toStringAsFixed(1)} and emotional valence by '
              '${valenceDelta.toStringAsFixed(2)}.',
          magnitude: valenceDelta.abs() >= .1 ? valenceDelta : frequencyDelta,
          direction: _direction(
            valenceDelta.abs() >= .1 ? valenceDelta : frequencyDelta,
          ),
          nodeIds: {
            person.id,
            ...baseline.map((item) => item.interaction.id),
            ...current.map((item) => item.interaction.id),
          },
          explainability: _pairedExplainability(
            baseline.last.evidence.last,
            current.last.evidence.last,
            'Compared interaction frequency and valence around the same person.',
          ),
          personLabel: person.label,
          frequencyDelta: frequencyDelta,
          valenceDelta: valenceDelta,
        ),
      );
    }
    return result;
  }

  List<BehavioralDelta> _identity(
    DateTime currentStart,
    DateTime currentEnd,
    DateTime baselineStart,
  ) {
    final baseline = _nodeEvidence(
      {NodeType.belief, NodeType.identityShift},
      baselineStart,
      currentStart,
    )..sort((a, b) => a.evidence.observedAt.compareTo(b.evidence.observedAt));
    final current = _nodeEvidence(
      {NodeType.belief, NodeType.identityShift},
      currentStart,
      currentEnd,
    )..sort((a, b) => a.evidence.observedAt.compareTo(b.evidence.observedAt));
    if (baseline.isEmpty || current.isEmpty) return const [];
    final before = baseline.last;
    final after = current.last;
    if (normalizeGraphLabel(before.node.label) ==
        normalizeGraphLabel(after.node.label)) {
      return const [];
    }
    return [
      IdentityShiftDelta(
        id: 'weekly-identity-shift',
        title: 'Self-perception shifted',
        statement: '${before.node.label} → ${after.node.label}',
        magnitude: .5,
        direction: DeltaDirection.shifted,
        nodeIds: {before.node.id, after.node.id},
        explainability: _pairedExplainability(
          before.evidence,
          after.evidence,
          'Contrasted earlier and current self-descriptions.',
        ),
        previousBelief: before.node.label,
        currentBelief: after.node.label,
      ),
    ];
  }

  List<({GraphNode node, GraphNodeEvidence evidence})> _nodeEvidence(
    Set<NodeType> types,
    DateTime start,
    DateTime end,
  ) => [
    for (final node in graph.nodes.where((node) => types.contains(node.type)))
      for (final evidence in node.evidence)
        if (_inRange(evidence.observedAt, start, end))
          (node: node, evidence: evidence),
  ];

  static AiExplainability _pairedExplainability(
    Object baseline,
    Object current,
    String reason,
  ) {
    final before = _slice(baseline);
    final after = _slice(current);
    return AiExplainability(
      confidence: ((before.confidence + after.confidence) * 50).round(),
      evidence: [_citation(before), _citation(after)],
      reasoning: [reason],
      alternativeExplanation:
          'Recording frequency or omitted context may explain part of the change.',
      uncertainty:
          'Only recorded moments in the selected week windows are represented.',
    );
  }

  static _EvidenceSlice _slice(Object evidence) => switch (evidence) {
    GraphNodeEvidence item => _EvidenceSlice(
      entryId: item.entryId,
      excerpt: item.excerpt,
      confidence: item.confidence,
      startUtf16: item.startUtf16,
      endUtf16: item.endUtf16,
    ),
    GraphEdgeEvidence item => _EvidenceSlice(
      entryId: item.entryId,
      excerpt: item.excerpt,
      confidence: item.confidence,
      startUtf16: item.startUtf16,
      endUtf16: item.endUtf16,
    ),
    _ => throw ArgumentError.value(evidence, 'evidence'),
  };

  static VerifiableCitation _citation(_EvidenceSlice evidence) =>
      VerifiableCitation(
        sourceEntryId: evidence.entryId,
        exactQuote: evidence.excerpt,
        confidenceScore: evidence.confidence,
        startUtf16: evidence.startUtf16,
        endUtf16: evidence.endUtf16,
      );

  static double _averageTone(
    List<({GraphNode node, GraphNodeEvidence evidence})> values,
  ) =>
      values.map((item) => _tone(item.node.label)).reduce((a, b) => a + b) /
      values.length;

  static double _tone(String value) {
    final text = normalizeGraphLabel(value);
    const positive = ['calm', 'happy', 'hopeful', 'energized', 'relieved'];
    const negative = [
      'overwhelm',
      'anxious',
      'angry',
      'frustrated',
      'sad',
      'tired',
    ];
    final up = positive.where(text.contains).length;
    final down = negative.where(text.contains).length;
    return ((up - down) / (up + down).clamp(1, 20)).toDouble();
  }

  static DeltaDirection _direction(double value) {
    if (value > .05) return DeltaDirection.increased;
    if (value < -.05) return DeltaDirection.decreased;
    return DeltaDirection.stable;
  }

  static bool _inRange(DateTime value, DateTime start, DateTime end) =>
      !value.isBefore(start) && value.isBefore(end);
}

class _EvidenceSlice {
  const _EvidenceSlice({
    required this.entryId,
    required this.excerpt,
    required this.confidence,
    required this.startUtf16,
    required this.endUtf16,
  });

  final String entryId;
  final String excerpt;
  final double confidence;
  final int startUtf16;
  final int endUtf16;
}
