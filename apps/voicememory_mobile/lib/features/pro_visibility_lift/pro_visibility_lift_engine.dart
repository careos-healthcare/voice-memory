import '../beta/archive_beta_mission_gate.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import '../proof_quality_response/proof_quality_response_model.dart';
import 'pro_visibility_lift_copy.dart';
import 'pro_visibility_lift_model.dart';
import 'pro_visibility_lift_store.dart';

abstract final class ProVisibilityLiftEngine {
  ProVisibilityLiftEngine._();

  static ProVisibilityLiftResult build({
    required ProVisibilityLiftSurface surface,
    required String source,
    required int entryCount,
    required bool isPro,
    required bool hasUsefulProof,
    required ProofConfidenceLevel confidenceLevel,
    required ProofQualityFeedbackState feedbackState,
    required bool hasPaywallSeen,
    required bool hasFreshReturnAfterCorrection,
    required bool hasChangeAnchor,
    required bool isRecording,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) {
    final shouldShow = shouldShowCard(
      entryCount: entryCount,
      isPro: isPro,
      hasUsefulProof: hasUsefulProof,
      confidenceLevel: confidenceLevel,
      feedbackState: feedbackState,
      hasPaywallSeen: hasPaywallSeen,
      hasFreshReturnAfterCorrection: hasFreshReturnAfterCorrection,
      hasChangeAnchor: hasChangeAnchor,
      isRecording: isRecording,
      isDegradedTranscriptState: isDegradedTranscriptState,
      isPostSaveDegradedState: isPostSaveDegradedState,
      whatChangedQuestionActive: whatChangedQuestionActive,
      patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
    );

    return ProVisibilityLiftResult(
      shouldShow: shouldShow,
      title: ProVisibilityLiftCopy.title,
      body: ProVisibilityLiftCopy.body,
      primaryCta: ProVisibilityLiftCopy.primaryCta,
      secondaryCta: ProVisibilityLiftCopy.secondaryCta,
      source: source,
      surface: surface,
      entryCount: entryCount,
      confidenceLevel: confidenceLevel,
      feedbackState: feedbackState,
      hasPaywallSeen: hasPaywallSeen,
    );
  }

  static bool shouldShowCard({
    required int entryCount,
    required bool isPro,
    required bool hasUsefulProof,
    required ProofConfidenceLevel confidenceLevel,
    required ProofQualityFeedbackState feedbackState,
    required bool hasPaywallSeen,
    required bool hasFreshReturnAfterCorrection,
    required bool hasChangeAnchor,
    required bool isRecording,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) {
    if (!ArchiveBetaMissionGate.isEnabled) return false;
    if (ProVisibilityLiftStore.isDismissedToday) return false;
    if (isPro) return false;
    if (entryCount < 3) return false;
    if (hasPaywallSeen) return false;
    if (!hasUsefulProof && !_hasEligibleConfidence(confidenceLevel)) {
      return false;
    }
    if (feedbackState == ProofQualityFeedbackState.tooVague ||
        feedbackState == ProofQualityFeedbackState.notRelevant) {
      return false;
    }
    if (feedbackState == ProofQualityFeedbackState.alreadyKnewThis &&
        !hasFreshReturnAfterCorrection &&
        !hasChangeAnchor) {
      return false;
    }
    if (isRecording) return false;
    if (isDegradedTranscriptState) return false;
    if (isPostSaveDegradedState) return false;
    if (whatChangedQuestionActive) return false;
    if (patternReviewInboxHasActiveItems) return false;
    return _hasEligibleConfidence(confidenceLevel) || hasUsefulProof;
  }

  static bool _hasEligibleConfidence(ProofConfidenceLevel level) =>
      level == ProofConfidenceLevel.useful ||
      level == ProofConfidenceLevel.strong ||
      level == ProofConfidenceLevel.freshReturn;
}
