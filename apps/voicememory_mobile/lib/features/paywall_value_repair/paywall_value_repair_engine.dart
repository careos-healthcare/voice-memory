import '../beta_proof_feedback/beta_proof_feedback_model.dart';
import '../beta_repair_lab/beta_repair_lab_engine.dart';
import '../beta_repair_lab/beta_repair_lab_model.dart';
import '../beta_repair_lab/beta_repair_lab_store.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'paywall_value_repair_copy.dart';
import 'paywall_value_repair_model.dart';

/// Beta repair paywall value card — pre-paywall framing only.
abstract final class PaywallValueRepairEngine {
  PaywallValueRepairEngine._();

  static PaywallValueRepairResult build({
    required BetaRepairLabVisibilityInput input,
  }) {
    if (!shouldShow(input: input)) {
      return PaywallValueRepairResult.hidden;
    }
    return PaywallValueRepairResult(
      shouldShow: true,
      title: PaywallValueRepairCopy.title,
      body: PaywallValueRepairCopy.body,
      bullets: PaywallValueRepairCopy.bullets,
      supportLine: PaywallValueRepairCopy.support,
      primaryCta: PaywallValueRepairCopy.primaryCta,
      secondaryCta: PaywallValueRepairCopy.secondaryCta,
      source: input.source,
      entryCount: input.entryCount,
    );
  }

  static bool shouldShow({required BetaRepairLabVisibilityInput input}) {
    if (!BetaRepairLabEngine.shouldShowLab(
      betaMissionEnabled: input.betaMissionEnabled,
    )) {
      return false;
    }
    if (!BetaRepairLabEngine.isRepairActive(BetaRepairLabMode.paywallValue)) {
      return false;
    }
    if (input.isPro) return false;
    if (input.entryCount < 3) return false;
    if (!input.hasTimelineProofVisible && !input.hasConfirmedRepeat) {
      return false;
    }
    if (!_hasStrongUsefulProof(input)) return false;
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

  static bool blocksOtherProCardsWhenPaywallValueRepairActive({
    required bool betaMissionEnabled,
    required bool showPaywallValue,
  }) {
    if (!showPaywallValue) return false;
    if (!BetaRepairLabEngine.shouldShowLab(
      betaMissionEnabled: betaMissionEnabled,
    )) {
      return false;
    }
    return BetaRepairLabStore.activeMode == BetaRepairLabMode.paywallValue;
  }

  static bool _hasStrongUsefulProof(BetaRepairLabVisibilityInput input) {
    if (input.feedbackType == BetaProofFeedbackType.useful) return true;
    return input.confidenceLevel == ProofConfidenceLevel.useful ||
        input.confidenceLevel == ProofConfidenceLevel.strong ||
        input.confidenceLevel == ProofConfidenceLevel.freshReturn;
  }
}
