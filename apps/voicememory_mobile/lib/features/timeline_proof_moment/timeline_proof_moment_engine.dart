import '../../models/journal_entry.dart';
import '../archive_timeline_spine/archive_timeline_spine_engine.dart';
import '../archive_timeline_spine/archive_timeline_spine_model.dart';
import '../correction_memory/correction_memory_engine.dart';
import '../repeat_return_check/repeat_return_check_models.dart';
import 'timeline_proof_moment_copy.dart';
import 'timeline_proof_moment_model.dart';

/// Compresses archive timeline spine into one concise proof moment.
abstract final class TimelineProofMomentEngine {
  TimelineProofMomentEngine._();

  static const minMeaningfulSpineRows = 2;

  static TimelineProofMomentResult? build({
    required List<JournalEntry> entries,
    required bool beliefSurfaceVisible,
    required String source,
    bool compact = false,
    DateTime? now,
  }) {
    final spine = ArchiveTimelineSpineEngine.build(
      entries: entries,
      beliefSurfaceVisible: beliefSurfaceVisible,
      source: source,
      now: now,
    );
    return buildFromSpine(
      spine: spine,
      entries: entries,
      source: source,
      compact: compact,
      now: now,
    );
  }

  static TimelineProofMomentResult? buildFromSpine({
    required ArchiveTimelineSpineResult? spine,
    required List<JournalEntry> entries,
    required String source,
    bool compact = false,
    DateTime? now,
  }) {
    if (spine == null || !spine.shouldShow) return null;
    if (spine.rowCount < minMeaningfulSpineRows) return null;

    final correction = CorrectionMemoryEngine.snapshotFor(
      entries: entries,
      now: now,
    );
    final rows = <TimelineProofMomentRow>[
      const TimelineProofMomentRow(
        label: TimelineProofMomentCopy.firstSeenRow,
      ),
      if (spine.hasConfirmedRepeat)
        const TimelineProofMomentRow(
          label: TimelineProofMomentCopy.returnedRow,
        ),
      if (spine.hasCorrection && correction != null)
        TimelineProofMomentRow(
          label: TimelineProofMomentCopy.correctedRowFor(
            TimelineProofMomentCopy.correctionLabelFor(
              state: correction.state,
              returnedAfterFaded: correction.returnedAfterFaded,
            ),
          ),
        ),
      const TimelineProofMomentRow(
        label: TimelineProofMomentCopy.currentWeightRow,
      ),
    ];

    return TimelineProofMomentResult(
      shouldShow: true,
      entryCount: spine.entryCount,
      source: source,
      hasConfirmedRepeat: spine.hasConfirmedRepeat,
      hasCorrection: spine.hasCorrection,
      currentWeight: spine.currentWeight,
      rowCount: rows.length,
      title: compact
          ? TimelineProofMomentCopy.compactTitle
          : TimelineProofMomentCopy.title,
      body: TimelineProofMomentCopy.body,
      rows: rows,
      currentWeightLine:
          TimelineProofMomentCopy.currentWeightLineFor(spine.currentWeight),
      footer: TimelineProofMomentCopy.footer,
      differentiationLine: TimelineProofMomentCopy.differentiationLine,
      proLine: TimelineProofMomentCopy.proLine,
      compact: compact,
    );
  }

  static bool shouldShow({
    required TimelineProofMomentResult? result,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool firstProofPayoffVisible,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
    required bool isRecording,
    bool allowDuringFirstProofPayoff = false,
  }) {
    if (result == null || !result.shouldShow) return false;
    if (isRecording) return false;
    if (isDegradedTranscriptState) return false;
    if (isPostSaveDegradedState) return false;
    if (whatChangedQuestionActive) return false;
    if (patternReviewInboxHasActiveItems) return false;
    if (firstProofPayoffVisible && !allowDuringFirstProofPayoff) return false;
    return true;
  }

  static bool shouldShowOnPatterns({
    required TimelineProofMomentResult? result,
    required bool timelineSpineVisible,
    required bool isDegradedTranscriptState,
    required bool isPostSaveDegradedState,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) =>
      timelineSpineVisible &&
      shouldShow(
        result: result,
        isDegradedTranscriptState: isDegradedTranscriptState,
        isPostSaveDegradedState: isPostSaveDegradedState,
        firstProofPayoffVisible: false,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
        isRecording: false,
      );

  static bool shouldShowOnRecordReady({
    required TimelineProofMomentResult? result,
    required bool isDegradedTranscriptState,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) {
    if (result == null || !result.hasConfirmedRepeat) return false;
    return shouldShow(
      result: result,
      isDegradedTranscriptState: isDegradedTranscriptState,
      isPostSaveDegradedState: false,
      firstProofPayoffVisible: false,
      whatChangedQuestionActive: whatChangedQuestionActive,
      patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
      isRecording: false,
    );
  }

  static bool shouldShowOnFirstProofPayoffPostSave({
    required TimelineProofMomentResult? result,
    required bool showFirstProofPayoff,
    required bool isDegradedPostSave,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
  }) =>
      showFirstProofPayoff &&
      shouldShow(
        result: result,
        isDegradedTranscriptState: isDegradedPostSave,
        isPostSaveDegradedState: isDegradedPostSave,
        firstProofPayoffVisible: true,
        whatChangedQuestionActive: whatChangedQuestionActive,
        patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
        isRecording: false,
        allowDuringFirstProofPayoff: true,
      );

  static bool patternReviewInboxHasActiveItems({
    required List<JournalEntry> entries,
    List<RepeatReturnCheckRecord> returnChecks = const [],
  }) =>
      ArchiveTimelineSpineEngine.patternReviewInboxHasActiveItems(
        entries: entries,
        returnChecks: returnChecks,
      );
}
