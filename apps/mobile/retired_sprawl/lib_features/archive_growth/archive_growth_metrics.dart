import 'package:archiveme_mobile/features/archive_growth/archive_confidence_engine.dart';
import 'package:archiveme_mobile/features/archive_growth/archive_growth_maturity.dart' show ArchiveGrowthMaturity;

/// V1 growth metrics derived from [ArchiveConfidenceEngine] and [ArchiveGrowthMaturity].
class ArchiveGrowthMetrics {
  const ArchiveGrowthMetrics({
    required this.confidencePercent,
    required this.evidenceCount,
    required this.maturityLabel,
    required this.explanation,
  });

  factory ArchiveGrowthMetrics.fromConfidenceView(ArchiveConfidenceView view) {
    return ArchiveGrowthMetrics(
      confidencePercent: view.score,
      evidenceCount: view.maturity.recordingCount,
      maturityLabel: view.maturity.label,
      explanation: view.explanation,
    );
  }

  final int confidencePercent;
  final int evidenceCount;
  final String maturityLabel;
  final String explanation;
}