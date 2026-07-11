import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/freeze_drift_scanner/freeze_drift_scanner.dart';
import 'package:voicememory_mobile/features/paid_intent/paid_intent_confirmation_models.dart';
import 'package:voicememory_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof.dart';
import 'package:voicememory_mobile/features/paid_intent_beta_proof/paid_intent_beta_proof_copy.dart';
import 'package:voicememory_mobile/features/pro_single_promise/pro_single_promise.dart';
import 'package:voicememory_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:voicememory_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:voicememory_mobile/features/release_blocker_priority/release_blocker_priority.dart';
import 'package:voicememory_mobile/features/release_candidate_freeze/release_candidate_freeze.dart';
import 'package:voicememory_mobile/features/revenuecat_sandbox_proof/revenuecat_sandbox_proof.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';

const _docsPath = 'docs/paid_intent_beta_script.md';

PaidIntentBetaProofInput _input({
  bool firstSaveCompleted = true,
  bool firstUsefulProofSeen = true,
  bool proofAcceptedOrCorrected = true,
  bool proPromiseSeen = true,
  bool proTapped = true,
  bool purchaseAttempted = false,
  bool purchaseCompleted = false,
  bool restoreAttempted = false,
  bool purchaseMechanicsBlocked = false,
  PaidIntentBetaWouldPay? testerWouldPay,
}) =>
    PaidIntentBetaProofInput(
      firstSaveCompleted: firstSaveCompleted,
      firstUsefulProofSeen: firstUsefulProofSeen,
      proofAcceptedOrCorrected: proofAcceptedOrCorrected,
      proPromiseSeen: proPromiseSeen,
      proTapped: proTapped,
      purchaseAttempted: purchaseAttempted,
      purchaseCompleted: purchaseCompleted,
      restoreAttempted: restoreAttempted,
      purchaseMechanicsBlocked: purchaseMechanicsBlocked,
      testerWouldPay: testerWouldPay,
    );

PaidIntentBetaProofSignal _signal(
  PaidIntentBetaProofResult result,
  PaidIntentBetaProofSignalId id,
) =>
    result.signals.firstWhere((signal) => signal.id == id);

void main() {
  group('PaidIntentBetaProof.build', () {
    test('no signals -> insufficientData', () {
      final result = PaidIntentBetaProof.build(const PaidIntentBetaProofInput());
      expect(result.decision, PaidIntentBetaProofDecision.insufficientData);
      expect(result.paidIntentSignalWeak, isTrue);
      expect(
        result.earliestGap,
        PaidIntentBetaProofSignalId.firstSaveCompleted,
      );
    });

    test('first save only -> proofNotReached', () {
      final result = PaidIntentBetaProof.build(
        _input(
          firstUsefulProofSeen: false,
          proofAcceptedOrCorrected: false,
          proPromiseSeen: false,
          proTapped: false,
        ),
      );
      expect(result.decision, PaidIntentBetaProofDecision.proofNotReached);
      expect(
        _signal(result, PaidIntentBetaProofSignalId.firstUsefulProofSeen)
            .status,
        PaidIntentBetaProofSignalStatus.fail,
      );
    });

    test('proof seen but not accepted -> proofNotUseful', () {
      final result = PaidIntentBetaProof.build(
        _input(
          proofAcceptedOrCorrected: false,
          proPromiseSeen: false,
          proTapped: false,
        ),
      );
      expect(result.decision, PaidIntentBetaProofDecision.proofNotUseful);
      expect(
        _signal(result, PaidIntentBetaProofSignalId.proofAcceptedOrCorrected)
            .status,
        PaidIntentBetaProofSignalStatus.fail,
      );
    });

    test('proof accepted but Pro not seen -> proNotSeen', () {
      final result = PaidIntentBetaProof.build(
        _input(proPromiseSeen: false, proTapped: false),
      );
      expect(result.decision, PaidIntentBetaProofDecision.proNotSeen);
    });

    test('Pro seen but not tapped -> proNotTapped', () {
      final result = PaidIntentBetaProof.build(_input(proTapped: false));
      expect(result.decision, PaidIntentBetaProofDecision.proNotTapped);
    });

    test('purchase attempted but mechanics blocked -> purchaseBlocked', () {
      final result = PaidIntentBetaProof.build(
        _input(
          purchaseAttempted: true,
          purchaseMechanicsBlocked: true,
        ),
      );
      expect(result.decision, PaidIntentBetaProofDecision.purchaseBlocked);
    });

    test('purchase attempted and abandoned -> paidIntentWeak', () {
      final result = PaidIntentBetaProof.build(
        _input(purchaseAttempted: true),
      );
      expect(result.decision, PaidIntentBetaProofDecision.paidIntentWeak);
    });

    test('tester says no -> paidIntentWeak', () {
      final result = PaidIntentBetaProof.build(
        _input(testerWouldPay: PaidIntentBetaWouldPay.no),
      );
      expect(result.decision, PaidIntentBetaProofDecision.paidIntentWeak);
      expect(result.paidIntentSignalPromising, isFalse);
    });

    test('tester says yes -> paidIntentPromising', () {
      final result = PaidIntentBetaProof.build(
        _input(testerWouldPay: PaidIntentBetaWouldPay.yes),
      );
      expect(result.decision, PaidIntentBetaProofDecision.paidIntentPromising);
      expect(result.paidIntentSignalWeak, isFalse);
    });

    test('tester says maybe -> paidIntentPromising', () {
      final result = PaidIntentBetaProof.build(
        _input(testerWouldPay: PaidIntentBetaWouldPay.maybe),
      );
      expect(result.decision, PaidIntentBetaProofDecision.paidIntentPromising);
    });

    test('purchase completed -> paidIntentPromising', () {
      final result = PaidIntentBetaProof.build(
        _input(
          purchaseAttempted: true,
          purchaseCompleted: true,
        ),
      );
      expect(result.decision, PaidIntentBetaProofDecision.paidIntentPromising);
    });

    test('pro tapped with no would-pay answer -> insufficientData', () {
      final result = PaidIntentBetaProof.build(_input());
      expect(result.decision, PaidIntentBetaProofDecision.insufficientData);
      expect(
        result.earliestGap,
        PaidIntentBetaProofSignalId.testerWouldPay,
      );
    });

    test('restore attempted is tracked but not required', () {
      final result = PaidIntentBetaProof.build(
        _input(
          restoreAttempted: true,
          testerWouldPay: PaidIntentBetaWouldPay.yes,
        ),
      );
      expect(
        _signal(result, PaidIntentBetaProofSignalId.restoreAttempted).status,
        PaidIntentBetaProofSignalStatus.pass,
      );
    });
  });

  group('PaidIntentBetaProof factories', () {
    test('fromWouldPayResponseId maps yes/maybe/no/notYet', () {
      expect(
        PaidIntentBetaProof.fromWouldPayResponseId(
          PaidIntentConfirmationResponseIds.yes999,
        ).testerWouldPay,
        PaidIntentBetaWouldPay.yes,
      );
      expect(
        PaidIntentBetaProof.fromWouldPayResponseId(
          PaidIntentConfirmationResponseIds.maybe,
        ).testerWouldPay,
        PaidIntentBetaWouldPay.maybe,
      );
      expect(
        PaidIntentBetaProof.fromWouldPayResponseId(
          PaidIntentConfirmationResponseIds.no,
        ).testerWouldPay,
        PaidIntentBetaWouldPay.no,
      );
      expect(
        PaidIntentBetaProof.fromWouldPayResponseId(
          PaidIntentConfirmationResponseIds.notYet,
        ).testerWouldPay,
        PaidIntentBetaWouldPay.notYet,
      );
    });

    test('fromAttribution builds full funnel input', () {
      final input = PaidIntentBetaProof.fromAttribution(
        firstSaveCompleted: true,
        firstUsefulProofSeen: true,
        proofAcceptedOrCorrected: true,
        proPromiseSeen: true,
        proTapped: true,
        purchaseAttempted: true,
        purchaseCompleted: true,
        restoreAttempted: true,
        testerWouldPay: PaidIntentBetaWouldPay.yes,
      );
      final result = PaidIntentBetaProof.build(input);
      expect(result.decision, PaidIntentBetaProofDecision.paidIntentPromising);
    });

    test('isPaidIntentSignalWeak matches decision table', () {
      expect(
        PaidIntentBetaProof.isPaidIntentSignalWeak(
          PaidIntentBetaProofDecision.paidIntentPromising,
        ),
        isFalse,
      );
      expect(
        PaidIntentBetaProof.isPaidIntentSignalWeak(
          PaidIntentBetaProofDecision.proNotTapped,
        ),
        isTrue,
      );
    });
  });

  group('PaidIntentBetaProofCopy', () {
    test('headline says Paid intent beta proof', () {
      expect(PaidIntentBetaProofCopy.headline, 'Paid intent beta proof');
    });

    test('trackedLine lists all nine signals', () {
      final lower = PaidIntentBetaProofCopy.trackedLine.toLowerCase();
      expect(lower, contains('first save'));
      expect(lower, contains('first useful proof'));
      expect(lower, contains('proof accepted'));
      expect(lower, contains('pro promise seen'));
      expect(lower, contains('pro tapped'));
      expect(lower, contains('purchase attempted'));
      expect(lower, contains('purchase completed'));
      expect(lower, contains('restore attempted'));
      expect(lower, contains('would-pay'));
    });

    test('guardrail says no new product surfaces', () {
      expect(
        PaidIntentBetaProofCopy.guardrail.toLowerCase(),
        contains('do not add product surfaces'),
      );
      expect(
        PaidIntentBetaProofCopy.guardrail.toLowerCase(),
        contains('pricing experiments'),
      );
      expect(
        PaidIntentBetaProofCopy.guardrail.toLowerCase(),
        contains('new pro benefits'),
      );
    });

    test('copy avoids therapy diagnosis coaching and advice claims', () {
      for (final text in PaidIntentBetaProofCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
      }
    });
  });

  group('Protected areas', () {
    test('docs file exists with tester script', () {
      expect(File(_docsPath).existsSync(), isTrue);
      final docs = File(_docsPath).readAsStringSync().toLowerCase();
      expect(docs, contains('first useful proof'));
      expect(docs, contains('would pay'));
      expect(docs, contains('do not add new product surfaces'));
    });

    test('module does not import billing or purchases_flutter', () {
      for (final path in [
        'lib/features/paid_intent_beta_proof/paid_intent_beta_proof.dart',
        'lib/features/paid_intent_beta_proof/paid_intent_beta_proof_copy.dart',
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
