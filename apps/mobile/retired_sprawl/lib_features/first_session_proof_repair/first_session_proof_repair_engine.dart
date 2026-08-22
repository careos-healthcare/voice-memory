import 'package:archiveme_mobile/features/app_review/archive_app_review_access_gate.dart';
import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/beta_improvement/beta_improvement_pack_engine.dart';
import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_engine.dart';
import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_store.dart';
import 'package:archiveme_mobile/features/first_session_proof_repair/first_session_proof_repair_copy.dart';
import 'package:archiveme_mobile/features/first_session_proof_repair/first_session_proof_repair_model.dart';
import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:archiveme_mobile/features/revenue_readiness/revenue_readiness_dashboard_v2_model.dart';

abstract final class FirstSessionProofRepairEngine {
  FirstSessionProofRepairEngine._();

  static const usefulProofConcernThreshold = 2;
  static const firstSessionSaveConcernThreshold = 1;

  static FirstSessionCaptureRepairResult buildCapture({
    required int entryCount,
    required String source,
  }) {
    final base = FirstSessionCaptureRepairResult(
      shouldShow: entryCount == 0,
      title: FirstSessionProofRepairCopy.captureTitle,
      body: FirstSessionProofRepairCopy.captureBody,
      primaryCta: FirstSessionProofRepairCopy.capturePrimaryCta,
      secondaryCta: FirstSessionProofRepairCopy.captureSecondaryCta,
      microcopy: FirstSessionProofRepairCopy.captureMicrocopy,
      typedCapturePrompt: FirstSessionProofRepairCopy.typedCapturePrompt,
      chips: [
        for (final id in FirstSessionProofRepairCopy.captureChipOrder)
          FirstSessionProofRepairChip(
            id: id,
            text: FirstSessionProofRepairCopy.captureChipText(id),
          ),
      ],
      entryCount: entryCount,
      source: source,
    );
    return BetaImprovementPackEngine.applyCaptureRepair(base: base) ?? base;
  }

  static bool shouldShowCapture({
    required FirstSessionCaptureRepairResult? result,
    required bool betaMissionEnabled,
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    required bool isDegradedTranscriptState,
    required bool isPermissionBlocked,
    required int entryCount,
    bool isFirstSession = true,
  }) {
    if (!ArchiveBetaMissionGate.isEnabled && !betaMissionEnabled) return false;
    if (ArchiveAppReviewAccessGate.isEnabled) return false;
    if (result == null || !result.shouldShow) return false;
    if (entryCount != 0) return false;
    if (!isFirstSession) return false;
    if (!isReady) return false;
    if (isRecording) return false;
    if (isPostSave) return false;
    if (isDegradedTranscriptState) return false;
    if (isPermissionBlocked) return false;
    return true;
  }

  static ProofQualityRepairResult buildProof({
    required ProofQualityRepairVisibilityInput input,
  }) {
    final shouldShow = shouldShowProof(input: input);
    return ProofQualityRepairResult(
      shouldShow: shouldShow,
      title: FirstSessionProofRepairCopy.proofTitle,
      body: FirstSessionProofRepairCopy.proofBody,
      cta: FirstSessionProofRepairCopy.proofCta,
      source: input.source,
      entryCount: input.entryCount,
      confidenceLevel: input.confidenceLevel,
      surface: BetaProofFeedbackSurface.timelineProofMoment,
    );
  }

  static bool shouldShowProof({
    required ProofQualityRepairVisibilityInput input,
  }) {
    if (!ArchiveBetaMissionGate.isEnabled) return false;
    if (input.entryCount < 3) return false;
    if (!input.hasTimelineProofVisible && !input.hasConfirmedRepeat) {
      return false;
    }
    if (input.betaProofFeedbackRowVisible) return false;
    if (input.isRecording) return false;
    if (input.isDegradedTranscriptState) return false;
    if (input.whatChangedQuestionActive) return false;
    if (input.patternReviewInboxHasActiveItems) return false;
    if (BetaProofFeedbackStore.isAnsweredToday(
      BetaProofFeedbackSurface.timelineProofMoment,
    )) {
      return false;
    }
    return _needsProofQualityRepair(input);
  }

  static bool _needsProofQualityRepair(
    ProofQualityRepairVisibilityInput input,
  ) {
    final weakConfidence =
        input.confidenceLevel == ProofConfidenceLevel.watchOnly ||
        input.confidenceLevel == ProofConfidenceLevel.emerging;
    final weakUsefulCount =
        input.usefulFeedbackCount < usefulProofConcernThreshold;
    final hasNegativeFeedback = input.negativeFeedbackCount > 0;
    return weakConfidence || weakUsefulCount || hasNegativeFeedback;
  }

  static bool betaProofFeedbackRowVisible({
    required bool parentVisible,
    required int entryCount,
    required bool hasConfirmedRepeat,
    required bool isRecording,
    required bool isPostSaveDegraded,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) {
    if (!parentVisible) return false;
    if (BetaProofFeedbackStore.isAnsweredToday(
      BetaProofFeedbackSurface.timelineProofMoment,
    )) {
      return true;
    }
    return BetaProofFeedbackEngine.shouldShow(
      surface: BetaProofFeedbackSurface.timelineProofMoment,
      parentVisible: parentVisible,
      entryCount: entryCount,
      hasConfirmedRepeat: hasConfirmedRepeat,
      isRecording: isRecording,
      isPostSaveDegraded: isPostSaveDegraded,
      whatChangedQuestionActive: whatChangedQuestionActive,
      patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
    );
  }

  static FirstSessionProofRepairFocus resolveRepairFocus(
    RevenueReadinessDashboardV2Input input,
  ) {
    if (input.usefulCount < usefulProofConcernThreshold) {
      return const FirstSessionProofRepairFocus(
        focus: FirstSessionProofRepairFocusId.usefulProofQuality,
        label: FirstSessionProofRepairCopy.focusUsefulProofQuality,
      );
    }
    if (input.firstSessionSaveCount <= firstSessionSaveConcernThreshold) {
      return const FirstSessionProofRepairFocus(
        focus: FirstSessionProofRepairFocusId.firstSessionCapture,
        label: FirstSessionProofRepairCopy.focusFirstSessionCapture,
      );
    }
    return const FirstSessionProofRepairFocus(
      focus: FirstSessionProofRepairFocusId.continueTesting,
      label: FirstSessionProofRepairCopy.focusContinueTesting,
    );
  }

  static ({int useful, int negative}) feedbackCountsFromStore() {
    var useful = 0;
    var negative = 0;
    for (final surface in BetaProofFeedbackSurface.values) {
      final type = BetaProofFeedbackStore.recordFor(surface).feedbackType;
      if (type == BetaProofFeedbackType.useful) useful++;
      if (type == BetaProofFeedbackType.tooVague ||
          type == BetaProofFeedbackType.alreadyKnew ||
          type == BetaProofFeedbackType.notRelevant) {
        negative++;
      }
    }
    return (useful: useful, negative: negative);
  }

  static String captureStatusLabel({required bool visible}) => visible
      ? FirstSessionProofRepairCopy.statusCaptureActive
      : FirstSessionProofRepairCopy.statusCaptureInactive;

  static String proofStatusLabel({required bool visible}) => visible
      ? FirstSessionProofRepairCopy.statusProofActive
      : FirstSessionProofRepairCopy.statusProofInactive;

  static String chipPromptFor(String chipText) =>
      '${FirstSessionProofRepairCopy.typedCapturePrompt} $chipText';
}