import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/change_trail_clarity/change_trail_clarity.dart';
import 'package:voicememory_mobile/features/core_archive_journey/core_archive_journey.dart';
import 'package:voicememory_mobile/features/pro_promise_copy_audit/pro_promise_copy_audit.dart';
import 'package:voicememory_mobile/features/pro_promise_copy_audit/pro_promise_copy_audit_copy.dart';
import 'package:voicememory_mobile/features/pro_single_promise/pro_single_promise.dart';
import 'package:voicememory_mobile/features/pro_single_promise/pro_single_promise_copy.dart';
import 'package:voicememory_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:voicememory_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:voicememory_mobile/features/proof_trail_positioning/proof_trail_positioning_copy.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_copy.dart';
import 'package:voicememory_mobile/features/timeline_proof_moment/timeline_proof_moment_copy.dart';
import 'package:voicememory_mobile/features/paywall_value_sharpening/paywall_value_sharpening_copy.dart';
import 'package:voicememory_mobile/features/landing_continuity/landing_app_continuity_copy.dart';
import 'package:voicememory_mobile/features/release_candidate_freeze/release_candidate_freeze.dart';
import 'package:voicememory_mobile/features/revenuecat_sandbox_proof/revenuecat_sandbox_proof.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';

void main() {
  group('ProPromiseCopyAudit.audit', () {
    test('preferred single promise language is aligned', () {
      const copy =
          'Free shows the first useful proof. Pro keeps the longer proof trail.';
      final result = ProPromiseCopyAudit.audit(copy);
      expect(result.decision, ProPromiseCopyAuditDecision.aligned);
      expect(result.isAligned, isTrue);
      expect(ProPromiseCopyAudit.containsPreferredLanguage(copy), isTrue);
    });

    test('continuity language with returns/changes/fades is aligned', () {
      const copy =
          'Pro keeps tracking what returns, changes, fades, or gets corrected.';
      final result = ProPromiseCopyAudit.audit(copy);
      expect(result.decision, ProPromiseCopyAuditDecision.aligned);
      expect(ProPromiseCopyAudit.containsPreferredLanguage(copy), isTrue);
    });

    test('Pro single promise module copy is aligned', () {
      for (final copy in ProSinglePromiseCopy.allVisibleStrings()) {
        final result = ProPromiseCopyAudit.audit(copy);
        expect(result.isAligned, isTrue, reason: copy);
      }
    });

    test('proof trail positioning copy is aligned', () {
      final result = ProPromiseCopyAudit.audit(
        ProofTrailPositioningCopy.proLine,
      );
      expect(result.decision, ProPromiseCopyAuditDecision.aligned);
    });

    test('full timeline promise conflicts', () {
      final result = ProPromiseCopyAudit.audit(
        'Pro keeps the full timeline as it grows.',
      );
      expect(result.decision, ProPromiseCopyAuditDecision.conflictFound);
      expect(result.conflict, ProPromiseCopyConflict.fullTimelinePromise);
      expect(result.neutralizeHint, ProPromiseCopyAuditCopy.preferredProLine);
    });

    test('longer story promise conflicts', () {
      final result = ProPromiseCopyAudit.audit(
        'Pro tells your longer story over time.',
      );
      expect(result.conflict, ProPromiseCopyConflict.longerStoryPromise);
    });

    test('more AI promise conflicts', () {
      final result = ProPromiseCopyAudit.audit(
        'Upgrade for more AI insights about your archive.',
      );
      expect(result.conflict, ProPromiseCopyConflict.moreAiPromise);
    });

    test('negated more AI language is aligned', () {
      final result = ProPromiseCopyAudit.audit(
        ProSinglePromiseCopy.notMoreAiLine,
      );
      expect(result.isAligned, isTrue);
    });

    test('more features promise conflicts', () {
      final result = ProPromiseCopyAudit.audit(
        'Unlock more features with Pro.',
      );
      expect(result.conflict, ProPromiseCopyConflict.moreFeaturesPromise);
    });

    test('reports as primary promise conflicts', () {
      final result = ProPromiseCopyAudit.audit(
        'Pro unlocks reports across your archive.',
      );
      expect(result.conflict, ProPromiseCopyConflict.reportsPrimaryPromise);
    });

    test('dashboard as primary promise conflicts', () {
      final result = ProPromiseCopyAudit.audit(
        'Your analytics dashboard updates with Pro.',
      );
      expect(result.conflict, ProPromiseCopyConflict.dashboardPrimaryPromise);
    });

    test('storage backup promise conflicts', () {
      final result = ProPromiseCopyAudit.audit(
        'Cloud backup keeps every recording safe with Pro.',
      );
      expect(result.conflict, ProPromiseCopyConflict.storageBackupPromise);
    });

    test('ranking scoring promise conflicts', () {
      final result = ProPromiseCopyAudit.audit(
        'Importance scoring ranks what matters most in Pro.',
      );
      expect(result.conflict, ProPromiseCopyConflict.rankingScoringPromise);
    });

    test('ambiguous pro copy without preferred language needs review', () {
      final result = ProPromiseCopyAudit.audit('See what Pro keeps.');
      expect(result.decision, ProPromiseCopyAuditDecision.needsReview);
    });

    test('neutral non-pro copy is aligned', () {
      final result = ProPromiseCopyAudit.audit('Save one repeat when it happens.');
      expect(result.decision, ProPromiseCopyAuditDecision.aligned);
    });
  });

  group('ProPromiseCopyAudit.auditAll', () {
    test('batch reports conflict count', () {
      final batch = ProPromiseCopyAudit.auditAll([
        const ProPromiseCopyAuditEntry(
          id: 'good',
          copy: 'Free shows the first useful proof. Pro keeps the longer proof trail.',
        ),
        const ProPromiseCopyAuditEntry(
          id: 'bad',
          copy: 'Pro keeps the full timeline as it grows.',
        ),
      ]);

      expect(batch.conflictCount, 1);
      expect(batch.allAligned, isFalse);
    });
  });

  group('Pro promise copy corpus', () {
    final corpus = <ProPromiseCopyAuditEntry>[
      for (final copy in ProSinglePromiseCopy.allVisibleStrings())
        ProPromiseCopyAuditEntry(id: 'pro_single_promise', copy: copy),
      ProPromiseCopyAuditEntry(
        id: 'proof_trail_positioning',
        copy: ProofTrailPositioningCopy.proLine,
      ),
      ProPromiseCopyAuditEntry(
        id: 'timeline_proof_moment',
        copy: TimelineProofMomentCopy.proLine,
      ),
      ProPromiseCopyAuditEntry(
        id: 'surface_priority',
        copy: SurfacePriorityCopy.paidReason,
      ),
      ProPromiseCopyAuditEntry(
        id: 'landing_continuity',
        copy: LandingAppContinuityCopy.freePositioning,
      ),
      for (final copy in PaywallValueSharpeningCopy.allPaywallStrings())
        ProPromiseCopyAuditEntry(id: 'paywall_value_sharpening', copy: copy),
    ];

    test('known Pro surfaces pass audit or only need review', () {
      final batch = ProPromiseCopyAudit.auditAll(corpus);
      final conflicts = batch.results
          .where(
            (result) =>
                result.decision == ProPromiseCopyAuditDecision.conflictFound,
          )
          .toList();
      expect(
        conflicts,
        isEmpty,
        reason: conflicts.map((r) => '${r.copy} -> ${r.message}').join('\n'),
      );
    });
  });

  group('ProPromiseCopyAuditCopy', () {
    test('states preferred free and pro lines', () {
      expect(
        ProPromiseCopyAuditCopy.preferredFreeLine.toLowerCase(),
        contains('first useful proof'),
      );
      expect(
        ProPromiseCopyAuditCopy.preferredProLine.toLowerCase(),
        contains('longer proof trail'),
      );
    });

    test('guardrail is copy guard only', () {
      final lower = ProPromiseCopyAuditCopy.guardrail.toLowerCase();
      expect(lower, contains('copy guard only'));
      expect(lower, contains('revenuecat'));
      expect(lower, contains('purchase flow'));
    });

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in ProPromiseCopyAuditCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });
  });

  group('Protected areas', () {
    test('module does not import billing or purchases_flutter', () {
      for (final path in [
        'lib/features/pro_promise_copy_audit/pro_promise_copy_audit.dart',
        'lib/features/pro_promise_copy_audit/pro_promise_copy_audit_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('package:purchases_flutter'), isFalse);
        expect(source.contains('billing/'), isFalse);
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
