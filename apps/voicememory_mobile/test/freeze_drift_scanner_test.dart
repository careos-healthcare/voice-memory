import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/change_trail_clarity/change_trail_clarity.dart';
import 'package:voicememory_mobile/features/core_archive_journey/core_archive_journey.dart';
import 'package:voicememory_mobile/features/freeze_drift_scanner/freeze_drift_scanner.dart';
import 'package:voicememory_mobile/features/freeze_drift_scanner/freeze_drift_scanner_copy.dart';
import 'package:voicememory_mobile/features/pro_single_promise/pro_single_promise.dart';
import 'package:voicememory_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:voicememory_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:voicememory_mobile/features/release_candidate_freeze/release_candidate_freeze.dart';
import 'package:voicememory_mobile/features/revenuecat_sandbox_proof/revenuecat_sandbox_proof.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';

FreezeDriftScannerInput _input({
  bool freezeActive = true,
  required FreezeDriftCategory category,
  bool fixesFirstJourneyComprehension = false,
  bool fixesCriticalProofTrust = false,
}) =>
    FreezeDriftScannerInput(
      freezeActive: freezeActive,
      category: category,
      fixesFirstJourneyComprehension: fixesFirstJourneyComprehension,
      fixesCriticalProofTrust: fixesCriticalProofTrust,
    );

void main() {
  group('FreezeDriftScanner.scan', () {
    test('freeze inactive -> freezeInactive', () {
      final result = FreezeDriftScanner.scan(
        _input(
          freezeActive: false,
          category: FreezeDriftCategory.newDashboard,
        ),
      );
      expect(result.decision, FreezeDriftDecision.freezeInactive);
      expect(result.freezeAllowed, isTrue);
    });

    for (final category in FreezeDriftScanner.riskyCategories) {
      test('risky drift $category blocks by default', () {
        final result = FreezeDriftScanner.scan(_input(category: category));
        expect(result.decision, FreezeDriftDecision.blocked);
        expect(result.blocksByDefault, isTrue);
        expect(result.isRiskyDrift, isTrue);
        expect(result.freezeAllowed, isFalse);
      });
    }

    for (final category in FreezeDriftScanner.allowedCategories) {
      test('allowed change $category passes during freeze', () {
        final result = FreezeDriftScanner.scan(_input(category: category));
        expect(result.decision, FreezeDriftDecision.allowed);
        expect(result.freezeAllowed, isTrue);
        expect(result.isRiskyDrift, isFalse);
      });
    }

    test('record layout allowed only with first journey fix flag', () {
      final blocked = FreezeDriftScanner.scan(
        _input(category: FreezeDriftCategory.recordLayoutChange),
      );
      expect(blocked.decision, FreezeDriftDecision.blocked);

      final allowed = FreezeDriftScanner.scan(
        _input(
          category: FreezeDriftCategory.recordLayoutChange,
          fixesFirstJourneyComprehension: true,
        ),
      );
      expect(allowed.decision, FreezeDriftDecision.allowed);
    });

    test('anchor threshold allowed only with critical proof trust fix flag', () {
      final blocked = FreezeDriftScanner.scan(
        _input(category: FreezeDriftCategory.anchorThresholdChange),
      );
      expect(blocked.decision, FreezeDriftDecision.blocked);

      final allowed = FreezeDriftScanner.scan(
        _input(
          category: FreezeDriftCategory.anchorThresholdChange,
          fixesCriticalProofTrust: true,
        ),
      );
      expect(allowed.decision, FreezeDriftDecision.allowed);
    });
  });

  group('FreezeDriftScanner integration', () {
    test('fromFreezeInput blocks new product feature drift', () {
      final result = FreezeDriftScanner.fromFreezeInput(
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
          addsNewUserFacingSurface: true,
          changesPricingOrPaywall: false,
          changesProofThresholds: false,
          changesRecordLayout: false,
        ),
        freezeActive: true,
      );
      expect(result.decision, FreezeDriftDecision.blocked);
      expect(result.category, FreezeDriftCategory.newFeatureSurface);
    });

    test('fromFreezeInput allows purchase blocker fix', () {
      final result = FreezeDriftScanner.fromFreezeInput(
        const ReleaseCandidateFreezeInput(
          changeType: ReleaseCandidateChangeType.purchaseBlocker,
          blocksRelease: false,
          blocksPurchase: true,
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
        freezeActive: true,
      );
      expect(result.decision, FreezeDriftDecision.allowed);
      expect(result.category, FreezeDriftCategory.purchase);
    });

    test('toFreezeInput maps storage positioning to pro benefit drift', () {
      final freezeInput = FreezeDriftScanner.toFreezeInput(
        _input(category: FreezeDriftCategory.storagePositioning),
      );
      expect(
        freezeInput.changeType,
        ReleaseCandidateChangeType.newProBenefit,
      );
    });

    test('categoryForChangeType round-trips risky categories', () {
      expect(
        FreezeDriftScanner.categoryForChangeType(
          ReleaseCandidateChangeType.newDashboard,
        ),
        FreezeDriftCategory.newDashboard,
      );
      expect(
        FreezeDriftScanner.categoryForChangeType(
          ReleaseCandidateChangeType.newActionItems,
        ),
        FreezeDriftCategory.actionItemExpansion,
      );
    });
  });

  group('FreezeDriftScannerCopy', () {
    test('lists risky and allowed drift categories in copy', () {
      expect(
        FreezeDriftScannerCopy.riskyLine.toLowerCase(),
        allOf(
          contains('dashboard'),
          contains('ranking'),
          contains('chat mode'),
          contains('anchor'),
        ),
      );
      expect(
        FreezeDriftScannerCopy.allowedLine.toLowerCase(),
        allOf(
          contains('purchase'),
          contains('restore'),
          contains('entitlement'),
          contains('security'),
        ),
      );
    });

    test('guardrail says no product UI changes', () {
      expect(
        FreezeDriftScannerCopy.guardrail.toLowerCase(),
        contains('no product ui changes'),
      );
    });

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in FreezeDriftScannerCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });
  });

  group('Protected areas', () {
    test('module does not import billing or purchases_flutter', () {
      for (final path in [
        'lib/features/freeze_drift_scanner/freeze_drift_scanner.dart',
        'lib/features/freeze_drift_scanner/freeze_drift_scanner_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
        expect(source.contains('paywall_source'), isFalse);
        expect(source.contains('importance_scoring'), isFalse);
      }
    });

    test('release candidate freeze still blocks new dashboard', () {
      expect(
        ReleaseCandidateFreeze.build(
          const ReleaseCandidateFreezeInput(
            changeType: ReleaseCandidateChangeType.newDashboard,
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

    test('revenuecat sandbox proof still requires manual device steps', () {
      final result = RevenueCatSandboxProof.build(
        const RevenueCatSandboxProofInput(
          iosApiKeyPresent: true,
          offeringLoads: true,
          productTitlePriceVisible: true,
        ),
      );
      expect(result.decision, RevenueCatSandboxProofDecision.manualRequired);
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

ChangeTrailClaritySummary _fullTrailSummary() => const ChangeTrailClaritySummary(
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
