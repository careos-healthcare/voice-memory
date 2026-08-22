import 'package:archiveme_mobile/features/insights/insight_evidence.dart';

enum BeliefEvolutionDirection {
  strengthening,
  weakening,
  emerging,
  disappearing,
}

class BeliefConfidencePoint {
  const BeliefConfidencePoint({
    required this.at,
    required this.confidence,
    required this.evidenceCount,
  });

  final DateTime at;
  final int confidence;
  final int evidenceCount;
}

class TrackedBeliefRecord {
  const TrackedBeliefRecord({
    required this.beliefId,
    required this.statement,
    required this.firstSeen,
    required this.lastSeen,
    required this.evidenceCount,
    required this.confidenceHistory,
    required this.supportingReflectionIds,
  });

  final String beliefId;
  final String statement;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final int evidenceCount;
  final List<BeliefConfidencePoint> confidenceHistory;
  final List<String> supportingReflectionIds;
}

class BeliefEvolutionInsight {
  const BeliefEvolutionInsight({
    required this.id,
    required this.beliefId,
    required this.statement,
    required this.direction,
    required this.summary,
    required this.confidence,
    required this.evidenceCount,
    required this.supportingEvidence,
    required this.record,
  });

  final String id;
  final String beliefId;
  final String statement;
  final BeliefEvolutionDirection direction;
  final String summary;
  final int confidence;
  final int evidenceCount;
  final List<InsightEvidenceLine> supportingEvidence;
  final TrackedBeliefRecord record;
}