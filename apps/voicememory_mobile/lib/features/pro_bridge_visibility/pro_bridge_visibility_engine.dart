import '../beta_improvement/beta_improvement_pack_engine.dart';
import '../beta_improvement/proof_to_pro_path_engine.dart';
import '../pro_evidence_value/pro_evidence_value_dismiss_store.dart';
import '../pro_moment_timing/pro_moment_timing_model.dart';
import 'pro_bridge_timing_loosen_engine.dart';
import 'pro_bridge_visibility_copy.dart';
import 'pro_bridge_visibility_model.dart';

/// Visibility for the post-proof Pro bridge card — no billing changes.
abstract final class ProBridgeVisibilityEngine {
  ProBridgeVisibilityEngine._();

  static const minEntryCount = 3;

  static ProBridgeVisibilityResult build({
    required ProBridgeVisibilityInput input,
  }) {
    final loosen = ProBridgeTimingLoosenEngine.evaluate(
      input: ProBridgeTimingLoosenEngine.fromVisibilityInput(input),
    );
    final triggerReason = loosen.trigger?.analyticsValue ?? loosen.blockedReason?.analyticsValue;

    final proBridgeLine = BetaImprovementPackEngine.proBridgeLine(
      entryCount: input.entryCount,
      hasMeaningfulProof: input.hasTimelineProofVisible,
    );
    final branchTitle = BetaImprovementPackEngine.proBridgeTitle(
      entryCount: input.entryCount,
      hasMeaningfulProof: input.hasTimelineProofVisible,
    );
    final branchBody = BetaImprovementPackEngine.proBridgeBody(
      entryCount: input.entryCount,
      hasMeaningfulProof: input.hasTimelineProofVisible,
    );
    final baseBody = input.compact
        ? ProBridgeVisibilityCopy.compactBody
        : ProBridgeVisibilityCopy.body;
    final freeLine = BetaImprovementPackEngine.proFreeLine();
    final paidLine = BetaImprovementPackEngine.proPaidLine();
    final bodyParts = <String>[
      if (branchBody != null)
        branchBody
      else ...[
        if (freeLine != null) freeLine,
        if (paidLine != null) paidLine,
        if (freeLine == null && paidLine == null) baseBody,
        if (proBridgeLine != null) proBridgeLine,
      ],
    ];

    return ProBridgeVisibilityResult(
      shouldShow: shouldShow(input: input),
      title: branchTitle ?? ProBridgeVisibilityCopy.title,
      body: bodyParts.join(' '),
      cta: ProBridgeVisibilityCopy.cta,
      secondary: ProBridgeVisibilityCopy.secondary,
      entryCount: input.entryCount,
      source: input.source,
      surface: input.surface,
      triggerReason: triggerReason,
      hasTimelineProof: input.hasTimelineProofVisible,
      feedbackState: input.feedbackState,
      confidenceLevel: loosen.confidenceLevel,
      hasSafeAnchor: loosen.hasSafeAnchor,
    );
  }

  static bool shouldShow({
    required ProBridgeVisibilityInput input,
  }) {
    if (input.isPro) return false;
    if (!input.postProofProBridgeEnabled) return false;
    if (ProEvidenceValueDismissStore.isDismissed()) return false;
    if (input.entryCount < minEntryCount) return false;

    if (input.hasFirstProofPayoffVisible &&
        input.surface ==
            ProBridgeVisibilitySurface.recordPostSaveAfterPayoff) {
      return false;
    }

    if (ProofToProPathEngine.shouldSuppressStandaloneProBridgeCard(
      entryCount: input.entryCount,
      hasMeaningfulProof: input.hasTimelineProofVisible,
      firstProofPayoffVisible: input.hasFirstProofPayoffVisible,
    )) {
      return false;
    }

    return ProBridgeTimingLoosenEngine.evaluate(
      input: ProBridgeTimingLoosenEngine.fromVisibilityInput(input),
    ).allowed;
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
      hasMonthlyPrivateReportPreviewVisible:
          input.hasMonthlyPrivateReportPreviewVisible,
      hasBetaProofLiftVisible: input.hasBetaProofLiftVisible,
      hasReturnAfterProofStrengthenedVisible:
          input.hasReturnAfterProofStrengthenedVisible,
      feedbackState: input.feedbackState,
      whatChangedQuestionActive: input.whatChangedQuestionActive,
      patternReviewInboxHasActiveItems: input.patternReviewInboxHasActiveItems,
      proSlotAvailable: input.proSlotAvailable,
      confidenceLevel: input.confidenceLevel,
      hasSafeAnchor: input.hasSafeAnchor,
      hasFreshReturnAfterCorrection: input.hasFreshReturnAfterCorrection,
      hasSolidStrongPatternWithSafeAnchors:
          input.hasSolidStrongPatternWithSafeAnchors,
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
