/// Copy for internal Pro moment timing audit v2 — metadata only.
abstract final class ProMomentTimingAuditV2Copy {
  ProMomentTimingAuditV2Copy._();

  static const title = 'Pro moment timing audit';
  static const subtitle =
      'Checks whether Pro appears after proof — not before value.';

  static const statusReady = 'Ready';
  static const statusWatch = 'Watch';
  static const statusBlocked = 'Blocked';

  static const checkNeverBeforeFirstProof =
      'Pro bridge never appears before first proof';
  static const checkAfterUsefulProof = 'Pro bridge appears after useful proof';
  static const checkAfterStrongProof = 'Pro bridge appears after strong proof';
  static const checkAfterFreshReturn = 'Pro bridge appears after fresh return';
  static const checkAfterCorrectionRelevant =
      'Pro bridge appears after correction that becomes relevant again';
  static const checkBlockedTooVague = 'Pro bridge is blocked after Too vague';
  static const checkBlockedNotRelevant =
      'Pro bridge is blocked after Not relevant';
  static const checkAlreadyKnewNeedsDelta =
      'Pro bridge after Already knew requires change/delta';
  static const checkNotHiddenByGuidance =
      'Pro bridge is not hidden by generic guidance';
  static const checkPaywallSourceProofConnected =
      'Paywall source is proof-connected from proof bridge';
  static const checkPaywallCopyProofConnected =
      'Paywall copy uses proof-connected headline';
  static const checkOneProCardPerSurface =
      'Only one Pro card appears per surface';

  static const detailBlockedBeforeProof = 'Blocked before first proof';
  static const detailAllowedAfterProof = 'Allowed after proof signal';
  static const detailBlockedAfterFeedback = 'Blocked after negative feedback';
  static const detailAlreadyKnewWithoutDelta = 'Blocked without change/delta';
  static const detailAlreadyKnewWithDelta =
      'Allowed when correction/delta exists';
  static const detailVisibleWithGuidance = 'Visible alongside guidance slot';
  static const detailValueMomentSource = 'Uses value_moment paywall source';
  static const detailProofConnectedHeadline = 'Uses proof-connected headline';
  static const detailSingleProSlot = 'Surface priority caps Pro to one card';
  static const detailFailed = 'Timing rule check failed';

  static const diagnosisTooEarly = 'Too early: user has not seen proof yet';
  static const diagnosisTooHidden =
      'Too hidden: useful proof exists but no Pro bridge';
  static const diagnosisWrongSource =
      'Wrong source: paywall is not proof-connected';
  static const diagnosisTooCluttered =
      'Too cluttered: multiple Pro prompts compete';
  static const diagnosisCorrect = 'Correct: Pro appears after proof';

  static const localNote =
      'Rule checks only. No purchase simulation. Metadata counts — no journal text.';
}
