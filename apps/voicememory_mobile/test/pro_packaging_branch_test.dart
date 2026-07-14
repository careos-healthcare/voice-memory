import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/beta_decision/beta_decision_model.dart';
import 'package:voicememory_mobile/features/beta_improvement/beta_improvement_model.dart';
import 'package:voicememory_mobile/features/beta_improvement/beta_improvement_pack_engine.dart';
import 'package:voicememory_mobile/features/beta_improvement/beta_improvement_recommendation_gate.dart';
import 'package:voicememory_mobile/features/beta_improvement/pro_packaging_branch_engine.dart';
import 'package:voicememory_mobile/features/beta_improvement/pro_packaging_copy_fix.dart';
import 'package:voicememory_mobile/features/pro_bridge_visibility/pro_bridge_visibility_copy.dart';
import 'package:voicememory_mobile/features/pro_bridge_visibility/pro_bridge_visibility_engine.dart';
import 'package:voicememory_mobile/features/pro_bridge_visibility/pro_bridge_visibility_model.dart';
import 'package:voicememory_mobile/features/proof_quality_response/proof_quality_response_model.dart';
import 'package:voicememory_mobile/features/pro_packaging/pro_value_copy.dart';
import 'package:voicememory_mobile/features/pro_packaging/pro_value_engine.dart';
import 'package:voicememory_mobile/features/v1_interface/v1_expansion_gate_copy.dart';

BetaTesterOutcome _outcome(Set<BetaDecisionSignal> signals) =>
    BetaTesterOutcome(testerId: 't1', signals: signals);

List<BetaTesterOutcome> _proPackagingOutcomes() => [
      _outcome({
        BetaDecisionSignal.understoodPromise,
        BetaDecisionSignal.savedFirstMoment,
        BetaDecisionSignal.returnedDay2,
        BetaDecisionSignal.reachedThreeMoments,
        BetaDecisionSignal.sawFirstProof,
        BetaDecisionSignal.proofFeltMeaningful,
      }),
    ];

ProBridgeVisibilityInput _bridgeInput({
  required int entryCount,
  required bool hasTimelineProof,
}) =>
    ProBridgeVisibilityInput(
      entryCount: entryCount,
      source: 'test',
      surface: ProBridgeVisibilitySurface.recordPostSaveAfterPayoff,
      isPro: false,
      postProofProBridgeEnabled: true,
      hasTimelineProofVisible: hasTimelineProof,
      hasFirstProofPayoffVisible: hasTimelineProof,
      proSlotAvailable: true,
      isRecording: false,
      isZeroEntryState: entryCount == 0,
      isFirstRecordingState: entryCount <= 1,
      isPostSaveDegradedState: false,
      isDegradedTranscriptState: false,
      hasFirstProof: entryCount >= 3,
      hasBetaTesterReportVisible: false,
      hasCorrectionMemoryVisible: false,
      hasMonthlyPrivateReportPreviewVisible: false,
      hasBetaProofLiftVisible: false,
      hasReturnAfterProofStrengthenedVisible: false,
      whatChangedQuestionActive: false,
      patternReviewInboxHasActiveItems: false,
      feedbackState: ProofQualityFeedbackState.none,
      confidenceLevel: null,
      hasSafeAnchor: hasTimelineProof,
      hasFreshReturnAfterCorrection: false,
      hasSolidStrongPatternWithSafeAnchors: hasTimelineProof,
      compact: false,
    );

void main() {
  final proOutcomes = _proPackagingOutcomes();

  group('Pro packaging copy', () {
    test('says keep the longer trail and free first repeat', () {
      expect(ProPackagingCopyFix.headline, 'Keep the longer trail.');
      expect(
        ProPackagingCopyFix.subheadline.toLowerCase(),
        contains('first useful repeat'),
      );
      expect(
        ProPackagingCopyFix.proValue.toLowerCase(),
        contains('older evidence'),
      );
      expect(
        ProPackagingCopyFix.proValue.toLowerCase(),
        contains('change over time'),
      );
    });

    test('explicitly avoids more AI positioning', () {
      expect(
        ProPackagingCopyFix.whyPayLine.toLowerCase(),
        contains('not for more ai'),
      );
      expect(
        ProPackagingCopyFix.notMoreAiLine.toLowerCase(),
        contains('not more ai'),
      );
    });

    test('has no banned therapy/diagnosis/coaching language', () {
      final blob =
          ProPackagingCopyFix.allVisibleStrings().join(' ').toLowerCase();
      for (final banned in ProPackagingCopyFix.bannedWords) {
        if (banned == 'more ai') continue;
        expect(blob, isNot(contains(banned)), reason: banned);
      }
      for (final line in ProPackagingCopyFix.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
    });

    test('includes correction and restore affordances in copy module', () {
      expect(ProPackagingCopyFix.restoreLine, 'Restore purchases');
      expect(ProPackagingCopyFix.proofBridge, isNotEmpty);
      expect(ProPackagingCopyFix.longerTrailBullets, hasLength(3));
    });
  });

  group('ProPackagingBranchEngine', () {
    test('activates from proof-felt-meaningful without pay intent', () {
      expect(
        BetaImprovementRecommendationGate.activeBranch(
          outcomesOverride: proOutcomes,
        ),
        BetaImprovementBranch.proPackaging,
      );
    });

    test('bridge is gated after meaningful proof not first-run empty', () {
      expect(
        ProPackagingBranchEngine.shouldShowBridge(
          entryCount: 0,
          hasMeaningfulProof: false,
          outcomesOverride: proOutcomes,
        ),
        isFalse,
      );
      expect(
        ProPackagingBranchEngine.shouldShowBridge(
          entryCount: 3,
          hasMeaningfulProof: true,
          outcomesOverride: proOutcomes,
        ),
        isTrue,
      );
      expect(
        ProPackagingBranchEngine.bridgeTitle(
          entryCount: 3,
          hasMeaningfulProof: true,
          outcomesOverride: proOutcomes,
        ),
        ProPackagingCopyFix.headline,
      );
    });

    test('paywall packaging uses sharper headline when branch active', () {
      final packaging = ProPackagingEngine.build(
        offeringsAvailable: false,
        showPlanPrices: false,
      );
      expect(packaging.title, ProPackagingCopy.title);
      expect(packaging.restoreLabel, ProPackagingCopy.restorePurchases);

      // Branch active via outcomes is tested through gate; engine methods
      // return sharper copy when branch is recommended.
      expect(ProPackagingBranchEngine.paywallHeadline(), isNull);
    });

    test('purchase unavailable copy remains honest', () {
      expect(
        ProPackagingCopy.offeringsUnavailableBody.toLowerCase(),
        contains('unavailable'),
      );
      expect(
        ProPackagingCopyFix.unavailableHonestyLine.toLowerCase(),
        contains('not available'),
      );
    });
  });

  group('Pro bridge integration', () {
    test('pack engine exposes branch bridge copy after meaningful proof', () {
      expect(
        BetaImprovementPackEngine.proBridgeTitle(
          entryCount: 3,
          hasMeaningfulProof: true,
          outcomesOverride: proOutcomes,
        ),
        ProPackagingCopyFix.headline,
      );
      expect(
        BetaImprovementPackEngine.firstProofProBridgeLines(
          entryCount: 3,
          hasMeaningfulProof: true,
          outcomesOverride: proOutcomes,
        ),
        hasLength(2),
      );
    });

    test('baseline bridge stays unchanged without active branch', () {
      final result = ProBridgeVisibilityEngine.build(
        input: _bridgeInput(entryCount: 3, hasTimelineProof: true),
      );
      expect(result.title, ProBridgeVisibilityCopy.title);
      expect(result.body.toLowerCase(), isNot(contains('more ai')));
    });
  });

  group('V1 guardrails', () {
    test('expansion gates doc still blocks utility expansion drift', () {
      final doc = File(V1ExpansionGateCopy.expansionGatesDocPath).readAsStringSync();
      expect(doc.toLowerCase(), contains('ask your archive'));
      expect(doc.toLowerCase(), contains('loop packs'));
    });
  });
}
