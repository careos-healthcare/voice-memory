import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/contradiction_change_future/contradiction_change_future_copy.dart';
import 'package:voicememory_mobile/features/contradiction_change_future/contradiction_change_future_gate.dart';
import 'package:voicememory_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'package:voicememory_mobile/features/single_launch_checklist/single_launch_checklist.dart';

const _docsPath = 'docs/CONTRADICTION_CHANGE_FUTURE.md';

ContradictionChangeFutureGateInput _input({
  bool? strongProofTrailComplete,
  bool? paidIntentBetaComplete,
  bool? v1ChangeDetectionUiRequested,
}) => ContradictionChangeFutureGateInput(
  strongProofTrailComplete: strongProofTrailComplete,
  paidIntentBetaComplete: paidIntentBetaComplete,
  v1ChangeDetectionUiRequested: v1ChangeDetectionUiRequested,
);

ContradictionChangeFutureRule _rule(
  ContradictionChangeFutureGateResult result,
  ContradictionChangeFutureRuleId id,
) => result.rules.firstWhere((rule) => rule.id == id);

ContradictionChangeFuturePrereq _prereq(
  ContradictionChangeFutureGateResult result,
  ContradictionChangeFuturePrereqId id,
) => result.prereqs.firstWhere((prereq) => prereq.id == id);

void main() {
  group('ContradictionChangeFutureGate.build', () {
    test('gate tracks seven canonical rules in order', () {
      final result = ContradictionChangeFutureGate.build(_input());
      expect(result.rules.length, ContradictionChangeFutureGate.ruleCount);
      expect(
        result.ruleOrder,
        ContradictionChangeFutureGate.canonicalRuleOrder,
      );
      expect(
        result.rules.map((rule) => rule.id).toList(),
        ContradictionChangeFutureGate.canonicalRuleOrder,
      );
    });

    test('gate tracks two canonical prereqs in order', () {
      final result = ContradictionChangeFutureGate.build(_input());
      expect(result.prereqs.length, ContradictionChangeFutureGate.prereqCount);
      expect(
        result.prereqOrder,
        ContradictionChangeFutureGate.canonicalPrereqOrder,
      );
    });

    test('default input -> changeFrozen with directive language blocked', () {
      final result = ContradictionChangeFutureGate.build(_input());
      expect(
        result.decision,
        ContradictionChangeFutureGateDecision.changeFrozen,
      );
      expect(result.v1LiveUiBlocked, isTrue);
      expect(result.coachingLanguageBlocked, isTrue);
      expect(result.forecastLanguageBlocked, isTrue);
      expect(result.clinicalLabelBlocked, isTrue);
      expect(result.rulesPass, isTrue);
      expect(
        result.futureValueLanguage,
        ContradictionChangeFutureGate.canonicalFutureValueLanguage,
      );
    });

    test(
      'proof trail and beta complete -> futureChangeDetectionDocumented',
      () {
        final result = ContradictionChangeFutureGate.build(
          _input(strongProofTrailComplete: true, paidIntentBetaComplete: true),
        );
        expect(
          result.decision,
          ContradictionChangeFutureGateDecision.futureChangeDetectionDocumented,
        );
        expect(result.proofTrailComplete, isTrue);
        expect(result.v1LiveUiBlocked, isTrue);
      },
    );

    test(
      'v1 change UI requested without proof trail fails strongProofTrailRequired',
      () {
        final result = ContradictionChangeFutureGate.build(
          _input(
            strongProofTrailComplete: false,
            v1ChangeDetectionUiRequested: true,
          ),
        );
        expect(
          _rule(
            result,
            ContradictionChangeFutureRuleId.strongProofTrailRequired,
          ).status,
          ContradictionChangeFutureRuleStatus.fail,
        );
        expect(
          _rule(result, ContradictionChangeFutureRuleId.noNewLiveV1Ui).status,
          ContradictionChangeFutureRuleStatus.fail,
        );
      },
    );

    test('canonical rules pass for gate copy', () {
      final result = ContradictionChangeFutureGate.build(_input());
      for (final rule in result.rules) {
        expect(
          rule.status,
          ContradictionChangeFutureRuleStatus.pass,
          reason: rule.id.name,
        );
      }
    });

    test('evaluateCopyPassesRules rejects clinical-label copy', () {
      expect(
        ContradictionChangeFutureGate.evaluateCopyPassesRules(
          'This clinical diagnosis report explains the shift.',
        ),
        isFalse,
      );
    });

    test('evaluateCopyPassesRules rejects directive copy', () {
      expect(
        ContradictionChangeFutureGate.evaluateCopyPassesRules(
          'You should try this directive plan next.',
        ),
        isFalse,
      );
    });

    test('evaluateCopyPassesRules rejects forecast copy', () {
      expect(
        ContradictionChangeFutureGate.evaluateCopyPassesRules(
          'This will happen and you will change soon.',
        ),
        isFalse,
      );
    });

    test('report exposes canonical copy', () {
      final report = ContradictionChangeFutureGate.report(
        ContradictionChangeFutureGate.build(_input()),
      );
      expect(report.headline, ContradictionChangeFutureCopy.headline);
      expect(
        report.futureValueLine,
        ContradictionChangeFutureCopy.futureValueLine,
      );
      expect(report.guardrail, ContradictionChangeFutureCopy.guardrail);
    });
  });

  group('ContradictionChangeFutureGate.composeInput', () {
    test('bridges launch checklist paid-intent beta complete', () {
      final input = ContradictionChangeFutureGate.composeInput(
        launchChecklist: const SingleLaunchChecklistInput(
          paidIntentBetaComplete: true,
        ),
      );
      expect(input.paidIntentBetaComplete, isTrue);
    });

    test('bridges paid-intent promising as beta complete', () {
      final input = ContradictionChangeFutureGate.composeInput(
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
      expect(input.paidIntentBetaComplete, isTrue);
      expect(input.strongProofTrailComplete, isTrue);
    });
  });

  group('ContradictionChangeFutureGate.fromRepoSignals', () {
    late String docsSource;
    late String gateCopySource;

    setUpAll(() {
      docsSource = File(_docsPath).readAsStringSync();
      gateCopySource = File(
        'lib/features/contradiction_change_future/contradiction_change_future_copy.dart',
      ).readAsStringSync();
    });

    test('detectDocListsRules matches docs', () {
      expect(
        ContradictionChangeFutureGate.detectDocListsRules(docsSource),
        isTrue,
      );
    });

    test('detectGuardrailPresentInCopy matches gate copy', () {
      expect(
        ContradictionChangeFutureGate.detectGuardrailPresentInCopy(
          gateCopySource,
        ),
        isTrue,
      );
    });

    test('detectFutureValuePresentInCopy matches gate copy', () {
      expect(
        ContradictionChangeFutureGate.detectFutureValuePresentInCopy(
          gateCopySource,
        ),
        isTrue,
      );
    });

    test('fromRepoSignals defaults to changeFrozen', () {
      final result = ContradictionChangeFutureGate.build(
        ContradictionChangeFutureGate.fromRepoSignals(
          contradictionChangeFutureDocSource: docsSource,
          gateCopySource: gateCopySource,
        ),
      );
      expect(
        result.decision,
        ContradictionChangeFutureGateDecision.changeFrozen,
      );
      expect(
        _prereq(
          result,
          ContradictionChangeFuturePrereqId.strongProofTrailComplete,
        ).status,
        ContradictionChangeFuturePrereqStatus.pending,
      );
    });
  });

  group('protected regression', () {
    test('docs describe future change detection scope', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('contradiction change'));
      expect(doc, contains('you used to say this'));
      expect(doc, contains('now your saved moments show something different'));
      expect(doc, contains('this repeat may be changing'));
      expect(doc, contains('strong proof trail'));
      expect(doc, contains('correction allowed'));
      expect(doc, contains('clinical-label'));
      expect(doc, contains('directive'));
      expect(doc, contains('forecast'));
      expect(doc, contains('no new live v1 ui'));
    });

    test('guardrail forbids directive and forecast language', () {
      final guardrail = ContradictionChangeFutureCopy.guardrail.toLowerCase();
      expect(guardrail, contains('future premium change detection'));
      expect(guardrail, contains('strong proof trail'));
      expect(guardrail, contains('correction allowed'));
      expect(guardrail, contains('do not add clinical-label'));
      expect(guardrail, contains('directive'));
      expect(guardrail, contains('forecast'));
      expect(guardrail, contains('no new live v1 ui'));
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final copy in ContradictionChangeFutureCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });

    test('module does not import live contradiction detection UI', () {
      for (final path in [
        'lib/features/contradiction_change_future/contradiction_change_future_gate.dart',
        'lib/features/contradiction_change_future/contradiction_change_future_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('contradiction_detection_service'), isFalse);
        expect(source.contains('archive_v1_contradictions_section'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
      }
    });

    test('advice guard registers contradiction change future copy', () {
      final guardSource = File(
        'lib/features/archive_proof/proof_surface_advice_guard.dart',
      ).readAsStringSync();
      expect(
        guardSource,
        contains('ContradictionChangeFutureCopy.allVisibleStrings()'),
      );
    });
  });
}
