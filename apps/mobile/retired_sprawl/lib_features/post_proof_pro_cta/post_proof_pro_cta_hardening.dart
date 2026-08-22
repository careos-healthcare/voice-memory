import 'package:archiveme_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'package:archiveme_mobile/features/post_proof_pro_cta/post_proof_pro_cta_copy.dart';

/// Post-proof Pro CTA hardening — Pro CTA after value, not before.
abstract final class PostProofProCtaHardening {
  PostProofProCtaHardening._();

  static const ruleCount = 8;

  static const List<PostProofProCtaRuleId> canonicalRuleOrder = [
    PostProofProCtaRuleId.hideBeforeFirstUsefulProofUnlessExplicitOpen,
    PostProofProCtaRuleId.showAfterProofValueMoment,
    PostProofProCtaRuleId.canonicalCtaAndBody,
    PostProofProCtaRuleId.noMoreAiLanguage,
    PostProofProCtaRuleId.noDashboardLanguage,
    PostProofProCtaRuleId.noStorageLanguage,
    PostProofProCtaRuleId.noUrgencyScarcityLanguage,
    PostProofProCtaRuleId.noPricingOrRevenueCatChanges,
  ];

  static const moreAiViolationMarkers = [
    'more ai',
    'advanced ai',
    'powerful ai',
    'ai insights',
    'smarter ai',
  ];

  static const dashboardViolationMarkers = [
    'life dashboard',
    'your dashboard',
    'main dashboard',
    'command center',
  ];

  static const storageViolationMarkers = [
    'unlimited storage',
    'cloud storage',
    'store everything',
    'archive storage',
  ];

  static const urgencyScarcityViolationMarkers = [
    'limited time',
    'act now',
    'last chance',
    'only today',
    "don't miss",
    'hurry',
  ];

  static PostProofProCtaHardeningResult build(
    PostProofProCtaHardeningInput input,
  ) {
    final rules = _buildRules(input);
    final rulesPass = rules.every(
      (rule) => rule.status == PostProofProCtaRuleStatus.pass,
    );
    final shouldShow = shouldShowProCta(input);
    final decision = rulesPass && shouldShow
        ? PostProofProCtaHardeningDecision.proCtaHardened
        : PostProofProCtaHardeningDecision.proCtaBlocked;
    return PostProofProCtaHardeningResult(
      decision: decision,
      message: PostProofProCtaCopy.messageFor(decision),
      recommendation: PostProofProCtaCopy.recommendationFor(decision),
      positioning: PostProofProCtaCopy.positioning,
      canonicalCta: PostProofProCtaCopy.canonicalCta,
      canonicalBody: PostProofProCtaCopy.canonicalBody,
      rules: rules,
      ruleOrder: canonicalRuleOrder,
      rulesPass: rulesPass,
      shouldShowProCta: shouldShow,
      urgencyLanguageBlocked: true,
      storageLanguageBlocked: true,
      dashboardLanguageBlocked: true,
      pricingChangesBlocked: true,
      earliestRuleFailure: rules
          .where((rule) => rule.status == PostProofProCtaRuleStatus.fail)
          .map((rule) => rule.id)
          .firstOrNull,
    );
  }

  static PostProofProCtaHardeningReport report(
    PostProofProCtaHardeningResult result,
  ) => PostProofProCtaHardeningReport(
    headline: PostProofProCtaCopy.headline,
    body: PostProofProCtaCopy.body,
    positioning: PostProofProCtaCopy.positioning,
    orderLine: PostProofProCtaCopy.orderLine,
    guardrail: PostProofProCtaCopy.guardrail,
    result: result,
  );

  static bool shouldShowProCta(PostProofProCtaHardeningInput input) {
    if (input.userExplicitlyOpenedPro ?? false) return true;
    final hasProofValue =
        (input.firstUsefulProofSeen ?? false) ||
        (input.proofAcceptedOrCorrected ?? false) ||
        (input.clearLongerTrailMoment ?? false);
    return hasProofValue;
  }

  static PostProofProCtaHardeningInput composeInput({
    bool? firstUsefulProofSeen,
    bool? proofAcceptedOrCorrected,
    bool? clearLongerTrailMoment,
    bool? userExplicitlyOpenedPro,
    bool? proCtaRequested,
    bool? pricingChangeRequested,
    bool? revenueCatChangeRequested,
    PaidIntentBetaProofResult? paidIntentBeta,
  }) => PostProofProCtaHardeningInput(
    firstUsefulProofSeen:
        firstUsefulProofSeen ??
        _signalPassed(
          paidIntentBeta,
          PaidIntentBetaProofSignalId.firstUsefulProofSeen,
        ),
    proofAcceptedOrCorrected:
        proofAcceptedOrCorrected ??
        _signalPassed(
          paidIntentBeta,
          PaidIntentBetaProofSignalId.proofAcceptedOrCorrected,
        ),
    clearLongerTrailMoment: clearLongerTrailMoment,
    userExplicitlyOpenedPro: userExplicitlyOpenedPro,
    proCtaRequested: proCtaRequested,
    pricingChangeRequested: pricingChangeRequested,
    revenueCatChangeRequested: revenueCatChangeRequested,
  );

  static PostProofProCtaHardeningInput fromRepoSignals({
    required String postProofProCtaDocSource,
    required String hardeningCopySource,
    bool? firstUsefulProofSeen,
    bool? proofAcceptedOrCorrected,
    bool? clearLongerTrailMoment,
    bool? userExplicitlyOpenedPro,
    bool? proCtaRequested,
    bool? pricingChangeRequested,
    bool? revenueCatChangeRequested,
  }) => PostProofProCtaHardeningInput(
    firstUsefulProofSeen: firstUsefulProofSeen,
    proofAcceptedOrCorrected: proofAcceptedOrCorrected,
    clearLongerTrailMoment: clearLongerTrailMoment,
    userExplicitlyOpenedPro: userExplicitlyOpenedPro,
    proCtaRequested: proCtaRequested,
    pricingChangeRequested: pricingChangeRequested,
    revenueCatChangeRequested: revenueCatChangeRequested,
    docListsRules: detectDocListsRules(postProofProCtaDocSource),
    guardrailPresentInCopy: detectGuardrailPresentInCopy(hardeningCopySource),
    canonicalCopyPresentInCopy: detectCanonicalCopyPresentInCopy(
      hardeningCopySource,
    ),
  );

  static bool detectDocListsRules(String docSource) {
    const markers = [
      'keep the longer trail',
      'free showed the first useful proof',
      'pro keeps tracking what happens next',
      'hide before first useful proof',
      'explicit pro open',
      'accepted proof',
      'longer-trail moment',
      'no more ai',
      'life-dashboard',
      'storage framing',
      'urgency',
      'scarcity',
      'pricing or revenuecat',
      'post-proof pro cta',
    ];
    final lower = docSource.toLowerCase();
    return markers.every(lower.contains);
  }

  static bool detectGuardrailPresentInCopy(String hardeningCopySource) {
    final lower = hardeningCopySource.toLowerCase();
    return lower.contains('post-proof pro cta') &&
        lower.contains('hide before first useful proof') &&
        lower.contains('explicitly opens pro') &&
        lower.contains('clear longer-trail moment') &&
        lower.contains('canonical cta and body') &&
        lower.contains('never say more ai') &&
        lower.contains('life-dashboard framing') &&
        lower.contains('storage framing') &&
        lower.contains('urgency/scarcity') &&
        lower.contains('do not change pricing or revenuecat');
  }

  static bool detectCanonicalCopyPresentInCopy(String hardeningCopySource) {
    final lower = hardeningCopySource.toLowerCase();
    return lower.contains(PostProofProCtaCopy.canonicalCta.toLowerCase()) &&
        lower.contains('free showed the first useful proof') &&
        lower.contains('pro keeps tracking what happens next');
  }

  static bool evaluateCopyPassesRules(String copy) =>
      !_violatesMoreAi(copy) &&
      !_violatesDashboard(copy) &&
      !_violatesStorage(copy) &&
      !_violatesUrgencyScarcity(copy);

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

  static List<PostProofProCtaRule> _buildRules(
    PostProofProCtaHardeningInput input,
  ) {
    final copyBundle = [
      PostProofProCtaCopy.positioning,
      PostProofProCtaCopy.canonicalCta,
      PostProofProCtaCopy.canonicalBody,
      PostProofProCtaCopy.guardrail,
      PostProofProCtaCopy.body,
    ].join(' ');
    final guardrailLower = PostProofProCtaCopy.guardrail.toLowerCase();
    final proCtaRequested = input.proCtaRequested ?? false;
    final hasProofValue =
        (input.firstUsefulProofSeen ?? false) ||
        (input.proofAcceptedOrCorrected ?? false) ||
        (input.clearLongerTrailMoment ?? false);
    final explicitOpen = input.userExplicitlyOpenedPro ?? false;
    return [
      _rule(
        id: PostProofProCtaRuleId.hideBeforeFirstUsefulProofUnlessExplicitOpen,
        passes:
            guardrailLower.contains('hide before first useful proof') &&
            (!proCtaRequested || explicitOpen || hasProofValue),
      ),
      _rule(
        id: PostProofProCtaRuleId.showAfterProofValueMoment,
        passes:
            guardrailLower.contains('clear longer-trail moment') &&
            (!proCtaRequested || shouldShowProCta(input)),
      ),
      _rule(
        id: PostProofProCtaRuleId.canonicalCtaAndBody,
        passes:
            copyBundle.contains(PostProofProCtaCopy.canonicalCta) &&
            copyBundle.contains(PostProofProCtaCopy.canonicalBody),
      ),
      _rule(
        id: PostProofProCtaRuleId.noMoreAiLanguage,
        passes:
            evaluateCopyPassesRules(copyBundle) &&
            guardrailLower.contains('never say more ai'),
      ),
      _rule(
        id: PostProofProCtaRuleId.noDashboardLanguage,
        passes:
            evaluateCopyPassesRules(copyBundle) &&
            guardrailLower.contains('life-dashboard framing'),
      ),
      _rule(
        id: PostProofProCtaRuleId.noStorageLanguage,
        passes:
            evaluateCopyPassesRules(copyBundle) &&
            guardrailLower.contains('storage framing'),
      ),
      _rule(
        id: PostProofProCtaRuleId.noUrgencyScarcityLanguage,
        passes:
            evaluateCopyPassesRules(copyBundle) &&
            guardrailLower.contains('urgency/scarcity'),
      ),
      _rule(
        id: PostProofProCtaRuleId.noPricingOrRevenueCatChanges,
        passes:
            guardrailLower.contains('do not change pricing or revenuecat') &&
            (!(input.pricingChangeRequested ?? false) &&
                !(input.revenueCatChangeRequested ?? false)),
      ),
    ];
  }

  static bool _violatesMoreAi(String copy) {
    final lower = copy.toLowerCase();
    for (final marker in moreAiViolationMarkers) {
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

  static bool _violatesDashboard(String copy) =>
      dashboardViolationMarkers.any(copy.toLowerCase().contains);

  static bool _violatesStorage(String copy) {
    final lower = copy.toLowerCase();
    for (final marker in storageViolationMarkers) {
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

  static bool _violatesUrgencyScarcity(String copy) =>
      urgencyScarcityViolationMarkers.any(copy.toLowerCase().contains);

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

  static PostProofProCtaRule _rule({
    required PostProofProCtaRuleId id,
    required bool passes,
  }) => PostProofProCtaRule(
    id: id,
    label: PostProofProCtaCopy.ruleLabelFor(id),
    status: passes
        ? PostProofProCtaRuleStatus.pass
        : PostProofProCtaRuleStatus.fail,
    detailLabel: passes
        ? PostProofProCtaCopy.detailPass
        : PostProofProCtaCopy.detailFail,
  );
}

class PostProofProCtaHardeningInput {
  const PostProofProCtaHardeningInput({
    this.firstUsefulProofSeen,
    this.proofAcceptedOrCorrected,
    this.clearLongerTrailMoment,
    this.userExplicitlyOpenedPro,
    this.proCtaRequested,
    this.pricingChangeRequested,
    this.revenueCatChangeRequested,
    this.docListsRules = true,
    this.guardrailPresentInCopy = true,
    this.canonicalCopyPresentInCopy = true,
  });

  final bool? firstUsefulProofSeen;
  final bool? proofAcceptedOrCorrected;
  final bool? clearLongerTrailMoment;
  final bool? userExplicitlyOpenedPro;
  final bool? proCtaRequested;
  final bool? pricingChangeRequested;
  final bool? revenueCatChangeRequested;
  final bool docListsRules;
  final bool guardrailPresentInCopy;
  final bool canonicalCopyPresentInCopy;
}

class PostProofProCtaRule {
  const PostProofProCtaRule({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final PostProofProCtaRuleId id;
  final String label;
  final PostProofProCtaRuleStatus status;
  final String detailLabel;
}

class PostProofProCtaHardeningResult {
  const PostProofProCtaHardeningResult({
    required this.decision,
    required this.message,
    required this.recommendation,
    required this.positioning,
    required this.canonicalCta,
    required this.canonicalBody,
    required this.rules,
    required this.ruleOrder,
    required this.rulesPass,
    required this.shouldShowProCta,
    required this.urgencyLanguageBlocked,
    required this.storageLanguageBlocked,
    required this.dashboardLanguageBlocked,
    required this.pricingChangesBlocked,
    required this.earliestRuleFailure,
  });

  final PostProofProCtaHardeningDecision decision;
  final String message;
  final String recommendation;
  final String positioning;
  final String canonicalCta;
  final String canonicalBody;
  final List<PostProofProCtaRule> rules;
  final List<PostProofProCtaRuleId> ruleOrder;
  final bool rulesPass;
  final bool shouldShowProCta;
  final bool urgencyLanguageBlocked;
  final bool storageLanguageBlocked;
  final bool dashboardLanguageBlocked;
  final bool pricingChangesBlocked;
  final PostProofProCtaRuleId? earliestRuleFailure;
}

class PostProofProCtaHardeningReport {
  const PostProofProCtaHardeningReport({
    required this.headline,
    required this.body,
    required this.positioning,
    required this.orderLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String positioning;
  final String orderLine;
  final String guardrail;
  final PostProofProCtaHardeningResult result;
}