import 'monthly_ambition_pressure_review_model.dart';
import 'prove_enough_evidence_trail_model.dart';

/// Saved prove_enough data bundled for Markdown/PDF export.
class ProveEnoughPatternReport {
  const ProveEnoughPatternReport({
    required this.generatedAt,
    required this.trail,
    this.monthlyReview,
    this.rangeStart,
    this.rangeEnd,
  });

  static const reportTitle = 'Proving-Enough Loop Report';
  static const proGateTitle = 'Pattern reports are Pro.';

  static const summarySection = 'Summary';
  static const evidenceTrailSection = 'Evidence trail';
  static const choiceVsPressureSection = 'Choice vs pressure';
  static const restGuiltSection = 'Rest guilt';
  static const triggerMapSection = 'Trigger map';
  static const confirmedSection = 'What confirmed the loop';
  static const challengedSection = 'What challenged the loop';
  static const directionSection =
      'Whether the loop is getting stronger or fading';
  static const nextMissionSection = 'Next evidence mission';

  final DateTime generatedAt;
  final ProveEnoughEvidenceTrail trail;
  final MonthlyAmbitionPressureReview? monthlyReview;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;

  String get nextEvidenceMission {
    final fromTrail = trail.latestMission?.trim();
    if (fromTrail != null && fromTrail.isNotEmpty) return fromTrail;
    final fromReview = monthlyReview?.nextMonthMission.trim();
    if (fromReview != null && fromReview.isNotEmpty) return fromReview;
    return '';
  }

  List<ProveEnoughEvidenceMoment> get allMoments {
    final moments = [
      ...trail.supportingMoments,
      ...trail.contradictionMoments,
      ...trail.restGuiltMoments,
      ...trail.choiceMoments,
    ];
    moments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return moments;
  }

  bool get hasExportableContent =>
      allMoments.isNotEmpty ||
      trail.triggerSummary.trim().isNotEmpty ||
      nextEvidenceMission.isNotEmpty ||
      monthlyReview != null;
}
