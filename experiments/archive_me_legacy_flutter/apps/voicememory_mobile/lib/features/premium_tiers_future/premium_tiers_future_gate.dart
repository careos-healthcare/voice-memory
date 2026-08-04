import '../paid_intent_beta_proof/paid_intent_beta_proof.dart';
import '../single_launch_checklist/single_launch_checklist.dart';
import 'premium_tiers_future_copy.dart';

/// Premium tiers future gate — prevent higher-tier complexity before simple Pro converts.
abstract final class PremiumTiersFutureGate {
  PremiumTiersFutureGate._();

  static const tierCount = 5;
  static const prereqCount = 1;
  static const ruleCount = 4;

  static const canonicalTierOrder = [
    PremiumTierFutureId.longerHistory,
    PremiumTierFutureId.reportsExport,
    PremiumTierFutureId.crossDeviceSync,
    PremiumTierFutureId.privateBackup,
    PremiumTierFutureId.advancedSearch,
  ];

  static const canonicalFutureTierIdeas = [
    'longer history',
    'reports/export',
    'cross-device sync',
    'private backup',
    'advanced search',
  ];

  static const canonicalPrereqOrder = [
    PremiumTiersFuturePrereqId.simpleProPurchaseProofComplete,
  ];

  static const canonicalRuleOrder = [
    PremiumTiersFutureRuleId.noNewProductsOrPricesNow,
    PremiumTiersFutureRuleId.noRevenueCatProductChanges,
    PremiumTiersFutureRuleId.noTierUi,
    PremiumTiersFutureRuleId.higherTiersRequireSimpleProPurchaseProof,
  ];

  static const newProductsOrPricesViolationMarkers = [
    'add new product',
    'new price tier',
    'create a premium plus',
    'introducing pro plus',
    'new subscription tier',
  ];

  static const revenueCatProductChangeViolationMarkers = [
    'change revenuecat products',
    'add new offering',
    'new entitlement tier',
    'create a second subscription',
  ];

  static const tierUiViolationMarkers = [
    'tier comparison screen',
    'choose your tier',
    'upgrade to premium plus',
    'pick your plan tier',
  ];

  static PremiumTiersFutureGateResult build(PremiumTiersFutureGateInput input) {
    final rules = _buildRules(input);
    final prereqs = _buildPrereqs(input);
    final rulesPass = rules.every(
      (rule) => rule.status == PremiumTiersFutureRuleStatus.pass,
    );
    final proPurchaseProofComplete = prereqs.every(
      (prereq) => prereq.status == PremiumTiersFuturePrereqStatus.pass,
    );
    final decision = rulesPass && proPurchaseProofComplete
        ? PremiumTiersFutureGateDecision.futureTiersDocumented
        : PremiumTiersFutureGateDecision.tiersFrozen;
    final tiers = _buildTiers(
      proPurchaseProofComplete: proPurchaseProofComplete,
    );
    return PremiumTiersFutureGateResult(
      decision: decision,
      message: PremiumTiersFutureCopy.messageFor(decision),
      recommendation: PremiumTiersFutureCopy.recommendationFor(decision),
      positioning: PremiumTiersFutureCopy.positioning,
      futureTierIdeas: canonicalFutureTierIdeas,
      rules: rules,
      ruleOrder: canonicalRuleOrder,
      rulesPass: rulesPass,
      prereqs: prereqs,
      prereqOrder: canonicalPrereqOrder,
      tiers: tiers,
      tierOrder: canonicalTierOrder,
      proPurchaseProofComplete: proPurchaseProofComplete,
      newProductsBlocked: true,
      revenueCatChangesBlocked: true,
      tierUiBlocked: true,
      earliestPrereqGap: prereqs
          .where(
            (prereq) => prereq.status != PremiumTiersFuturePrereqStatus.pass,
          )
          .map((prereq) => prereq.id)
          .firstOrNull,
      earliestRuleFailure: rules
          .where((rule) => rule.status == PremiumTiersFutureRuleStatus.fail)
          .map((rule) => rule.id)
          .firstOrNull,
      documentedTierCount: tiers
          .where(
            (tier) =>
                tier.status == PremiumTierFutureStatus.futureTierDocumented,
          )
          .length,
      blockedTierCount: tiers
          .where(
            (tier) =>
                tier.status == PremiumTierFutureStatus.blockedBeforeProProof,
          )
          .length,
    );
  }

  static PremiumTiersFutureGateReport report(
    PremiumTiersFutureGateResult result,
  ) => PremiumTiersFutureGateReport(
    headline: PremiumTiersFutureCopy.headline,
    body: PremiumTiersFutureCopy.body,
    positioning: PremiumTiersFutureCopy.positioning,
    futureTierIdeasLine: PremiumTiersFutureCopy.futureTierIdeasLine,
    orderLine: PremiumTiersFutureCopy.orderLine,
    prereqOrderLine: PremiumTiersFutureCopy.prereqOrderLine,
    guardrail: PremiumTiersFutureCopy.guardrail,
    result: result,
  );

  static PremiumTiersFutureGateInput composeInput({
    bool? simpleProPurchaseProofComplete,
    bool? tierUiRequested,
    bool? higherTierExpansionRequested,
    SingleLaunchChecklistInput? launchChecklist,
    PaidIntentBetaProofResult? paidIntentBeta,
  }) => PremiumTiersFutureGateInput(
    simpleProPurchaseProofComplete:
        simpleProPurchaseProofComplete ??
        launchChecklist?.sandboxPurchaseWorks ??
        _simpleProPurchaseProofFrom(paidIntentBeta),
    tierUiRequested: tierUiRequested,
    higherTierExpansionRequested: higherTierExpansionRequested,
  );

  static PremiumTiersFutureGateInput fromRepoSignals({
    required String premiumTiersFutureDocSource,
    required String gateCopySource,
    bool? simpleProPurchaseProofComplete,
    bool? tierUiRequested,
    bool? higherTierExpansionRequested,
  }) => PremiumTiersFutureGateInput(
    simpleProPurchaseProofComplete: simpleProPurchaseProofComplete,
    tierUiRequested: tierUiRequested,
    higherTierExpansionRequested: higherTierExpansionRequested,
    docListsRules: detectDocListsRules(premiumTiersFutureDocSource),
    guardrailPresentInCopy: detectGuardrailPresentInCopy(gateCopySource),
    futureTierIdeasPresentInCopy: detectFutureTierIdeasPresentInCopy(
      gateCopySource,
    ),
  );

  static bool detectDocListsRules(String docSource) {
    const markers = [
      'longer history',
      'reports/export',
      'cross-device sync',
      'private backup',
      'advanced search',
      'no new products or prices',
      'no revenuecat product changes',
      'no tier ui',
      'simple pro purchase proof',
      'premium tiers future',
    ];
    final lower = docSource.toLowerCase();
    return markers.every(lower.contains);
  }

  static bool detectGuardrailPresentInCopy(String gateCopySource) {
    final lower = gateCopySource.toLowerCase();
    return lower.contains('premium tiers future') &&
        lower.contains('do not add new products or prices now') &&
        lower.contains('do not change revenuecat products') &&
        lower.contains('do not add tier ui') &&
        lower.contains('simple pro purchase proof first');
  }

  static bool detectFutureTierIdeasPresentInCopy(String gateCopySource) {
    final lower = gateCopySource.toLowerCase();
    return canonicalFutureTierIdeas.every(lower.contains);
  }

  static bool evaluateCopyPassesRules(String copy) =>
      !_violatesNewProductsOrPrices(copy) &&
      !_violatesRevenueCatProductChanges(copy) &&
      !_violatesTierUi(copy);

  static bool? _simpleProPurchaseProofFrom(PaidIntentBetaProofResult? result) =>
      _signalPassed(result, PaidIntentBetaProofSignalId.purchaseCompleted);

  static bool? _signalPassed(
    PaidIntentBetaProofResult? result,
    PaidIntentBetaProofSignalId id,
  ) {
    if (result == null) return null;
    for (final signal in result.signals) {
      if (signal.id == id) {
        return signal.status == PaidIntentBetaProofSignalStatus.pass;
      }
    }
    return null;
  }

  static List<PremiumTiersFutureRule> _buildRules(
    PremiumTiersFutureGateInput input,
  ) {
    final copyBundle = [
      PremiumTiersFutureCopy.positioning,
      PremiumTiersFutureCopy.futureTierIdeasLine,
      PremiumTiersFutureCopy.guardrail,
      PremiumTiersFutureCopy.body,
    ].join(' ');
    final guardrailLower = PremiumTiersFutureCopy.guardrail.toLowerCase();
    final proPurchaseProofComplete =
        input.simpleProPurchaseProofComplete ?? false;
    return [
      _rule(
        id: PremiumTiersFutureRuleId.noNewProductsOrPricesNow,
        passes:
            evaluateCopyPassesRules(copyBundle) &&
            guardrailLower.contains('do not add new products or prices now'),
      ),
      _rule(
        id: PremiumTiersFutureRuleId.noRevenueCatProductChanges,
        passes:
            evaluateCopyPassesRules(copyBundle) &&
            guardrailLower.contains('do not change revenuecat products'),
      ),
      _rule(
        id: PremiumTiersFutureRuleId.noTierUi,
        passes:
            guardrailLower.contains('do not add tier ui') &&
            (!(input.tierUiRequested ?? false) || proPurchaseProofComplete),
      ),
      _rule(
        id: PremiumTiersFutureRuleId.higherTiersRequireSimpleProPurchaseProof,
        passes:
            guardrailLower.contains('simple pro purchase proof first') &&
            (!(input.higherTierExpansionRequested ?? false) ||
                proPurchaseProofComplete),
      ),
    ];
  }

  static List<PremiumTiersFuturePrereq> _buildPrereqs(
    PremiumTiersFutureGateInput input,
  ) => [
    _prereq(
      id: PremiumTiersFuturePrereqId.simpleProPurchaseProofComplete,
      value: input.simpleProPurchaseProofComplete,
    ),
  ];

  static List<PremiumTierFuture> _buildTiers({
    required bool proPurchaseProofComplete,
  }) => canonicalTierOrder
      .map(
        (id) => PremiumTierFuture(
          id: id,
          label: PremiumTiersFutureCopy.labelFor(id),
          positioning: PremiumTiersFutureCopy.positioningFor(id),
          status: proPurchaseProofComplete
              ? PremiumTierFutureStatus.futureTierDocumented
              : PremiumTierFutureStatus.blockedBeforeProProof,
          detailLabel: proPurchaseProofComplete
              ? PremiumTiersFutureCopy.detailFutureTierDocumented
              : PremiumTiersFutureCopy.detailBlockedBeforeProProof,
        ),
      )
      .toList();

  static bool _violatesNewProductsOrPrices(String copy) {
    final lower = copy.toLowerCase();
    for (final marker in newProductsOrPricesViolationMarkers) {
      var index = 0;
      while (true) {
        index = lower.indexOf(marker, index);
        if (index < 0) break;
        if (!_markerInProhibitionContext(lower, index)) return true;
        index += marker.length;
      }
    }
    return false;
  }

  static bool _violatesRevenueCatProductChanges(String copy) {
    final lower = copy.toLowerCase();
    for (final marker in revenueCatProductChangeViolationMarkers) {
      var index = 0;
      while (true) {
        index = lower.indexOf(marker, index);
        if (index < 0) break;
        if (!_markerInProhibitionContext(lower, index)) return true;
        index += marker.length;
      }
    }
    return false;
  }

  static bool _violatesTierUi(String copy) =>
      tierUiViolationMarkers.any(copy.toLowerCase().contains);

  static bool _markerInProhibitionContext(String lower, int markerStart) {
    final prefix = lower.substring(0, markerStart);
    const prohibitionMarkers = ['avoid ', 'without ', 'never ', 'no ', 'not '];
    for (final marker in prohibitionMarkers) {
      final index = prefix.lastIndexOf(marker);
      if (index < 0) continue;
      final between = prefix.substring(index + marker.length);
      if (!between.contains('. ')) return true;
    }
    return false;
  }

  static PremiumTiersFuturePrereqStatus _statusFor(bool? value) =>
      switch (value) {
        true => PremiumTiersFuturePrereqStatus.pass,
        false => PremiumTiersFuturePrereqStatus.fail,
        null => PremiumTiersFuturePrereqStatus.pending,
      };

  static PremiumTiersFuturePrereq _prereq({
    required PremiumTiersFuturePrereqId id,
    required bool? value,
  }) {
    final status = _statusFor(value);
    return PremiumTiersFuturePrereq(
      id: id,
      label: PremiumTiersFutureCopy.prereqLabelFor(id),
      status: status,
      detailLabel: switch (status) {
        PremiumTiersFuturePrereqStatus.pass =>
          PremiumTiersFutureCopy.detailPass,
        PremiumTiersFuturePrereqStatus.pending =>
          PremiumTiersFutureCopy.detailPending,
        PremiumTiersFuturePrereqStatus.fail =>
          PremiumTiersFutureCopy.detailFail,
      },
    );
  }

  static PremiumTiersFutureRule _rule({
    required PremiumTiersFutureRuleId id,
    required bool passes,
  }) => PremiumTiersFutureRule(
    id: id,
    label: PremiumTiersFutureCopy.ruleLabelFor(id),
    status: passes
        ? PremiumTiersFutureRuleStatus.pass
        : PremiumTiersFutureRuleStatus.fail,
    detailLabel: passes
        ? PremiumTiersFutureCopy.detailPass
        : PremiumTiersFutureCopy.detailFail,
  );
}

class PremiumTiersFutureGateInput {
  const PremiumTiersFutureGateInput({
    this.simpleProPurchaseProofComplete,
    this.tierUiRequested,
    this.higherTierExpansionRequested,
    this.docListsRules = true,
    this.guardrailPresentInCopy = true,
    this.futureTierIdeasPresentInCopy = true,
  });

  final bool? simpleProPurchaseProofComplete;
  final bool? tierUiRequested;
  final bool? higherTierExpansionRequested;
  final bool docListsRules;
  final bool guardrailPresentInCopy;
  final bool futureTierIdeasPresentInCopy;
}

class PremiumTiersFutureRule {
  const PremiumTiersFutureRule({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final PremiumTiersFutureRuleId id;
  final String label;
  final PremiumTiersFutureRuleStatus status;
  final String detailLabel;
}

class PremiumTiersFuturePrereq {
  const PremiumTiersFuturePrereq({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final PremiumTiersFuturePrereqId id;
  final String label;
  final PremiumTiersFuturePrereqStatus status;
  final String detailLabel;
}

class PremiumTierFuture {
  const PremiumTierFuture({
    required this.id,
    required this.label,
    required this.positioning,
    required this.status,
    required this.detailLabel,
  });

  final PremiumTierFutureId id;
  final String label;
  final String positioning;
  final PremiumTierFutureStatus status;
  final String detailLabel;
}

class PremiumTiersFutureGateResult {
  const PremiumTiersFutureGateResult({
    required this.decision,
    required this.message,
    required this.recommendation,
    required this.positioning,
    required this.futureTierIdeas,
    required this.rules,
    required this.ruleOrder,
    required this.rulesPass,
    required this.prereqs,
    required this.prereqOrder,
    required this.tiers,
    required this.tierOrder,
    required this.proPurchaseProofComplete,
    required this.newProductsBlocked,
    required this.revenueCatChangesBlocked,
    required this.tierUiBlocked,
    required this.earliestPrereqGap,
    required this.earliestRuleFailure,
    required this.documentedTierCount,
    required this.blockedTierCount,
  });

  final PremiumTiersFutureGateDecision decision;
  final String message;
  final String recommendation;
  final String positioning;
  final List<String> futureTierIdeas;
  final List<PremiumTiersFutureRule> rules;
  final List<PremiumTiersFutureRuleId> ruleOrder;
  final bool rulesPass;
  final List<PremiumTiersFuturePrereq> prereqs;
  final List<PremiumTiersFuturePrereqId> prereqOrder;
  final List<PremiumTierFuture> tiers;
  final List<PremiumTierFutureId> tierOrder;
  final bool proPurchaseProofComplete;
  final bool newProductsBlocked;
  final bool revenueCatChangesBlocked;
  final bool tierUiBlocked;
  final PremiumTiersFuturePrereqId? earliestPrereqGap;
  final PremiumTiersFutureRuleId? earliestRuleFailure;
  final int documentedTierCount;
  final int blockedTierCount;
}

class PremiumTiersFutureGateReport {
  const PremiumTiersFutureGateReport({
    required this.headline,
    required this.body,
    required this.positioning,
    required this.futureTierIdeasLine,
    required this.orderLine,
    required this.prereqOrderLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String positioning;
  final String futureTierIdeasLine;
  final String orderLine;
  final String prereqOrderLine;
  final String guardrail;
  final PremiumTiersFutureGateResult result;
}
