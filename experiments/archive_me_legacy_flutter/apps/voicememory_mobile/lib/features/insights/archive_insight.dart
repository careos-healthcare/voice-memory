import 'insight_evidence.dart';
import '../ai_engines/models/ai_explainability.dart';

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

  AiExplainability get explainability => AiExplainability(
    confidence: confidence.clamp(0, 100),
    evidence: supportingEvidence.isEmpty
        ? [AiEvidenceSource(sourceId: id, excerpt: title)]
        : supportingEvidence
              .map(
                (item) => AiEvidenceSource(
                  sourceId: item.entryId,
                  excerpt: item.quote,
                ),
              )
              .toList(),
    reasoning: [
      summary,
      archiveConclusion ??
          'No broader conclusion was added beyond the summary.',
      'The confidence score reflects $evidenceCount supporting moments.',
    ],
    alternativeExplanation:
        'The pattern may reflect a temporary circumstance rather than a '
        'stable part of your archive.',
    uncertainty: evidenceCount < 3
        ? 'Only a small number of saved moments support this conclusion.'
        : 'Unrecorded context or experiences could change this interpretation.',
  );
}

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
