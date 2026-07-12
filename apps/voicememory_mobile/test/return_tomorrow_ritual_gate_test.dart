import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'package:voicememory_mobile/features/return_tomorrow_ritual/return_tomorrow_ritual_copy.dart';
import 'package:voicememory_mobile/features/return_tomorrow_ritual/return_tomorrow_ritual_gate.dart';
import 'package:voicememory_mobile/features/single_launch_checklist/single_launch_checklist.dart';

const _docsPath = 'docs/RETURN_TOMORROW_RITUAL.md';

ReturnTomorrowRitualGateInput _input({
  bool? paidIntentBetaComplete,
  bool? v1RitualUiRequested,
}) =>
    ReturnTomorrowRitualGateInput(
      paidIntentBetaComplete: paidIntentBetaComplete,
      v1RitualUiRequested: v1RitualUiRequested,
    );

ReturnTomorrowRitualRule _rule(
  ReturnTomorrowRitualGateResult result,
  ReturnTomorrowRitualRuleId id,
) =>
    result.rules.firstWhere((rule) => rule.id == id);

void main() {
  group('ReturnTomorrowRitualGate.build', () {
    test('gate tracks four canonical rules in order', () {
      final result = ReturnTomorrowRitualGate.build(_input());
      expect(result.rules.length, ReturnTomorrowRitualGate.ruleCount);
      expect(result.ruleOrder, ReturnTomorrowRitualGate.canonicalRuleOrder);
      expect(
        result.rules.map((rule) => rule.id).toList(),
        ReturnTomorrowRitualGate.canonicalRuleOrder,
      );
    });

    test('default input -> ritualFrozen with pressure blocked', () {
      final result = ReturnTomorrowRitualGate.build(_input());
      expect(result.decision, ReturnTomorrowRitualGateDecision.ritualFrozen);
      expect(result.v1LiveUiBlocked, isTrue);
      expect(result.dailyHomeworkBlocked, isTrue);
      expect(result.retentionPressureBlocked, isTrue);
      expect(result.rulesPass, isTrue);
      expect(
        result.allowedLanguage,
        ReturnTomorrowRitualGate.canonicalAllowedLanguage,
      );
    });

    test('paid-intent beta complete -> futureRetentionDocumented', () {
      final result = ReturnTomorrowRitualGate.build(
        _input(paidIntentBetaComplete: true),
      );
      expect(
        result.decision,
        ReturnTomorrowRitualGateDecision.futureRetentionDocumented,
      );
      expect(result.betaProofComplete, isTrue);
      expect(result.v1LiveUiBlocked, isTrue);
    });

    test('v1 ritual UI requested without beta proof fails noNewLiveV1Ui', () {
      final result = ReturnTomorrowRitualGate.build(
        _input(
          paidIntentBetaComplete: false,
          v1RitualUiRequested: true,
        ),
      );
      expect(
        _rule(result, ReturnTomorrowRitualRuleId.noNewLiveV1Ui).status,
        ReturnTomorrowRitualRuleStatus.fail,
      );
    });

    test('canonical rules pass for gate copy', () {
      final result = ReturnTomorrowRitualGate.build(_input());
      for (final rule in result.rules) {
        expect(rule.status, ReturnTomorrowRitualRuleStatus.pass, reason: rule.id.name);
      }
    });

    test('evaluateCopyPassesRules rejects streak pressure copy', () {
      expect(
        ReturnTomorrowRitualGate.evaluateCopyPassesRules(
          'Keep your streak alive tomorrow.',
        ),
        isFalse,
      );
    });

    test('evaluateCopyPassesRules rejects daily homework copy', () {
      expect(
        ReturnTomorrowRitualGate.evaluateCopyPassesRules(
          'Complete your homework every day.',
        ),
        isFalse,
      );
    });

    test('evaluateCopyPassesRules rejects habit tracker copy', () {
      expect(
        ReturnTomorrowRitualGate.evaluateCopyPassesRules(
          'Use our habit tracker to build your streak habit.',
        ),
        isFalse,
      );
    });

    test('report exposes canonical copy', () {
      final report = ReturnTomorrowRitualGate.report(
        ReturnTomorrowRitualGate.build(_input()),
      );
      expect(report.headline, ReturnTomorrowRitualCopy.headline);
      expect(report.allowedLanguageLine, ReturnTomorrowRitualCopy.allowedLanguageLine);
      expect(report.guardrail, ReturnTomorrowRitualCopy.guardrail);
    });
  });

  group('ReturnTomorrowRitualGate.composeInput', () {
    test('bridges launch checklist paid-intent beta complete', () {
      final input = ReturnTomorrowRitualGate.composeInput(
        launchChecklist: const SingleLaunchChecklistInput(
          paidIntentBetaComplete: true,
        ),
      );
      expect(input.paidIntentBetaComplete, isTrue);
    });

    test('bridges paid-intent promising as beta complete', () {
      final input = ReturnTomorrowRitualGate.composeInput(
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
    });
  });

  group('ReturnTomorrowRitualGate.fromRepoSignals', () {
    late String docsSource;
    late String gateCopySource;

    setUpAll(() {
      docsSource = File(_docsPath).readAsStringSync();
      gateCopySource = File(
        'lib/features/return_tomorrow_ritual/return_tomorrow_ritual_copy.dart',
      ).readAsStringSync();
    });

    test('detectDocListsRules matches docs', () {
      expect(
        ReturnTomorrowRitualGate.detectDocListsRules(docsSource),
        isTrue,
      );
    });

    test('detectGuardrailPresentInCopy matches gate copy', () {
      expect(
        ReturnTomorrowRitualGate.detectGuardrailPresentInCopy(gateCopySource),
        isTrue,
      );
    });

    test('detectAllowedLanguagePresentInCopy matches gate copy', () {
      expect(
        ReturnTomorrowRitualGate.detectAllowedLanguagePresentInCopy(
          gateCopySource,
        ),
        isTrue,
      );
    });

    test('fromRepoSignals defaults to ritualFrozen', () {
      final result = ReturnTomorrowRitualGate.build(
        ReturnTomorrowRitualGate.fromRepoSignals(
          returnTomorrowRitualDocSource: docsSource,
          gateCopySource: gateCopySource,
        ),
      );
      expect(result.decision, ReturnTomorrowRitualGateDecision.ritualFrozen);
    });
  });

  group('protected regression', () {
    test('docs describe future retention ritual scope', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('return tomorrow ritual'));
      expect(doc, contains('watch this tomorrow'));
      expect(doc, contains('did this come back?'));
      expect(doc, contains('future retention only'));
      expect(doc, contains('no new live v1 ui'));
      expect(doc, contains('daily homework'));
      expect(doc, contains('streaks'));
    });

    test('guardrail forbids homework and pressure language', () {
      final guardrail = ReturnTomorrowRitualCopy.guardrail.toLowerCase();
      expect(guardrail, contains('future retention only'));
      expect(guardrail, contains('do not add streaks'));
      expect(guardrail, contains('daily homework'));
      expect(guardrail, contains('no new live v1 ui'));
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final copy in ReturnTomorrowRitualCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });

    test('module does not import paywall or live ritual UI', () {
      for (final path in [
        'lib/features/return_tomorrow_ritual/return_tomorrow_ritual_gate.dart',
        'lib/features/return_tomorrow_ritual/return_tomorrow_ritual_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
        expect(source.contains('return_tomorrow_cue_card'), isFalse);
      }
    });

    test('advice guard registers return tomorrow ritual copy', () {
      final guardSource = File(
        'lib/features/archive_proof/proof_surface_advice_guard.dart',
      ).readAsStringSync();
      expect(
        guardSource,
        contains('ReturnTomorrowRitualCopy.allVisibleStrings()'),
      );
    });
  });
}
