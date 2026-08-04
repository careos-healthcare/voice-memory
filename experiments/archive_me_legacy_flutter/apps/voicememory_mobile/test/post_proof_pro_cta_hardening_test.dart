import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'package:voicememory_mobile/features/post_proof_pro_cta/post_proof_pro_cta_copy.dart';
import 'package:voicememory_mobile/features/post_proof_pro_cta/post_proof_pro_cta_hardening.dart';

const _docsPath = 'docs/POST_PROOF_PRO_CTA.md';

PostProofProCtaHardeningInput _input({
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
);

PostProofProCtaRule _rule(
  PostProofProCtaHardeningResult result,
  PostProofProCtaRuleId id,
) => result.rules.firstWhere((rule) => rule.id == id);

void main() {
  group('PostProofProCtaHardening.shouldShowProCta', () {
    test('hidden before first useful proof', () {
      expect(PostProofProCtaHardening.shouldShowProCta(_input()), isFalse);
    });

    test('shown after first useful proof', () {
      expect(
        PostProofProCtaHardening.shouldShowProCta(
          _input(firstUsefulProofSeen: true),
        ),
        isTrue,
      );
    });

    test('shown after accepted proof', () {
      expect(
        PostProofProCtaHardening.shouldShowProCta(
          _input(proofAcceptedOrCorrected: true),
        ),
        isTrue,
      );
    });

    test('shown after clear longer-trail moment', () {
      expect(
        PostProofProCtaHardening.shouldShowProCta(
          _input(clearLongerTrailMoment: true),
        ),
        isTrue,
      );
    });

    test('shown when user explicitly opens Pro before proof', () {
      expect(
        PostProofProCtaHardening.shouldShowProCta(
          _input(userExplicitlyOpenedPro: true),
        ),
        isTrue,
      );
    });
  });

  group('PostProofProCtaHardening.build', () {
    test('gate tracks eight canonical rules in order', () {
      final result = PostProofProCtaHardening.build(_input());
      expect(result.rules.length, PostProofProCtaHardening.ruleCount);
      expect(result.ruleOrder, PostProofProCtaHardening.canonicalRuleOrder);
    });

    test('default input -> proCtaBlocked', () {
      final result = PostProofProCtaHardening.build(_input());
      expect(result.decision, PostProofProCtaHardeningDecision.proCtaBlocked);
      expect(result.shouldShowProCta, isFalse);
      expect(result.urgencyLanguageBlocked, isTrue);
      expect(result.storageLanguageBlocked, isTrue);
      expect(result.dashboardLanguageBlocked, isTrue);
      expect(result.pricingChangesBlocked, isTrue);
      expect(result.rulesPass, isTrue);
    });

    test('proof value present -> proCtaHardened', () {
      final result = PostProofProCtaHardening.build(
        _input(firstUsefulProofSeen: true),
      );
      expect(result.decision, PostProofProCtaHardeningDecision.proCtaHardened);
      expect(result.canonicalCta, PostProofProCtaCopy.canonicalCta);
      expect(result.canonicalBody, PostProofProCtaCopy.canonicalBody);
    });

    test(
      'pro CTA requested before proof without explicit open fails hide rule',
      () {
        final result = PostProofProCtaHardening.build(
          _input(firstUsefulProofSeen: false, proCtaRequested: true),
        );
        expect(
          _rule(
            result,
            PostProofProCtaRuleId.hideBeforeFirstUsefulProofUnlessExplicitOpen,
          ).status,
          PostProofProCtaRuleStatus.fail,
        );
      },
    );

    test('explicit Pro open allows CTA before proof value', () {
      final result = PostProofProCtaHardening.build(
        _input(userExplicitlyOpenedPro: true, proCtaRequested: true),
      );
      expect(result.decision, PostProofProCtaHardeningDecision.proCtaHardened);
    });

    test('pricing change requested fails pricing rule', () {
      final result = PostProofProCtaHardening.build(
        _input(firstUsefulProofSeen: true, pricingChangeRequested: true),
      );
      expect(
        _rule(
          result,
          PostProofProCtaRuleId.noPricingOrRevenueCatChanges,
        ).status,
        PostProofProCtaRuleStatus.fail,
      );
    });

    test('canonical rules pass for hardened copy', () {
      final result = PostProofProCtaHardening.build(
        _input(firstUsefulProofSeen: true),
      );
      for (final rule in result.rules) {
        expect(
          rule.status,
          PostProofProCtaRuleStatus.pass,
          reason: rule.id.name,
        );
      }
    });

    test('evaluateCopyPassesRules rejects more AI copy', () {
      expect(
        PostProofProCtaHardening.evaluateCopyPassesRules(
          'Unlock more AI insights with Pro.',
        ),
        isFalse,
      );
    });

    test('evaluateCopyPassesRules rejects dashboard copy', () {
      expect(
        PostProofProCtaHardening.evaluateCopyPassesRules(
          'ArchiveMe is your life dashboard for patterns.',
        ),
        isFalse,
      );
    });

    test('evaluateCopyPassesRules rejects storage copy', () {
      expect(
        PostProofProCtaHardening.evaluateCopyPassesRules(
          'Get unlimited storage for your archive.',
        ),
        isFalse,
      );
    });

    test('evaluateCopyPassesRules rejects urgency copy', () {
      expect(
        PostProofProCtaHardening.evaluateCopyPassesRules(
          'Limited time offer — act now.',
        ),
        isFalse,
      );
    });

    test('report exposes canonical copy', () {
      final report = PostProofProCtaHardening.report(
        PostProofProCtaHardening.build(_input(firstUsefulProofSeen: true)),
      );
      expect(report.headline, PostProofProCtaCopy.headline);
      expect(report.guardrail, PostProofProCtaCopy.guardrail);
      expect(report.orderLine, PostProofProCtaCopy.orderLine);
    });
  });

  group('PostProofProCtaHardening.composeInput', () {
    test('bridges paid-intent proof signals', () {
      final input = PostProofProCtaHardening.composeInput(
        paidIntentBeta: PaidIntentBetaProof.build(
          const PaidIntentBetaProofInput(
            firstSaveCompleted: true,
            firstUsefulProofSeen: true,
            proofAcceptedOrCorrected: true,
            proPromiseSeen: true,
            proTapped: true,
            purchaseAttempted: true,
            purchaseCompleted: true,
          ),
        ),
      );
      expect(input.firstUsefulProofSeen, isTrue);
      expect(input.proofAcceptedOrCorrected, isTrue);
    });
  });

  group('PostProofProCtaHardening.fromRepoSignals', () {
    late String docsSource;
    late String copySource;

    setUpAll(() {
      docsSource = File(_docsPath).readAsStringSync();
      copySource = File(
        'lib/features/post_proof_pro_cta/post_proof_pro_cta_copy.dart',
      ).readAsStringSync();
    });

    test('detectDocListsRules matches docs', () {
      expect(PostProofProCtaHardening.detectDocListsRules(docsSource), isTrue);
    });

    test('detectGuardrailPresentInCopy matches copy', () {
      expect(
        PostProofProCtaHardening.detectGuardrailPresentInCopy(copySource),
        isTrue,
      );
    });

    test('detectCanonicalCopyPresentInCopy matches copy', () {
      expect(
        PostProofProCtaHardening.detectCanonicalCopyPresentInCopy(copySource),
        isTrue,
      );
    });

    test('fromRepoSignals defaults to proCtaBlocked', () {
      final result = PostProofProCtaHardening.build(
        PostProofProCtaHardening.fromRepoSignals(
          postProofProCtaDocSource: docsSource,
          hardeningCopySource: copySource,
        ),
      );
      expect(result.decision, PostProofProCtaHardeningDecision.proCtaBlocked);
    });
  });

  group('protected regression', () {
    test('docs describe post-proof Pro CTA scope', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('post-proof pro cta'));
      expect(doc, contains('keep the longer trail'));
      expect(doc, contains('free showed the first useful proof'));
      expect(doc, contains('pro keeps tracking what happens next'));
      expect(doc, contains('hide before first useful proof'));
      expect(doc, contains('explicitly opens pro'));
      expect(doc, contains('accepted proof'));
      expect(doc, contains('longer-trail moment'));
      expect(doc, contains('no more ai'));
      expect(doc, contains('life-dashboard'));
      expect(doc, contains('storage framing'));
      expect(doc, contains('urgency'));
      expect(doc, contains('scarcity'));
      expect(doc, contains('pricing or revenuecat'));
    });

    test('guardrail enforces post-proof timing and copy', () {
      final guardrail = PostProofProCtaCopy.guardrail.toLowerCase();
      expect(guardrail, contains('after value, not before'));
      expect(guardrail, contains('hide before first useful proof'));
      expect(guardrail, contains('canonical cta and body'));
      expect(guardrail, contains('never say more ai'));
      expect(guardrail, contains('do not change pricing or revenuecat'));
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final copy in PostProofProCtaCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });

    test('module does not import paywall billing or RevenueCat service', () {
      for (final path in [
        'lib/features/post_proof_pro_cta/post_proof_pro_cta_hardening.dart',
        'lib/features/post_proof_pro_cta/post_proof_pro_cta_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
        expect(source.contains('revenuecat_service'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
      }
    });

    test('advice guard registers post-proof Pro CTA copy', () {
      final guardSource = File(
        'lib/features/archive_proof/proof_surface_advice_guard.dart',
      ).readAsStringSync();
      expect(guardSource, contains('PostProofProCtaCopy.allVisibleStrings()'));
    });
  });
}
