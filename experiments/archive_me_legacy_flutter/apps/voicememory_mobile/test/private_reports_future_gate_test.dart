import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/first_proof_success_beta/first_proof_success_beta_guard.dart';
import 'package:voicememory_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'package:voicememory_mobile/features/private_reports_future/private_reports_future_copy.dart';
import 'package:voicememory_mobile/features/private_reports_future/private_reports_future_gate.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';

const _docsPath = 'docs/PRIVATE_REPORTS_FUTURE.md';

PrivateReportsFutureGateInput _input({
  bool? firstProofSeen,
  bool? longerProofTrailConverts,
}) => PrivateReportsFutureGateInput(
  firstProofSeen: firstProofSeen,
  longerProofTrailConverts: longerProofTrailConverts,
);

PrivateReportsFutureRule _rule(
  PrivateReportsFutureGateResult result,
  PrivateReportsFutureRuleId id,
) => result.rules.firstWhere((rule) => rule.id == id);

void main() {
  group('PrivateReportsFutureGate.build', () {
    test('gate tracks seven canonical rules in order', () {
      final result = PrivateReportsFutureGate.build(_input());
      expect(result.rules.length, PrivateReportsFutureGate.ruleCount);
      expect(result.ruleOrder, PrivateReportsFutureGate.canonicalRuleOrder);
      expect(
        result.rules.map((rule) => rule.id).toList(),
        PrivateReportsFutureGate.canonicalRuleOrder,
      );
    });

    test('default input -> laterUpgradeOnly with launch headline blocked', () {
      final result = PrivateReportsFutureGate.build(_input());
      expect(
        result.decision,
        PrivateReportsFutureGateDecision.laterUpgradeOnly,
      );
      expect(result.launchHeadlineBlocked, isTrue);
      expect(result.primaryProPromiseBlocked, isTrue);
      expect(result.rulesPass, isTrue);
    });

    test('first proof without trail conversion -> laterUpgradeOnly', () {
      final result = PrivateReportsFutureGate.build(
        _input(firstProofSeen: true, longerProofTrailConverts: false),
      );
      expect(
        result.decision,
        PrivateReportsFutureGateDecision.laterUpgradeOnly,
      );
    });

    test('first proof and trail conversion -> futureProAddOnAllowed', () {
      final result = PrivateReportsFutureGate.build(
        _input(firstProofSeen: true, longerProofTrailConverts: true),
      );
      expect(
        result.decision,
        PrivateReportsFutureGateDecision.futureProAddOnAllowed,
      );
      expect(result.launchHeadlineBlocked, isTrue);
      expect(result.primaryProPromiseBlocked, isTrue);
    });

    test('trail conversion without first proof fails add-on rule', () {
      final result = PrivateReportsFutureGate.build(
        _input(firstProofSeen: false, longerProofTrailConverts: true),
      );
      expect(
        _rule(
          result,
          PrivateReportsFutureRuleId.futureProAddOnAfterTrailConverts,
        ).status,
        PrivateReportsFutureRuleStatus.fail,
      );
      expect(
        result.decision,
        PrivateReportsFutureGateDecision.laterUpgradeOnly,
      );
    });

    test('canonical rules pass for gate copy', () {
      final result = PrivateReportsFutureGate.build(_input());
      for (final rule in result.rules) {
        expect(
          rule.status,
          PrivateReportsFutureRuleStatus.pass,
          reason: rule.id.name,
        );
      }
    });

    test('evaluateCopyPassesRules rejects therapist-ready claims', () {
      expect(
        PrivateReportsFutureGate.evaluateCopyPassesRules(
          'Share with your therapist automatically.',
        ),
        isFalse,
      );
    });

    test('evaluateCopyPassesRules rejects report-primary Pro copy', () {
      expect(
        PrivateReportsFutureGate.evaluateCopyPassesRules(
          'Unlock reports with Pro.',
        ),
        isFalse,
      );
    });

    test('report exposes canonical copy', () {
      final report = PrivateReportsFutureGate.report(
        PrivateReportsFutureGate.build(_input()),
      );
      expect(report.headline, PrivateReportsFutureCopy.headline);
      expect(report.positioning, PrivateReportsFutureCopy.positioning);
      expect(report.guardrail, PrivateReportsFutureCopy.guardrail);
    });
  });

  group('PrivateReportsFutureGate.composeInput', () {
    test('bridges proofWorking and proofStrongEnoughForPro', () {
      final strongProof = FirstProofSuccessBetaGuard.build(
        FirstProofSuccessBetaInput(
          usableMomentCount: 3,
          hasSafeAnchor: true,
          hasMatchQuality: true,
          proofShown: true,
          proofAccepted: true,
          userUnderstoodWhy: true,
          proPromiseSeen: true,
          proofThresholdStillThree: true,
          betaReadinessStillGuardsThree: true,
          proofConfidence: ProofConfidenceLevel.strong,
        ),
      );
      final input = PrivateReportsFutureGate.composeInput(
        firstProofSuccessBeta: strongProof,
      );
      final result = PrivateReportsFutureGate.build(input);
      expect(input.firstProofSeen, isTrue);
      expect(input.longerProofTrailConverts, isTrue);
      expect(
        result.decision,
        PrivateReportsFutureGateDecision.futureProAddOnAllowed,
      );
    });

    test('bridges paid-intent promising as trail conversion', () {
      final input = PrivateReportsFutureGate.composeInput(
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
      expect(input.firstProofSeen, isTrue);
      expect(input.longerProofTrailConverts, isTrue);
    });
  });

  group('PrivateReportsFutureGate.fromRepoSignals', () {
    late String docsSource;
    late String gateCopySource;

    setUpAll(() {
      docsSource = File(_docsPath).readAsStringSync();
      gateCopySource = File(
        'lib/features/private_reports_future/private_reports_future_copy.dart',
      ).readAsStringSync();
    });

    test('detectDocListsRules matches docs', () {
      expect(PrivateReportsFutureGate.detectDocListsRules(docsSource), isTrue);
    });

    test('detectGuardrailPresentInCopy matches gate copy', () {
      expect(
        PrivateReportsFutureGate.detectGuardrailPresentInCopy(gateCopySource),
        isTrue,
      );
    });

    test('fromRepoSignals defaults to laterUpgradeOnly', () {
      final result = PrivateReportsFutureGate.build(
        PrivateReportsFutureGate.fromRepoSignals(
          privateReportsFutureDocSource: docsSource,
          gateCopySource: gateCopySource,
        ),
      );
      expect(
        result.decision,
        PrivateReportsFutureGateDecision.laterUpgradeOnly,
      );
    });
  });

  group('protected regression', () {
    test('docs describe later-upgrade scope', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('private reports'));
      expect(doc, contains('later upgrade'));
      expect(doc, contains('not primary pro promise'));
      expect(doc, contains('only after first proof'));
    });

    test('guardrail blocks launch headline and primary pro promise', () {
      final guardrail = PrivateReportsFutureCopy.guardrail.toLowerCase();
      expect(guardrail, contains('launch headline'));
      expect(guardrail, contains('not the primary pro promise'));
      expect(guardrail, contains('only after first proof'));
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final copy in PrivateReportsFutureCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });

    test('module does not import paywall or live report UI', () {
      for (final path in [
        'lib/features/private_reports_future/private_reports_future_gate.dart',
        'lib/features/private_reports_future/private_reports_future_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
        expect(source.contains('private_report_sheet'), isFalse);
      }
    });

    test('advice guard registers private reports future copy', () {
      final guardSource = File(
        'lib/features/archive_proof/proof_surface_advice_guard.dart',
      ).readAsStringSync();
      expect(
        guardSource,
        contains('PrivateReportsFutureCopy.allVisibleStrings()'),
      );
    });
  });
}
