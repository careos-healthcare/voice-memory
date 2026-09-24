/// Premium tiers future copy — prevent higher-tier complexity before simple Pro converts.
abstract final class PremiumTiersFutureCopy {
  PremiumTiersFutureCopy._();

  static const headline = 'Premium tiers future gate';

  static const body =
      'Prevent higher-tier complexity before simple Pro converts. '
      'Classification and documentation only.';

  static const positioning =
      'Premium tiers stay future ideas only — simple Pro must convert before higher-tier planning.';

  static const futureTierIdeasLine =
      'Future tier ideas: longer history, reports/export, cross-device sync, private backup, advanced search.';

  static const orderLine =
      'Rules: no new products or prices now, no RevenueCat product changes, no tier UI, '
      'higher tiers require simple Pro purchase proof first.';

  static const prereqOrderLine =
      'Prerequisites: simple Pro purchase proof complete.';

  static const guardrail =
      'Premium tiers future gate classifies future tier ideas only. Do not add new products or prices now. '
      'Do not change RevenueCat products. Do not add tier UI. Higher tiers require simple Pro purchase proof first.';

  static const tiersFrozenLine =
      'Keep premium tiers frozen until simple Pro purchase proof is complete.';

  static const futureTiersDocumentedLine =
      'Simple Pro purchase proof complete. Document premium tiers as future ideas only — no new products, prices, or tier UI.';

  static const detailPass = 'Pass';
  static const detailPending = 'Pending';
  static const detailFail = 'Fail';

  static const detailBlockedBeforeProProof =
      'Blocked before simple Pro purchase proof';
  static const detailFutureTierDocumented = 'Future tier documented only';

  static String labelFor(PremiumTierFutureId id) => switch (id) {
    PremiumTierFutureId.longerHistory => 'Longer history',
    PremiumTierFutureId.reportsExport => 'Reports/export',
    PremiumTierFutureId.crossDeviceSync => 'Cross-device sync',
    PremiumTierFutureId.privateBackup => 'Private backup',
    PremiumTierFutureId.advancedSearch => 'Advanced search',
  };

  static String positioningFor(PremiumTierFutureId id) => switch (id) {
    PremiumTierFutureId.longerHistory =>
      'Future longer history tier — after simple Pro converts.',
    PremiumTierFutureId.reportsExport =>
      'Future reports/export tier — after simple Pro converts.',
    PremiumTierFutureId.crossDeviceSync =>
      'Future cross-device sync tier — after simple Pro converts.',
    PremiumTierFutureId.privateBackup =>
      'Future private backup tier — after simple Pro converts.',
    PremiumTierFutureId.advancedSearch =>
      'Future advanced search tier — after simple Pro converts.',
  };

  static String prereqLabelFor(PremiumTiersFuturePrereqId id) => switch (id) {
    PremiumTiersFuturePrereqId.simpleProPurchaseProofComplete =>
      'Simple Pro purchase proof complete',
  };

  static String ruleLabelFor(PremiumTiersFutureRuleId id) => switch (id) {
    PremiumTiersFutureRuleId.noNewProductsOrPricesNow =>
      'No new products or prices now',
    PremiumTiersFutureRuleId.noRevenueCatProductChanges =>
      'No RevenueCat product changes',
    PremiumTiersFutureRuleId.noTierUi => 'No tier UI',
    PremiumTiersFutureRuleId.higherTiersRequireSimpleProPurchaseProof =>
      'Higher tiers require simple Pro purchase proof first',
  };

  static String messageFor(PremiumTiersFutureGateDecision decision) =>
      switch (decision) {
        PremiumTiersFutureGateDecision.tiersFrozen => tiersFrozenLine,
        PremiumTiersFutureGateDecision.futureTiersDocumented =>
          futureTiersDocumentedLine,
      };

  static String recommendationFor(
    PremiumTiersFutureGateDecision decision,
  ) => switch (decision) {
    PremiumTiersFutureGateDecision.tiersFrozen =>
      'Keep one simple Pro offer until purchase proof lands. Do not add products, prices, or tier UI.',
    PremiumTiersFutureGateDecision.futureTiersDocumented =>
      'Document premium tiers as future ideas only. Keep RevenueCat products unchanged until tier strategy is proven.',
  };

  static Iterable<String> allVisibleStrings() sync* {
    yield headline;
    yield body;
    yield positioning;
    yield futureTierIdeasLine;
    yield orderLine;
    yield prereqOrderLine;
    yield guardrail;
    yield tiersFrozenLine;
    yield futureTiersDocumentedLine;
    yield detailPass;
    yield detailPending;
    yield detailFail;
    yield detailBlockedBeforeProProof;
    yield detailFutureTierDocumented;
    for (final id in PremiumTierFutureId.values) {
      yield labelFor(id);
      yield positioningFor(id);
    }
    for (final id in PremiumTiersFuturePrereqId.values) {
      yield prereqLabelFor(id);
    }
    for (final id in PremiumTiersFutureRuleId.values) {
      yield ruleLabelFor(id);
    }
    for (final decision in PremiumTiersFutureGateDecision.values) {
      yield messageFor(decision);
      yield recommendationFor(decision);
    }
  }
}

enum PremiumTierFutureId {
  longerHistory,
  reportsExport,
  crossDeviceSync,
  privateBackup,
  advancedSearch,
}

enum PremiumTierFutureStatus { blockedBeforeProProof, futureTierDocumented }

enum PremiumTiersFuturePrereqId { simpleProPurchaseProofComplete }

enum PremiumTiersFuturePrereqStatus { pass, pending, fail }

enum PremiumTiersFutureRuleId {
  noNewProductsOrPricesNow,
  noRevenueCatProductChanges,
  noTierUi,
  higherTiersRequireSimpleProPurchaseProof,
}

enum PremiumTiersFutureRuleStatus { pass, fail }

enum PremiumTiersFutureGateDecision { tiersFrozen, futureTiersDocumented }
