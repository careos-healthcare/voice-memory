import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/proof_protection/proof_repair_outcome_matrix.dart';
import 'package:voicememory_mobile/features/proof_protection/proof_repair_playbooks.dart';
import 'package:voicememory_mobile/features/proof_protection/proof_repair_playbooks_copy.dart';

void main() {
  group('ProofRepairPlaybooks.fromOutcome mapping', () {
    test('every outcome maps to the correct playbook', () {
      final cases = <(ProofRepairOutcomeDecision, ProofRepairPlaybook)>[
        (
          ProofRepairOutcomeDecision.insufficientData,
          ProofRepairPlaybook.waitForMoreData,
        ),
        (
          ProofRepairOutcomeDecision.repairProofAgain,
          ProofRepairPlaybook.repairProofAgain,
        ),
        (
          ProofRepairOutcomeDecision.tightenAnchorsAgain,
          ProofRepairPlaybook.tightenAnchorsAgain,
        ),
        (
          ProofRepairOutcomeDecision.proofStableReturnToEvidenceTrail,
          ProofRepairPlaybook.returnToEvidenceTrail,
        ),
        (
          ProofRepairOutcomeDecision.productionCandidate,
          ProofRepairPlaybook.productionReadiness,
        ),
      ];

      for (final (decision, expectedPlaybook) in cases) {
        final plan = ProofRepairPlaybooks.fromOutcome(decision);
        expect(plan.playbook, expectedPlaybook);
      }
    });
  });

  group('ProofRepairPlaybookPlan content', () {
    test('each playbook returns required title problem and action', () {
      for (final playbook in ProofRepairPlaybook.values) {
        final plan = ProofRepairPlaybooks.fromOutcome(_decisionFor(playbook));
        expect(plan.title, ProofRepairPlaybooksCopy.titleFor(playbook));
        expect(plan.problem, ProofRepairPlaybooksCopy.problemFor(playbook));
        expect(plan.action, ProofRepairPlaybooksCopy.actionFor(playbook));
        expect(plan.title.trim(), isNotEmpty);
        expect(plan.problem.trim(), isNotEmpty);
        expect(plan.action.trim(), isNotEmpty);
      }
    });

    test('successMetric is present for every playbook', () {
      for (final playbook in ProofRepairPlaybook.values) {
        final metric = ProofRepairPlaybooksCopy.successMetricFor(playbook);
        expect(metric.trim(), isNotEmpty);
        expect(
          ProofRepairPlaybooks.fromOutcome(
            _decisionFor(playbook),
          ).successMetric,
          metric,
        );
      }
    });
  });

  group('Playbook guardrails', () {
    test('repairProofAgain blocks Pro pricing and timeline', () {
      final plan = ProofRepairPlaybooks.fromOutcome(
        ProofRepairOutcomeDecision.repairProofAgain,
      );
      expect(plan.blockedChanges, contains('Pro card changes'));
      expect(plan.blockedChanges, contains('Pricing changes'));
      expect(plan.blockedChanges, contains('Evidence trail card changes'));
      expect(plan.action, contains('Pro, pricing, and timeline work blocked'));
    });

    test('tightenAnchorsAgain blocks lowering thresholds', () {
      final plan = ProofRepairPlaybooks.fromOutcome(
        ProofRepairOutcomeDecision.tightenAnchorsAgain,
      );
      expect(plan.blockedChanges, contains('Lowering proof thresholds'));
      expect(plan.blockedChanges, contains('Showing more proof to compensate'));
    });

    test('returnToEvidenceTrail blocks proof engine changes', () {
      final plan = ProofRepairPlaybooks.fromOutcome(
        ProofRepairOutcomeDecision.proofStableReturnToEvidenceTrail,
      );
      expect(plan.blockedChanges, contains('Proof engine changes'));
      expect(plan.blockedChanges, contains('Anchor changes'));
      expect(plan.allowedChanges, contains('Evidence trail clarity copy'));
    });

    test('waitForMoreData blocks all product changes', () {
      final plan = ProofRepairPlaybooks.fromOutcome(
        ProofRepairOutcomeDecision.insufficientData,
      );
      expect(plan.allowedChanges, ['None']);
      expect(plan.blockedChanges, contains('Product changes'));
      expect(plan.blockedChanges, contains('Proof changes'));
      expect(plan.blockedChanges, contains('Pro changes'));
      expect(plan.blockedChanges, contains('Pricing changes'));
    });

    test('productionReadiness blocks product features', () {
      final plan = ProofRepairPlaybooks.fromOutcome(
        ProofRepairOutcomeDecision.productionCandidate,
      );
      expect(plan.blockedChanges, contains('Product features'));
      expect(plan.blockedChanges, contains('Proof changes'));
      expect(plan.blockedChanges, contains('Pro changes'));
      expect(plan.blockedChanges, contains('Pricing changes'));
      expect(plan.allowedChanges, contains('Store metadata'));
      expect(plan.allowedChanges, contains('RevenueCat verification'));
    });
  });

  group('ProofRepairPlaybooksCopy safety', () {
    test('passes metadata-safe guard', () {
      for (final text in ProofRepairPlaybooksCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });
  });

  group('Protected areas', () {
    test('no protected pricing purchase or UI files touched', () {
      for (final path in [
        'lib/features/proof_protection/proof_repair_playbooks.dart',
        'lib/features/proof_protection/proof_repair_playbooks_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('PaywallSource'), isFalse);
        expect(source.contains('restorePurchases'), isFalse);
        expect(source.contains('billing/'), isFalse);
        expect(source.contains('record_screen'), isFalse);
      }
    });
  });
}

ProofRepairOutcomeDecision _decisionFor(ProofRepairPlaybook playbook) =>
    switch (playbook) {
      ProofRepairPlaybook.waitForMoreData =>
        ProofRepairOutcomeDecision.insufficientData,
      ProofRepairPlaybook.repairProofAgain =>
        ProofRepairOutcomeDecision.repairProofAgain,
      ProofRepairPlaybook.tightenAnchorsAgain =>
        ProofRepairOutcomeDecision.tightenAnchorsAgain,
      ProofRepairPlaybook.returnToEvidenceTrail =>
        ProofRepairOutcomeDecision.proofStableReturnToEvidenceTrail,
      ProofRepairPlaybook.productionReadiness =>
        ProofRepairOutcomeDecision.productionCandidate,
    };
