import 'package:archiveme_mobile/features/first_proof_payoff/first_proof_payoff_engine.dart';
import 'package:archiveme_mobile/features/open_capture/open_capture_engine.dart';
import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_engine.dart';
import 'package:archiveme_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:archiveme_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:archiveme_mobile/features/return_after_proof/return_after_proof_copy.dart';
import 'package:archiveme_mobile/features/return_after_proof/return_after_proof_model.dart';
import 'package:archiveme_mobile/features/return_after_proof/return_after_proof_strengthening_engine.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

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
    final strengthened = ReturnAfterProofStrengtheningEngine.build(
      entries: entries,
      source: source,
      firstProofSeen: firstProofSeen,
      timelineProofVisible: timelineProofVisible,
      calibration: calibration,
    );

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
      strengthened: strengthened,
    );
  }

  static bool shouldShowGenericOnRecordReady({
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
  }) {
    if (ReturnAfterProofStrengtheningEngine.shouldShowOnRecordReady(
      result: result.strengthened,
      isReady: isReady,
      isRecording: isRecording,
      isDegradedTranscriptState: isDegradedTranscriptState,
      whatChangedQuestionActive: whatChangedQuestionActive,
      patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
      firstProofSeen: firstProofSeen,
      timelineProofVisible: timelineProofVisible,
      dismissedForToday: dismissedForToday,
    )) {
      return false;
    }
    return shouldShowOnRecordReady(
      result: result,
      isReady: isReady,
      isRecording: isRecording,
      isDegradedTranscriptState: isDegradedTranscriptState,
      whatChangedQuestionActive: whatChangedQuestionActive,
      patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
      firstProofSeen: firstProofSeen,
      timelineProofVisible: timelineProofVisible,
      betaTesterReportVisible: betaTesterReportVisible,
      dismissedForToday: dismissedForToday,
    );
  }

  static bool shouldShowStrengthenedOnRecordReady({
    required ReturnAfterProofResult result,
    required bool isReady,
    required bool isRecording,
    required bool isDegradedTranscriptState,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
    required bool firstProofSeen,
    required bool timelineProofVisible,
    required bool dismissedForToday,
  }) => ReturnAfterProofStrengtheningEngine.shouldShowOnRecordReady(
    result: result.strengthened,
    isReady: isReady,
    isRecording: isRecording,
    isDegradedTranscriptState: isDegradedTranscriptState,
    whatChangedQuestionActive: whatChangedQuestionActive,
    patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
    firstProofSeen: firstProofSeen,
    timelineProofVisible: timelineProofVisible,
    dismissedForToday: dismissedForToday,
  );

  static bool shouldShowAnyOnRecordReady({
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
      shouldShowStrengthenedOnRecordReady(
        result: result,
        isReady: isReady,
        isRecording: isRecording,
        isDegradedTranscriptState: isDegradedTranscriptState,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
        firstProofSeen: firstProofSeen,
        timelineProofVisible: timelineProofVisible,
        dismissedForToday: dismissedForToday,
      ) ||
      shouldShowGenericOnRecordReady(
        result: result,
        isReady: isReady,
        isRecording: isRecording,
        isDegradedTranscriptState: isDegradedTranscriptState,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
        firstProofSeen: firstProofSeen,
        timelineProofVisible: timelineProofVisible,
        betaTesterReportVisible: betaTesterReportVisible,
        dismissedForToday: dismissedForToday,
      );

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
    if (!firstProofSeen && !timelineProofVisible && !betaTesterReportVisible) {
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

  static bool shouldShowGenericOnFirstProofPayoffPostSave({
    required ReturnAfterProofResult result,
    required bool showFirstProofPayoff,
    required bool isRecording,
    required bool isPostSaveDegraded,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
    required bool dismissedForToday,
  }) {
    if (ReturnAfterProofStrengtheningEngine.shouldShowOnFirstProofPayoffPostSave(
      result: result.strengthened,
      showFirstProofPayoff: showFirstProofPayoff,
      isRecording: isRecording,
      isPostSaveDegraded: isPostSaveDegraded,
      whatChangedQuestionActive: whatChangedQuestionActive,
      patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
      dismissedForToday: dismissedForToday,
    )) {
      return false;
    }
    return _shouldShowFirstProofPayoffPostSave(
      result: result,
      showFirstProofPayoff: showFirstProofPayoff,
      isRecording: isRecording,
      isPostSaveDegraded: isPostSaveDegraded,
      whatChangedQuestionActive: whatChangedQuestionActive,
      patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
      dismissedForToday: dismissedForToday,
    );
  }

  static bool _shouldShowFirstProofPayoffPostSave({
    required ReturnAfterProofResult result,
    required bool showFirstProofPayoff,
    required bool isRecording,
    required bool isPostSaveDegraded,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
    required bool dismissedForToday,
  }) => shouldShow(
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

  static bool shouldShowStrengthenedOnFirstProofPayoffPostSave({
    required ReturnAfterProofResult result,
    required bool showFirstProofPayoff,
    required bool isRecording,
    required bool isPostSaveDegraded,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
    required bool dismissedForToday,
  }) =>
      ReturnAfterProofStrengtheningEngine.shouldShowOnFirstProofPayoffPostSave(
        result: result.strengthened,
        showFirstProofPayoff: showFirstProofPayoff,
        isRecording: isRecording,
        isPostSaveDegraded: isPostSaveDegraded,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
        dismissedForToday: dismissedForToday,
      );

  static bool shouldShowOnFirstProofPayoffPostSave({
    required ReturnAfterProofResult result,
    required bool showFirstProofPayoff,
    required bool isRecording,
    required bool isPostSaveDegraded,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
    required bool dismissedForToday,
  }) =>
      shouldShowGenericOnFirstProofPayoffPostSave(
        result: result,
        showFirstProofPayoff: showFirstProofPayoff,
        isRecording: isRecording,
        isPostSaveDegraded: isPostSaveDegraded,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
        dismissedForToday: dismissedForToday,
      ) ||
      shouldShowStrengthenedOnFirstProofPayoffPostSave(
        result: result,
        showFirstProofPayoff: showFirstProofPayoff,
        isRecording: isRecording,
        isPostSaveDegraded: isPostSaveDegraded,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
        dismissedForToday: dismissedForToday,
      );

  static bool patternReviewInboxHasActiveItems({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) => OpenCaptureEngine.patternReviewInboxHasActiveItems(
    entries: entries,
    returnChecks: returnChecks,
  );
}