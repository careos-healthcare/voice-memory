/// Copy for the beta conversion diagnosis dashboard.
abstract final class BetaConversionDiagnosisCopy {
  BetaConversionDiagnosisCopy._();

  static const title = 'Beta diagnosis';

  static const body = 'Use this to see where the loop is breaking.';

  static const noIssuesLine = 'No loop breaks flagged from local counts yet.';

  static const localCountsNote =
      'Local device counts only. No transcripts, entry IDs, or user identifiers.';

  static const diagnosisTitle = 'Diagnosis';
  static const metricPrefix = 'Metric';
  static const targetPrefix = 'Target';
  static const fixPrefix = 'Fix';

  static const firstCaptureUnclear = 'First capture is still unclear';
  static const returnReasonWeak = 'Return reason is weak';
  static const notReachingProof = 'Users are not reaching enough proof';
  static const timelineNotUseful = 'Timeline proof is not useful enough yet';
  static const specificityWeak = 'Specificity is weak';
  static const changeDeltaWeak = 'Change/delta is weak';
  static const relevanceWeak = 'Relevance/correction is weak';
  static const returnAfterProofWeak = 'Return after proof is weak';
  static const proBridgeHidden = 'Pro bridge is too hidden or too late';
  static const paidReasonWeak = 'Paid reason is not strong enough';

  static const fixFirstCapture = 'First capture';
  static const fixReturnPrompt = 'Return prompt';
  static const fixThreeMomentCompletion = 'Three moment completion';
  static const fixProofSpecificity = 'Proof specificity';
  static const fixChangeDeltaProof = 'Change/delta proof';
  static const fixCurrentRelevance = 'Current relevance';
  static const fixReturnAfterProof = 'Return after proof';
  static const fixProBridgeVisibility = 'Pro bridge visibility';
  static const fixPaywallPaidReason = 'Paywall paid reason';

  static const metricFirstSaveRate = 'First save rate';
  static const metricSecondSaveRate = 'Second save rate';
  static const metricThirdSaveRate = 'Third save rate';
  static const metricUsefulFeedbackRate = 'Useful feedback rate';
  static const metricTooVagueRate = 'Too vague rate';
  static const metricAlreadyKnewRate = 'Already knew rate';
  static const metricNotRelevantRate = 'Not relevant rate';
  static const metricReturnAfterProofRate = 'Return after proof rate';
  static const metricPaywallSeenAfterProofRate =
      'Paywall seen after proof rate';
  static const metricPurchaseCtaRate = 'Purchase CTA rate';

  static Iterable<String> allVisibleStrings() sync* {
    yield title;
    yield body;
    yield noIssuesLine;
    yield localCountsNote;
    yield firstCaptureUnclear;
    yield returnReasonWeak;
    yield notReachingProof;
    yield timelineNotUseful;
    yield specificityWeak;
    yield changeDeltaWeak;
    yield relevanceWeak;
    yield returnAfterProofWeak;
    yield proBridgeHidden;
    yield paidReasonWeak;
    yield fixFirstCapture;
    yield fixReturnPrompt;
    yield fixThreeMomentCompletion;
    yield fixProofSpecificity;
    yield fixChangeDeltaProof;
    yield fixCurrentRelevance;
    yield fixReturnAfterProof;
    yield fixProBridgeVisibility;
    yield fixPaywallPaidReason;
  }
}
