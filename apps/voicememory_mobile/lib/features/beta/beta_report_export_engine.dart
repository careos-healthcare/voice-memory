import '../activation/activation_dropoff_review_engine.dart';
import 'beta_activation_loop_counts.dart';
import 'beta_metrics_decision_engine.dart';
import 'beta_metrics_decision_model.dart';
import 'beta_report_export_copy.dart';
import 'beta_report_export_model.dart';
import 'core_value_feedback_store.dart';
import 'proof_of_value_engine.dart';

/// Builds a clipboard-safe beta report from local diagnostics inputs only.
abstract final class BetaReportExportEngine {
  BetaReportExportEngine._();

  static BetaReportExport build({
    BetaActivationLoopCounts? betaCounts,
  }) {
    final counters = ActivationDropoffReviewEngine.fromBetaCounts(betaCounts);
    final metricsInput = BetaMetricsDecisionEngine.fromBetaCounts(
      betaCounts: betaCounts,
    );
    final metricsReport = BetaMetricsDecisionEngine.build(input: metricsInput);
    final proofReport = ProofOfValueEngine.build(
      input: ProofOfValueEngine.fromBetaCounts(betaCounts: betaCounts),
    );

    return BetaReportExport(
      title: BetaReportExportCopy.reportTitle,
      appOpened: counters.appOpened,
      firstMomentSaved: counters.firstMomentSaved,
      secondMomentSaved: counters.secondMomentSaved,
      firstProofReached: counters.firstProofReached,
      returnCheckAnswered: counters.returnCheckAnswered,
      proTapped: counters.proTapped,
      coreValueLocalAnswer: CoreValueFeedbackStore.cached.diagnosticsSummary,
      proofOfValueSummary: proofReport.summary,
      proofOfValueRecommendation: proofReport.recommendation,
      decisionBottleneck: metricsReport.summary,
      decisionFixArea: _fixAreaFor(metricsReport),
      manualQuestions: BetaReportExportCopy.manualQuestions,
    );
  }

  static String _fixAreaFor(BetaMetricsDecisionReport report) {
    final rowId = switch (report.primaryBottleneck) {
      BetaMetricsDecisionBottleneck.notEnoughData =>
        BetaMetricsDecisionRowId.firstSave,
      BetaMetricsDecisionBottleneck.firstScreen =>
        BetaMetricsDecisionRowId.firstSave,
      BetaMetricsDecisionBottleneck.returnLoop =>
        BetaMetricsDecisionRowId.secondSave,
      BetaMetricsDecisionBottleneck.firstProofActivation =>
        BetaMetricsDecisionRowId.firstProof,
      BetaMetricsDecisionBottleneck.evidenceSpecificity =>
        BetaMetricsDecisionRowId.specificProof,
      BetaMetricsDecisionBottleneck.retention =>
        BetaMetricsDecisionRowId.wouldContinue,
      BetaMetricsDecisionBottleneck.monetisation =>
        BetaMetricsDecisionRowId.wouldPay,
      BetaMetricsDecisionBottleneck.healthy =>
        BetaMetricsDecisionRowId.firstProof,
    };

    return report.rows
        .firstWhere((row) => row.id == rowId)
        .fixArea;
  }
}
