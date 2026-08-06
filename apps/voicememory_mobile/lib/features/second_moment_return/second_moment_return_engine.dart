import '../../models/journal_entry.dart';
import '../early_archive/early_first_signal_engine.dart';
import '../return_day/return_day_flow_engine.dart';
import '../return_day/return_day_flow_store.dart';
import '../revenue_lift_experiment_v2/revenue_lift_experiment_v2_copy.dart';
import '../revenue_lift_experiment_v2/revenue_lift_experiment_v2_engine.dart';
import 'second_moment_return_copy.dart';
import 'second_moment_return_model.dart';
import 'second_moment_return_store.dart';

/// Second-moment return guidance — visibility only, no evidence changes.
abstract final class SecondMomentReturnEngine {
  SecondMomentReturnEngine._();

  static SecondMomentReturnResult build({
    required List<JournalEntry> entries,
    required String source,
    DateTime? now,
  }) {
    final entryCount = entries.length;
    final hasConfirmedRepeat =
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries);

    return SecondMomentReturnResult(
      shouldShow: qualifiesForAudience(
        entryCount: entryCount,
        hasConfirmedRepeat: hasConfirmedRepeat,
        secondDayReturnCueCompleted: secondDayReturnCueCompleted(
          entries: entries,
          now: now,
        ),
        dismissedForToday: SecondMomentReturnStore.isDismissedToday,
      ),
      title: SecondMomentReturnCopy.title,
      body: SecondMomentReturnCopy.body,
      noticeLine: SecondMomentReturnCopy.noticeLine,
      noPressureLine: SecondMomentReturnCopy.noPressureLine,
      noticedSomethingAction: SecondMomentReturnCopy.noticedSomethingAction,
      showWhatToNoticeAction: SecondMomentReturnCopy.showWhatToNoticeAction,
      notTodayAction: SecondMomentReturnCopy.notTodayAction,
      afterNoticedSomething: SecondMomentReturnCopy.afterNoticedSomething,
      afterNotToday: SecondMomentReturnCopy.afterNotToday,
      returnReasonLine:
          RevenueLiftExperimentV2Engine.showReturnReasonLine(
            entryCount: entryCount,
          )
          ? RevenueLiftExperimentV2Copy.returnReasonLine
          : '',
      prompts: [
        for (final type in SecondMomentReturnCopy.promptOrder)
          SecondMomentReturnPrompt(
            type: type,
            text: SecondMomentReturnCopy.promptTextFor(type),
          ),
      ],
      entryCount: entryCount,
      source: source,
      hasConfirmedRepeat: hasConfirmedRepeat,
    );
  }

  static bool qualifiesForAudience({
    required int entryCount,
    required bool hasConfirmedRepeat,
    required bool secondDayReturnCueCompleted,
    required bool dismissedForToday,
  }) {
    if (dismissedForToday) return false;
    if (entryCount == 1) return true;
    if (entryCount == 2 &&
        !hasConfirmedRepeat &&
        !secondDayReturnCueCompleted) {
      return true;
    }
    return false;
  }

  static bool secondDayReturnCueCompleted({
    required List<JournalEntry> entries,
    DateTime? now,
  }) {
    if (ReturnDayFlowStore.answeredToday) return true;
    if (entries.length >= 2 &&
        ReturnDayFlowGates.returnedOnLaterDay(entries: entries, now: now) &&
        ReturnDayFlowStore.todayAnswer != null) {
      return true;
    }
    return false;
  }

  static bool shouldShow({
    required SecondMomentReturnResult? result,
    required bool isReady,
    required bool isRecording,
    required bool isPostSave,
    required bool isDegradedTranscriptState,
    required bool firstProofPayoffVisible,
    required bool whatChangedQuestionActive,
    required bool patternReviewInboxHasActiveItems,
    required int entryCount,
  }) {
    if (result == null || !result.shouldShow) return false;
    if (entryCount >= 3) return false;
    if (!isReady) return false;
    if (isRecording) return false;
    if (isPostSave) return false;
    if (isDegradedTranscriptState) return false;
    if (firstProofPayoffVisible) return false;
    if (whatChangedQuestionActive) return false;
    if (patternReviewInboxHasActiveItems) return false;
    return true;
  }
}
