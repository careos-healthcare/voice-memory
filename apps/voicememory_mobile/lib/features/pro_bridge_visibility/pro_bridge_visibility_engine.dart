import '../pro_evidence_value/pro_evidence_value_dismiss_store.dart';
import '../pro_moment_timing/pro_moment_timing_engine.dart';
import '../pro_moment_timing/pro_moment_timing_model.dart';
import 'pro_bridge_visibility_copy.dart';
import 'pro_bridge_visibility_model.dart';

/// Visibility for the post-proof Pro bridge card — no billing changes.
abstract final class ProBridgeVisibilityEngine {
  ProBridgeVisibilityEngine._();

  static const minEntryCount = 3;

  static ProBridgeVisibilityResult build({
    required ProBridgeVisibilityInput input,
  }) {
    final timing = toTimingContext(input);
    final evaluation = ProMomentTimingEngine.evaluate(timing);
    final triggerReason =
        evaluation.trigger?.analyticsValue ?? evaluation.reason;

    return ProBridgeVisibilityResult(
      shouldShow: shouldShow(input: input),
      title: ProBridgeVisibilityCopy.title,
      body: input.compact
          ? ProBridgeVisibilityCopy.compactBody
          : ProBridgeVisibilityCopy.body,
      cta: ProBridgeVisibilityCopy.cta,
      secondary: ProBridgeVisibilityCopy.secondary,
      entryCount: input.entryCount,
      source: input.source,
      surface: input.surface,
      triggerReason: triggerReason,
      hasTimelineProof: input.hasTimelineProofVisible,
      feedbackState: input.feedbackState,
    );
  }

  static bool shouldShow({
    required ProBridgeVisibilityInput input,
  }) {
    if (input.isPro) return false;
    if (!input.postProofProBridgeEnabled) return false;
    if (ProEvidenceValueDismissStore.isDismissed()) return false;
    if (input.entryCount < minEntryCount) return false;

    final timing = toTimingContext(input);
    return ProMomentTimingEngine.evaluate(timing).allowed;
  }

  static ProMomentTimingContext toTimingContext(ProBridgeVisibilityInput input) {
    return ProMomentTimingContext(
      surface: _proMomentSurface(input.surface),
      source: input.source,
      entryCount: input.entryCount,
      isRecording: input.isRecording,
      isZeroEntryState: input.isZeroEntryState,
      isFirstRecordingState: input.isFirstRecordingState,
      isPostSaveDegradedState: input.isPostSaveDegradedState,
      isDegradedTranscriptState: input.isDegradedTranscriptState,
      hasFirstProof: input.hasFirstProof,
      hasTimelineProofVisible: input.hasTimelineProofVisible,
      hasFirstProofPayoffVisible: input.hasFirstProofPayoffVisible,
      hasBetaTesterReportVisible: input.hasBetaTesterReportVisible,
      hasCorrectionMemoryVisible: input.hasCorrectionMemoryVisible,
      feedbackState: input.feedbackState,
      whatChangedQuestionActive: input.whatChangedQuestionActive,
      patternReviewInboxHasActiveItems: input.patternReviewInboxHasActiveItems,
      proSlotAvailable: input.proSlotAvailable,
    );
  }

  static Future<void> dismiss() => ProEvidenceValueDismissStore.dismiss();

  static ProMomentTimingSurface _proMomentSurface(
    ProBridgeVisibilitySurface surface,
  ) =>
      switch (surface) {
        ProBridgeVisibilitySurface.recordReady =>
          ProMomentTimingSurface.recordReady,
        ProBridgeVisibilitySurface.recordPostSaveAfterPayoff =>
          ProMomentTimingSurface.recordPostSave,
        ProBridgeVisibilitySurface.archivePatterns =>
          ProMomentTimingSurface.archivePatterns,
      };
}
