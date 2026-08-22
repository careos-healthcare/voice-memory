/// First proof field readiness copy — beta measurement and repair routing only.
abstract final class FirstProofFieldReadinessCopy {
  FirstProofFieldReadinessCopy._();

  static const headline = 'First proof field readiness';

  static const body =
      'Measure whether first proof succeeds with real testers without loosening '
      'proof thresholds. Route repairs only — no anchor, volume, or threshold changes.';

  static const orderLine =
      'Signals: 3 usable moments, strong proof, watch_only fallback, safe anchor, '
      'acceptance, correction, too vague, not relevant, why appeared, what to save next.';

  static const checkThreeUsableMoments = 'User saved 3 usable moments';
  static const checkStrongProofAppeared = 'Strong proof appeared';
  static const checkWatchOnlyInstead = 'watch_only appeared instead';
  static const checkNoSafeAnchor = 'No safe anchor';
  static const checkProofAccepted = 'Proof accepted';
  static const checkProofCorrected = 'Proof corrected';
  static const checkProofTooVague = 'Proof too vague';
  static const checkProofNotRelevant = 'Proof not relevant';
  static const checkUnderstoodWhyAppeared = 'User understood why it appeared';
  static const checkUnderstoodWhatToSaveNext =
      'User understood what to save next';

  static const detailPass = 'Observed';
  static const detailConcern = 'Needs repair routing';
  static const detailNotObserved = 'Not observed yet';

  static const insufficientCaptureLine =
      'Tester has not saved 3 usable moments yet. Repair capture guidance first.';

  static const repairAnchorSafetyLine =
      'Proof surfaced without a safe anchor. Repair anchor extraction and evidence '
      'display — do not loosen anchors.';

  static const repairProofClarityLine =
      'Proof felt too vague or why-it-appeared was unclear. Repair proof explanation '
      'copy only.';

  static const repairProofRelevanceLine =
      'Proof felt not relevant. Route to relevance repair — do not loosen anchors.';

  static const repairProofStrengthLine =
      'watch_only appeared instead of useful or strong proof. Repair capture specificity '
      'and proof selection — do not change thresholds.';

  static const repairSaveNextGuidanceLine =
      'Tester did not understand what to save next. Repair save-next guidance only.';

  static const repairWhyAppearedLine =
      'Tester did not understand why proof appeared. Repair why-appeared explanation only.';

  static const fieldReadyLine =
      'First proof field readiness passes for this tester. Continue beta without '
      'threshold changes.';

  static const needsManualReviewLine =
      'Mixed or incomplete field signals. Review manually before changing proof rules.';

  static const guardrail =
      'First proof field readiness measures beta outcomes and routes repairs only. '
      'Do not loosen anchors, expand proof volume, or change thresholds.';

  static String labelFor(FirstProofFieldReadinessSignalId id) => switch (id) {
    FirstProofFieldReadinessSignalId.userSavedThreeUsableMoments =>
      checkThreeUsableMoments,
    FirstProofFieldReadinessSignalId.strongProofAppeared =>
      checkStrongProofAppeared,
    FirstProofFieldReadinessSignalId.watchOnlyAppearedInstead =>
      checkWatchOnlyInstead,
    FirstProofFieldReadinessSignalId.noSafeAnchor => checkNoSafeAnchor,
    FirstProofFieldReadinessSignalId.proofAccepted => checkProofAccepted,
    FirstProofFieldReadinessSignalId.proofCorrected => checkProofCorrected,
    FirstProofFieldReadinessSignalId.proofTooVague => checkProofTooVague,
    FirstProofFieldReadinessSignalId.proofNotRelevant => checkProofNotRelevant,
    FirstProofFieldReadinessSignalId.userUnderstoodWhyAppeared =>
      checkUnderstoodWhyAppeared,
    FirstProofFieldReadinessSignalId.userUnderstoodWhatToSaveNext =>
      checkUnderstoodWhatToSaveNext,
  };

  static String messageFor(
    FirstProofFieldReadinessDecision decision,
  ) => switch (decision) {
    FirstProofFieldReadinessDecision.insufficientCapture =>
      insufficientCaptureLine,
    FirstProofFieldReadinessDecision.repairAnchorSafety =>
      repairAnchorSafetyLine,
    FirstProofFieldReadinessDecision.repairProofClarity =>
      repairProofClarityLine,
    FirstProofFieldReadinessDecision.repairProofRelevance =>
      repairProofRelevanceLine,
    FirstProofFieldReadinessDecision.repairProofStrength =>
      repairProofStrengthLine,
    FirstProofFieldReadinessDecision.repairSaveNextGuidance =>
      repairSaveNextGuidanceLine,
    FirstProofFieldReadinessDecision.repairWhyAppeared => repairWhyAppearedLine,
    FirstProofFieldReadinessDecision.fieldReady => fieldReadyLine,
    FirstProofFieldReadinessDecision.needsManualReview => needsManualReviewLine,
  };

  static String recommendationFor(
    FirstProofFieldReadinessDecision decision,
  ) => switch (decision) {
    FirstProofFieldReadinessDecision.insufficientCapture =>
      'Route to first-session capture repair and three-moment guidance.',
    FirstProofFieldReadinessDecision.repairAnchorSafety =>
      'Route to anchor extraction and evidence display repair.',
    FirstProofFieldReadinessDecision.repairProofClarity =>
      'Route to proof explanation and specificity repair.',
    FirstProofFieldReadinessDecision.repairProofRelevance =>
      'Route to proof relevance repair.',
    FirstProofFieldReadinessDecision.repairProofStrength =>
      'Route to capture specificity repair without lowering proof thresholds.',
    FirstProofFieldReadinessDecision.repairSaveNextGuidance =>
      'Route to save-next guidance repair.',
    FirstProofFieldReadinessDecision.repairWhyAppeared =>
      'Route to why-appeared explanation repair.',
    FirstProofFieldReadinessDecision.fieldReady =>
      'Continue beta testing. No proof-threshold changes needed.',
    FirstProofFieldReadinessDecision.needsManualReview =>
      'Review tester notes before any proof-threshold change.',
  };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield orderLine;
    yield checkThreeUsableMoments;
    yield checkStrongProofAppeared;
    yield checkWatchOnlyInstead;
    yield checkNoSafeAnchor;
    yield checkProofAccepted;
    yield checkProofCorrected;
    yield checkProofTooVague;
    yield checkProofNotRelevant;
    yield checkUnderstoodWhyAppeared;
    yield checkUnderstoodWhatToSaveNext;
    yield detailPass;
    yield detailConcern;
    yield detailNotObserved;
    yield insufficientCaptureLine;
    yield repairAnchorSafetyLine;
    yield repairProofClarityLine;
    yield repairProofRelevanceLine;
    yield repairProofStrengthLine;
    yield repairSaveNextGuidanceLine;
    yield repairWhyAppearedLine;
    yield fieldReadyLine;
    yield needsManualReviewLine;
    yield guardrail;
    for (final decision in FirstProofFieldReadinessDecision.values) {
      yield messageFor(decision);
      yield recommendationFor(decision);
    }
  }
}

enum FirstProofFieldReadinessSignalId {
  userSavedThreeUsableMoments,
  strongProofAppeared,
  watchOnlyAppearedInstead,
  noSafeAnchor,
  proofAccepted,
  proofCorrected,
  proofTooVague,
  proofNotRelevant,
  userUnderstoodWhyAppeared,
  userUnderstoodWhatToSaveNext,
}

enum FirstProofFieldReadinessSignalStatus { pass, concern, notObserved }

enum FirstProofFieldReadinessDecision {
  insufficientCapture,
  repairAnchorSafety,
  repairProofClarity,
  repairProofRelevance,
  repairProofStrength,
  repairSaveNextGuidance,
  repairWhyAppeared,
  fieldReady,
  needsManualReview,
}