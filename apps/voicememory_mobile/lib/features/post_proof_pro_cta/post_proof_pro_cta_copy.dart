/// Post-proof Pro CTA copy — after value, not before.
abstract final class PostProofProCtaCopy {
  PostProofProCtaCopy._();

  static const headline = 'Post-proof Pro CTA hardening';

  static const body =
      'Ensure the Pro CTA appears after value, not before. Classification and gating only.';

  static const positioning =
      'Pro CTA stays post-proof — canonical longer-trail framing, no urgency or storage language.';

  static const canonicalCta = 'Keep the longer trail';

  static const canonicalBody =
      'Free showed the first useful proof. Pro keeps tracking what happens next.';

  static const orderLine =
      'Rules: hide before first useful proof unless explicit Pro open, show after proof value, '
      'canonical CTA/body, no more AI, no life-dashboard framing, no storage framing, '
      'no urgency/scarcity, no pricing or RevenueCat changes.';

  static const guardrail =
      'Post-proof Pro CTA hardening keeps the Pro CTA after value, not before. '
      'Hide before first useful proof unless user explicitly opens Pro. '
      'Show after first useful proof, accepted proof, or clear longer-trail moment. '
      'Use canonical CTA and body only. Never say more AI, life-dashboard framing, storage framing, '
      'or urgency/scarcity language. Do not change pricing or RevenueCat.';

  static const proCtaBlockedLine =
      'Keep Pro CTA hidden until first useful proof, accepted proof, or a clear longer-trail moment.';

  static const proCtaHardenedLine =
      'Post-proof Pro CTA hardened. Show canonical longer-trail CTA only after proof value lands.';

  static const detailPass = 'Pass';
  static const detailFail = 'Fail';

  static const detailProCtaBlocked = 'Pro CTA blocked before proof value';
  static const detailProCtaHardened = 'Pro CTA hardened after proof value';

  static String ruleLabelFor(PostProofProCtaRuleId id) => switch (id) {
        PostProofProCtaRuleId.hideBeforeFirstUsefulProofUnlessExplicitOpen =>
          'Hide before first useful proof unless explicit Pro open',
        PostProofProCtaRuleId.showAfterProofValueMoment =>
          'Show after proof value moment',
        PostProofProCtaRuleId.canonicalCtaAndBody => 'Canonical CTA and body',
        PostProofProCtaRuleId.noMoreAiLanguage => 'No more AI language',
        PostProofProCtaRuleId.noDashboardLanguage => 'No life-dashboard framing',
        PostProofProCtaRuleId.noStorageLanguage => 'No storage framing',
        PostProofProCtaRuleId.noUrgencyScarcityLanguage =>
          'No urgency or scarcity language',
        PostProofProCtaRuleId.noPricingOrRevenueCatChanges =>
          'No pricing or RevenueCat changes',
      };

  static String messageFor(PostProofProCtaHardeningDecision decision) =>
      switch (decision) {
        PostProofProCtaHardeningDecision.proCtaBlocked => proCtaBlockedLine,
        PostProofProCtaHardeningDecision.proCtaHardened => proCtaHardenedLine,
      };

  static String recommendationFor(PostProofProCtaHardeningDecision decision) =>
      switch (decision) {
        PostProofProCtaHardeningDecision.proCtaBlocked =>
          'Wait for first useful proof or explicit Pro open before surfacing the CTA.',
        PostProofProCtaHardeningDecision.proCtaHardened =>
          'Use canonical post-proof CTA and body only. Keep pricing and RevenueCat unchanged.',
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield positioning;
    yield canonicalCta;
    yield canonicalBody;
    yield orderLine;
    yield guardrail;
    yield proCtaBlockedLine;
    yield proCtaHardenedLine;
    yield detailPass;
    yield detailFail;
    yield detailProCtaBlocked;
    yield detailProCtaHardened;
    for (final id in PostProofProCtaRuleId.values) {
      yield ruleLabelFor(id);
    }
    for (final decision in PostProofProCtaHardeningDecision.values) {
      yield messageFor(decision);
      yield recommendationFor(decision);
    }
  }
}

enum PostProofProCtaRuleId {
  hideBeforeFirstUsefulProofUnlessExplicitOpen,
  showAfterProofValueMoment,
  canonicalCtaAndBody,
  noMoreAiLanguage,
  noDashboardLanguage,
  noStorageLanguage,
  noUrgencyScarcityLanguage,
  noPricingOrRevenueCatChanges,
}

enum PostProofProCtaRuleStatus {
  pass,
  fail,
}

enum PostProofProCtaHardeningDecision {
  proCtaBlocked,
  proCtaHardened,
}
