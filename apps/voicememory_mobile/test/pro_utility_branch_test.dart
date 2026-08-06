import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/beta_decision/beta_decision_model.dart';
import 'package:voicememory_mobile/features/beta_improvement/beta_improvement_model.dart';
import 'package:voicememory_mobile/features/beta_improvement/beta_improvement_pack_engine.dart';
import 'package:voicememory_mobile/features/beta_improvement/beta_improvement_recommendation_gate.dart';
import 'package:voicememory_mobile/features/beta_improvement/pro_utility_branch_engine.dart';
import 'package:voicememory_mobile/features/beta_improvement/pro_utility_copy_fix.dart';
import 'package:voicememory_mobile/features/pro_bridge_visibility/pro_bridge_visibility_engine.dart';
import 'package:voicememory_mobile/features/pro_bridge_visibility/pro_bridge_visibility_model.dart';
import 'package:voicememory_mobile/features/proof_quality_response/proof_quality_response_model.dart';
import 'package:voicememory_mobile/features/v1_interface/v1_expansion_gate_copy.dart';

BetaTesterOutcome _outcome(Set<BetaDecisionSignal> signals) =>
    BetaTesterOutcome(testerId: 't1', signals: signals);

List<BetaTesterOutcome> _proUtilityOutcomes() => [
  _outcome({
    BetaDecisionSignal.understoodPromise,
    BetaDecisionSignal.savedFirstMoment,
    BetaDecisionSignal.returnedDay2,
    BetaDecisionSignal.reachedThreeMoments,
    BetaDecisionSignal.proofFeltMeaningful,
    BetaDecisionSignal.willingToPayForLongerTrail,
    BetaDecisionSignal.askedForExport,
  }),
  _outcome({
    BetaDecisionSignal.understoodPromise,
    BetaDecisionSignal.savedFirstMoment,
    BetaDecisionSignal.returnedDay2,
    BetaDecisionSignal.reachedThreeMoments,
    BetaDecisionSignal.proofFeltMeaningful,
    BetaDecisionSignal.willingToPayForLongerTrail,
    BetaDecisionSignal.askedForHistory,
  }),
  _outcome({
    BetaDecisionSignal.understoodPromise,
    BetaDecisionSignal.savedFirstMoment,
    BetaDecisionSignal.returnedDay2,
    BetaDecisionSignal.reachedThreeMoments,
    BetaDecisionSignal.proofFeltMeaningful,
    BetaDecisionSignal.willingToPayForLongerTrail,
    BetaDecisionSignal.askedForReport,
  }),
];

ProBridgeVisibilityInput _bridgeInput({
  required int entryCount,
  required bool hasTimelineProof,
}) => ProBridgeVisibilityInput(
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
  final utilityOutcomes = _proUtilityOutcomes();

  group('Pro utility copy', () {
    test('says keep more of the trail with utility rows', () {
      expect(ProUtilityCopyFix.headline, 'Keep more of the trail.');
      expect(
        ProUtilityCopyFix.subheadline.toLowerCase(),
        contains('older evidence'),
      );
      expect(ProUtilityCopyFix.historyTitle, 'Older proof history');
      expect(
        ProUtilityCopyFix.historyBody.toLowerCase(),
        contains('repeat changed'),
      );
      expect(ProUtilityCopyFix.exportTitle, 'Export your archive');
      expect(
        ProUtilityCopyFix.exportBody.toLowerCase(),
        contains('saved moments'),
      );
      expect(ProUtilityCopyFix.privateReportTitle, 'Private report preview');
      expect(
        ProUtilityCopyFix.privateReportBody.toLowerCase(),
        contains('what returned'),
      );
    });

    test('explicitly avoids more AI positioning', () {
      expect(
        ProUtilityCopyFix.notMoreAiLine.toLowerCase(),
        contains('not more ai'),
      );
      expect(
        ProUtilityCopyFix.notMoreAiLine.toLowerCase(),
        contains('your own evidence'),
      );
    });

    test('has no banned therapy/diagnosis/coaching language', () {
      final blob = ProUtilityCopyFix.allVisibleStrings()
          .join(' ')
          .toLowerCase();
      for (final banned in ProUtilityCopyFix.bannedWords) {
        if (banned == 'more ai') continue;
        expect(blob, isNot(contains(banned)), reason: banned);
      }
      for (final line in ProUtilityCopyFix.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
    });

    test('does not mention blocked expansion surfaces', () {
      final blob = ProUtilityCopyFix.allVisibleStrings()
          .join(' ')
          .toLowerCase();
      expect(blob, isNot(contains('ask archive')));
      expect(blob, isNot(contains('loop packs')));
      expect(blob, isNot(contains('annual plan')));
      expect(blob, isNot(contains('b2b')));
    });
  });

  group('ProUtilityBranchEngine', () {
    test('activates when expansion gate and utility ask are met', () {
      expect(
        BetaImprovementRecommendationGate.activeBranch(
          outcomesOverride: utilityOutcomes,
        ),
        BetaImprovementBranch.proUtility,
      );
    });

    test('is hidden on empty first-run', () {
      expect(
        ProUtilityBranchEngine.shouldShowUtility(
          entryCount: 0,
          hasMeaningfulProof: false,
          outcomesOverride: utilityOutcomes,
        ),
        isFalse,
      );
      expect(
        ProUtilityBranchEngine.build(
          entryCount: 0,
          hasMeaningfulProof: false,
          outcomesOverride: utilityOutcomes,
        ).shouldShowSection,
        isFalse,
      );
    });

    test('requires meaningful proof or explicit utility ask', () {
      expect(
        ProUtilityBranchEngine.shouldShowUtility(
          entryCount: 3,
          hasMeaningfulProof: false,
          outcomesOverride: const [],
        ),
        isFalse,
      );
      expect(
        ProUtilityBranchEngine.shouldShowUtility(
          entryCount: 3,
          hasMeaningfulProof: true,
          outcomesOverride: utilityOutcomes,
        ),
        isTrue,
      );
    });

    test('export link is live only when export surface config allows', () {
      final live = ProUtilityBranchEngine.build(
        entryCount: 3,
        hasMeaningfulProof: true,
        outcomesOverride: utilityOutcomes,
        config: const ProUtilityBranchConfig(exportSurfaceLive: true),
      );
      expect(live.exportLinkLive, isTrue);
      final rows = ProUtilityBranchEngine.utilityRows(
        entryCount: 3,
        hasMeaningfulProof: true,
        outcomesOverride: utilityOutcomes,
        config: const ProUtilityBranchConfig(exportSurfaceLive: true),
      );
      final exportRow = rows.firstWhere((row) => row.title.contains('Export'));
      expect(exportRow.route, ProUtilityBranchEngine.exportRoute);

      final preview = ProUtilityBranchEngine.build(
        entryCount: 3,
        hasMeaningfulProof: true,
        outcomesOverride: utilityOutcomes,
        config: const ProUtilityBranchConfig(exportSurfaceLive: false),
      );
      expect(preview.exportLinkLive, isFalse);
      final previewRows = ProUtilityBranchEngine.utilityRows(
        entryCount: 3,
        hasMeaningfulProof: true,
        outcomesOverride: utilityOutcomes,
        config: const ProUtilityBranchConfig(exportSurfaceLive: false),
      );
      final previewExport = previewRows.firstWhere(
        (row) => row.title.contains('Export'),
      );
      expect(previewExport.route, isNull);
      expect(previewExport.body, ProUtilityCopyFix.exportPlannedBody);
    });

    test('private report remains preview unless config enables live', () {
      final model = ProUtilityBranchEngine.build(
        entryCount: 3,
        hasMeaningfulProof: true,
        outcomesOverride: utilityOutcomes,
      );
      expect(model.privateReportLive, isFalse);
      expect(model.isPreviewOnly, isTrue);

      final rows = ProUtilityBranchEngine.utilityRows(
        entryCount: 3,
        hasMeaningfulProof: true,
        outcomesOverride: utilityOutcomes,
      );
      final reportRow = rows.firstWhere(
        (row) => row.title.contains('Private report'),
      );
      expect(reportRow.previewOnly, isTrue);
      expect(reportRow.route, isNull);
      expect(reportRow.body, contains(ProUtilityCopyFix.plannedSuffix));
    });

    test('bridge copy appears after meaningful proof', () {
      expect(
        ProUtilityBranchEngine.bridgeTitle(
          entryCount: 3,
          hasMeaningfulProof: true,
          outcomesOverride: utilityOutcomes,
        ),
        ProUtilityCopyFix.headline,
      );
      expect(
        ProUtilityBranchEngine.firstProofBridgeLines(
          entryCount: 3,
          hasMeaningfulProof: true,
          outcomesOverride: utilityOutcomes,
        ),
        hasLength(2),
      );
    });
  });

  group('Pack engine integration', () {
    test('exposes utility rows and bridge when branch active', () {
      expect(
        BetaImprovementPackEngine.proUtilityRows(
          entryCount: 3,
          hasMeaningfulProof: true,
          outcomesOverride: utilityOutcomes,
        ),
        isNotNull,
      );
      expect(
        BetaImprovementPackEngine.firstProofProBridgeLines(
          entryCount: 3,
          hasMeaningfulProof: true,
          outcomesOverride: utilityOutcomes,
        ),
        contains(ProUtilityCopyFix.proofBridge),
      );
    });
  });

  group('V1 guardrails', () {
    test('expansion gates doc still blocks utility expansion drift', () {
      final doc = File(
        V1ExpansionGateCopy.expansionGatesDocPath,
      ).readAsStringSync();
      expect(doc.toLowerCase(), contains('ask your archive'));
      expect(doc.toLowerCase(), contains('loop packs'));
    });
  });
}
