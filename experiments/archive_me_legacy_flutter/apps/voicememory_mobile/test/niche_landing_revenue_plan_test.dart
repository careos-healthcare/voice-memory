import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/niche_landing_revenue/niche_landing_revenue_copy.dart';
import 'package:voicememory_mobile/features/niche_landing_revenue/niche_landing_revenue_plan.dart';

const _docsPath = 'docs/NICHE_LANDING_REVENUE_PLAN.md';

NicheLandingRevenuePlanInput _input({
  bool? appV1SurfaceRequested,
  bool? medicalTherapyClaimRequested,
  bool? landingPageMissingCorePromise,
  bool? landingPageMissingPaidPromise,
}) => NicheLandingRevenuePlanInput(
  appV1SurfaceRequested: appV1SurfaceRequested,
  medicalTherapyClaimRequested: medicalTherapyClaimRequested,
  landingPageMissingCorePromise: landingPageMissingCorePromise,
  landingPageMissingPaidPromise: landingPageMissingPaidPromise,
);

NicheLandingRevenueRule _rule(
  NicheLandingRevenuePlanResult result,
  NicheLandingRevenueRuleId id,
) => result.rules.firstWhere((rule) => rule.id == id);

void main() {
  group('NicheLandingRevenuePlan.build', () {
    test('plan tracks six landing pages and four rules in order', () {
      final result = NicheLandingRevenuePlan.build(_input());
      expect(
        result.landingPages.length,
        NicheLandingRevenuePlan.landingPageCount,
      );
      expect(result.rules.length, NicheLandingRevenuePlan.ruleCount);
      expect(
        result.landingPageOrder,
        NicheLandingRevenuePlan.canonicalLandingPageOrder,
      );
      expect(result.ruleOrder, NicheLandingRevenuePlan.canonicalRuleOrder);
    });

    test('default input -> landingPlanDocumented', () {
      final result = NicheLandingRevenuePlan.build(_input());
      expect(
        result.decision,
        NicheLandingRevenuePlanDecision.landingPlanDocumented,
      );
      expect(result.rulesPass, isTrue);
      expect(result.marketingWebOnly, isTrue);
      expect(result.medicalClaimsBlocked, isTrue);
      expect(result.appV1SurfacesBlocked, isTrue);
      expect(result.corePromise, NicheLandingRevenueCopy.corePromise);
      expect(result.paidPromise, NicheLandingRevenueCopy.paidPromise);
    });

    test('every landing page carries canonical promises', () {
      final result = NicheLandingRevenuePlan.build(_input());
      for (final page in result.landingPages) {
        expect(page.corePromise, NicheLandingRevenueCopy.corePromise);
        expect(page.paidPromise, NicheLandingRevenueCopy.paidPromise);
      }
    });

    test('app V1 surface requested fails marketing/web rule', () {
      final result = NicheLandingRevenuePlan.build(
        _input(appV1SurfaceRequested: true),
      );
      expect(
        result.decision,
        NicheLandingRevenuePlanDecision.landingPlanFrozen,
      );
      expect(
        _rule(
          result,
          NicheLandingRevenueRuleId.marketingWebNotAppV1Surface,
        ).status,
        NicheLandingRevenueRuleStatus.fail,
      );
    });

    test('medical claim requested fails wellness-treatment rule', () {
      final result = NicheLandingRevenuePlan.build(
        _input(medicalTherapyClaimRequested: true),
      );
      expect(
        _rule(result, NicheLandingRevenueRuleId.noMedicalTherapyClaims).status,
        NicheLandingRevenueRuleStatus.fail,
      );
    });

    test('missing core promise fails core promise rule', () {
      final result = NicheLandingRevenuePlan.build(
        _input(landingPageMissingCorePromise: true),
      );
      expect(
        _rule(
          result,
          NicheLandingRevenueRuleId.corePromiseOnEveryLandingPage,
        ).status,
        NicheLandingRevenueRuleStatus.fail,
      );
    });

    test('missing paid promise fails paid promise rule', () {
      final result = NicheLandingRevenuePlan.build(
        _input(landingPageMissingPaidPromise: true),
      );
      expect(
        _rule(result, NicheLandingRevenueRuleId.paidPromiseDocumented).status,
        NicheLandingRevenueRuleStatus.fail,
      );
    });

    test('canonical rules pass for documented plan', () {
      final result = NicheLandingRevenuePlan.build(_input());
      for (final rule in result.rules) {
        expect(
          rule.status,
          NicheLandingRevenueRuleStatus.pass,
          reason: rule.id.name,
        );
      }
    });

    test('evaluateCopyPassesRules rejects therapy tool copy', () {
      expect(
        NicheLandingRevenuePlan.evaluateCopyPassesRules(
          'ArchiveMe is your therapy tool for anxiety.',
        ),
        isFalse,
      );
    });

    test('evaluateCopyPassesRules rejects app V1 surface copy', () {
      expect(
        NicheLandingRevenuePlan.evaluateCopyPassesRules(
          'Ship in the mobile app as a new app v1 screen.',
        ),
        isFalse,
      );
    });

    test('landingPagePassesRules requires core promise', () {
      expect(
        NicheLandingRevenuePlan.landingPagePassesRules(
          NicheLandingRevenueCopy.corePromise,
        ),
        isTrue,
      );
      expect(
        NicheLandingRevenuePlan.landingPagePassesRules(
          'A niche hook without the core promise.',
        ),
        isFalse,
      );
    });

    test('report exposes canonical copy', () {
      final report = NicheLandingRevenuePlan.report(
        NicheLandingRevenuePlan.build(_input()),
      );
      expect(report.headline, NicheLandingRevenueCopy.headline);
      expect(report.guardrail, NicheLandingRevenueCopy.guardrail);
      expect(report.landingPagesLine, NicheLandingRevenueCopy.landingPagesLine);
    });
  });

  group('NicheLandingRevenuePlan.fromRepoSignals', () {
    late String docsSource;
    late String copySource;

    setUpAll(() {
      docsSource = File(_docsPath).readAsStringSync();
      copySource = File(
        'lib/features/niche_landing_revenue/niche_landing_revenue_copy.dart',
      ).readAsStringSync();
    });

    test('detectDocListsRules matches docs', () {
      expect(NicheLandingRevenuePlan.detectDocListsRules(docsSource), isTrue);
    });

    test('detectGuardrailPresentInCopy matches copy', () {
      expect(
        NicheLandingRevenuePlan.detectGuardrailPresentInCopy(copySource),
        isTrue,
      );
    });

    test('detectLandingPagesPresentInCopy matches copy', () {
      expect(
        NicheLandingRevenuePlan.detectLandingPagesPresentInCopy(copySource),
        isTrue,
      );
    });

    test('detectPromisesPresentInCopy matches copy', () {
      expect(
        NicheLandingRevenuePlan.detectPromisesPresentInCopy(copySource),
        isTrue,
      );
    });

    test('fromRepoSignals defaults to landingPlanDocumented', () {
      final result = NicheLandingRevenuePlan.build(
        NicheLandingRevenuePlan.fromRepoSignals(
          nicheLandingRevenueDocSource: docsSource,
          planCopySource: copySource,
        ),
      );
      expect(
        result.decision,
        NicheLandingRevenuePlanDecision.landingPlanDocumented,
      );
    });
  });

  group('protected regression', () {
    test('docs describe niche landing revenue scope', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('niche landing revenue'));
      expect(doc, contains('saying yes/no capacity'));
      expect(doc, contains('prove enough'));
      expect(doc, contains('relationship replay'));
      expect(doc, contains('repeating habit'));
      expect(doc, contains('work pressure'));
      expect(doc, contains('overcommitment'));
      expect(doc, contains('marketing/web'));
      expect(doc, contains('not app v1'));
      expect(doc, contains('wellness-treatment'));
      expect(doc, contains('save one repeat'));
      expect(doc, contains('archiveme compares it later'));
      expect(doc, contains('pro keeps the longer proof trail'));
    });

    test('guardrail enforces marketing/web acquisition only', () {
      final guardrail = NicheLandingRevenueCopy.guardrail.toLowerCase();
      expect(guardrail, contains('marketing/web acquisition pages only'));
      expect(guardrail, contains('not app v1 feature surfaces'));
      expect(guardrail, contains('avoid medical or wellness-treatment claims'));
      expect(
        guardrail,
        contains('save one repeat. archiveme compares it later'),
      );
      expect(guardrail, contains('pro keeps the longer proof trail'));
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final copy in NicheLandingRevenueCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });

    test('module does not import paywall billing or RevenueCat service', () {
      for (final path in [
        'lib/features/niche_landing_revenue/niche_landing_revenue_plan.dart',
        'lib/features/niche_landing_revenue/niche_landing_revenue_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
        expect(source.contains('revenuecat_service'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
      }
    });

    test('advice guard registers niche landing revenue copy', () {
      final guardSource = File(
        'lib/features/archive_proof/proof_surface_advice_guard.dart',
      ).readAsStringSync();
      expect(
        guardSource,
        contains('NicheLandingRevenueCopy.allVisibleStrings()'),
      );
    });
  });
}
