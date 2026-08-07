import '../beta_proof_feedback/beta_proof_feedback_model.dart';
import '../beta_repair_lab/beta_repair_lab_copy.dart';
import '../beta_repair_lab/beta_repair_lab_engine.dart';
import '../beta_repair_lab/beta_repair_lab_model.dart';
import '../beta_repair_lab/beta_repair_lab_store.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'pricing_value_framing_copy.dart';
import 'pricing_value_framing_model.dart';

/// Beta repair pricing value framing — pre-paywall decision copy only.
abstract final class PricingValueFramingEngine {
  PricingValueFramingEngine._();

  static PricingValueFramingResult build({
    required BetaRepairLabVisibilityInput input,
  }) {
    if (!shouldShow(input: input)) {
      return PricingValueFramingResult.hidden;
    }
    final hasUsefulProof = _hasStrongUsefulProof(input);
    return PricingValueFramingResult(
      shouldShow: true,
      title: PricingValueFramingCopy.title,
      body: PricingValueFramingCopy.body,
      valueExplanation: PricingValueFramingCopy.valueExplanation,
      bullets: PricingValueFramingCopy.bullets,
      reassurance: PricingValueFramingCopy.reassurance,
      primaryCta: PricingValueFramingCopy.primaryCta,
      secondaryCta: PricingValueFramingCopy.secondaryCta,
      feedbackPrompt: PricingValueFramingCopy.feedbackPrompt,
      source: input.source,
      entryCount: input.entryCount,
      hasUsefulProof: hasUsefulProof,
      activeRepairMode: BetaRepairLabMode.pricingValueFraming.analyticsValue,
    );
  }

  static bool shouldShow({required BetaRepairLabVisibilityInput input}) {
    if (!BetaRepairLabEngine.shouldShowLab(
      betaMissionEnabled: input.betaMissionEnabled,
    )) {
      return false;
    }
    if (!BetaRepairLabEngine.isRepairActive(
      BetaRepairLabMode.pricingValueFraming,
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
    if (input.isRecording) return false;
    if (input.isDegradedTranscriptState) return false;
    if (input.whatChangedQuestionActive) return false;
    if (input.patternReviewInboxHasActiveItems) return false;
    return true;
  }

  static bool blocksOtherProCardsWhenPricingValueFramingActive({
    required bool betaMissionEnabled,
    required bool showPricingValueFraming,
  }) {
    if (!showPricingValueFraming) return false;
    if (!BetaRepairLabEngine.shouldShowLab(
      betaMissionEnabled: betaMissionEnabled,
    )) {
      return false;
    }
    return BetaRepairLabStore.activeMode ==
        BetaRepairLabMode.pricingValueFraming;
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
