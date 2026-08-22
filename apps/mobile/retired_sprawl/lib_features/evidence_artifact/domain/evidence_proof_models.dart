import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';

/// One verbatim cite pulled from the fact ledger / journal trail.
class EvidenceProofCitation {
  const EvidenceProofCitation({
    required this.entryId,
    required this.quote,
    required this.recordedAt,
  });

  final String entryId;
  final String quote;
  final DateTime recordedAt;
}

/// Aggregated occurrence math for a belief or insight.
class EvidenceProofStats {
  const EvidenceProofStats({
    required this.totalFrequency,
    required this.spanDays,
    required this.timespanLabel,
    required this.frequencyBadgeLabel,
    required this.occurrenceDensityPerWeek,
  });

  final int totalFrequency;
  final int spanDays;
  final String timespanLabel;
  final String frequencyBadgeLabel;
  final double occurrenceDensityPerWeek;
}

/// Screenshot-ready proof payload derived from ledger citations.
class EvidenceProofArtifact {
  const EvidenceProofArtifact({
    required this.subjectTitle,
    required this.confidenceBand,
    required this.stats,
    required this.citations,
    this.confidencePercent,
  });

  final String subjectTitle;
  final PatternMatchConfidenceBand confidenceBand;
  final EvidenceProofStats stats;
  final List<EvidenceProofCitation> citations;
  final int? confidencePercent;

  bool get hasCitations => citations.isNotEmpty;

  String get pngFilename =>
      'archiveme_evidence_proof_${DateTime.now().millisecondsSinceEpoch}.png';
}