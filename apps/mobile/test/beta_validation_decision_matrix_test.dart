import 'dart:io';

import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/beta_validation_decision_matrix/beta_validation_decision_matrix_copy.dart';
import 'package:archiveme_mobile/features/beta_validation_decision_matrix/beta_validation_decision_matrix_engine.dart';
import 'package:archiveme_mobile/features/beta_validation_decision_matrix/beta_validation_decision_matrix_model.dart';
import 'package:archiveme_mobile/features/revenue_readiness/revenue_readiness_dashboard_v2_engine.dart';
import 'package:archiveme_mobile/features/revenue_readiness/revenue_readiness_dashboard_v2_model.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/beta/beta_validation_decision_matrix_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

BetaValidationDecisionMatrixInput _input({
  int testerCount = 20,
  int firstSessionSaveCount = 0,
  int usefulProofCount = 0,
  int sawProCount = 0,
  int understandsProYesMaybeCount = 0,
  int paywallCtaTapCount = 0,
  int? wouldPayYesMaybeCount,
}) => BetaValidationDecisionMatrixInput(
  testerCount: testerCount,
  firstSessionSaveCount: firstSessionSaveCount,
  usefulProofCount: usefulProofCount,
  sawProCount: sawProCount,
  understandsProYesMaybeCount: understandsProYesMaybeCount,
  paywallCtaTapCount: paywallCtaTapCount,
  wouldPayYesMaybeCount: wouldPayYesMaybeCount,
);

Future<void> _pumpCard(
  WidgetTester tester, {
  required BetaValidationDecisionMatrixResult result,
}) async {
  ArchiveBetaMissionGate.enabledOverride = true;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: BetaValidationDecisionMatrixCard(resultOverride: result),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(ArchiveBetaMissionGate.resetForTest);
  tearDown(ArchiveBetaMissionGate.resetForTest);

  group('BetaValidationDecisionMatrixEngine thresholds', () {
    test('uses 20-tester thresholds for 20-29 testers', () {
      final thresholds = BetaValidationDecisionMatrixEngine.thresholdsFor(25);
      expect(thresholds.cohortSize, 20);
      expect(thresholds.firstSessionSaveTarget, 5);
      expect(thresholds.usefulProofTarget, 5);
      expect(thresholds.sawProTarget, 3);
      expect(thresholds.understandsProTarget, 3);
      expect(thresholds.paywallCtaTapTarget, 2);
      expect(thresholds.wouldPayTarget, 3);
    });

    test('uses 30-tester thresholds for 30+ testers', () {
      final thresholds = BetaValidationDecisionMatrixEngine.thresholdsFor(30);
      expect(thresholds.cohortSize, 30);
      expect(thresholds.firstSessionSaveTarget, 8);
      expect(thresholds.usefulProofTarget, 8);
      expect(thresholds.sawProTarget, 5);
      expect(thresholds.understandsProTarget, 5);
      expect(thresholds.paywallCtaTapTarget, 3);
      expect(thresholds.wouldPayTarget, 5);
    });
  });

  group('BetaValidationDecisionMatrixEngine outcomes', () {
    test('insufficientData under 20 testers', () {
      final result = BetaValidationDecisionMatrixEngine.buildFromInput(
        _input(testerCount: 19, usefulProofCount: 10),
      );
      expect(result.outcome, BetaValidationDecisionOutcome.insufficientData);
    });

    test('protectProof wins over all later failures', () {
      final result = BetaValidationDecisionMatrixEngine.buildFromInput(
        _input(
          usefulProofCount: 4,
        ),
      );
      expect(result.outcome, BetaValidationDecisionOutcome.protectProof);
    });

    test(
      'fixOpeningScreenOnly wins after proof passes but first-session fails',
      () {
        final result = BetaValidationDecisionMatrixEngine.buildFromInput(
          _input(usefulProofCount: 5, firstSessionSaveCount: 4),
        );
        expect(
          result.outcome,
          BetaValidationDecisionOutcome.fixOpeningScreenOnly,
        );
      },
    );

    test(
      'fixProPlacement wins after proof and first-session pass but saw Pro fails',
      () {
        final result = BetaValidationDecisionMatrixEngine.buildFromInput(
          _input(usefulProofCount: 5, firstSessionSaveCount: 5, sawProCount: 2),
        );
        expect(result.outcome, BetaValidationDecisionOutcome.fixProPlacement);
      },
    );

    test(
      'fixProExplanation wins after saw Pro passes but understands Pro fails',
      () {
        final result = BetaValidationDecisionMatrixEngine.buildFromInput(
          _input(
            usefulProofCount: 5,
            firstSessionSaveCount: 5,
            sawProCount: 3,
            understandsProYesMaybeCount: 2,
          ),
        );
        expect(result.outcome, BetaValidationDecisionOutcome.fixProExplanation);
      },
    );

    test(
      'fixPaywallValue wins when earlier gates pass and paywall CTA tap is 0',
      () {
        final result = BetaValidationDecisionMatrixEngine.buildFromInput(
          _input(
            usefulProofCount: 5,
            firstSessionSaveCount: 5,
            sawProCount: 3,
            understandsProYesMaybeCount: 3,
          ),
        );
        expect(result.outcome, BetaValidationDecisionOutcome.fixPaywallValue);
      },
    );

    test('widenBetaAndValidatePricing when all pass', () {
      final result = BetaValidationDecisionMatrixEngine.buildFromInput(
        _input(
          usefulProofCount: 5,
          firstSessionSaveCount: 5,
          sawProCount: 3,
          understandsProYesMaybeCount: 3,
          paywallCtaTapCount: 2,
          wouldPayYesMaybeCount: 3,
        ),
      );
      expect(
        result.outcome,
        BetaValidationDecisionOutcome.widenBetaAndValidatePricing,
      );
    });
  });

  group('BetaValidationDecisionMatrixCopy', () {
    test('passes metadata-safe guard', () {
      for (final text in BetaValidationDecisionMatrixCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });
  });

  group('BetaValidationDecisionMatrixCard', () {
    testWidgets('renders all metrics with actual/target', (tester) async {
      final result = BetaValidationDecisionMatrixEngine.buildFromInput(
        _input(
          usefulProofCount: 4,
          firstSessionSaveCount: 5,
          sawProCount: 3,
          understandsProYesMaybeCount: 2,
          paywallCtaTapCount: 1,
          wouldPayYesMaybeCount: 2,
        ),
      );
      await _pumpCard(tester, result: result);

      expect(find.text('First-session saves: 5/5'), findsOneWidget);
      expect(find.text('Useful proof: 4/5'), findsOneWidget);
      expect(find.text('Saw Pro: 3/3'), findsOneWidget);
      expect(find.text('Understands Pro (yes/maybe): 2/3'), findsOneWidget);
      expect(find.text('Paywall CTA tapped: 1/2'), findsOneWidget);
      expect(find.text('Would pay (yes/maybe): 2/3'), findsOneWidget);
    });

    testWidgets('says Only fix this one next', (tester) async {
      final result = BetaValidationDecisionMatrixEngine.buildFromInput(
        _input(usefulProofCount: 4),
      );
      await _pumpCard(tester, result: result);

      expect(
        find.text(BetaValidationDecisionMatrixCopy.onlyFixThisOneNext),
        findsOneWidget,
      );
    });
  });

  group('Integration wiring', () {
    test('no product behavior changes in engine', () {
      final source = File(
        'lib/features/beta_validation_decision_matrix/beta_validation_decision_matrix_engine.dart',
      ).readAsStringSync();
      expect(source.contains('PaywallSource'), isFalse);
      expect(source.contains('RevenueCat'), isFalse);
      expect(source.contains('purchase'), isFalse);
    });

    test('testing screen renders card', () {
      final source = File(
        '../../packages/archiveme_research/lib/screens/testing_archiveme_screen.dart',
      ).readAsStringSync();
      expect(source, contains('BetaValidationDecisionMatrixCard'));
    });

    test('revenue dashboard exposes selected validation outcome', () {
      final dashboard = RevenueReadinessDashboardV2Engine.buildFromInput(
        const RevenueReadinessDashboardV2Input(
          testerCount: 20,
          usefulCount: 4,
          firstSessionSaveCount: 5,
          sawProCount: 3,
          understandsProYesMaybe: 2,
          paywallCtaTapped: 1,
        ),
      );
      expect(
        dashboard.validationDecision.outcome,
        BetaValidationDecisionOutcome.protectProof,
      );

      final cardSource = File(
        'lib/widgets/beta/revenue_readiness_dashboard_v2_card.dart',
      ).readAsStringSync();
      expect(cardSource, contains('validationDecision'));
      expect(cardSource, contains('_ValidationDecisionBlock'));
    });
  });
}