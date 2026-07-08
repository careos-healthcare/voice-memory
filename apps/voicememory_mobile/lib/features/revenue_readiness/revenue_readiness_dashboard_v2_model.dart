import 'revenue_readiness_dashboard_v2_copy.dart';
import '../beta_decision_rules/beta_decision_rule_model.dart';
import '../revenue_lift_experiment_v2/revenue_lift_experiment_v2_model.dart';

enum RevenueReadinessDashboardV2Status {
  healthy,
  watch,
  failing,
  noData;

  String get label => switch (this) {
        RevenueReadinessDashboardV2Status.healthy =>
          RevenueReadinessDashboardV2Copy.statusHealthy,
        RevenueReadinessDashboardV2Status.watch =>
          RevenueReadinessDashboardV2Copy.statusWatch,
        RevenueReadinessDashboardV2Status.failing =>
          RevenueReadinessDashboardV2Copy.statusFailing,
        RevenueReadinessDashboardV2Status.noData =>
          RevenueReadinessDashboardV2Copy.statusPending,
      };
}

enum RevenueReadinessDashboardV2SectionId {
  capture,
  proof,
  returnFunnel,
  revenue,
  diagnosis,
}

enum RevenueReadinessDashboardV2MetricId {
  firstSave,
  secondSave,
  thirdSave,
  timelineProofSeen,
  useful,
  tooVague,
  alreadyKnew,
  notRelevant,
  negativeCombined,
  returnAfterProof,
  returnPromptSeen,
  returnPromptTapped,
  proBridgeSeen,
  proBridgeCtaTapped,
  paywallSeen,
  paywallCtaTapped,
  purchaseStarted,
  purchaseCompleted,
  restoreAttempted,
  restoreCompleted,
}

enum RevenueReadinessDashboardV2DiagnosisId {
  lowFirstSave,
  lowSecondSave,
  lowThirdSave,
  lowUsefulProof,
  negativeAboveUseful,
  lowReturnAfterProof,
  lowPaywallSeen,
  weakCtaTap,
  purchaseCompletionIssue,
  restoreFailure,
  firstSaveLiftNeeded,
  returnAfterProofLiftNeeded,
  proVisibilityLiftNeeded,
  paywallCtaLiftNeeded,
  firstSessionCaptureWeak,
  proUnderstandingWeak,
}

class RevenueReadinessDashboardV2MetricRow {
  const RevenueReadinessDashboardV2MetricRow({
    required this.id,
    required this.label,
    required this.status,
    required this.valueLabel,
    this.nextActionLabel,
  });

  final RevenueReadinessDashboardV2MetricId id;
  final String label;
  final RevenueReadinessDashboardV2Status status;
  final String valueLabel;
  final String? nextActionLabel;

  bool get hasData => status != RevenueReadinessDashboardV2Status.noData;
}

class RevenueReadinessDashboardV2Section {
  const RevenueReadinessDashboardV2Section({
    required this.id,
    required this.title,
    required this.rows,
  });

  final RevenueReadinessDashboardV2SectionId id;
  final String title;
  final List<RevenueReadinessDashboardV2MetricRow> rows;
}

class RevenueReadinessDashboardV2Diagnosis {
  const RevenueReadinessDashboardV2Diagnosis({
    required this.id,
    required this.title,
    required this.nextActionLabel,
    this.metricLabel,
    this.metricValueLabel,
  });

  final RevenueReadinessDashboardV2DiagnosisId id;
  final String title;
  final String nextActionLabel;
  final String? metricLabel;
  final String? metricValueLabel;
}

class RevenueReadinessDashboardV2Input {
  const RevenueReadinessDashboardV2Input({
    this.recordScreenSeen = 0,
    this.firstMomentSaved = 0,
    this.secondMomentSaved = 0,
    this.thirdMomentSaved = 0,
    this.confirmedRepeatSeen = 0,
    this.timelineProofSeen = 0,
    this.usefulCount = 0,
    this.tooVagueCount = 0,
    this.alreadyKnewCount = 0,
    this.notRelevantCount = 0,
    this.returnedAfterFirstProof = 0,
    this.returnPromptSeen = 0,
    this.returnPromptTapped = 0,
    this.proBridgeSeen = 0,
    this.proBridgeCtaTapped = 0,
    this.paywallSeen = 0,
    this.paywallCtaTapped = 0,
    this.purchaseStarted = 0,
    this.purchaseCompleted = 0,
    this.restoreAttempted = 0,
    this.restoreCompleted = 0,
    this.firstSaveInFirstSession = 0,
    this.firstSessionOpportunities = 0,
    this.understandsProYesMaybe = 0,
    this.understandsProSurveyResponses = 0,
    this.testerCount = 0,
    this.firstSessionSaveCount = 0,
    this.sawProCount = 0,
  });

  final int recordScreenSeen;
  final int firstMomentSaved;
  final int secondMomentSaved;
  final int thirdMomentSaved;
  final int confirmedRepeatSeen;
  final int timelineProofSeen;
  final int usefulCount;
  final int tooVagueCount;
  final int alreadyKnewCount;
  final int notRelevantCount;
  final int returnedAfterFirstProof;
  final int returnPromptSeen;
  final int returnPromptTapped;
  final int proBridgeSeen;
  final int proBridgeCtaTapped;
  final int paywallSeen;
  final int paywallCtaTapped;
  final int purchaseStarted;
  final int purchaseCompleted;
  final int restoreAttempted;
  final int restoreCompleted;
  final int firstSaveInFirstSession;
  final int firstSessionOpportunities;
  final int understandsProYesMaybe;
  final int understandsProSurveyResponses;
  final int testerCount;
  final int firstSessionSaveCount;
  final int sawProCount;

  int get totalFeedbackCount =>
      usefulCount + tooVagueCount + alreadyKnewCount + notRelevantCount;

  int get negativeFeedbackCount =>
      tooVagueCount + alreadyKnewCount + notRelevantCount;
}

class RevenueReadinessDashboardV2Dashboard {
  const RevenueReadinessDashboardV2Dashboard({
    required this.title,
    required this.subtitle,
    required this.liftFocus,
    required this.sections,
    required this.diagnoses,
    required this.decisionRule,
  });

  final String title;
  final String subtitle;
  final RevenueLiftExperimentV2LiftFocus liftFocus;
  final List<RevenueReadinessDashboardV2Section> sections;
  final List<RevenueReadinessDashboardV2Diagnosis> diagnoses;
  final BetaDecisionRuleResult decisionRule;

  List<RevenueReadinessDashboardV2MetricRow> get allRows =>
      sections.expand((section) => section.rows).toList();

  List<String> get allDisplayedText => [
        title,
        subtitle,
        liftFocus.label,
        for (final section in sections) ...[
          section.title,
          for (final row in section.rows) ...[
            row.label,
            row.valueLabel,
            if (row.nextActionLabel != null) row.nextActionLabel!,
            row.status.label,
          ],
        ],
        for (final diagnosis in diagnoses) ...[
          diagnosis.title,
          if (diagnosis.metricLabel != null) diagnosis.metricLabel!,
          if (diagnosis.metricValueLabel != null) diagnosis.metricValueLabel!,
          diagnosis.nextActionLabel,
        ],
        decisionRule.title,
        decisionRule.body,
        decisionRule.reason,
        decisionRule.cta,
        RevenueReadinessDashboardV2Copy.localCountsNote,
      ];

  bool get hasDiagnoses => diagnoses.isNotEmpty;
}
