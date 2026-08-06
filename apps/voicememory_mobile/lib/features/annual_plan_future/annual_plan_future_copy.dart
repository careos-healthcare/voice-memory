/// Annual plan future copy — annual plan as future revenue test only.
abstract final class AnnualPlanFutureCopy {
  AnnualPlanFutureCopy._();

  static const headline = 'Annual plan future gate';

  static const body =
      'Document annual plan as future revenue test only after monthly purchase proof. '
      'Classification and documentation only.';

  static const positioning =
      'Annual plan stays future revenue test only — longer proof trail for the year after monthly proof lands.';

  static const futureAnnualPlanLine =
      'Future annual plan: keep the longer proof trail for the year.';

  static const yearTrailFocusCopy = 'Keep the longer proof trail for the year.';

  static const orderLine =
      'Rules: no annual RevenueCat product now, no paywall changes now, '
      'annual plan requires monthly sandbox purchase proof, annual plan requires paid-intent beta value, '
      'copy focuses on longer proof trail for the year.';

  static const prereqOrderLine =
      'Prerequisites: monthly sandbox purchase proof complete, paid-intent beta shows value.';

  static const guardrail =
      'Annual plan future gate documents annual plan as future revenue test only. '
      'Do not add annual RevenueCat product now. Do not change paywall now. '
      'Annual plan requires monthly sandbox purchase proof first. '
      'Annual plan requires paid-intent beta showing value. '
      'Copy must focus on keeping longer proof trail for the year.';

  static const annualPlanFrozenLine =
      'Keep annual plan frozen until monthly sandbox purchase proof and paid-intent beta value land.';

  static const annualPlanDocumentedLine =
      'Monthly purchase proof and paid-intent beta value complete. Document annual plan as future revenue test only.';

  static const detailPass = 'Pass';
  static const detailPending = 'Pending';
  static const detailFail = 'Fail';

  static const detailBlockedBeforeProof =
      'Blocked before monthly purchase proof';
  static const detailFutureAnnualPlanDocumented =
      'Future annual plan documented only';

  static String prereqLabelFor(AnnualPlanFuturePrereqId id) => switch (id) {
    AnnualPlanFuturePrereqId.monthlySandboxPurchaseProofComplete =>
      'Monthly sandbox purchase proof complete',
    AnnualPlanFuturePrereqId.paidIntentBetaShowsValue =>
      'Paid-intent beta shows value',
  };

  static String ruleLabelFor(AnnualPlanFutureRuleId id) => switch (id) {
    AnnualPlanFutureRuleId.noAnnualRevenueCatProductNow =>
      'No annual RevenueCat product now',
    AnnualPlanFutureRuleId.noPaywallChangesNow => 'No paywall changes now',
    AnnualPlanFutureRuleId.annualPlanRequiresMonthlySandboxPurchaseProof =>
      'Annual plan requires monthly sandbox purchase proof first',
    AnnualPlanFutureRuleId.annualPlanRequiresPaidIntentBetaValue =>
      'Annual plan requires paid-intent beta showing value',
    AnnualPlanFutureRuleId.copyFocusesOnLongerProofTrailForYear =>
      'Copy focuses on longer proof trail for the year',
  };

  static String messageFor(AnnualPlanFutureGateDecision decision) =>
      switch (decision) {
        AnnualPlanFutureGateDecision.annualPlanFrozen => annualPlanFrozenLine,
        AnnualPlanFutureGateDecision.annualPlanDocumented =>
          annualPlanDocumentedLine,
      };

  static String recommendationFor(
    AnnualPlanFutureGateDecision decision,
  ) => switch (decision) {
    AnnualPlanFutureGateDecision.annualPlanFrozen =>
      'Keep monthly Pro offer until sandbox purchase proof and paid-intent beta value land.',
    AnnualPlanFutureGateDecision.annualPlanDocumented =>
      'Document annual plan as future revenue test only. Do not add annual RevenueCat product or paywall changes yet.',
  };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield positioning;
    yield futureAnnualPlanLine;
    yield yearTrailFocusCopy;
    yield orderLine;
    yield prereqOrderLine;
    yield guardrail;
    yield annualPlanFrozenLine;
    yield annualPlanDocumentedLine;
    yield detailPass;
    yield detailPending;
    yield detailFail;
    yield detailBlockedBeforeProof;
    yield detailFutureAnnualPlanDocumented;
    for (final id in AnnualPlanFuturePrereqId.values) {
      yield prereqLabelFor(id);
    }
    for (final id in AnnualPlanFutureRuleId.values) {
      yield ruleLabelFor(id);
    }
    for (final decision in AnnualPlanFutureGateDecision.values) {
      yield messageFor(decision);
      yield recommendationFor(decision);
    }
  }
}

enum AnnualPlanFuturePrereqId {
  monthlySandboxPurchaseProofComplete,
  paidIntentBetaShowsValue,
}

enum AnnualPlanFuturePrereqStatus { pass, pending, fail }

enum AnnualPlanFutureRuleId {
  noAnnualRevenueCatProductNow,
  noPaywallChangesNow,
  annualPlanRequiresMonthlySandboxPurchaseProof,
  annualPlanRequiresPaidIntentBetaValue,
  copyFocusesOnLongerProofTrailForYear,
}

enum AnnualPlanFutureRuleStatus { pass, fail }

enum AnnualPlanFuturePlanStatus {
  blockedBeforeProof,
  futureAnnualPlanDocumented,
}

enum AnnualPlanFutureGateDecision { annualPlanFrozen, annualPlanDocumented }
