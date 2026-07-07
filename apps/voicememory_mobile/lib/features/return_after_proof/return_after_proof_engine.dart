import '../../models/journal_entry.dart';
import '../first_proof_payoff/first_proof_payoff_engine.dart';
import '../open_capture/open_capture_engine.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_engine.dart';
import '../proof_confidence_calibration/proof_confidence_calibration_model.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import 'return_after_proof_copy.dart';
import 'return_after_proof_model.dart';
import 'return_after_proof_store.dart';

/// Visibility and content for return-after-proof guidance.
abstract final class ReturnAfterProofEngine {
  ReturnAfterProofEngine._();

  static const minEntryCount = 3;

  static ReturnAfterProofResult build({
    required List<JournalEntry> entries,
    required String source,
    required bool firstProofSeen,
    required bool timelineProofVisible,
    required bool betaTesterReportVisible,
  }) {
    final entryCount = entries.length;
    final hasFirstProof = firstProofSeen;
    final hasTimelineProof = timelineProofVisible;

    final calibration = ProofConfidenceCalibrationEngine.build(
      entries: entries,
      beliefSurfaceVisible: timelineProofVisible || firstProofSeen,
      source: source,
    );
    final body = calibration.level == ProofConfidenceLevel.strong
        ? ReturnAfterProofCopy.strongBody
        : ReturnAfterProofCopy.body;

    return ReturnAfterProofResult(
      shouldShow: true,
      title: ReturnAfterProofCopy.title,
      body: body,
      closingLine: ReturnAfterProofCopy.closingLine,
      prompts: [
        for (final type in ReturnAfterProofPromptTypeLists.capturePrompts)
          ReturnAfterProofPrompt(
            type: type,
            label: ReturnAfterProofCopy.chipLabelFor(type),
            selectedLine: ReturnAfterProofCopy.selectedPromptLineFor(type),
          ),
      ],
      entryCount: entryCount,
      source: source,
      hasTimelineProof: hasTimelineProof,
      hasFirstProof: hasFirstProof,
    );
  }

  static bool firstProofSeenFor(List<JournalEntry> entries) =>
      FirstProofPayoffEngine.build(entries: entries) != null;

  static bool shouldShow({
    required ReturnAfterProofResult result,
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    required bool isPostSaveDegraded,
    required bool firstProofPayoffVisible,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
    required bool firstProofSeen,
    required bool timelineProofVisible,
    required bool betaTesterReportVisible,
    required bool dismissedForToday,
  }) {
    if (!result.shouldShow) return false;
    if (result.entryCount < minEntryCount) return false;
    if (result.entryCount <= 1) return false;
    if (!isReady && !isPostSave) return false;
    if (isRecording) return false;
    if (isPostSaveDegraded) return false;
    if (whatChangedQuestionActive) return false;
    if (patternReviewInboxHasActiveItems) return false;
    if (dismissedForToday) return false;
    if (!firstProofSeen &&
        !timelineProofVisible &&
        !betaTesterReportVisible) {
      return false;
    }
    if (isPostSave) {
      return firstProofPayoffVisible;
    }
    if (firstProofPayoffVisible) return false;
    return true;
  }

  static bool shouldShowOnRecordReady({
    required ReturnAfterProofResult result,
    required bool isReady,
    required bool isRecording,
    required bool isDegradedTranscriptState,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
    required bool firstProofSeen,
    required bool timelineProofVisible,
    required bool betaTesterReportVisible,
    required bool dismissedForToday,
  }) =>
      shouldShow(
        result: result,
        isReady: isReady,
        isRecording: isRecording,
        isPostSave: false,
        isPostSaveDegraded: false,
        firstProofPayoffVisible: false,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
        firstProofSeen: firstProofSeen,
        timelineProofVisible: timelineProofVisible,
        betaTesterReportVisible: betaTesterReportVisible,
        dismissedForToday: dismissedForToday,
      ) &&
      !isDegradedTranscriptState;

  static bool shouldShowOnFirstProofPayoffPostSave({
    required ReturnAfterProofResult result,
    required bool showFirstProofPayoff,
    required bool isRecording,
    required bool isPostSaveDegraded,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
    required bool dismissedForToday,
  }) =>
      shouldShow(
        result: result,
        isReady: false,
        isRecording: isRecording,
        isPostSave: true,
        isPostSaveDegraded: isPostSaveDegraded,
        firstProofPayoffVisible: showFirstProofPayoff,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
        firstProofSeen: true,
        timelineProofVisible: false,
        betaTesterReportVisible: false,
        dismissedForToday: dismissedForToday,
      );

  static bool patternReviewInboxHasActiveItems({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) =>
      OpenCaptureEngine.patternReviewInboxHasActiveItems(
        entries: entries,
        returnChecks: returnChecks,
      );
}
