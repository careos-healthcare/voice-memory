import 'dart:io';

import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/change_trail_clarity/change_trail_clarity.dart';
import 'package:archiveme_mobile/features/core_archive_journey/core_archive_journey.dart';
import 'package:archiveme_mobile/features/pro_single_promise/pro_single_promise.dart';
import 'package:archiveme_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:archiveme_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:archiveme_mobile/features/release_blocker_priority/release_blocker_priority.dart';
import 'package:archiveme_mobile/features/release_blocker_priority/release_blocker_priority_copy.dart';
import 'package:archiveme_mobile/features/release_candidate_freeze/release_candidate_freeze.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:flutter_test/flutter_test.dart';

ReleaseBlockerPriorityInput _input({
  bool freezeActive = true,
  bool hasSecuritySecretsBlocker = false,
  bool hasCrash = false,
  bool blocksStoreReadiness = false,
  bool risksAppStoreRejection = false,
  bool blocksPurchase = false,
  bool blocksRestore = false,
  bool blocksEntitlement = false,
  bool firstJourneyComprehensionWeak = false,
  bool criticalProofTrustWeak = false,
  bool paidIntentSignalWeak = false,
}) => ReleaseBlockerPriorityInput(
  freezeActive: freezeActive,
  hasSecuritySecretsBlocker: hasSecuritySecretsBlocker,
  hasCrash: hasCrash,
  blocksStoreReadiness: blocksStoreReadiness,
  risksAppStoreRejection: risksAppStoreRejection,
  blocksPurchase: blocksPurchase,
  blocksRestore: blocksRestore,
  blocksEntitlement: blocksEntitlement,
  firstJourneyComprehensionWeak: firstJourneyComprehensionWeak,
  criticalProofTrustWeak: criticalProofTrustWeak,
  paidIntentSignalWeak: paidIntentSignalWeak,
);

void main() {
  group('ReleaseBlockerPriority.build', () {
    test('security secrets blocker is first priority', () {
      final result = ReleaseBlockerPriority.build(
        _input(
          hasSecuritySecretsBlocker: true,
          hasCrash: true,
          blocksPurchase: true,
        ),
      );
      expect(
        result.decision,
        ReleaseBlockerPriorityDecision.fixSecuritySecretsFirst,
      );
    });

    test('crash is second priority after security', () {
      final result = ReleaseBlockerPriority.build(
        _input(hasCrash: true, blocksPurchase: true),
      );
      expect(result.decision, ReleaseBlockerPriorityDecision.fixCrashFirst);
    });

    test('store readiness is third priority', () {
      final result = ReleaseBlockerPriority.build(
        _input(blocksStoreReadiness: true, blocksPurchase: true),
      );
      expect(
        result.decision,
        ReleaseBlockerPriorityDecision.fixStoreReadinessFirst,
      );
    });

    test('App Store rejection risk follows store readiness', () {
      final result = ReleaseBlockerPriority.build(
        _input(risksAppStoreRejection: true, blocksPurchase: true),
      );
      expect(
        result.decision,
        ReleaseBlockerPriorityDecision.fixAppStoreRiskFirst,
      );
    });

    test('purchase blocker is next after store risk', () {
      final result = ReleaseBlockerPriority.build(
        _input(blocksPurchase: true, blocksRestore: true),
      );
      expect(result.decision, ReleaseBlockerPriorityDecision.fixPurchaseFirst);
    });

    test('restore blocker follows purchase', () {
      final result = ReleaseBlockerPriority.build(
        _input(blocksRestore: true, blocksEntitlement: true),
      );
      expect(result.decision, ReleaseBlockerPriorityDecision.fixRestoreFirst);
    });

    test('entitlement blocker follows restore', () {
      final result = ReleaseBlockerPriority.build(
        _input(blocksEntitlement: true, firstJourneyComprehensionWeak: true),
      );
      expect(
        result.decision,
        ReleaseBlockerPriorityDecision.fixEntitlementFirst,
      );
    });

    test('first journey comprehension weakness is next', () {
      final result = ReleaseBlockerPriority.build(
        _input(
          firstJourneyComprehensionWeak: true,
          criticalProofTrustWeak: true,
        ),
      );
      expect(
        result.decision,
        ReleaseBlockerPriorityDecision.fixFirstJourneyFirst,
      );
    });

    test('critical proof trust weakness follows first journey', () {
      final result = ReleaseBlockerPriority.build(
        _input(criticalProofTrustWeak: true, paidIntentSignalWeak: true),
      );
      expect(
        result.decision,
        ReleaseBlockerPriorityDecision.fixProofTrustFirst,
      );
    });

    test('paid intent signal weakness is last blocker before ready', () {
      final result = ReleaseBlockerPriority.build(
        _input(paidIntentSignalWeak: true),
      );
      expect(
        result.decision,
        ReleaseBlockerPriorityDecision.validatePaidIntentFirst,
      );
    });

    test('all blockers cleared returns ready for paid intent beta', () {
      final result = ReleaseBlockerPriority.build(_input());
      expect(
        result.decision,
        ReleaseBlockerPriorityDecision.readyForPaidIntentBeta,
      );
    });

    test('freeze inactive returns resume after freeze', () {
      final result = ReleaseBlockerPriority.build(_input(freezeActive: false));
      expect(result.decision, ReleaseBlockerPriorityDecision.resumeAfterFreeze);
    });
  });

  group('ReleaseBlockerPriorityCopy', () {
    test('headline says Fix blockers in order', () {
      expect(ReleaseBlockerPriorityCopy.headline, 'Fix blockers in order');
    });

    test('body says fix highest-impact blocker first', () {
      expect(
        ReleaseBlockerPriorityCopy.body.toLowerCase(),
        contains('highest-impact blocker first'),
      );
    });

    test('body says do not start new product work', () {
      expect(
        ReleaseBlockerPriorityCopy.body.toLowerCase(),
        contains('do not start new product work'),
      );
    });

    test(
      'priorityLine includes security crash store purchase restore entitlement',
      () {
        final lower = ReleaseBlockerPriorityCopy.priorityLine.toLowerCase();
        expect(lower, contains('security'));
        expect(lower, contains('crash'));
        expect(lower, contains('store readiness'));
        expect(lower, contains('purchase'));
        expect(lower, contains('restore'));
        expect(lower, contains('entitlement'));
        expect(lower, contains('first journey'));
        expect(lower, contains('proof trust'));
        expect(lower, contains('paid-intent beta'));
      },
    );

    test('firstJourneyLine protects save one repeat journey', () {
      final lower = ReleaseBlockerPriorityCopy.firstJourneyLine.toLowerCase();
      expect(lower, contains('save one repeat'));
      expect(lower, contains('first useful proof'));
    });

    test('readyLine says run paid-intent beta without adding features', () {
      expect(
        ReleaseBlockerPriorityCopy.readyLine.toLowerCase(),
        contains('without adding features'),
      );
    });

    test('guardrail blocks new product surfaces and feature volume', () {
      final lower = ReleaseBlockerPriorityCopy.guardrail.toLowerCase();
      expect(lower, contains('not new product surfaces'));
      expect(lower, contains('feature volume'));
    });

    test('copy does not say better than ChatGPT', () {
      for (final text in ReleaseBlockerPriorityCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('better than chatgpt'), isFalse, reason: text);
      }
    });

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in ReleaseBlockerPriorityCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });
  });

  group('Protected areas', () {
    test('module does not import billing entitlements or ranking UI', () {
      for (final path in [
        'lib/features/release_blocker_priority/release_blocker_priority.dart',
        'lib/features/release_blocker_priority/release_blocker_priority_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
        expect(source.contains('billing/'), isFalse);
        expect(source.contains('importance_scoring'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
      }
    });

    test('release candidate freeze still blocks new product feature', () {
      expect(
        ReleaseCandidateFreeze.build(
          const ReleaseCandidateFreezeInput(
            changeType: ReleaseCandidateChangeType.newProductFeature,
            blocksRelease: false,
            blocksPurchase: false,
            blocksRestore: false,
            blocksEntitlement: false,
            causesCrash: false,
            risksAppStoreRejection: false,
            affectsSecuritySecrets: false,
            fixesFirstJourneyComprehension: false,
            fixesCriticalProofTrust: false,
            addsNewUserFacingSurface: false,
            changesPricingOrPaywall: false,
            changesProofThresholds: false,
            changesRecordLayout: false,
          ),
        ).allowed,
        isFalse,
      );
    });

    test('pro single promise still reaches release candidate', () {
      expect(
        ProSinglePromise.build(
          const ProSinglePromiseInput(
            userUnderstandsFirstProof: true,
            userUnderstandsProKeepsLongerTrail: true,
            userThinksProMeansMoreAi: false,
            userThinksProMeansStorage: false,
            userThinksProMeansMoreFeatures: false,
            userThinksProMeansReports: false,
            userThinksProMeansRanking: false,
            userUnderstandsContinuityValue: true,
            userFeelsPressureOrManipulation: false,
            wouldPayYes: true,
            wouldPayMaybe: false,
          ),
        ).decision,
        ProSinglePromiseDecision.releaseCandidate,
      );
    });

    test('proof selection principle still blocks ranking', () {
      expect(ProofSelectionPrinciple.allowsRankingUi(), isFalse);
      expect(
        ProofDetailRepairCopy.whyThisOneLine,
        contains('clearest specific repeat'),
      );
    });

    test('record screen remains capture-first', () {
      final audit = SurfacePriorityEngine.auditRecordReady(
        entryCount: 4,
        source: 'record',
        candidates: SurfacePriorityCandidates.recordReady(
          firstMomentCapture: false,
          secondMomentReturn: false,
          lowFrictionReturn: false,
          whatToNoticeNext: false,
          betaTodaySummary: false,
          openCapturePromptChips: false,
          captureFreedomLine: false,
          timelineProofMoment: true,
          archiveTimelineSpine: false,
          timelinePositioning: false,
          currentRelevance: false,
          correctionMemory: false,
          notRelevantRecovery: false,
          proofQualityResponse: false,
          evidenceWeighting: false,
          proofSpecificity: false,
          presentDayRelevance: false,
          patternConfidence: false,
          betaTesterReport: false,
          proEvidenceValue: false,
          privateReportProBridge: false,
          suppressLegacyEducation: false,
          betaProofLift: true,
        ),
      );
      expect(audit.proofCardKey, 'timelineProofMoment');
      expect(audit.guidanceCardKey, isNull);
    });

    test('core archive journey still blocks voice assistant positioning', () {
      expect(
        CoreArchiveJourneyGuardrail.allowsVoiceAssistantPositioning(),
        isFalse,
      );
      expect(
        ChangeTrailClarity.resolve(_fullTrailSummary()),
        ChangeTrailClarityDecision.releaseCandidate,
      );
    });
  });
}

ChangeTrailClaritySummary _fullTrailSummary() =>
    const ChangeTrailClaritySummary(
      totalTesters: 30,
      understoodFirstProofCount: 7,
      understoodProKeepsTrailCount: 6,
      understoodReturnsCount: 6,
      understoodChangesCount: 6,
      understoodFadesCount: 6,
      understoodCorrectionsCount: 6,
      thoughtMoreAiCount: 0,
      wantedMoreProofCount: 0,
      wantedRankingCount: 0,
      wouldPayYesCount: 2,
      wouldPayMaybeCount: 1,
      wouldPayNoCount: 1,
    );