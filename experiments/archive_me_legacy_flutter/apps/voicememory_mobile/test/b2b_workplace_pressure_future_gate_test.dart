import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/b2b_workplace_pressure_future/b2b_workplace_pressure_future_copy.dart';
import 'package:voicememory_mobile/features/b2b_workplace_pressure_future/b2b_workplace_pressure_future_gate.dart';
import 'package:voicememory_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'package:voicememory_mobile/features/single_launch_checklist/single_launch_checklist.dart';

const _docsPath = 'docs/B2B_WORKPLACE_PRESSURE_FUTURE.md';

B2bWorkplacePressureFutureGateInput _input({
  bool? testFlightUploaded = true,
  bool? paidIntentBetaComplete = true,
  bool? v1B2bUiRequested,
}) => B2bWorkplacePressureFutureGateInput(
  testFlightUploaded: testFlightUploaded,
  paidIntentBetaComplete: paidIntentBetaComplete,
  v1B2bUiRequested: v1B2bUiRequested,
);

B2bWorkplacePressureFuturePrereq _prereq(
  B2bWorkplacePressureFutureGateResult result,
  B2bWorkplacePressureFuturePrereqId id,
) => result.prereqs.firstWhere((prereq) => prereq.id == id);

B2bWorkplacePressureAudience _audience(
  B2bWorkplacePressureFutureGateResult result,
  B2bWorkplacePressureAudienceId id,
) => result.audiences.firstWhere((audience) => audience.id == id);

B2bWorkplacePressureFutureRule _rule(
  B2bWorkplacePressureFutureGateResult result,
  B2bWorkplacePressureFutureRuleId id,
) => result.rules.firstWhere((rule) => rule.id == id);

void main() {
  group('B2bWorkplacePressureFutureGate.build', () {
    test('gate tracks six audiences, two prerequisites, and five rules', () {
      final result = B2bWorkplacePressureFutureGate.build(_input());
      expect(
        result.audiences.length,
        B2bWorkplacePressureFutureGate.audienceCount,
      );
      expect(result.prereqs.length, B2bWorkplacePressureFutureGate.prereqCount);
      expect(result.rules.length, B2bWorkplacePressureFutureGate.ruleCount);
      expect(
        result.audienceOrder,
        B2bWorkplacePressureFutureGate.canonicalAudienceOrder,
      );
      expect(
        result.prereqOrder,
        B2bWorkplacePressureFutureGate.canonicalPrereqOrder,
      );
      expect(
        result.ruleOrder,
        B2bWorkplacePressureFutureGate.canonicalRuleOrder,
      );
    });

    test('beta proof complete -> futureLandingPositioningDocumented', () {
      final result = B2bWorkplacePressureFutureGate.build(_input());
      expect(
        result.decision,
        B2bWorkplacePressureFutureGateDecision
            .futureLandingPositioningDocumented,
      );
      expect(result.betaProofComplete, isTrue);
      expect(result.v1LiveB2bUiBlocked, isTrue);
      expect(result.employerDashboardBlocked, isTrue);
      expect(result.employeeSurveillanceBlocked, isTrue);
      expect(result.medicalTherapyClaimsBlocked, isTrue);
      expect(result.blockedAudienceCount, 0);
      expect(
        result.documentedAudienceCount,
        B2bWorkplacePressureFutureGate.audienceCount,
      );
      expect(result.earliestPrereqGap, isNull);
    });

    test('pending TestFlight -> b2bFrozen and audiences blocked', () {
      final result = B2bWorkplacePressureFutureGate.build(
        _input(testFlightUploaded: null),
      );
      expect(result.decision, B2bWorkplacePressureFutureGateDecision.b2bFrozen);
      expect(
        result.earliestPrereqGap,
        B2bWorkplacePressureFuturePrereqId.testFlightUploaded,
      );
      expect(
        _audience(result, B2bWorkplacePressureAudienceId.founders).status,
        B2bWorkplacePressureAudienceStatus.blockedBeforeBetaProof,
      );
    });

    test('paid-intent beta incomplete -> b2bFrozen', () {
      final result = B2bWorkplacePressureFutureGate.build(
        _input(paidIntentBetaComplete: false),
      );
      expect(result.decision, B2bWorkplacePressureFutureGateDecision.b2bFrozen);
      expect(
        _prereq(
          result,
          B2bWorkplacePressureFuturePrereqId.paidIntentBetaComplete,
        ).status,
        B2bWorkplacePressureFuturePrereqStatus.fail,
      );
    });

    test('v1 B2B UI requested without beta proof fails noLiveB2bUi', () {
      final result = B2bWorkplacePressureFutureGate.build(
        _input(testFlightUploaded: false, v1B2bUiRequested: true),
      );
      expect(
        _rule(result, B2bWorkplacePressureFutureRuleId.noLiveB2bUi).status,
        B2bWorkplacePressureFutureRuleStatus.fail,
      );
    });

    test('audiences map to audience wedge ids', () {
      final result = B2bWorkplacePressureFutureGate.build(_input());
      expect(
        _audience(
          result,
          B2bWorkplacePressureAudienceId.founders,
        ).audienceWedgeId,
        'founders',
      );
      expect(
        _audience(
          result,
          B2bWorkplacePressureAudienceId.peopleWhoSayYesWithNoCapacity,
        ).audienceWedgeId,
        'peopleWhoSayYesWithNoCapacity',
      );
    });

    test('canonical rules pass for gate copy', () {
      final result = B2bWorkplacePressureFutureGate.build(_input());
      for (final rule in result.rules) {
        expect(
          rule.status,
          B2bWorkplacePressureFutureRuleStatus.pass,
          reason: rule.id.name,
        );
      }
    });

    test('evaluateCopyPassesRules rejects employer dashboard copy', () {
      expect(
        B2bWorkplacePressureFutureGate.evaluateCopyPassesRules(
          'Your employer dashboard for team wellbeing.',
        ),
        isFalse,
      );
    });

    test('evaluateCopyPassesRules rejects employee surveillance copy', () {
      expect(
        B2bWorkplacePressureFutureGate.evaluateCopyPassesRules(
          'Monitor your employees with our dashboard.',
        ),
        isFalse,
      );
    });

    test('evaluateCopyPassesRules rejects medical therapy claim copy', () {
      expect(
        B2bWorkplacePressureFutureGate.evaluateCopyPassesRules(
          'Therapy tool for workplace stress.',
        ),
        isFalse,
      );
    });

    test('report exposes canonical copy', () {
      final report = B2bWorkplacePressureFutureGate.report(
        B2bWorkplacePressureFutureGate.build(_input()),
      );
      expect(report.headline, B2bWorkplacePressureFutureCopy.headline);
      expect(report.positioning, B2bWorkplacePressureFutureCopy.positioning);
      expect(report.guardrail, B2bWorkplacePressureFutureCopy.guardrail);
    });
  });

  group('B2bWorkplacePressureFutureGate.composeInput', () {
    test('bridges launch checklist prereqs', () {
      final input = B2bWorkplacePressureFutureGate.composeInput(
        launchChecklist: const SingleLaunchChecklistInput(
          testFlightUploaded: true,
          paidIntentBetaComplete: true,
        ),
      );
      expect(input.testFlightUploaded, isTrue);
      expect(input.paidIntentBetaComplete, isTrue);
    });

    test('bridges paid-intent promising as beta complete', () {
      final input = B2bWorkplacePressureFutureGate.composeInput(
        testFlightUploaded: true,
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

  group('B2bWorkplacePressureFutureGate.fromRepoSignals', () {
    late String docsSource;
    late String gateCopySource;
    late String audienceWedgeModelSource;

    setUpAll(() {
      docsSource = File(_docsPath).readAsStringSync();
      gateCopySource = File(
        'lib/features/b2b_workplace_pressure_future/b2b_workplace_pressure_future_copy.dart',
      ).readAsStringSync();
      audienceWedgeModelSource = File(
        'lib/features/b2b_workplace_pressure_future/b2b_workplace_pressure_future_gate.dart',
      ).readAsStringSync();
    });

    test('detectDocListsRules matches docs', () {
      expect(
        B2bWorkplacePressureFutureGate.detectDocListsRules(docsSource),
        isTrue,
      );
    });

    test('detectGuardrailPresentInCopy matches gate copy', () {
      expect(
        B2bWorkplacePressureFutureGate.detectGuardrailPresentInCopy(
          gateCopySource,
        ),
        isTrue,
      );
    });

    test('detectAudienceWedgeIdsAligned matches gate model', () {
      expect(
        B2bWorkplacePressureFutureGate.detectAudienceWedgeIdsAligned(
          audienceWedgeModelSource,
        ),
        isTrue,
      );
    });

    test('fromRepoSignals defaults to b2bFrozen', () {
      final result = B2bWorkplacePressureFutureGate.build(
        B2bWorkplacePressureFutureGate.fromRepoSignals(
          b2bWorkplacePressureFutureDocSource: docsSource,
          gateCopySource: gateCopySource,
          audienceWedgeModelSource: audienceWedgeModelSource,
        ),
      );
      expect(result.decision, B2bWorkplacePressureFutureGateDecision.b2bFrozen);
    });
  });

  group('protected regression', () {
    test('docs describe B2B-lite future scope', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('b2b'));
      expect(doc, contains('workplace pressure'));
      expect(doc, contains('founders'));
      expect(doc, contains('no employer dashboard'));
      expect(doc, contains('no employee surveillance'));
      expect(doc, contains('no live b2b ui'));
      expect(doc, contains('future landing-page positioning'));
    });

    test('guardrail blocks employer dashboard and surveillance', () {
      final guardrail = B2bWorkplacePressureFutureCopy.guardrail.toLowerCase();
      expect(guardrail, contains('no employer dashboard'));
      expect(guardrail, contains('no employee surveillance'));
      expect(guardrail, contains('no live b2b ui'));
      expect(guardrail, contains('future landing-page positioning only'));
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final copy in B2bWorkplacePressureFutureCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });

    test('module does not import paywall or live B2B UI', () {
      for (final path in [
        'lib/features/b2b_workplace_pressure_future/b2b_workplace_pressure_future_gate.dart',
        'lib/features/b2b_workplace_pressure_future/b2b_workplace_pressure_future_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
        expect(source.contains('employer_dashboard'), isFalse);
      }
    });

    test('advice guard registers B2B workplace pressure future copy', () {
      final guardSource = File(
        'lib/features/archive_proof/proof_surface_advice_guard.dart',
      ).readAsStringSync();
      expect(
        guardSource,
        contains('B2bWorkplacePressureFutureCopy.allVisibleStrings()'),
      );
    });

    test('docs list all six audience segments', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('founders'));
      expect(doc, contains('managers'));
      expect(doc, contains('carers'));
      expect(doc, contains('high-responsibility workers'));
      expect(doc, contains('people who overcommit'));
      expect(doc, contains('people who say yes with no capacity'));
    });
  });
}
