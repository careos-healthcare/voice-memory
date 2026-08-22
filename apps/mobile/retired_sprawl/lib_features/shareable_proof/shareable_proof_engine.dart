import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_store.dart';
import 'package:archiveme_mobile/features/shareable_proof/shareable_proof_model.dart';

/// Visibility rules for generic non-private share proof.
abstract final class ShareableProofEngine {
  ShareableProofEngine._();

  static ShareableProofResult build({
    required ShareableProofVisibilityInput input,
  }) {
    if (!shouldShow(input)) {
      return ShareableProofResult.hidden(entryCount: input.entryCount);
    }
    return ShareableProofResult(
      shouldShow: true,
      entryCount: input.entryCount,
      hasTimelineProof: input.timelineProofMomentSeen,
    );
  }

  static bool shouldShow(ShareableProofVisibilityInput input) {
    if (input.isRecording) return false;
    if (input.isDegradedTranscript) return false;
    if (input.whatChangedQuestionActive) return false;
    if (input.patternReviewInboxHasActiveItems) return false;
    if (_hasNegativeFeedbackToday()) return false;
    if (!_hasPositiveTrigger(input)) return false;
    return true;
  }

  static bool _hasPositiveTrigger(ShareableProofVisibilityInput input) {
    if (_hasUsefulFeedbackToday()) return true;
    if (input.timelineProofMomentSeen) return true;
    if (input.betaTesterReportSeen) return true;
    return false;
  }

  static bool _hasUsefulFeedbackToday() {
    for (final surface in BetaProofFeedbackSurface.values) {
      if (!BetaProofFeedbackStore.isAnsweredToday(surface)) continue;
      final record = BetaProofFeedbackStore.recordFor(surface);
      if (record.feedbackType == BetaProofFeedbackType.useful) {
        return true;
      }
    }
    return false;
  }

  static bool _hasNegativeFeedbackToday() {
    for (final surface in BetaProofFeedbackSurface.values) {
      if (!BetaProofFeedbackStore.isAnsweredToday(surface)) continue;
      final type = BetaProofFeedbackStore.recordFor(surface).feedbackType;
      if (type == BetaProofFeedbackType.tooVague ||
          type == BetaProofFeedbackType.notRelevant) {
        return true;
      }
    }
    return false;
  }
}