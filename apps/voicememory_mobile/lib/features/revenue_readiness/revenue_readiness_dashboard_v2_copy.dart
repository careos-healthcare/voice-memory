/// Copy for the unified revenue readiness dashboard — metadata only.
abstract final class RevenueReadinessDashboardV2Copy {
  RevenueReadinessDashboardV2Copy._();

  static const title = 'Revenue readiness';
  static const subtitle =
      'Full conversion path from first save to purchase — local beta counts only.';

  static const notEnoughData = 'Not enough beta data yet';
  static const localCountsNote =
      'Local device counts only. No transcripts, entry IDs, or user identifiers.';

  static const sectionCapture = 'Capture funnel';
  static const sectionProof = 'Proof funnel';
  static const sectionReturn = 'Return funnel';
  static const sectionRevenue = 'Revenue funnel';
  static const sectionDiagnosis = 'Conversion breaks';
  static const sectionDecisionRule = 'Selected decision rule';

  static const firstSave = 'First save';
  static const secondSave = 'Second save';
  static const thirdSave = 'Third save';

  static const timelineProofSeen = 'Timeline proof seen';
  static const useful = 'Useful feedback';
  static const tooVague = 'Too vague';
  static const alreadyKnew = 'Already knew';
  static const notRelevant = 'Not relevant';
  static const negativeCombined = 'Negative feedback combined';

  static const returnAfterProof = 'Return after proof';
  static const returnPromptSeen = 'Return-after-proof prompt seen';
  static const returnPromptTapped = 'Return-after-proof prompt tapped';

  static const proBridgeSeen = 'Pro bridge seen';
  static const proBridgeCtaTapped = 'Pro bridge CTA tapped';
  static const paywallSeen = 'Paywall seen';
  static const paywallCtaTapped = 'Paywall CTA tapped';
  static const purchaseStarted = 'Purchase started';
  static const purchaseCompleted = 'Purchase completed';
  static const restoreAttempted = 'Restore attempted';
  static const restoreCompleted = 'Restore completed';

  static const statusPending = 'Pending';
  static const statusHealthy = 'Healthy';
  static const statusWatch = 'Watch';
  static const statusFailing = 'Failing';

  static const noDiagnosesLine = 'No conversion breaks flagged from local counts yet.';
  static const nextActionPrefix = 'Next action';

  static const diagnosisLowFirstSave = 'Low first save';
  static const diagnosisLowSecondSave = 'Low second save';
  static const diagnosisLowThirdSave = 'Low third save';
  static const diagnosisLowUsefulProof = 'Useful below 25%';
  static const diagnosisNegativeAboveUseful = 'Negative feedback above useful';
  static const diagnosisLowReturnAfterProof = 'Return after proof under 25%';
  static const diagnosisLowPaywallSeen = 'Paywall seen under 35% after proof';
  static const diagnosisWeakCtaTap = 'CTA tap weak after paywall seen';
  static const diagnosisPurchaseCompletion =
      'Purchase started but not completed';
  static const diagnosisRestoreFailure = 'Restore failures';

  static const actionFixFirstCapture = 'Fix first capture';
  static const actionFixReturnPrompt = 'Fix return prompt';
  static const actionFixReasonToReturn = 'Fix reason to come back';
  static const actionFixProofWeak = 'Proof too weak/cautious';
  static const actionFixAnchorCalibration = 'Anchor/relevance calibration issue';
  static const actionFixReturnLoop = 'Return loop weak';
  static const actionFixProBridgeHidden = 'Pro bridge too hidden';
  static const actionFixPaywallValue = 'Paywall value unclear';
  static const actionFixBillingConfidence = 'Billing/purchase confidence issue';
  static const actionFixRestoreFlow = 'Restore flow issue';

  static const diagnosisFirstSaveLiftNeeded = 'First save lift needed';
  static const diagnosisReturnAfterProofLiftNeeded =
      'Return after proof lift needed';
  static const diagnosisProVisibilityLiftNeeded = 'Pro visibility lift needed';
  static const diagnosisPaywallCtaLiftNeeded = 'Paywall CTA lift needed';
  static const diagnosisFirstSessionCaptureWeak = 'First-session capture weak';
  static const diagnosisProUnderstandingWeak = 'Pro understanding weak';

  static const actionPaywallCtaLift = 'Sharpen paywall CTA copy and purchase line';
  static const actionFirstSaveLift = 'Sharpen first save lift copy';
  static const actionFirstSessionLift = 'Show first session lift card';
  static const actionProUnderstandingLift = 'Show Pro understanding lift card';
  static const actionReturnAfterProofLift = 'Sharpen return-after-proof reason copy';
  static const actionProVisibilityLift = 'Sharpen Pro visibility bridge copy';

  static Iterable<String> allVisibleStrings() sync* {
    yield title;
    yield subtitle;
    yield notEnoughData;
    yield localCountsNote;
    yield sectionCapture;
    yield sectionProof;
    yield sectionReturn;
    yield sectionRevenue;
    yield sectionDiagnosis;
    yield sectionDecisionRule;
    yield firstSave;
    yield secondSave;
    yield thirdSave;
    yield timelineProofSeen;
    yield useful;
    yield tooVague;
    yield alreadyKnew;
    yield notRelevant;
    yield negativeCombined;
    yield returnAfterProof;
    yield returnPromptSeen;
    yield returnPromptTapped;
    yield proBridgeSeen;
    yield proBridgeCtaTapped;
    yield paywallSeen;
    yield paywallCtaTapped;
    yield purchaseStarted;
    yield purchaseCompleted;
    yield restoreAttempted;
    yield restoreCompleted;
    yield statusPending;
    yield statusHealthy;
    yield statusWatch;
    yield statusFailing;
    yield noDiagnosesLine;
    yield diagnosisLowFirstSave;
    yield diagnosisLowSecondSave;
    yield diagnosisLowThirdSave;
    yield diagnosisLowUsefulProof;
    yield diagnosisNegativeAboveUseful;
    yield diagnosisLowReturnAfterProof;
    yield diagnosisLowPaywallSeen;
    yield diagnosisWeakCtaTap;
    yield diagnosisPurchaseCompletion;
    yield diagnosisRestoreFailure;
    yield actionFixFirstCapture;
    yield actionFixReturnPrompt;
    yield actionFixReasonToReturn;
    yield actionFixProofWeak;
    yield actionFixAnchorCalibration;
    yield actionFixReturnLoop;
    yield actionFixProBridgeHidden;
    yield actionFixPaywallValue;
    yield actionFixBillingConfidence;
    yield actionFixRestoreFlow;
    yield diagnosisFirstSaveLiftNeeded;
    yield diagnosisReturnAfterProofLiftNeeded;
    yield diagnosisProVisibilityLiftNeeded;
    yield diagnosisPaywallCtaLiftNeeded;
    yield diagnosisFirstSessionCaptureWeak;
    yield diagnosisProUnderstandingWeak;
    yield actionFirstSaveLift;
    yield actionFirstSessionLift;
    yield actionReturnAfterProofLift;
    yield actionProVisibilityLift;
    yield actionProUnderstandingLift;
    yield actionPaywallCtaLift;
  }
}
