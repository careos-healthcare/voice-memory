import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'package:voicememory_mobile/features/premium_tiers_future/premium_tiers_future_copy.dart';
import 'package:voicememory_mobile/features/premium_tiers_future/premium_tiers_future_gate.dart';
import 'package:voicememory_mobile/features/single_launch_checklist/single_launch_checklist.dart';

const _docsPath = 'docs/PREMIUM_TIERS_FUTURE.md';

PremiumTiersFutureGateInput _input({
  bool? simpleProPurchaseProofComplete,
  bool? tierUiRequested,
  bool? higherTierExpansionRequested,
}) => PremiumTiersFutureGateInput(
  simpleProPurchaseProofComplete: simpleProPurchaseProofComplete,
  tierUiRequested: tierUiRequested,
  higherTierExpansionRequested: higherTierExpansionRequested,
);

PremiumTiersFuturePrereq _prereq(
  PremiumTiersFutureGateResult result,
  PremiumTiersFuturePrereqId id,
) => result.prereqs.firstWhere((prereq) => prereq.id == id);

PremiumTierFuture _tier(
  PremiumTiersFutureGateResult result,
  PremiumTierFutureId id,
) => result.tiers.firstWhere((tier) => tier.id == id);

PremiumTiersFutureRule _rule(
  PremiumTiersFutureGateResult result,
  PremiumTiersFutureRuleId id,
) => result.rules.firstWhere((rule) => rule.id == id);

void main() {
  group('PremiumTiersFutureGate.build', () {
    test('gate tracks five tiers, one prerequisite, and four rules', () {
      final result = PremiumTiersFutureGate.build(_input());
      expect(result.tiers.length, PremiumTiersFutureGate.tierCount);
      expect(result.prereqs.length, PremiumTiersFutureGate.prereqCount);
      expect(result.rules.length, PremiumTiersFutureGate.ruleCount);
      expect(result.tierOrder, PremiumTiersFutureGate.canonicalTierOrder);
      expect(result.prereqOrder, PremiumTiersFutureGate.canonicalPrereqOrder);
      expect(result.ruleOrder, PremiumTiersFutureGate.canonicalRuleOrder);
    });

    test('default input -> tiersFrozen with complexity blocked', () {
      final result = PremiumTiersFutureGate.build(_input());
      expect(result.decision, PremiumTiersFutureGateDecision.tiersFrozen);
      expect(result.newProductsBlocked, isTrue);
      expect(result.revenueCatChangesBlocked, isTrue);
      expect(result.tierUiBlocked, isTrue);
      expect(result.rulesPass, isTrue);
      expect(
        result.futureTierIdeas,
        PremiumTiersFutureGate.canonicalFutureTierIdeas,
      );
    });

    test('simple Pro purchase proof complete -> futureTiersDocumented', () {
      final result = PremiumTiersFutureGate.build(
        _input(simpleProPurchaseProofComplete: true),
      );
      expect(
        result.decision,
        PremiumTiersFutureGateDecision.futureTiersDocumented,
      );
      expect(result.proPurchaseProofComplete, isTrue);
      expect(result.documentedTierCount, PremiumTiersFutureGate.tierCount);
      expect(result.blockedTierCount, 0);
    });

    test('pending purchase proof -> tiersFrozen', () {
      final result = PremiumTiersFutureGate.build(
        _input(simpleProPurchaseProofComplete: null),
      );
      expect(result.decision, PremiumTiersFutureGateDecision.tiersFrozen);
      expect(
        result.earliestPrereqGap,
        PremiumTiersFuturePrereqId.simpleProPurchaseProofComplete,
      );
      expect(
        _tier(result, PremiumTierFutureId.longerHistory).status,
        PremiumTierFutureStatus.blockedBeforeProProof,
      );
    });

    test('tier UI requested without purchase proof fails noTierUi', () {
      final result = PremiumTiersFutureGate.build(
        _input(simpleProPurchaseProofComplete: false, tierUiRequested: true),
      );
      expect(
        _rule(result, PremiumTiersFutureRuleId.noTierUi).status,
        PremiumTiersFutureRuleStatus.fail,
      );
    });

    test('higher tier expansion without proof fails proof rule', () {
      final result = PremiumTiersFutureGate.build(
        _input(
          simpleProPurchaseProofComplete: false,
          higherTierExpansionRequested: true,
        ),
      );
      expect(
        _rule(
          result,
          PremiumTiersFutureRuleId.higherTiersRequireSimpleProPurchaseProof,
        ).status,
        PremiumTiersFutureRuleStatus.fail,
      );
    });

    test('canonical rules pass for gate copy', () {
      final result = PremiumTiersFutureGate.build(_input());
      for (final rule in result.rules) {
        expect(
          rule.status,
          PremiumTiersFutureRuleStatus.pass,
          reason: rule.id.name,
        );
      }
    });

    test('evaluateCopyPassesRules rejects new product copy', () {
      expect(
        PremiumTiersFutureGate.evaluateCopyPassesRules(
          'Add new product and create a premium plus tier today.',
        ),
        isFalse,
      );
    });

    test('evaluateCopyPassesRules rejects RevenueCat change copy', () {
      expect(
        PremiumTiersFutureGate.evaluateCopyPassesRules(
          'Change RevenueCat products and add new offering now.',
        ),
        isFalse,
      );
    });

    test('evaluateCopyPassesRules rejects tier UI copy', () {
      expect(
        PremiumTiersFutureGate.evaluateCopyPassesRules(
          'Open the tier comparison screen and choose your tier.',
        ),
        isFalse,
      );
    });

    test('report exposes canonical copy', () {
      final report = PremiumTiersFutureGate.report(
        PremiumTiersFutureGate.build(_input()),
      );
      expect(report.headline, PremiumTiersFutureCopy.headline);
      expect(
        report.futureTierIdeasLine,
        PremiumTiersFutureCopy.futureTierIdeasLine,
      );
      expect(report.guardrail, PremiumTiersFutureCopy.guardrail);
    });
  });

  group('PremiumTiersFutureGate.composeInput', () {
    test('bridges launch checklist sandbox purchase works', () {
      final input = PremiumTiersFutureGate.composeInput(
        launchChecklist: const SingleLaunchChecklistInput(
          sandboxPurchaseWorks: true,
        ),
      );
      expect(input.simpleProPurchaseProofComplete, isTrue);
    });

    test('bridges paid-intent purchase completed as simple Pro proof', () {
      final input = PremiumTiersFutureGate.composeInput(
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
      expect(input.simpleProPurchaseProofComplete, isTrue);
    });
  });

  group('PremiumTiersFutureGate.fromRepoSignals', () {
    late String docsSource;
    late String gateCopySource;

    setUpAll(() {
      docsSource = File(_docsPath).readAsStringSync();
      gateCopySource = File(
        'lib/features/premium_tiers_future/premium_tiers_future_copy.dart',
      ).readAsStringSync();
    });

    test('detectDocListsRules matches docs', () {
      expect(PremiumTiersFutureGate.detectDocListsRules(docsSource), isTrue);
    });

    test('detectGuardrailPresentInCopy matches gate copy', () {
      expect(
        PremiumTiersFutureGate.detectGuardrailPresentInCopy(gateCopySource),
        isTrue,
      );
    });

    test('detectFutureTierIdeasPresentInCopy matches gate copy', () {
      expect(
        PremiumTiersFutureGate.detectFutureTierIdeasPresentInCopy(
          gateCopySource,
        ),
        isTrue,
      );
    });

    test('fromRepoSignals defaults to tiersFrozen', () {
      final result = PremiumTiersFutureGate.build(
        PremiumTiersFutureGate.fromRepoSignals(
          premiumTiersFutureDocSource: docsSource,
          gateCopySource: gateCopySource,
        ),
      );
      expect(result.decision, PremiumTiersFutureGateDecision.tiersFrozen);
      expect(
        _prereq(
          result,
          PremiumTiersFuturePrereqId.simpleProPurchaseProofComplete,
        ).status,
        PremiumTiersFuturePrereqStatus.pending,
      );
    });
  });

  group('protected regression', () {
    test('docs describe premium tiers future scope', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('premium tiers future'));
      expect(doc, contains('longer history'));
      expect(doc, contains('reports/export'));
      expect(doc, contains('cross-device sync'));
      expect(doc, contains('private backup'));
      expect(doc, contains('advanced search'));
      expect(doc, contains('no new products or prices'));
      expect(doc, contains('no revenuecat product changes'));
      expect(doc, contains('no tier ui'));
      expect(doc, contains('simple pro purchase proof'));
    });

    test('guardrail blocks products, RevenueCat changes, and tier UI', () {
      final guardrail = PremiumTiersFutureCopy.guardrail.toLowerCase();
      expect(guardrail, contains('premium tiers future'));
      expect(guardrail, contains('do not add new products or prices now'));
      expect(guardrail, contains('do not change revenuecat products'));
      expect(guardrail, contains('do not add tier ui'));
      expect(guardrail, contains('simple pro purchase proof first'));
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final copy in PremiumTiersFutureCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });

    test('module does not import RevenueCat or paywall UI', () {
      for (final path in [
        'lib/features/premium_tiers_future/premium_tiers_future_gate.dart',
        'lib/features/premium_tiers_future/premium_tiers_future_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
        expect(source.contains('revenuecat_service'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
      }
    });

    test('advice guard registers premium tiers future copy', () {
      final guardSource = File(
        'lib/features/archive_proof/proof_surface_advice_guard.dart',
      ).readAsStringSync();
      expect(
        guardSource,
        contains('PremiumTiersFutureCopy.allVisibleStrings()'),
      );
    });
  });
}
