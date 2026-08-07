import '../paid_intent_beta_proof/paid_intent_beta_proof.dart';
import '../single_launch_checklist/single_launch_checklist.dart';
import 'annual_plan_future_copy.dart';

/// Annual plan future gate — annual plan as future revenue test only.
abstract final class AnnualPlanFutureGate {
  AnnualPlanFutureGate._();

  static const prereqCount = 2;
  static const ruleCount = 5;

  static const canonicalPrereqOrder = [
    AnnualPlanFuturePrereqId.monthlySandboxPurchaseProofComplete,
    AnnualPlanFuturePrereqId.paidIntentBetaShowsValue,
  ];

  static const canonicalRuleOrder = [
    AnnualPlanFutureRuleId.noAnnualRevenueCatProductNow,
    AnnualPlanFutureRuleId.noPaywallChangesNow,
    AnnualPlanFutureRuleId.annualPlanRequiresMonthlySandboxPurchaseProof,
    AnnualPlanFutureRuleId.annualPlanRequiresPaidIntentBetaValue,
    AnnualPlanFutureRuleId.copyFocusesOnLongerProofTrailForYear,
  ];

  static const annualRevenueCatProductViolationMarkers = [
    'add annual revenuecat product',
    'new annual subscription',
    'annual revenuecat offering',
    'create annual entitlement',
  ];

  static const paywallChangeViolationMarkers = [
    'change the paywall',
    'redesign paywall',
    'new paywall layout',
    'update paywall pricing ui',
  ];

  static AnnualPlanFutureGateResult build(AnnualPlanFutureGateInput input) {
    final rules = _buildRules(input);
    final prereqs = _buildPrereqs(input);
    final rulesPass = rules.every(
      (rule) => rule.status == AnnualPlanFutureRuleStatus.pass,
    );
    final prereqsComplete = prereqs.every(
      (prereq) => prereq.status == AnnualPlanFuturePrereqStatus.pass,
    );
    final decision = rulesPass && prereqsComplete
        ? AnnualPlanFutureGateDecision.annualPlanDocumented
        : AnnualPlanFutureGateDecision.annualPlanFrozen;
    final plan = _buildPlan(prereqsComplete: prereqsComplete);
    return AnnualPlanFutureGateResult(
      decision: decision,
      message: AnnualPlanFutureCopy.messageFor(decision),
      recommendation: AnnualPlanFutureCopy.recommendationFor(decision),
      positioning: AnnualPlanFutureCopy.positioning,
      yearTrailFocusCopy: AnnualPlanFutureCopy.yearTrailFocusCopy,
      rules: rules,
      ruleOrder: canonicalRuleOrder,
      rulesPass: rulesPass,
      prereqs: prereqs,
      prereqOrder: canonicalPrereqOrder,
      plan: plan,
      prereqsComplete: prereqsComplete,
      annualRevenueCatProductBlocked: true,
      paywallChangesBlocked: true,
      earliestPrereqGap: prereqs
          .where((prereq) => prereq.status != AnnualPlanFuturePrereqStatus.pass)
          .map((prereq) => prereq.id)
          .firstOrNull,
      earliestRuleFailure: rules
          .where((rule) => rule.status == AnnualPlanFutureRuleStatus.fail)
          .map((rule) => rule.id)
          .firstOrNull,
    );
  }

  static AnnualPlanFutureGateReport report(AnnualPlanFutureGateResult result) =>
      AnnualPlanFutureGateReport(
        headline: AnnualPlanFutureCopy.headline,
        body: AnnualPlanFutureCopy.body,
        positioning: AnnualPlanFutureCopy.positioning,
        futureAnnualPlanLine: AnnualPlanFutureCopy.futureAnnualPlanLine,
        orderLine: AnnualPlanFutureCopy.orderLine,
        prereqOrderLine: AnnualPlanFutureCopy.prereqOrderLine,
        guardrail: AnnualPlanFutureCopy.guardrail,
        result: result,
      );

  static AnnualPlanFutureGateInput composeInput({
    bool? monthlySandboxPurchaseProofComplete,
    bool? paidIntentBetaShowsValue,
    bool? annualRevenueCatProductRequested,
    bool? paywallChangeRequested,
    bool? annualPlanRequested,
    bool? annualCopyMissingYearTrailFocus,
    SingleLaunchChecklistInput? launchChecklist,
    PaidIntentBetaProofResult? paidIntentBeta,
  }) => AnnualPlanFutureGateInput(
    monthlySandboxPurchaseProofComplete:
        monthlySandboxPurchaseProofComplete ??
        launchChecklist?.sandboxPurchaseWorks ??
        _monthlyPurchaseProofFrom(paidIntentBeta),
    paidIntentBetaShowsValue:
        paidIntentBetaShowsValue ??
        _paidIntentBetaShowsValueFrom(paidIntentBeta),
    annualRevenueCatProductRequested: annualRevenueCatProductRequested,
    paywallChangeRequested: paywallChangeRequested,
    annualPlanRequested: annualPlanRequested,
    annualCopyMissingYearTrailFocus: annualCopyMissingYearTrailFocus,
  );

  static AnnualPlanFutureGateInput fromRepoSignals({
    required String annualPlanFutureDocSource,
    required String gateCopySource,
    bool? monthlySandboxPurchaseProofComplete,
    bool? paidIntentBetaShowsValue,
    bool? annualRevenueCatProductRequested,
    bool? paywallChangeRequested,
    bool? annualPlanRequested,
    bool? annualCopyMissingYearTrailFocus,
  }) => AnnualPlanFutureGateInput(
    monthlySandboxPurchaseProofComplete: monthlySandboxPurchaseProofComplete,
    paidIntentBetaShowsValue: paidIntentBetaShowsValue,
    annualRevenueCatProductRequested: annualRevenueCatProductRequested,
    paywallChangeRequested: paywallChangeRequested,
    annualPlanRequested: annualPlanRequested,
    annualCopyMissingYearTrailFocus: annualCopyMissingYearTrailFocus,
    docListsRules: detectDocListsRules(annualPlanFutureDocSource),
    guardrailPresentInCopy: detectGuardrailPresentInCopy(gateCopySource),
    yearTrailFocusPresentInCopy: detectYearTrailFocusPresentInCopy(
      gateCopySource,
    ),
  );

  static bool detectDocListsRules(String docSource) {
    const markers = [
      'annual plan future',
      'no annual revenuecat product',
      'no paywall changes',
      'monthly sandbox purchase proof',
      'paid-intent beta',
      'longer proof trail for the year',
      'future revenue test',
    ];
    final lower = docSource.toLowerCase();
    return markers.every(lower.contains);
  }

  static bool detectGuardrailPresentInCopy(String gateCopySource) {
    final lower = gateCopySource.toLowerCase();
    return lower.contains('annual plan future gate') &&
        lower.contains('do not add annual revenuecat product now') &&
        lower.contains('do not change paywall now') &&
        lower.contains('monthly sandbox purchase proof first') &&
        lower.contains('paid-intent beta showing value') &&
        lower.contains('longer proof trail for the year');
  }

  static bool detectYearTrailFocusPresentInCopy(String gateCopySource) {
    final lower = gateCopySource.toLowerCase();
    return lower.contains(
      AnnualPlanFutureCopy.yearTrailFocusCopy.toLowerCase(),
    );
  }

  static bool evaluateCopyPassesRules(String copy) =>
      !_violatesAnnualRevenueCatProduct(copy) && !_violatesPaywallChanges(copy);

  static bool? _monthlyPurchaseProofFrom(PaidIntentBetaProofResult? result) =>
      _signalPassed(result, PaidIntentBetaProofSignalId.purchaseCompleted);

  static bool? _paidIntentBetaShowsValueFrom(
    PaidIntentBetaProofResult? result,
  ) {
    if (result == null) return null;
    final proofSeen =
        _signalPassed(
          result,
          PaidIntentBetaProofSignalId.firstUsefulProofSeen,
        ) ??
        false;
    final proofUseful =
        _signalPassed(
          result,
          PaidIntentBetaProofSignalId.proofAcceptedOrCorrected,
        ) ??
        false;
    if (proofSeen && proofUseful) return true;
    if (result.paidIntentSignalPromising) return true;
    if (proofSeen == false || proofUseful == false) return false;
    return null;
  }

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

  static AnnualPlanFuturePlan _buildPlan({required bool prereqsComplete}) =>
      AnnualPlanFuturePlan(
        label: 'Future annual plan',
        positioning: AnnualPlanFutureCopy.futureAnnualPlanLine,
        yearTrailFocusCopy: AnnualPlanFutureCopy.yearTrailFocusCopy,
        status: prereqsComplete
            ? AnnualPlanFuturePlanStatus.futureAnnualPlanDocumented
            : AnnualPlanFuturePlanStatus.blockedBeforeProof,
        detailLabel: prereqsComplete
            ? AnnualPlanFutureCopy.detailFutureAnnualPlanDocumented
            : AnnualPlanFutureCopy.detailBlockedBeforeProof,
      );

  static List<AnnualPlanFutureRule> _buildRules(
    AnnualPlanFutureGateInput input,
  ) {
    final copyBundle = [
      AnnualPlanFutureCopy.positioning,
      AnnualPlanFutureCopy.futureAnnualPlanLine,
      AnnualPlanFutureCopy.yearTrailFocusCopy,
      AnnualPlanFutureCopy.guardrail,
      AnnualPlanFutureCopy.body,
    ].join(' ');
    final guardrailLower = AnnualPlanFutureCopy.guardrail.toLowerCase();
    final monthlyProofComplete =
        input.monthlySandboxPurchaseProofComplete ?? false;
    final paidIntentValue = input.paidIntentBetaShowsValue ?? false;
    return [
      _rule(
        id: AnnualPlanFutureRuleId.noAnnualRevenueCatProductNow,
        passes:
            guardrailLower.contains(
              'do not add annual revenuecat product now',
            ) &&
            evaluateCopyPassesRules(copyBundle) &&
            !(input.annualRevenueCatProductRequested ?? false),
      ),
      _rule(
        id: AnnualPlanFutureRuleId.noPaywallChangesNow,
        passes:
            guardrailLower.contains('do not change paywall now') &&
            evaluateCopyPassesRules(copyBundle) &&
            !(input.paywallChangeRequested ?? false),
      ),
      _rule(
        id: AnnualPlanFutureRuleId
            .annualPlanRequiresMonthlySandboxPurchaseProof,
        passes:
            guardrailLower.contains('monthly sandbox purchase proof first') &&
            (!(input.annualPlanRequested ?? false) || monthlyProofComplete),
      ),
      _rule(
        id: AnnualPlanFutureRuleId.annualPlanRequiresPaidIntentBetaValue,
        passes:
            guardrailLower.contains('paid-intent beta showing value') &&
            (!(input.annualPlanRequested ?? false) || paidIntentValue),
      ),
      _rule(
        id: AnnualPlanFutureRuleId.copyFocusesOnLongerProofTrailForYear,
        passes:
            guardrailLower.contains('longer proof trail for the year') &&
            copyBundle.contains(AnnualPlanFutureCopy.yearTrailFocusCopy) &&
            !(input.annualCopyMissingYearTrailFocus ?? false),
      ),
    ];
  }

  static List<AnnualPlanFuturePrereq> _buildPrereqs(
    AnnualPlanFutureGateInput input,
  ) => [
    _prereq(
      id: AnnualPlanFuturePrereqId.monthlySandboxPurchaseProofComplete,
      value: input.monthlySandboxPurchaseProofComplete,
    ),
    _prereq(
      id: AnnualPlanFuturePrereqId.paidIntentBetaShowsValue,
      value: input.paidIntentBetaShowsValue,
    ),
  ];

  static bool _violatesAnnualRevenueCatProduct(String copy) {
    final lower = copy.toLowerCase();
    for (final marker in annualRevenueCatProductViolationMarkers) {
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

  static bool _violatesPaywallChanges(String copy) {
    final lower = copy.toLowerCase();
    for (final marker in paywallChangeViolationMarkers) {
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

  static bool _markerInProhibitionContext(String lower, int markerStart) {
    final prefix = lower.substring(0, markerStart);
    const prohibitionMarkers = [
      'avoid ',
      'without ',
      'never ',
      'no ',
      'not ',
      'do not ',
    ];
    for (final marker in prohibitionMarkers) {
      final index = prefix.lastIndexOf(marker);
      if (index < 0) continue;
      final between = prefix.substring(index + marker.length);
      if (!between.contains('. ')) return true;
    }
    return false;
  }

  static AnnualPlanFuturePrereqStatus _statusFor(bool? value) =>
      switch (value) {
        true => AnnualPlanFuturePrereqStatus.pass,
        false => AnnualPlanFuturePrereqStatus.fail,
        null => AnnualPlanFuturePrereqStatus.pending,
      };

  static AnnualPlanFuturePrereq _prereq({
    required AnnualPlanFuturePrereqId id,
    required bool? value,
  }) {
    final status = _statusFor(value);
    return AnnualPlanFuturePrereq(
      id: id,
      label: AnnualPlanFutureCopy.prereqLabelFor(id),
      status: status,
      detailLabel: switch (status) {
        AnnualPlanFuturePrereqStatus.pass => AnnualPlanFutureCopy.detailPass,
        AnnualPlanFuturePrereqStatus.pending =>
          AnnualPlanFutureCopy.detailPending,
        AnnualPlanFuturePrereqStatus.fail => AnnualPlanFutureCopy.detailFail,
      },
    );
  }

  static AnnualPlanFutureRule _rule({
    required AnnualPlanFutureRuleId id,
    required bool passes,
  }) => AnnualPlanFutureRule(
    id: id,
    label: AnnualPlanFutureCopy.ruleLabelFor(id),
    status: passes
        ? AnnualPlanFutureRuleStatus.pass
        : AnnualPlanFutureRuleStatus.fail,
    detailLabel: passes
        ? AnnualPlanFutureCopy.detailPass
        : AnnualPlanFutureCopy.detailFail,
  );
}

class AnnualPlanFutureGateInput {
  const AnnualPlanFutureGateInput({
    this.monthlySandboxPurchaseProofComplete,
    this.paidIntentBetaShowsValue,
    this.annualRevenueCatProductRequested,
    this.paywallChangeRequested,
    this.annualPlanRequested,
    this.annualCopyMissingYearTrailFocus,
    this.docListsRules = true,
    this.guardrailPresentInCopy = true,
    this.yearTrailFocusPresentInCopy = true,
  });

  final bool? monthlySandboxPurchaseProofComplete;
  final bool? paidIntentBetaShowsValue;
  final bool? annualRevenueCatProductRequested;
  final bool? paywallChangeRequested;
  final bool? annualPlanRequested;
  final bool? annualCopyMissingYearTrailFocus;
  final bool docListsRules;
  final bool guardrailPresentInCopy;
  final bool yearTrailFocusPresentInCopy;
}

class AnnualPlanFuturePrereq {
  const AnnualPlanFuturePrereq({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final AnnualPlanFuturePrereqId id;
  final String label;
  final AnnualPlanFuturePrereqStatus status;
  final String detailLabel;
}

class AnnualPlanFutureRule {
  const AnnualPlanFutureRule({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final AnnualPlanFutureRuleId id;
  final String label;
  final AnnualPlanFutureRuleStatus status;
  final String detailLabel;
}

class AnnualPlanFuturePlan {
  const AnnualPlanFuturePlan({
    required this.label,
    required this.positioning,
    required this.yearTrailFocusCopy,
    required this.status,
    required this.detailLabel,
  });

  final String label;
  final String positioning;
  final String yearTrailFocusCopy;
  final AnnualPlanFuturePlanStatus status;
  final String detailLabel;
}

class AnnualPlanFutureGateResult {
  const AnnualPlanFutureGateResult({
    required this.decision,
    required this.message,
    required this.recommendation,
    required this.positioning,
    required this.yearTrailFocusCopy,
    required this.rules,
    required this.ruleOrder,
    required this.rulesPass,
    required this.prereqs,
    required this.prereqOrder,
    required this.plan,
    required this.prereqsComplete,
    required this.annualRevenueCatProductBlocked,
    required this.paywallChangesBlocked,
    required this.earliestPrereqGap,
    required this.earliestRuleFailure,
  });

  final AnnualPlanFutureGateDecision decision;
  final String message;
  final String recommendation;
  final String positioning;
  final String yearTrailFocusCopy;
  final List<AnnualPlanFutureRule> rules;
  final List<AnnualPlanFutureRuleId> ruleOrder;
  final bool rulesPass;
  final List<AnnualPlanFuturePrereq> prereqs;
  final List<AnnualPlanFuturePrereqId> prereqOrder;
  final AnnualPlanFuturePlan plan;
  final bool prereqsComplete;
  final bool annualRevenueCatProductBlocked;
  final bool paywallChangesBlocked;
  final AnnualPlanFuturePrereqId? earliestPrereqGap;
  final AnnualPlanFutureRuleId? earliestRuleFailure;
}

class AnnualPlanFutureGateReport {
  const AnnualPlanFutureGateReport({
    required this.headline,
    required this.body,
    required this.positioning,
    required this.futureAnnualPlanLine,
    required this.orderLine,
    required this.prereqOrderLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String positioning;
  final String futureAnnualPlanLine;
  final String orderLine;
  final String prereqOrderLine;
  final String guardrail;
  final AnnualPlanFutureGateResult result;
}
