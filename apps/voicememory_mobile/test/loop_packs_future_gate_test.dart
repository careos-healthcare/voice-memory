import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/loop_packs_future/loop_packs_future_copy.dart';
import 'package:voicememory_mobile/features/loop_packs_future/loop_packs_future_gate.dart';
import 'package:voicememory_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'package:voicememory_mobile/features/single_launch_checklist/single_launch_checklist.dart';

const _docsPath = 'docs/LOOP_PACKS_FUTURE.md';

LoopPacksFutureGateInput _input({
  bool? testFlightUploaded = true,
  bool? paidIntentBetaComplete = true,
}) =>
    LoopPacksFutureGateInput(
      testFlightUploaded: testFlightUploaded,
      paidIntentBetaComplete: paidIntentBetaComplete,
    );

LoopPackFuturePrereq _prereq(
  LoopPacksFutureGateResult result,
  LoopPackFuturePrereqId id,
) =>
    result.prereqs.firstWhere((prereq) => prereq.id == id);

LoopPackFuture _pack(
  LoopPacksFutureGateResult result,
  LoopPackFutureId id,
) =>
    result.packs.firstWhere((pack) => pack.id == id);

void main() {
  group('LoopPacksFutureGate.build', () {
    test('gate tracks six packs and two prerequisites in order', () {
      final result = LoopPacksFutureGate.build(_input());
      expect(result.packs.length, LoopPacksFutureGate.packCount);
      expect(result.prereqs.length, LoopPacksFutureGate.prereqCount);
      expect(result.packOrder, LoopPacksFutureGate.canonicalPackOrder);
      expect(result.prereqOrder, LoopPacksFutureGate.canonicalPrereqOrder);
      expect(
        result.packs.map((pack) => pack.id).toList(),
        LoopPacksFutureGate.canonicalPackOrder,
      );
    });

    test('beta proof complete -> packsDocumentedOnly', () {
      final result = LoopPacksFutureGate.build(_input());
      expect(result.decision, LoopPacksFutureGateDecision.packsDocumentedOnly);
      expect(result.betaProofComplete, isTrue);
      expect(result.v1SurfacingBlocked, isTrue);
      expect(result.onboardingUiBlocked, isTrue);
      expect(result.paywallBenefitsBlocked, isTrue);
      expect(result.blockedPackCount, 0);
      expect(result.documentedPackCount, LoopPacksFutureGate.packCount);
      expect(result.earliestPrereqGap, isNull);
    });

    test('pending TestFlight -> packsFrozen and packs blocked', () {
      final result = LoopPacksFutureGate.build(
        _input(testFlightUploaded: null),
      );
      expect(result.decision, LoopPacksFutureGateDecision.packsFrozen);
      expect(result.betaProofComplete, isFalse);
      expect(
        result.earliestPrereqGap,
        LoopPackFuturePrereqId.testFlightUploaded,
      );
      expect(
        _pack(result, LoopPackFutureId.sayingYesNoCapacity).status,
        LoopPackFutureStatus.blockedBeforeBetaProof,
      );
    });

    test('paid-intent beta incomplete -> packsFrozen', () {
      final result = LoopPacksFutureGate.build(
        _input(paidIntentBetaComplete: false),
      );
      expect(result.decision, LoopPacksFutureGateDecision.packsFrozen);
      expect(
        _prereq(result, LoopPackFuturePrereqId.paidIntentBetaComplete).status,
        LoopPackFuturePrereqStatus.fail,
      );
    });

    test('packs map to audience wedge ids', () {
      final result = LoopPacksFutureGate.build(_input());
      expect(
        _pack(result, LoopPackFutureId.sayingYesNoCapacity).audienceWedgeId,
        'sayingYesNoCapacity',
      );
      expect(
        _pack(result, LoopPackFutureId.tryingToProveEnough).audienceWedgeId,
        'proveEnough',
      );
      expect(
        _pack(result, LoopPackFutureId.feelingBehindWhenStopping)
            .audienceWedgeId,
        'feelingBehindWhenStop',
      );
    });

    test('report exposes canonical copy', () {
      final report = LoopPacksFutureGate.report(
        LoopPacksFutureGate.build(_input()),
      );
      expect(report.headline, LoopPacksFutureCopy.headline);
      expect(report.guardrail, LoopPacksFutureCopy.guardrail);
      expect(report.prereqOrderLine, LoopPacksFutureCopy.prereqOrderLine);
    });
  });

  group('LoopPacksFutureGate.composeInput', () {
    test('bridges single launch checklist fields', () {
      final input = LoopPacksFutureGate.composeInput(
        launchChecklist: const SingleLaunchChecklistInput(
          testFlightUploaded: true,
          paidIntentBetaComplete: true,
        ),
      );
      final result = LoopPacksFutureGate.build(input);
      expect(result.decision, LoopPacksFutureGateDecision.packsDocumentedOnly);
    });

    test('bridges paid-intent beta promising signal', () {
      final input = LoopPacksFutureGate.composeInput(
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

  group('LoopPacksFutureGate.fromRepoSignals', () {
    late String docsSource;
    late String gateCopySource;
    late String audienceWedgeModelSource;

    setUpAll(() {
      docsSource = File(_docsPath).readAsStringSync();
      gateCopySource = File(
        'lib/features/loop_packs_future/loop_packs_future_copy.dart',
      ).readAsStringSync();
      audienceWedgeModelSource = File(
        'lib/features/acquisition/audience_wedge_model.dart',
      ).readAsStringSync();
    });

    test('detectRoadmapDocListsPacks matches loop packs doc', () {
      expect(
        LoopPacksFutureGate.detectRoadmapDocListsPacks(docsSource),
        isTrue,
      );
    });

    test('detectGuardrailPresentInCopy matches gate copy', () {
      expect(
        LoopPacksFutureGate.detectGuardrailPresentInCopy(gateCopySource),
        isTrue,
      );
    });

    test('detectAudienceWedgeIdsAligned matches audience wedge model', () {
      expect(
        LoopPacksFutureGate.detectAudienceWedgeIdsAligned(
          audienceWedgeModelSource,
        ),
        isTrue,
      );
    });

    test('fromRepoSignals defaults pending prerequisites -> packsFrozen', () {
      final result = LoopPacksFutureGate.build(
        LoopPacksFutureGate.fromRepoSignals(
          loopPacksFutureDocSource: docsSource,
          gateCopySource: gateCopySource,
          audienceWedgeModelSource: audienceWedgeModelSource,
        ),
      );
      expect(result.decision, LoopPacksFutureGateDecision.packsFrozen);
      expect(result.betaProofComplete, isFalse);
    });
  });

  group('protected regression', () {
    test('docs describe acquisition-only loop pack scope', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('loop packs'));
      expect(doc, contains('do not add new onboarding ui'));
      expect(doc, contains('do not add paywall benefits'));
    });

    test('guardrail forbids onboarding UI and paywall benefits', () {
      final guardrail = LoopPacksFutureCopy.guardrail.toLowerCase();
      expect(guardrail, contains('do not add new onboarding ui'));
      expect(guardrail, contains('do not add paywall benefits'));
      expect(guardrail, contains('clinical framing'));
    });

    test('pack positioning avoids therapy and diagnosis language', () {
      const forbidden = ['therapy', 'diagnosis', 'diagnose', 'disorder'];
      for (final id in LoopPackFutureId.values) {
        final positioning = LoopPacksFutureCopy.positioningFor(id).toLowerCase();
        for (final word in forbidden) {
          expect(positioning.contains(word), isFalse, reason: '$id: $positioning');
        }
        expect(
          ProofSurfaceAdviceGuard.passes(LoopPacksFutureCopy.positioningFor(id)),
          isTrue,
          reason: LoopPacksFutureCopy.positioningFor(id),
        );
      }
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final copy in LoopPacksFutureCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });

    test('module does not import onboarding screens or paywall sources', () {
      for (final path in [
        'lib/features/loop_packs_future/loop_packs_future_gate.dart',
        'lib/features/loop_packs_future/loop_packs_future_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
        expect(source.contains('onboarding_screen'), isFalse);
      }
    });

    test('advice guard registers loop packs future copy', () {
      final guardSource = File(
        'lib/features/archive_proof/proof_surface_advice_guard.dart',
      ).readAsStringSync();
      expect(
        guardSource,
        contains('LoopPacksFutureCopy.allVisibleStrings()'),
      );
    });
  });
}
