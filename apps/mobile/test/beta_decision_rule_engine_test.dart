import 'dart:io';

import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/beta_decision_rules/beta_decision_rule_copy.dart';
import 'package:archiveme_mobile/features/beta_decision_rules/beta_decision_rule_engine.dart';
import 'package:archiveme_mobile/features/beta_decision_rules/beta_decision_rule_model.dart';
import 'package:archiveme_mobile/features/revenue_readiness/revenue_readiness_dashboard_v2_engine.dart';
import 'package:archiveme_mobile/features/revenue_readiness/revenue_readiness_dashboard_v2_model.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/beta/beta_decision_rule_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _privateTranscript =
    'I had no capacity but I said yes again to the extra meeting today.';

BetaDecisionRuleInput _input({
  int testerCount = 10,
  int firstSessionSaveCount = 0,
  int sawProCount = 0,
  int understandsProYesMaybeCount = 0,
  int usefulProofCount = 0,
}) => BetaDecisionRuleInput(
  testerCount: testerCount,
  firstSessionSaveCount: firstSessionSaveCount,
  sawProCount: sawProCount,
  understandsProYesMaybeCount: understandsProYesMaybeCount,
  usefulProofCount: usefulProofCount,
);

Future<void> _pumpCard(
  WidgetTester tester, {
  required BetaDecisionRuleResult result,
}) async {
  ArchiveBetaMissionGate.enabledOverride = true;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: BetaDecisionRuleCard(resultOverride: result),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(ArchiveBetaMissionGate.resetForTest);
  tearDown(ArchiveBetaMissionGate.resetForTest);

  group('BetaDecisionRuleEngine', () {
    test('returns insufficientData under 10 testers', () {
      final result = BetaDecisionRuleEngine.buildFromInput(
        _input(testerCount: 9, usefulProofCount: 5),
      );
      expect(result.outcome, BetaDecisionRuleOutcome.insufficientData);
    });

    test('protectProof wins if useful proof < 2', () {
      final result = BetaDecisionRuleEngine.buildFromInput(
        _input(usefulProofCount: 1),
      );
      expect(result.outcome, BetaDecisionRuleOutcome.protectProof);
    });

    test(
      'fixOpeningScreenOnly wins when first-session save <= 1 and proof safe',
      () {
        final result = BetaDecisionRuleEngine.buildFromInput(
          _input(firstSessionSaveCount: 1, usefulProofCount: 3),
        );
        expect(result.outcome, BetaDecisionRuleOutcome.fixOpeningScreenOnly);
      },
    );

    test(
      'fixProPlacement wins when first-session save >= 2 and saw Pro <= 1',
      () {
        final result = BetaDecisionRuleEngine.buildFromInput(
          _input(firstSessionSaveCount: 2, sawProCount: 1, usefulProofCount: 3),
        );
        expect(result.outcome, BetaDecisionRuleOutcome.fixProPlacement);
      },
    );

    test(
      'fixProExplanation wins when saw Pro >= 3 and understands Pro <= 1',
      () {
        final result = BetaDecisionRuleEngine.buildFromInput(
          _input(
            firstSessionSaveCount: 4,
            sawProCount: 3,
            understandsProYesMaybeCount: 1,
            usefulProofCount: 4,
          ),
        );
        expect(result.outcome, BetaDecisionRuleOutcome.fixProExplanation);
      },
    );

    test('continueMoreTesters when all gates pass', () {
      final result = BetaDecisionRuleEngine.buildFromInput(
        _input(
          firstSessionSaveCount: 4,
          sawProCount: 4,
          understandsProYesMaybeCount: 3,
          usefulProofCount: 4,
        ),
      );
      expect(result.outcome, BetaDecisionRuleOutcome.continueMoreTesters);
    });

    test('priority order puts protectProof above fixOpeningScreenOnly', () {
      final result = BetaDecisionRuleEngine.buildFromInput(
        _input(firstSessionSaveCount: 1, usefulProofCount: 1),
      );
      expect(result.outcome, BetaDecisionRuleOutcome.protectProof);
    });

    test('priority order puts fixOpeningScreenOnly above fixProPlacement', () {
      final result = BetaDecisionRuleEngine.buildFromInput(
        _input(firstSessionSaveCount: 1, usefulProofCount: 3),
      );
      expect(result.outcome, BetaDecisionRuleOutcome.fixOpeningScreenOnly);
    });

    test('priority order puts fixProPlacement above fixProExplanation', () {
      final result = BetaDecisionRuleEngine.buildFromInput(
        _input(
          firstSessionSaveCount: 2,
          sawProCount: 1,
          understandsProYesMaybeCount: 1,
          usefulProofCount: 3,
        ),
      );
      expect(result.outcome, BetaDecisionRuleOutcome.fixProPlacement);
    });
  });

  group('BetaDecisionRuleCopy', () {
    test('uses exact outcome copy', () {
      expect(
        BetaDecisionRuleCopy.titleFor(
          BetaDecisionRuleOutcome.fixOpeningScreenOnly,
        ),
        'Fix the opening screen only',
      );
      expect(
        BetaDecisionRuleCopy.bodyFor(BetaDecisionRuleOutcome.protectProof),
        contains('Useful proof dropped below the safe floor'),
      );
      expect(
        BetaDecisionRuleCopy.ctaFor(
          BetaDecisionRuleOutcome.continueMoreTesters,
        ),
        'Invite more testers',
      );
    });
  });

  group('BetaDecisionRuleCard', () {
    testWidgets('renders all outcome copy for protectProof', (tester) async {
      final result = BetaDecisionRuleEngine.buildFromInput(
        _input(usefulProofCount: 1),
      );
      await _pumpCard(tester, result: result);

      expect(find.text(result.title), findsOneWidget);
      expect(find.text(result.body), findsOneWidget);
      expect(find.text(result.reason), findsOneWidget);
      expect(find.text(result.cta), findsOneWidget);
    });

    testWidgets('shows counted inputs', (tester) async {
      final result = BetaDecisionRuleEngine.buildFromInput(
        _input(
          firstSessionSaveCount: 2,
          sawProCount: 1,
          understandsProYesMaybeCount: 1,
          usefulProofCount: 3,
        ),
      );
      await _pumpCard(tester, result: result);

      expect(find.textContaining('Testers: 10/10'), findsOneWidget);
      expect(find.textContaining('First-session saves: 2/10'), findsOneWidget);
      expect(find.textContaining('Saw Pro: 1/10'), findsOneWidget);
      expect(
        find.textContaining('Understands Pro (yes/maybe): 1/10'),
        findsOneWidget,
      );
      expect(find.textContaining('Useful proof: 3/10'), findsOneWidget);
    });

    testWidgets('no private journal text', (tester) async {
      final result = BetaDecisionRuleEngine.buildFromInput(
        _input(usefulProofCount: 1),
      );
      await _pumpCard(tester, result: result);

      expect(find.textContaining(_privateTranscript), findsNothing);
      for (final text in BetaDecisionRuleCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });
  });

  group('RevenueReadinessDashboardV2 integration', () {
    test('dashboard model exposes selected outcome', () {
      final dashboard = RevenueReadinessDashboardV2Engine.buildFromInput(
        const RevenueReadinessDashboardV2Input(
          testerCount: 10,
          firstSessionSaveCount: 1,
          sawProCount: 1,
          understandsProYesMaybe: 1,
          usefulCount: 3,
        ),
      );

      expect(
        dashboard.decisionRule.outcome,
        BetaDecisionRuleOutcome.fixOpeningScreenOnly,
      );
      expect(dashboard.sections.length, 4);
      expect(dashboard.hasDiagnoses, isFalse);
    });

    test('existing diagnosis fields still work', () {
      final dashboard = RevenueReadinessDashboardV2Engine.buildFromInput(
        const RevenueReadinessDashboardV2Input(
          recordScreenSeen: 10,
          firstMomentSaved: 1,
          testerCount: 10,
          firstSessionSaveCount: 1,
          usefulCount: 1,
        ),
      );

      expect(
        dashboard.diagnoses.any(
          (diagnosis) =>
              diagnosis.id ==
              RevenueReadinessDashboardV2DiagnosisId.lowFirstSave,
        ),
        isTrue,
      );
      expect(dashboard.decisionRule.outcome, isNotNull);
    });
  });

  group('Integration wiring', () {
    test('testing screen renders decision card', () {
      final source = File(
        '../../packages/archiveme_research/lib/screens/testing_archiveme_screen.dart',
      ).readAsStringSync();
      expect(source, contains('BetaDecisionRuleCard'));
      expect(source, contains('RevenueReadinessDashboardV2Card'));
    });

    test('revenue dashboard card shows selected decision rule', () {
      final source = File(
        'lib/widgets/beta/revenue_readiness_dashboard_v2_card.dart',
      ).readAsStringSync();
      expect(source, contains('decisionRule'));
      expect(source, contains('revenue_readiness_dashboard_v2_decision_rule'));
    });

    test('decision card copy stays metadata-safe', () {
      for (final text in BetaDecisionRuleCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });
  });
}