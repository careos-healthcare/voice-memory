import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/first_proof_success_beta/first_proof_success_beta_guard.dart';
import 'package:voicememory_mobile/features/future_expansion_roadmap/future_expansion_roadmap_copy.dart';
import 'package:voicememory_mobile/features/future_expansion_roadmap/future_expansion_roadmap_gate.dart';
import 'package:voicememory_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:voicememory_mobile/features/release_fragility/release_fragility_audit.dart';
import 'package:voicememory_mobile/features/release_fragility/release_fragility_copy.dart';
import 'package:voicememory_mobile/features/secrets_rotation_gate/secrets_rotation_launch_gate.dart';
import 'package:voicememory_mobile/features/secrets_rotation_gate/secrets_rotation_launch_gate_copy.dart';
import 'package:voicememory_mobile/features/single_launch_checklist/single_launch_checklist.dart';

const _docsPath = 'docs/FUTURE_EXPANSION_ROADMAP.md';

FutureExpansionRoadmapGateInput _input({
  bool? testFlightUploaded = true,
  bool? purchaseWorks = true,
  bool? restoreWorks = true,
  bool? entitlementPersists = true,
  bool? paidIntentBetaComplete = true,
  bool? firstProofSuccessRateAcceptable = true,
  bool? noReleaseBlockers = true,
  bool? noSecretsProductionBlockerForProductionLaunch = true,
}) => FutureExpansionRoadmapGateInput(
  testFlightUploaded: testFlightUploaded,
  purchaseWorks: purchaseWorks,
  restoreWorks: restoreWorks,
  entitlementPersists: entitlementPersists,
  paidIntentBetaComplete: paidIntentBetaComplete,
  firstProofSuccessRateAcceptable: firstProofSuccessRateAcceptable,
  noReleaseBlockers: noReleaseBlockers,
  noSecretsProductionBlockerForProductionLaunch:
      noSecretsProductionBlockerForProductionLaunch,
);

FutureExpansionPrereq _prereq(
  FutureExpansionRoadmapGateResult result,
  FutureExpansionPrereqId id,
) => result.prereqs.firstWhere((prereq) => prereq.id == id);

FutureExpansionIdea _idea(
  FutureExpansionRoadmapGateResult result,
  FutureExpansionIdeaId id,
) => result.ideas.firstWhere((idea) => idea.id == id);

void main() {
  group('FutureExpansionRoadmapGate.build', () {
    test('gate tracks fourteen ideas and eight prerequisites in order', () {
      final result = FutureExpansionRoadmapGate.build(_input());
      expect(result.ideas.length, FutureExpansionRoadmapGate.ideaCount);
      expect(result.prereqs.length, FutureExpansionRoadmapGate.prereqCount);
      expect(result.ideaOrder, FutureExpansionRoadmapGate.canonicalIdeaOrder);
      expect(
        result.prereqOrder,
        FutureExpansionRoadmapGate.canonicalPrereqOrder,
      );
      expect(
        result.ideas.map((idea) => idea.id).toList(),
        FutureExpansionRoadmapGate.canonicalIdeaOrder,
      );
    });

    test('all prerequisites pass -> postV1PlanningAllowed', () {
      final result = FutureExpansionRoadmapGate.build(_input());
      expect(
        result.decision,
        FutureExpansionGateDecision.postV1PlanningAllowed,
      );
      expect(result.releaseProofComplete, isTrue);
      expect(result.blockedIdeaCount, 0);
      expect(result.readyIdeaCount, greaterThan(0));
      expect(result.earliestPrereqGap, isNull);
    });

    test('pending TestFlight -> expansionFrozen and ideas blocked', () {
      final result = FutureExpansionRoadmapGate.build(
        _input(testFlightUploaded: null),
      );
      expect(result.decision, FutureExpansionGateDecision.expansionFrozen);
      expect(result.releaseProofComplete, isFalse);
      expect(
        result.earliestPrereqGap,
        FutureExpansionPrereqId.testFlightUploaded,
      );
      expect(
        _idea(result, FutureExpansionIdeaId.loopPacks).status,
        FutureExpansionIdeaStatus.blockedBeforeReleaseProof,
      );
    });

    test('release blockers present -> expansionFrozen', () {
      final result = FutureExpansionRoadmapGate.build(
        _input(noReleaseBlockers: false),
      );
      expect(result.decision, FutureExpansionGateDecision.expansionFrozen);
      expect(
        _prereq(result, FutureExpansionPrereqId.noReleaseBlockers).status,
        FutureExpansionPrereqStatus.fail,
      );
    });

    test('secrets production blocker -> expansionFrozen', () {
      final result = FutureExpansionRoadmapGate.build(
        _input(noSecretsProductionBlockerForProductionLaunch: false),
      );
      expect(result.decision, FutureExpansionGateDecision.expansionFrozen);
      expect(
        _prereq(
          result,
          FutureExpansionPrereqId.noSecretsProductionBlockerForProductionLaunch,
        ).status,
        FutureExpansionPrereqStatus.fail,
      );
    });

    test('paid-intent beta incomplete still allows pricing experiments', () {
      final result = FutureExpansionRoadmapGate.build(
        _input(paidIntentBetaComplete: false),
      );
      expect(result.decision, FutureExpansionGateDecision.expansionFrozen);
      expect(result.pricingExperimentsBlocked, isFalse);
    });

    test('cross-device continuity stays documented after release proof', () {
      final result = FutureExpansionRoadmapGate.build(_input());
      expect(
        _idea(result, FutureExpansionIdeaId.crossDeviceContinuity).status,
        FutureExpansionIdeaStatus.documentedNotSurfaced,
      );
    });

    test(
      'premium tiers stay documented even when paid-intent beta complete',
      () {
        final result = FutureExpansionRoadmapGate.build(_input());
        expect(
          _idea(result, FutureExpansionIdeaId.premiumLongerTrailTiers).status,
          FutureExpansionIdeaStatus.documentedNotSurfaced,
        );
      },
    );

    test(
      'loop packs ready for post-V1 planning when release proof complete',
      () {
        final result = FutureExpansionRoadmapGate.build(_input());
        expect(
          _idea(result, FutureExpansionIdeaId.loopPacks).status,
          FutureExpansionIdeaStatus.readyForPostV1Planning,
        );
      },
    );

    test('report exposes canonical copy', () {
      final report = FutureExpansionRoadmapGate.report(
        FutureExpansionRoadmapGate.build(_input()),
      );
      expect(report.headline, FutureExpansionRoadmapCopy.headline);
      expect(report.guardrail, FutureExpansionRoadmapCopy.guardrail);
      expect(
        report.prereqOrderLine,
        FutureExpansionRoadmapCopy.prereqOrderLine,
      );
    });
  });

  group('FutureExpansionRoadmapGate.composeInput', () {
    test('bridges single launch checklist fields', () {
      final input = FutureExpansionRoadmapGate.composeInput(
        launchChecklist: const SingleLaunchChecklistInput(
          testFlightUploaded: true,
          sandboxPurchaseWorks: true,
          restoreWorks: true,
          entitlementPersists: true,
          paidIntentBetaComplete: true,
        ),
        releaseFragility: ReleaseFragilityAuditResult(
          decision: ReleaseFragilityDecision.lowRisk,
          message: 'ok',
          recommendation: 'ok',
          risks: const [],
          riskOrder: ReleaseFragilityAudit.canonicalRiskOrder,
          earliestBlocker: null,
          lowRiskCount: 0,
          manualCheckCount: 0,
          blockedCount: 0,
        ),
        firstProofSuccessBeta: FirstProofSuccessBetaGuard.build(
          FirstProofSuccessBetaInput(
            usableMomentCount: 3,
            hasSafeAnchor: true,
            hasMatchQuality: true,
            proofShown: true,
            proofAccepted: true,
            userUnderstoodWhy: true,
            proofThresholdStillThree: true,
            betaReadinessStillGuardsThree: true,
            proofConfidence: ProofConfidenceLevel.strong,
          ),
        ),
        secretsRotation: SecretsRotationLaunchGateResult(
          status: SecretsRotationLaunchGateStatus.readyForProductionSubmission,
          message: 'ready',
          recommendation: 'ready',
          checks: const [],
          earliestBlocker: null,
          productionSubmissionReady: true,
          testFlightAllowed: true,
        ),
      );
      final result = FutureExpansionRoadmapGate.build(input);
      expect(
        result.decision,
        FutureExpansionGateDecision.postV1PlanningAllowed,
      );
      expect(
        _prereq(result, FutureExpansionPrereqId.testFlightUploaded).status,
        FutureExpansionPrereqStatus.pass,
      );
      expect(
        _prereq(
          result,
          FutureExpansionPrereqId.firstProofSuccessRateAcceptable,
        ).status,
        FutureExpansionPrereqStatus.pass,
      );
    });

    test('bridges paid-intent beta promising signal', () {
      final input = FutureExpansionRoadmapGate.composeInput(
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

    test('release fragility blocked maps to no release blockers false', () {
      final input = FutureExpansionRoadmapGate.composeInput(
        releaseFragility: ReleaseFragilityAuditResult(
          decision: ReleaseFragilityDecision.releaseBlocked,
          message: ReleaseFragilityCopy.releaseBlockedLine,
          recommendation: 'fix',
          risks: const [],
          riskOrder: ReleaseFragilityAudit.canonicalRiskOrder,
          earliestBlocker: ReleaseFragilityRiskId.bundleId,
          lowRiskCount: 0,
          manualCheckCount: 0,
          blockedCount: 1,
        ),
      );
      expect(input.noReleaseBlockers, isFalse);
    });
  });

  group('FutureExpansionRoadmapGate.fromRepoSignals', () {
    late String docsSource;
    late String gateCopySource;

    setUpAll(() {
      docsSource = File(_docsPath).readAsStringSync();
      gateCopySource = File(
        'lib/features/future_expansion_roadmap/future_expansion_roadmap_copy.dart',
      ).readAsStringSync();
    });

    test('detectRoadmapDocListsIdeas matches roadmap doc', () {
      expect(
        FutureExpansionRoadmapGate.detectRoadmapDocListsIdeas(docsSource),
        isTrue,
      );
    });

    test('detectGuardrailPresentInCopy matches gate copy', () {
      expect(
        FutureExpansionRoadmapGate.detectGuardrailPresentInCopy(gateCopySource),
        isTrue,
      );
    });

    test(
      'fromRepoSignals defaults pending prerequisites -> expansionFrozen',
      () {
        final result = FutureExpansionRoadmapGate.build(
          FutureExpansionRoadmapGate.fromRepoSignals(
            futureExpansionRoadmapDocSource: docsSource,
            gateCopySource: gateCopySource,
          ),
        );
        expect(result.decision, FutureExpansionGateDecision.expansionFrozen);
        expect(result.releaseProofComplete, isFalse);
      },
    );
  });

  group('protected regression', () {
    test('docs describe audit-only expansion gate scope', () {
      final doc = File(_docsPath).readAsStringSync().toLowerCase();
      expect(doc, contains('future expansion'));
      expect(doc, contains('no new live ui'));
      expect(doc, contains('audit'));
    });

    test('guardrail forbids V1 surfacing and pricing experiments', () {
      final guardrail = FutureExpansionRoadmapCopy.guardrail.toLowerCase();
      expect(guardrail, contains('no new live ui'));
      expect(
        guardrail,
        contains('no pricing experiments before paid-intent beta'),
      );
      expect(guardrail, contains('not surfaced in v1'));
    });

    test('all visible strings pass proof surface advice guard', () {
      for (final copy in FutureExpansionRoadmapCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(copy),
          isTrue,
          reason: 'Advice guard failed for: $copy',
        );
      }
    });

    test('module does not import billing SDK or purchases_flutter', () {
      for (final path in [
        'lib/features/future_expansion_roadmap/future_expansion_roadmap_gate.dart',
        'lib/features/future_expansion_roadmap/future_expansion_roadmap_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
      }
    });

    test('advice guard registers future expansion roadmap copy', () {
      final guardSource = File(
        'lib/features/archive_proof/proof_surface_advice_guard.dart',
      ).readAsStringSync();
      expect(
        guardSource,
        contains('FutureExpansionRoadmapCopy.allVisibleStrings()'),
      );
    });
  });
}
