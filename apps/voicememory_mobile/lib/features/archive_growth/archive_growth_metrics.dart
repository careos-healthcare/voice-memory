import 'archive_confidence_engine.dart';

/// V1 growth metrics derived from [ArchiveConfidenceEngine] and [ArchiveGrowthMaturity].
class ArchiveGrowthMetrics {
  const ArchiveGrowthMetrics({
    required this.confidencePercent,
    required this.evidenceCount,
    required this.maturityLabel,
    required this.explanation,
  });

  final int confidencePercent;
  final int evidenceCount;
  final String maturityLabel;
  final String explanation;

  factory ArchiveGrowthMetrics.fromConfidenceView(ArchiveConfidenceView view) {
    return ArchiveGrowthMetrics(
      confidencePercent: view.score,
      evidenceCount: view.maturity.recordingCount,
      maturityLabel: view.maturity.label,
      explanation: view.explanation,
    );
  }
}
