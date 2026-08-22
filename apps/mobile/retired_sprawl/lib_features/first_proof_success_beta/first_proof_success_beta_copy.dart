/// First proof success beta copy — measurement and prompt/input guidance only.
abstract final class FirstProofSuccessBetaCopy {
  FirstProofSuccessBetaCopy._();

  static const headline = 'First proof success beta guard';

  static const body =
      'Measure first proof success with real testers without loosening proof '
      'thresholds. Route failures to prompt and input guidance only.';

  static const orderLine =
      'Signals: usable moments, safe anchor, match quality, proof confidence, '
      'proof shown, acceptance, correction, too vague, not relevant, understood why, '
      'saved again after proof.';

  static const checkUsableMomentsReady = 'Enough usable moments saved';
  static const checkSafeAnchorPresent = 'Safe anchor present';
  static const checkMatchQualityPresent = 'Match quality present';
  static const checkProofConfidenceStrong = 'Proof confidence strong enough';
  static const checkProofShown = 'Proof shown';
  static const checkProofAccepted = 'Proof accepted';
  static const checkProofCorrected = 'Proof corrected';
  static const checkTooVagueSelected = 'Too vague selected';
  static const checkNotRelevantSelected = 'Not relevant selected';
  static const checkUserUnderstoodWhy = 'User understood why';
  static const checkUserSavedAnotherAfterProof =
      'User saved another moment after proof';

  static const detailPass = 'Observed';
  static const detailConcern = 'Needs guidance routing';
  static const detailNotObserved = 'Not observed yet';

  static const notEnoughMomentsLine =
      'Tester has not saved 3 usable moments yet. Route to more real moments '
      'and capture guidance — do not lower minProofEntryCount.';

  static const weakInputQualityLine =
      'Input quality is too weak for proof. Route to prompt and capture specificity '
      'guidance only — do not loosen thresholds.';

  static const noSafeAnchorLine =
      'Proof cannot proceed without a safe anchor. Route to anchor and evidence '
      'guidance — do not loosen anchor rules.';

  static const proofNotShownLine =
      'Proof has not been shown yet. Keep collecting usable moments and wait for '
      'the existing first-proof path — do not expand proof volume.';

  static const proofShownNeedsFeedbackLine =
      'Proof was shown but feedback is incomplete. Collect acceptance or repair '
      'feedback on the existing first-proof path only.';

  static const proofTooVagueRiskLine =
      'Proof felt too vague. Route to proof trust repair and explanation guidance '
      'only — do not loosen thresholds.';

  static const proofNotRelevantRiskLine =
      'Proof felt not relevant. Route to proof trust repair and relevance guidance '
      'only — do not loosen anchors.';

  static const proofWorkingLine =
      'First proof is working for this tester. Continue beta without threshold '
      'or volume changes.';

  static const proofStrongEnoughForProLine =
      'Proof accepted after Pro promise was seen. Strong enough to continue Pro-path '
      'measurement without loosening proof rules.';

  static const guardrail =
      'First proof success beta guard measures outcomes and routes prompt/input '
      'guidance only. Do not loosen minProofEntryCount, anchor rules, or proof volume.';

  static String labelFor(FirstProofSuccessBetaSignalId id) => switch (id) {
    FirstProofSuccessBetaSignalId.usableMomentsReady => checkUsableMomentsReady,
    FirstProofSuccessBetaSignalId.safeAnchorPresent => checkSafeAnchorPresent,
    FirstProofSuccessBetaSignalId.matchQualityPresent =>
      checkMatchQualityPresent,
    FirstProofSuccessBetaSignalId.proofConfidenceStrong =>
      checkProofConfidenceStrong,
    FirstProofSuccessBetaSignalId.proofShown => checkProofShown,
    FirstProofSuccessBetaSignalId.proofAccepted => checkProofAccepted,
    FirstProofSuccessBetaSignalId.proofCorrected => checkProofCorrected,
    FirstProofSuccessBetaSignalId.tooVagueSelected => checkTooVagueSelected,
    FirstProofSuccessBetaSignalId.notRelevantSelected =>
      checkNotRelevantSelected,
    FirstProofSuccessBetaSignalId.userUnderstoodWhy => checkUserUnderstoodWhy,
    FirstProofSuccessBetaSignalId.userSavedAnotherAfterProof =>
      checkUserSavedAnotherAfterProof,
  };

  static String messageFor(FirstProofSuccessBetaDecision decision) =>
      switch (decision) {
        FirstProofSuccessBetaDecision.notEnoughMoments => notEnoughMomentsLine,
        FirstProofSuccessBetaDecision.weakInputQuality => weakInputQualityLine,
        FirstProofSuccessBetaDecision.noSafeAnchor => noSafeAnchorLine,
        FirstProofSuccessBetaDecision.proofNotShown => proofNotShownLine,
        FirstProofSuccessBetaDecision.proofShownNeedsFeedback =>
          proofShownNeedsFeedbackLine,
        FirstProofSuccessBetaDecision.proofTooVagueRisk =>
          proofTooVagueRiskLine,
        FirstProofSuccessBetaDecision.proofNotRelevantRisk =>
          proofNotRelevantRiskLine,
        FirstProofSuccessBetaDecision.proofWorking => proofWorkingLine,
        FirstProofSuccessBetaDecision.proofStrongEnoughForPro =>
          proofStrongEnoughForProLine,
      };

  static String recommendationFor(FirstProofSuccessBetaDecision decision) =>
      switch (decision) {
        FirstProofSuccessBetaDecision.notEnoughMoments =>
          'Route to more real moments and first-session capture guidance.',
        FirstProofSuccessBetaDecision.weakInputQuality =>
          'Route to prompt assist and capture specificity guidance only.',
        FirstProofSuccessBetaDecision.noSafeAnchor =>
          'Route to anchor extraction and evidence display guidance.',
        FirstProofSuccessBetaDecision.proofNotShown =>
          'Keep building usable moments on the existing first-proof path.',
        FirstProofSuccessBetaDecision.proofShownNeedsFeedback =>
          'Collect proof feedback on the existing first-proof path.',
        FirstProofSuccessBetaDecision.proofTooVagueRisk =>
          'Route to proof trust repair and explanation guidance.',
        FirstProofSuccessBetaDecision.proofNotRelevantRisk =>
          'Route to proof trust repair and relevance guidance.',
        FirstProofSuccessBetaDecision.proofWorking =>
          'Continue beta testing. No proof-threshold changes needed.',
        FirstProofSuccessBetaDecision.proofStrongEnoughForPro =>
          'Continue Pro-path measurement. Do not loosen proof thresholds.',
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield orderLine;
    yield checkUsableMomentsReady;
    yield checkSafeAnchorPresent;
    yield checkMatchQualityPresent;
    yield checkProofConfidenceStrong;
    yield checkProofShown;
    yield checkProofAccepted;
    yield checkProofCorrected;
    yield checkTooVagueSelected;
    yield checkNotRelevantSelected;
    yield checkUserUnderstoodWhy;
    yield checkUserSavedAnotherAfterProof;
    yield detailPass;
    yield detailConcern;
    yield detailNotObserved;
    yield notEnoughMomentsLine;
    yield weakInputQualityLine;
    yield noSafeAnchorLine;
    yield proofNotShownLine;
    yield proofShownNeedsFeedbackLine;
    yield proofTooVagueRiskLine;
    yield proofNotRelevantRiskLine;
    yield proofWorkingLine;
    yield proofStrongEnoughForProLine;
    yield guardrail;
    for (final decision in FirstProofSuccessBetaDecision.values) {
      yield messageFor(decision);
      yield recommendationFor(decision);
    }
  }
}

enum FirstProofSuccessBetaSignalId {
  usableMomentsReady,
  safeAnchorPresent,
  matchQualityPresent,
  proofConfidenceStrong,
  proofShown,
  proofAccepted,
  proofCorrected,
  tooVagueSelected,
  notRelevantSelected,
  userUnderstoodWhy,
  userSavedAnotherAfterProof,
}

enum FirstProofSuccessBetaSignalStatus { pass, concern, notObserved }

enum FirstProofSuccessBetaDecision {
  notEnoughMoments,
  weakInputQuality,
  noSafeAnchor,
  proofNotShown,
  proofShownNeedsFeedback,
  proofTooVagueRisk,
  proofNotRelevantRisk,
  proofWorking,
  proofStrongEnoughForPro,
}