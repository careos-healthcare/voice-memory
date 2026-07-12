import '../paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'price_objection_feedback_copy.dart';

/// Price objection feedback gate — collect why users do not buy after Pro tap.
abstract final class PriceObjectionFeedbackGate {
  PriceObjectionFeedbackGate._();

  static const reasonCount = 7;
  static const ruleCount = 5;

  static const canonicalReasonOrder = [
    PriceObjectionReasonId.needStrongerProof,
    PriceObjectionReasonId.tooExpensive,
    PriceObjectionReasonId.notClearWhatProKeeps,
    PriceObjectionReasonId.notReadyYet,
    PriceObjectionReasonId.wantedSyncBackup,
    PriceObjectionReasonId.wantedReports,
    PriceObjectionReasonId.other,
  ];

  static const canonicalRuleOrder = [
    PriceObjectionFeedbackRuleId.showOnlyAfterProTapWithoutPurchase,
    PriceObjectionFeedbackRuleId.doNotChangePrice,
    PriceObjectionFeedbackRuleId.doNotAddDiscounts,
    PriceObjectionFeedbackRuleId.doNotAddNewFeatures,
    PriceObjectionFeedbackRuleId.feedPaidIntentBetaInterpretationOnly,
  ];

  static const priceChangeViolationMarkers = [
    'change the price',
    'lower the price',
    'raise the price',
    'new price point',
    'adjust pricing',
  ];

  static const discountViolationMarkers = [
    'add a discount',
    'promo code',
    'limited offer',
    'sale price',
    'percent off',
  ];

  static const newFeatureViolationMarkers = [
    'add new feature',
    'ship sync backup',
    'build reports feature',
    'launch new capability',
  ];

  static PriceObjectionFeedbackGateResult build(
    PriceObjectionFeedbackGateInput input,
  ) {
    final rules = _buildRules(input);
    final reasons = _buildReasons();
    final rulesPass = rules.every(
      (rule) => rule.status == PriceObjectionFeedbackRuleStatus.pass,
    );
    final shouldShow = shouldShowFeedback(input);
    final decision = rulesPass && shouldShow
        ? PriceObjectionFeedbackGateDecision.objectionFeedbackDocumented
        : PriceObjectionFeedbackGateDecision.objectionFeedbackFrozen;
    return PriceObjectionFeedbackGateResult(
      decision: decision,
      message: PriceObjectionFeedbackCopy.messageFor(decision),
      recommendation: PriceObjectionFeedbackCopy.recommendationFor(decision),
      positioning: PriceObjectionFeedbackCopy.positioning,
      reasons: reasons,
      reasonOrder: canonicalReasonOrder,
      rules: rules,
      ruleOrder: canonicalRuleOrder,
      rulesPass: rulesPass,
      shouldShowFeedback: shouldShow,
      priceChangesBlocked: true,
      discountsBlocked: true,
      newFeaturesBlocked: true,
      paidIntentBetaOnly: true,
      earliestRuleFailure: rules
          .where((rule) => rule.status == PriceObjectionFeedbackRuleStatus.fail)
          .map((rule) => rule.id)
          .firstOrNull,
    );
  }

  static PriceObjectionFeedbackGateReport report(
    PriceObjectionFeedbackGateResult result,
  ) =>
      PriceObjectionFeedbackGateReport(
        headline: PriceObjectionFeedbackCopy.headline,
        body: PriceObjectionFeedbackCopy.body,
        positioning: PriceObjectionFeedbackCopy.positioning,
        reasonOrderLine: PriceObjectionFeedbackCopy.reasonOrderLine,
        orderLine: PriceObjectionFeedbackCopy.orderLine,
        guardrail: PriceObjectionFeedbackCopy.guardrail,
        result: result,
      );

  static bool shouldShowFeedback(PriceObjectionFeedbackGateInput input) {
    if (input.isPro ?? false) return false;
    final proTapped = input.proTapped ?? false;
    final purchaseCompleted = input.purchaseCompleted ?? false;
    return proTapped && !purchaseCompleted;
  }

  static PriceObjectionFeedbackGateInput composeInput({
    bool? proTapped,
    bool? purchaseCompleted,
    bool? isPro,
    bool? feedbackRequested,
    bool? priceChangeRequested,
    bool? discountRequested,
    bool? newFeatureRequested,
    bool? nonBetaInterpretationRequested,
    PaidIntentBetaProofResult? paidIntentBeta,
  }) =>
      PriceObjectionFeedbackGateInput(
        proTapped: proTapped ??
            _signalPassed(
              paidIntentBeta,
              PaidIntentBetaProofSignalId.proTapped,
            ),
        purchaseCompleted: purchaseCompleted ??
            _signalPassed(
              paidIntentBeta,
              PaidIntentBetaProofSignalId.purchaseCompleted,
            ),
        isPro: isPro,
        feedbackRequested: feedbackRequested,
        priceChangeRequested: priceChangeRequested,
        discountRequested: discountRequested,
        newFeatureRequested: newFeatureRequested,
        nonBetaInterpretationRequested: nonBetaInterpretationRequested,
      );

  static PriceObjectionFeedbackGateInput fromRepoSignals({
    required String priceObjectionFeedbackDocSource,
    required String gateCopySource,
    bool? proTapped,
    bool? purchaseCompleted,
    bool? isPro,
    bool? feedbackRequested,
    bool? priceChangeRequested,
    bool? discountRequested,
    bool? newFeatureRequested,
    bool? nonBetaInterpretationRequested,
  }) =>
      PriceObjectionFeedbackGateInput(
        proTapped: proTapped,
        purchaseCompleted: purchaseCompleted,
        isPro: isPro,
        feedbackRequested: feedbackRequested,
        priceChangeRequested: priceChangeRequested,
        discountRequested: discountRequested,
        newFeatureRequested: newFeatureRequested,
        nonBetaInterpretationRequested: nonBetaInterpretationRequested,
        docListsRules: detectDocListsRules(priceObjectionFeedbackDocSource),
        guardrailPresentInCopy: detectGuardrailPresentInCopy(gateCopySource),
        reasonsPresentInCopy: detectReasonsPresentInCopy(gateCopySource),
      );

  static bool detectDocListsRules(String docSource) {
    const markers = [
      'need stronger proof',
      'too expensive',
      'not clear what pro keeps',
      'not ready yet',
      'wanted sync/backup',
      'wanted reports',
      'other',
      'show only after pro tap without purchase',
      'do not change price',
      'do not add discounts',
      'do not add new features',
      'paid-intent beta interpretation',
      'price objection feedback',
    ];
    final lower = docSource.toLowerCase();
    return markers.every(lower.contains);
  }

  static bool detectGuardrailPresentInCopy(String gateCopySource) {
    final lower = gateCopySource.toLowerCase();
    return lower.contains('price objection feedback gate') &&
        lower.contains('show only after pro tap without purchase') &&
        lower.contains('do not change price') &&
        lower.contains('do not add discounts') &&
        lower.contains('do not add new features') &&
        lower.contains('feed paid-intent beta interpretation only');
  }

  static bool detectReasonsPresentInCopy(String gateCopySource) {
    final lower = gateCopySource.toLowerCase();
    return canonicalReasonOrder.every(
      (id) => lower.contains(PriceObjectionFeedbackCopy.labelFor(id).toLowerCase()),
    );
  }

  static bool evaluateCopyPassesRules(String copy) =>
      !_violatesPriceChange(copy) &&
      !_violatesDiscount(copy) &&
      !_violatesNewFeature(copy);

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

  static List<PriceObjectionReason> _buildReasons() =>
      canonicalReasonOrder
          .map(
            (id) => PriceObjectionReason(
              id: id,
              label: PriceObjectionFeedbackCopy.labelFor(id),
              positioning: PriceObjectionFeedbackCopy.positioningFor(id),
            ),
          )
          .toList();

  static List<PriceObjectionFeedbackRule> _buildRules(
    PriceObjectionFeedbackGateInput input,
  ) {
    final copyBundle = [
      PriceObjectionFeedbackCopy.positioning,
      PriceObjectionFeedbackCopy.reasonOrderLine,
      PriceObjectionFeedbackCopy.guardrail,
      PriceObjectionFeedbackCopy.body,
    ].join(' ');
    final guardrailLower = PriceObjectionFeedbackCopy.guardrail.toLowerCase();
    final feedbackRequested = input.feedbackRequested ?? false;
    final showEligible = shouldShowFeedback(input);
    return [
      _rule(
        id: PriceObjectionFeedbackRuleId.showOnlyAfterProTapWithoutPurchase,
        passes: guardrailLower.contains('show only after pro tap without purchase') &&
            (!feedbackRequested || showEligible),
      ),
      _rule(
        id: PriceObjectionFeedbackRuleId.doNotChangePrice,
        passes: guardrailLower.contains('do not change price') &&
            evaluateCopyPassesRules(copyBundle) &&
            !(input.priceChangeRequested ?? false),
      ),
      _rule(
        id: PriceObjectionFeedbackRuleId.doNotAddDiscounts,
        passes: guardrailLower.contains('do not add discounts') &&
            evaluateCopyPassesRules(copyBundle) &&
            !(input.discountRequested ?? false),
      ),
      _rule(
        id: PriceObjectionFeedbackRuleId.doNotAddNewFeatures,
        passes: guardrailLower.contains('do not add new features') &&
            evaluateCopyPassesRules(copyBundle) &&
            !(input.newFeatureRequested ?? false),
      ),
      _rule(
        id: PriceObjectionFeedbackRuleId.feedPaidIntentBetaInterpretationOnly,
        passes: guardrailLower
                .contains('feed paid-intent beta interpretation only') &&
            !(input.nonBetaInterpretationRequested ?? false),
      ),
    ];
  }

  static bool _violatesPriceChange(String copy) {
    final lower = copy.toLowerCase();
    for (final marker in priceChangeViolationMarkers) {
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

  static bool _violatesDiscount(String copy) {
    final lower = copy.toLowerCase();
    for (final marker in discountViolationMarkers) {
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

  static bool _violatesNewFeature(String copy) {
    final lower = copy.toLowerCase();
    for (final marker in newFeatureViolationMarkers) {
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
    const prohibitionMarkers = ['avoid ', 'without ', 'never ', 'no ', 'not ', 'do not '];
    for (final marker in prohibitionMarkers) {
      final index = prefix.lastIndexOf(marker);
      if (index < 0) continue;
      final between = prefix.substring(index + marker.length);
      if (!between.contains('. ')) return true;
    }
    return false;
  }

  static PriceObjectionFeedbackRule _rule({
    required PriceObjectionFeedbackRuleId id,
    required bool passes,
  }) =>
      PriceObjectionFeedbackRule(
        id: id,
        label: PriceObjectionFeedbackCopy.ruleLabelFor(id),
        status: passes
            ? PriceObjectionFeedbackRuleStatus.pass
            : PriceObjectionFeedbackRuleStatus.fail,
        detailLabel: passes
            ? PriceObjectionFeedbackCopy.detailPass
            : PriceObjectionFeedbackCopy.detailFail,
      );
}

class PriceObjectionFeedbackGateInput {
  const PriceObjectionFeedbackGateInput({
    this.proTapped,
    this.purchaseCompleted,
    this.isPro,
    this.feedbackRequested,
    this.priceChangeRequested,
    this.discountRequested,
    this.newFeatureRequested,
    this.nonBetaInterpretationRequested,
    this.docListsRules = true,
    this.guardrailPresentInCopy = true,
    this.reasonsPresentInCopy = true,
  });

  final bool? proTapped;
  final bool? purchaseCompleted;
  final bool? isPro;
  final bool? feedbackRequested;
  final bool? priceChangeRequested;
  final bool? discountRequested;
  final bool? newFeatureRequested;
  final bool? nonBetaInterpretationRequested;
  final bool docListsRules;
  final bool guardrailPresentInCopy;
  final bool reasonsPresentInCopy;
}

class PriceObjectionReason {
  const PriceObjectionReason({
    required this.id,
    required this.label,
    required this.positioning,
  });

  final PriceObjectionReasonId id;
  final String label;
  final String positioning;
}

class PriceObjectionFeedbackRule {
  const PriceObjectionFeedbackRule({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final PriceObjectionFeedbackRuleId id;
  final String label;
  final PriceObjectionFeedbackRuleStatus status;
  final String detailLabel;
}

class PriceObjectionFeedbackGateResult {
  const PriceObjectionFeedbackGateResult({
    required this.decision,
    required this.message,
    required this.recommendation,
    required this.positioning,
    required this.reasons,
    required this.reasonOrder,
    required this.rules,
    required this.ruleOrder,
    required this.rulesPass,
    required this.shouldShowFeedback,
    required this.priceChangesBlocked,
    required this.discountsBlocked,
    required this.newFeaturesBlocked,
    required this.paidIntentBetaOnly,
    required this.earliestRuleFailure,
  });

  final PriceObjectionFeedbackGateDecision decision;
  final String message;
  final String recommendation;
  final String positioning;
  final List<PriceObjectionReason> reasons;
  final List<PriceObjectionReasonId> reasonOrder;
  final List<PriceObjectionFeedbackRule> rules;
  final List<PriceObjectionFeedbackRuleId> ruleOrder;
  final bool rulesPass;
  final bool shouldShowFeedback;
  final bool priceChangesBlocked;
  final bool discountsBlocked;
  final bool newFeaturesBlocked;
  final bool paidIntentBetaOnly;
  final PriceObjectionFeedbackRuleId? earliestRuleFailure;
}

class PriceObjectionFeedbackGateReport {
  const PriceObjectionFeedbackGateReport({
    required this.headline,
    required this.body,
    required this.positioning,
    required this.reasonOrderLine,
    required this.orderLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String positioning;
  final String reasonOrderLine;
  final String orderLine;
  final String guardrail;
  final PriceObjectionFeedbackGateResult result;
}
