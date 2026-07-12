import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'package:voicememory_mobile/features/price_objection_feedback/price_objection_feedback_copy.dart';
import 'package:voicememory_mobile/features/price_objection_feedback/price_objection_feedback_gate.dart';

const _docsPath = 'docs/PRICE_OBJECTION_FEEDBACK.md';

PriceObjectionFeedbackGateInput _input({
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
    );

PriceObjectionFeedbackRule _rule(
  PriceObjectionFeedbackGateResult result,
  PriceObjectionFeedbackRuleId id,
) =>
    result.rules.firstWhere((rule) => rule.id == id);

void main() {
  group('PriceObjectionFeedbackGate.shouldShowFeedback', () {
    test('hidden before Pro tap', () {
      expect(
        PriceObjectionFeedbackGate.shouldShowFeedback(_input()),
        isFalse,
      );
    });

    test('shown after Pro tap without purchase', () {
      expect(
        PriceObjectionFeedbackGate.shouldShowFeedback(
          _input(proTapped: true, purchaseCompleted: false),
        ),
        isTrue,
      );
    });

    test('hidden after purchase completed', () {
      expect(
        PriceObjectionFeedbackGate.shouldShowFeedback(
          _input(proTapped: true, purchaseCompleted: true),
        ),
        isFalse,
      );
    });

    test('hidden for Pro users', () {
      expect(
        PriceObjectionFeedbackGate.shouldShowFeedback(
          _input(proTapped: true, purchaseCompleted: false, isPro: true),
        ),
        isFalse,
      );
    });
  });

  group('PriceObjectionFeedbackGate.build', () {
    test('gate tracks seven reasons and five rules in order', () {
      final result = PriceObjectionFeedbackGate.build(_input());
      expect(result.reasons.length, PriceObjectionFeedbackGate.reasonCount);
      expect(result.rules.length, PriceObjectionFeedbackGate.ruleCount);
      expect(result.reasonOrder, PriceObjectionFeedbackGate.canonicalReasonOrder);
      expect(result.ruleOrder, PriceObjectionFeedbackGate.canonicalRuleOrder);
    });

    test('default input -> objectionFeedbackFrozen', () {
      final result = PriceObjectionFeedbackGate.build(_input());
      expect(
        result.decision,
        PriceObjectionFeedbackGateDecision.objectionFeedbackFrozen,
      );
      expect(result.shouldShowFeedback, isFalse);
      expect(result.priceChangesBlocked, isTrue);
      expect(result.discountsBlocked, isTrue);
      expect(result.newFeaturesBlocked, isTrue);
      expect(result.paidIntentBetaOnly, isTrue);
      expect(result.rulesPass, isTrue);
    });

    test('pro tap without purchase -> objectionFeedbackDocumented', () {
      final result = PriceObjectionFeedbackGate.build(
        _input(proTapped: true, purchaseCompleted: false),
      );
      expect(
        result.decision,
        PriceObjectionFeedbackGateDecision.objectionFeedbackDocumented,
      );
      expect(result.shouldShowFeedback, isTrue);
    });

    test('feedback requested before Pro tap fails show rule', () {
      final result = PriceObjectionFeedbackGate.build(
        _input(
          proTapped: false,
          feedbackRequested: true,
        ),
      );
      expect(
        _rule(
          result,
          PriceObjectionFeedbackRuleId.showOnlyAfterProTapWithoutPurchase,
        ).status,
        PriceObjectionFeedbackRuleStatus.fail,
      );
    });

    test('price change requested fails price rule', () {
      final result = PriceObjectionFeedbackGate.build(
        _input(
          proTapped: true,
          purchaseCompleted: false,
          priceChangeRequested: true,
        ),
      );
      expect(
        _rule(result, PriceObjectionFeedbackRuleId.doNotChangePrice).status,
        PriceObjectionFeedbackRuleStatus.fail,
      );
    });

    test('discount requested fails discount rule', () {
      final result = PriceObjectionFeedbackGate.build(
        _input(
          proTapped: true,
          purchaseCompleted: false,
          discountRequested: true,
        ),
      );
      expect(
        _rule(result, PriceObjectionFeedbackRuleId.doNotAddDiscounts).status,
        PriceObjectionFeedbackRuleStatus.fail,
      );
    });

    test('new feature requested fails feature rule', () {
      final result = PriceObjectionFeedbackGate.build(
        _input(
          proTapped: true,
          purchaseCompleted: false,
          newFeatureRequested: true,
        ),
      );
      expect(
        _rule(result, PriceObjectionFeedbackRuleId.doNotAddNewFeatures).status,
        PriceObjectionFeedbackRuleStatus.fail,
      );
    });

    test('non-beta interpretation requested fails interpretation rule', () {
      final result = PriceObjectionFeedbackGate.build(
        _input(
          proTapped: true,
          purchaseCompleted: false,
          nonBetaInterpretationRequested: true,
        ),
      );
      expect(
        _rule(
          result,
          PriceObjectionFeedbackRuleId.feedPaidIntentBetaInterpretationOnly,
        ).status,
        PriceObjectionFeedbackRuleStatus.fail,
      );
    });

    test('canonical rules pass for gate copy', () {
      final result = PriceObjectionFeedbackGate.build(
        _input(proTapped: true, purchaseCompleted: false),
      );
      for (final rule in result.rules) {
        expect(rule.status, PriceObjectionFeedbackRuleStatus.pass, reason: rule.id.name);
      }
    });

    test('evaluateCopyPassesRules rejects price change copy', () {
      expect(
        PriceObjectionFeedbackGate.evaluateCopyPassesRules(
          'Change the price and adjust pricing today.',
        ),
        isFalse,
      );
    });

    test('evaluateCopyPassesRules rejects discount copy', () {
      expect(
        PriceObjectionFeedbackGate.evaluateCopyPassesRules(
          'Add a discount with a promo code now.',
        ),
        isFalse,
      );
    });

    test('evaluateCopyPassesRules rejects new feature copy', () {
      expect(
        PriceObjectionFeedbackGate.evaluateCopyPassesRules(
          'Add new feature and ship sync backup this week.',
        ),
        isFalse,
      );
    });

    test('report exposes canonical copy', () {
      final report = PriceObjectionFeedbackGate.report(
        PriceObjectionFeedbackGate.build(
          _input(proTapped: true, purchaseCompleted: false),
        ),
      );
      expect(report.headline, PriceObjectionFeedbackCopy.headline);
      expect(report.guardrail, PriceObjectionFeedbackCopy.guardrail);
      expect(report.reasonOrderLine, PriceObjectionFeedbackCopy.reasonOrderLine);
    });
  });

  group('PriceObjectionFeedbackGate.composeInput', () {
    test('bridges paid-intent proof signals', () {
      final input = PriceObjectionFeedbackGate.composeInput(
        paidIntentBeta: PaidIntentBetaProof.build(
          const PaidIntentBetaProofInput(
            firstSaveCompleted: true,
            firstUsefulProofSeen: true,
            proofAcceptedOrCorrected: true,
            proPromiseSeen: true,
            proTapped: true,
            purchaseAttempted: true,
            purchaseCompleted: false,
          ),
        ),
      );
      expect(input.proTapped, isTrue);
      expect(input.purchaseCompleted, isFalse);
    });
  });

  group('PriceObjectionFeedbackGate.fromRepoSignals', () {
    late String docsSource;
    late String copySource;

    setUpAll(() {
      docsSource = File(_docsPath).readAsStringSync();
      copySource = File(
        'lib/features/price_objection_feedback/price_objection_feedback_copy.dart',
      ).readAsStringSync();
    });

    test('detectDocListsRules matches docs', () {
      expect(
        PriceObjectionFeedbackGate.detectDocListsRules(docsSource),
        isTrue,
      );
    });

    test('detectGuardrailPresentInCopy matches copy', () {
      expect(
        PriceObjectionFeedbackGate.detectGuardrailPresentInCopy(copySource),
        isTrue,
      );
    });

    test('detectReasonsPresentInCopy matches copy', () {
      expect(
        PriceObjectionFeedbackGate.detectReasonsPresentInCopy(copySource),
        isTrue,
      );
    });

    test('fromRepoSignals defaults to objectionFeedbackFrozen', () {
      final result = PriceObjectionFeedbackGate.build(
        PriceObjectionFeedbackGate.fromRepoSignals(
          priceObjectionFeedbackDocSource: docsSource,
          gateCopySource: copySource,
        ),
      );
      expect(
        result.decision,
        PriceObjectionFeedbackGateDecision.objectionFeedbackFrozen,
      );
    });
  });

  group('protected regression', () {
    test('docs describe price objection feedback scope', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('price objection feedback'));
      expect(doc, contains('need stronger proof'));
      expect(doc, contains('too expensive'));
      expect(doc, contains('not clear what pro keeps'));
      expect(doc, contains('not ready yet'));
      expect(doc, contains('wanted sync/backup'));
      expect(doc, contains('wanted reports'));
      expect(doc, contains('other'));
      expect(doc, contains('show only after pro tap without purchase'));
      expect(doc, contains('do not change price'));
      expect(doc, contains('do not add discounts'));
      expect(doc, contains('do not add new features'));
      expect(doc, contains('paid-intent beta interpretation'));
    });

    test('guardrail enforces post-tap feedback only', () {
      final guardrail = PriceObjectionFeedbackCopy.guardrail.toLowerCase();
      expect(guardrail, contains('show only after pro tap without purchase'));
      expect(guardrail, contains('do not change price'));
      expect(guardrail, contains('do not add discounts'));
      expect(guardrail, contains('do not add new features'));
      expect(guardrail, contains('feed paid-intent beta interpretation only'));
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final copy in PriceObjectionFeedbackCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });

    test('module does not import paywall billing or RevenueCat service', () {
      for (final path in [
        'lib/features/price_objection_feedback/price_objection_feedback_gate.dart',
        'lib/features/price_objection_feedback/price_objection_feedback_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
        expect(source.contains('revenuecat_service'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
      }
    });

    test('advice guard registers price objection feedback copy', () {
      final guardSource = File(
        'lib/features/archive_proof/proof_surface_advice_guard.dart',
      ).readAsStringSync();
      expect(
        guardSource,
        contains('PriceObjectionFeedbackCopy.allVisibleStrings()'),
      );
    });
  });
}
