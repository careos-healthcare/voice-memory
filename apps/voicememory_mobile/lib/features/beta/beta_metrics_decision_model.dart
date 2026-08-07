import 'beta_metrics_decision_copy.dart';

enum BetaMetricsDecisionRowId {
  firstSave,
  secondSave,
  firstProof,
  specificProof,
  wouldContinue,
  wouldPay,
}

enum BetaMetricsDecisionBottleneck {
  notEnoughData,
  firstScreen,
  returnLoop,
  firstProofActivation,
  evidenceSpecificity,
  retention,
  monetisation,
  healthy,
}

enum BetaMetricsDecisionRowStatus {
  ready,
  belowTarget,
  checkManually,
  notEnoughData;

  String get label => switch (this) {
    BetaMetricsDecisionRowStatus.ready => BetaMetricsDecisionCopy.statusReady,
    BetaMetricsDecisionRowStatus.belowTarget =>
      BetaMetricsDecisionCopy.statusBelowTarget,
    BetaMetricsDecisionRowStatus.checkManually =>
      BetaMetricsDecisionCopy.statusCheckManually,
    BetaMetricsDecisionRowStatus.notEnoughData =>
      BetaMetricsDecisionCopy.statusNotEnoughData,
  };
}

/// Local tester funnel counts — automatic and optional qualitative fields.
class BetaMetricsDecisionInput {
  const BetaMetricsDecisionInput({
    this.totalTesters = 0,
    this.firstMomentSaved = 0,
    this.secondMomentSaved = 0,
    this.firstProofReached = 0,
    this.returnCheckAnswered = 0,
    this.proTapped = 0,
    this.proofFeltSpecific,
    this.proofUsefulCount,
    this.wouldKeepUsing,
    this.wouldPay,
  });

  final int totalTesters;
  final int firstMomentSaved;
  final int secondMomentSaved;
  final int firstProofReached;
  final int returnCheckAnswered;
  final int proTapped;
  final int? proofFeltSpecific;
  final int? proofUsefulCount;
  final int? wouldKeepUsing;
  final int? wouldPay;
}

class BetaMetricsDecisionRow {
  const BetaMetricsDecisionRow({
    required this.id,
    required this.metricName,
    required this.currentValue,
    required this.targetValue,
    required this.status,
    required this.fixArea,
    this.problemLabel,
  });

  final BetaMetricsDecisionRowId id;
  final String metricName;
  final String currentValue;
  final String targetValue;
  final BetaMetricsDecisionRowStatus status;
  final String fixArea;
  final String? problemLabel;
}

class BetaMetricsDecisionReport {
  const BetaMetricsDecisionReport({
    required this.title,
    required this.summary,
    required this.primaryBottleneck,
    required this.rows,
    this.coreValueFeedbackLabel,
    this.coreValueFeedbackAnswer,
  });

  final String title;
  final String summary;
  final BetaMetricsDecisionBottleneck primaryBottleneck;
  final List<BetaMetricsDecisionRow> rows;
  final String? coreValueFeedbackLabel;
  final String? coreValueFeedbackAnswer;

  List<String> get visibleCopyBlocks => [
    title,
    summary,
    ?coreValueFeedbackLabel,
    ?coreValueFeedbackAnswer,
    for (final row in rows) ...[
      row.metricName,
      row.currentValue,
      row.targetValue,
      row.status.label,
      row.fixArea,
      if (row.problemLabel != null) row.problemLabel!,
    ],
  ];
}
