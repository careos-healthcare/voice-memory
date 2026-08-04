/// Fixed beta failure mode identifiers — no free text.
abstract final class BetaFeedbackIssueIds {
  BetaFeedbackIssueIds._();

  static const unclearPromise = 'unclear_promise';
  static const firstMomentBlocked = 'first_moment_blocked';
  static const activationDropoff = 'activation_dropoff';
  static const repetitiveLoop = 'repetitive_loop';
  static const weakAlternative = 'weak_alternative';
  static const paidSignalReady = 'paid_signal_ready';
  static const quickCaptureStillWork = 'quick_capture_still_work';

  static const all = [
    unclearPromise,
    firstMomentBlocked,
    activationDropoff,
    repetitiveLoop,
    weakAlternative,
    paidSignalReady,
    quickCaptureStillWork,
  ];
}

/// Engine inputs — local counts and flags only.
class BetaFeedbackResponseInput {
  const BetaFeedbackResponseInput({
    required this.capacityWedgeActive,
    required this.capacityMomentCount,
    required this.activationTarget,
    required this.fitIsPositive,
    required this.fitIsUnclear,
    required this.fitNotAnswered,
    required this.pullReasonRecordCount,
    required this.outcomeRecordCount,
    required this.laterCostRecordCount,
    required this.weeklyReviewAvailable,
    required this.boundaryResponseSelected,
    required this.boundaryResponseCopied,
    required this.proInterestCaptured,
    required this.paidIntentStrongWtp,
    required this.paidIntentSoftWtp,
    required this.dailyChangeAvailable,
    required this.dailyChangeDismissed,
    required this.quickCaptureFrictionStillWork,
  });

  final bool capacityWedgeActive;
  final int capacityMomentCount;
  final int activationTarget;
  final bool fitIsPositive;
  final bool fitIsUnclear;
  final bool fitNotAnswered;
  final int pullReasonRecordCount;
  final int outcomeRecordCount;
  final int laterCostRecordCount;
  final bool weeklyReviewAvailable;
  final bool boundaryResponseSelected;
  final bool boundaryResponseCopied;
  final bool proInterestCaptured;
  final bool paidIntentStrongWtp;
  final bool paidIntentSoftWtp;
  final bool dailyChangeAvailable;
  final bool dailyChangeDismissed;
  final bool quickCaptureFrictionStillWork;
}

/// Local beta response recommendation — fixed copy only.
class BetaFeedbackResponseResult {
  const BetaFeedbackResponseResult({
    required this.hasRecommendation,
    required this.issueId,
    required this.localBetaSignalLabel,
    required this.suggestedNextFixLabel,
    required this.recommendedResponseSummary,
    required this.productProblemSummary,
    required this.whatToChangeSummary,
    required this.whatNotToChangeSummary,
    required this.successSignalSummary,
  });

  final bool hasRecommendation;
  final String issueId;
  final String localBetaSignalLabel;
  final String suggestedNextFixLabel;
  final String recommendedResponseSummary;
  final String productProblemSummary;
  final String whatToChangeSummary;
  final String whatNotToChangeSummary;
  final String successSignalSummary;

  static const hidden = BetaFeedbackResponseResult(
    hasRecommendation: false,
    issueId: '',
    localBetaSignalLabel: 'Not enough evidence yet',
    suggestedNextFixLabel: '',
    recommendedResponseSummary: '',
    productProblemSummary: '',
    whatToChangeSummary: '',
    whatNotToChangeSummary: '',
    successSignalSummary: '',
  );
}
