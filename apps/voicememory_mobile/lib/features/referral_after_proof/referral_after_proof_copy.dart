/// Referral after proof copy — future referral only after proof value.
abstract final class ReferralAfterProofCopy {
  ReferralAfterProofCopy._();

  static const headline = 'Referral after proof gate';

  static const body =
      'Allow future referral and invite only after proof value, never before. '
      'Classification and gating documentation only.';

  static const positioning =
      'Referral prompts stay after proof value — never before useful proof or Pro promise understanding.';

  static const orderLine =
      'Rules: only after proof value, never share private content, invite shares product not archive, '
      'not shown in first five minutes, not part of paid promise, no live referral UI for V1 unless '
      'existing route is gated.';

  static const guardrail =
      'Referral after proof gate defers referral prompts until proof value lands. Referral prompt only after useful proof accepted or Pro promise understood. Not shown in first five minutes. Never share private content. Invite shares product, not user archive. Not part of paid promise. No live referral UI for V1 unless an existing route is already gated.';

  static const referralBlockedLine =
      'Keep referral prompts frozen until useful proof is accepted or Pro promise is understood.';

  static const referralAfterProofAllowedLine =
      'Proof value reached. Referral may surface only through gated existing routes — never before proof, never in first five minutes.';

  static const detailPass = 'Pass';
  static const detailFail = 'Fail';

  static const detailReferralBlocked = 'Referral blocked before proof value';
  static const detailReferralAfterProofAllowed = 'Referral after proof allowed';

  static String ruleLabelFor(ReferralAfterProofRuleId id) => switch (id) {
        ReferralAfterProofRuleId.onlyAfterProofValue =>
          'Only after useful proof or Pro promise understood',
        ReferralAfterProofRuleId.neverSharePrivateContent =>
          'Never share private content',
        ReferralAfterProofRuleId.inviteSharesProductNotArchive =>
          'Invite shares product, not user archive',
        ReferralAfterProofRuleId.notShownInFirstFiveMinutes =>
          'Not shown in first five minutes',
        ReferralAfterProofRuleId.notPartOfPaidPromise => 'Not part of paid promise',
        ReferralAfterProofRuleId.noLiveReferralUiUnlessGated =>
          'No live referral UI unless existing route gated',
      };

  static String messageFor(ReferralAfterProofGateDecision decision) =>
      switch (decision) {
        ReferralAfterProofGateDecision.referralBlocked => referralBlockedLine,
        ReferralAfterProofGateDecision.referralAfterProofAllowed =>
          referralAfterProofAllowedLine,
      };

  static String recommendationFor(ReferralAfterProofGateDecision decision) =>
      switch (decision) {
        ReferralAfterProofGateDecision.referralBlocked =>
          'Do not surface referral prompts before proof value. Keep invite copy product-only.',
        ReferralAfterProofGateDecision.referralAfterProofAllowed =>
          'Gate referral through existing routes only. Never share archive content in invite copy.',
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield positioning;
    yield orderLine;
    yield guardrail;
    yield referralBlockedLine;
    yield referralAfterProofAllowedLine;
    yield detailPass;
    yield detailFail;
    yield detailReferralBlocked;
    yield detailReferralAfterProofAllowed;
    for (final id in ReferralAfterProofRuleId.values) {
      yield ruleLabelFor(id);
    }
    for (final decision in ReferralAfterProofGateDecision.values) {
      yield messageFor(decision);
      yield recommendationFor(decision);
    }
  }
}

enum ReferralAfterProofRuleId {
  onlyAfterProofValue,
  neverSharePrivateContent,
  inviteSharesProductNotArchive,
  notShownInFirstFiveMinutes,
  notPartOfPaidPromise,
  noLiveReferralUiUnlessGated,
}

enum ReferralAfterProofRuleStatus {
  pass,
  fail,
}

enum ReferralAfterProofGateDecision {
  referralBlocked,
  referralAfterProofAllowed,
}
