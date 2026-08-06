import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_memory_after_v1/archive_memory_after_v1_copy.dart';
import 'package:voicememory_mobile/features/archive_memory_after_v1/archive_memory_after_v1_gate.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'package:voicememory_mobile/features/single_launch_checklist/single_launch_checklist.dart';

const _docsPath = 'docs/ARCHIVE_MEMORY_AFTER_V1.md';

ArchiveMemoryAfterV1GateInput _input({
  bool? paidIntentBetaComplete,
  bool? withinFirstFiveMinutes,
  bool? memorySurfacingRequested,
  bool? v1ArchiveMemoryUiRequested,
}) => ArchiveMemoryAfterV1GateInput(
  paidIntentBetaComplete: paidIntentBetaComplete,
  withinFirstFiveMinutes: withinFirstFiveMinutes,
  memorySurfacingRequested: memorySurfacingRequested,
  v1ArchiveMemoryUiRequested: v1ArchiveMemoryUiRequested,
);

ArchiveMemoryAfterV1Rule _rule(
  ArchiveMemoryAfterV1GateResult result,
  ArchiveMemoryAfterV1RuleId id,
) => result.rules.firstWhere((rule) => rule.id == id);

void main() {
  group('ArchiveMemoryAfterV1Gate.build', () {
    test('gate tracks five canonical rules in order', () {
      final result = ArchiveMemoryAfterV1Gate.build(_input());
      expect(result.rules.length, ArchiveMemoryAfterV1Gate.ruleCount);
      expect(result.ruleOrder, ArchiveMemoryAfterV1Gate.canonicalRuleOrder);
      expect(
        result.rules.map((rule) => rule.id).toList(),
        ArchiveMemoryAfterV1Gate.canonicalRuleOrder,
      );
    });

    test('default input -> archiveMemoryFrozen with promise blocked', () {
      final result = ArchiveMemoryAfterV1Gate.build(_input());
      expect(
        result.decision,
        ArchiveMemoryAfterV1GateDecision.archiveMemoryFrozen,
      );
      expect(result.v1LiveUiBlocked, isTrue);
      expect(result.primaryProPromiseBlocked, isTrue);
      expect(result.storageFramingBlocked, isTrue);
      expect(result.firstFiveMinutesSurfacingBlocked, isTrue);
      expect(result.rulesPass, isTrue);
    });

    test('paid-intent beta complete -> futureArchiveMemoryDocumented', () {
      final result = ArchiveMemoryAfterV1Gate.build(
        _input(paidIntentBetaComplete: true),
      );
      expect(
        result.decision,
        ArchiveMemoryAfterV1GateDecision.futureArchiveMemoryDocumented,
      );
      expect(result.betaProofComplete, isTrue);
      expect(result.v1LiveUiBlocked, isTrue);
    });

    test('memory surfacing in first five minutes fails timing rule', () {
      final result = ArchiveMemoryAfterV1Gate.build(
        _input(
          paidIntentBetaComplete: true,
          withinFirstFiveMinutes: true,
          memorySurfacingRequested: true,
        ),
      );
      expect(
        _rule(
          result,
          ArchiveMemoryAfterV1RuleId.notPartOfFirstFiveMinutes,
        ).status,
        ArchiveMemoryAfterV1RuleStatus.fail,
      );
      expect(
        result.decision,
        ArchiveMemoryAfterV1GateDecision.archiveMemoryFrozen,
      );
    });

    test('v1 archive memory UI without beta proof fails noNewLiveV1Ui', () {
      final result = ArchiveMemoryAfterV1Gate.build(
        _input(paidIntentBetaComplete: false, v1ArchiveMemoryUiRequested: true),
      );
      expect(
        _rule(result, ArchiveMemoryAfterV1RuleId.noNewLiveV1Ui).status,
        ArchiveMemoryAfterV1RuleStatus.fail,
      );
    });

    test('canonical rules pass for gate copy', () {
      final result = ArchiveMemoryAfterV1Gate.build(_input());
      for (final rule in result.rules) {
        expect(
          rule.status,
          ArchiveMemoryAfterV1RuleStatus.pass,
          reason: rule.id.name,
        );
      }
    });

    test('evaluateCopyPassesRules rejects primary pro promise copy', () {
      expect(
        ArchiveMemoryAfterV1Gate.evaluateCopyPassesRules(
          'Unlock archive memory — that is what Pro gives you.',
        ),
        isFalse,
      );
    });

    test('evaluateCopyPassesRules rejects storage framing copy', () {
      expect(
        ArchiveMemoryAfterV1Gate.evaluateCopyPassesRules(
          'Get unlimited storage for your archive memory.',
        ),
        isFalse,
      );
    });

    test('report exposes canonical copy', () {
      final report = ArchiveMemoryAfterV1Gate.report(
        ArchiveMemoryAfterV1Gate.build(_input()),
      );
      expect(report.headline, ArchiveMemoryAfterV1Copy.headline);
      expect(report.orderLine, ArchiveMemoryAfterV1Copy.orderLine);
      expect(report.guardrail, ArchiveMemoryAfterV1Copy.guardrail);
    });
  });

  group('ArchiveMemoryAfterV1Gate.composeInput', () {
    test('bridges launch checklist paid-intent beta complete', () {
      final input = ArchiveMemoryAfterV1Gate.composeInput(
        launchChecklist: const SingleLaunchChecklistInput(
          paidIntentBetaComplete: true,
        ),
      );
      expect(input.paidIntentBetaComplete, isTrue);
    });

    test('bridges paid-intent promising as beta complete', () {
      final input = ArchiveMemoryAfterV1Gate.composeInput(
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

  group('ArchiveMemoryAfterV1Gate.fromRepoSignals', () {
    late String docsSource;
    late String gateCopySource;

    setUpAll(() {
      docsSource = File(_docsPath).readAsStringSync();
      gateCopySource = File(
        'lib/features/archive_memory_after_v1/archive_memory_after_v1_copy.dart',
      ).readAsStringSync();
    });

    test('detectDocListsRules matches docs', () {
      expect(ArchiveMemoryAfterV1Gate.detectDocListsRules(docsSource), isTrue);
    });

    test('detectGuardrailPresentInCopy matches gate copy', () {
      expect(
        ArchiveMemoryAfterV1Gate.detectGuardrailPresentInCopy(gateCopySource),
        isTrue,
      );
    });

    test('fromRepoSignals defaults to archiveMemoryFrozen', () {
      final result = ArchiveMemoryAfterV1Gate.build(
        ArchiveMemoryAfterV1Gate.fromRepoSignals(
          archiveMemoryAfterV1DocSource: docsSource,
          gateCopySource: gateCopySource,
        ),
      );
      expect(
        result.decision,
        ArchiveMemoryAfterV1GateDecision.archiveMemoryFrozen,
      );
    });
  });

  group('protected regression', () {
    test('docs describe future archive memory scope', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('archive memory after v1'));
      expect(doc, contains('future enhancement'));
      expect(doc, contains('not part of first five minutes'));
      expect(doc, contains('not primary pro promise'));
      expect(doc, contains('proof trail'));
      expect(doc, contains('not storage'));
      expect(doc, contains('no new live v1 ui'));
    });

    test('guardrail forbids first-five-minute and storage framing', () {
      final guardrail = ArchiveMemoryAfterV1Copy.guardrail.toLowerCase();
      expect(guardrail, contains('archive memory after v1'));
      expect(guardrail, contains('future enhancement'));
      expect(guardrail, contains('not part of first five minutes'));
      expect(guardrail, contains('not the primary pro promise'));
      expect(guardrail, contains('proof trail'));
      expect(guardrail, contains('not storage'));
      expect(guardrail, contains('no new live v1 ui'));
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final copy in ArchiveMemoryAfterV1Copy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });

    test('module does not import live archive memory UI', () {
      for (final path in [
        'lib/features/archive_memory_after_v1/archive_memory_after_v1_gate.dart',
        'lib/features/archive_memory_after_v1/archive_memory_after_v1_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('daily_archive_memory_engine'), isFalse);
        expect(source.contains('pro_memory_upgrade_bridge'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
      }
    });

    test('advice guard registers archive memory after V1 copy', () {
      final guardSource = File(
        'lib/features/archive_proof/proof_surface_advice_guard.dart',
      ).readAsStringSync();
      expect(
        guardSource,
        contains('ArchiveMemoryAfterV1Copy.allVisibleStrings()'),
      );
    });
  });
}
