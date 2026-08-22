import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_store.dart';
import 'package:archiveme_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:archiveme_mobile/features/pro_evidence_value/pro_evidence_value_engine.dart';
import 'package:archiveme_mobile/features/proof_specificity/proof_specificity_engine.dart';
import 'package:archiveme_mobile/features/proof_specificity_boost/proof_specificity_boost_model.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Builds and gates proof specificity boost — safe display summaries only.
abstract final class ProofSpecificityBoostEngine {
  ProofSpecificityBoostEngine._();

  static ProofSpecificityBoostResult build({
    required List<JournalEntry> entries,
    required bool beliefSurfaceVisible,
    required String source,
    List<String> beliefEvidencePhrases = const [],
  }) {
    final hasConfirmedRepeat =
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries);
    final hasBeliefSurface = beliefSurfaceVisible;
    if (!hasConfirmedRepeat && !hasBeliefSurface) {
      return ProofSpecificityBoostResult.hidden(
        source: source,
        entryCount: entries.length,
      );
    }

    final specificity = ProofSpecificityEngine.build(
      entries: entries,
      beliefSurfaceVisible: beliefSurfaceVisible,
      source: source,
      beliefEvidencePhrases: beliefEvidencePhrases,
    );

    final anchors =
        specificity.shouldShow && !specificity.usesFallbackEvidenceLine
        ? List<String>.from(specificity.evidenceAnchors)
        : const <String>[];
    final usesFallback = anchors.isEmpty;
    final hasSafeAnchor = anchors.isNotEmpty;

    return ProofSpecificityBoostResult(
      shouldShow: true,
      entryCount: entries.length,
      source: source,
      hasConfirmedRepeat: hasConfirmedRepeat,
      hasBeliefSurface: hasBeliefSurface,
      evidenceAnchors: anchors,
      usesFallbackEvidenceLine: usesFallback,
      hasSafeAnchor: hasSafeAnchor,
    );
  }

  static bool qualifiesForDisplay({
    required ProofSpecificityBoostResult result,
    required ProofSpecificityBoostSurface surface,
    required bool timelineProofVisible,
    required bool firstProofPayoffVisible,
  }) {
    if (!result.shouldShow) return false;

    final betaSurface = _betaSurfaceFor(surface);
    final betaRecord = BetaProofFeedbackStore.recordFor(betaSurface);
    final betaTooVague =
        betaRecord.answered &&
        betaRecord.feedbackType == BetaProofFeedbackType.tooVague;

    if (surface == ProofSpecificityBoostSurface.patterns) {
      return betaTooVague;
    }

    if (betaTooVague) return true;

    if (surface == ProofSpecificityBoostSurface.firstProofPayoff &&
        firstProofPayoffVisible &&
        result.hasConfirmedRepeat) {
      return true;
    }

    if (timelineProofVisible && result.usesFallbackEvidenceLine) {
      return true;
    }

    return false;
  }

  static bool shouldShow({
    required ProofSpecificityBoostResult result,
    required ProofSpecificityBoostSurface surface,
    required bool parentVisible,
    required bool timelineProofVisible,
    required bool firstProofPayoffVisible,
    required bool isRecording,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) {
    if (!parentVisible) return false;
    if (isRecording) return false;
    if (isDegradedTranscriptState) return false;
    if (isPostSaveDegradedState) return false;
    if (whatChangedQuestionActive) return false;
    if (patternReviewInboxHasActiveItems) return false;
    if (!result.hasConfirmedRepeat && !result.hasBeliefSurface) return false;
    if (!qualifiesForDisplay(
      result: result,
      surface: surface,
      timelineProofVisible: timelineProofVisible,
      firstProofPayoffVisible: firstProofPayoffVisible,
    )) {
      return false;
    }
    return true;
  }

  static bool shouldShowAnsweredFollowUp({
    required ProofSpecificityBoostSurface surface,
  }) => ProofSpecificityBoostStore.isAnswered(surface);

  static bool shouldRender({
    required ProofSpecificityBoostResult result,
    required ProofSpecificityBoostSurface surface,
    required bool parentVisible,
    required bool timelineProofVisible,
    required bool firstProofPayoffVisible,
    required bool isRecording,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) {
    if (shouldShowAnsweredFollowUp(surface: surface)) {
      if (!parentVisible) return false;
      if (isRecording) return false;
      if (isDegradedTranscriptState) return false;
      if (isPostSaveDegradedState) return false;
      if (whatChangedQuestionActive) return false;
      if (patternReviewInboxHasActiveItems) return false;
      return true;
    }
    return shouldShow(
      result: result,
      surface: surface,
      parentVisible: parentVisible,
      timelineProofVisible: timelineProofVisible,
      firstProofPayoffVisible: firstProofPayoffVisible,
      isRecording: isRecording,
      isDegradedTranscriptState: isDegradedTranscriptState,
      isPostSaveDegradedState: isPostSaveDegradedState,
      whatChangedQuestionActive: whatChangedQuestionActive,
      patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
    );
  }

  static BetaProofFeedbackSurface _betaSurfaceFor(
    ProofSpecificityBoostSurface surface,
  ) => switch (surface) {
    ProofSpecificityBoostSurface.timelineProofMoment =>
      BetaProofFeedbackSurface.timelineProofMoment,
    ProofSpecificityBoostSurface.firstProofPayoff =>
      BetaProofFeedbackSurface.firstProofPayoff,
    ProofSpecificityBoostSurface.patterns =>
      BetaProofFeedbackSurface.timelineProofMoment,
  };

  static bool patternReviewInboxHasActiveItems({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) => ProEvidenceValueEngine.patternReviewInboxHasActiveItems(
    entries: entries,
    returnChecks: returnChecks,
  );
}