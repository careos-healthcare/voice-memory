import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta_fix_playbooks/beta_fix_playbook_copy.dart';
import 'package:voicememory_mobile/features/beta_fix_playbooks/beta_fix_playbook_engine.dart';
import 'package:voicememory_mobile/features/beta_validation_decision_matrix/beta_validation_decision_matrix_model.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/beta/beta_fix_playbook_card.dart';

Future<void> _pumpCard(
  WidgetTester tester, {
  required BetaValidationDecisionOutcome outcome,
}) async {
  ArchiveBetaMissionGate.enabledOverride = true;
  final result = BetaFixPlaybookEngine.buildForOutcome(outcome);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: BetaFixPlaybookCard(
            resultOverride: result,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(ArchiveBetaMissionGate.resetForTest);
  tearDown(ArchiveBetaMissionGate.resetForTest);

  group('BetaFixPlaybookEngine', () {
    test('no playbook for insufficientData', () {
      final result = BetaFixPlaybookEngine.buildForOutcome(
        BetaValidationDecisionOutcome.insufficientData,
      );
      expect(result.shouldShow, isFalse);
    });

    test('protectProof playbook has correct diagnosis and do-not-do list', () {
      final result = BetaFixPlaybookEngine.buildForOutcome(
        BetaValidationDecisionOutcome.protectProof,
      );
      expect(result.title, BetaFixPlaybookCopy.protectProofTitle);
      expect(result.diagnosis, BetaFixPlaybookCopy.protectProofDiagnosis);
      expect(result.fixPlan, contains(BetaFixPlaybookCopy.protectProofFix6));
      expect(result.doNotDo, contains(BetaFixPlaybookCopy.protectProofDont1));
      expect(result.doNotDo, contains(BetaFixPlaybookCopy.protectProofDont4));
    });

    test('fixOpeningScreenOnly does not prescribe Pro changes as fix plan', () {
      final result = BetaFixPlaybookEngine.buildForOutcome(
        BetaValidationDecisionOutcome.fixOpeningScreenOnly,
      );
      expect(result.diagnosis, BetaFixPlaybookCopy.openingScreenDiagnosis);
      expect(result.doNotDo, contains(BetaFixPlaybookCopy.openingScreenDont2));
      for (final step in result.fixPlan) {
        expect(step.toLowerCase().contains('change pro'), isFalse);
      }
    });

    test('fixProPlacement blocks weak-proof Pro pressure', () {
      final result = BetaFixPlaybookEngine.buildForOutcome(
        BetaValidationDecisionOutcome.fixProPlacement,
      );
      expect(result.fixPlan, contains(BetaFixPlaybookCopy.proPlacementFix3));
      expect(result.doNotDo, contains(BetaFixPlaybookCopy.proPlacementDont1));
      expect(result.doNotDo, contains(BetaFixPlaybookCopy.proPlacementDont3));
    });

    test('fixProExplanation includes Free vs Pro guidance', () {
      final result = BetaFixPlaybookEngine.buildForOutcome(
        BetaValidationDecisionOutcome.fixProExplanation,
      );
      expect(result.fixPlan, contains(BetaFixPlaybookCopy.proExplanationFix1));
      expect(result.fixPlan, contains(BetaFixPlaybookCopy.proExplanationFix3));
    });

    test('fixPaywallValue avoids RevenueCat changes', () {
      final result = BetaFixPlaybookEngine.buildForOutcome(
        BetaValidationDecisionOutcome.fixPaywallValue,
      );
      expect(result.diagnosis, BetaFixPlaybookCopy.paywallValueDiagnosis);
      expect(result.doNotDo, contains(BetaFixPlaybookCopy.paywallValueDont2));
      expect(result.doNotDo, contains(BetaFixPlaybookCopy.paywallValueDont3));
    });

    test('widenBeta playbook renders widen/pricing guidance', () {
      final result = BetaFixPlaybookEngine.buildForOutcome(
        BetaValidationDecisionOutcome.widenBetaAndValidatePricing,
      );
      expect(result.title, BetaFixPlaybookCopy.widenBetaTitle);
      expect(result.fixPlan, contains(BetaFixPlaybookCopy.widenBetaFix2));
      expect(result.doNotDo, contains(BetaFixPlaybookCopy.widenBetaDont1));
    });
  });

  group('BetaFixPlaybookCopy', () {
    test('passes metadata-safe guard on guidance copy', () {
      for (final outcome in BetaValidationDecisionOutcome.values) {
        if (outcome == BetaValidationDecisionOutcome.insufficientData) {
          continue;
        }
        expect(
          ProofSurfaceAdviceGuard.passes(BetaFixPlaybookCopy.titleFor(outcome)),
          isTrue,
          reason: outcome.name,
        );
        expect(
          ProofSurfaceAdviceGuard.passes(
            BetaFixPlaybookCopy.diagnosisFor(outcome),
          ),
          isTrue,
          reason: outcome.name,
        );
        for (final step in BetaFixPlaybookCopy.fixPlanFor(outcome)) {
          expect(ProofSurfaceAdviceGuard.passes(step), isTrue, reason: step);
        }
      }
      expect(
        ProofSurfaceAdviceGuard.passes(BetaFixPlaybookCopy.guidanceOnlyNote),
        isTrue,
      );
    });
  });

  group('BetaFixPlaybookCard', () {
    testWidgets('card says guidance only', (tester) async {
      await _pumpCard(
        tester,
        outcome: BetaValidationDecisionOutcome.protectProof,
      );
      expect(
        find.text(BetaFixPlaybookCopy.guidanceOnlyNote),
        findsOneWidget,
      );
    });

    testWidgets('protectProof playbook renders diagnosis and do-not-do', (
      tester,
    ) async {
      await _pumpCard(
        tester,
        outcome: BetaValidationDecisionOutcome.protectProof,
      );
      expect(find.text(BetaFixPlaybookCopy.protectProofDiagnosis), findsOneWidget);
      expect(find.textContaining(BetaFixPlaybookCopy.protectProofDont1),
          findsOneWidget);
    });
  });

  group('Integration wiring', () {
    test('no product behavior changes in engine', () {
      final source =
          File('lib/features/beta_fix_playbooks/beta_fix_playbook_engine.dart')
              .readAsStringSync();
      expect(source.contains('PaywallSource'), isFalse);
      expect(source.contains('RevenueCat'), isFalse);
      expect(source.contains('shouldShowCard'), isFalse);
    });

    test('testing screen renders playbook card', () {
      final source =
          File('lib/screens/testing_archiveme_screen.dart').readAsStringSync();
      expect(source, contains('BetaFixPlaybookCard'));
    });

    test('revenue dashboard references playbook diagnosis', () {
      final source = File(
        'lib/widgets/beta/revenue_readiness_dashboard_v2_card.dart',
      ).readAsStringSync();
      expect(source, contains('BetaFixPlaybookEngine'));
    });
  });
}
