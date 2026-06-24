import '../capacity_loop/capacity_pull_reason_models.dart';
import 'archive_daily_change_models.dart';

/// Copy for archive daily change — fixed signals only, no transcript text.
abstract final class ArchiveDailyChangeCopy {
  ArchiveDailyChangeCopy._();

  static const title = 'Your archive changed today';
  static const alternativeSectionTitle = 'Alternative next move';
  static const loopSectionTitle = 'What changed since last time';
  static const weeklySectionTitle = 'Next alternative to try';

  static const changeNewYesMoment = 'You added another yes moment.';
  static const changeUrgencyPull = 'Urgency appeared again as the pull.';
  static const changeLaterCost = 'You marked a later cost on one moment.';
  static const changeBoundarySelected = 'You chose a default pause line.';
  static const changeYesLoopReady =
      'Your yes loop has enough evidence to review.';

  static const alternativeUrgency =
      'I cannot answer properly right now — I will come back to you.';
  static const alternativeResponsibility =
      'Let me check my capacity and come back to you.';
  static const alternativeDisappointment =
      'I want to help, but I need to check what I can realistically do.';
  static const alternativeAnsweredTooQuickly =
      'I need to pause before I say yes.';
  static const alternativeNoPullReason =
      'Save what pulled you toward yes to make this clearer.';

  static const watchUrgentResponsible =
      'Watch for urgent requests where you feel responsible.';
  static const watchAnswerBeforeCapacity =
      'Watch for moments where you answer before checking capacity.';
  static const watchHardToDelay =
      'Watch for requests that feel hard to delay.';

  static String changeLineFor(ArchiveDailyChangeKind kind) => switch (kind) {
        ArchiveDailyChangeKind.newYesMoment => changeNewYesMoment,
        ArchiveDailyChangeKind.urgencyPull => changeUrgencyPull,
        ArchiveDailyChangeKind.laterCost => changeLaterCost,
        ArchiveDailyChangeKind.boundarySelected => changeBoundarySelected,
        ArchiveDailyChangeKind.yesLoopReady => changeYesLoopReady,
      };

  static String alternativeForPullReason(String? reasonId) => switch (reasonId) {
        CapacityPullReasonIds.soundedUrgent => alternativeUrgency,
        CapacityPullReasonIds.feltResponsible => alternativeResponsibility,
        CapacityPullReasonIds.avoidDisappoint => alternativeDisappointment,
        CapacityPullReasonIds.answeredTooQuickly => alternativeAnsweredTooQuickly,
        _ => alternativeNoPullReason,
      };

  static String watchNextForPullReason(String? reasonId) => switch (reasonId) {
        CapacityPullReasonIds.soundedUrgent ||
        CapacityPullReasonIds.feltResponsible =>
          watchUrgentResponsible,
        CapacityPullReasonIds.answeredTooQuickly => watchAnswerBeforeCapacity,
        _ => watchHardToDelay,
      };

  static List<String> allVisibleStrings() => [
        title,
        alternativeSectionTitle,
        loopSectionTitle,
        weeklySectionTitle,
        changeNewYesMoment,
        changeUrgencyPull,
        changeLaterCost,
        changeBoundarySelected,
        changeYesLoopReady,
        alternativeUrgency,
        alternativeResponsibility,
        alternativeDisappointment,
        alternativeAnsweredTooQuickly,
        alternativeNoPullReason,
        watchUrgentResponsible,
        watchAnswerBeforeCapacity,
        watchHardToDelay,
      ];
}
