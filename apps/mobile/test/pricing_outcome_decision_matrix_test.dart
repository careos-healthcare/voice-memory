import 'dart:io';

import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/pricing_validation/pricing_outcome_decision_copy.dart';
import 'package:archiveme_mobile/features/pricing_validation/pricing_outcome_decision_matrix.dart';
import 'package:flutter_test/flutter_test.dart';

PricingValidationSummary _summary({
  int totalTesters = 30,
  int usefulProofCount = 10,
  int sawProCount = 8,
  int understandsProCount = 7,
  int paywallCtaTapCount = 5,
  int wouldPayYesMaybeCount = 0,
  int price299Count = 0,
  int price499Count = 0,
  int price799Count = 0,
  int wouldNotPayMonthlyCount = 0,
  int moreProofOverTimeCount = 0,
  int betterCorrectionsCount = 0,
  int clearerTimelineCount = 0,
  int lowerPriceCount = 0,
}) => PricingValidationSummary(
  totalTesters: totalTesters,
  usefulProofCount: usefulProofCount,
  sawProCount: sawProCount,
  understandsProCount: understandsProCount,
  paywallCtaTapCount: paywallCtaTapCount,
  wouldPayYesMaybeCount: wouldPayYesMaybeCount,
  price299Count: price299Count,
  price499Count: price499Count,
  price799Count: price799Count,
  wouldNotPayMonthlyCount: wouldNotPayMonthlyCount,
  moreProofOverTimeCount: moreProofOverTimeCount,
  betterCorrectionsCount: betterCorrectionsCount,
  clearerTimelineCount: clearerTimelineCount,
  lowerPriceCount: lowerPriceCount,
);

void main() {
  group('PricingOutcomeDecisionMatrix thresholds', () {
    test('uses 7/30 equivalent useful proof target', () {
      expect(PricingOutcomeDecisionMatrix.usefulProofTargetFor(30), 7);
      expect(PricingOutcomeDecisionMatrix.usefulProofTargetFor(20), 5);
    });

    test('uses 4/30 equivalent would-pay target', () {
      expect(PricingOutcomeDecisionMatrix.wouldPayTargetFor(30), 4);
      expect(PricingOutcomeDecisionMatrix.wouldPayTargetFor(20), 3);
    });
  });

  group('PricingOutcomeDecisionMatrix.resolve', () {
    test('total testers below 20 returns insufficientData', () {
      final decision = PricingOutcomeDecisionMatrix.resolve(
        _summary(totalTesters: 19),
      );
      expect(decision, PricingOutcomeDecision.insufficientData);
    });

    test('weak useful proof returns insufficientData', () {
      final decision = PricingOutcomeDecisionMatrix.resolve(
        _summary(usefulProofCount: 6),
      );
      expect(decision, PricingOutcomeDecision.insufficientData);
    });

    test('most would not pay monthly returns subscriptionRisk', () {
      final decision = PricingOutcomeDecisionMatrix.resolve(
        _summary(
          wouldNotPayMonthlyCount: 8,
          price299Count: 2,
          price499Count: 1,
          price799Count: 1,
        ),
      );
      expect(decision, PricingOutcomeDecision.subscriptionRisk);
    });

    test('more proof over time wins returns evidenceTrailFocus', () {
      final decision = PricingOutcomeDecisionMatrix.resolve(
        _summary(
          price499Count: 3,
          price799Count: 3,
          wouldNotPayMonthlyCount: 1,
          wouldPayYesMaybeCount: 4,
          moreProofOverTimeCount: 6,
          clearerTimelineCount: 2,
          lowerPriceCount: 2,
        ),
      );
      expect(decision, PricingOutcomeDecision.evidenceTrailFocus);
    });

    test('clearer timeline wins returns timelineClarity', () {
      final decision = PricingOutcomeDecisionMatrix.resolve(
        _summary(
          price499Count: 3,
          price799Count: 3,
          wouldNotPayMonthlyCount: 1,
          wouldPayYesMaybeCount: 4,
          clearerTimelineCount: 6,
          moreProofOverTimeCount: 2,
          lowerPriceCount: 2,
        ),
      );
      expect(decision, PricingOutcomeDecision.timelineClarity);
    });

    test('lower price reason wins returns lowerPriceTest', () {
      final decision = PricingOutcomeDecisionMatrix.resolve(
        _summary(
          price499Count: 3,
          price799Count: 3,
          wouldNotPayMonthlyCount: 1,
          wouldPayYesMaybeCount: 4,
          lowerPriceCount: 6,
          moreProofOverTimeCount: 2,
          clearerTimelineCount: 2,
        ),
      );
      expect(decision, PricingOutcomeDecision.lowerPriceTest);
    });

    test('£2.99 as largest positive price returns lowerPriceTest', () {
      final decision = PricingOutcomeDecisionMatrix.resolve(
        _summary(
          price299Count: 7,
          price499Count: 2,
          price799Count: 1,
          wouldNotPayMonthlyCount: 3,
          wouldPayYesMaybeCount: 2,
        ),
      );
      expect(decision, PricingOutcomeDecision.lowerPriceTest);
    });

    test('£4.99/£7.99 with enough would-pay returns pricingSignalStrong', () {
      final decision = PricingOutcomeDecisionMatrix.resolve(
        _summary(
          price299Count: 2,
          price499Count: 4,
          price799Count: 4,
          wouldNotPayMonthlyCount: 3,
          wouldPayYesMaybeCount: 5,
        ),
      );
      expect(decision, PricingOutcomeDecision.pricingSignalStrong);
    });

    test('ties resolve conservatively in documented order', () {
      final decision = PricingOutcomeDecisionMatrix.resolve(
        _summary(
          wouldNotPayMonthlyCount: 5,
          price299Count: 5,
          price499Count: 1,
          price799Count: 1,
          clearerTimelineCount: 5,
          lowerPriceCount: 5,
          moreProofOverTimeCount: 5,
          wouldPayYesMaybeCount: 5,
        ),
      );
      expect(decision, PricingOutcomeDecision.subscriptionRisk);
    });

    test('timelineClarity wins over lowerPriceTest and evidenceTrailFocus', () {
      final decision = PricingOutcomeDecisionMatrix.resolve(
        _summary(
          price499Count: 3,
          price799Count: 3,
          wouldNotPayMonthlyCount: 1,
          wouldPayYesMaybeCount: 4,
          clearerTimelineCount: 5,
          lowerPriceCount: 5,
          moreProofOverTimeCount: 5,
        ),
      );
      expect(decision, PricingOutcomeDecision.timelineClarity);
    });
  });

  group('PricingOutcomeDecisionCopy.report', () {
    test('returns title body nextAction and guardrail', () {
      final summary = _summary(
        wouldNotPayMonthlyCount: 8,
        price299Count: 1,
        price499Count: 1,
        price799Count: 1,
      );
      final decision = PricingOutcomeDecisionMatrix.resolve(summary);
      final report = PricingOutcomeDecisionCopy.report(summary, decision);

      expect(report.title, PricingOutcomeDecisionCopy.titleFor(decision));
      expect(report.body, PricingOutcomeDecisionCopy.bodyFor(decision));
      expect(
        report.nextAction,
        PricingOutcomeDecisionCopy.nextActionFor(decision),
      );
      expect(report.guardrail, PricingOutcomeDecisionCopy.guardrail);
      expect(report.title, 'Subscription risk');
      expect(
        report.nextAction,
        'Test subscription objection before changing price.',
      );
    });

    test('passes metadata-safe guard', () {
      for (final text in PricingOutcomeDecisionCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });
  });

  group('Protected areas', () {
    test('no protected pricing or purchase files touched', () {
      final engineSource = File(
        'lib/features/pricing_validation/pricing_outcome_decision_matrix.dart',
      ).readAsStringSync();
      expect(engineSource.contains('PaywallSource'), isFalse);
      expect(engineSource.contains('RevenueCat'), isFalse);
      expect(engineSource.contains('restorePurchases'), isFalse);
      expect(engineSource.contains('entitlement'), isFalse);
      expect(engineSource.contains('billing/'), isFalse);

      final copySource = File(
        'lib/features/pricing_validation/pricing_outcome_decision_copy.dart',
      ).readAsStringSync();
      expect(copySource.contains('PaywallSource'), isFalse);
      expect(copySource.contains('restorePurchases'), isFalse);
      expect(copySource.contains('billing/'), isFalse);
      expect(copySource, contains('Do not change RevenueCat'));
      expect(copySource, contains('or entitlements from this decision matrix'));
    });
  });
}