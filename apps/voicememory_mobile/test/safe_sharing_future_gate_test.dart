import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'package:voicememory_mobile/features/safe_sharing_future/safe_sharing_future_copy.dart';
import 'package:voicememory_mobile/features/safe_sharing_future/safe_sharing_future_gate.dart';
import 'package:voicememory_mobile/features/single_launch_checklist/single_launch_checklist.dart';

const _docsPath = 'docs/SAFE_SHARING_FUTURE.md';

SafeSharingFutureGateInput _input({
  bool? firstUsefulProofSeen,
  bool? paidIntentBetaComplete,
  bool? withinFirstFiveMinutes,
  bool? sharingPromptRequested,
  bool? v1SharingExpansionRequested,
}) => SafeSharingFutureGateInput(
  firstUsefulProofSeen: firstUsefulProofSeen,
  paidIntentBetaComplete: paidIntentBetaComplete,
  withinFirstFiveMinutes: withinFirstFiveMinutes,
  sharingPromptRequested: sharingPromptRequested,
  v1SharingExpansionRequested: v1SharingExpansionRequested,
);

SafeSharingFutureRule _rule(
  SafeSharingFutureGateResult result,
  SafeSharingFutureRuleId id,
) => result.rules.firstWhere((rule) => rule.id == id);

SafeSharingFuturePrereq _prereq(
  SafeSharingFutureGateResult result,
  SafeSharingFuturePrereqId id,
) => result.prereqs.firstWhere((prereq) => prereq.id == id);

void main() {
  group('SafeSharingFutureGate.build', () {
    test('gate tracks six canonical rules in order', () {
      final result = SafeSharingFutureGate.build(_input());
      expect(result.rules.length, SafeSharingFutureGate.ruleCount);
      expect(result.ruleOrder, SafeSharingFutureGate.canonicalRuleOrder);
      expect(
        result.rules.map((rule) => rule.id).toList(),
        SafeSharingFutureGate.canonicalRuleOrder,
      );
    });

    test('gate tracks two canonical prereqs in order', () {
      final result = SafeSharingFutureGate.build(_input());
      expect(result.prereqs.length, SafeSharingFutureGate.prereqCount);
      expect(result.prereqOrder, SafeSharingFutureGate.canonicalPrereqOrder);
    });

    test('default input -> sharingFrozen with privacy blocked', () {
      final result = SafeSharingFutureGate.build(_input());
      expect(result.decision, SafeSharingFutureGateDecision.sharingFrozen);
      expect(result.rawPrivateTextBlocked, isTrue);
      expect(result.explicitShareRequired, isTrue);
      expect(result.archiveContentSharingBlocked, isTrue);
      expect(result.firstFiveMinutesSharingBlocked, isTrue);
      expect(result.v1SharingExpansionBlocked, isTrue);
      expect(result.rulesPass, isTrue);
    });

    test('proof and beta complete -> futureGrowthSharingDocumented', () {
      final result = SafeSharingFutureGate.build(
        _input(firstUsefulProofSeen: true, paidIntentBetaComplete: true),
      );
      expect(
        result.decision,
        SafeSharingFutureGateDecision.futureGrowthSharingDocumented,
      );
      expect(result.sharingProofComplete, isTrue);
    });

    test('sharing prompt in first five minutes fails timing rule', () {
      final result = SafeSharingFutureGate.build(
        _input(
          firstUsefulProofSeen: true,
          paidIntentBetaComplete: true,
          withinFirstFiveMinutes: true,
          sharingPromptRequested: true,
        ),
      );
      expect(
        _rule(
          result,
          SafeSharingFutureRuleId.noSharingInFirstFiveMinutes,
        ).status,
        SafeSharingFutureRuleStatus.fail,
      );
      expect(result.decision, SafeSharingFutureGateDecision.sharingFrozen);
    });

    test('sharing prompt before first useful proof fails proof rule', () {
      final result = SafeSharingFutureGate.build(
        _input(firstUsefulProofSeen: false, sharingPromptRequested: true),
      );
      expect(
        _rule(
          result,
          SafeSharingFutureRuleId.noSharingBeforeFirstUsefulProof,
        ).status,
        SafeSharingFutureRuleStatus.fail,
      );
    });

    test(
      'v1 sharing expansion without proof fails noLiveV1SharingExpansion',
      () {
        final result = SafeSharingFutureGate.build(
          _input(
            firstUsefulProofSeen: false,
            paidIntentBetaComplete: false,
            v1SharingExpansionRequested: true,
          ),
        );
        expect(
          _rule(
            result,
            SafeSharingFutureRuleId.noLiveV1SharingExpansion,
          ).status,
          SafeSharingFutureRuleStatus.fail,
        );
      },
    );

    test('canonical rules pass for gate copy', () {
      final result = SafeSharingFutureGate.build(_input());
      for (final rule in result.rules) {
        expect(
          rule.status,
          SafeSharingFutureRuleStatus.pass,
          reason: rule.id.name,
        );
      }
    });

    test('evaluateCopyPassesRules rejects raw private text leak copy', () {
      expect(
        SafeSharingFutureGate.evaluateCopyPassesRules(
          'We share raw text by default with your contacts.',
        ),
        isFalse,
      );
    });

    test('evaluateCopyPassesRules rejects archive content share copy', () {
      expect(
        SafeSharingFutureGate.evaluateCopyPassesRules(
          'Share your archive with friends automatically.',
        ),
        isFalse,
      );
    });

    test('report exposes canonical copy', () {
      final report = SafeSharingFutureGate.report(
        SafeSharingFutureGate.build(_input()),
      );
      expect(report.headline, SafeSharingFutureCopy.headline);
      expect(report.orderLine, SafeSharingFutureCopy.orderLine);
      expect(report.guardrail, SafeSharingFutureCopy.guardrail);
    });
  });

  group('SafeSharingFutureGate.composeInput', () {
    test('bridges launch checklist paid-intent beta complete', () {
      final input = SafeSharingFutureGate.composeInput(
        launchChecklist: const SingleLaunchChecklistInput(
          paidIntentBetaComplete: true,
        ),
      );
      expect(input.paidIntentBetaComplete, isTrue);
    });

    test('bridges paid-intent beta with first useful proof seen', () {
      final input = SafeSharingFutureGate.composeInput(
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
      expect(input.firstUsefulProofSeen, isTrue);
    });
  });

  group('SafeSharingFutureGate.fromRepoSignals', () {
    late String docsSource;
    late String gateCopySource;

    setUpAll(() {
      docsSource = File(_docsPath).readAsStringSync();
      gateCopySource = File(
        'lib/features/safe_sharing_future/safe_sharing_future_copy.dart',
      ).readAsStringSync();
    });

    test('detectDocListsRules matches docs', () {
      expect(SafeSharingFutureGate.detectDocListsRules(docsSource), isTrue);
    });

    test('detectGuardrailPresentInCopy matches gate copy', () {
      expect(
        SafeSharingFutureGate.detectGuardrailPresentInCopy(gateCopySource),
        isTrue,
      );
    });

    test('fromRepoSignals defaults to sharingFrozen', () {
      final result = SafeSharingFutureGate.build(
        SafeSharingFutureGate.fromRepoSignals(
          safeSharingFutureDocSource: docsSource,
          gateCopySource: gateCopySource,
        ),
      );
      expect(result.decision, SafeSharingFutureGateDecision.sharingFrozen);
      expect(
        _prereq(result, SafeSharingFuturePrereqId.firstUsefulProofSeen).status,
        SafeSharingFuturePrereqStatus.pending,
      );
    });
  });

  group('protected regression', () {
    test('docs describe future growth sharing scope', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('safe sharing'));
      expect(doc, contains('never share raw private text by default'));
      expect(doc, contains('explicit user share'));
      expect(doc, contains('product insight'));
      expect(doc, contains('not archive content'));
      expect(doc, contains('first five minutes'));
      expect(doc, contains('first useful proof'));
      expect(doc, contains('no new live v1 sharing'));
    });

    test('guardrail forbids raw text leak and early sharing', () {
      final guardrail = SafeSharingFutureCopy.guardrail.toLowerCase();
      expect(guardrail, contains('future growth sharing'));
      expect(guardrail, contains('never share raw private text by default'));
      expect(guardrail, contains('explicit user share or export'));
      expect(guardrail, contains('product insight'));
      expect(guardrail, contains('not archive content'));
      expect(guardrail, contains('first five minutes'));
      expect(guardrail, contains('first useful proof'));
      expect(guardrail, contains('no new live v1 sharing'));
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final copy in SafeSharingFutureCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });

    test('module does not import live sharing UI or paywall', () {
      for (final path in [
        'lib/features/safe_sharing_future/safe_sharing_future_gate.dart',
        'lib/features/safe_sharing_future/safe_sharing_future_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
        expect(source.contains('safe_sharing_model'), isFalse);
        expect(source.contains('archive_discovery_share'), isFalse);
      }
    });

    test('advice guard registers safe sharing future copy', () {
      final guardSource = File(
        'lib/features/archive_proof/proof_surface_advice_guard.dart',
      ).readAsStringSync();
      expect(
        guardSource,
        contains('SafeSharingFutureCopy.allVisibleStrings()'),
      );
    });
  });
}
