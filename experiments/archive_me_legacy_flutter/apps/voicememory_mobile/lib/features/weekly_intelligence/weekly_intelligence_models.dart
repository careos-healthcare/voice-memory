import '../ai_engines/models/ai_explainability.dart';
import '../explainable_conclusion/explainable_conclusion.dart';

enum BehavioralDeltaDimension {
  actionIntentRatio,
  emotionalVelocity,
  habitDrift,
  relationshipDynamics,
  identityShift,
}

enum DeltaDirection { increased, decreased, stable, emerged, faded, shifted }

abstract class BehavioralDelta {
  const BehavioralDelta({
    required this.id,
    required this.title,
    required this.statement,
    required this.magnitude,
    required this.direction,
    required this.nodeIds,
    required this.explainability,
  });

  final String id;
  final String title;
  final String statement;
  final double magnitude;
  final DeltaDirection direction;
  final Set<String> nodeIds;
  final AiExplainability explainability;
  BehavioralDeltaDimension get dimension;
}

class ActionIntentRatio extends BehavioralDelta {
  const ActionIntentRatio({
    required super.id,
    required super.title,
    required super.statement,
    required super.magnitude,
    required super.direction,
    required super.nodeIds,
    required super.explainability,
    required this.baselineIntentCount,
    required this.currentActionCount,
    required this.executionRatio,
  });

  final int baselineIntentCount;
  final int currentActionCount;
  final double executionRatio;

  @override
  BehavioralDeltaDimension get dimension =>
      BehavioralDeltaDimension.actionIntentRatio;
}

class EmotionalVelocity extends BehavioralDelta {
  const EmotionalVelocity({
    required super.id,
    required super.title,
    required super.statement,
    required super.magnitude,
    required super.direction,
    required super.nodeIds,
    required super.explainability,
    required this.baselineTone,
    required this.currentTone,
  });

  final double baselineTone;
  final double currentTone;

  @override
  BehavioralDeltaDimension get dimension =>
      BehavioralDeltaDimension.emotionalVelocity;
}

class HabitDrift extends BehavioralDelta {
  const HabitDrift({
    required super.id,
    required super.title,
    required super.statement,
    required super.magnitude,
    required super.direction,
    required super.nodeIds,
    required super.explainability,
    required this.habitLabel,
    required this.baselineWeeklyMentions,
    required this.currentMentions,
    required this.frictionPoints,
  });

  final String habitLabel;
  final double baselineWeeklyMentions;
  final int currentMentions;
  final List<String> frictionPoints;

  @override
  BehavioralDeltaDimension get dimension => BehavioralDeltaDimension.habitDrift;
}

class RelationshipDynamicsDelta extends BehavioralDelta {
  const RelationshipDynamicsDelta({
    required super.id,
    required super.title,
    required super.statement,
    required super.magnitude,
    required super.direction,
    required super.nodeIds,
    required super.explainability,
    required this.personLabel,
    required this.frequencyDelta,
    required this.valenceDelta,
  });

  final String personLabel;
  final double frequencyDelta;
  final double valenceDelta;

  @override
  BehavioralDeltaDimension get dimension =>
      BehavioralDeltaDimension.relationshipDynamics;
}

class IdentityShiftDelta extends BehavioralDelta {
  const IdentityShiftDelta({
    required super.id,
    required super.title,
    required super.statement,
    required super.magnitude,
    required super.direction,
    required super.nodeIds,
    required super.explainability,
    required this.previousBelief,
    required this.currentBelief,
  });

  final String previousBelief;
  final String currentBelief;

  @override
  BehavioralDeltaDimension get dimension =>
      BehavioralDeltaDimension.identityShift;
}

class WeeklyIntelligenceSnapshot {
  const WeeklyIntelligenceSnapshot({
    required this.weekStart,
    required this.weekEnd,
    required this.baselineWeekCount,
    required this.deltas,
    required this.localSemanticMatches,
    required this.generatedAt,
    this.fromCache = false,
  });

  final DateTime weekStart;
  final DateTime weekEnd;
  final int baselineWeekCount;
  final List<BehavioralDelta> deltas;
  final int localSemanticMatches;
  final DateTime generatedAt;
  final bool fromCache;

  String get weekKey =>
      '${weekStart.year.toString().padLeft(4, '0')}-W'
      '${_isoWeek(weekStart).toString().padLeft(2, '0')}';

  WeeklyIntelligenceSnapshot asCached() => WeeklyIntelligenceSnapshot(
    weekStart: weekStart,
    weekEnd: weekEnd,
    baselineWeekCount: baselineWeekCount,
    deltas: deltas,
    localSemanticMatches: localSemanticMatches,
    generatedAt: generatedAt,
    fromCache: true,
  );

  static int _isoWeek(DateTime value) {
    final thursday = value.add(Duration(days: 4 - value.weekday));
    final firstThursday = DateTime.utc(thursday.year, 1, 4);
    return 1 +
        thursday
                .difference(
                  firstThursday.add(Duration(days: 4 - firstThursday.weekday)),
                )
                .inDays ~/
            7;
  }
}

AiExplainability aiExplainabilityFromV4(ExplainableConclusion conclusion) {
  if (conclusion.isLegacy ||
      conclusion.provenance.schemaVersion !=
          ExplainableConclusion.schemaVersion) {
    throw const FormatException('Weekly intelligence requires strict V4 data.');
  }
  return AiExplainability(
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
