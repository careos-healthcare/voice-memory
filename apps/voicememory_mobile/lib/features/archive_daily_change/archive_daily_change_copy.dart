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

  static const labelDelayBeforeReplying = 'Delay before replying';
  static const labelCheckCapacityBeforeAnswering =
      'Check capacity before answering';
  static const labelUseDefaultPause = 'Use your default pause';
  static const labelMarkPullFirst = 'Mark the pull first';
  static const labelSaveMomentOnly =
      'Save only the moment, not the full story';
  static const labelReviewLoop = 'Review the loop';
  static const labelWatchPull = 'Watch for the same pull';

  // Legacy label aliases kept for tests that reference old names.
  static const labelDelayAnswer = labelDelayBeforeReplying;
  static const labelCheckCapacity = labelCheckCapacityBeforeAnswering;
  static const labelDefaultPause = labelUseDefaultPause;
  static const labelMarkPull = labelMarkPullFirst;
  static const labelSaveOneMore = labelSaveMomentOnly;

  static const urgencyWithLaterCostLine =
      'Urgency keeps showing up, and one of those yes moments later cost you time or energy.';

  static const responsibilityWithSaidYesLine =
      'Feeling responsible is becoming the pull to watch. You marked yes again when that was present.';

  static String repeatedPullWithLaterCostLine(String pullShortLabel) =>
      pullShortLabel == 'urgency'
          ? urgencyWithLaterCostLine
          : '${_capitalize(pullShortLabel)} has appeared more than once, '
              'and at least one yes moment had a later cost.';

  static String repeatedPullWithSaidYesLine(String pullShortLabel) =>
      pullShortLabel == 'feeling responsible'
          ? responsibilityWithSaidYesLine
          : 'You kept saying yes when $pullShortLabel was the pull.';

  static const patternInterruptedLine =
      'You marked at least one moment where the pattern changed.';

  static const stillFormingLine =
      'Your yes loop is still forming. One more real moment will make this clearer.';

  static const waitingForNextMomentLine =
      'You saved a moment. Come back when the next real request pulls you toward yes.';

  static const fitConfirmedLine =
      'You marked the yes loop as fitting what you noticed.';

  static const fitPartlyNewMomentLine =
      'You marked the loop as partly fitting. This new moment gives it more evidence.';

  static const quickCaptureStillWorkLine =
      'Quick save still felt like work. The next version should reduce steps, not add more reflection.';

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

  static const altUrgency =
      'Do not answer immediately. Use: ‘I cannot answer properly right now — I will come back to you.’';
  static const altResponsibility =
      'Check your actual capacity before accepting responsibility.';
  static const altDisappointment =
      'Use: ‘I want to help, but I need to check what I can realistically do.’';
  static const altSqueezeItIn =
      'Ask what would need to move before saying yes.';
  static const altOpportunity =
      'Delay the answer long enough to check whether this opportunity displaces something important.';
  static const altAnsweredTooQuickly =
      'Pause before replying. Do not answer in the first moment.';
  static const altQuickCaptureStillWork =
      'Save only the pull. Skip the rest.';

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
        ArchiveDailyChangeResponseType.waitingForNextMoment =>
          waitingForNextMomentLine,
        ArchiveDailyChangeResponseType.fitConfirmed => fitConfirmedLine,
        ArchiveDailyChangeResponseType.fitPartlyNewMoment =>
          fitPartlyNewMomentLine,
        ArchiveDailyChangeResponseType.quickCaptureStillWork =>
          quickCaptureStillWorkLine,
        ArchiveDailyChangeResponseType.noPullReasonYet => noPullReasonLine,
        ArchiveDailyChangeResponseType.recentChange => changeNewYesMoment,
      };

  static String alternativeLabelForPull(String? pullId) => switch (pullId) {
        CapacityPullReasonIds.soundedUrgent => labelDelayBeforeReplying,
        CapacityPullReasonIds.feltResponsible =>
          labelCheckCapacityBeforeAnswering,
        CapacityPullReasonIds.avoidDisappoint => labelUseDefaultPause,
        CapacityPullReasonIds.squeezeItIn =>
          labelCheckCapacityBeforeAnswering,
        CapacityPullReasonIds.wantedOpportunity => labelDelayBeforeReplying,
        CapacityPullReasonIds.answeredTooQuickly => labelDelayBeforeReplying,
        _ => labelMarkPullFirst,
      };

  static String alternativeBodyForPull(String? pullId) => switch (pullId) {
        CapacityPullReasonIds.soundedUrgent => altUrgency,
        CapacityPullReasonIds.feltResponsible => altResponsibility,
        CapacityPullReasonIds.avoidDisappoint => altDisappointment,
        CapacityPullReasonIds.squeezeItIn => altSqueezeItIn,
        CapacityPullReasonIds.wantedOpportunity => altOpportunity,
        CapacityPullReasonIds.answeredTooQuickly => altAnsweredTooQuickly,
        _ => bodyBeforeReplyingTemplate,
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
        labelDelayBeforeReplying,
        labelCheckCapacityBeforeAnswering,
        labelUseDefaultPause,
        labelMarkPullFirst,
        labelSaveMomentOnly,
        labelReviewLoop,
        labelWatchPull,
        urgencyWithLaterCostLine,
        responsibilityWithSaidYesLine,
        repeatedPullWithLaterCostLine('urgency'),
        repeatedPullWithSaidYesLine('feeling responsible'),
        patternInterruptedLine,
        stillFormingLine,
        waitingForNextMomentLine,
        fitConfirmedLine,
        fitPartlyNewMomentLine,
        quickCaptureStillWorkLine,
        noPullReasonLine,
        changeNewYesMoment,
        changeLaterCost,
        changeBoundarySelected,
        changeYesLoopReady,
        altUrgency,
        altResponsibility,
        altDisappointment,
        altSqueezeItIn,
        altOpportunity,
        altAnsweredTooQuickly,
        altQuickCaptureStillWork,
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
