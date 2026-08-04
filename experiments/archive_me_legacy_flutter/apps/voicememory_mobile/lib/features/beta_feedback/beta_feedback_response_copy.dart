import 'beta_feedback_response_models.dart';

/// Copy for beta feedback response rules — product readiness only.
abstract final class BetaFeedbackResponseCopy {
  BetaFeedbackResponseCopy._();

  static const sectionTitle = 'Suggested next fix';
  static const localBetaSignalPrefix = 'Local beta signal';
  static const notEnoughEvidence = 'Not enough evidence yet';

  static const suggestedFixClarifyPromise =
      'Suggested next fix: clarify first-moment promise';
  static const suggestedFixFirstRecordingCta =
      'Suggested next fix: improve first recording CTA';
  static const suggestedFixActivationPath =
      'Suggested next fix: improve 3-moment activation path';
  static const suggestedFixDailyChange =
      'Suggested next fix: sharpen daily change response';
  static const suggestedFixAlternatives =
      'Suggested next fix: sharpen alternative rules';
  static const suggestedFixPaidLaunch =
      'Suggested next fix: prepare paid launch';
  static const suggestedFixReduceCaptureWorkload =
      'Suggested next fix: reduce capture workload further';

  static const unclearPromiseProblem =
      'The first-moment promise may still be too broad.';
  static const firstMomentBlockedProblem =
      'The first save path may be blocked or unclear.';
  static const activationDropoffProblem =
      'Users may save once but not reach three yes moments.';
  static const repetitiveLoopProblem =
      'The loop may feel repetitive after return visits.';
  static const weakAlternativeProblem =
      'Alternative next moves may feel too generic.';
  static const paidSignalReadyProblem =
      'Return and willingness-to-pay signals may be strong enough to prepare paid launch.';
  static const quickCaptureStillWorkProblem =
      'Quick capture may still feel like extra workload.';

  static const unclearPromiseChange =
      'Tighten onboarding copy. Show: Catch the yes before it costs you. Save a yes moment. See what pulled you in. Review what changed. Do not add more explanation.';
  static const firstMomentBlockedChange =
      'Fix record/start flow. Make CTA Save yes moment. Show prompt: What are you about to agree to, and what makes it hard to pause? Reduce competing cards before first save.';
  static const activationDropoffChange =
      'Fix activation path. Show N of 3 yes moments saved. Explain: Three real moments are enough to start seeing what repeats. Add one clear CTA back to Record.';
  static const repetitiveLoopChange =
      'Sharpen daily change. Combine pull reason + outcome + later cost. Avoid repeating the same line.';
  static const weakAlternativeChange =
      'Improve alternative rules. Prefer selected boundary response. Match pull reason to a stronger fixed response.';
  static const paidSignalReadyChange =
      'Prepare RevenueCat / paid launch next. Do not enable payments in the response branch. RevenueCat should only be finished after return + WTP signal.';
  static const quickCaptureStillWorkChange =
      'Reduce capture workload further. Keep quick save fixed and optional. Do not add typing or long journaling.';

  static const doNotEnablePayments =
      'Do not enable RevenueCat or payments in this response branch.';
  static const doNotAddBackend = 'Do not add backend work.';
  static const doNotBuildAllFixes = 'Do not build all fixes at once.';
  static const oneBranchPerFailure =
      'Use one branch per repeated failure after beta evidence.';
  static const revenueCatAfterWtp =
      'RevenueCat only after return + WTP evidence.';

  static const unclearPromiseSuccess =
      'User saves first yes moment without asking what the app is for.';
  static const firstMomentBlockedSuccess =
      'User saves the first yes moment on the first visit.';
  static const activationDropoffSuccess =
      'User saves 3 yes moments and reviews the yes loop.';
  static const repetitiveLoopSuccess =
      'Return users report the daily change feels specific, not repetitive.';
  static const weakAlternativeSuccess =
      'Users copy or select a boundary response that matches the pull.';
  static const paidSignalReadySuccess =
      'User returns, marks fit, and expresses willingness to pay — prepare paid launch separately.';
  static const quickCaptureStillWorkSuccess =
      'User reports quick capture felt light enough to use again.';

  static String suggestedFixForIssue(String issueId) => switch (issueId) {
    BetaFeedbackIssueIds.unclearPromise => suggestedFixClarifyPromise,
    BetaFeedbackIssueIds.firstMomentBlocked => suggestedFixFirstRecordingCta,
    BetaFeedbackIssueIds.activationDropoff => suggestedFixActivationPath,
    BetaFeedbackIssueIds.repetitiveLoop => suggestedFixDailyChange,
    BetaFeedbackIssueIds.weakAlternative => suggestedFixAlternatives,
    BetaFeedbackIssueIds.paidSignalReady => suggestedFixPaidLaunch,
    BetaFeedbackIssueIds.quickCaptureStillWork =>
      suggestedFixReduceCaptureWorkload,
    _ => '',
  };

  static List<String> allVisibleStrings() => [
    sectionTitle,
    localBetaSignalPrefix,
    notEnoughEvidence,
    suggestedFixClarifyPromise,
    suggestedFixFirstRecordingCta,
    suggestedFixActivationPath,
    suggestedFixDailyChange,
    suggestedFixAlternatives,
    suggestedFixPaidLaunch,
    suggestedFixReduceCaptureWorkload,
    unclearPromiseProblem,
    firstMomentBlockedProblem,
    activationDropoffProblem,
    repetitiveLoopProblem,
    weakAlternativeProblem,
    paidSignalReadyProblem,
    quickCaptureStillWorkProblem,
    unclearPromiseChange,
    firstMomentBlockedChange,
    activationDropoffChange,
    repetitiveLoopChange,
    weakAlternativeChange,
    paidSignalReadyChange,
    quickCaptureStillWorkChange,
    doNotEnablePayments,
    doNotAddBackend,
    doNotBuildAllFixes,
    oneBranchPerFailure,
    revenueCatAfterWtp,
    unclearPromiseSuccess,
    firstMomentBlockedSuccess,
    activationDropoffSuccess,
    repetitiveLoopSuccess,
    weakAlternativeSuccess,
    paidSignalReadySuccess,
    quickCaptureStillWorkSuccess,
  ];
}
