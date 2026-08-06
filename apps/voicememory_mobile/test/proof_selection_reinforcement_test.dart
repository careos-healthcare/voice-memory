import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_model.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_store.dart';
import 'package:voicememory_mobile/features/evidence_trail_clarity/evidence_trail_clarity_engine.dart';
import 'package:voicememory_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';
import 'package:voicememory_mobile/features/pricing_validation/pricing_validation_engine.dart';
import 'package:voicememory_mobile/features/proof_caution_guard/proof_caution_guard_model.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:voicememory_mobile/features/proof_detail_repair/proof_detail_repair_engine.dart';
import 'package:voicememory_mobile/features/proof_selection/proof_selection_principle.dart';
import 'package:voicememory_mobile/features/proof_selection/proof_selection_principle_copy.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';

const _behaviorPhrase = 'said yes when I had no capacity for one more thing';

ProofDetailRepairResult _strongDetail() => ProofDetailRepairEngine.build(
  level: ProofConfidenceLevel.strong,
  hasSafeAnchor: true,
  behaviorPhrase: _behaviorPhrase,
);

BetaRepairLabVisibilityInput _repairInput() => BetaRepairLabVisibilityInput(
  mode: BetaRepairLabMode.evidenceTrailTimelineClarity,
  entryCount: 4,
  source: 'test',
  isPro: false,
  isRecording: false,
  isDegradedTranscriptState: false,
  whatChangedQuestionActive: false,
  patternReviewInboxHasActiveItems: false,
  hasTimelineProofVisible: true,
  hasConfirmedRepeat: true,
  confidenceLevel: ProofConfidenceLevel.watchOnly,
  hasUsefulProofFeedback: false,
  feedbackType: null,
  isNegativeFeedback: false,
  betaMissionEnabled: true,
);

void main() {
  group('ProofSelectionPrincipleCopy', () {
    test('headline is Why this proof appears first', () {
      expect(
        ProofSelectionPrincipleCopy.headline,
        'Why this proof appears first',
      );
    });

    test('body includes clearest specific repeat', () {
      expect(
        ProofSelectionPrincipleCopy.body,
        contains('clearest specific repeat'),
      );
    });

    test('body includes compare safely right now', () {
      expect(
        ProofSelectionPrincipleCopy.body,
        contains('compare safely right now'),
      );
    });

    test('body says it is not the most important thing', () {
      expect(
        ProofSelectionPrincipleCopy.body,
        contains('not saying this is the most important thing'),
      );
    });

    test('body says user can confirm or correct it', () {
      expect(ProofSelectionPrincipleCopy.body, contains('confirm'));
      expect(ProofSelectionPrincipleCopy.body, contains('correct'));
    });

    test('guardrail blocks ranking until one proof moment is trusted', () {
      expect(
        ProofSelectionPrincipleCopy.guardrail,
        contains('Do not rank patterns'),
      );
      expect(
        ProofSelectionPrincipleCopy.guardrail,
        contains('trust one proof moment'),
      );
    });

    test('decision label is Selection not ranking', () {
      expect(
        ProofSelectionPrincipleCopy.decisionLabel,
        'Selection, not ranking',
      );
    });

    test('copy does not include ranked list language', () {
      for (final text in ProofSelectionPrincipleCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('ranked list'), isFalse, reason: text);
      }
    });

    test('copy does not include importance scoring language', () {
      for (final text in ProofSelectionPrincipleCopy.allVisibleStrings()) {
        final lower = text.toLowerCase();
        expect(lower.contains('importance score'), isFalse, reason: text);
        expect(lower.contains('importance scoring'), isFalse, reason: text);
      }
    });

    test('copy avoids therapy diagnosis coaching advice language', () {
      for (final text in ProofSelectionPrincipleCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
        expect(
          ProofSelectionPrinciple.copyPassesGuard(text),
          isTrue,
          reason: text,
        );
      }
    });
  });

  group('ProofSelectionPrinciple helpers', () {
    test('snapshot exposes all five product rules', () {
      final snapshot = ProofSelectionPrinciple.snapshot();
      expect(snapshot.rules, ProofSelectionPrincipleRule.values);
      expect(snapshot.rules, hasLength(5));
      expect(
        snapshot.rules.map((rule) => rule.label),
        contains('Clearest safe repeat right now'),
      );
    });

    test('decision helpers block ranking features', () {
      expect(ProofSelectionPrinciple.allowsRankingUi(), isFalse);
      expect(ProofSelectionPrinciple.allowsImportanceScoring(), isFalse);
      expect(ProofSelectionPrinciple.allowsRankedLists(), isFalse);
    });

    test('detail copy aligns with principle shared wording', () {
      expect(ProofSelectionPrinciple.detailCopyAlignsWithPrinciple(), isTrue);
    });
  });

  group('Proof detail reinforcement', () {
    test('More detail copy still includes clearest safe repeat', () {
      expect(_strongDetail().body, contains('clearest specific repeat'));
      expect(
        _strongDetail().body,
        contains(ProofSelectionPrincipleCopy.whyThisOneLine),
      );
    });

    test('More detail copy still says not ranking every past mention yet', () {
      expect(
        _strongDetail().body,
        contains('not ranking every past mention yet'),
      );
    });

    test('More detail copy still keeps Too vague Not relevant correction', () {
      expect(
        _strongDetail().body,
        contains(ProofSelectionPrincipleCopy.correctionLine),
      );
    });

    test('watchOnly proof does not expose detail', () {
      expect(
        ProofDetailRepairEngine.build(
          level: ProofConfidenceLevel.watchOnly,
          hasSafeAnchor: true,
          behaviorPhrase: _behaviorPhrase,
        ).shouldShow,
        isFalse,
      );
    });

    test('no-safe-anchor proof does not expose detail', () {
      expect(
        ProofDetailRepairEngine.build(
          level: ProofConfidenceLevel.strong,
          hasSafeAnchor: false,
          behaviorPhrase: _behaviorPhrase,
        ).shouldShow,
        isFalse,
      );
    });

    test('generic rejected proof does not expose detail', () {
      expect(
        ProofDetailRepairEngine.build(
          level: ProofConfidenceLevel.strong,
          hasSafeAnchor: true,
          behaviorPhrase: 'kept checking',
          weakReasons: const [
            PatternMatchWeakReason.onlyGenericWordingOverlaps,
          ],
        ).shouldShow,
        isFalse,
      );
    });

    test('correction-blocked proof does not expose detail', () {
      expect(
        ProofDetailRepairEngine.build(
          level: ProofConfidenceLevel.useful,
          hasSafeAnchor: true,
          behaviorPhrase: _behaviorPhrase,
          cautionBlockedReason:
              ProofCautionGuardBlockedReason.userMarkedNotRelevant,
        ).shouldShow,
        isFalse,
      );
    });
  });

  group('Protected areas', () {
    test('principle module does not import protected systems', () {
      for (final path in [
        'lib/features/proof_selection/proof_selection_principle.dart',
        'lib/features/proof_selection/proof_selection_principle_copy.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('anchor_specificity_guard'), isFalse);
        expect(source.contains('PaywallSource'), isFalse);
        expect(source.contains('RevenueCat'), isFalse);
        expect(source.contains('billing/'), isFalse);
        expect(source.contains('evidence_trail_clarity'), isFalse);
        expect(source.contains('pricing_validation'), isFalse);
        expect(source.contains('restorePurchases'), isFalse);
        expect(source.contains('journal_storage'), isFalse);
      }
    });

    test('pro pricing evidence trail behaviour unchanged', () {
      expect(
        EvidenceTrailClarityEngine.shouldShow(
          input: _repairInput(),
          hasSafeAnchor: false,
        ),
        isFalse,
      );
      BetaRepairLabStore.repairModeOverrideForTest = 'pricingValidation';
      expect(
        PricingValidationEngine.shouldShow(
          input: _repairInput(),
          hasProEngagement: true,
        ),
        isFalse,
      );
    });

    test(
      'record screen remains capture-first without stacking extra cards',
      () {
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
      },
    );
  });
}
