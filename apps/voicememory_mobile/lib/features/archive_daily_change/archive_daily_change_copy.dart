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
  static const labelCheckCapacityFirst = 'Check capacity first';
  static const labelNameTheLimit = 'Name the limit';
  static const labelMoveSomethingFirst = 'Move something first';
  static const labelCheckTradeOff = 'Check the trade-off';
  static const labelPauseFirstAnswer = 'Pause the first answer';
  static const labelSaveOnlyPull = 'Save only the pull';
  static const labelMarkPullFirst = 'Mark the pull first';
  static const labelUseDefaultPause = 'Use your default pause';
  static const labelReviewLoop = 'Review the loop';
  static const labelWatchPull = 'Watch for the same pull';

  // Legacy label aliases kept for tests that reference old names.
  static const labelCheckCapacityBeforeAnswering = labelCheckCapacityFirst;
  static const labelDelayAnswer = labelDelayBeforeReplying;
  static const labelCheckCapacity = labelCheckCapacityFirst;
  static const labelDefaultPause = labelUseDefaultPause;
  static const labelMarkPull = labelMarkPullFirst;
  static const labelSaveMomentOnly = labelSaveOnlyPull;
  static const labelSaveOneMore = labelSaveOnlyPull;

  static const repeatedPullNewOutcomeLine =
      'Responsibility showed up again, but the outcome changed.';

  static const samePullSameOutcomeLine =
      'The same pull led to the same answer again.';

  static const samePullLaterCostLine =
      'The pull repeated, and the later cost repeated too.';

  static const fitPartlyNewMomentLine =
      'This still only partly fits. The new moment adds evidence, but the '
      'pattern is not settled.';

  static const quickCaptureStillWorkLine =
      'The next useful step is less reflection, not more. Save only the pull.';

  static const boundaryResponseSelectedLine =
      'Your next move is already chosen: use your pause response before '
      'answering.';

  // Legacy aliases for gradual migration in tests.
  static const responsibilityRepeatedDelayedLine = repeatedPullNewOutcomeLine;
  static const urgencyWithLaterCostLine = samePullLaterCostLine;
  static const responsibilityWithSaidYesLine = samePullSameOutcomeLine;

  static String repeatedPullWithLaterCostLine(String pullShortLabel) =>
      samePullLaterCostLine;

  static String repeatedPullWithSaidYesLine(String pullShortLabel) =>
      samePullSameOutcomeLine;

  static const patternInterruptedLine = repeatedPullNewOutcomeLine;

  static const stillFormingLine =
      'Your yes loop is still forming. One more real moment will make this clearer.';

  static const waitingForNextMomentLine =
      'You saved a moment. Come back when the next real request pulls you toward yes.';

  static const fitConfirmedLine =
      'You marked the yes loop as fitting what you noticed.';

  static const noPullReasonLine =
      'You saved the moment, but the pull is still unclear.';

  static const changeNewYesMoment =
      'You added another yes moment. This may be worth comparing with earlier saves.';
  static const changeLaterCost = 'You marked a later cost on one moment.';
  static const changeBoundarySelected = boundaryResponseSelectedLine;
  static const changeYesLoopReady =
      'Your yes loop has enough evidence to review.';

  static const altUrgency =
      'Do not answer immediately. Use: ‘I cannot answer properly right now — '
      'I will come back to you.’';
  static const altResponsibility =
      'Check your actual capacity before accepting responsibility.';
  static const altDisappointment =
      'Use: ‘I want to help, but I need to check what I can realistically do.’';
  static const altSqueezeItIn =
      'Ask what would need to move before saying yes.';
  static const altOpportunity =
      'Check what this opportunity would displace before accepting.';
  static const altAnsweredTooQuickly = 'Do not answer in the first moment.';
  static const altQuickCaptureStillWork =
      'Skip the full story. Save only what pulled you toward yes.';
  static const altSomethingElse = 'Save the moment first. Name the pull later.';

  static const bodyDelayBeforeReplying = 'Delay the answer before replying.';
  static const bodyUrgencyCheckCapacity =
      'When urgency appears, do not answer immediately. Come back after checking your capacity.';
  static const bodyUsePauseAgain =
      'You delayed once. Try using the same pause again next time.';
  static const bodyOneMoreMoment =
      'One more real yes moment will make the loop clearer.';
  static const bodyWatchSamePull =
      'Watch for the same pull before agreeing again.';
  static const bodyMarkPull = 'Mark what pulled you toward yes.';
  static const bodyBeforeReplyingTemplate =
      'Before replying, use: ‘Let me check my capacity and come back to you.’';

  static const watchUrgentResponsible =
      'Watch for urgent requests where you feel responsible.';
  static const watchAnswerBeforeCapacity =
      'Watch for moments where you answer before checking capacity.';
  static const watchHardToDelay = 'Watch for requests that feel hard to delay.';
  static const watchSamePullMayRepeat =
      'This suggests the same pull may be the one to watch next.';

  static String pullShortLabel(String? reasonId) {
    if (reasonId == null || reasonId.isEmpty) return 'a repeated pull';
    return CapacityPullReasonCopy.shortLabelForReason(reasonId);
  }

  static String changeLineForResponseType(
    ArchiveDailyChangeResponseType type, {
    String? pullShortLabel,
  }) => switch (type) {
    ArchiveDailyChangeResponseType.repeatedPullWithLaterCost =>
      samePullLaterCostLine,
    ArchiveDailyChangeResponseType.repeatedPullWithSaidYes =>
      samePullSameOutcomeLine,
    ArchiveDailyChangeResponseType.patternInterrupted =>
      repeatedPullNewOutcomeLine,
    ArchiveDailyChangeResponseType.stillForming => stillFormingLine,
    ArchiveDailyChangeResponseType.waitingForNextMoment =>
      waitingForNextMomentLine,
    ArchiveDailyChangeResponseType.fitConfirmed => fitConfirmedLine,
    ArchiveDailyChangeResponseType.fitPartlyNewMoment => fitPartlyNewMomentLine,
    ArchiveDailyChangeResponseType.quickCaptureStillWork =>
      quickCaptureStillWorkLine,
    ArchiveDailyChangeResponseType.noPullReasonYet => noPullReasonLine,
    ArchiveDailyChangeResponseType.recentChange => changeNewYesMoment,
    ArchiveDailyChangeResponseType.boundaryResponseSelected =>
      boundaryResponseSelectedLine,
  };

  static String alternativeLabelForPull(String? pullId) => switch (pullId) {
    CapacityPullReasonIds.soundedUrgent => labelDelayBeforeReplying,
    CapacityPullReasonIds.feltResponsible => labelCheckCapacityFirst,
    CapacityPullReasonIds.avoidDisappoint => labelNameTheLimit,
    CapacityPullReasonIds.squeezeItIn => labelMoveSomethingFirst,
    CapacityPullReasonIds.wantedOpportunity => labelCheckTradeOff,
    CapacityPullReasonIds.answeredTooQuickly => labelPauseFirstAnswer,
    CapacityPullReasonIds.somethingElse => labelMarkPullFirst,
    _ => labelMarkPullFirst,
  };

  static String alternativeBodyForPull(String? pullId) => switch (pullId) {
    CapacityPullReasonIds.soundedUrgent => altUrgency,
    CapacityPullReasonIds.feltResponsible => altResponsibility,
    CapacityPullReasonIds.avoidDisappoint => altDisappointment,
    CapacityPullReasonIds.squeezeItIn => altSqueezeItIn,
    CapacityPullReasonIds.wantedOpportunity => altOpportunity,
    CapacityPullReasonIds.answeredTooQuickly => altAnsweredTooQuickly,
    CapacityPullReasonIds.somethingElse => altSomethingElse,
    _ => altSomethingElse,
  };

  static String watchNextForPullReason(String? reasonId) => switch (reasonId) {
    CapacityPullReasonIds.soundedUrgent ||
    CapacityPullReasonIds.feltResponsible => watchUrgentResponsible,
    CapacityPullReasonIds.answeredTooQuickly => watchAnswerBeforeCapacity,
    _ => watchHardToDelay,
  };

  static List<String> allVisibleStrings() => [
    title,
    alternativeSectionTitle,
    loopSectionTitle,
    weeklySectionTitle,
    labelDelayBeforeReplying,
    labelCheckCapacityFirst,
    labelNameTheLimit,
    labelMoveSomethingFirst,
    labelCheckTradeOff,
    labelPauseFirstAnswer,
    labelSaveOnlyPull,
    labelMarkPullFirst,
    labelUseDefaultPause,
    labelReviewLoop,
    labelWatchPull,
    repeatedPullNewOutcomeLine,
    samePullSameOutcomeLine,
    samePullLaterCostLine,
    patternInterruptedLine,
    stillFormingLine,
    waitingForNextMomentLine,
    fitConfirmedLine,
    fitPartlyNewMomentLine,
    quickCaptureStillWorkLine,
    boundaryResponseSelectedLine,
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
    altSomethingElse,
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
