import 'package:archiveme_mobile/features/belief_evidence/insight_evidence_line.dart';

/// Unified insight surfaced on Archive and Beliefs surfaces.
enum ArchiveInsightType {
  belief,
  contradiction,
  blindSpot,
  evolution,
  prediction,
}

class ArchiveInsight {
  const ArchiveInsight({
    required this.id,
    required this.type,
    required this.title,
    required this.summary,
    required this.confidence,
    required this.evidenceCount,
    required this.supportingEvidence,
    required this.createdAt,
    this.whyItMatters,
    this.archiveConclusion,
  });

  final String id;
  final ArchiveInsightType type;
  final String title;
  final String summary;
  final int confidence;
  final int evidenceCount;
  final List<InsightEvidenceLine> supportingEvidence;
  final DateTime createdAt;
  final String? whyItMatters;
  final String? archiveConclusion;

  String get what => title;
  String get why => summary;
}

/// Aggregated insight engines output for archive and return surfaces.
class ArchiveInsightsSnapshot {
  const ArchiveInsightsSnapshot({
    required this.strongestBelief,
    required this.contradictions,
    required this.evolution,
    required this.blindSpots,
    required this.predictions,
    required this.allInsights,
  });

  final ArchiveInsight? strongestBelief;
  final List<ArchiveInsight> contradictions;
  final List<ArchiveInsight> evolution;
  final List<ArchiveInsight> blindSpots;
  final List<ArchiveInsight> predictions;
  final List<ArchiveInsight> allInsights;

  static const empty = ArchiveInsightsSnapshot(
    strongestBelief: null,
    contradictions: [],
    evolution: [],
    blindSpots: [],
    predictions: [],
    allInsights: [],
  );
}
