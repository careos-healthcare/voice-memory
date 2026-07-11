import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/core_metrics_minimum/core_metrics_minimum_set.dart';
import 'package:voicememory_mobile/features/core_metrics_minimum/core_metrics_minimum_set_copy.dart';
import 'package:voicememory_mobile/features/freeze_drift_scanner/freeze_drift_scanner.dart';
import 'package:voicememory_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'package:voicememory_mobile/features/pro_single_promise/pro_single_promise.dart';
import 'package:voicememory_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:voicememory_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:voicememory_mobile/features/release_blocker_priority/release_blocker_priority.dart';
import 'package:voicememory_mobile/features/release_candidate_freeze/release_candidate_freeze.dart';
import 'package:voicememory_mobile/features/revenuecat_sandbox_proof/revenuecat_sandbox_proof.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';

void main() {
  group('CoreMetricsMinimumSet.build', () {
    test('defines fourteen core beta metrics', () {
      final result = CoreMetricsMinimumSet.build();
      expect(result.coreMetricCount, 14);
      expect(result.metrics.length, 14);
      expect(
        result.metrics.map((metric) => metric.id).toSet().length,
        14,
      );
    });

    test('nine metrics are used for paid-intent decisions', () {
      final result = CoreMetricsMinimumSet.build();
      expect(result.paidIntentMetrics.length, 9);
      expect(
        result.paidIntentMetrics.map((metric) => metric.id).toSet(),
        {
          CoreMetricsMinimumMetricId.firstSave,
          CoreMetricsMinimumMetricId.firstUsefulProofSeen,
          CoreMetricsMinimumMetricId.proofAccepted,
          CoreMetricsMinimumMetricId.proofCorrected,
          CoreMetricsMinimumMetricId.proPromiseSeen,
          CoreMetricsMinimumMetricId.proTapped,
          CoreMetricsMinimumMetricId.purchaseStarted,
          CoreMetricsMinimumMetricId.purchaseCompleted,
          CoreMetricsMinimumMetricId.restoreTapped,
        },
      );
    });
  });

  group('CoreMetricsMinimumSet.classify core beta metrics', () {
    final coreCases = <(String, CoreMetricsMinimumMetricId, Map<String, Object>?)>[
      ('app_opened', CoreMetricsMinimumMetricId.appOpened, null),
      ('first_recording_saved', CoreMetricsMinimumMetricId.firstSave, null),
      ('second_save', CoreMetricsMinimumMetricId.secondSave, null),
      (
        'first_proof_moment_seen',
        CoreMetricsMinimumMetricId.firstUsefulProofSeen,
        null,
      ),
      (
        'beta_proof_feedback_answered',
        CoreMetricsMinimumMetricId.proofAccepted,
        {'feedback_type': 'useful'},
      ),
      (
        'correction_memory_saved',
        CoreMetricsMinimumMetricId.proofCorrected,
        null,
      ),
      (
        'value_moment_pro_bridge_seen',
        CoreMetricsMinimumMetricId.proPromiseSeen,
        null,
      ),
      (
        'paywall_purchase_cta_tapped',
        CoreMetricsMinimumMetricId.proTapped,
        null,
      ),
      ('purchase_started', CoreMetricsMinimumMetricId.purchaseStarted, null),
      ('purchase_completed', CoreMetricsMinimumMetricId.purchaseCompleted, null),
      ('restore_started', CoreMetricsMinimumMetricId.restoreTapped, null),
      ('restore_completed', CoreMetricsMinimumMetricId.restoreSucceeded, null),
      ('entitlement_active', CoreMetricsMinimumMetricId.entitlementActive, null),
      (
        'crash_blocker_reported',
        CoreMetricsMinimumMetricId.crashOrBlockerReported,
        null,
      ),
    ];

    for (final (event, metricId, properties) in coreCases) {
      test('$event -> core beta $metricId', () {
        final result = CoreMetricsMinimumSet.classify(
          event,
          properties: properties,
        );
        expect(result.isCoreBeta, isTrue);
        expect(result.diagnosticOnly, isFalse);
        expect(result.notReleaseBlocking, isFalse);
        expect(result.coreMetricId, metricId);
      });
    }

    test('recording_created save_index 2 -> second save', () {
      final result = CoreMetricsMinimumSet.classify(
        'recording_created',
        properties: {'save_index': 2},
      );
      expect(result.coreMetricId, CoreMetricsMinimumMetricId.secondSave);
      expect(result.isCoreBeta, isTrue);
    });
  });

  group('CoreMetricsMinimumSet.classify diagnostic only', () {
    final diagnosticEvents = [
      'thread_return_evidence_seen',
      'beta_feedback_intelligence_seen',
      'weekly_thread_review_seen',
      'archive_proof_counter_seen',
      'day_7_continuity_seen',
      'second_moment_return_seen',
      'beta_proof_feedback_seen',
    ];

    for (final event in diagnosticEvents) {
      test('$event -> diagnosticOnly', () {
        final result = CoreMetricsMinimumSet.classify(event);
        expect(result.isCoreBeta, isFalse);
        expect(result.diagnosticOnly, isTrue);
        expect(result.notReleaseBlocking, isTrue);
        expect(result.notUsedForPaidIntentDecision, isTrue);
        expect(result.coreMetricId, isNull);
      });
    }

    test('beta_proof_feedback_answered too_vague stays diagnostic', () {
      final result = CoreMetricsMinimumSet.classify(
        'beta_proof_feedback_answered',
        properties: {'feedback_type': 'too_vague'},
      );
      expect(result.diagnosticOnly, isTrue);
      expect(result.notUsedForPaidIntentDecision, isTrue);
    });

    test('beta_feedback_submitted useful stays diagnostic', () {
      final result = CoreMetricsMinimumSet.classify(
        'beta_feedback_submitted',
        properties: {'option_type': 'useful'},
      );
      expect(result.diagnosticOnly, isTrue);
    });

    test('beta_feedback_submitted wrong maps crash/blocker core metric', () {
      final result = CoreMetricsMinimumSet.classify(
        'beta_feedback_submitted',
        properties: {'option_type': 'wrong'},
      );
      expect(result.coreMetricId,
          CoreMetricsMinimumMetricId.crashOrBlockerReported);
      expect(result.notUsedForPaidIntentDecision, isTrue);
    });
  });

  group('CoreMetricsMinimumSet paid-intent flags', () {
    test('purchase_completed is used for paid-intent decisions', () {
      final result = CoreMetricsMinimumSet.classify('purchase_completed');
      expect(result.notUsedForPaidIntentDecision, isFalse);
    });

    test('app_opened is core but not used for paid-intent decisions', () {
      final result = CoreMetricsMinimumSet.classify('app_opened');
      expect(result.isCoreBeta, isTrue);
      expect(result.notUsedForPaidIntentDecision, isTrue);
    });

    test('entitlement_active is core but not used for paid-intent decisions', () {
      final result = CoreMetricsMinimumSet.classify('entitlement_active');
      expect(result.isCoreBeta, isTrue);
      expect(result.notUsedForPaidIntentDecision, isTrue);
    });
  });

  group('CoreMetricsMinimumSetCopy', () {
    test('headline says Core metrics minimum set', () {
      expect(
        CoreMetricsMinimumSetCopy.headline,
        'Core metrics minimum set',
      );
    });

    test('coreLine lists fourteen release-beta metrics', () {
      final lower = CoreMetricsMinimumSetCopy.coreLine.toLowerCase();
      expect(lower, contains('app opened'));
      expect(lower, contains('first save'));
      expect(lower, contains('second save'));
      expect(lower, contains('first useful proof seen'));
      expect(lower, contains('proof accepted'));
      expect(lower, contains('proof corrected'));
      expect(lower, contains('pro promise seen'));
      expect(lower, contains('pro tapped'));
      expect(lower, contains('purchase started'));
      expect(lower, contains('purchase completed'));
      expect(lower, contains('restore tapped'));
      expect(lower, contains('restore succeeded'));
      expect(lower, contains('entitlement active'));
      expect(lower, contains('crash or blocker reported'));
    });

    test('guardrail says do not delete analytics', () {
      expect(
        CoreMetricsMinimumSetCopy.guardrail.toLowerCase(),
        contains('do not delete analytics'),
      );
      expect(
        CoreMetricsMinimumSetCopy.guardrail.toLowerCase(),
        contains('change emission'),
      );
    });

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in CoreMetricsMinimumSetCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });
  });

  group('Protected areas', () {
    test('module does not import billing or purchases_flutter', () {
      for (final path in [
        'lib/features/core_metrics_minimum/core_metrics_minimum_set.dart',
        'lib/features/core_metrics_minimum/core_metrics_minimum_set_copy.dart',
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

    test('freeze drift scanner still blocks new feature surface', () {
      expect(
        FreezeDriftScanner.scan(
          const FreezeDriftScannerInput(
            freezeActive: true,
            category: FreezeDriftCategory.newFeatureSurface,
          ),
        ).freezeAllowed,
        isFalse,
      );
    });

    test('paid intent beta proof still reaches promising on purchase', () {
      final result = PaidIntentBetaProof.build(
        PaidIntentBetaProof.fromAttribution(
          firstSaveCompleted: true,
          firstUsefulProofSeen: true,
          proofAcceptedOrCorrected: true,
          proPromiseSeen: true,
          proTapped: true,
          purchaseAttempted: true,
          purchaseCompleted: true,
        ),
      );
      expect(result.decision, PaidIntentBetaProofDecision.paidIntentPromising);
    });

    test('release blocker priority still validates paid intent when weak', () {
      expect(
        ReleaseBlockerPriority.build(
          const ReleaseBlockerPriorityInput(
            freezeActive: true,
            hasSecuritySecretsBlocker: false,
            hasCrash: false,
            blocksStoreReadiness: false,
            risksAppStoreRejection: false,
            blocksPurchase: false,
            blocksRestore: false,
            blocksEntitlement: false,
            firstJourneyComprehensionWeak: false,
            criticalProofTrustWeak: false,
            paidIntentSignalWeak: true,
          ),
        ).decision,
        ReleaseBlockerPriorityDecision.validatePaidIntentFirst,
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
  });
}
