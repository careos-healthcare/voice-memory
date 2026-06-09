import 'monthly_ambition_pressure_review_coordinator.dart';
import 'prove_enough_evidence_trail_coordinator.dart';
import 'prove_enough_pattern_report_model.dart';

/// Loads saved prove_enough data for pattern report export.
abstract final class ProveEnoughPatternReportCoordinator {
  ProveEnoughPatternReportCoordinator._();

  static Future<ProveEnoughPatternReport> load({DateTime? now}) async {
    final generatedAt = now ?? DateTime.now();
    final trail = await ProveEnoughEvidenceTrailCoordinator.load();
    final monthlyReview = await MonthlyAmbitionPressureReviewCoordinator.load(
      now: generatedAt,
    );

    final dates = [
      ...trail.supportingMoments,
      ...trail.contradictionMoments,
      ...trail.restGuiltMoments,
      ...trail.choiceMoments,
    ].map((moment) => moment.createdAt).toList()
      ..sort();

    return ProveEnoughPatternReport(
      generatedAt: generatedAt,
      trail: trail,
      monthlyReview: monthlyReview.hasEnoughData ? monthlyReview : null,
      rangeStart: dates.isEmpty ? null : dates.first,
      rangeEnd: dates.isEmpty ? null : dates.last,
    );
  }
}
