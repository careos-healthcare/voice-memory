import '../beta_proof_feedback/beta_proof_feedback_model.dart';
import '../beta_repair_lab/beta_repair_lab_copy.dart';
import '../beta_repair_lab/beta_repair_lab_engine.dart';
import '../beta_repair_lab/beta_repair_lab_model.dart';
import '../beta_repair_lab/beta_repair_lab_store.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'pricing_validation_copy.dart';
import 'pricing_validation_model.dart';

/// Beta repair pricing validation — intent collection only, no purchase changes.
abstract final class PricingValidationEngine {
  PricingValidationEngine._();

  static PricingValidationResult build({
    required BetaRepairLabVisibilityInput input,
    bool hasProEngagement = false,
  }) {
    if (!shouldShow(input: input, hasProEngagement: hasProEngagement)) {
      return PricingValidationResult.hidden;
    }
    final hasUsefulProof = _hasStrongUsefulProof(input);
    return PricingValidationResult(
      shouldShow: true,
      title: PricingValidationCopy.title,
      body: PricingValidationCopy.body,
      pricePrompt: PricingValidationCopy.pricePrompt,
      reasonPrompt: PricingValidationCopy.reasonPrompt,
      primaryCta: PricingValidationCopy.primaryCta,
      secondaryCta: PricingValidationCopy.secondaryCta,
      source: input.source,
      entryCount: input.entryCount,
      hasUsefulProof: hasUsefulProof,
      activeRepairMode: BetaRepairLabMode.pricingValidation.analyticsValue,
    );
  }

  static bool shouldShow({
    required BetaRepairLabVisibilityInput input,
    bool hasProEngagement = false,
  }) {
    if (!BetaRepairLabEngine.shouldShowLab(
      betaMissionEnabled: input.betaMissionEnabled,
    )) {
      return false;
    }
    if (!BetaRepairLabEngine.isRepairActive(
      BetaRepairLabMode.pricingValidation,
    )) {
      return false;
    }
    if (input.isPro) return false;
    if (input.entryCount < 3) return false;
    if (!input.hasTimelineProofVisible && !input.hasConfirmedRepeat) {
      return false;
    }
    if (!_hasStrongUsefulProof(input)) return false;
    if (_isWeakConfidence(input.confidenceLevel)) return false;
    if (input.feedbackType == BetaProofFeedbackType.tooVague ||
        input.feedbackType == BetaProofFeedbackType.notRelevant) {
      return false;
    }
    if (!hasProEngagement) return false;
    if (input.isRecording) return false;
    if (input.isDegradedTranscriptState) return false;
    if (input.whatChangedQuestionActive) return false;
    if (input.patternReviewInboxHasActiveItems) return false;
    return true;
  }

  static bool blocksOtherProCardsWhenPricingValidationActive({
    required bool betaMissionEnabled,
    required bool showPricingValidation,
  }) {
    if (!showPricingValidation) return false;
    if (!BetaRepairLabEngine.shouldShowLab(
      betaMissionEnabled: betaMissionEnabled,
    )) {
      return false;
    }
    return BetaRepairLabStore.activeMode == BetaRepairLabMode.pricingValidation;
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
