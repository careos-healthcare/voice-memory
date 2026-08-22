import 'dart:io';

import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/beta_results_reader/beta_results_reader.dart';
import 'package:archiveme_mobile/features/beta_results_reader/beta_results_reader_copy.dart';
import 'package:archiveme_mobile/features/beta_results_reader/beta_results_summary.dart';
import 'package:flutter_test/flutter_test.dart';

BetaResultsSummary _summary({
  int totalTesters = 30,
  int firstSessionSaveCount = 8,
  int usefulProofCount = 10,
  int tooVagueOrNotRelevantCount = 2,
  int sawProCount = 6,
  int understandsProCount = 6,
  int paywallCtaTapCount = 2,
  int wouldPayYesMaybeCount = 4,
  int evidenceTrailClearCount = 5,
  int wouldNotPayMonthlyCount = 0,
  int moreProofOverTimeCount = 0,
  int clearerTimelineCount = 0,
  int lowerPriceCount = 0,
  int price299Count = 0,
  int price499Count = 0,
  int price799Count = 0,
}) => BetaResultsSummary(
  totalTesters: totalTesters,
  firstSessionSaveCount: firstSessionSaveCount,
  usefulProofCount: usefulProofCount,
  tooVagueOrNotRelevantCount: tooVagueOrNotRelevantCount,
  sawProCount: sawProCount,
  understandsProCount: understandsProCount,
  paywallCtaTapCount: paywallCtaTapCount,
  wouldPayYesMaybeCount: wouldPayYesMaybeCount,
  evidenceTrailClearCount: evidenceTrailClearCount,
  wouldNotPayMonthlyCount: wouldNotPayMonthlyCount,
  moreProofOverTimeCount: moreProofOverTimeCount,
  clearerTimelineCount: clearerTimelineCount,
  lowerPriceCount: lowerPriceCount,
  price299Count: price299Count,
  price499Count: price499Count,
  price799Count: price799Count,
);

BetaResultsSummary _productionPassingSummary({int totalTesters = 30}) =>
    _summary(
      totalTesters: totalTesters,
      firstSessionSaveCount: totalTesters == 20 ? 5 : 8,
      usefulProofCount: totalTesters == 20 ? 5 : 7,
      tooVagueOrNotRelevantCount: totalTesters == 20 ? 4 : 6,
      sawProCount: totalTesters == 20 ? 3 : 4,
      understandsProCount: totalTesters == 20 ? 3 : 4,
      paywallCtaTapCount: 1,
      wouldPayYesMaybeCount: totalTesters == 20 ? 2 : 3,
      evidenceTrailClearCount: totalTesters == 20 ? 3 : 4,
    );

void main() {
  group('BetaResultsReader thresholds', () {
    test('30 tester exact targets', () {
      expect(BetaResultsReader.firstSessionSaveTargetFor(30), 8);
      expect(BetaResultsReader.usefulProofTargetFor(30), 7);
      expect(BetaResultsReader.evidenceTrailClearTargetFor(30), 4);
      expect(BetaResultsReader.sawProTargetFor(30), 4);
      expect(BetaResultsReader.understandsProTargetFor(30), 4);
      expect(BetaResultsReader.paywallCtaTapTargetFor(30), 1);
      expect(BetaResultsReader.wouldPayTargetFor(30), 3);
    });

    test('20 tester scaled targets', () {
      expect(BetaResultsReader.firstSessionSaveTargetFor(20), 5);
      expect(BetaResultsReader.usefulProofTargetFor(20), 5);
      expect(BetaResultsReader.evidenceTrailClearTargetFor(20), 3);
      expect(BetaResultsReader.sawProTargetFor(20), 3);
      expect(BetaResultsReader.understandsProTargetFor(20), 3);
      expect(BetaResultsReader.paywallCtaTapTargetFor(20), 1);
      expect(BetaResultsReader.wouldPayTargetFor(20), 2);
    });
  });

  group('BetaResultsReader.resolve branches', () {
    test('under 20 testers returns insufficientData', () {
      expect(
        BetaResultsReader.resolve(_summary(totalTesters: 19)),
        BetaResultsDecision.insufficientData,
      );
    });

    test('useful proof below target returns protectProof', () {
      expect(
        BetaResultsReader.resolve(_summary(usefulProofCount: 6)),
        BetaResultsDecision.protectProof,
      );
    });

    test('too vague or not relevant high returns protectProof', () {
      expect(
        BetaResultsReader.resolve(_summary(tooVagueOrNotRelevantCount: 7)),
        BetaResultsDecision.protectProof,
      );
    });

    test('first session below target returns improveFirstSession', () {
      expect(
        BetaResultsReader.resolve(_summary(firstSessionSaveCount: 7)),
        BetaResultsDecision.improveFirstSession,
      );
    });

    test(
      'evidence trail clear below target returns improveTimelineExplanation',
      () {
        expect(
          BetaResultsReader.resolve(_summary(evidenceTrailClearCount: 3)),
          BetaResultsDecision.improveTimelineExplanation,
        );
      },
    );

    test('sawPro below target returns proTooHidden', () {
      expect(
        BetaResultsReader.resolve(
          _summary(sawProCount: 3),
        ),
        BetaResultsDecision.proTooHidden,
      );
    });

    test('understandsPro below target returns improveProExplanation', () {
      expect(
        BetaResultsReader.resolve(
          _summary(understandsProCount: 3),
        ),
        BetaResultsDecision.improveProExplanation,
      );
    });

    test('clarity passes but wouldPay weak returns pricingValidation', () {
      expect(
        BetaResultsReader.resolve(
          _summary(wouldPayYesMaybeCount: 2),
        ),
        BetaResultsDecision.pricingValidation,
      );
    });

    test('moreProofOverTime strongest returns evidenceTrailFocus', () {
      expect(
        BetaResultsReader.resolve(
          _summary(
            paywallCtaTapCount: 0,
            moreProofOverTimeCount: 6,
            clearerTimelineCount: 2,
            lowerPriceCount: 1,
          ),
        ),
        BetaResultsDecision.evidenceTrailFocus,
      );
    });

    test('all production targets pass returns productionCandidate', () {
      expect(
        BetaResultsReader.resolve(_productionPassingSummary()),
        BetaResultsDecision.productionCandidate,
      );
      expect(
        BetaResultsReader.resolve(_productionPassingSummary(totalTesters: 20)),
        BetaResultsDecision.productionCandidate,
      );
    });

    test('conservative fallback returns improveTimelineExplanation', () {
      expect(
        BetaResultsReader.resolve(
          _summary(
            paywallCtaTapCount: 0,
          ),
        ),
        BetaResultsDecision.improveTimelineExplanation,
      );
    });
  });

  group('BetaResultsReader priority order', () {
    test('proof problems beat everything', () {
      expect(
        BetaResultsReader.resolve(
          _summary(
            usefulProofCount: 6,
            firstSessionSaveCount: 0,
            sawProCount: 0,
            wouldPayYesMaybeCount: 0,
          ),
        ),
        BetaResultsDecision.protectProof,
      );
    });

    test('first-session issue beats Pro issue', () {
      expect(
        BetaResultsReader.resolve(
          _summary(firstSessionSaveCount: 7, sawProCount: 1),
        ),
        BetaResultsDecision.improveFirstSession,
      );
    });

    test('timeline clarity issue beats pricing issue', () {
      expect(
        BetaResultsReader.resolve(
          _summary(
            evidenceTrailClearCount: 3,
            wouldPayYesMaybeCount: 1,
            sawProCount: 5,
          ),
        ),
        BetaResultsDecision.improveTimelineExplanation,
      );
    });

    test('Pro hidden beats pricing issue', () {
      expect(
        BetaResultsReader.resolve(
          _summary(
            sawProCount: 3,
            wouldPayYesMaybeCount: 1,
          ),
        ),
        BetaResultsDecision.proTooHidden,
      );
    });
  });

  group('BetaResultsReaderCopy.report', () {
    test('returns correct nextAction', () {
      final summary = _summary(firstSessionSaveCount: 7);
      final decision = BetaResultsReader.resolve(summary);
      final report = BetaResultsReaderCopy.report(summary, decision);

      expect(decision, BetaResultsDecision.improveFirstSession);
      expect(
        report.nextAction,
        'Keep proof stable and improve the first recording prompt.',
      );
      expect(report.title, BetaResultsReaderCopy.titleFor(decision));
      expect(report.body, BetaResultsReaderCopy.bodyFor(decision));
      expect(report.guardrail, BetaResultsReaderCopy.guardrail);
    });

    test('passes metadata-safe guard', () {
      for (final text in BetaResultsReaderCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });
  });

  group('Protected areas', () {
    test('no protected pricing purchase or UI files touched', () {
      for (final path in [
        'lib/features/beta_results_reader/beta_results_reader.dart',
        'lib/features/beta_results_reader/beta_results_reader_copy.dart',
        'lib/features/beta_results_reader/beta_results_summary.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('PaywallSource'), isFalse);
        expect(source.contains('RevenueCat'), isFalse);
        expect(source.contains('restorePurchases'), isFalse);
        expect(source.contains('billing/'), isFalse);
        expect(source.contains('record_screen'), isFalse);
      }
    });
  });
}