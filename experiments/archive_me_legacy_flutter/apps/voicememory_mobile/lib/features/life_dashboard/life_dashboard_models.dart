import '../../features/ai_engines/models/ai_explainability.dart';
import '../../features/explainable_conclusion/explainable_conclusion.dart';

enum TimeHorizon { today, thisMonth, thisYear }

extension TimeHorizonLabels on TimeHorizon {
  String get label => switch (this) {
    TimeHorizon.today => 'Today',
    TimeHorizon.thisMonth => 'This Month',
    TimeHorizon.thisYear => 'This Year',
  };
}

class IdentityDimension {
  const IdentityDimension({
    required this.coreBeliefs,
    required this.selfPerceptionShifts,
    required this.nodeIds,
    this.explainability,
  });

  final List<String> coreBeliefs;
  final List<String> selfPerceptionShifts;
  final Set<String> nodeIds;
  final AiExplainability? explainability;
}

class HabitTracker {
  const HabitTracker({
    required this.nodeId,
    required this.label,
    required this.mentionCount,
    required this.sentiment,
    required this.frictionPoints,
    required this.consistencyVelocity,
  });

  final String nodeId;
  final String label;
  final int mentionCount;
  final double sentiment;
  final List<String> frictionPoints;
  final double consistencyVelocity;
}

class RelationshipPulse {
  const RelationshipPulse({
    required this.personNodeId,
    required this.personLabel,
    required this.valenceTrend,
    required this.recentTouchpoints,
    required this.lastInteractionAt,
  });

  final String personNodeId;
  final String personLabel;
  final double valenceTrend;
  final int recentTouchpoints;
  final DateTime lastInteractionAt;
}

class GoalProgress {
  const GoalProgress({
    required this.nodeId,
    required this.label,
    required this.statedIntentions,
    required this.actualMentions,
    required this.momentum,
    this.explainability,
  });

  final String nodeId;
  final String label;
  final int statedIntentions;
  final int actualMentions;
  final double momentum;
  final AiExplainability? explainability;
}

class PredictiveHorizon {
  const PredictiveHorizon({
    required this.nodeId,
    required this.statement,
    required this.category,
    required this.probability,
    required this.explainability,
  });

  final String nodeId;
  final String statement;
  final String category;
  final double probability;
  final AiExplainability explainability;
}

class LocalDailyPulse {
  const LocalDailyPulse({
    required this.immediateActionItems,
    required this.activeHabitTallies,
    required this.goalMentionFrequencies,
    required this.emotionalVelocity,
  });

  final List<String> immediateActionItems;
  final Map<String, int> activeHabitTallies;
  final Map<String, int> goalMentionFrequencies;
  final double emotionalVelocity;
}

class DashboardSynthesizedPayload {
  const DashboardSynthesizedPayload({
    this.identity,
    this.goals = const [],
    this.predictions = const [],
  });

  final IdentityDimension? identity;
  final List<GoalProgress> goals;
  final List<PredictiveHorizon> predictions;

  factory DashboardSynthesizedPayload.fromApiJson(Map<String, dynamic> json) {
    final identityConclusion = ExplainableConclusion.fromJson(json['identity']);
    if (json['identity'] != null &&
        (identityConclusion == null || !_isStrictV4(identityConclusion))) {
      throw const FormatException('Dashboard identity must be strict V4.');
    }
    final goals = _parseConclusions(json['goals'], 'goals')
        .map(
          (item) => GoalProgress(
            nodeId: item.id,
            label: item.statement,
            statedIntentions: item.evidence.length,
            actualMentions: item.evidence.length,
            momentum: item.confidence / 100,
            explainability: _toAiExplainability(item),
          ),
        )
        .toList();
    final predictions = _parseConclusions(json['predictions'], 'predictions')
        .map(
          (item) => PredictiveHorizon(
            nodeId: item.id,
            statement: item.statement,
            category: 'Cloud trajectory synthesis',
            probability: item.confidence / 100,
            explainability: _toAiExplainability(item),
          ),
        )
        .toList();
    return DashboardSynthesizedPayload(
      identity: identityConclusion != null && _isStrictV4(identityConclusion)
          ? IdentityDimension(
              coreBeliefs: [identityConclusion.statement],
              selfPerceptionShifts: const [],
              nodeIds: const {},
              explainability: _toAiExplainability(identityConclusion),
            )
          : null,
      goals: goals,
      predictions: predictions,
    );
  }

  static List<ExplainableConclusion> _parseConclusions(
    Object? value,
    String field,
  ) {
    if (value is! List) {
      throw FormatException('Dashboard $field must be a list.');
    }
    final parsed = value.map(ExplainableConclusion.fromJson).toList();
    if (parsed.any((item) => item == null || !_isStrictV4(item))) {
      throw FormatException('Dashboard $field must contain strict V4 data.');
    }
    return parsed.cast<ExplainableConclusion>();
  }

  static bool _isStrictV4(ExplainableConclusion conclusion) =>
      !conclusion.isLegacy &&
      conclusion.provenance.schemaVersion ==
          ExplainableConclusion.schemaVersion;

  static AiExplainability _toAiExplainability(
    ExplainableConclusion conclusion,
  ) => AiExplainability(
    confidence: conclusion.confidence,
    evidence: conclusion.evidence
        .map(
          (citation) => VerifiableCitation(
            sourceEntryId: citation.entryId,
            exactQuote: citation.quote,
            audioTimestampMs: citation.audioTimestampMs,
            confidenceScore: citation.confidenceScore,
            startUtf16: citation.startUtf16,
            endUtf16: citation.endUtf16,
          ),
        )
        .toList(),
    reasoning: conclusion.reasoning,
    alternativeExplanation: conclusion.alternativeExplanation.statement,
    uncertainty: conclusion.uncertainty,
    theoryId: conclusion.theoryId ?? conclusion.id,
    evolutionHistory: conclusion.evolutionHistory,
  );
}

class LifeDashboardSnapshot {
  const LifeDashboardSnapshot({
    required this.horizon,
    required this.generatedAt,
    required this.identity,
    required this.dailyPulse,
    required this.habits,
    required this.relationships,
    required this.goals,
    required this.predictions,
    required this.localSemanticMatches,
    required this.usedCloudSynthesis,
  });

  final TimeHorizon horizon;
  final DateTime generatedAt;
  final IdentityDimension identity;
  final LocalDailyPulse dailyPulse;
  final List<HabitTracker> habits;
  final List<RelationshipPulse> relationships;
  final List<GoalProgress> goals;
  final List<PredictiveHorizon> predictions;
  final int localSemanticMatches;
  final bool usedCloudSynthesis;
}
