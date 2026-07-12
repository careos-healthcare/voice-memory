/// Niche landing revenue copy — acquisition pages without app V1 surfaces.
abstract final class NicheLandingRevenueCopy {
  NicheLandingRevenueCopy._();

  static const headline = 'Niche landing revenue plan';

  static const body =
      'Define revenue-focused acquisition pages without adding app UI. '
      'Marketing and web classification only.';

  static const positioning =
      'Niche landing pages stay marketing/web only — same core promise, same paid promise, no medical claims.';

  static const corePromise = 'Save one repeat. ArchiveMe compares it later.';

  static const paidPromise = 'Pro keeps the longer proof trail.';

  static const landingPagesLine =
      'Landing pages: saying yes/no capacity, prove enough, relationship replay, '
      'repeating habit, work pressure, overcommitment.';

  static const orderLine =
      'Rules: marketing/web not app V1 surface, no medical or wellness-treatment claims, '
      'core promise on every landing page, paid promise documented.';

  static const guardrail =
      'Niche landing revenue plan defines marketing/web acquisition pages only — not app V1 feature surfaces. '
      'Avoid medical or wellness-treatment claims. Every landing page points to the same core promise: '
      '"Save one repeat. ArchiveMe compares it later." Paid promise: "Pro keeps the longer proof trail."';

  static const landingPlanFrozenLine =
      'Keep niche landing pages in marketing/web planning until guardrails pass.';

  static const landingPlanDocumentedLine =
      'Niche landing revenue plan documented. Six acquisition pages share core and paid promises only.';

  static const detailPass = 'Pass';
  static const detailFail = 'Fail';

  static const detailLandingPlanFrozen = 'Landing plan frozen until guardrails pass';
  static const detailLandingPlanDocumented =
      'Landing plan documented for marketing/web acquisition';

  static String labelFor(NicheLandingPageId id) => switch (id) {
        NicheLandingPageId.sayingYesNoCapacity => 'Saying yes/no capacity',
        NicheLandingPageId.proveEnough => 'Prove enough',
        NicheLandingPageId.relationshipReplay => 'Relationship replay',
        NicheLandingPageId.repeatingHabit => 'Repeating habit',
        NicheLandingPageId.workPressure => 'Work pressure',
        NicheLandingPageId.overcommitment => 'Overcommitment',
      };

  static String hookFor(NicheLandingPageId id) => switch (id) {
        NicheLandingPageId.sayingYesNoCapacity =>
          'When yes/no capacity keeps replaying, save one repeat and compare it later.',
        NicheLandingPageId.proveEnough =>
          'When you keep trying to prove you did enough, save one repeat and compare it later.',
        NicheLandingPageId.relationshipReplay =>
          'When relationship replay loops return, save one repeat and compare it later.',
        NicheLandingPageId.repeatingHabit =>
          'When the same habit keeps returning, save one repeat and compare it later.',
        NicheLandingPageId.workPressure =>
          'When work pressure patterns repeat, save one repeat and compare it later.',
        NicheLandingPageId.overcommitment =>
          'When overcommitment cycles replay, save one repeat and compare it later.',
      };

  static String ruleLabelFor(NicheLandingRevenueRuleId id) => switch (id) {
        NicheLandingRevenueRuleId.marketingWebNotAppV1Surface =>
          'Marketing/web, not app V1 feature surface',
        NicheLandingRevenueRuleId.noMedicalTherapyClaims =>
          'No medical or wellness-treatment claims',
        NicheLandingRevenueRuleId.corePromiseOnEveryLandingPage =>
          'Core promise on every landing page',
        NicheLandingRevenueRuleId.paidPromiseDocumented =>
          'Paid promise documented',
      };

  static String messageFor(NicheLandingRevenuePlanDecision decision) =>
      switch (decision) {
        NicheLandingRevenuePlanDecision.landingPlanFrozen => landingPlanFrozenLine,
        NicheLandingRevenuePlanDecision.landingPlanDocumented =>
          landingPlanDocumentedLine,
      };

  static String recommendationFor(NicheLandingRevenuePlanDecision decision) =>
      switch (decision) {
        NicheLandingRevenuePlanDecision.landingPlanFrozen =>
          'Keep niche landing pages in marketing/web docs until core and paid promises align.',
        NicheLandingRevenuePlanDecision.landingPlanDocumented =>
          'Publish acquisition pages on marketing/web only. Keep app V1 surfaces unchanged.',
      };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield positioning;
    yield corePromise;
    yield paidPromise;
    yield landingPagesLine;
    yield orderLine;
    yield guardrail;
    yield landingPlanFrozenLine;
    yield landingPlanDocumentedLine;
    yield detailPass;
    yield detailFail;
    yield detailLandingPlanFrozen;
    yield detailLandingPlanDocumented;
    for (final id in NicheLandingPageId.values) {
      yield labelFor(id);
      yield hookFor(id);
    }
    for (final id in NicheLandingRevenueRuleId.values) {
      yield ruleLabelFor(id);
    }
    for (final decision in NicheLandingRevenuePlanDecision.values) {
      yield messageFor(decision);
      yield recommendationFor(decision);
    }
  }
}

enum NicheLandingPageId {
  sayingYesNoCapacity,
  proveEnough,
  relationshipReplay,
  repeatingHabit,
  workPressure,
  overcommitment,
}

enum NicheLandingRevenueRuleId {
  marketingWebNotAppV1Surface,
  noMedicalTherapyClaims,
  corePromiseOnEveryLandingPage,
  paidPromiseDocumented,
}

enum NicheLandingRevenueRuleStatus {
  pass,
  fail,
}

enum NicheLandingRevenuePlanDecision {
  landingPlanFrozen,
  landingPlanDocumented,
}
