import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'package:voicememory_mobile/features/safe_exports_future/safe_exports_future_copy.dart';
import 'package:voicememory_mobile/features/safe_exports_future/safe_exports_future_gate.dart';
import 'package:voicememory_mobile/features/single_launch_checklist/single_launch_checklist.dart';

const _docsPath = 'docs/SAFE_EXPORTS_FUTURE.md';

SafeExportsFutureGateInput _input({
  bool? exportTestsPass = true,
  bool? paidIntentBetaComplete = true,
}) =>
    SafeExportsFutureGateInput(
      exportTestsPass: exportTestsPass,
      paidIntentBetaComplete: paidIntentBetaComplete,
    );

SafeExportFuturePrereq _prereq(
  SafeExportsFutureGateResult result,
  SafeExportFuturePrereqId id,
) =>
    result.prereqs.firstWhere((prereq) => prereq.id == id);

SafeExportFuture _export(
  SafeExportsFutureGateResult result,
  SafeExportFutureId id,
) =>
    result.exports.firstWhere((export) => export.id == id);

SafeExportsFutureRule _rule(
  SafeExportsFutureGateResult result,
  SafeExportsFutureRuleId id,
) =>
    result.rules.firstWhere((rule) => rule.id == id);

void main() {
  group('SafeExportsFutureGate.build', () {
    test('gate tracks five exports, two prerequisites, and four rules', () {
      final result = SafeExportsFutureGate.build(_input());
      expect(result.exports.length, SafeExportsFutureGate.exportCount);
      expect(result.prereqs.length, SafeExportsFutureGate.prereqCount);
      expect(result.rules.length, SafeExportsFutureGate.ruleCount);
      expect(result.exportOrder, SafeExportsFutureGate.canonicalExportOrder);
      expect(result.prereqOrder, SafeExportsFutureGate.canonicalPrereqOrder);
      expect(result.ruleOrder, SafeExportsFutureGate.canonicalRuleOrder);
    });

    test('export proof complete -> futurePaidExpansionDocumented', () {
      final result = SafeExportsFutureGate.build(_input());
      expect(
        result.decision,
        SafeExportsFutureGateDecision.futurePaidExpansionDocumented,
      );
      expect(result.exportProofComplete, isTrue);
      expect(result.launchPromiseBlocked, isTrue);
      expect(result.primaryProPromiseBlocked, isTrue);
      expect(result.v1ExportUiBlocked, isTrue);
      expect(result.blockedExportCount, 0);
      expect(
        result.documentedExportCount,
        SafeExportsFutureGate.exportCount,
      );
      expect(result.earliestPrereqGap, isNull);
      expect(result.earliestRuleFailure, isNull);
    });

    test('pending export tests -> exportsFrozen and exports blocked', () {
      final result = SafeExportsFutureGate.build(
        _input(exportTestsPass: null),
      );
      expect(result.decision, SafeExportsFutureGateDecision.exportsFrozen);
      expect(result.exportProofComplete, isFalse);
      expect(
        result.earliestPrereqGap,
        SafeExportFuturePrereqId.exportTestsPass,
      );
      expect(
        _export(result, SafeExportFutureId.proofTrailPdf).status,
        SafeExportFutureStatus.blockedBeforeExportProof,
      );
    });

    test('paid-intent beta incomplete -> exportsFrozen', () {
      final result = SafeExportsFutureGate.build(
        _input(paidIntentBetaComplete: false),
      );
      expect(result.decision, SafeExportsFutureGateDecision.exportsFrozen);
      expect(
        result.earliestPrereqGap,
        SafeExportFuturePrereqId.paidIntentBetaComplete,
      );
      expect(
        _prereq(result, SafeExportFuturePrereqId.paidIntentBetaComplete).status,
        SafeExportFuturePrereqStatus.fail,
      );
    });

    test('marketing exports planned without tests fails testedBeforeMarketing', () {
      final result = SafeExportsFutureGate.build(
        SafeExportsFutureGateInput(
          exportTestsPass: false,
          paidIntentBetaComplete: true,
          marketingExportsPlanned: true,
        ),
      );
      expect(
        _rule(result, SafeExportsFutureRuleId.testedBeforeMarketing).status,
        SafeExportsFutureRuleStatus.fail,
      );
      expect(result.decision, SafeExportsFutureGateDecision.exportsFrozen);
    });

    test('canonical rules pass for gate copy', () {
      final result = SafeExportsFutureGate.build(_input());
      for (final rule in result.rules) {
        expect(rule.status, SafeExportsFutureRuleStatus.pass, reason: rule.id.name);
      }
    });

    test('evaluateCopyPassesRules rejects export-primary Pro copy', () {
      expect(
        SafeExportsFutureGate.evaluateCopyPassesRules(
          'Unlock exports with Pro.',
        ),
        isFalse,
      );
    });

    test('evaluateCopyPassesRules rejects private raw text leak copy', () {
      expect(
        SafeExportsFutureGate.evaluateCopyPassesRules(
          'Background export sends your raw text automatically.',
        ),
        isFalse,
      );
    });

    test('report exposes canonical copy', () {
      final report = SafeExportsFutureGate.report(
        SafeExportsFutureGate.build(_input()),
      );
      expect(report.headline, SafeExportsFutureCopy.headline);
      expect(report.positioning, SafeExportsFutureCopy.positioning);
      expect(report.guardrail, SafeExportsFutureCopy.guardrail);
    });
  });

  group('SafeExportsFutureGate.composeInput', () {
    test('bridges launch checklist paid-intent beta complete', () {
      final input = SafeExportsFutureGate.composeInput(
        exportTestsPass: true,
        launchChecklist: const SingleLaunchChecklistInput(
          testFlightUploaded: true,
          paidIntentBetaComplete: true,
        ),
      );
      expect(input.exportTestsPass, isTrue);
      expect(input.paidIntentBetaComplete, isTrue);
    });

    test('bridges paid-intent promising as beta complete', () {
      final input = SafeExportsFutureGate.composeInput(
        exportTestsPass: true,
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

  group('SafeExportsFutureGate.fromRepoSignals', () {
    late String docsSource;
    late String gateCopySource;

    setUpAll(() {
      docsSource = File(_docsPath).readAsStringSync();
      gateCopySource = File(
        'lib/features/safe_exports_future/safe_exports_future_copy.dart',
      ).readAsStringSync();
    });

    test('detectDocListsRules matches docs', () {
      expect(
        SafeExportsFutureGate.detectDocListsRules(docsSource),
        isTrue,
      );
    });

    test('detectGuardrailPresentInCopy matches gate copy', () {
      expect(
        SafeExportsFutureGate.detectGuardrailPresentInCopy(gateCopySource),
        isTrue,
      );
    });

    test('fromRepoSignals defaults to exportsFrozen', () {
      final result = SafeExportsFutureGate.build(
        SafeExportsFutureGate.fromRepoSignals(
          safeExportsFutureDocSource: docsSource,
          gateCopySource: gateCopySource,
        ),
      );
      expect(result.decision, SafeExportsFutureGateDecision.exportsFrozen);
    });
  });

  group('protected regression', () {
    test('docs describe future paid expansion scope', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('safe exports'));
      expect(doc, contains('future paid expansion'));
      expect(doc, contains('not primary pro promise'));
      expect(doc, contains('explicit user export action'));
      expect(doc, contains('no new export ui'));
    });

    test('guardrail blocks launch promise and primary pro promise', () {
      final guardrail = SafeExportsFutureCopy.guardrail.toLowerCase();
      expect(guardrail, contains('not the primary pro promise'));
      expect(guardrail, contains('explicit user export action'));
      expect(guardrail, contains('no new export ui'));
      expect(guardrail, contains('tested before marketing'));
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final copy in SafeExportsFutureCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });

    test('module does not import paywall or live export UI', () {
      for (final path in [
        'lib/features/safe_exports_future/safe_exports_future_gate.dart',
        'lib/features/safe_exports_future/safe_exports_future_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
        expect(source.contains('export_page'), isFalse);
        expect(source.contains('private_recap_service'), isFalse);
      }
    });

    test('advice guard registers safe exports future copy', () {
      final guardSource = File(
        'lib/features/archive_proof/proof_surface_advice_guard.dart',
      ).readAsStringSync();
      expect(
        guardSource,
        contains('SafeExportsFutureCopy.allVisibleStrings()'),
      );
    });

    test('docs list all five future export types', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('proof trail pdf'));
      expect(doc, contains('markdown archive'));
      expect(doc, contains('local backup'));
      expect(doc, contains('what changed monthly report'));
      expect(doc, contains('evidence trail export'));
    });
  });
}
