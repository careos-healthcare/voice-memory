import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/first_proof_success_beta/first_proof_success_beta_guard.dart';
import 'package:voicememory_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'package:voicememory_mobile/features/referral_after_proof/referral_after_proof_copy.dart';
import 'package:voicememory_mobile/features/referral_after_proof/referral_after_proof_gate.dart';

const _docsPath = 'docs/REFERRAL_AFTER_PROOF.md';

ReferralAfterProofGateInput _input({
  bool? proofValueReached,
  bool? usefulProofAccepted,
  bool? proPromiseUnderstood,
  bool? withinFirstFiveMinutes,
  bool? referralPromptRequested,
  bool existingReferralRoutePresent = true,
  bool referralRouteGated = true,
}) => ReferralAfterProofGateInput(
  proofValueReached: proofValueReached,
  usefulProofAccepted: usefulProofAccepted,
  proPromiseUnderstood: proPromiseUnderstood,
  withinFirstFiveMinutes: withinFirstFiveMinutes,
  referralPromptRequested: referralPromptRequested,
  existingReferralRoutePresent: existingReferralRoutePresent,
  referralRouteGated: referralRouteGated,
);

ReferralAfterProofRule _rule(
  ReferralAfterProofGateResult result,
  ReferralAfterProofRuleId id,
) => result.rules.firstWhere((rule) => rule.id == id);

void main() {
  group('ReferralAfterProofGate.build', () {
    test('gate tracks six canonical rules in order', () {
      final result = ReferralAfterProofGate.build(_input());
      expect(result.rules.length, ReferralAfterProofGate.ruleCount);
      expect(result.ruleOrder, ReferralAfterProofGate.canonicalRuleOrder);
      expect(
        result.rules.map((rule) => rule.id).toList(),
        ReferralAfterProofGate.canonicalRuleOrder,
      );
    });

    test('default input without proof value -> referralBlocked', () {
      final result = ReferralAfterProofGate.build(_input());
      expect(result.decision, ReferralAfterProofGateDecision.referralBlocked);
      expect(result.proofValueReached, isFalse);
      expect(result.privateContentSharingBlocked, isTrue);
      expect(result.paidPromiseBlocked, isTrue);
      expect(result.firstFiveMinutesSurfacingBlocked, isTrue);
    });

    test('proof value reached -> referralAfterProofAllowed', () {
      final result = ReferralAfterProofGate.build(
        _input(proofValueReached: true, usefulProofAccepted: true),
      );
      expect(
        result.decision,
        ReferralAfterProofGateDecision.referralAfterProofAllowed,
      );
      expect(result.rulesPass, isTrue);
      expect(result.v1LiveUiBlocked, isFalse);
    });

    test('pro promise understood unlocks referral after proof', () {
      final result = ReferralAfterProofGate.build(
        _input(proofValueReached: true, proPromiseUnderstood: true),
      );
      expect(
        result.decision,
        ReferralAfterProofGateDecision.referralAfterProofAllowed,
      );
    });

    test('referral prompt before proof value fails onlyAfterProofValue', () {
      final result = ReferralAfterProofGate.build(
        _input(proofValueReached: false, referralPromptRequested: true),
      );
      expect(
        _rule(result, ReferralAfterProofRuleId.onlyAfterProofValue).status,
        ReferralAfterProofRuleStatus.fail,
      );
    });

    test('referral prompt in first five minutes fails timing rule', () {
      final result = ReferralAfterProofGate.build(
        _input(
          proofValueReached: true,
          withinFirstFiveMinutes: true,
          referralPromptRequested: true,
        ),
      );
      expect(
        _rule(
          result,
          ReferralAfterProofRuleId.notShownInFirstFiveMinutes,
        ).status,
        ReferralAfterProofRuleStatus.fail,
      );
      expect(result.decision, ReferralAfterProofGateDecision.referralBlocked);
    });

    test('existing route without gating fails noLiveReferralUiUnlessGated', () {
      final result = ReferralAfterProofGate.build(
        _input(
          proofValueReached: true,
          existingReferralRoutePresent: true,
          referralRouteGated: false,
        ),
      );
      expect(
        _rule(
          result,
          ReferralAfterProofRuleId.noLiveReferralUiUnlessGated,
        ).status,
        ReferralAfterProofRuleStatus.fail,
      );
      expect(result.v1LiveUiBlocked, isTrue);
    });

    test('canonical rules pass for gate copy', () {
      final result = ReferralAfterProofGate.build(
        _input(proofValueReached: true),
      );
      for (final rule in result.rules) {
        expect(
          rule.status,
          ReferralAfterProofRuleStatus.pass,
          reason: rule.id.name,
        );
      }
    });

    test('evaluateCopyPassesRules rejects archive-sharing invite copy', () {
      expect(
        ReferralAfterProofGate.evaluateCopyPassesRules(
          'Here is my archive from this week.',
        ),
        isFalse,
      );
    });

    test('evaluateCopyPassesRules rejects paid-promise referral copy', () {
      expect(
        ReferralAfterProofGate.evaluateCopyPassesRules(
          'Invite friends to unlock Pro.',
        ),
        isFalse,
      );
    });

    test('report exposes canonical copy', () {
      final report = ReferralAfterProofGate.report(
        ReferralAfterProofGate.build(_input(proofValueReached: true)),
      );
      expect(report.headline, ReferralAfterProofCopy.headline);
      expect(report.positioning, ReferralAfterProofCopy.positioning);
      expect(report.guardrail, ReferralAfterProofCopy.guardrail);
    });
  });

  group('ReferralAfterProofGate.composeInput', () {
    test('bridges useful proof accepted from first proof beta input', () {
      final input = ReferralAfterProofGate.composeInput(
        firstProofSuccessBeta: const FirstProofSuccessBetaInput(
          usableMomentCount: 3,
          proofAccepted: true,
          userUnderstoodWhy: true,
        ),
      );
      expect(input.usefulProofAccepted, isTrue);
      expect(input.proofValueReached, isTrue);
    });

    test('bridges pro promise understood from first proof beta input', () {
      final input = ReferralAfterProofGate.composeInput(
        firstProofSuccessBeta: const FirstProofSuccessBetaInput(
          usableMomentCount: 3,
          proPromiseSeen: true,
          userUnderstoodWhy: true,
        ),
      );
      expect(input.proPromiseUnderstood, isTrue);
      expect(input.proofValueReached, isTrue);
    });

    test('bridges paid-intent proof accepted signal', () {
      final paidIntent = PaidIntentBetaProof.build(
        const PaidIntentBetaProofInput(
          firstSaveCompleted: true,
          firstUsefulProofSeen: true,
          proofAcceptedOrCorrected: true,
        ),
      );
      final input = ReferralAfterProofGate.composeInput(
        paidIntentBeta: paidIntent,
      );
      expect(input.usefulProofAccepted, isTrue);
      expect(input.proofValueReached, isTrue);
    });
  });

  group('ReferralAfterProofGate.fromRepoSignals', () {
    late String docsSource;
    late String gateCopySource;
    late String appRouterSource;
    late String referralImplementationSource;

    setUpAll(() {
      docsSource = File(_docsPath).readAsStringSync();
      gateCopySource = File(
        'lib/features/referral_after_proof/referral_after_proof_copy.dart',
      ).readAsStringSync();
      appRouterSource = File('lib/router/app_router.dart').readAsStringSync();
      referralImplementationSource = File(
        'lib/features/referral/referral_invite_after_value.dart',
      ).readAsStringSync();
    });

    test('detectDocListsRules matches docs', () {
      expect(ReferralAfterProofGate.detectDocListsRules(docsSource), isTrue);
    });

    test('detectGuardrailPresentInCopy matches gate copy', () {
      expect(
        ReferralAfterProofGate.detectGuardrailPresentInCopy(gateCopySource),
        isTrue,
      );
    });

    test('detectExistingReferralRouteInRouter matches /invite route', () {
      expect(
        ReferralAfterProofGate.detectExistingReferralRouteInRouter(
          appRouterSource,
        ),
        isTrue,
      );
    });

    test(
      'detectReferralRouteGatedInImplementation matches after-value gate',
      () {
        expect(
          ReferralAfterProofGate.detectReferralRouteGatedInImplementation(
            referralImplementationSource,
          ),
          isTrue,
        );
      },
    );

    test('fromRepoSignals defaults to referralBlocked', () {
      final result = ReferralAfterProofGate.build(
        ReferralAfterProofGate.fromRepoSignals(
          referralAfterProofDocSource: docsSource,
          gateCopySource: gateCopySource,
          appRouterSource: appRouterSource,
          referralImplementationSource: referralImplementationSource,
        ),
      );
      expect(result.decision, ReferralAfterProofGateDecision.referralBlocked);
      expect(result.existingReferralRoutePresent, isTrue);
      expect(result.referralRouteGated, isTrue);
    });
  });

  group('protected regression', () {
    test('docs describe after-proof referral scope', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('referral after proof'));
      expect(doc, contains('never share private content'));
      expect(doc, contains('not shown in first five minutes'));
      expect(doc, contains('not part of paid promise'));
      expect(doc, contains('no live referral ui'));
    });

    test('guardrail enforces proof-value and privacy rules', () {
      final guardrail = ReferralAfterProofCopy.guardrail.toLowerCase();
      expect(guardrail, contains('proof value'));
      expect(guardrail, contains('never share private content'));
      expect(guardrail, contains('invite shares product'));
      expect(guardrail, contains('not shown in first five minutes'));
      expect(guardrail, contains('not part of paid promise'));
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final copy in ReferralAfterProofCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });

    test('module does not import paywall or live referral card UI', () {
      for (final path in [
        'lib/features/referral_after_proof/referral_after_proof_gate.dart',
        'lib/features/referral_after_proof/referral_after_proof_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
        expect(source.contains('referral_invite_card'), isFalse);
      }
    });

    test('advice guard registers referral after proof copy', () {
      final guardSource = File(
        'lib/features/archive_proof/proof_surface_advice_guard.dart',
      ).readAsStringSync();
      expect(
        guardSource,
        contains('ReferralAfterProofCopy.allVisibleStrings()'),
      );
    });
  });
}
