import '../beta_proof_feedback/beta_proof_feedback_model.dart';
import '../beta_repair_lab/beta_repair_lab_copy.dart';
import '../beta_repair_lab/beta_repair_lab_engine.dart';
import '../beta_repair_lab/beta_repair_lab_model.dart';
import '../beta_repair_lab/beta_repair_lab_store.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'evidence_trail_clarity_copy.dart';
import 'evidence_trail_clarity_model.dart';

/// Beta repair evidence trail timeline clarity — proof-first explanation only.
abstract final class EvidenceTrailClarityEngine {
  EvidenceTrailClarityEngine._();

  static EvidenceTrailClarityResult build({
    required BetaRepairLabVisibilityInput input,
    required bool hasSafeAnchor,
    bool blocksProCards = false,
  }) {
    if (!shouldShow(
      input: input,
      hasSafeAnchor: hasSafeAnchor,
      blocksProCards: blocksProCards,
    )) {
      return EvidenceTrailClarityResult.hidden;
    }
    final hasUsefulProof = _hasStrongUsefulProof(input);
    return EvidenceTrailClarityResult(
      shouldShow: true,
      title: EvidenceTrailClarityCopy.title,
      body: EvidenceTrailClarityCopy.body,
      timelineRows: EvidenceTrailClarityCopy.timelineRows,
      supportLine: EvidenceTrailClarityCopy.supportLine,
      primaryCta: EvidenceTrailClarityCopy.primaryCta,
      secondaryCta: EvidenceTrailClarityCopy.secondaryCta,
      feedbackPrompt: EvidenceTrailClarityCopy.feedbackPrompt,
      source: input.source,
      entryCount: input.entryCount,
      hasUsefulProof: hasUsefulProof,
      confidenceLevel: input.confidenceLevel,
      activeRepairMode:
          BetaRepairLabMode.evidenceTrailTimelineClarity.analyticsValue,
    );
  }

  static bool shouldShow({
    required BetaRepairLabVisibilityInput input,
    required bool hasSafeAnchor,
    bool blocksProCards = false,
  }) {
    if (!BetaRepairLabEngine.shouldShowLab(
      betaMissionEnabled: input.betaMissionEnabled,
    )) {
      return false;
    }
    if (!BetaRepairLabEngine.isRepairActive(
      BetaRepairLabMode.evidenceTrailTimelineClarity,
    )) {
      return false;
    }
    if (blocksProCards) return false;
    if (input.isPro) return false;
    if (input.entryCount < 3) return false;
    if (!hasSafeAnchor) return false;
    if (!input.hasTimelineProofVisible && !input.hasConfirmedRepeat) {
      return false;
    }
    if (!_hasStrongUsefulProof(input)) return false;
    if (_isWeakConfidence(input.confidenceLevel)) return false;
    if (input.feedbackType == BetaProofFeedbackType.tooVague ||
        input.feedbackType == BetaProofFeedbackType.notRelevant) {
      return false;
    }
    if (input.isRecording) return false;
    if (input.isDegradedTranscriptState) return false;
    if (input.whatChangedQuestionActive) return false;
    if (input.patternReviewInboxHasActiveItems) return false;
    return true;
  }

  static bool blocksOtherProCardsWhenEvidenceTrailClarityActive({
    required bool betaMissionEnabled,
    required bool showEvidenceTrailClarity,
  }) {
    if (!showEvidenceTrailClarity) return false;
    if (!BetaRepairLabEngine.shouldShowLab(betaMissionEnabled: betaMissionEnabled)) {
      return false;
    }
    return BetaRepairLabStore.activeMode ==
        BetaRepairLabMode.evidenceTrailTimelineClarity;
  }

  static bool _hasStrongUsefulProof(BetaRepairLabVisibilityInput input) {
    if (input.feedbackType == BetaProofFeedbackType.useful) return true;
    return input.confidenceLevel == ProofConfidenceLevel.useful ||
        input.confidenceLevel == ProofConfidenceLevel.strong ||
        input.confidenceLevel == ProofConfidenceLevel.freshReturn;
  }

  static bool _isWeakConfidence(ProofConfidenceLevel level) =>
      level == ProofConfidenceLevel.watchOnly ||
      level == ProofConfidenceLevel.emerging;
}
