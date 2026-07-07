import '../../models/journal_entry.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../pro_evidence_value/pro_evidence_value_engine.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import 'timeline_positioning_copy.dart';
import 'timeline_positioning_model.dart';

/// Builds timeline positioning from safe metadata — copy layer only.
abstract final class TimelinePositioningEngine {
  TimelinePositioningEngine._();

  static const maxEarlyEntryCount = 7;

  static TimelinePositioningResult build({
    required List<JournalEntry> entries,
    required bool beliefSurfaceVisible,
    required String source,
  }) {
    final hasConfirmedRepeat =
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries);

    return TimelinePositioningResult(
      shouldShow: true,
      entryCount: entries.length,
      source: source,
      hasConfirmedRepeat: hasConfirmedRepeat,
      hasBeliefSurface: beliefSurfaceVisible,
      title: TimelinePositioningCopy.title,
      body: TimelinePositioningCopy.body,
      differentiationLine: TimelinePositioningCopy.differentiationLine,
      timelineBullets: TimelinePositioningCopy.timelineBullets,
      proBridgeLine: TimelinePositioningCopy.proBridgeLine,
    );
  }

  static bool shouldShow({
    required TimelinePositioningResult? result,
    required int otherEducationCardCount,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool firstProofPayoffVisible,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) {
    if (result == null || !result.shouldShow) return false;
    if (isDegradedTranscriptState) return false;
    if (isPostSaveDegradedState) return false;
    if (firstProofPayoffVisible) return false;
    if (whatChangedQuestionActive) return false;
    if (patternReviewInboxHasActiveItems) return false;
    if (otherEducationCardCount > 1) return false;
    return true;
  }

  static bool shouldShowOnRecordReady({
    required TimelinePositioningResult? result,
    required int entryCount,
    required int otherEducationCardCount,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool firstProofPayoffVisible,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) =>
      entryCount <= maxEarlyEntryCount &&
      shouldShow(
        result: result,
        otherEducationCardCount: otherEducationCardCount,
        isDegradedTranscriptState: isDegradedTranscriptState,
        isPostSaveDegradedState: isPostSaveDegradedState,
        firstProofPayoffVisible: firstProofPayoffVisible,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
      );

  static bool shouldShowOnPatterns({
    required TimelinePositioningResult? result,
    required int otherEducationCardCount,
    required bool isDegradedTranscriptState,
    required bool firstProofPayoffVisible,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) =>
      shouldShow(
        result: result,
        otherEducationCardCount: otherEducationCardCount,
        isDegradedTranscriptState: isDegradedTranscriptState,
        isPostSaveDegradedState: false,
        firstProofPayoffVisible: firstProofPayoffVisible,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
      );

  static bool shouldShowOnWeeklyReview({
    required TimelinePositioningResult? result,
    required bool primaryPlacementVisible,
    required bool isDegradedTranscriptState,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) =>
      !primaryPlacementVisible &&
      shouldShow(
        result: result,
        otherEducationCardCount: 0,
        isDegradedTranscriptState: isDegradedTranscriptState,
        isPostSaveDegradedState: false,
        firstProofPayoffVisible: false,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
      );

  static int countOtherEducationCards({
    required bool captureFreedomLineVisible,
    required bool currentRelevanceVisible,
    required bool evidenceWeightingVisible,
    required bool proofSpecificityVisible,
    required bool presentDayRelevanceVisible,
  }) {
    var count = 0;
    if (captureFreedomLineVisible) count++;
    if (currentRelevanceVisible) count++;
    if (evidenceWeightingVisible) count++;
    if (proofSpecificityVisible) count++;
    if (presentDayRelevanceVisible) count++;
    return count;
  }

  static bool patternReviewInboxHasActiveItems({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) =>
      ProEvidenceValueEngine.patternReviewInboxHasActiveItems(
        entries: entries,
        returnChecks: returnChecks,
      );
}
