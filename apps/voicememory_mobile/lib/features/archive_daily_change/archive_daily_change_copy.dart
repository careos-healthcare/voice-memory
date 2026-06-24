import '../capacity_loop/capacity_pull_reason_copy.dart';
import '../capacity_loop/capacity_pull_reason_models.dart';
import 'archive_daily_change_models.dart';

/// Copy for archive daily change — fixed signals only, no transcript text.
abstract final class ArchiveDailyChangeCopy {
  ArchiveDailyChangeCopy._();

  static const title = 'Your archive changed today';
  static const alternativeSectionTitle = 'Alternative next move';
  static const loopSectionTitle = 'What changed since last time';
  static const weeklySectionTitle = 'Next alternative to try';

  static const labelDelayAnswer = 'Delay the answer';
  static const labelCheckCapacity = 'Check capacity first';
  static const labelDefaultPause = 'Use your default pause';
  static const labelMarkPull = 'Mark the pull';
  static const labelSaveOneMore = 'Save one more yes moment';
  static const labelReviewLoop = 'Review the loop';
  static const labelWatchPull = 'Watch for the same pull';

  static String repeatedPullWithLaterCostLine(String pullShortLabel) =>
      '${_capitalize(pullShortLabel)} has appeared more than once, '
      'and at least one yes moment had a later cost.';

  static String repeatedPullWithSaidYesLine(String pullShortLabel) =>
      'You kept saying yes when $pullShortLabel was the pull.';

  static const patternInterruptedLine =
      'You marked at least one moment where the pattern changed.';

  static const stillFormingLine =
      'Your yes loop is still forming. One more real moment will make this clearer.';

  static const fitConfirmedLine =
      'You marked the yes loop as fitting what you noticed.';

  static const noPullReasonLine =
      'You saved the moment, but the pull is still unclear.';

  static const changeNewYesMoment =
      'You added another yes moment. This may be worth comparing with earlier saves.';
  static const changeLaterCost =
      'You marked a later cost on one moment.';
  static const changeBoundarySelected =
      'You chose a default pause line.';
  static const changeYesLoopReady =
      'Your yes loop has enough evidence to review.';

  static const bodyDelayBeforeReplying =
      'Delay the answer before replying.';
  static const bodyUrgencyCheckCapacity =
      'When urgency appears, do not answer immediately. Come back after checking your capacity.';
  static const bodyUsePauseAgain =
      'You delayed once. Try using the same pause again next time.';
  static const bodyOneMoreMoment =
      'One more real yes moment will make the loop clearer.';
  static const bodyWatchSamePull =
      'Watch for the same pull before agreeing again.';
  static const bodyMarkPull =
      'Mark what pulled you toward yes.';
  static const bodyBeforeReplyingTemplate =
      'Before replying, use: ‘Let me check my capacity and come back to you.’';

  static const watchUrgentResponsible =
      'Watch for urgent requests where you feel responsible.';
  static const watchAnswerBeforeCapacity =
      'Watch for moments where you answer before checking capacity.';
  static const watchHardToDelay =
      'Watch for requests that feel hard to delay.';
  static const watchSamePullMayRepeat =
      'This suggests the same pull may be the one to watch next.';

  static String pullShortLabel(String? reasonId) {
    if (reasonId == null || reasonId.isEmpty) return 'a repeated pull';
    return CapacityPullReasonCopy.shortLabelForReason(reasonId);
  }

  static String changeLineForResponseType(
    ArchiveDailyChangeResponseType type, {
    String? pullShortLabel,
  }) =>
      switch (type) {
        ArchiveDailyChangeResponseType.repeatedPullWithLaterCost =>
          repeatedPullWithLaterCostLine(
            pullShortLabel ?? 'A repeated pull',
          ),
        ArchiveDailyChangeResponseType.repeatedPullWithSaidYes =>
          repeatedPullWithSaidYesLine(
            pullShortLabel ?? 'a repeated pull',
          ),
        ArchiveDailyChangeResponseType.patternInterrupted =>
          patternInterruptedLine,
        ArchiveDailyChangeResponseType.stillForming => stillFormingLine,
        ArchiveDailyChangeResponseType.fitConfirmed => fitConfirmedLine,
        ArchiveDailyChangeResponseType.noPullReasonYet => noPullReasonLine,
        ArchiveDailyChangeResponseType.recentChange => changeNewYesMoment,
      };

  static String watchNextForPullReason(String? reasonId) => switch (reasonId) {
        CapacityPullReasonIds.soundedUrgent ||
        CapacityPullReasonIds.feltResponsible =>
          watchUrgentResponsible,
        CapacityPullReasonIds.answeredTooQuickly => watchAnswerBeforeCapacity,
        _ => watchHardToDelay,
      };

  static String _capitalize(String input) {
    if (input.isEmpty) return input;
    return '${input[0].toUpperCase()}${input.substring(1)}';
  }

  static List<String> allVisibleStrings() => [
        title,
        alternativeSectionTitle,
        loopSectionTitle,
        weeklySectionTitle,
        labelDelayAnswer,
        labelCheckCapacity,
        labelDefaultPause,
        labelMarkPull,
        labelSaveOneMore,
        labelReviewLoop,
        labelWatchPull,
        repeatedPullWithLaterCostLine('urgency'),
        repeatedPullWithSaidYesLine('feeling responsible'),
        patternInterruptedLine,
        stillFormingLine,
        fitConfirmedLine,
        noPullReasonLine,
        changeNewYesMoment,
        changeLaterCost,
        changeBoundarySelected,
        changeYesLoopReady,
        bodyDelayBeforeReplying,
        bodyUrgencyCheckCapacity,
        bodyUsePauseAgain,
        bodyOneMoreMoment,
        bodyWatchSamePull,
        bodyMarkPull,
        bodyBeforeReplyingTemplate,
        watchUrgentResponsible,
        watchAnswerBeforeCapacity,
        watchHardToDelay,
        watchSamePullMayRepeat,
      ];
}
