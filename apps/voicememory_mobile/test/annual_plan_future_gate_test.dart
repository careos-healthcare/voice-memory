import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/annual_plan_future/annual_plan_future_copy.dart';
import 'package:voicememory_mobile/features/annual_plan_future/annual_plan_future_gate.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'package:voicememory_mobile/features/single_launch_checklist/single_launch_checklist.dart';

const _docsPath = 'docs/ANNUAL_PLAN_FUTURE.md';

AnnualPlanFutureGateInput _input({
  bool? monthlySandboxPurchaseProofComplete,
  bool? paidIntentBetaShowsValue,
  bool? annualRevenueCatProductRequested,
  bool? paywallChangeRequested,
  bool? annualPlanRequested,
  bool? annualCopyMissingYearTrailFocus,
}) =>
    AnnualPlanFutureGateInput(
      monthlySandboxPurchaseProofComplete:
          monthlySandboxPurchaseProofComplete,
      paidIntentBetaShowsValue: paidIntentBetaShowsValue,
      annualRevenueCatProductRequested: annualRevenueCatProductRequested,
      paywallChangeRequested: paywallChangeRequested,
      annualPlanRequested: annualPlanRequested,
      annualCopyMissingYearTrailFocus: annualCopyMissingYearTrailFocus,
    );

AnnualPlanFuturePrereq _prereq(
  AnnualPlanFutureGateResult result,
  AnnualPlanFuturePrereqId id,
) =>
    result.prereqs.firstWhere((prereq) => prereq.id == id);

AnnualPlanFutureRule _rule(
  AnnualPlanFutureGateResult result,
  AnnualPlanFutureRuleId id,
) =>
    result.rules.firstWhere((rule) => rule.id == id);

void main() {
  group('AnnualPlanFutureGate.build', () {
    test('gate tracks two prerequisites and five rules in order', () {
      final result = AnnualPlanFutureGate.build(_input());
      expect(result.prereqs.length, AnnualPlanFutureGate.prereqCount);
      expect(result.rules.length, AnnualPlanFutureGate.ruleCount);
      expect(result.prereqOrder, AnnualPlanFutureGate.canonicalPrereqOrder);
      expect(result.ruleOrder, AnnualPlanFutureGate.canonicalRuleOrder);
    });

    test('default input -> annualPlanFrozen with changes blocked', () {
      final result = AnnualPlanFutureGate.build(_input());
      expect(result.decision, AnnualPlanFutureGateDecision.annualPlanFrozen);
      expect(result.annualRevenueCatProductBlocked, isTrue);
      expect(result.paywallChangesBlocked, isTrue);
      expect(result.rulesPass, isTrue);
      expect(
        result.plan.status,
        AnnualPlanFuturePlanStatus.blockedBeforeProof,
      );
    });

    test('both prereqs complete -> annualPlanDocumented', () {
      final result = AnnualPlanFutureGate.build(
        _input(
          monthlySandboxPurchaseProofComplete: true,
          paidIntentBetaShowsValue: true,
        ),
      );
      expect(
        result.decision,
        AnnualPlanFutureGateDecision.annualPlanDocumented,
      );
      expect(result.prereqsComplete, isTrue);
      expect(
        result.plan.status,
        AnnualPlanFuturePlanStatus.futureAnnualPlanDocumented,
      );
      expect(
        result.yearTrailFocusCopy,
        AnnualPlanFutureCopy.yearTrailFocusCopy,
      );
    });

    test('pending monthly proof -> annualPlanFrozen', () {
      final result = AnnualPlanFutureGate.build(
        _input(monthlySandboxPurchaseProofComplete: null),
      );
      expect(result.decision, AnnualPlanFutureGateDecision.annualPlanFrozen);
      expect(
        result.earliestPrereqGap,
        AnnualPlanFuturePrereqId.monthlySandboxPurchaseProofComplete,
      );
    });

    test('annual RevenueCat product requested fails product rule', () {
      final result = AnnualPlanFutureGate.build(
        _input(annualRevenueCatProductRequested: true),
      );
      expect(
        _rule(
          result,
          AnnualPlanFutureRuleId.noAnnualRevenueCatProductNow,
        ).status,
        AnnualPlanFutureRuleStatus.fail,
      );
    });

    test('paywall change requested fails paywall rule', () {
      final result = AnnualPlanFutureGate.build(
        _input(paywallChangeRequested: true),
      );
      expect(
        _rule(result, AnnualPlanFutureRuleId.noPaywallChangesNow).status,
        AnnualPlanFutureRuleStatus.fail,
      );
    });

    test('annual plan requested without monthly proof fails proof rule', () {
      final result = AnnualPlanFutureGate.build(
        _input(
          monthlySandboxPurchaseProofComplete: false,
          annualPlanRequested: true,
        ),
      );
      expect(
        _rule(
          result,
          AnnualPlanFutureRuleId.annualPlanRequiresMonthlySandboxPurchaseProof,
        ).status,
        AnnualPlanFutureRuleStatus.fail,
      );
    });

    test('annual plan requested without beta value fails value rule', () {
      final result = AnnualPlanFutureGate.build(
        _input(
          paidIntentBetaShowsValue: false,
          annualPlanRequested: true,
        ),
      );
      expect(
        _rule(
          result,
          AnnualPlanFutureRuleId.annualPlanRequiresPaidIntentBetaValue,
        ).status,
        AnnualPlanFutureRuleStatus.fail,
      );
    });

    test('missing year trail focus fails copy rule', () {
      final result = AnnualPlanFutureGate.build(
        _input(annualCopyMissingYearTrailFocus: true),
      );
      expect(
        _rule(
          result,
          AnnualPlanFutureRuleId.copyFocusesOnLongerProofTrailForYear,
        ).status,
        AnnualPlanFutureRuleStatus.fail,
      );
    });

    test('canonical rules pass for gate copy', () {
      final result = AnnualPlanFutureGate.build(_input());
      for (final rule in result.rules) {
        expect(rule.status, AnnualPlanFutureRuleStatus.pass, reason: rule.id.name);
      }
    });

    test('evaluateCopyPassesRules rejects annual RevenueCat product copy', () {
      expect(
        AnnualPlanFutureGate.evaluateCopyPassesRules(
          'Add annual RevenueCat product and new annual subscription today.',
        ),
        isFalse,
      );
    });

    test('evaluateCopyPassesRules rejects paywall change copy', () {
      expect(
        AnnualPlanFutureGate.evaluateCopyPassesRules(
          'Change the paywall and redesign paywall layout now.',
        ),
        isFalse,
      );
    });

    test('report exposes canonical copy', () {
      final report = AnnualPlanFutureGate.report(
        AnnualPlanFutureGate.build(_input()),
      );
      expect(report.headline, AnnualPlanFutureCopy.headline);
      expect(report.futureAnnualPlanLine, AnnualPlanFutureCopy.futureAnnualPlanLine);
      expect(report.guardrail, AnnualPlanFutureCopy.guardrail);
    });
  });

  group('AnnualPlanFutureGate.composeInput', () {
    test('bridges launch checklist sandbox purchase works', () {
      final input = AnnualPlanFutureGate.composeInput(
        launchChecklist: const SingleLaunchChecklistInput(
          sandboxPurchaseWorks: true,
        ),
      );
      expect(input.monthlySandboxPurchaseProofComplete, isTrue);
    });

    test('bridges paid-intent purchase completed as monthly proof', () {
      final input = AnnualPlanFutureGate.composeInput(
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
      expect(input.monthlySandboxPurchaseProofComplete, isTrue);
      expect(input.paidIntentBetaShowsValue, isTrue);
    });
  });

  group('AnnualPlanFutureGate.fromRepoSignals', () {
    late String docsSource;
    late String gateCopySource;

    setUpAll(() {
      docsSource = File(_docsPath).readAsStringSync();
      gateCopySource = File(
        'lib/features/annual_plan_future/annual_plan_future_copy.dart',
      ).readAsStringSync();
    });

    test('detectDocListsRules matches docs', () {
      expect(AnnualPlanFutureGate.detectDocListsRules(docsSource), isTrue);
    });

    test('detectGuardrailPresentInCopy matches gate copy', () {
      expect(
        AnnualPlanFutureGate.detectGuardrailPresentInCopy(gateCopySource),
        isTrue,
      );
    });

    test('detectYearTrailFocusPresentInCopy matches gate copy', () {
      expect(
        AnnualPlanFutureGate.detectYearTrailFocusPresentInCopy(gateCopySource),
        isTrue,
      );
    });

    test('fromRepoSignals defaults to annualPlanFrozen', () {
      final result = AnnualPlanFutureGate.build(
        AnnualPlanFutureGate.fromRepoSignals(
          annualPlanFutureDocSource: docsSource,
          gateCopySource: gateCopySource,
        ),
      );
      expect(result.decision, AnnualPlanFutureGateDecision.annualPlanFrozen);
      expect(
        _prereq(
          result,
          AnnualPlanFuturePrereqId.monthlySandboxPurchaseProofComplete,
        ).status,
        AnnualPlanFuturePrereqStatus.pending,
      );
    });
  });

  group('protected regression', () {
    test('docs describe annual plan future scope', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('annual plan future'));
      expect(doc, contains('no annual revenuecat product'));
      expect(doc, contains('no paywall changes'));
      expect(doc, contains('monthly sandbox purchase proof'));
      expect(doc, contains('paid-intent beta'));
      expect(doc, contains('longer proof trail for the year'));
      expect(doc, contains('future revenue test'));
    });

    test('guardrail blocks annual product and paywall changes', () {
      final guardrail = AnnualPlanFutureCopy.guardrail.toLowerCase();
      expect(guardrail, contains('annual plan future gate'));
      expect(guardrail, contains('do not add annual revenuecat product now'));
      expect(guardrail, contains('do not change paywall now'));
      expect(guardrail, contains('monthly sandbox purchase proof first'));
      expect(guardrail, contains('paid-intent beta showing value'));
      expect(guardrail, contains('longer proof trail for the year'));
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final copy in AnnualPlanFutureCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });

    test('module does not import RevenueCat or paywall UI', () {
      for (final path in [
        'lib/features/annual_plan_future/annual_plan_future_gate.dart',
        'lib/features/annual_plan_future/annual_plan_future_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
        expect(source.contains('revenuecat_service'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
      }
    });

    test('advice guard registers annual plan future copy', () {
      final guardSource = File(
        'lib/features/archive_proof/proof_surface_advice_guard.dart',
      ).readAsStringSync();
      expect(
        guardSource,
        contains('AnnualPlanFutureCopy.allVisibleStrings()'),
      );
    });
  });
}
