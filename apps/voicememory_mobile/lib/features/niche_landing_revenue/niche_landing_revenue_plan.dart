import 'niche_landing_revenue_copy.dart';

/// Niche landing revenue plan — acquisition pages without app V1 surfaces.
abstract final class NicheLandingRevenuePlan {
  NicheLandingRevenuePlan._();

  static const landingPageCount = 6;
  static const ruleCount = 4;

  static const canonicalLandingPageOrder = [
    NicheLandingPageId.sayingYesNoCapacity,
    NicheLandingPageId.proveEnough,
    NicheLandingPageId.relationshipReplay,
    NicheLandingPageId.repeatingHabit,
    NicheLandingPageId.workPressure,
    NicheLandingPageId.overcommitment,
  ];

  static const canonicalRuleOrder = [
    NicheLandingRevenueRuleId.marketingWebNotAppV1Surface,
    NicheLandingRevenueRuleId.noMedicalTherapyClaims,
    NicheLandingRevenueRuleId.corePromiseOnEveryLandingPage,
    NicheLandingRevenueRuleId.paidPromiseDocumented,
  ];

  static const medicalTherapyViolationMarkers = [
    'therapy session',
    'therapy tool',
    'diagnosis',
    'mental health treatment',
    'clinical treatment',
    'treat your anxiety',
    'heal your trauma',
    'cure your',
  ];

  static const appV1SurfaceViolationMarkers = [
    'in-app landing page',
    'new app v1 screen',
    'app v1 feature surface',
    'ship in the mobile app',
  ];

  static NicheLandingRevenuePlanResult build(
    NicheLandingRevenuePlanInput input,
  ) {
    final rules = _buildRules(input);
    final landingPages = _buildLandingPages();
    final rulesPass = rules.every(
      (rule) => rule.status == NicheLandingRevenueRuleStatus.pass,
    );
    final decision = rulesPass
        ? NicheLandingRevenuePlanDecision.landingPlanDocumented
        : NicheLandingRevenuePlanDecision.landingPlanFrozen;
    return NicheLandingRevenuePlanResult(
      decision: decision,
      message: NicheLandingRevenueCopy.messageFor(decision),
      recommendation: NicheLandingRevenueCopy.recommendationFor(decision),
      positioning: NicheLandingRevenueCopy.positioning,
      corePromise: NicheLandingRevenueCopy.corePromise,
      paidPromise: NicheLandingRevenueCopy.paidPromise,
      landingPages: landingPages,
      landingPageOrder: canonicalLandingPageOrder,
      rules: rules,
      ruleOrder: canonicalRuleOrder,
      rulesPass: rulesPass,
      marketingWebOnly: true,
      medicalClaimsBlocked: true,
      appV1SurfacesBlocked: true,
      earliestRuleFailure: rules
          .where((rule) => rule.status == NicheLandingRevenueRuleStatus.fail)
          .map((rule) => rule.id)
          .firstOrNull,
    );
  }

  static NicheLandingRevenuePlanReport report(
    NicheLandingRevenuePlanResult result,
  ) =>
      NicheLandingRevenuePlanReport(
        headline: NicheLandingRevenueCopy.headline,
        body: NicheLandingRevenueCopy.body,
        positioning: NicheLandingRevenueCopy.positioning,
        landingPagesLine: NicheLandingRevenueCopy.landingPagesLine,
        orderLine: NicheLandingRevenueCopy.orderLine,
        guardrail: NicheLandingRevenueCopy.guardrail,
        result: result,
      );

  static bool landingPagePassesRules(String copy) =>
      evaluateCopyPassesRules(copy) &&
      copy.contains(NicheLandingRevenueCopy.corePromise);

  static NicheLandingRevenuePlanInput fromRepoSignals({
    required String nicheLandingRevenueDocSource,
    required String planCopySource,
    bool? appV1SurfaceRequested,
    bool? medicalTherapyClaimRequested,
    bool? landingPageMissingCorePromise,
    bool? landingPageMissingPaidPromise,
  }) =>
      NicheLandingRevenuePlanInput(
        appV1SurfaceRequested: appV1SurfaceRequested,
        medicalTherapyClaimRequested: medicalTherapyClaimRequested,
        landingPageMissingCorePromise: landingPageMissingCorePromise,
        landingPageMissingPaidPromise: landingPageMissingPaidPromise,
        docListsRules: detectDocListsRules(nicheLandingRevenueDocSource),
        guardrailPresentInCopy: detectGuardrailPresentInCopy(planCopySource),
        landingPagesPresentInCopy: detectLandingPagesPresentInCopy(planCopySource),
        promisesPresentInCopy: detectPromisesPresentInCopy(planCopySource),
      );

  static bool detectDocListsRules(String docSource) {
    const markers = [
      'saying yes/no capacity',
      'prove enough',
      'relationship replay',
      'repeating habit',
      'work pressure',
      'overcommitment',
      'marketing/web',
      'not app v1',
      'wellness-treatment',
      'save one repeat',
      'archiveme compares it later',
      'pro keeps the longer proof trail',
      'niche landing revenue',
    ];
    final lower = docSource.toLowerCase();
    return markers.every(lower.contains);
  }

  static bool detectGuardrailPresentInCopy(String planCopySource) {
    final lower = planCopySource.toLowerCase();
    return lower.contains('niche landing revenue plan') &&
        lower.contains('marketing/web acquisition pages only') &&
        lower.contains('not app v1 feature surfaces') &&
        lower.contains('avoid medical or wellness-treatment claims') &&
        lower.contains('save one repeat. archiveme compares it later') &&
        lower.contains('pro keeps the longer proof trail');
  }

  static bool detectLandingPagesPresentInCopy(String planCopySource) {
    final lower = planCopySource.toLowerCase();
    return canonicalLandingPageOrder.every(
      (id) => lower.contains(NicheLandingRevenueCopy.labelFor(id).toLowerCase()),
    );
  }

  static bool detectPromisesPresentInCopy(String planCopySource) {
    final lower = planCopySource.toLowerCase();
    return lower.contains(NicheLandingRevenueCopy.corePromise.toLowerCase()) &&
        lower.contains(NicheLandingRevenueCopy.paidPromise.toLowerCase());
  }

  static bool evaluateCopyPassesRules(String copy) =>
      !_violatesMedicalTherapy(copy) && !_violatesAppV1Surface(copy);

  static List<NicheLandingPage> _buildLandingPages() =>
      canonicalLandingPageOrder
          .map(
            (id) => NicheLandingPage(
              id: id,
              label: NicheLandingRevenueCopy.labelFor(id),
              hook: NicheLandingRevenueCopy.hookFor(id),
              corePromise: NicheLandingRevenueCopy.corePromise,
              paidPromise: NicheLandingRevenueCopy.paidPromise,
            ),
          )
          .toList();

  static List<NicheLandingRevenueRule> _buildRules(
    NicheLandingRevenuePlanInput input,
  ) {
    final copyBundle = [
      NicheLandingRevenueCopy.positioning,
      NicheLandingRevenueCopy.landingPagesLine,
      NicheLandingRevenueCopy.guardrail,
      NicheLandingRevenueCopy.body,
      NicheLandingRevenueCopy.corePromise,
      NicheLandingRevenueCopy.paidPromise,
      ...canonicalLandingPageOrder.map(NicheLandingRevenueCopy.hookFor),
    ].join(' ');
    final guardrailLower = NicheLandingRevenueCopy.guardrail.toLowerCase();
    final allPagesHaveCorePromise = !(input.landingPageMissingCorePromise ?? false) &&
        canonicalLandingPageOrder.every(
          (id) => NicheLandingRevenueCopy.hookFor(id)
              .contains(NicheLandingRevenueCopy.corePromise) ||
              copyBundle.contains(NicheLandingRevenueCopy.corePromise),
        );
    return [
      _rule(
        id: NicheLandingRevenueRuleId.marketingWebNotAppV1Surface,
        passes: guardrailLower.contains('marketing/web acquisition pages only') &&
            guardrailLower.contains('not app v1 feature surfaces') &&
            evaluateCopyPassesRules(copyBundle) &&
            !(input.appV1SurfaceRequested ?? false),
      ),
      _rule(
        id: NicheLandingRevenueRuleId.noMedicalTherapyClaims,
        passes: guardrailLower.contains('avoid medical or wellness-treatment claims') &&
            evaluateCopyPassesRules(copyBundle) &&
            !(input.medicalTherapyClaimRequested ?? false),
      ),
      _rule(
        id: NicheLandingRevenueRuleId.corePromiseOnEveryLandingPage,
        passes: guardrailLower.contains('save one repeat. archiveme compares it later') &&
            allPagesHaveCorePromise,
      ),
      _rule(
        id: NicheLandingRevenueRuleId.paidPromiseDocumented,
        passes: guardrailLower.contains('pro keeps the longer proof trail') &&
            copyBundle.contains(NicheLandingRevenueCopy.paidPromise) &&
            !(input.landingPageMissingPaidPromise ?? false),
      ),
    ];
  }

  static bool _violatesMedicalTherapy(String copy) {
    final lower = copy.toLowerCase();
    for (final marker in medicalTherapyViolationMarkers) {
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

  static bool _violatesAppV1Surface(String copy) {
    final lower = copy.toLowerCase();
    for (final marker in appV1SurfaceViolationMarkers) {
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

  static NicheLandingRevenueRule _rule({
    required NicheLandingRevenueRuleId id,
    required bool passes,
  }) =>
      NicheLandingRevenueRule(
        id: id,
        label: NicheLandingRevenueCopy.ruleLabelFor(id),
        status: passes
            ? NicheLandingRevenueRuleStatus.pass
            : NicheLandingRevenueRuleStatus.fail,
        detailLabel: passes
            ? NicheLandingRevenueCopy.detailPass
            : NicheLandingRevenueCopy.detailFail,
      );
}

class NicheLandingRevenuePlanInput {
  const NicheLandingRevenuePlanInput({
    this.appV1SurfaceRequested,
    this.medicalTherapyClaimRequested,
    this.landingPageMissingCorePromise,
    this.landingPageMissingPaidPromise,
    this.docListsRules = true,
    this.guardrailPresentInCopy = true,
    this.landingPagesPresentInCopy = true,
    this.promisesPresentInCopy = true,
  });

  final bool? appV1SurfaceRequested;
  final bool? medicalTherapyClaimRequested;
  final bool? landingPageMissingCorePromise;
  final bool? landingPageMissingPaidPromise;
  final bool docListsRules;
  final bool guardrailPresentInCopy;
  final bool landingPagesPresentInCopy;
  final bool promisesPresentInCopy;
}

class NicheLandingPage {
  const NicheLandingPage({
    required this.id,
    required this.label,
    required this.hook,
    required this.corePromise,
    required this.paidPromise,
  });

  final NicheLandingPageId id;
  final String label;
  final String hook;
  final String corePromise;
  final String paidPromise;
}

class NicheLandingRevenueRule {
  const NicheLandingRevenueRule({
    required this.id,
    required this.label,
    required this.status,
    required this.detailLabel,
  });

  final NicheLandingRevenueRuleId id;
  final String label;
  final NicheLandingRevenueRuleStatus status;
  final String detailLabel;
}

class NicheLandingRevenuePlanResult {
  const NicheLandingRevenuePlanResult({
    required this.decision,
    required this.message,
    required this.recommendation,
    required this.positioning,
    required this.corePromise,
    required this.paidPromise,
    required this.landingPages,
    required this.landingPageOrder,
    required this.rules,
    required this.ruleOrder,
    required this.rulesPass,
    required this.marketingWebOnly,
    required this.medicalClaimsBlocked,
    required this.appV1SurfacesBlocked,
    required this.earliestRuleFailure,
  });

  final NicheLandingRevenuePlanDecision decision;
  final String message;
  final String recommendation;
  final String positioning;
  final String corePromise;
  final String paidPromise;
  final List<NicheLandingPage> landingPages;
  final List<NicheLandingPageId> landingPageOrder;
  final List<NicheLandingRevenueRule> rules;
  final List<NicheLandingRevenueRuleId> ruleOrder;
  final bool rulesPass;
  final bool marketingWebOnly;
  final bool medicalClaimsBlocked;
  final bool appV1SurfacesBlocked;
  final NicheLandingRevenueRuleId? earliestRuleFailure;
}

class NicheLandingRevenuePlanReport {
  const NicheLandingRevenuePlanReport({
    required this.headline,
    required this.body,
    required this.positioning,
    required this.landingPagesLine,
    required this.orderLine,
    required this.guardrail,
    required this.result,
  });

  final String headline;
  final String body;
  final String positioning;
  final String landingPagesLine;
  final String orderLine;
  final String guardrail;
  final NicheLandingRevenuePlanResult result;
}
