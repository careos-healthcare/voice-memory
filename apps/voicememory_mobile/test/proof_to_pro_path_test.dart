import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/beta_decision/beta_decision_model.dart';
import 'package:voicememory_mobile/features/beta_improvement/beta_improvement_model.dart';
import 'package:voicememory_mobile/features/beta_improvement/beta_improvement_pack_engine.dart';
import 'package:voicememory_mobile/features/beta_improvement/beta_improvement_recommendation_gate.dart';
import 'package:voicememory_mobile/features/beta_improvement/pro_packaging_branch_engine.dart';
import 'package:voicememory_mobile/features/beta_improvement/pro_packaging_copy_fix.dart';
import 'package:voicememory_mobile/features/beta_improvement/proof_emotional_clarity_copy_fix.dart';
import 'package:voicememory_mobile/features/beta_improvement/proof_emotional_clarity_engine.dart';
import 'package:voicememory_mobile/features/beta_improvement/proof_to_pro_path_engine.dart';
import 'package:voicememory_mobile/features/pro_bridge_visibility/pro_bridge_visibility_engine.dart';
import 'package:voicememory_mobile/features/pro_bridge_visibility/pro_bridge_visibility_model.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:voicememory_mobile/features/proof_quality_response/proof_quality_response_model.dart';
import 'package:voicememory_mobile/features/v1_interface/v1_expansion_gate_copy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

BetaTesterOutcome _outcome(Set<BetaDecisionSignal> signals) =>
    BetaTesterOutcome(testerId: 't1', signals: signals);

List<BetaTesterOutcome> _proofClarityOutcomes() => [
  _outcome({
    BetaDecisionSignal.understoodPromise,
    BetaDecisionSignal.savedFirstMoment,
    BetaDecisionSignal.returnedDay2,
    BetaDecisionSignal.reachedThreeMoments,
    BetaDecisionSignal.sawFirstProof,
  }),
];

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

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
  transcript: transcript,
  durationSeconds: 30,
  reflection: const Reflection(
    mood: 'thoughtful',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up again today.',
    repeatedSignal: '',
  ),
);

List<JournalEntry> _threeRelatedEntries() => [
  _entry(
    id: 'e1',
    transcript:
        'I had no capacity but I said yes again to the extra meeting today.',
    createdAt: DateTime(2026, 6, 10, 12),
  ),
  _entry(
    id: 'e2',
    transcript:
        'Same thing — said yes when I had no capacity for one more thing.',
    createdAt: DateTime(2026, 6, 11, 12),
  ),
  _entry(
    id: 'e3',
    transcript:
        'I said yes again even though I had no capacity for one more ask.',
    createdAt: DateTime(2026, 6, 12, 12),
  ),
];

ProofConfidenceCalibrationResult _strongCalibration({
  required int entryCount,
}) => ProofConfidenceCalibrationResult(
  shouldCalibrate: true,
  entryCount: entryCount,
  source: 'test',
  level: ProofConfidenceLevel.strong,
  primaryCopy: 'This has a clearer timeline now.',
  displayCopy: 'This has a clearer timeline now.',
  hasSafeAnchor: true,
  hasMatchQuality: true,
  hasCorrection: false,
  hasFreshReturn: false,
);

ProBridgeVisibilityInput _bridgeInput({
  required int entryCount,
  required bool hasTimelineProof,
  bool firstProofPayoffVisible = false,
}) => ProBridgeVisibilityInput(
  entryCount: entryCount,
  source: 'test',
  surface: ProBridgeVisibilitySurface.recordPostSaveAfterPayoff,
  isPro: false,
  postProofProBridgeEnabled: true,
  hasTimelineProofVisible: hasTimelineProof,
  hasFirstProofPayoffVisible: firstProofPayoffVisible,
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
  final clarityOutcomes = _proofClarityOutcomes();
  final packagingOutcomes = _proPackagingOutcomes();
  final entries = _threeRelatedEntries();
  final calibration = _strongCalibration(entryCount: entries.length);

  group('Proof-to-Pro path copy', () {
    test('includes proof clarity and quiet Pro bridge lines', () {
      expect(ProofEmotionalClarityCopyFix.headline, 'This came back.');
      expect(
        ProofEmotionalClarityCopyFix.whyItMightMatterLabel.toLowerCase(),
        contains('why this might matter'),
      );
      expect(
        ProPackagingCopyFix.proofBridge,
        'This is the kind of trail Pro keeps building.',
      );
      expect(
        ProPackagingCopyFix.freeLine,
        'Free helps you see the first useful repeat.',
      );
      expect(ProPackagingCopyFix.proPromise, 'Pro keeps the longer trail.');
    });

    test('has no banned therapy/diagnosis/coaching language', () {
      final blob = [
        ...ProofEmotionalClarityCopyFix.allVisibleStrings(),
        ...ProPackagingCopyFix.allVisibleStrings(),
      ].join(' ').toLowerCase();
      const banned = [
        'therapy',
        'diagnosis',
        'treatment',
        'trauma',
        'healing',
        'mental health',
        'ai coach',
        'chatbot',
        'breakthrough',
        'better answers',
        'unlimited coaching',
      ];
      for (final word in banned) {
        expect(blob, isNot(contains(word)), reason: word);
      }
      expect(blob, isNot(contains('ask archive')));
      expect(blob, isNot(contains('loop packs')));
    });
  });

  group('ProofToProPathEngine sequencing', () {
    test(
      'proof clarity is shown before Pro packaging on proPackaging branch',
      () {
        expect(
          BetaImprovementRecommendationGate.activeBranch(
            outcomesOverride: packagingOutcomes,
          ),
          BetaImprovementBranch.proPackaging,
        );

        final path = ProofToProPathEngine.build(
          entryCount: 3,
          hasMeaningfulProof: true,
          outcomesOverride: packagingOutcomes,
        );
        expect(path.showProofEmotionalClarity, isTrue);
        expect(path.showProPackagingBridge, isTrue);
        expect(path.showProPackagingBridge, isTrue);

        final clarity = ProofEmotionalClarityEngine.build(
          entries: entries,
          calibration: calibration,
          hasStrongEvidence: true,
          outcomesOverride: packagingOutcomes,
        );
        expect(clarity, isNotNull);
        expect(clarity!.headline, 'This came back.');

        final bridgeLines = ProPackagingBranchEngine.firstProofBridgeLines(
          entryCount: 3,
          hasMeaningfulProof: true,
          outcomesOverride: packagingOutcomes,
        );
        expect(bridgeLines.first, ProPackagingCopyFix.proofBridge);
        expect(bridgeLines.last, contains('first useful repeat'));
      },
    );

    test('proof clarity only when proofEmotionalClarity branch is active', () {
      expect(
        BetaImprovementRecommendationGate.activeBranch(
          outcomesOverride: clarityOutcomes,
        ),
        BetaImprovementBranch.proofEmotionalClarity,
      );

      final path = ProofToProPathEngine.build(
        entryCount: 3,
        hasMeaningfulProof: true,
        outcomesOverride: clarityOutcomes,
      );
      expect(path.showProofEmotionalClarity, isTrue);
      expect(path.showProPackagingBridge, isFalse);
      expect(
        ProPackagingBranchEngine.shouldShowBridge(
          entryCount: 3,
          hasMeaningfulProof: true,
          outcomesOverride: clarityOutcomes,
        ),
        isFalse,
      );
    });

    test('Pro packaging is not shown on empty first-run', () {
      final path = ProofToProPathEngine.build(
        entryCount: 0,
        hasMeaningfulProof: false,
        outcomesOverride: packagingOutcomes,
      );
      expect(path.showProofEmotionalClarity, isFalse);
      expect(path.showProPackagingBridge, isFalse);
      expect(
        ProPackagingBranchEngine.shouldShowBridge(
          entryCount: 0,
          hasMeaningfulProof: false,
          outcomesOverride: packagingOutcomes,
        ),
        isFalse,
      );
    });

    test('Pro packaging is not shown before meaningful proof', () {
      final path = ProofToProPathEngine.build(
        entryCount: 2,
        hasMeaningfulProof: false,
        outcomesOverride: packagingOutcomes,
      );
      expect(path.showProPackagingBridge, isFalse);
    });

    test('proofToPro override alias is documented for manual testing', () {
      expect(ProofToProPathEngine.proofToProOverride, 'proofToPro');
      expect(
        BetaImprovementRecommendationGate.buildDefineKey,
        'ARCHIVEME_BETA_IMPROVEMENT_BRANCH',
      );
      expect(ProofToProPathEngine.isProofToProOverride(), isFalse);
    });

    test(
      'suppresses standalone Pro bridge when proof card carries inline bridge',
      () {
        final path = ProofToProPathEngine.build(
          entryCount: 3,
          hasMeaningfulProof: true,
          firstProofPayoffVisible: true,
          outcomesOverride: packagingOutcomes,
        );
        expect(path.suppressStandaloneProBridgeCard, isTrue);
        expect(
          ProBridgeVisibilityEngine.shouldShow(
            input: _bridgeInput(
              entryCount: 3,
              hasTimelineProof: true,
              firstProofPayoffVisible: true,
            ),
          ),
          isFalse,
        );
      },
    );
  });

  group('Pack engine integration', () {
    test(
      'proPackaging branch exposes paired bridge lines after meaningful proof',
      () {
        final lines = BetaImprovementPackEngine.firstProofProBridgeLines(
          entryCount: 3,
          hasMeaningfulProof: true,
          outcomesOverride: packagingOutcomes,
        );
        expect(lines, hasLength(2));
        expect(lines.first, ProPackagingCopyFix.proofBridge);
      },
    );

    test('proofEmotionalClarity branch does not expose Pro bridge lines', () {
      final lines = BetaImprovementPackEngine.firstProofProBridgeLines(
        entryCount: 3,
        hasMeaningfulProof: true,
        outcomesOverride: clarityOutcomes,
      );
      expect(lines, isEmpty);
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
