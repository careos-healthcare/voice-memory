import '../beta_feedback/beta_feedback_models.dart';
import '../beta_invite/beta_invite_models.dart';
import '../pro_interest/pro_interest_models.dart';

/// Read-only beta validation snapshot — counts and booleans only.
class BetaOutcomesSnapshot {
  const BetaOutcomesSnapshot({
    required this.savedMomentCount,
    required this.usableEvidenceCount,
    required this.depthLevelLabel,
    required this.watchThemesCount,
    required this.returnRitualSet,
    required this.feedbackStatusLabel,
    required this.optionalNotePresent,
    required this.testimonialCopied,
    required this.shareProofReady,
    required this.interpretations,
    required this.feedbackState,
    required this.proInterestCaptured,
    required this.selectedProValueCount,
    required this.proInterestPricingLabel,
    required this.proInterestNotePresent,
    required this.proInterestInterpretations,
    required this.proInterestState,
    required this.betaInviteCopiedCount,
    required this.betaInviteLastVariantLabel,
    required this.betaInviteTaskCopied,
    required this.firstWeekPathProgressLabel,
    required this.archiveClarityStageLabel,
    required this.thenVsNowAvailableLabel,
    required this.archiveCalendarAvailableLabel,
    required this.insightFeedbackCapturedLabel,
    required this.milestoneShareCountLabel,
  });

  final int savedMomentCount;
  final int usableEvidenceCount;
  final String depthLevelLabel;
  final int watchThemesCount;
  final bool returnRitualSet;
  final String feedbackStatusLabel;
  final bool optionalNotePresent;
  final bool testimonialCopied;
  final bool shareProofReady;
  final List<String> interpretations;
  final BetaFeedbackState feedbackState;
  final bool proInterestCaptured;
  final int selectedProValueCount;
  final String proInterestPricingLabel;
  final bool proInterestNotePresent;
  final List<String> proInterestInterpretations;
  final ProInterestState proInterestState;
  final int betaInviteCopiedCount;
  final String betaInviteLastVariantLabel;
  final bool betaInviteTaskCopied;
  final String firstWeekPathProgressLabel;
  final String archiveClarityStageLabel;
  final String thenVsNowAvailableLabel;
  final String archiveCalendarAvailableLabel;
  final String insightFeedbackCapturedLabel;
  final String milestoneShareCountLabel;
}

/// Local inputs for deterministic beta outcomes — metadata only.
class BetaOutcomesInput {
  const BetaOutcomesInput({
    required this.savedMomentCount,
    required this.usableEvidenceCount,
    required this.depthLevelLabel,
    required this.watchThemesCount,
    required this.returnRitualSet,
    required this.feedbackState,
    required this.shareProofReady,
    required this.proInterestState,
    this.betaInviteCopyStats = BetaInviteCopyStats.empty,
    this.firstWeekPathProgressLabel = '',
    this.archiveClarityStageLabel = '',
    this.thenVsNowAvailableLabel = '',
    this.archiveCalendarAvailableLabel = '',
    this.insightFeedbackCapturedLabel = '',
    this.milestoneShareCountLabel = '',
  });

  final int savedMomentCount;
  final int usableEvidenceCount;
  final String depthLevelLabel;
  final int watchThemesCount;
  final bool returnRitualSet;
  final BetaFeedbackState feedbackState;
  final bool shareProofReady;
  final ProInterestState proInterestState;
  final BetaInviteCopyStats betaInviteCopyStats;
  final String firstWeekPathProgressLabel;
  final String archiveClarityStageLabel;
  final String thenVsNowAvailableLabel;
  final String archiveCalendarAvailableLabel;
  final String insightFeedbackCapturedLabel;
  final String milestoneShareCountLabel;
}
