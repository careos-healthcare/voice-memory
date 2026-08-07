import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/first_proof_success_beta/first_proof_success_beta_guard.dart';
import 'package:voicememory_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'package:voicememory_mobile/features/single_launch_checklist/single_launch_checklist.dart';
import 'package:voicememory_mobile/features/three_day_proof_challenge/three_day_proof_challenge_copy.dart';
import 'package:voicememory_mobile/features/three_day_proof_challenge/three_day_proof_challenge_gate.dart';

const _docsPath = 'docs/THREE_DAY_PROOF_CHALLENGE.md';

ThreeDayProofChallengeGateInput _input({
  bool? paidIntentBetaComplete,
  bool? usersNeedThreeDayChallenge,
}) => ThreeDayProofChallengeGateInput(
  paidIntentBetaComplete: paidIntentBetaComplete,
  usersNeedThreeDayChallenge: usersNeedThreeDayChallenge,
);

void main() {
  group('ThreeDayProofChallengeGate.build', () {
    test('gate tracks four canonical rules in order', () {
      final result = ThreeDayProofChallengeGate.build(_input());
      expect(result.rules.length, ThreeDayProofChallengeGate.ruleCount);
      expect(result.ruleOrder, ThreeDayProofChallengeGate.canonicalRuleOrder);
      expect(
        result.rules.map((rule) => rule.id).toList(),
        ThreeDayProofChallengeGate.canonicalRuleOrder,
      );
    });

    test('default input -> futureAcquisitionOnly with V1 blocked', () {
      final result = ThreeDayProofChallengeGate.build(_input());
      expect(
        result.decision,
        ThreeDayProofChallengeGateDecision.futureAcquisitionOnly,
      );
      expect(result.v1SurfacingBlocked, isTrue);
      expect(result.rulesPass, isTrue);
      expect(result.promise, ThreeDayProofChallengeCopy.promise);
    });

    test(
      'paid-intent beta complete without user need -> futureAcquisitionOnly',
      () {
        final result = ThreeDayProofChallengeGate.build(
          _input(
            paidIntentBetaComplete: true,
            usersNeedThreeDayChallenge: false,
          ),
        );
        expect(
          result.decision,
          ThreeDayProofChallengeGateDecision.futureAcquisitionOnly,
        );
        expect(result.v1SurfacingBlocked, isTrue);
      },
    );

    test('paid-intent beta and user need -> v1SurfacingAllowed', () {
      final result = ThreeDayProofChallengeGate.build(
        _input(paidIntentBetaComplete: true, usersNeedThreeDayChallenge: true),
      );
      expect(
        result.decision,
        ThreeDayProofChallengeGateDecision.v1SurfacingAllowed,
      );
      expect(result.v1SurfacingBlocked, isFalse);
    });

    test('user need without paid-intent beta -> futureAcquisitionOnly', () {
      final result = ThreeDayProofChallengeGate.build(
        _input(paidIntentBetaComplete: false, usersNeedThreeDayChallenge: true),
      );
      expect(
        result.decision,
        ThreeDayProofChallengeGateDecision.futureAcquisitionOnly,
      );
      expect(result.v1SurfacingBlocked, isTrue);
    });

    test('canonical rules pass for gate copy', () {
      final result = ThreeDayProofChallengeGate.build(_input());
      for (final rule in result.rules) {
        expect(
          rule.status,
          ThreeDayProofChallengeRuleStatus.pass,
          reason: rule.id.name,
        );
      }
    });

    test('evaluateCopyPassesRules rejects streak pressure copy', () {
      expect(
        ThreeDayProofChallengeGate.evaluateCopyPassesRules(
          'Keep your streak alive for 3 days.',
        ),
        isFalse,
      );
    });

    test('evaluateCopyPassesRules rejects required check-in copy', () {
      expect(
        ThreeDayProofChallengeGate.evaluateCopyPassesRules(
          'Must check in every morning.',
        ),
        isFalse,
      );
    });

    test('report exposes canonical copy', () {
      final report = ThreeDayProofChallengeGate.report(
        ThreeDayProofChallengeGate.build(_input()),
      );
      expect(report.headline, ThreeDayProofChallengeCopy.headline);
      expect(report.promise, ThreeDayProofChallengeCopy.promise);
      expect(report.guardrail, ThreeDayProofChallengeCopy.guardrail);
    });
  });

  group('ThreeDayProofChallengeGate.composeInput', () {
    test('bridges paid-intent beta and notEnoughMoments need signal', () {
      final input = ThreeDayProofChallengeGate.composeInput(
        launchChecklist: const SingleLaunchChecklistInput(
          paidIntentBetaComplete: true,
        ),
        firstProofSuccessBeta: FirstProofSuccessBetaGuard.build(
          FirstProofSuccessBetaInput(
            usableMomentCount: 1,
            proofThresholdStillThree: true,
            betaReadinessStillGuardsThree: true,
          ),
        ),
      );
      final result = ThreeDayProofChallengeGate.build(input);
      expect(input.paidIntentBetaComplete, isTrue);
      expect(input.usersNeedThreeDayChallenge, isTrue);
      expect(
        result.decision,
        ThreeDayProofChallengeGateDecision.v1SurfacingAllowed,
      );
    });

    test('bridges proofNotReached as user need signal', () {
      final input = ThreeDayProofChallengeGate.composeInput(
        paidIntentBeta: PaidIntentBetaProof.build(
          const PaidIntentBetaProofInput(
            firstSaveCompleted: true,
            firstUsefulProofSeen: false,
          ),
        ),
      );
      expect(input.usersNeedThreeDayChallenge, isTrue);
    });
  });

  group('ThreeDayProofChallengeGate.fromRepoSignals', () {
    late String docsSource;
    late String gateCopySource;

    setUpAll(() {
      docsSource = File(_docsPath).readAsStringSync();
      gateCopySource = File(
        'lib/features/three_day_proof_challenge/three_day_proof_challenge_copy.dart',
      ).readAsStringSync();
    });

    test('detectDocListsPromise matches docs', () {
      expect(
        ThreeDayProofChallengeGate.detectDocListsPromise(docsSource),
        isTrue,
      );
    });

    test('detectGuardrailPresentInCopy matches gate copy', () {
      expect(
        ThreeDayProofChallengeGate.detectGuardrailPresentInCopy(gateCopySource),
        isTrue,
      );
    });

    test('fromRepoSignals defaults to futureAcquisitionOnly', () {
      final result = ThreeDayProofChallengeGate.build(
        ThreeDayProofChallengeGate.fromRepoSignals(
          threeDayProofChallengeDocSource: docsSource,
          gateCopySource: gateCopySource,
        ),
      );
      expect(
        result.decision,
        ThreeDayProofChallengeGateDecision.futureAcquisitionOnly,
      );
    });
  });

  group('protected regression', () {
    test('docs describe future challenge scope without V1 changes', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('three day proof challenge'));
      expect(doc, contains('save 3 real moments in 3 days'));
      expect(doc, contains('no streaks'));
      expect(doc, contains('no daily pressure'));
      expect(doc, contains('no required check-in'));
    });

    test('guardrail forbids streaks daily pressure and required check-ins', () {
      final guardrail = ThreeDayProofChallengeCopy.guardrail.toLowerCase();
      expect(guardrail, contains('do not add streaks'));
      expect(guardrail, contains('daily pressure'));
      expect(guardrail, contains('required check-ins'));
    });

    test('promise matches spec', () {
      expect(
        ThreeDayProofChallengeCopy.promise,
        'Save 3 real moments in 3 days. See the first useful proof.',
      );
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final copy in ThreeDayProofChallengeCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });

    test('module does not import live challenge UI or paywall sources', () {
      for (final path in [
        'lib/features/three_day_proof_challenge/three_day_proof_challenge_gate.dart',
        'lib/features/three_day_proof_challenge/three_day_proof_challenge_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
        expect(source.contains('three_day_challenge_card'), isFalse);
      }
    });

    test('advice guard registers three day proof challenge copy', () {
      final guardSource = File(
        'lib/features/archive_proof/proof_surface_advice_guard.dart',
      ).readAsStringSync();
      expect(
        guardSource,
        contains('ThreeDayProofChallengeCopy.allVisibleStrings()'),
      );
    });
  });
}
